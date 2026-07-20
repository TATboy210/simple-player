// ignore_for_file: overridden_fields — intentional: each engine needs independent ValueNotifier instances
import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/lifecycle_phase.dart';

/// Hand-written Fake implementing all ISP interfaces for testing.
///
/// No FFI imports, no platform plugins — runs purely in Dart.
/// Provides controllable behavior and call tracking for tests.
///
/// Uses EngineStateMachine for state management (matching FvpEngine).
class FakeEngine implements MediaEngine, SubtitleConfig {
  bool _disposed = false;

  /// 状态机 — 管理 state/isSeeking/isBuffering
  ///
  /// onPlay/onPause 在构造时注入，使 togglePlayPause 可以正常工作
  @override
  late final EngineStateMachine stateMachine = EngineStateMachine(
    onPlay: play,
    onPause: pause,
  );

  // ─── ValueNotifier fields (delegated to stateMachine where applicable) ───

  @override
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);

  /// 主播放状态 — 委托给 stateMachine
  @override
  ValueNotifier<MediaState> get state => stateMachine.state;

  @override
  final ValueNotifier<int> position = ValueNotifier<int>(0);

  @override
  final ValueNotifier<int> duration = ValueNotifier<int>(0);

  @override
  final ValueNotifier<double> volume = ValueNotifier<double>(1.0);

  @override
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  /// 是否正在缓冲 — 委托给 stateMachine
  @override
  ValueNotifier<bool> get isBuffering => stateMachine.isBuffering;

  @override
  final ValueNotifier<String> subtitleText = ValueNotifier<String>('');

  @override
  final ValueNotifier<int> buffered = ValueNotifier<int>(0);

  @override
  final ValueNotifier<double> aspectRatio = ValueNotifier<double>(16 / 9);

  @override
  final ValueNotifier<PlayerError?> lastError = ValueNotifier<PlayerError?>(null);

  @override
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);

  /// 是否正在 seek — 委托给 stateMachine
  @override
  ValueNotifier<bool> get isSeeking => stateMachine.isSeeking;

  // ─── Internal state ───

  /// open() generation 计数器 — 委托给 stateMachine (Phase 20 D5 单一真相源)
  ///
  /// FakeEngine 不再持有独立 _openGeneration，直接使用 stateMachine 的嵌入计数器。
  /// 与 FvpEngine 保持一致的 generation 守卫语义。

  MediaInfo _mediaInfo = const MediaInfo();

  @override
  MediaInfo get mediaInfo => _mediaInfo;

  @override
  int get subtitleDelay => _subtitleDelayMs;

  // ─── Call tracking for test introspection ───

  int openCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  int stopCallCount = 0;
  final List<String> openPaths = [];

  /// When set, the next open() will simulate an error after loading.
  String? failNextOpenWith;

  // ─── Call tracking for new Phase 3 methods ───

  int seekToCallCount = 0;
  int? lastSeekToMs;
  int setExternalSubtitleCallCount = 0;
  String? lastExternalSubtitlePath;
  int setSubtitleDelayCallCount = 0;
  int setVolumeCallCount = 0;
  double? lastSetVolumeValue;
  int _subtitleDelayMs = 0;

  // ─── Interface getters (matching FvpEngine pattern) ───

  TrackControl get trackControl => this;

  SubtitleConfig get subtitleConfig => this;

  VideoEffectControl get videoEffectControl => this;

  RendererControl get rendererControl => this;

  VolumeControl get volumeControl => this;

  // ─── Playback control ───

  /// 生命周期阶段 — 委托给 stateMachine (Phase 20 D6 正交生命周期)
  ValueNotifier<LifecyclePhase> get lifecyclePhase => stateMachine.lifecyclePhase;

  /// 从 error 状态恢复 — 委托给 stateMachine (Phase 20 D7)
  void recover() {
    stateMachine.recover(lastError: lastError);
  }

  @override
  Future<void> open(String path) async {
    if (_disposed) return;
    openCallCount++;
    openPaths.add(path);
    final gen = stateMachine.nextGeneration();
    stateMachine.transitionTo(MediaState.opening, 'fake.open');
    await Future<void>.value();
    // generation 不匹配或已 dispose → 丢弃结果
    if (_disposed || gen != stateMachine.currentGeneration) return;

    if (failNextOpenWith != null) {
      final msg = failNextOpenWith!;
      failNextOpenWith = null;
      stateMachine.transitionTo(MediaState.error, 'fake.open.error');
      lastError.value = UnknownError(msg);
      return;
    }

    duration.value = _mediaInfo.duration;
    position.value = 0;
    lastError.value = null;
    // open 成功后回到 idle — 匹配 FvpEngine.open() 行为
    stateMachine.transitionTo(MediaState.idle, 'fake.open.success');
  }

  @override
  void play() {
    if (_disposed) return;
    stateMachine.transitionTo(MediaState.playing, 'fake.play');
    playCallCount++;
  }

  @override
  void pause() {
    if (_disposed) return;
    stateMachine.transitionTo(MediaState.paused, 'fake.pause');
    pauseCallCount++;
  }

  @override
  void stop() {
    if (_disposed) return;
    stateMachine.transitionTo(MediaState.idle, 'fake.stop');
    position.value = 0;
    stopCallCount++;
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_disposed) return;
    seekToCallCount++;
    lastSeekToMs = milliseconds;
    final clamped = milliseconds.clamp(0, duration.value);
    position.value = clamped;
  }

  @override
  void setVolume(double value) {
    if (_disposed) return;
    setVolumeCallCount++;
    lastSetVolumeValue = value;
    final clamped = value.clamp(0.0, 1.0);
    volume.value = clamped;
    if (clamped == 0) {
      isMuted.value = true;
    } else if (clamped > 0) {
      isMuted.value = false;
    }
  }

  @override
  void setMute(bool mute) {
    if (_disposed) return;
    isMuted.value = mute;
  }

  @override
  void togglePlayPause() {
    if (_disposed) return;
    stateMachine.togglePlayPause();
  }

  @override
  void setPlaybackRate(double rate) {
    if (_disposed) return;
    final clamped = rate.clamp(0.25, 4.0);
    playbackSpeed.value = clamped;
  }

  @override
  void skipForward([int ms = 10000]) {
    seekTo((position.value + ms).clamp(0, duration.value));
  }

  @override
  void skipBack([int ms = 10000]) {
    seekTo((position.value - ms).clamp(0, duration.value));
  }

  // ─── AB loop / range ───

  @override
  void setRange({required int from, int to = -1}) {
    // no-op in fake
  }

  // ─── Audio tracks (TrackControl) ───

  @override
  List<AudioTrackInfo> getAudioTracks() => _mediaInfo.audioTracks;

  @override
  void switchAudioTrack(int trackIndex) {
    // no-op in fake
  }

  @override
  List<int> get activeAudioTracks => [];

  // ─── Subtitles (SubtitleConfig) ───

  @override
  List<SubtitleTrackInfo> getSubtitleTracks() => _mediaInfo.subtitleTracks;

  @override
  void switchSubtitleTrack(int trackIndex) {
    // no-op in fake
  }

  @override
  void toggleSubtitle() {
    // no-op in fake
  }

  @override
  List<int> get activeSubtitleTracks => [];

  // ─── External subtitle ───

  @override
  void setExternalSubtitle(String path) {
    if (_disposed) return;
    setExternalSubtitleCallCount++;
    lastExternalSubtitlePath = path;
  }

  // ─── Subtitle delay ───

  @override
  void setSubtitleDelay(int milliseconds) {
    if (_disposed) return;
    setSubtitleDelayCallCount++;
    _subtitleDelayMs = milliseconds;
  }

  // ─── Equalizer ───

  @override
  void setEqualizer(String afFilter) {
    // no-op in fake
  }

  // ─── Video Processing (VideoEffectControl) ───

  int setVideoEffectCallCount = 0;
  VideoEffectType? lastVideoEffectType;
  double? lastVideoEffectValue;

  @override
  void setVideoEffect(VideoEffectType effect, double value) {
    if (_disposed) return;
    setVideoEffectCallCount++;
    lastVideoEffectType = effect;
    lastVideoEffectValue = value;
  }

  int rotateCallCount = 0;
  int? lastRotateDegree;

  @override
  void rotate(int degree) {
    if (_disposed) return;
    rotateCallCount++;
    lastRotateDegree = degree;
  }

  int setAspectRatioCallCount = 0;
  double? lastAspectRatioValue;

  @override
  void setAspectRatio(double ratio) {
    if (_disposed) return;
    setAspectRatioCallCount++;
    lastAspectRatioValue = ratio;
  }

  int setDeinterlaceCallCount = 0;
  bool? lastDeinterlaceValue;

  @override
  void setDeinterlace(bool enable) {
    if (_disposed) return;
    setDeinterlaceCallCount++;
    lastDeinterlaceValue = enable;
  }

  // ─── D3D11 Performance (RendererControl) ───

  int setD3d11SyncEnabledCallCount = 0;
  bool? lastD3d11SyncEnabled;

  @override
  void setD3d11SyncEnabled(bool enabled) {
    if (_disposed) return;
    setD3d11SyncEnabledCallCount++;
    lastD3d11SyncEnabled = enabled;
  }

  int setHardwareDecodingCallCount = 0;
  bool? lastHardwareDecodingEnabled;

  @override
  void setHardwareDecoding(bool enabled) {
    if (_disposed) return;
    setHardwareDecodingCallCount++;
    lastHardwareDecodingEnabled = enabled;
  }

  // ─── Lifecycle ───

  @override
  void dispose() {
    if (_disposed) return; // Phase 20 D8: double-dispose safety
    _disposed = true;
    stateMachine.dispose();
    textureId.dispose();
    position.dispose();
    duration.dispose();
    volume.dispose();
    isMuted.dispose();
    subtitleText.dispose();
    buffered.dispose();
    aspectRatio.dispose();
    lastError.dispose();
    playbackSpeed.dispose();
  }

  // ─── Test helper methods ───

  /// Pre-configure what open() will expose.
  void configureMedia({
    int durationMs = 60000,
    List<AudioTrackInfo>? audioTracks,
    List<SubtitleTrackInfo>? subtitleTracks,
  }) {
    _mediaInfo = MediaInfo(
      duration: durationMs,
      audioTracks: audioTracks ?? const [],
      subtitleTracks: subtitleTracks ?? const [],
    );
  }

  /// Simulate an error state.
  void simulateError(String message) {
    stateMachine.transitionTo(MediaState.error, 'fake.simulateError');
    lastError.value = UnknownError(message);
  }

  /// Simulate playback completed.
  void simulateCompleted() {
    stateMachine.transitionTo(MediaState.completed, 'fake.simulateCompleted');
  }

  /// Simulate buffering state — only sets transient flag, does not change main state.
  void simulateBuffering(bool buffering) {
    isBuffering.value = buffering;
  }
}
