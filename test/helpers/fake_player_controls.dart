import 'dart:async';

import 'package:simple_player_flutter/ui/player/player_video_controls.dart';

/// 路径B 测试 fake — 实现 [PlayerPort] 用纯 Dart [StreamController.broadcast]。
///
/// 模拟 media_kit [Player] 的 stream + state 快照 + 精细交互调用计数，无 FFI
/// 依赖。基础播放命令已收口到 PlaybackController，不属于本 fake 的职责。
class FakePlayerControls implements PlayerPort {
  FakePlayerControls({
    this.isPlayingNow = false,
    this.isBufferingNow = false,
    this.positionNow = Duration.zero,
    this.durationNow = Duration.zero,
    this.volumeNow = 100.0,
    this.rateNow = 1.0,
  });

  // ─── 8 个 broadcast stream(模拟 player.stream.*)───
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _buffering = StreamController<bool>.broadcast();
  final StreamController<bool> _completed = StreamController<bool>.broadcast();
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _buffer =
      StreamController<Duration>.broadcast();
  final StreamController<double> _volume = StreamController<double>.broadcast();
  final StreamController<double> _rate = StreamController<double>.broadcast();

  @override
  Stream<bool> get playing {
    streamListenAccessCount++;
    return _playing.stream;
  }

  @override
  Stream<bool> get buffering {
    streamListenAccessCount++;
    return _buffering.stream;
  }

  @override
  Stream<bool> get completed {
    streamListenAccessCount++;
    return _completed.stream;
  }

  @override
  Stream<Duration> get position {
    streamListenAccessCount++;
    return _position.stream;
  }

  @override
  Stream<Duration> get duration {
    streamListenAccessCount++;
    return _duration.stream;
  }

  @override
  Stream<Duration> get buffer {
    streamListenAccessCount++;
    return _buffer.stream;
  }

  @override
  Stream<double> get volume {
    streamListenAccessCount++;
    return _volume.stream;
  }

  @override
  Stream<double> get rate {
    streamListenAccessCount++;
    return _rate.stream;
  }

  /// 记录 [PlayerControlsState] 对各 stream 建立监听的次数。
  ///
  /// 生命周期 reparent 不应重新初始化 controls state；因此该计数在多次
  /// deactivate/activate 后应保持不变，source replacement 后新 port 应只增加一轮。
  int streamListenAccessCount = 0;

  /// 暴露订阅状态，验证 source replacement/dispose 是否真正解绑 stream。
  bool get hasListeners =>
      _playing.hasListener ||
      _buffering.hasListener ||
      _completed.hasListener ||
      _position.hasListener ||
      _duration.hasListener ||
      _buffer.hasListener ||
      _volume.hasListener ||
      _rate.hasListener;

  // ─── 初始快照(非 final,测试可改)───
  @override
  bool isPlayingNow;
  @override
  bool isBufferingNow;
  @override
  Duration positionNow;
  @override
  Duration durationNow;
  @override
  double volumeNow; // 0-100 media_kit 语义
  @override
  double rateNow;

  // ─── 精细交互调用计数 ───
  int seekCallCount = 0;
  int setRateCallCount = 0;
  Duration? lastSeekPosition;
  double? lastRate;

  @override
  void seek(Duration position) {
    seekCallCount++;
    lastSeekPosition = position;
  }

  @override
  void setRate(double rate) {
    setRateCallCount++;
    lastRate = rate;
  }

  // ─── 测试 helper:推送 stream 事件(模拟 player.stream.* add)───
  void emitPlaying(bool v) => _playing.add(v);
  void emitBuffering(bool v) => _buffering.add(v);
  void emitCompleted(bool v) => _completed.add(v);
  void emitPosition(Duration d) => _position.add(d);
  void emitDuration(Duration d) => _duration.add(d);
  void emitBuffer(Duration d) => _buffer.add(d);
  void emitVolume(double v) => _volume.add(v); // 0-100
  void emitRate(double v) => _rate.add(v);

  void dispose() {
    _playing.close();
    _buffering.close();
    _completed.close();
    _position.close();
    _duration.close();
    _buffer.close();
    _volume.close();
    _rate.close();
  }
}
