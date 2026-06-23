import 'package:flutter/foundation.dart';

import 'package:player_engine/player_engine.dart';

/// Hand-written Fake implementing PlayerEngine for testing.
///
/// No FFI imports, no platform plugins — runs purely in Dart.
/// Provides controllable behavior and call tracking for tests.
class FakeEngine implements PlayerEngine {
  bool _disposed = false;

  // ─── ValueNotifier fields (defaults match FvpEngine) ───

  @override
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);

  @override
  final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(
    MediaState.idle,
  );

  @override
  final ValueNotifier<int> position = ValueNotifier<int>(0);

  @override
  final ValueNotifier<int> duration = ValueNotifier<int>(0);

  @override
  final ValueNotifier<double> volume = ValueNotifier<double>(1.0);

  @override
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  @override
  final ValueNotifier<bool> isBuffering = ValueNotifier<bool>(false);

  @override
  final ValueNotifier<String> subtitleText = ValueNotifier<String>('');

  @override
  final ValueNotifier<int> buffered = ValueNotifier<int>(0);

  @override
  final ValueNotifier<double> aspectRatio = ValueNotifier<double>(16 / 9);

  @override
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  @override
  MediaErrorType errorType = MediaErrorType.unknown;

  @override
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);

  // ─── Internal state ───

  MediaInfo _mediaInfo = const MediaInfo();

  @override
  MediaInfo get mediaInfo => _mediaInfo;

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
  int _subtitleDelayMs = 0;
  // ─── Playback control ───

  @override
  Future<void> open(String path) async {
    if (_disposed) return;
    openCallCount++;
    openPaths.add(path);
    state.value = MediaState.loading;
    // Minimal async yield to allow test pump
    await Future<void>.value();
    if (_disposed) return;

    // Simulate open failure if configured
    if (failNextOpenWith != null) {
      final msg = failNextOpenWith!;
      failNextOpenWith = null; // one-shot
      state.value = MediaState.error;
      errorMessage.value = msg;
      return;
    }

    // Pre-configured _mediaInfo is used (caller sets it before open)
    duration.value = _mediaInfo.duration;
    position.value = 0;
    errorMessage.value = null;
    // Do NOT set state to idle — caller (play) sets it to playing
    // This matches FvpEngine behavior: open() does not set idle
  }

  @override
  void play() {
    if (_disposed) return;
    state.value = MediaState.playing;
    playCallCount++;
  }

  @override
  void pause() {
    if (_disposed) return;
    state.value = MediaState.paused;
    pauseCallCount++;
  }

  @override
  void stop() {
    if (_disposed) return;
    state.value = MediaState.stopped;
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
    if (state.value == MediaState.playing) {
      pause();
    } else if (state.value == MediaState.idle ||
        state.value == MediaState.paused ||
        state.value == MediaState.stopped ||
        state.value == MediaState.completed) {
      play();
    }
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

  // ─── Audio tracks ───

  @override
  List<AudioTrackInfo> getAudioTracks() => _mediaInfo.audioTracks;

  @override
  void switchAudioTrack(int trackIndex) {
    // no-op in fake
  }

  @override
  List<int> get activeAudioTracks => [];

  // ─── Subtitles ───

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

  @override
  int get subtitleDelay => _subtitleDelayMs;

  // ─── Equalizer ───

  @override
  void setEqualizer(String afFilter) {
    // no-op in fake
  }

  // ─── Video Processing ───

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

  // ─── D3D11 Performance ───

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
    _disposed = true;
    textureId.dispose();
    state.dispose();
    position.dispose();
    duration.dispose();
    volume.dispose();
    isMuted.dispose();
    isBuffering.dispose();
    subtitleText.dispose();
    buffered.dispose();
    aspectRatio.dispose();
    errorMessage.dispose();
    playbackSpeed.dispose();
  }

  // ─── Test helper methods ───

  /// Pre-configure what open() will expose.
  ///
  /// Call before open() to set duration, audio tracks, subtitle tracks.
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
    state.value = MediaState.error;
    errorMessage.value = message;
  }

  /// Simulate playback completed.
  void simulateCompleted() {
    state.value = MediaState.completed;
  }

  /// Simulate buffering state.
  void simulateBuffering(bool buffering) {
    isBuffering.value = buffering;
    if (buffering) {
      state.value = MediaState.buffering;
    }
  }
}
