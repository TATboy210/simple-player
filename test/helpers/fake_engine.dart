// ignore_for_file: overridden_fields — intentional: each engine needs independent ValueNotifier instances
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// Hand-written Fake implementing all ISP interfaces for testing.
///
/// No FFI imports, no platform plugins — runs purely in Dart.
/// Provides controllable behavior and call tracking for tests.
///
/// State/generation management is inlined (matching MediaKitEngine after
/// EngineStateMachine removal): self-owned notifiers + operation counter.
class FakeEngine implements MediaEngine, SubtitleConfig {
  bool _disposed = false;

  // ─── ValueNotifier fields ───

  @override
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);

  /// 主播放状态
  @override
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);

  /// 是否正在 seek
  @override
  final ValueNotifier<bool> isSeeking = ValueNotifier(false);

  /// 是否正在缓冲
  @override
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  // open/stop 请求计数器 — 与 MediaKitEngine._operationGeneration 同语义:
  // 每次请求递增, 使旧异步 continuation 过期 (不得发布状态/错误/清空新媒体).
  int _operationGeneration = 0;

  @override
  final ValueNotifier<int> position = ValueNotifier<int>(0);

  @override
  final ValueNotifier<int> duration = ValueNotifier<int>(0);

  @override
  final ValueNotifier<double> volume = ValueNotifier<double>(1.0);

  @override
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

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
  /// FakeEngine 原无此字段,加派生 notifier 供测试构造（供 ControlBar 测试构造）.
  /// late final + 构造函数 eager 初始化:避免 dispose 时未初始化访问崩溃.
  late final ValueNotifier<bool> isPlayingNotifier;

  /// 路径B Commit1:构造函数 eager 初始化 isPlayingNotifier + 监听 state.
  FakeEngine() {
    isPlayingNotifier = ValueNotifier<bool>(state.value == MediaState.playing);
    state.addListener(_onStateChanged);
  }

  /// state 变化时同步派生 isPlayingNotifier(playing→true,其他→false).
  void _onStateChanged() {
    isPlayingNotifier.value = state.value == MediaState.playing;
  }

  // ─── Internal state ───

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
    final gen = ++_operationGeneration;
    state.value = MediaState.opening;
    await (openGate?.future ?? Future<void>.value());
    // generation 不匹配或已 dispose 时，调用方不得提交过期请求的副作用。
    if (_disposed || gen != _operationGeneration) {
      return const OpenSuperseded();
    }

    final failureMessage = failNextOpenWith;
    if (failureMessage != null) {
      failNextOpenWith = null;
      final error = UnknownError(failureMessage);
      state.value = MediaState.error;
      lastError.value = error;
      return OpenError(error);
    }

    _mediaInfo = _configuredMediaInfo;
    _hasMedia = true;
    duration.value = _mediaInfo.duration;
    position.value = 0;
    lastError.value = null;
    // open 成功后回到 idle — 匹配 MediaKitEngine.open() 行为
    state.value = MediaState.idle;
    return OpenSuccess(_mediaInfo);
  }

  @override
  void play() {
    if (_disposed) return;
    // 空置态 (无媒体) play 无意义 — 与 MediaKitEngine.play 同款 guard:
    // state 保持 idle, 防止 UI 卸载空置页.
    if (!_hasMedia) return;
    state.value = MediaState.playing;
    playCallCount++;
  }

  @override
  void pause() {
    if (_disposed) return;
    if (state.value != MediaState.playing) return;
    state.value = MediaState.paused;
    pauseCallCount++;
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    // 使正在等待的 open 失效，并让本次 stop 可辨识为过期操作。
    final generation = ++_operationGeneration;
    final failureMessage = failNextStopWith;
    stopCallCount++;
    await (stopGate?.future ?? Future<void>.value());
    // 新 open/stop 已取得生命周期所有权时，旧 stop 不得发布任何状态。
    if (_disposed || generation != _operationGeneration) return;

    if (failureMessage != null) {
      failNextStopWith = null;
      // 停止失败时保留加载媒体，避免测试替身伪造安全的空置状态。
      lastError.value = UnknownError(failureMessage);
      state.value = MediaState.error;
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
    isSeeking.value = false;
    isBuffering.value = false;
    state.value = MediaState.idle;
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

  /// 切换播放/暂停 — 分派逻辑与 MediaKitEngine.togglePlayPause 同构.
  /// 计数保留: UI 路由契约测试依赖 togglePlayPauseCallCount.
  @override
  void togglePlayPause() {
    if (_disposed) return;
    togglePlayPauseCallCount++;
    final current = state.value;
    if (current == MediaState.playing) {
      pause();
    } else if (current == MediaState.idle ||
        current == MediaState.paused ||
        current == MediaState.completed) {
      play();
    }
    // opening/error — no-op
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
    if (_disposed) return; // double-dispose safety
    _disposed = true;
    // isPlayingNotifier 监听 state — 必须在 state.dispose() 之前
    // removeListener + dispose, 否则访问已释放的 state 抛 StateError.
    state.removeListener(_onStateChanged);
    isPlayingNotifier.dispose();
    state.dispose();
    isSeeking.dispose();
    isBuffering.dispose();
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
    state.value = MediaState.error;
    lastError.value = UnknownError(message);
  }

  /// Simulate playback completed.
  void simulateCompleted() {
    state.value = MediaState.completed;
  }

  /// Simulate buffering state — only sets transient flag, does not change main state.
  void simulateBuffering(bool buffering) {
    isBuffering.value = buffering;
  }
}
