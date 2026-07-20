import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/diagnostics/diagnostics_bundle.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';
import 'package:simple_player_flutter/kernel/engine/media_engine.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/engine/models/audio_track_info.dart';
import 'package:simple_player_flutter/kernel/engine/models/media_info.dart';
import 'package:simple_player_flutter/kernel/engine/models/subtitle_track_info.dart';
import 'package:simple_player_flutter/kernel/engine/video_effect_type.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

/// 单一仲裁枚举 — 标识某能力路由到旧引擎还是新引擎 (D14/ADAPT-04).
///
/// Single arbiter enum: per-capability routing target. Phase 16 uses
/// `KernelMode.legacy` exclusively via `DelegationPolicy.all(KernelMode.legacy)`.
enum KernelMode { legacy, migrated }

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
  final KernelMode stateView;

  /// PlaybackControl 路由 (open/play/pause/seek 等控制方法).
  final KernelMode playback;

  /// TrackControl 路由 (音轨查询/切换).
  final KernelMode track;

  /// SubtitleConfig 路由 (字幕轨道/延迟/均衡器).
  final KernelMode subtitle;

  /// VideoEffectControl 路由 (亮度/旋转/宽高比/反交错).
  final KernelMode videoEffect;

  /// RendererControl 路由 (D3D11 同步/硬解).
  final KernelMode renderer;

  /// VolumeControl 路由 (音量/静音 — 单一路由, 见 KernelAdapter).
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

  @override
  ValueNotifier<int?> get textureId => _policy.stateView == KernelMode.legacy
      ? _legacy.textureId
      : _migrated.textureId;

  @override
  ValueNotifier<MediaState> get state =>
      _policy.stateView == KernelMode.legacy ? _legacy.state : _migrated.state;

  @override
  ValueNotifier<int> get position => _policy.stateView == KernelMode.legacy
      ? _legacy.position
      : _migrated.position;

  @override
  ValueNotifier<int> get duration => _policy.stateView == KernelMode.legacy
      ? _legacy.duration
      : _migrated.duration;

  @override
  ValueNotifier<bool> get isBuffering => _policy.stateView == KernelMode.legacy
      ? _legacy.isBuffering
      : _migrated.isBuffering;

  @override
  ValueNotifier<bool> get isSeeking => _policy.stateView == KernelMode.legacy
      ? _legacy.isSeeking
      : _migrated.isSeeking;

  @override
  ValueNotifier<String> get subtitleText =>
      _policy.stateView == KernelMode.legacy
      ? _legacy.subtitleText
      : _migrated.subtitleText;

  @override
  ValueNotifier<int> get buffered => _policy.stateView == KernelMode.legacy
      ? _legacy.buffered
      : _migrated.buffered;

  @override
  ValueNotifier<double> get aspectRatio =>
      _policy.stateView == KernelMode.legacy
      ? _legacy.aspectRatio
      : _migrated.aspectRatio;

  @override
  ValueNotifier<PlayerError?> get lastError =>
      _policy.stateView == KernelMode.legacy
      ? _legacy.lastError
      : _migrated.lastError;

  @override
  ValueNotifier<double> get playbackSpeed =>
      _policy.stateView == KernelMode.legacy
      ? _legacy.playbackSpeed
      : _migrated.playbackSpeed;

  @override
  MediaInfo get mediaInfo => _policy.stateView == KernelMode.legacy
      ? _legacy.mediaInfo
      : _migrated.mediaInfo;

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

  @override
  ValueNotifier<double> get volume =>
      _policy.volume == KernelMode.legacy ? _legacy.volume : _migrated.volume;

  @override
  ValueNotifier<bool> get isMuted =>
      _policy.volume == KernelMode.legacy ? _legacy.isMuted : _migrated.isMuted;

  @override
  void setVolume(double value) => _targetFor('setVolume').setVolume(value);

  @override
  void setMute(bool mute) => _targetFor('setMute').setMute(mute);

  // ===== PlaybackControl (10 methods via _policy.playback — excludes setVolume/setMute) =====

  // ===== PlaybackControl (10 methods via _targetFor per-method routing, Phase 20 D9) =====

  @override
  Future<void> open(String path) => _targetFor('open').open(path);

  @override
  void play() => _targetFor('play').play();

  @override
  void pause() => _targetFor('pause').pause();

  @override
  void stop() => _targetFor('stop').stop();

  @override
  void togglePlayPause() => _targetFor('togglePlayPause').togglePlayPause();

  @override
  Future<void> seekTo(int ms) => _targetFor('seekTo').seekTo(ms);

  @override
  void setPlaybackRate(double rate) => _targetFor('setPlaybackRate').setPlaybackRate(rate);

  @override
  void setRange({required int from, int to = -1}) =>
      _targetFor('setRange').setRange(from: from, to: to);

  @override
  void skipForward([int ms = 10000]) => _targetFor('skipForward').skipForward(ms);

  @override
  void skipBack([int ms = 10000]) => _targetFor('skipBack').skipBack(ms);

  // ===== TrackControl (3 members via _targetFor per-method routing, Phase 20 D9) =====
  @override
  List<AudioTrackInfo> getAudioTracks() => _targetFor('getAudioTracks').getAudioTracks();

  @override
  void switchAudioTrack(int trackId) => _targetFor('switchAudioTrack').switchAudioTrack(trackId);

  @override
  List<int> get activeAudioTracks => _policy.track == KernelMode.legacy
      ? _legacy.activeAudioTracks
      : _migrated.activeAudioTracks;

  // ===== SubtitleConfig (8 members via _targetFor per-method routing, Phase 20 D9) =====
  @override
  List<SubtitleTrackInfo> getSubtitleTracks() => _targetFor('getSubtitleTracks').getSubtitleTracks();

  @override
  void switchSubtitleTrack(int trackId) => _targetFor('switchSubtitleTrack').switchSubtitleTrack(trackId);

  @override
  void toggleSubtitle() => _targetFor('toggleSubtitle').toggleSubtitle();

  @override
  void setExternalSubtitle(String path) => _targetFor('setExternalSubtitle').setExternalSubtitle(path);

  @override
  void setSubtitleDelay(int delay) => _targetFor('setSubtitleDelay').setSubtitleDelay(delay);

  @override
  void setEqualizer(String preset) => _targetFor('setEqualizer').setEqualizer(preset);

  @override
  int get subtitleDelay => _policy.subtitle == KernelMode.legacy
      ? _legacy.subtitleDelay
      : _migrated.subtitleDelay;

  @override
  List<int> get activeSubtitleTracks => _policy.subtitle == KernelMode.legacy
      ? _legacy.activeSubtitleTracks
      : _migrated.activeSubtitleTracks;

  // ===== VideoEffectControl (4 members via _targetFor per-method routing, Phase 20 D9) =====
  @override
  void setVideoEffect(VideoEffectType effectType, double value) =>
      _targetFor('setVideoEffect').setVideoEffect(effectType, value);

  @override
  void rotate(int degrees) => _targetFor('rotate').rotate(degrees);

  @override
  void setAspectRatio(double ratio) => _targetFor('setAspectRatio').setAspectRatio(ratio);

  @override
  void setDeinterlace(bool enable) => _targetFor('setDeinterlace').setDeinterlace(enable);

  // ===== RendererControl (2 members via _targetFor per-method routing, Phase 20 D9) =====
  @override
  void setD3d11SyncEnabled(bool enabled) =>
      _targetFor('setD3d11SyncEnabled').setD3d11SyncEnabled(enabled);

  @override
  void setHardwareDecoding(bool enabled) =>
      _targetFor('setHardwareDecoding').setHardwareDecoding(enabled);
}
