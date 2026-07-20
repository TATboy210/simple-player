import 'dart:async';

import 'package:fvp/mdk.dart' as mdk;

import 'player_proxy.dart';

/// Adapter that wraps mdk.Player and implements [MdkPlayerLike].
///
/// Production implementation — delegates all calls to the real FFI-based
/// mdk.Player. Used by FvpEngine's default playerFactory.
///
/// For testing, use a pure Dart fake implementing [MdkPlayerLike] instead.
class MdkPlayerProxy implements MdkPlayerLike {
  MdkPlayerProxy(this._player);

  /// 创建默认的真实 mdk.Player 代理 — 供 FvpEngine 默认工厂使用
  factory MdkPlayerProxy.create() => MdkPlayerProxy(mdk.Player());

  final mdk.Player _player;

  /// Expose the underlying mdk.Player for helpers that still need direct access.
  mdk.Player get rawPlayer => _player;

  // ─── PlayerProxy ───

  @override
  set volume(double value) => _player.volume = value;

  @override
  set mute(bool value) => _player.mute = value;

  @override
  void setProperty(String key, String value) =>
      _player.setProperty(key, value);

  @override
  String? getProperty(String key) => _player.getProperty(key);

  // ─── Media lifecycle ───

  @override
  set media(String path) => _player.media = path;

  @override
  Future<int> prepare() => _player.prepare();

  @override
  dynamic get mediaInfo => _player.mediaInfo;

  @override
  Future<int> updateTexture() => _player.updateTexture();

  @override
  dynamic get textureId => _player.textureId;

  // ─── Track control ───

  @override
  set activeAudioTracks(List<int> tracks) =>
      _player.activeAudioTracks = tracks;

  @override
  List<int> get activeAudioTracks => _player.activeAudioTracks;

  @override
  set activeSubtitleTracks(List<int> tracks) =>
      _player.activeSubtitleTracks = tracks;

  @override
  List<int> get activeSubtitleTracks => _player.activeSubtitleTracks;

  // ─── Playback state ───

  /// 设置播放状态 — 将 MdkPlaybackState 映射到 mdk.PlaybackState
  @override
  set state(dynamic value) {
    if (value is MdkPlaybackState) {
      _player.state = switch (value) {
        MdkPlaybackState.stopped => mdk.PlaybackState.stopped,
        MdkPlaybackState.playing => mdk.PlaybackState.playing,
        MdkPlaybackState.paused => mdk.PlaybackState.paused,
      };
    } else if (value is mdk.PlaybackState) {
      _player.state = value;
    }
  }

  /// 获取当前播放状态 — 映射到 MdkPlaybackState
  @override
  dynamic get state {
    final mdkState = _player.state;
    return switch (mdkState) {
      mdk.PlaybackState.stopped => MdkPlaybackState.stopped,
      mdk.PlaybackState.playing => MdkPlaybackState.playing,
      mdk.PlaybackState.paused => MdkPlaybackState.paused,
      _ => MdkPlaybackState.stopped,
    };
  }

  /// mdk.Player 没有 start() 方法 — 使用 state setter 替代
  @override
  void start() => _player.state = mdk.PlaybackState.playing;

  /// mdk.Player 没有 stop() 方法 — 使用 state setter 替代
  @override
  void stop() => _player.state = mdk.PlaybackState.stopped;

  @override
  int get position => _player.position;

  @override
  int buffered() => _player.buffered();

  @override
  Future<void> seek({required int position, void Function(bool)? callback}) =>
      _player.seek(position: position);

  @override
  set playbackRate(double rate) => _player.playbackRate = rate;

  // ─── Buffer configuration ───

  @override
  void setBufferRange({required int min, required int max, required bool drop}) =>
      _player.setBufferRange(min: min, max: max, drop: drop);

  @override
  void setRange({required int from, int to = -1}) =>
      _player.setRange(from: from, to: to);

  // ─── Video properties ───

  @override
  void setVideoEffect(Object? effect, List<double> values) =>
      _player.setVideoEffect(effect as mdk.VideoEffect, values);

  @override
  void setAspectRatio(double ratio) => _player.setAspectRatio(ratio);

  @override
  void rotate(int degree) => _player.rotate(degree);

  // ─── Event streams — 映射 mdk 类型到 Dart 类型 ───

  @override
  Stream<dynamic> get onStateChanged {
    return _player.onStateChanged.map((event) {
      final mdkState = event.newValue;
      final dartState = switch (mdkState) {
        mdk.PlaybackState.stopped => MdkPlaybackState.stopped,
        mdk.PlaybackState.playing => MdkPlaybackState.playing,
        mdk.PlaybackState.paused => MdkPlaybackState.paused,
        _ => MdkPlaybackState.stopped,
      };
      return MdkStateChangedEvent(dartState);
    });
  }

  @override
  Stream<dynamic> get onMediaStatus {
    return _player.onMediaStatus.map((event) {
      final mdkStatus = event.newValue;
      int value = 0;
      if (mdkStatus.test(mdk.MediaStatus.buffering)) value |= 1;
      if (mdkStatus.test(mdk.MediaStatus.end)) value |= 8;
      return MdkMediaStatusEvent(MdkMediaStatus.fromValue(value));
    });
  }

  // ─── Lifecycle ───

  @override
  void dispose() => _player.dispose();
}
