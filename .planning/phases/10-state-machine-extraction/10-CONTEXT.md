# Phase 10: 状态机提取 + 引擎瘦身 - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

从 FvpEngine 中提取独立 EngineStateMachine 类（拥有状态 + 强制转换守卫），并将 FvpEngine 从 632 行精简至 <350 行。Helper 类实现对应接口，FvpEngine 暴露接口 getter 而非 delegation 方法。便捷方法拆分到状态机和 mixin。

不涉及 UI 层改动、不涉及 open() 防御增强（Phase 11）、不涉及轨道管理统一（Phase 12）。

</domain>

<decisions>
## Implementation Decisions

### 状态模型（SVC-02）

- **D-01:** 使用 Phase 9 确定的 6 状态正交枚举（idle/opening/playing/paused/completed/error）+ 2 个独立 bool 标志（isSeeking/isBuffering）。路线图的"9 状态 ~40 条边"描述已过时，不采用。
- **D-02:** EngineStateMachine 为独立类，拥有 `ValueNotifier<MediaState>` + `ValueNotifier<bool> isSeeking` + `ValueNotifier<bool> isBuffering`。提供 `transitionTo(MediaState, String caller)` 方法。
- **D-03:** 非法状态转换处理：debug 模式 assert 报错（不崩溃），release 模式静默忽略。与当前 `_safeSetState` 行为一致。
- **D-04:** 删除现有 `MediaStateTransition` extension（`canTransitionTo`），用 EngineStateMachine 内部的 switch expression 穷举替代。
- **D-05:** 状态机的 `transitionTo` 返回 `bool`（成功/被忽略），调用方可选择是否检查结果。

### FvpEngine 瘦身（ENG-02）

- **D-06:** TrackManager 实现 TrackControl 接口，SubtitleConfigurator 实现 SubtitleConfig 接口，VideoEffectController 实现 VideoEffectControl 接口，D3D11Configurator 实现 RendererControl 接口。
- **D-07:** FvpEngine 暴露接口 getter：`TrackControl get trackControl => _trackManager`、`SubtitleConfig get subtitleConfig => _subtitleConfigurator` 等。删除所有 ~200 行 delegation 方法。调用者从 `engine.switchAudioTrack()` 改为 `engine.trackControl.switchAudioTrack()`。
- **D-08:** FvpEngine 最小核心保留：open/play/pause/stop/seekTo + 状态转换调用 + dispose + ValueNotifier 字段 + 工厂构造函数。
- **D-09:** `togglePlayPause` 移至 EngineStateMachine（依赖状态判断调 play 还是 pause）。
- **D-10:** `skipForward`/`skipBack`/`setRange` 移至 PlaybackControl 的 default mixin（纯计算 + 委托 seekTo）。
- **D-11:** `setVolume`/`setMute` 移至 VolumeController helper（实现 VolumeControl 接口或通过 engine getter 暴露）。
- **D-12:** `setPlaybackRate` 移至独立方法或保留在 FvpEngine（需要同时设置 player.playbackRate + ValueNotifier + positionPoller）。

### Claude's Discretion

- D-10 中 skipForward/skipBack/setRange 的 mixin 命名和位置由 Claude 决定
- D-11/D-12 中 volume/playbackRate 的具体归属由 Claude 决定（取决于 helper 接口设计）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/ROADMAP.md` — Phase 10 目标、成功标准、依赖关系
- `.planning/REQUIREMENTS.md` — ENG-02, SVC-02 需求定义
- `.planning/PROJECT.md` — 项目约束、已知问题、技术环境

### Phase 9 决策（必须了解）
- `.planning/phases/09-interface-decomposition/09-CONTEXT.md` — D-01~D-06 接口分解、D-16~D-19 MediaState 正交拆分、D-04 删除旧 mixin

### 架构文档
- `.planning/codebase/ARCHITECTURE.md` — 系统分层、Component Responsibilities、Pattern Overview
- `.planning/codebase/STRUCTURE.md` — lib/kernel/engine/ 目录结构

### 关键源文件（需阅读理解当前实现）
- `lib/kernel/engine/fvp_engine.dart` — 当前 632 行，6 helper 组合，目标瘦身核心
- `lib/kernel/engine/media_state.dart` — 6 值枚举 + MediaStateTransition extension（待删除）
- `lib/kernel/engine/engine_state.dart` — MediaEngine 接口定义（Phase 9 重构后）
- `lib/kernel/engine/track_manager.dart` — 待实现 TrackControl 接口
- `lib/kernel/engine/subtitle_configurator.dart` — 待实现 SubtitleConfig 接口
- `lib/kernel/engine/video_effect_controller.dart` — 待实现 VideoEffectControl 接口
- `lib/kernel/engine/d3d11_configurator.dart` — 待实现 RendererControl 接口
- `lib/kernel/engine/volume_controller.dart` — 待分析是否实现独立接口
- `lib/kernel/engine/position_poller.dart` — 轮询器生命周期与状态机交互
- `lib/kernel/engine/fvp_callback_handler.dart` — mdk 回调→状态机转换

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/kernel/engine/media_state.dart` — MediaStateTransition 的 switch expression 可直接迁移到 EngineStateMachine
- `lib/kernel/engine/fvp_engine.dart` — 工厂构造函数模式可复用（状态机作为新依赖注入）
- `lib/kernel/bridge/window_bridge.dart` — abstract class 接口模式参考（4 states + 7 commands）

### Established Patterns
- ValueNotifier + ValueListenableBuilder 状态管理 — 状态机的 notifier 遵循此模式
- sealed class 错误处理 — PlayerError 已在 Phase 9 统一
- 工厂构造函数 — FvpEngine 的 late field 消除模式可复用于状态机注入
- helper 组合模式 — 6 个 helper 已验证此架构可行

### Integration Points
- `lib/kernel/engine/fvp_callback_handler.dart` — mdk 回调中调用 `_safeSetState`，需改为调用 `stateMachine.transitionTo`
- `lib/kernel/engine/media_opener.dart` — open() 结果处理中调用状态转换
- `lib/features/player/services/state_monitor.dart` — 监听 `engine.state` ValueNotifier，需改为监听 `engine.stateMachine.state`
- `lib/ui/player/player_screen.dart` — 通过 EngineStateView 读取状态，getter 路径不变

</code_context>

<specifics>
## Specific Ideas

- "Helper 实现接口 + 组合暴露"是用户明确选择的最激进瘦身方案
- FvpEngine 的 API 表面会改变：从 `engine.switchAudioTrack()` 变为 `engine.trackControl.switchAudioTrack()`
- 状态机应可独立测试（不需要 fvp Player 实例）
- togglePlayPause 放在状态机中是因为它依赖状态读取

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-状态机提取 + 引擎瘦身*
*Context gathered: 2026-07-14*
