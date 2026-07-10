# Phase A: 架构定稿与核心模型 - Context

**Gathered:** 2026-07-09
**Status:** Ready for planning

<domain>
## Phase Boundary

建立 FullscreenAdapter 抽象层、状态模型、事件流和错误模型，使全屏成为有状态、有事件、有错误模型的独立核心能力模块。UI 层将只依赖 FullscreenAdapter 接口，不再直接调用 fullscreen_window 插件或依赖 WindowBridge 的全屏相关方法。

本阶段只定义接口和数据模型，不实现命令队列（Phase B）和平台适配（Phase C）。

</domain>

<decisions>
## Implementation Decisions

### 状态模型 (STATE)
- **D-01:** FullscreenSnapshot 采用**单一 ValueNotifier 包装不可变数据类**模式。FullscreenSnapshot 是纯数据类 + copyWith，外层 `ValueNotifier<FullscreenSnapshot>` 持有。与 WindowState 模式一致。全屏是强一致状态域，不适合拆成多个独立字段 notifier。
- **D-02:** phase 状态机采用 **5 状态线性机**：stable ↔ entering/leaving + forcedChange（OS 外部变更）+ error。转换路径简洁明确。
- **D-03:** FullscreenSnapshot 与 WindowState **独立共存 + 渐进迁移**。WindowState.mode 中的 fullscreen 枚举值保留但标记为 deprecated，FullscreenAdapter 内部同步两者状态。
- **D-04:** per-window 状态容器：内部 `Map<int, ValueNotifier<FullscreenSnapshot>>`，单窗口使用 `defaultWindowId = 0`。为 v2 MULTI-01 多窗口需求预留。
- **D-05:** restoreMode（全屏前的窗口状态）由 FullscreenAdapter 在 enter 时自动快照当前 WindowState.mode，退出时用它决定恢复目标。调用方不需要关心恢复逻辑。

### 事件系统 (EVT)
- **D-06:** FullscreenEvent 流内部使用 `StreamController<FullscreenEvent>.broadcast()` 实现。业务层通过 `Stream<FullscreenEvent>` 监听，与 _WindowListener 解耦。
- **D-07:** FullscreenAdapter 订阅 WindowBridge/driver 暴露的回调流，将原生事件转换为 FullscreenEvent 后广播。不直接耦合 `_WindowListener` 私有类型。

### 错误模型 (ERR)
- **D-08:** FullscreenError 采用 **sealed class** 设计，7 种错误类型各自可携带上下文字段（如 StateDesync 携带 actual vs expected，PlatformFailure 携带 platform message）。
- **D-09:** error 不是锁死态。下一次合法 `setFullscreen`/`toggle` 自动清理为 stable 并重走流程。不可恢复错误（如 Unsupported）允许重试但立即返回同类错误 + UI 明确提示。

### Adapter 边界 (ARCH)
- **D-10:** FullscreenAdapter 与 WindowService **并列 + 内部组合**。FullscreenAdapter 是独立模块，内部使用 WindowService 的通用窗口方法（setAlwaysOnTop 等）+ fullscreen_window 插件。WindowService 继续保留通用窗口操作职责。
- **D-11:** 迁移策略为 **Phase A 接口 + Phase B 渐进迁移**。Phase A 只建接口和模型，Phase B 实现时逐步替换 WindowService 中的全屏调用，feature flag 控制新旧切换。

### Claude's Discretion
- restoreMode 的具体快照时机（调用原生前 vs 后）留给实现阶段决定
- ForcedChange 事件的检测机制留给实现阶段
- displayId 的获取方式留给 Phase C 平台适配

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/PROJECT.md` — 项目全貌、核心价值、约束、已锁定决策
- `.planning/REQUIREMENTS.md` — 22 个 v1 需求（STATE/EVT/ERR/CMD/RST/PLAT/ARCH），Phase A 涉及 STATE-01~03, EVT-01~03, ERR-01~03, ARCH-01~02
- `.planning/ROADMAP.md` — 4 阶段路线图，Phase A 目标和成功标准
- `.planning/STATE.md` — 当前项目状态

### 现有实现
- `lib/kernel/bridge/window_service.dart` — 当前全屏实现（WindowService.setMode → fullscreen_window.setFullScreen）
- `lib/kernel/bridge/window_bridge.dart` — 抽象窗口管理接口（4 状态 notifier + 7 命令方法）
- `lib/kernel/bridge/window_state.dart` — 窗口状态容器（WindowState 数据类）
- `lib/kernel/bridge/window_mode.dart` — WindowMode 枚举（含 fullscreen 值）
- `packages/fullscreen_window/` — 本地全屏插件

### 代码库模式
- `.planning/codebase/ARCHITECTURE.md` — 分层架构、数据流、关键抽象
- `.planning/codebase/STACK.md` — 技术栈、依赖、平台要求
- `.planning/codebase/CONVENTIONS.md` — 命名规范、状态管理模式、错误处理

### 参考记忆
- `memory/project_fullscreen_bugs.md` — 5 个全屏 bug 修复经验
- `memory/project_fullscreen_win32_fix.md` — Win32 FFI 重写方案
- `memory/anti_pattern_fullscreen_ffi.md` — 禁止 win32 包的反面教训

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **WindowState 模式**: 不可变数据类 + 单一 ValueNotifier 包装，FullscreenSnapshot 直接复用此模式
- **WindowBridge 抽象接口**: 已有的抽象层设计模式，FullscreenAdapter 可参考其 ValueNotifier getter + 命令方法的结构
- **EngineState mixin 模式**: 能力 mixin 设计（TrackControl/VideoEffects），FullscreenAdapter 可参考其接口隔离方式
- **PlaylistStore 的 Map 模式**: per-window Map 容器可参考 PlaylistStore 的状态管理模式
- **win32_fullscreen.dart**: 已有的 Win32 FFI 全屏实现，FullscreenAdapter 内部可复用

### Established Patterns
- **ValueNotifier + ValueListenableBuilder**: 唯一状态管理模式，FullscreenAdapter 必须遵循
- **不可变数据 + copyWith**: 所有状态容器使用此模式（PlaylistItem, AppSettings, WindowState）
- **Composition over inheritance**: FvpEngine 由 6 个 helper 组合，PlaybackController 由 3 个子模块组合。FullscreenAdapter 应采用类似模式
- **Abstract interface + concrete implementation**: WindowBridge → WindowService 模式，FullscreenAdapter → DesktopFullscreenAdapter

### Integration Points
- **WindowService**: FullscreenAdapter 内部使用其通用窗口方法（setAlwaysOnTop, setAspectRatio 等）
- **fullscreen_window 插件**: FullscreenAdapter 内部调用 setFullScreen()
- **UI 层**: PlayerScreen/keyboard_handler 将从 WindowService.mode 迁移到 FullscreenAdapter.snapshot
- **_WindowListener**: WindowBridge 需要暴露回调流供 FullscreenAdapter 订阅

</code_context>

<specifics>
## Specific Ideas

- 全屏是强一致状态域，必须保证 snapshot 的原子性更新
- error 状态不是锁死态，重试自动清理并重走流程
- Adapter 订阅 WindowBridge 暴露的回调流，不耦合私有类型
- Phase A 只建接口和模型，不实现命令队列和平台适配

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: A-架构定稿与核心模型*
*Context gathered: 2026-07-09*
