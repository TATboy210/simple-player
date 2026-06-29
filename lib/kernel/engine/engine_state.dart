import 'package:flutter/foundation.dart';

export 'media_error_type.dart';
export 'models/media_info.dart';
export 'media_state.dart';
export 'video_effect_type.dart';
export 'models/audio_track_info.dart';
export 'models/subtitle_track_info.dart';

import 'media_error_type.dart';
import 'models/media_info.dart';
import 'media_state.dart';
import 'models/audio_track_info.dart';
import 'models/subtitle_track_info.dart';
import 'video_effect_type.dart';

/// 播放器响应式状态 — ValueNotifier 集合
///
/// UI 层通过此 mixin 监听播放状态，不依赖具体引擎实现。
mixin EngineState {
  // ── 响应式状态 ──
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
  final ValueNotifier<int> position = ValueNotifier(0);
  final ValueNotifier<int> duration = ValueNotifier(0);
  final ValueNotifier<double> volume = ValueNotifier(1.0);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);
  final ValueNotifier<String> subtitleText = ValueNotifier('');
  final ValueNotifier<int> buffered = ValueNotifier(0);
  final ValueNotifier<double> aspectRatio = ValueNotifier(16 / 9);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);
  final ValueNotifier<double> playbackSpeed = ValueNotifier(1.0);

  // ── 只读属性 ──
  MediaErrorType get errorType;
  MediaInfo get mediaInfo;
  int get subtitleDelay;

  // ── 核心播放控制 ──
  Future<void> open(String path);
  void play();
  void pause();
  void stop();
  void togglePlayPause();
  Future<void> seekTo(int ms);
  void setVolume(double volume);
  void setMute(bool mute);
  void setPlaybackRate(double rate);
  void setRange({required int from, int to = -1});
  void skipForward([int ms = 10000]) => seekTo(position.value + ms);
  void skipBack([int ms = 10000]) => seekTo(position.value - ms);

  // ── 音轨/字幕 ──
  List<AudioTrackInfo> getAudioTracks();
  void switchAudioTrack(int trackId);
  List<int> get activeAudioTracks;
  List<SubtitleTrackInfo> getSubtitleTracks();
  void switchSubtitleTrack(int trackId);
  void toggleSubtitle();
  void setExternalSubtitle(String path);
  void setSubtitleDelay(int delay);
  void setEqualizer(String preset);

  // ── 视频效果 ──
  void setVideoEffect(VideoEffectType effectType, double value);
  void rotate(int degrees);
  void setAspectRatio(double ratio);
  void setDeinterlace(bool enable);

  // ── 生命周期 ──
  void dispose();
}
