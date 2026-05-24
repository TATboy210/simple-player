import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../src/rust/api/events.dart';
import '../../src/rust/api/player.dart';
import '../models/media_error_type.dart';
import '../models/media_state.dart';
import '../models/media_info.dart';
import '../models/video_effect_type.dart';
import 'media_engine.dart';

/// libmpv engine implementation via Rust + flutter_rust_bridge.
/// Replaces FvpEngine (fvp/MDK) with libmpv for cross-platform playback.
/// Event-driven: mpv property changes pushed via Stream<PlayerEvent>.
class MpvEngine implements MediaEngine {
  MpvPlayer? _player;
  StreamSubscription<PlayerEvent>? _eventSub;
  bool _disposed = false;

  // ─── ValueNotifier 实现 ───

  @override
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);

  @override
  final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(MediaState.idle);

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
  final ValueNotifier<double> aspectRatio = ValueNotifier<double>(16.0 / 9.0);

  @override
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  @override
  MediaErrorType get errorType => MediaErrorType.unknown;

  @override
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);

  @override
  MediaInfo get mediaInfo => const MediaInfo();

  // ─── 播放控制 ───

  @override
  Future<void> open(String path) async {
    if (_disposed) return;
    _player ??= await MpvPlayer.newInstance();
    state.value = MediaState.loading;
    errorMessage.value = null;
    await _player!.loadFile(path: path);
    _startListening();
  }

  void _startListening() {
    _eventSub?.cancel();
    startEventLoop().then((stream) {
      _eventSub = stream.listen(_handleEvent, onError: (e) {
        debugPrint('[MpvEngine] stream error: $e');
        errorMessage.value = e.toString();
        state.value = MediaState.error;
      });
    });
  }

  void _handleEvent(PlayerEvent event) {
    if (_disposed) return;
    switch (event) {
      case PlayerEvent_Position(:final ms):
        position.value = ms.toInt();
      case PlayerEvent_Duration(:final ms):
        duration.value = ms.toInt();
      case PlayerEvent_Paused(:final paused):
        state.value = paused ? MediaState.paused : MediaState.playing;
      case PlayerEvent_State(:final state):
        switch (state) {
          case 'loading':
            this.state.value = MediaState.loading;
          case 'playing':
            this.state.value = MediaState.playing;
          case 'ended':
            this.state.value = MediaState.idle;
          case 'stopped':
            this.state.value = MediaState.idle;
        }
      case PlayerEvent_Error(:final message):
        errorMessage.value = message;
        state.value = MediaState.error;
    }
  }

  @override
  void play() {
    unawaited(_player?.play());
  }

  @override
  void pause() {
    unawaited(_player?.pause());
  }

  @override
  void stop() {
    unawaited(_player?.stop());
    position.value = 0;
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_player == null) return;
    await _player!.seek(positionMs: milliseconds);
  }

  @override
  void setVolume(double value) {
    volume.value = value.clamp(0.0, 1.0);
    unawaited(_player?.setVolume(vol: value));
  }

  @override
  void setMute(bool mute) {
    isMuted.value = mute;
    unawaited(_player?.setMute(muted: mute));
  }

  @override
  void togglePlayPause() {
    unawaited(_player?.togglePause());
  }

  @override
  void setPlaybackRate(double rate) {
    final clamped = rate.clamp(0.25, 4.0);
    playbackSpeed.value = clamped;
    unawaited(_player?.setSpeed(speed: clamped));
  }

  @override
  void setRange({required int from, int to = -1}) {
    // TODO: mpv ab-loop property
  }

  @override
  List<AudioTrackInfo> getAudioTracks() => [];

  @override
  void switchAudioTrack(int trackIndex) {}

  @override
  List<int> get activeAudioTracks => [];

  @override
  List<SubtitleTrackInfo> getSubtitleTracks() => [];

  @override
  void switchSubtitleTrack(int trackIndex) {}

  @override
  void toggleSubtitle() {}

  @override
  void setExternalSubtitle(String path) {}

  @override
  void setSubtitleDelay(int milliseconds) {}

  @override
  int get subtitleDelay => 0;

  @override
  void setEqualizer(String afFilter) {}

  @override
  void setVideoEffect(VideoEffectType effect, double value) {}

  @override
  void rotate(int degree) {}

  @override
  void setAspectRatio(double ratio) {}

  @override
  void setDeinterlace(bool enable) {}

  @override
  void skipForward([int seconds = 10]) {
    seekTo((position.value + seconds * 1000).clamp(0, duration.value));
  }

  @override
  void skipBack([int seconds = 10]) {
    seekTo((position.value - seconds * 1000).clamp(0, duration.value));
  }

  @override
  void dispose() {
    _disposed = true;
    _eventSub?.cancel();
    _player?.stop();
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
}
