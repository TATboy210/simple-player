import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/diagnostics/diagnostics_bundle.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';
import 'package:simple_player_flutter/kernel/engine/media_engine.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/engine/open_result.dart';
import 'package:simple_player_flutter/kernel/engine/models/audio_track_info.dart';
import 'package:simple_player_flutter/kernel/engine/models/media_info.dart';
import 'package:simple_player_flutter/kernel/engine/models/subtitle_track_info.dart';
import 'package:simple_player_flutter/kernel/engine/video_effect_type.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

/// 单一仲裁枚举 — 标识某能力路由到旧引擎还是新引擎 (D14/ADAPT-04).
///
/// Single arbiter enum: per-capability routing target. Phase 16 uses
/// `KernelMode.legacy` exclusively via `DelegationPolicy.all(KernelMode.legacy)`.
enum KernelMode {
  /// 旧引擎 (FvpEngine) — Phase 16 唯一活跃路由 (D14).
  ///
  /// Legacy engine (FvpEngine). Phase 16 exclusive active route.
  legacy,

  /// 新引擎 (NewFvpEngine) — Phase 20 迁移目标, Phase 16 未激活.
  ///
  /// New engine (NewFvpEngine). Phase 20 migration target; inactive in Phase 16.
  migrated,
}

/// 委托策略 — 7 个 final KernelMode 字段, 一一对应 MediaEngine 的 7 个 ISP 子接口 (D14).
///
/// Immutable per-capability routing policy. All 7 fields `final` (D15):
/// cutover rebuilds the adapter rather than flipping in place — structural
/// protection for Blocking Constraint #6 (identity-preserving ValueNotifier
/// forwarding; a mid-flight flip would detach UI listeners). `stateView` is a
/// plain field with no extra pin (D18): final+recreate already bounds mutation;
/// an extra pin would block Phase 20 partial cutover.
final class DelegationPolicy {
  const DelegationPolicy({
    required this.stateView,
    required this.playback,
    required this.track,
    required this.subtitle,
    required this.videoEffect,
    required this.renderer,
    required this.volume,
    this.migratedMethods = const {},
  });

  /// 全部 7 能力路由到同一 KernelMode — Phase 16 仅使用
  /// `DelegationPolicy.all(KernelMode.legacy)` (D14).
  const DelegationPolicy.all(KernelMode mode)
    : stateView = mode,
      playback = mode,
      track = mode,
      subtitle = mode,
      videoEffect = mode,
      renderer = mode,
      volume = mode,
      migratedMethods = const {};

  /// 按方法粒度路由 — Phase 20 D9 per-method DelegationPolicy
  ///
  /// Per-method routing granularity (Phase 20 D9).
  /// 包含已迁移到新引擎的方法名集合。空集表示全部走 legacy。
  /// 与 7 个 per-capability 字段共存：migratedMethods 优先级更高。
  final Set<String> migratedMethods;

  /// EngineStateView 路由 (只读状态视图: 11 ValueNotifier + mediaInfo).
  ///
  /// Routing target for read-only state view (11 ValueNotifiers + mediaInfo).
  final KernelMode stateView;

  /// PlaybackControl 路由 (open/play/pause/seek 等控制方法).
  ///
  /// Routing target for playback control (open/play/pause/seek/etc.).
  final KernelMode playback;

  /// TrackControl 路由 (音轨查询/切换).
  ///
  /// Routing target for audio track query and switching.
  final KernelMode track;

  /// SubtitleConfig 路由 (字幕轨道/延迟/均衡器).
  ///
  /// Routing target for subtitle tracks, delay, and equalizer.
  final KernelMode subtitle;

  /// VideoEffectControl 路由 (亮度/旋转/宽高比/反交错).
  ///
  /// Routing target for video effects (brightness/rotation/aspect/deinterlace).
  final KernelMode videoEffect;

  /// RendererControl 路由 (D3D11 同步/硬解).
  ///
  /// Routing target for renderer settings (D3D11 sync/hardware decoding).
  final KernelMode renderer;

  /// VolumeControl 路由 (音量/静音 — 单一路由, 见 KernelAdapter).
  ///
  /// Routing target for volume and mute (single route — see KernelAdapter).
  final KernelMode volume;
}

/// Strangler Fig seam — 临时路由层, 非永久架构层 (Phase 21 删除).
///
/// `KernelAdapter implements MediaEngine` 并将 7 个 ISP 子接口的约 44 个成员
/// 按 [_policy] 逐能力转发到 [_legacy] 或 [_migrated] 引擎. 组成:
///   - [_legacy]:   当前 FvpEngine (Phase 16 权威)
///   - [_migrated]:  未来 NewFvpEngine (Phase 20 切换目标)
///   - [_policy]:    DelegationPolicy — 逐能力路由仲裁
///   - [_bundle]:     DiagnosticsBundle — Phase 16 全 noop (D2/D3)
///
/// Phase 16 立场: 刻意死路由 — `DelegationPolicy.all(KernelMode.legacy)` 将
/// 100% 路由到 [_legacy], 行为与直接使用 FvpEngine 完全一致. 适配器不持有
/// 任何可变状态 (D17): 无计数器, 无迁移标志, 无缓存 — engine/policy/bundle
/// 均为注入依赖. The seam is collapsed/deleted in Phase 21 (SC4/D16).
///
/// P20 migration checklist (forward-looking, NOT implemented in Phase 16):
///   - openGeneration unified counter migrates from legacy into adapter/tracker (STATE-02, D23a)
///   - DiagnosticsBundle activation: swap noop slots to real slots (D3 dead-code -> live, D23b)
///   - DelegationPolicy field flip: all-legacy -> per-capability migrated (D14/STATE-06, D23c)
class KernelAdapter implements MediaEngine {
  /// 构造函数 — 旧/新引擎 + 委托策略 + 诊断 bundle (默认 noop, D12).
  /// Engine/policy/bundle are injected dependencies (not mutable state, D17).
  KernelAdapter({
    required MediaEngine legacy,
    required MediaEngine migrated,
    required DelegationPolicy policy,
    DiagnosticsBundle bundle = const DiagnosticsBundle.noop(),
  }) : _legacy = legacy,
       _migrated = migrated,
       _policy = policy,
       _bundle = bundle;

  final MediaEngine _legacy;
  final MediaEngine _migrated;
  final DelegationPolicy _policy;
  final DiagnosticsBundle _bundle;

  /// 按方法名路由 — Phase 20 D9 per-method DelegationPolicy
  ///
  /// Per-method routing: returns migrated engine if method is in migratedMethods,
  /// otherwise legacy engine. Enables method-by-method cutover.
  MediaEngine _targetFor(String method) =>
      _policy.migratedMethods.contains(method) ? _migrated : _legacy;

  /// 释放活动引擎并级联释放 bundle (D10). 路由由 _policy.stateView 决定,
  /// 无额外内部条件分支 (Phase 15 D8 — 无 _isMigrating 等内部标志分支).
  @override
  void dispose() {
    (_policy.stateView == KernelMode.legacy ? _legacy : _migrated).dispose();
    _bundle.dispose();
  }

  // ===== EngineStateView (11 ValueNotifier + mediaInfo via _policy.stateView) =====
  //
  // Identity-preserving forwarding (ADAPT-03 / Blocking Constraint #6): every
  // notifier getter returns the wrapped engine's OWN ValueNotifier instance —
  // never a fresh notifier wrapping `x.value`, which would detach all
  // ValueListenableBuilder listeners and freeze UI on cutover (D25 same() test,
  // Plan 16-04).

  /// 纹理 ID — 按 [_policy.stateView] 路由, 返回目标引擎的原始 ValueNotifier 实例.
  ///
  /// Texture ID. Routed by [_policy.stateView]; returns the target engine's
  /// own ValueNotifier instance (identity-preserving forwarding, ADAPT-03).
  @override
  ValueNotifier<int?> get textureId => _policy.stateView == KernelMode.legacy
      ? _legacy.textureId
      : _migrated.textureId;

  /// 播放状态 — identity-preserving 转发, 路由由 [_policy.stateView] 决定.
  ///
  /// Playback state. Identity-preserving forwarding; routed by [_policy.stateView].
  @override
  ValueNotifier<MediaState> get state =>
      _policy.stateView == KernelMode.legacy ? _legacy.state : _migrated.state;

  /// 当前播放位置 (毫秒) — identity-preserving 转发.
  ///
  /// Current playback position in milliseconds. Identity-preserving forwarding.
  @override
  ValueNotifier<int> get position => _policy.stateView == KernelMode.legacy
      ? _legacy.position
      : _migrated.position;

  /// 媒体总时长 (毫秒) — identity-preserving 转发.
  ///
  /// Total media duration in milliseconds. Identity-preserving forwarding.
  @override
  ValueNotifier<int> get duration => _policy.stateView == KernelMode.legacy
      ? _legacy.duration
      : _migrated.duration;

  /// 缓冲中标志 — identity-preserving 转发.
  ///
  /// Buffering flag. Identity-preserving forwarding.
  @override
  ValueNotifier<bool> get isBuffering => _policy.stateView == KernelMode.legacy
      ? _legacy.isBuffering
      : _migrated.isBuffering;

  /// 跳转中标志 — identity-preserving 转发.
  ///
  /// Seeking flag. Identity-preserving forwarding.
  @override
  ValueNotifier<bool> get isSeeking => _policy.stateView == KernelMode.legacy
      ? _legacy.isSeeking
      : _migrated.isSeeking;

  /// 当前字幕文本 — identity-preserving 转发.
  ///
  /// Current subtitle text. Identity-preserving forwarding.
  @override
  ValueNotifier<String> get subtitleText =>
      _policy.stateView == KernelMode.legacy
      ? _legacy.subtitleText
      : _migrated.subtitleText;

  /// 已缓冲位置 (毫秒) — identity-preserving 转发.
  ///
  /// Buffered position in milliseconds. Identity-preserving forwarding.
  @override
  ValueNotifier<int> get buffered => _policy.stateView == KernelMode.legacy
      ? _legacy.buffered
      : _migrated.buffered;

  /// 视频宽高比 — identity-preserving 转发.
  ///
  /// Video aspect ratio. Identity-preserving forwarding.
  @override
  ValueNotifier<double> get aspectRatio =>
      _policy.stateView == KernelMode.legacy
      ? _legacy.aspectRatio
      : _migrated.aspectRatio;

  /// 最近错误 — identity-preserving 转发.
  ///
  /// Most recent error. Identity-preserving forwarding.
  @override
  ValueNotifier<PlayerError?> get lastError =>
      _policy.stateView == KernelMode.legacy
      ? _legacy.lastError
      : _migrated.lastError;

  /// 播放速度倍率 — identity-preserving 转发.
  ///
  /// Playback speed multiplier. Identity-preserving forwarding.
  @override
  ValueNotifier<double> get playbackSpeed =>
      _policy.stateView == KernelMode.legacy
      ? _legacy.playbackSpeed
      : _migrated.playbackSpeed;

  /// 媒体元数据 — 路由由 [_policy.stateView] 决定.
  ///
  /// Media metadata. Routed by [_policy.stateView].
  @override
  MediaInfo get mediaInfo => _policy.stateView == KernelMode.legacy
      ? _legacy.mediaInfo
      : _migrated.mediaInfo;

  /// 状态机实例 — 路由由 [_policy.stateView] 决定.
  ///
  /// State machine instance. Routed by [_policy.stateView].
  @override
  EngineStateMachine get stateMachine => _policy.stateView == KernelMode.legacy
      ? _legacy.stateMachine
      : _migrated.stateMachine;

  // ===== VolumeControl (4 members via _policy.volume — single route) =====
  //
  // Single-route rationale (RESEARCH Pitfall 2 / Assumption A2):
  // PlaybackControl.setVolume/setMute and EngineStateView.volume/isMuted have
  // identical signatures to VolumeControl's 4 members. Dart interface
  // composition means ONE override satisfies all three parent-interface
  // declarations simultaneously; a second branch keyed on _policy.playback or
  // _policy.stateView would be unreachable dead code — route via _policy.volume.

  /// 当前音量 (0.0–1.0) — identity-preserving 转发, 路由由 [_policy.volume] 决定.
  ///
  /// Current volume (0.0–1.0). Identity-preserving forwarding; routed by [_policy.volume].
  @override
  ValueNotifier<double> get volume =>
      _policy.volume == KernelMode.legacy ? _legacy.volume : _migrated.volume;

  /// 静音标志 — identity-preserving 转发, 路由由 [_policy.volume] 决定.
  ///
  /// Mute flag. Identity-preserving forwarding; routed by [_policy.volume].
  @override
  ValueNotifier<bool> get isMuted =>
      _policy.volume == KernelMode.legacy ? _legacy.isMuted : _migrated.isMuted;

  /// 设置音量 — per-method 路由 via [_targetFor].
  ///
  /// Sets volume. Per-method routing via [_targetFor].
  @override
  void setVolume(double value) => _targetFor('setVolume').setVolume(value);

  /// 设置静音 — per-method 路由 via [_targetFor].
  ///
  /// Sets mute. Per-method routing via [_targetFor].
  @override
  void setMute(bool mute) => _targetFor('setMute').setMute(mute);

  // ===== PlaybackControl (10 methods via _policy.playback — excludes setVolume/setMute) =====

  // ===== PlaybackControl (10 methods via _targetFor per-method routing, Phase 20 D9) =====

  /// 打开媒体文件 — per-method 路由 via [_targetFor].
  ///
  /// Opens a media file and forwards its explicit result through [_targetFor].
  @override
  Future<OpenResult> open(String path) => _targetFor('open').open(path);

  /// 开始播放 — per-method 路由 via [_targetFor].
  ///
  /// Starts playback. Per-method routing via [_targetFor].
  @override
  void play() => _targetFor('play').play();

  /// 暂停播放 — per-method 路由 via [_targetFor].
  ///
  /// Pauses playback. Per-method routing via [_targetFor].
  @override
  void pause() => _targetFor('pause').pause();

  /// 停止播放 — per-method 路由 via [_targetFor].
  ///
  /// Stops playback. Per-method routing via [_targetFor].
  @override
  void stop() => _targetFor('stop').stop();

  /// 切换播放/暂停 — per-method 路由 via [_targetFor].
  ///
  /// Toggles play/pause. Per-method routing via [_targetFor].
  @override
  void togglePlayPause() => _targetFor('togglePlayPause').togglePlayPause();

  /// 跳转到指定位置 (毫秒) — per-method 路由 via [_targetFor].
  ///
  /// Seeks to the given position in milliseconds. Per-method routing via [_targetFor].
  @override
  Future<void> seekTo(int ms) => _targetFor('seekTo').seekTo(ms);

  /// 设置播放速度倍率 — per-method 路由 via [_targetFor].
  ///
  /// Sets playback speed multiplier. Per-method routing via [_targetFor].
  @override
  void setPlaybackRate(double rate) =>
      _targetFor('setPlaybackRate').setPlaybackRate(rate);

  /// 设置播放范围 — per-method 路由 via [_targetFor].
  ///
  /// Sets playback range. Per-method routing via [_targetFor].
  @override
  void setRange({required int from, int to = -1}) =>
      _targetFor('setRange').setRange(from: from, to: to);

  /// 快进 (默认 10 秒) — per-method 路由 via [_targetFor].
  ///
  /// Skips forward (default 10 seconds). Per-method routing via [_targetFor].
  @override
  void skipForward([int ms = 10000]) =>
      _targetFor('skipForward').skipForward(ms);

  /// 快退 (默认 10 秒) — per-method 路由 via [_targetFor].
  ///
  /// Skips back (default 10 seconds). Per-method routing via [_targetFor].
  @override
  void skipBack([int ms = 10000]) => _targetFor('skipBack').skipBack(ms);

  // ===== TrackControl (3 members via _targetFor per-method routing, Phase 20 D9) =====

  /// 获取可用音轨列表 — per-method 路由 via [_targetFor].
  ///
  /// Returns available audio tracks. Per-method routing via [_targetFor].
  @override
  List<AudioTrackInfo> getAudioTracks() =>
      _targetFor('getAudioTracks').getAudioTracks();

  /// 切换音轨 — per-method 路由 via [_targetFor].
  ///
  /// Switches audio track. Per-method routing via [_targetFor].
  @override
  void switchAudioTrack(int trackId) =>
      _targetFor('switchAudioTrack').switchAudioTrack(trackId);

  /// 活跃音轨 ID 列表 — 路由由 [_policy.track] 决定.
  ///
  /// Active audio track IDs. Routed by [_policy.track].
  @override
  List<int> get activeAudioTracks => _policy.track == KernelMode.legacy
      ? _legacy.activeAudioTracks
      : _migrated.activeAudioTracks;

  // ===== SubtitleConfig (8 members via _targetFor per-method routing, Phase 20 D9) =====

  /// 获取可用字幕轨道列表 — per-method 路由 via [_targetFor].
  ///
  /// Returns available subtitle tracks. Per-method routing via [_targetFor].
  @override
  List<SubtitleTrackInfo> getSubtitleTracks() =>
      _targetFor('getSubtitleTracks').getSubtitleTracks();

  /// 切换字幕轨道 — per-method 路由 via [_targetFor].
  ///
  /// Switches subtitle track. Per-method routing via [_targetFor].
  @override
  void switchSubtitleTrack(int trackId) =>
      _targetFor('switchSubtitleTrack').switchSubtitleTrack(trackId);

  /// 切换字幕开关 — per-method 路由 via [_targetFor].
  ///
  /// Toggles subtitle on/off. Per-method routing via [_targetFor].
  @override
  void toggleSubtitle() => _targetFor('toggleSubtitle').toggleSubtitle();

  /// 加载外挂字幕文件 — per-method 路由 via [_targetFor].
  ///
  /// Loads an external subtitle file. Per-method routing via [_targetFor].
  @override
  void setExternalSubtitle(String path) =>
      _targetFor('setExternalSubtitle').setExternalSubtitle(path);

  /// 设置字幕延迟 (毫秒) — per-method 路由 via [_targetFor].
  ///
  /// Sets subtitle delay in milliseconds. Per-method routing via [_targetFor].
  @override
  void setSubtitleDelay(int delay) =>
      _targetFor('setSubtitleDelay').setSubtitleDelay(delay);

  /// 设置均衡器预设 — per-method 路由 via [_targetFor].
  ///
  /// Sets equalizer preset. Per-method routing via [_targetFor].
  @override
  void setEqualizer(String preset) =>
      _targetFor('setEqualizer').setEqualizer(preset);

  /// 字幕延迟 (毫秒) — 路由由 [_policy.subtitle] 决定.
  ///
  /// Subtitle delay in milliseconds. Routed by [_policy.subtitle].
  @override
  int get subtitleDelay => _policy.subtitle == KernelMode.legacy
      ? _legacy.subtitleDelay
      : _migrated.subtitleDelay;

  /// 活跃字幕轨道 ID 列表 — 路由由 [_policy.subtitle] 决定.
  ///
  /// Active subtitle track IDs. Routed by [_policy.subtitle].
  @override
  List<int> get activeSubtitleTracks => _policy.subtitle == KernelMode.legacy
      ? _legacy.activeSubtitleTracks
      : _migrated.activeSubtitleTracks;

  // ===== VideoEffectControl (4 members via _targetFor per-method routing, Phase 20 D9) =====

  /// 设置视频效果 (亮度/对比度/饱和度等) — per-method 路由 via [_targetFor].
  ///
  /// Sets a video effect (brightness/contrast/saturation/etc.). Per-method routing via [_targetFor].
  @override
  void setVideoEffect(VideoEffectType effectType, double value) =>
      _targetFor('setVideoEffect').setVideoEffect(effectType, value);

  /// 旋转视频 (度数) — per-method 路由 via [_targetFor].
  ///
  /// Rotates video by given degrees. Per-method routing via [_targetFor].
  @override
  void rotate(int degrees) => _targetFor('rotate').rotate(degrees);

  /// 设置视频宽高比 — per-method 路由 via [_targetFor].
  ///
  /// Sets video aspect ratio. Per-method routing via [_targetFor].
  @override
  void setAspectRatio(double ratio) =>
      _targetFor('setAspectRatio').setAspectRatio(ratio);

  /// 启用/禁用反交错 — per-method 路由 via [_targetFor].
  ///
  /// Enables/disables deinterlacing. Per-method routing via [_targetFor].
  @override
  void setDeinterlace(bool enable) =>
      _targetFor('setDeinterlace').setDeinterlace(enable);

  // ===== RendererControl (2 members via _targetFor per-method routing, Phase 20 D9) =====

  /// 启用/禁用 D3D11 同步 — per-method 路由 via [_targetFor].
  ///
  /// Enables/disables D3D11 sync. Per-method routing via [_targetFor].
  @override
  void setD3d11SyncEnabled(bool enabled) =>
      _targetFor('setD3d11SyncEnabled').setD3d11SyncEnabled(enabled);

  /// 启用/禁用硬件解码 — per-method 路由 via [_targetFor].
  ///
  /// Enables/disables hardware decoding. Per-method routing via [_targetFor].
  @override
  void setHardwareDecoding(bool enabled) =>
      _targetFor('setHardwareDecoding').setHardwareDecoding(enabled);
}
