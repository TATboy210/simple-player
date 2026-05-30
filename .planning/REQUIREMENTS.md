# Requirements — Simple Player Flutter v1.2

**日期:** 2026-05-30
**策略:** 安全加固 + 窗口持续优化 + Debug 工具（架构优化延后至有详细报告）

## v1.2 需求

### 安全加固 (SEC)

- [ ] **SEC-01**: FFI 内存安全
  - WindowService 中 6 处 `calloc` 手动管理指针的生命周期安全
  - `_savedFrame` 在 `dispose()` 中缺失清理（内存泄漏路径）
  - 短生命周期指针（margins, MonitorInfo, frame）用 try/finally 包裹
  - 长生命周期指针（_savedFrame, _savedMaximizeFrame）确保所有异常路径都释放
  - fullscreen 转换超时保护（防止 `_fullscreenTransitioning` 永久锁定）
  - 文件: `lib/kernel/bridge/window_service.dart`, `lib/kernel/bridge/win32_bindings.dart`
  - 风险: 指针所有权跨方法边界（_enterFullscreen 分配, _exitFullscreen 释放）

- [ ] **SEC-02**: 输入验证（HTTP/HTTPS 结构化验证）
  - HTTP/HTTPS URL 使用 `Uri.tryParse()` 结构化验证
  - RTSP/RTMP/SRT/UDP 保持前缀检测（不阻断 FFmpeg 支持的协议）
  - 文件路径控制字符过滤
  - 文件: `lib/kernel/services/path_validator.dart`, `lib/kernel/engine/fvp_engine.dart`

### 窗口优化 (WIN)

- [ ] **WIN-04**: 窗口管理和用户体验持续改进
  - 窗口启动和恢复流程优化
  - 全屏/最大化/恢复动画平滑度
  - 多显示器场景边界检查
  - 窗口几何状态持久化可靠性
  - 文件: `lib/kernel/bridge/window_service.dart`, `lib/ui/player/custom_title_bar.dart`

### 性能优化 (PERF)

- [ ] **PERF-04**: 播放器性能优化
  - PositionPoller 250ms 轮询优化（减少 CPU 唤醒或使用回调）
  - ThumbnailService LRU 缓存从 List O(n) 改为 LinkedHashMap O(1)
  - D3D11 sync 模式智能切换（高刷新率显示器异步模式）
  - 渲染管线性能审计（基于 Flutter #97334 Windows 动画卡顿分析）
  - 文件: `lib/kernel/engine/position_poller.dart`, `lib/kernel/services/thumbnail_service.dart`, `lib/kernel/engine/fvp_engine.dart`

### Debug 工具 (DBG)

- [ ] **DBG-01**: Debug 工具和诊断改进
  - 结构化日志输出（JSON 格式 LogPrinter）
  - 命名 logger 实例（按模块分类）
  - `dart:developer` Timeline 追踪关键方法（3-5 个性能敏感路径）
  - 文件: `lib/kernel/utils/log.dart`

## v1.3+ 延后需求（需要详细报告）

### 架构优化 (ARCH) — 需要详细分析报告

- [ ] **ARCH-01**: FvpEngine 拆分 — 需要引擎层详细报告（方法分析、依赖图、拆分方案）
- [ ] **ARCH-02**: SettingsStore 简化 — 需要持久化层详细报告（存储格式、迁移策略）
- [ ] **ARCH-03**: 单例迁移 — 需要依赖关系详细报告（21+ 文件影响分析）

### 保留但不改动

- 流媒体相关代码（HLS/ABR）— 保留现有代码，暂不实现新功能
- 平台相关代码 — 保留 Win32 FFI，暂不添加 macOS/Linux 支持

## 不在范围内

- 新依赖引入 — 使用 Dart SDK 内建能力
- 状态管理迁移 — ValueNotifier 保留
- 流媒体新功能 — 播放器支持本地运行
- 跨平台支持 — Windows 优先

## 可追溯性

| 需求 | Phase | 状态 | 来源 |
|------|-------|------|------|
| SEC-01 | 9 | 待规划 | CONCERNS.md (HIGH) |
| SEC-02 | 9 | 待规划 | CONCERNS.md (MEDIUM) |
| WIN-04 | 10 | 待规划 | 用户请求 |
| PERF-04 | 11 | 待规划 | CONCERNS.md + Flutter #97334 |
| DBG-01 | 12 | 待规划 | 用户请求 |

---
*最后更新: 2026-05-30 — v1.2 roadmap updated: 4 phases (9-12), PERF-04 added*
