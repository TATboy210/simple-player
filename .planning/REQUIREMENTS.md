# Requirements: 错误捕获定位反馈系统

**Defined:** 2026-08-28
**Core Value:** 出错可定位——任何错误发生时，无需接调试器即可知道错误在哪个文件哪一行、调用链是什么，一键复制或从日志文件回溯。

## v1 Requirements

### 捕获与契约 (Capture)

- [x] **CAP-01**: 四类错误源（FlutterError.onError 框架异常、PlatformDispatcher.onError 异步未捕获、runZonedGuarded 启动兜底、PlayerError 引擎错误）统一归一化为同一不可变 ErrorReport 契约（时间戳/严重级/错误/栈/媒体路径快照/event ID）
- [x] **CAP-02**: 三全局钩子在启动时于同一 guarded zone 内安装，保留 FlutterError.presentError 调试输出，dispatcher 处理后返回 true
- [x] **CAP-03**: ErrorReporter 为唯一 fan-in/fan-out 服务，入口不抛异常（reentrancy-safe），副作用逐一隔离，故障注入测试覆盖
- [x] **CAP-04**: 有界 FIFO 队列 + 指纹去重（类型/消息/来源/顶部应用帧），重复错误合并计数，关闭卡片推进队列不删证据

### 定位 (Locate)

- [x] **LOC-01**: 保守首帧定位——StackFrame.fromStackTrace 提取首个 package:simple_player_flutter 帧，raw stack 全程保留
- [x] **LOC-02**: 源码行显示——可信源码根路径校验（containment check），debug/profile 可读源码行；release 读不到源码优雅降级为仅定位文本，不报错不闪退
- [x] **LOC-03**: 报告含媒体路径快照（PlaybackController.currentPath，报告时快照不可变）与 failed-open 尝试路径上下文

### 落盘 (Log)

- [x] **LOG-01**: kernel_logger 保持门面，新增 error/fatal-only FileSink，输出引擎为 logger 2.7.0 `FileOutput(file, overrideExisting: false, encoding: utf8)` 单文件追加（context7 验证：append 语义正确）
- [x] **LOG-02**: 仅错误事件上盘（普通 debug/info 日志不上盘），落盘独立于卡片可见性
- [x] **LOG-03**: 单写者串行写队列（UTF-8 追加、有界 close/drain），写盘失败非致命不递归，降级为限流 debugPrint + "日志不可用"状态
- [x] **LOG-04**: path_provider 提供默认日志位置（不用 exe 目录/进程 cwd），配置路径写入前校验
- [x] **LOG-05**: 稳定诊断包格式（report ID/来源/时序/媒体快照/定位/可选源码行/重复信息/raw stack/日志路径），卡片复制与文件记录同格式

### 卡片 (Card)

- [x] **CARD-01**: 左上角非模态错误卡片，常驻手动关，无自动消失、无 route/barrier/autofocus、不抢焦点
- [x] **CARD-02**: 卡片 hit-test 严格限卡片边界，不遮挡控制栏/标题栏/播放列表交互（Windows 冒烟验证）
- [x] **CARD-03**: 渐进详情——折叠显示摘要+严重级+媒体路径，展开显示文件:行号/源码行/raw stack/日志路径
- [x] **CARD-04**: 一键复制诊断包（与 LOG-05 同格式），复制失败不影响卡片
- [x] **CARD-05**: build 期捕获的错误经 post-frame 合并发布 UI，不产生 markNeedsBuild 次生错误
- [x] **CARD-06**: 挂载于 app/player root Stack，ValueListenableBuilder 订阅 reporter 呈现状态（项目 ValueNotifier 惯例，不引入新状态库）

### 设置 (Settings)

- [x] **SET-01**: 设置"通用"tab 错误卡片开关（默认开；关掉后只落盘不弹卡，捕获与落盘不受影响）
- [x] **SET-02**: ~~设置"通用"tab 日志输出路径可配置~~ **2026-09-01 用户决策修订:路径配置功能移除**(实测判定鸡肋)——log 固定写软件根目录 logs/,exe 旁不可写时静默回退 Application Support(双层链与内部可写探测保留,配置 UI/配置层按 gap 闭环移除)
- [x] **SET-03**: 设置值重启持久化

### 迁移 (Migration)

- [x] **MIG-01**: PlayerErrorReportBridge（engine.lastError → ErrorReporter）经集成测试证明等效覆盖后，替换并移除旧 ErrorBanner——v1 内完成统一

### 验证 (Verification)

- [x] **VER-01**: 四源端到端故障注入——每源各产单报告+文件证据+卡片（开关开启时）
- [x] **VER-02**: 合成错误爆发（100-1000 事件）下有界内存、合并 UI、受控写盘、播放控制仍响应
- [x] **VER-03**: zone 一致性冒烟（binding/runApp 同 zone）、reentrancy 测试、复制/关闭失败隔离测试
- [x] **VER-04**: Windows 实机冒烟：标题拖动/窗口控制/seek/播放列表/全屏/ESC/媒体键在卡片显示期间全部正常
- [x] **VER-05**: 文档化 release 源码/符号策略与原生崩溃边界（Dart 钩子不覆盖 libmpv/FFI 进程崩溃）

## v2 Requirements

### 增强 (Enhancement)

- **ENH-01**: "打开日志目录"快捷操作（Windows UX 验证后）
- **ENH-02**: 细粒度 per-origin 节流策略（从真实观测日志调优）
- **ENH-03**: 内置只读日志查看器（外编辑器不足时才考虑）

## Out of Scope

| Feature | Reason |
|---------|--------|
| 远程上报/遥测（Sentry/Crashlytics） | 个人桌面应用无此需求，本地文件够用 |
| 日志轮转/压缩/加密 | 单文件追加已满足，不预建轮子 |
| 跨会话错误历史数据库 | 纯文本日志回溯足够（Unix 原则 5） |
| AI 归因/自动重试恢复 | 超出"定位反馈"边界，自动恢复有风险 |
| 原生崩溃捕获（libmpv/FFI access violation） | Dart 钩子覆盖不到，属 WER LocalDumps 开发机工具域 |
| 播放功能演进 | 与错误反馈无关 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CAP-01 | Phase 1 | Complete |
| CAP-02 | Phase 1 | Complete |
| CAP-03 | Phase 1 | Complete |
| CAP-04 | Phase 1 | Complete |
| LOC-01 | Phase 2 | Complete |
| LOC-02 | Phase 2 | Complete |
| LOC-03 | Phase 2 | Complete |
| LOG-01 | Phase 2 | Complete |
| LOG-02 | Phase 2 | Complete |
| LOG-03 | Phase 2 | Complete |
| LOG-04 | Phase 2 | Complete |
| LOG-05 | Phase 2 | Complete |
| CARD-01 | Phase 3 | Complete |
| CARD-02 | Phase 3 | Complete |
| CARD-03 | Phase 3 | Complete |
| CARD-04 | Phase 3 | Complete |
| CARD-05 | Phase 3 | Complete |
| CARD-06 | Phase 3 | Complete |
| MIG-01 | Phase 3 | Complete |
| SET-01 | Phase 4 | Complete |
| SET-02 | Phase 4 | Complete |
| SET-03 | Phase 4 | Complete |
| VER-01 | Phase 5 | Complete |
| VER-02 | Phase 5 | Complete |
| VER-03 | Phase 5 | Complete |
| VER-04 | Phase 5 | Complete |
| VER-05 | Phase 5 | Complete |

**Coverage:**

- v1 requirements: 27
- Mapped to phases: 27
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-28*
*Last updated: 2026-08-28 after roadmap creation*
