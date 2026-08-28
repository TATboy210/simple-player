# Project Research Summary

**Project:** Simple Player Flutter  
**Domain:** Local Flutter Windows error capture, source-location enrichment, append-only diagnostics, and non-modal developer feedback  
**Researched:** 2026-08-28  
**Confidence:** MEDIUM-HIGH

## Executive Summary

This milestone adds a developer-local diagnostics pipeline to a Flutter Windows media player: framework, root-isolate全局三钩子 + PlayerError 桥接的输入经一个故障隔离的 `ErrorReporter` 归一化为不可变 `ErrorReport`，持久化为纯文本日志（kernel_logger 门面 + logger.FileOutput 引擎），并以左上角非模态错误卡片反馈。

The recommended implementation is deliberately local and narrow: install `FlutterError.onError` / `PlatformDispatcher.instance.onError` / 窄 `runZonedGuarded` 启动守卫，显式桥接 `PlayerError`；`ErrorReporter` 快照媒体上下文、安全富化（首个项目帧 + 可选源码行）、指纹去重、有界 FIFO 队列，独立扇出到 KernelLogger 与 UI 状态。

The dominant risks are 递归错误处理、zone 错配/丢错、build 期 notifier 发布、release 无源码、文件 I/O 与洪流二次事故。缓解：钩子同步不抛、同 zone 启动、UI 发布推迟到 post-frame、源码查找可选且限路径、单写者串行写盘、队列与去重状态有界。

## Key Findings

### Recommended Stack（HIGH 置信）

无需新运行时依赖：Flutter/Dart 提供捕获边界与栈解析，`logger 2.7.0` 提供输出管线（**FileOutput，append 语义**；不用 AdvancedFileOutput——其默认轮转/缓冲与单文件追加决策冲突），`path_provider 2.1.6` 提供默认可写位置。

- **FlutterError.onError**：框架 build/layout/paint/手势/生命周期错误；转发前先 `FlutterError.presentError(details)` 保留调试输出
- **PlatformDispatcher.instance.onError**：root-isolate 未捕获异步/插件错误；**接受报告后返回 true**
- **runZonedGuarded**：兜底启动守卫（非主异步机制）；binding 初始化、reporter/logger 初始化、钩子安装、runApp 在同一 guarded 闭包内
- **logger 2.7.0 FileOutput**：`FileOutput(file, overrideExisting: false, encoding: utf8)` 单文件追加
- **StackFrame.fromStackTrace**：尽力提取首个 `package:simple_player_flutter` 帧
- **ValueNotifier 惯例**：reporter 暴露 `ValueNotifier<ErrorPresentationState>`（FIFO/计数/dismiss 语义属于 reporter 而非卡片）
- **不引入**：第三方崩溃包、遥测、第二套日志架构、in-app 日志控制台

### Expected Features

**必备（table stakes）：**
- 四源统一捕获 → 同一 report 契约（时间戳/严重级/错误/栈/媒体路径快照）
- 单活动常驻非模态卡片：摘要+严重级+媒体路径+展开详情+手动关闭，无自动消失、不抢焦点
- 渐进详情：文件:行号优先、错误类型/消息、可选源码行、raw stack、媒体路径、日志路径仅展开后显示；release 明确"源码不可用"状态不伪造
- 一键复制诊断包：event ID/时间/严重级/来源/异常/媒体路径/定位/源码行/重复信息/raw stack/日志路径
- 有界 FIFO + 保守指纹去重（类型/消息/来源/顶部应用帧；首现+重复计数）
- 仅错误上盘，独立于卡片可见性
- 设置开关只控展示、日志路径校验+回退默认

**差异化：**
- 可信首帧定位 + 可选源码行（开发者 checkout 限路径）
- 跨源单一 report 契约 + event ID
- 降噪保根因（首现+重复计数/首末时间）
- 同卡片按需详情

**推迟（v1.x/v2+）：**
- 细粒度 per-origin 节流、"打开日志目录"快捷操作（Windows UX 验证后）
- 内置只读日志查看器（外编辑器足够时）
- 用户触发恢复、跨会话索引历史、数据库、远程上报、AI 归因、自动重试、轮转

### Architecture Approach

单向管线：捕获边缘最小适配 → ErrorReporter 归一化/快照/去重/有界队列/安全扇出 → KernelLogger 扇出文件输出；player feature 拥有唯一 PlayerError 桥。

1. **Global hook installer（main.dart）**：三钩子在完整 guarded 启动中安装
2. **ErrorSource/不可变 ErrorReport/工厂+富化（kernel/diagnostics/）**
3. **ErrorReporter**：唯一 fan-in/fan-out 边界，注入 clock/context provider/locator/source reader/sink
依赖注入便于故障注入测试
4. **KernelLogger + ErrorOnlyFileSink**：保留门面，error/fatal-only sink 适配 logger.FileOutput
5. **PlayerErrorReportBridge**：engine.lastError → ErrorReporter（feature 装配，随服务销毁）
6. **ErrorCardHost + ErrorCard**：挂 root Stack，ValueListenableBuilder 订阅，有界 hit-test 区域
7. **设置通用 tab**：展示偏好+日志路径（写入前校验+回退 last-known-good）

### Critical Pitfalls（7 项）

1. zone-only 捕获或 zone 错配 —— 三钩子齐装、同 zone 启动
2. reporter 递归 —— 钩子最小化不抛、副作用隔离、reentrancy guard + debugPrint 兜底
3. build 期同步 notifier 发布 —— 先捕获入队，post-frame 合并发布
4. release 源码过度承诺 —— 定位/源码建模为可选状态，不信任任意绝对路径
5. 并发文件输出损坏 —— 单 sink 串行队列、UTF-8 追加、有界 close/drain、安全不可用状态
6. 非模态实际变模态 —— hit-test 限卡片边界、无 route/barrier/autofocus、Windows 冒烟
7. 错误洪流 —— reentrancy 预防与有界指纹抑制分离、100-1000 事件合成爆发测试

## Implications for Roadmap

按依赖驱动分 5 个 phase（契约→落盘→桥+卡片→设置→端到端验证）：

### Phase 1: 诊断契约 + ErrorReporter 核心 + 安全全局捕获
不可变 ErrorReport/ErrorSource/严重级/event ID/位置可选状态/报告工厂/formatter + 有界去重/FIFO 呈现策略；独立 ErrorReporter（注入 clock/context providers、不抛/reentrancy-safe）；完整启动组装（同 zone guarded 闭包内完成 binding/reporter/钩子/runApp）；验证：四源注入测试+zone 一致性+reentrancy+100-1000 爆发测试

### Phase 2: 定位富化 + 仅错误文件落盘
保守首帧定位（StackFrame.fromStackTrace + raw stack 保留 + 可信源码行解析 + release 回退）；ErrorOnlyFileSink（kernel_logger 门面下，logger.FileOutput 追加语义、纯文本 printer、error/fatal-only）+ path_provider 默认位置 + 配置路径校验 + 单写者串行写队列 + 有界 close/drain + 稳定诊断包/文件记录格式（report ID/来源/时序/媒体快照/定位/可选源码行/重复/raw stack/日志路径）
验证：畸形栈/无应用帧/缺源码/越界路径/目录被拒/写关失败/串行顺序/release 等效无源码测试

### Phase 3: PlayerError 桥 + 非模态统一错误卡片
PlayerErrorReportBridge（engine.lastError → ErrorReporter，随服务销毁；failed-open 尝试路径上下文）+ ErrorCardHost（root Stack 挂载）+ ErrorCard（左上角、严重级文本、重复/队列计数、展开详情、raw stack、日志路径、复制诊断包、手动 dismiss/next）+ 卡片可见性偏好输入（不影响捕获/落盘）
替换旧 ErrorBanner 仅在桥集成测试证明等效覆盖后
验证：子 build 抛异常→单原始报告无次生错误；复制/关闭失败隔离；卡外 hit-test 保持；焦点/快捷键保持；Windows 手动冒烟（标题拖动/窗口控制/seek/播放列表/全屏/ESC/媒体键）

### Phase 4: 设置、配置变更与运维降级
设置通用 tab：showErrorCards + 日志目的地配置（写入前可写校验、安全默认回退、last-known-good、sink 不可用时可见非递归状态）
验证：重启持久化、关卡片仍落盘、无效路径回退、成功重配、配置变更后 sink 恢复

### Phase 5: 端到端故障注入、release 策略与洪流加固
端到端证明四源各产单报告+文件证据+卡片；合成爆发性能/洪流验证（有界内存、合并 UI、受控写盘/重复摘要、播放控制响应）；文档化 Windows profile/release 源码/符号策略+记录 build ID+原生崩溃边界声明
验证：shutdown/close 行为+全故障隔离回归套件

### Phase Ordering Rationale

- 契约与 reporter 是系统边界——无 UI/logger 扩展/桥应发明平行表示
- 落盘先于全局路由与视觉反馈：报告失败可隔离测试，不进递归失败路径
- PlayerError 桥先于旧 banner 移除：迁移期保留今天的可恢复引擎错误反馈
- UI 契约稳定后建设；设置最后；端到端/洪流验证收尾

### Research Flags

**需 planning 深研：**
- Phase 1：当前启动顺序、KernelLogger 初始化生命周期、PlayerError/媒体路径所有权（brownfield 接线与重复路由行为需代码级调查）
 brownfield 接线
- Phase 2：logger 适配行为、Windows 写/关语义、profile/release build flags 与 debug-artifact 保留策略
- Phase "Phase 3 需实机冒烟：标题栏拖动、全屏、ESC、媒体键——widget 测试无法完全证明"）3：实际 player Stack、旧 ErrorBanner 行为、标题栏/控制栏排除区、剪贴板/无障碍 API
- Phase 5：真实重复引擎错误下 profile 去重/写合并策略（从观测日志调优，不凭空规则）

**标准模式（可跳过单独研究）：**
- Phase 4：布尔/路径持久化与配置更新是项目既有模式
- Phase 1 钩子 API 机制：官方指南充分，规划聚焦仓库集成与测试

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | 官方 Flutter/Dart API + 锁定 logger 2.7.0，无需新依赖 |
| Features | MEDIUM | UX 共识强，队列/复制/设置细节需实施验证 |
| Architecture | MEDIUM | fan-in/fan-out 结构受支持；brownfield 接线需代码级验证 |
| Pitfalls | MEDIUM | 主论点受官方文档支持；真实洪流/Windows I/O 细节实施时验证 |

**Overall confidence:** MEDIUM-HIGH

## Sources

### Primary (HIGH confidence)
- [Flutter: Handling errors in Flutter](https://docs.flutter.dev/testing/errors) — 三钩子捕获边界与 handler 行为
- [Flutter: Zone mismatch breaking change](https://docs.flutter.dev/release/breaking-changes/zone-errors) — same-zone 启动要求
- [Flutter API: PlatformDispatcher.onError](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html) — root-isolate 契约
- [Flutter API: FlutterErrorDetails / StackFrame](https://api.flutter.dev/flutter/foundation/StackFrame-class.html) — 可用字段与尽力解析
- [Dart API: runZonedGuarded](https://api.dart.dev/stable/dart-async/runZonedGuarded.html) — 错误 zone 契约
- [logger 2.7.0](https://pub.dev/packages/logger) — FileOutput/AdvancedFileOutput、追加行为
- [Flutter file persistence cookbook](https://docs.flutter.dev/cookbook/persistence/reading-writing-files) — 应用托管可写存储模式

### Secondary (MEDIUM confidence)
- [VS Code notification UX guidelines](https://code.visualstudio.com/api/ux-guidelines/notifications) — 单通知+重复合并
- [VLC desktop bug-report guidance](https://docs.videolan.me/vlc-user/en/support/report_a_bug/desktop.html) — 完整本地日志取证
- [Dart Zones guide](https://dart.dev/libraries/async/zones) — zone 边界与陷阱
- 项目集成参考: lib/main.dart, lib/kernel/diagnostics/kernel_logger.dart, lib/kernel/services/playback_controller.dart, lib/features/player/player_feature.dart, lib/ui/player/error_banner.dart

### Tertiary (LOW confidence)
- [Microsoft Fluent MessageBar](https://fluent2.microsoft.design/components/web/react/core/messagebar/usage) — 非模态错误消息模式
- [W3C WCAG Error Identification](https://www.w3.org/WAI/WCAG21/Understanding/error-identification.html) — 颜色之外的文本标识
- [Microsoft WER LocalDumps](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps) — 原生崩溃诊断边界

---
*Research completed: 2026-08-28*
*Ready for roadmap: yes*
