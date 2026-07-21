import 'engine_state_view.dart';
import 'playback_control.dart';
import 'track_control.dart';
import 'subtitle_config.dart';
import 'video_effect_control.dart';
import 'renderer_control.dart';
import 'volume_control.dart';

/// 播放引擎组合接口 — 服务层统一依赖类型.
///
/// Composite engine interface — unified dependency type for service layer.
///
/// Aggregates [EngineStateView] (read-only state) with 6 control ISP
/// interfaces (7 `implements` total) into a single type. Service layer
/// (PlaybackController, PlaybackStateManager, AutoAdvancePolicy, etc.)
/// accesses both state and control through this interface without
/// depending on concrete [FvpEngine].
///
/// Architecture:
///   - UI layer → EngineStateView (read-only state)
///   - Service layer → MediaEngine (state + control)
///   - FvpEngine implements MediaEngine (concrete implementation)
///
/// Design rationale: the legacy EngineState mixin mixed state and control
/// methods. After ISP decomposition, the service layer needs both — this
/// composite type bridges the gap without coupling to FvpEngine.
abstract class MediaEngine
    implements
        EngineStateView,
        PlaybackControl,
        TrackControl,
        SubtitleConfig,
        VideoEffectControl,
        RendererControl,
        VolumeControl {}
