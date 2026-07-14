# Phase 9: 接口分解 + 状态模型统一 - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

将 EngineState "god mixin" 按 ISP 原则拆分为独立 abstract class 接口（EngineStateView + PlaybackControl + 4 能力接口），统一 MediaErrorType + PlayerErrorCode 双错误体系为 sealed class PlayerError，将 PlaybackController 及其子模块从 feature 层迁移到 kernel 层，将 MediaState flat enum 拆为正交状态（主状态 + 瞬态标志）。

不涉及 UI 层改动、不涉及状态机转换守卫（Phase 10）、不涉及轨道管理统一（Phase 12）。

</domain>

<decisions>
## Implementation Decisions

### 接口分解（ENG-01）

- **D-01:** EngineStateView = abstract class，包含 12 个只读 getter（textureId/state/position/duration/volume/isMuted/isBuffering/subtitleText/buffered/aspectRatio/errorMessage/playbackSpeed）。UI 层通过 EngineStateView 引用引擎，只能读不能写。
- **D-02:** PlaybackControl = abstract class，包含核心操作方法（open/play/pause/stop/togglePlayPause/seekTo/setVolume/setMute/setPlaybackRate/setRange/skipForward/skipBack）。EngineStateView 是"仪表盘"，PlaybackControl 是"遥控器"。
- **D-03:** 4 个能力接口全部用 abstract class（与 EngineStateView 风格统一）：
  - `TrackControl` — getAudioTracks/switchAudioTrack/activeAudioTracks
  - `SubtitleConfig` — getSubtitleTracks/switchSubtitleTrack/toggleSubtitle/setExternalSubtitle/setSubtitleDelay/setEqualizer + subtitleText/subtitleDelay getter
  - `VideoEffectControl` — setVideoEffect/rotate/setAspectRatio/setDeinterlace + aspectRatio getter
  - `RendererControl` — setD3d11SyncEnabled/setHardwareDecoding
- **D-04:** 删除 EngineState mixin，一步到位。不保留 @Deprecated 过渡。FvpEngine 改为 `implements` 所有接口。
- **D-05:** 12 个 ValueNotifier 的 getter 全部集中在 EngineStateView，不分散到能力接口。能力接口只定义方法（和必要的状态 getter 如 subtitleText/aspectRatio）。
- **D-06:** 删除现有 3 个空壳 mixin（TrackControl/VideoEffects/RendererConfig），用新的 abstract class 替代。

### 错误模型统一（ENG-03）

- **D-07:** PlayerError = 嵌套层级 sealed class。第一层大类（FileError/CodecError/PlaybackError/NetworkError/UnknownError），每个大类可包含细分错误码。支持 exhaustive pattern matching。
- **D-08:** OpenResult 适配 PlayerError。OpenError(PlayerError error) 替代 OpenError(MediaErrorType type, String message)。
- **D-09:** EngineStateView 上新增 `ValueNotifier<PlayerError?> lastError`，替代现有的 errorMessage (ValueNotifier<String?>) 和 errorType getter。删除旧字段，完全替换。
- **D-10:** 删除 MediaErrorType enum 和 PlayerErrorCode enum，统一到 PlayerError sealed class 体系中。

### PlaybackController 迁移（SVC-01）

- **D-11:** 全部 5 个模块迁到 `kernel/services/`：PlaybackController + PlaybackNavigator + FileOperations + StateMonitor + SubtitleService。
- **D-12:** PlayerServices DI 容器也迁到 `kernel/`，作为 kernel 层的 DI 入口。
- **D-13:** 删除 PlaybackContract 接口，子模块直接依赖 PlaybackController。减少一层间接。
- **D-14:** 全局自动替换 import 路径（features/player/services/ → kernel/services/）。不保留旧路径 re-export。
- **D-15:** features/player/ 只保留 UI 文件（player_feature.dart, deferred_player_feature.dart），所有服务/逻辑归 kernel/。

### MediaState 枚举重构

- **D-16:** MediaState 拆为正交状态：主状态枚举（idle/opening/playing/paused/completed/error，6 个值）+ 两个瞬态标志 ValueNotifier<bool>（isSeeking/isBuffering）。
- **D-17:** EngineStateView 上暴露 3 个独立 getter：`ValueNotifier<MediaState> state`、`ValueNotifier<bool> isSeeking`、`ValueNotifier<bool> isBuffering`。
- **D-18:** 状态转换守卫（switch expression 穷举）留给 Phase 10。Phase 9 只拆状态模型。
- **D-19:** 删除现有 MediaState transition guard extension，Phase 10 用新状态机替代。

### Claude's Discretion
无 — 所有决策均用户明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/ROADMAP.md` — Phase 9 目标、成功标准、依赖关系
- `.planning/REQUIREMENTS.md` — ENG-01, ENG-03, SVC-01 需求定义
- `.planning/PROJECT.md` — 项目约束、已知问题、技术环境

### 架构文档
- `.planning/codebase/ARCHITECTURE.md` — 系统分层、Component Responsibilities、Pattern Overview
- `.planning/codebase/CONCERNS.md` — Features Layer 双职责问题、PlayerFeature 283 行 View+ViewModel 混合
- `.planning/codebase/STRUCTURE.md` — lib/kernel/ 目录结构

### 关键源文件（需阅读理解当前实现）
- `lib/kernel/engine/engine_state.dart` — 当前 EngineState "god mixin"（~35 方法 + 12 ValueNotifier）
- `lib/kernel/engine/fvp_engine.dart` — 唯一引擎实现（641 行），with EngineState + 3 空壳 mixin
- `lib/kernel/engine/media_error_type.dart` — MediaErrorType enum（5 值），待删除
- `lib/kernel/models/player_error.dart` — PlayerErrorCode（11 值）+ PlayerError class，当前死代码
- `lib/kernel/engine/open_result.dart` — OpenResult sealed class，需适配 PlayerError
- `lib/kernel/models/media_state.dart` — MediaState enum（9 值）+ transition guard extension
- `lib/features/player/services/playback_controller.dart` — 待迁移：Facade 编排器
- `lib/features/player/services/playback_navigator.dart` — 待迁移：曲目导航
- `lib/features/player/services/file_operations.dart` — 待迁移：文件操作
- `lib/features/player/services/state_monitor.dart` — 待迁移：状态监控
- `lib/features/player/services/subtitle_service.dart` — 待迁移：字幕服务
- `lib/features/player/player_services.dart` — 待迁移：DI 容器
- `lib/kernel/engine/track_control.dart` — 空壳 mixin，待替换为 abstract class
- `lib/kernel/engine/video_effects.dart` — 空壳 mixin，待替换为 abstract class
- `lib/kernel/engine/renderer_config.dart` — 空壳 mixin，待替换为 abstract class

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/kernel/engine/open_result.dart` — OpenResult sealed class 模式可复用于 PlayerError 设计
- `lib/kernel/bridge/window_state.dart` — 不可变状态 + copyWith 模式可参考
- `lib/kernel/engine/track_control.dart` / `video_effects.dart` / `renderer_config.dart` — 现有空壳 mixin 的方法签名可作为新接口的参考

### Established Patterns
- ValueNotifier + ValueListenableBuilder 状态管理 — 所有状态暴露遵循此模式
- sealed class 错误处理 — Phase 1 确认的 FullscreenResult (Success/Failure) 模式可复用
- abstract class 接口 — WindowBridge (4 states + 7 commands) 模式可参考
- 构造函数注入 — PlayerServices DI 模式可参考

### Integration Points
- `lib/features/player/player_feature.dart` — PlayerServices 创建点，import 路径需更新
- `lib/ui/player/player_screen.dart` — 通过 EngineStateView 引用引擎状态
- `lib/ui/player/controls_overlay.dart` — 接收 isFullscreen 等状态参数
- `lib/ui/dialogs/settings_dialog.dart` — 通过能力接口（TrackControl 等）检测引擎能力

</code_context>

<specifics>
## Specific Ideas

- 用户明确要求"一步到位"：删除旧 mixin/旧字段，不保留 @Deprecated 过渡
- 所有接口统一用 abstract class，不用 mixin（与 EngineStateView 风格一致）
- 错误模型用嵌套层级（大类 + 细分码），不是扁平 11 子类
- MediaState 用正交拆分（主状态 + 瞬态标志），不用组合枚举值

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 9-接口分解 + 状态模型统一*
*Context gathered: 2026-07-14*
