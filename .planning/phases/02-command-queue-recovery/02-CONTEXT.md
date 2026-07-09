# Phase B: 命令队列与恢复策略 - Context

**Gathered:** 2026-07-09
**Status:** Ready for planning

<domain>
## Phase Boundary

实现 per-window 命令串行化、幂等合并、真实状态回读和完整恢复策略。使快速连按 F 10 次不出现状态错位，各种窗口模式切换场景（windowed/maximized/副屏/minimized）都能正确恢复。同时将旧 fullscreen_window 调用点渐进迁移到 FullscreenAdapter。

本阶段不实现平台特定驱动（Phase C），不实现质量收尾和 E2E 测试（Phase D）。

</domain>

<decisions>
## Implementation Decisions

### 命令队列实现策略 (CMD)
- **D-12:** 命令队列采用 **Completer 链** 模式。一个 Completer 代表当前 in-flight 命令，新命令到达时如果前一个还没完成，入队等待。状态机清晰，实现简单。
- **D-13:** 命令执行 **5 秒超时 + 报错**。超时后取消并报 BusyTransition 错误。macOS 全屏动画约 1s，5s 足够覆盖极端情况。
- **D-14:** 队列采用 **per-windowId 独立队列**。每个 windowId 一个独立的队列实例，多窗口完全隔离。与 Phase A D-04 的 per-window 状态容器一致。
- **D-15:** FullscreenCommandQueue 作为 **独立类**，FullscreenAdapter 内部持有。职责分离清晰，可独立测试。
- **D-16:** 命令开始执行时（非入队时）立即更新 snapshot.phase 为 entering/leaving。排队中的命令不提前改 phase，避免"看起来在切换、其实还在排队"的假状态。
- **D-17:** 队列中待执行命令可以合并。新命令入队时，如果队列中已有相同目标的待执行命令，直接复用前一个的 Completer，不重复入队。合并规则：1) toggle 先解析为明确目标（setFullscreen(true/false)）再参与合并；2) 只在同一 windowId 下、且 target + displayId 相同才合并。

### 幂等合并与状态回读 (CMD-02/CMD-03)
- **D-18:** toggle 命令 **先解析再合并**。toggle 基于已确认状态解析为 setFullscreen(true/false)，再按 setFullscreen(target) 去重/合并。
- **D-19:** 状态回读采用 **等回调 + 超时轮询** 三级策略：1) 先等 WindowListener 回调确认状态（主路径）；2) 若 500ms 未确认，进入短轮询（100ms 间隔，最多 20 次 = 2s）；3) 仍未收敛则按超时错误处理，并做一次最终 query() 校正。总超时 2.5s。
- **D-20:** StateDesync 时 **报错 + 不自动重试**。回读结果与目标不一致时：1) 发出 StateDesync 事件；2) snapshot.phase 设为 error；3) 但 snapshot 的 isFullscreen/effectiveMode 仍更新为回读到的真实状态（snapshot 始终反映现实）。用户可手动重试。
- **D-21:** 轮询查询使用 **windowManager.isFullScreen()**。跨平台可用。WindowBridge.mode 只作缓存参考，不作真实状态回读依据。回读以 windowManager.isFullScreen()（或后续 driver 的真实查询）为准。

### 恢复策略细节 (RST)
- **D-22:** restoreMode 在 **调用原生前快照**。快照内容：restoreMode + position + size + displayId（可取到就存）。仅在"非全屏→进入全屏"时采集，同一轮全屏会话里不反复覆盖快照。
- **D-23:** maximized 恢复采用 **调用 maximize()**。restoreMode == maximized 时优先恢复最大化语义，不用几何去模拟最大化（避免语义漂移）。
- **D-24:** 副屏恢复采用 **setBounds 恢复**。退出全屏后用快照的 position + size 调用 windowManager.setBounds() 恢复到副屏原始位置。降级策略：如果副屏已不可用（显示器拓扑变化），降级到主屏可见区域并 center。
- **D-25:** minimized 状态下全屏采用 **先 restore 再全屏**。检测到 minimized 时，先调用 windowManager.restore() 恢复窗口，再进入全屏。两步操作串行执行。

### 旧实现迁移路径 (ARCH-03)
- **D-26:** 迁移策略为 **Adapter 内部双实现**。FullscreenAdapter 内部同时持有旧实现（fullscreen_window 直调）和新实现（command queue + driver），运行时通过编译时 flag 切换。
- **D-27:** feature flag 采用 **编译时 --dart-define=USE_NEW_FULLSCREEN=true**。简单，不需要运行时切换。
- **D-28:** 迁移顺序为 **先迁移 WindowService**。Phase B：WindowService.setMode(fullscreen) 内部委托 FullscreenAdapter。后续阶段：UI（player_screen / keyboard_handler / control_bar）改为直接依赖 FullscreenAdapter。
- **D-29:** 兼容约束：WindowService 仅转发 fullscreen，不接管队列/状态机逻辑；全屏状态真相源固定为 FullscreenAdapter.snapshot/events；禁止在 UI 层新增任何 fullscreen_window 直调。
- **D-30:** Phase B 同时清理 UI 层的 fullscreen_window 直调（如果有的话）。
- **D-31:** feature flag 粒度：只在 FullscreenAdapter 内切换实现（legacy/new），不在 UI 或 WindowService 层再加二级 flag。

### Claude's Discretion
- 具体的 Completer 链实现细节（如队列最大长度、内存清理策略）留给实现阶段
- windowManager.isFullScreen() 的跨平台一致性差异留给 Phase C 平台适配
- 轮询 Timer 的取消和清理逻辑留给实现阶段

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/PROJECT.md` — 项目全貌、核心价值、约束、已锁定决策
- `.planning/REQUIREMENTS.md` — 22 个 v1 需求，Phase B 涉及 CMD-01~03, RST-01~04, ARCH-03
- `.planning/ROADMAP.md` — 4 阶段路线图，Phase B 目标和成功标准
- `.planning/STATE.md` — 当前项目状态
- `.planning/phases/01-architecture-core-models/01-CONTEXT.md` — Phase A 决策（D-01~11），Phase B 必须遵循

### 现有实现
- `lib/kernel/bridge/window_service.dart` — 当前全屏实现（WindowService.setMode → fullscreen_window.setFullScreen），迁移目标
- `lib/kernel/bridge/window_bridge.dart` — 抽象窗口管理接口（4 状态 notifier + 7 命令方法）
- `lib/kernel/bridge/window_state.dart` — 窗口状态容器（WindowState 数据类）
- `lib/kernel/bridge/window_mode.dart` — WindowMode 枚举（含 fullscreen 值）
- `lib/ui/player/player_screen.dart` — 主屏幕，可能有 fullscreen_window 直调需清理
- `lib/ui/player/keyboard_handler.dart` — 键盘处理，F 键触发全屏
- `packages/fullscreen_window/` — 本地全屏插件，旧实现依赖

### 代码库模式
- `.planning/codebase/ARCHITECTURE.md` — 分层架构、数据流、关键抽象
- `.planning/codebase/STACK.md` — 技术栈、依赖、平台要求

### 参考记忆
- `memory/project_fullscreen_bugs.md` — 5 个全屏 bug 修复经验
- `memory/project_fullscreen_win32_fix.md` — Win32 FFI 重写方案
- `memory/anti_pattern_fullscreen_ffi.md` — 禁止 win32 包的反面教训

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **WindowService.setMode()**: 当前全屏入口，Phase B 改为委托给 FullscreenAdapter
- **fullscreen_window 插件**: 旧实现依赖，FullscreenAdapter 内部的 legacy 分支继续使用
- **WindowState 模式**: 不可变数据类 + ValueNotifier，FullscreenSnapshot 复用此模式
- **WindowPersistence 的 debounce 模式**: 可参考其 Timer 管理方式处理轮询

### Established Patterns
- **ValueNotifier + ValueListenableBuilder**: 唯一状态管理模式
- **Composition over inheritance**: FvpEngine 由 6 个 helper 组合，FullscreenCommandQueue 作为独立类被 Adapter 持有
- **openGeneration guard**: PlaybackNavigator 的并发保护模式，命令队列可参考
- **atomic write + retry**: PlaylistStore 的错误恢复模式，可参考其超时和重试策略

### Integration Points
- **WindowService.setMode()**: Phase B 的主要迁移点，内部改为委托 FullscreenAdapter
- **keyboard_handler.dart**: F 键触发全屏，Phase B 清理其中的 fullscreen_window 直调
- **player_screen.dart**: 全屏相关 UI 逻辑，Phase B 清理直调
- **WindowListener 回调**: FullscreenAdapter 订阅其回调流用于状态回读

</code_context>

<specifics>
## Specific Ideas

- 命令开始执行时（非入队时）才更新 phase，避免排队中的假状态
- toggle 必须基于已确认状态解析目标，再参与合并
- StateDesync 时 snapshot 仍更新为真实状态（snapshot 始终反映现实），同时发错误事件
- 副屏不可用时降级到主屏 center
- 两阶段迁移：Phase B WindowService 转发，后续阶段 UI 直连 Adapter
- 验收关卡：快速连按 F（10 次）无错态、maximized→fullscreen→exit 恢复正确、副屏恢复正确、StateDesync 有错误事件且状态回读正确

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: B-命令队列与恢复策略*
*Context gathered: 2026-07-09*
