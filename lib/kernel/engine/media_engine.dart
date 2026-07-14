import 'engine_state_view.dart';
import 'playback_control.dart';
import 'track_control.dart';
import 'subtitle_config.dart';
import 'video_effect_control.dart';
import 'renderer_control.dart';

/// 播放引擎组合接口 — 服务层统一依赖类型
///
/// 将 6 个 ISP 接口聚合为单一类型，服务层（PlaybackController、StateMonitor 等）
/// 通过此接口同时访问状态和控制方法，无需依赖具体实现类。
///
/// 架构位置：
///   - UI 层 → EngineStateView（只读状态）
///   - 服务层 → MediaEngine（状态 + 控制）
///   - FvpEngine implements MediaEngine（具体实现）
///
/// 设计说明：
///   旧 EngineState mixin 混合了状态和控制方法。ISP 拆分后，
///   服务层需要同时访问两者。此接口作为组合类型，避免服务层
///   依赖具体 FvpEngine 实现。
abstract class MediaEngine
    implements
        EngineStateView,
        PlaybackControl,
        TrackControl,
        SubtitleConfig,
        VideoEffectControl,
        RendererControl {}
