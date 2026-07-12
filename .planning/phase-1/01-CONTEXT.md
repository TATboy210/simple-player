# Phase 1: 全屏代码简化 - Context

**Gathered:** 2026-07-12
**Status:** Ready for planning

<domain>
## Phase Boundary

简化全屏代码架构：减少抽象层（4→3），建立 WindowService 为 isFullscreen 单一数据源，评估 flutter_fullscreen 包并输出评估文档。不涉及设置面板改动、不涉及跨平台行为统一。

</domain>

<decisions>
## Implementation Decisions

### 驱动层合并策略
- **D-01:** 删除 DesktopFullscreenDriver（window_manager fallback driver），macOS/Linux 直接调用 fullscreen_window 包原生代码。层数 4→3。
- **D-02:** 删除 DesktopFullscreenDriverFactory，平台检测逻辑内联到 WindowService.init()。减少一个文件和一层间接。
- **D-03:** WindowsFullscreenDriver (459行) 和 Win32FullscreenFfi (509行) 保持分离。FFI bindings 可独立测试，职责清晰，合并后 ~900 行超最佳实践。
- **D-04:** 同时清理各层内部冗余抽象：CommandQueue 防重入、7 种错误类型简化为 sealed class、状态机过度抽象删除。
- **D-05:** macOS/Linux 直接用 packages/fullscreen_window/ 的原生代码（113行 C++ macOS、182行 C Linux），不经过额外抽象层。

### flutter_fullscreen 评估
- **D-06:** 不引入 flutter_fullscreen 包。原因：内部完全依赖 window_manager，无法解决 WS_THICKFRAME 7px 缝隙，用户确认 win32 包会导致一帧卡顿。Windows 保留自研 Win32 FFI。
- **D-07:** 输出 flutter_fullscreen 评估文档到 `.planning/research/`，包含对比表、不用原因、引入条件。满足 FULL-02 需求。

### 全屏状态归属
- **D-08:** WindowService 为 isFullscreen 唯一 owner，通过 ValueNotifier 暴露。SettingsStore 删除 saveIsFullscreen/isFullscreen 相关 getter/setter。满足 FULL-03。
- **D-09:** 全屏状态需要持久化，由 WindowService 管理（而非 SettingsStore）。启动时恢复全屏状态。
- **D-10:** 窗口几何快照/恢复逻辑保留在 WindowService 内部（_restoreSnapshot），不移到驱动层。

### 错误处理
- **D-11:** 错误处理用 sealed class (FullscreenResult: Success/Failure) + 自动恢复窗口状态。替代现有 7 种错误类型分类。
- **D-12:** 确认链简化：保留回调确认为主路径，超时后简化为单次查询（而非 20 次轮询），删除 _confirmByWindowId 复杂映射。

### WindowService 职责边界
- **D-13:** WindowService 保持现状不拆分。合并全屏状态后可能超 500 行，但职责内聚（全屏+resize+持久化+几何都属窗口管理）。
- **D-14:** 保留 WindowBridge 抽象接口（4 states + 7 commands），用于测试和 macOS/Linux 平台实现。
- **D-15:** WindowService 通过构造函数注入持久化接口，便于测试和解耦 SettingsStore 直接依赖。
- **D-16:** 简化 resize debounce 为单个 Timer（当前有 _resizeDebounce 和 _resizeEndTimer 两个），减少 Timer/Completer 交互复杂度。

### Claude's Discretion
无 — 所有决策均用户明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/ROADMAP.md` — Phase 1 目标、成功标准、依赖关系
- `.planning/REQUIREMENTS.md` — FULL-01, FULL-02, FULL-03 需求定义
- `.planning/PROJECT.md` — 项目约束、已知问题、技术环境

### 架构文档
- `.planning/codebase/ARCHITECTURE.md` — 全屏 Toggle Path (line 157-165)、FullscreenDriver 抽象、WindowService 组件职责
- `.planning/codebase/STRUCTURE.md` — lib/kernel/bridge/ 目录结构、文件位置
- `.planning/codebase/CONCERNS.md` — Win32 Fullscreen FFI 脆弱性 (line 78-83)、WindowService Timer/Completer 交互 (line 84-88)、确认链超时问题 (line 39-43)

### 关键源文件（需阅读理解当前实现）
- `lib/kernel/bridge/window_service.dart` — 451 行，全屏协调器
- `lib/kernel/bridge/fullscreen_driver.dart` — 抽象接口
- `lib/kernel/bridge/desktop_fullscreen_driver.dart` — 待删除：window_manager fallback
- `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` — 待删除：工厂类
- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` — 459 行，Win32 FFI 驱动
- `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` — 509 行，FFI bindings
- `lib/kernel/bridge/platform/macos_fullscreen_driver.dart` — macOS 驱动
- `lib/kernel/bridge/platform/linux_fullscreen_driver.dart` — Linux 驱动
- `lib/kernel/persistence/settings_store.dart` — 待清理：全屏相关 getter/setter
- `packages/fullscreen_window/` — 本地包，macOS/Linux 复用目标

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `packages/fullscreen_window/` — macOS/Linux 原生全屏实现可直接复用（113行 C++ macOS、182行 C Linux）
- `lib/kernel/bridge/window_persistence.dart` — 窗口几何持久化，WindowService 已使用
- `lib/kernel/bridge/window_state.dart` — 不可变状态容器，含 copyWith 模式
- `lib/kernel/bridge/window_mode.dart` — WindowMode enum (windowed/maximized/fullscreen/minimized)

### Established Patterns
- ValueNotifier + ValueListenableBuilder 状态管理 — 全屏状态暴露遵循此模式
- sealed class 错误处理 — 项目已有 OpenResult (OpenSuccess/OpenError) 模式可复用
- 不可变状态 + copyWith — VideoProcessingState、StartupState 模式可参考
- 构造函数注入 — PlayerServices DI 模式可参考

### Integration Points
- `lib/main.dart` — DesktopFullscreenDriverFactory.create() 调用需改为 WindowService.init() 内联
- `lib/ui/player/player_screen.dart:193` — F 键全屏调用 windowService.setMode()
- `lib/ui/player/controls_overlay.dart:185` — 接收 isFullscreen 参数
- `lib/kernel/bridge/window_bridge.dart` — 抽象接口，所有全屏调用经过此接口

</code_context>

<specifics>
## Specific Ideas

- 用户明确要求："千万必要下载win32依赖，这个依赖会导致播放器全屏有一帧卡顿" — Win32 FFI 核心必须保留
- 长期记忆逆向分析建议从 3,248 行精简到 ~800 行，删除过度抽象层
- flutter_fullscreen 评估文档需包含：对比表、不用原因、什么条件下会考虑引入

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1-全屏代码简化*
*Context gathered: 2026-07-12*
