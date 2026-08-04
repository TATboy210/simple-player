// ignore_for_file: overridden_fields — intentional: each engine needs independent ValueNotifier instances
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// Hand-written Fake implementing all ISP interfaces for testing.
///
/// No FFI imports, no platform plugins — runs purely in Dart.
/// Provides controllable behavior and call tracking for tests.
///
/// Uses EngineStateMachine for state management (matching MediaKitEngine).
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
  final ValueNotifier<PlayerError?> lastError = ValueNotifier<PlayerError?>(
    null,
  );

  @override
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);

  /// 派生 isPlaying(监听 state==playing) — 路径B Commit1:
  /// CenterGroup/PlayPauseButton 新签名需 `ValueListenable<bool>` isPlaying,
  /// FakeEngine 原无此字段,加派生 notifier 供测试构造(同 controls_overlay 模式).
  /// late final + 构造函数 eager 初始化:避免 dispose 时未初始化访问崩溃.
  late final ValueNotifier<bool> isPlayingNotifier;

  /// 是否正在 seek — 委托给 stateMachine
  @override
  ValueNotifier<bool> get isSeeking => stateMachine.isSeeking;

  /// 路径B Commit1:构造函数 eager 初始化 isPlayingNotifier + 监听 state.
  /// 访问 state 触发 stateMachine 惰性初始化(与 open/stop 等方法一致).
  FakeEngine() {
    isPlayingNotifier = ValueNotifier<bool>(state.value == MediaState.playing);
    state.addListener(_onStateChanged);
  }

  /// state 变化时同步派生 isPlayingNotifier(playing→true,其他→false).
  void _onStateChanged() {
    isPlayingNotifier.value = state.value == MediaState.playing;
  }

  // ─── Internal state ───

  /// open() generation 计数器 — 委托给 stateMachine (Phase 20 D5 单一真相源)
  ///
  /// FakeEngine 不再持有独立 _openGeneration，直接使用 stateMachine 的嵌入计数器。
  /// 与 MediaKitEngine 保持一致的 generation 守卫语义。

  MediaInfo _configuredMediaInfo = const MediaInfo();
  MediaInfo _mediaInfo = const MediaInfo();
  bool _hasMedia = false;

  @override
  MediaInfo get mediaInfo => _mediaInfo;

  @override
  bool get hasMedia => _hasMedia;

  @override
  int get subtitleDelay => _subtitleDelayMs;

  // ─── Call tracking for test introspection ───

  int openCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  int stopCallCount = 0;

  /// Exposes every play/pause intent, including states where the state machine
  /// cannot transition, so UI interaction tests can assert the tap was routed.
  int togglePlayPauseCallCount = 0;

  /// Records explicit skip requests independently from the resulting seek.
  /// This preserves the requested duration even when seek clamping applies.
  int skipBackCallCount = 0;
  int skipForwardCallCount = 0;
  int? lastSkipBackMs;
  int? lastSkipForwardMs;
  final List<String> openPaths = [];

  /// When set, the next open() will simulate an error after loading.
  String? failNextOpenWith;

  /// When set, the next stop() keeps the loaded media and reports an error.
  ///
  /// This mirrors [MediaKitEngine.stop]'s recoverable failure behavior so
  /// controller tests can verify that the visible title is not cleared early.
  String? failNextStopWith;

  /// When non-null, open waits for the test to release this deterministic gate.
  Completer<void>? openGate;

  /// When non-null, stop waits for the test to release this deterministic gate.
  ///
  /// This makes it possible to assert that a stale stop cannot overwrite a
  /// newer open request after its asynchronous backend operation completes.
  Completer<void>? stopGate;

  /// When true, seekTo() throws an Exception to simulate seek failure.
  bool seekToShouldThrow = false;

  // ─── Call tracking for new Phase 3 methods ───

  int seekToCallCount = 0;
  int? lastSeekToMs;
  int setExternalSubtitleCallCount = 0;
  String? lastExternalSubtitlePath;
  int setSubtitleDelayCallCount = 0;
  int setVolumeCallCount = 0;
  double? lastSetVolumeValue;
  int _subtitleDelayMs = 0;

  // ─── Interface getters (matching MediaKitEngine pattern) ───

  TrackControl get trackControl => this;

  SubtitleConfig get subtitleConfig => this;

  VideoEffectControl get videoEffectControl => this;

  RendererControl get rendererControl => this;

  VolumeControl get volumeControl => this;

  // ─── Playback control ───

  @override
  Future<OpenResult> open(String path) async {
    if (_disposed) return const OpenSuperseded();
    openCallCount++;
    openPaths.add(path);
    final gen = stateMachine.nextGeneration();
    stateMachine.transitionTo(MediaState.opening, 'fake.open');
    await (openGate?.future ?? Future<void>.value());
    // generation 不匹配或已 dispose 时，调用方不得提交过期请求的副作用。
    if (_disposed || gen != stateMachine.currentGeneration) {
      return const OpenSuperseded();
    }

    final failureMessage = failNextOpenWith;
    if (failureMessage != null) {
      failNextOpenWith = null;
      final error = UnknownError(failureMessage);
      stateMachine.transitionTo(MediaState.error, 'fake.open.error');
      lastError.value = error;
      return OpenError(error);
    }

    _mediaInfo = _configuredMediaInfo;
    _hasMedia = true;
    duration.value = _mediaInfo.duration;
    position.value = 0;
    lastError.value = null;
    // open 成功后回到 idle — 匹配 MediaKitEngine.open() 行为
    stateMachine.transitionTo(MediaState.idle, 'fake.open.success');
    return OpenSuccess(_mediaInfo);
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
  Future<void> stop() async {
    if (_disposed) return;
    // 使正在等待的 open 失效，并让本次 stop 可辨识为过期操作。
    final generation = stateMachine.nextGeneration();
    final failureMessage = failNextStopWith;
    stopCallCount++;
    await (stopGate?.future ?? Future<void>.value());
    // 新 open/stop 已取得生命周期所有权时，旧 stop 不得发布任何状态。
    if (_disposed || !stateMachine.isCurrent(generation)) return;

    if (failureMessage != null) {
      failNextStopWith = null;
      // 停止失败时保留加载媒体，避免测试替身伪造安全的空置状态。
      lastError.value = UnknownError(failureMessage);
      stateMachine.transitionTo(
        MediaState.error,
        'fake.stop.error',
        generation: generation,
      );
      return;
    }

    _hasMedia = false;
    _mediaInfo = const MediaInfo();
    position.value = 0;
    duration.value = 0;
    buffered.value = 0;
    aspectRatio.value = 0;
    subtitleText.value = '';
    lastError.value = null;
    stateMachine.isSeeking.value = false;
    stateMachine.isBuffering.value = false;
    stateMachine.transitionTo(
      MediaState.idle,
      'fake.stop',
      generation: generation,
    );
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_disposed) return;
    seekToCallCount++;
    lastSeekToMs = milliseconds;
    if (seekToShouldThrow) {
      seekToShouldThrow = false; // one-shot
      throw Exception('simulated seek failure');
    }
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
    togglePlayPauseCallCount++;
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
    if (_disposed) return;
    skipForwardCallCount++;
    lastSkipForwardMs = ms;
    seekTo((position.value + ms).clamp(0, duration.value));
  }

  @override
  void skipBack([int ms = 10000]) {
    if (_disposed) return;
    skipBackCallCount++;
    lastSkipBackMs = ms;
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
    // isPlayingNotifier 监听 state(stateMachine.state)— 必须在
    // stateMachine.dispose()(释放 state)之前 removeListener + dispose,
    // 否则访问已释放的 state 抛 StateError.
    state.removeListener(_onStateChanged);
    isPlayingNotifier.dispose();
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
    _configuredMediaInfo = MediaInfo(
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
