import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'player_video_controls.dart';

/// 生产环境 [PlayerPort] — 包装 media_kit 真实 [Player]。
///
/// 路径B:控制栏直连 `player.stream`/`player.state`,绕过 [MediaEngine] 中间层。
/// 仅纯播放控制(playOrPause/seek/setRate)直写 player;volume/mute 写走
/// [MediaEngine](保 `_preMuteVolume` 语义),故本端口不暴露 setVolume。
///
/// stream + state 字段名完全镜像(见 media_kit `PlayerStream`/`PlayerState`
/// 源码,1.2.6),1:1 转发零转换。[Player] 的 playOrPause/seek/setRate 返回
/// `Future<void>`,适配器 void 语义用 [unawaited] fire-and-forget(对齐
/// `MediaKitEngine` 的 `unawaited(_player.play())` 模式)。
///
/// 本类无单元测试 — 构造需真实 [Player](FFI mdk.dll),headless 环境无法构造
/// (见 memory [[reference_mdk_dll_headless_test_failures]])。核心逻辑测试覆盖
/// 落在 [PlayerControlsState](用 FakePlayerControls),生产接线由 flutter analyze
/// + 实机验证。
class MediaKitPlayerPort implements PlayerPort {
  MediaKitPlayerPort(this._player);

  final Player _player;

  // ─── 8 个 stream(1:1 转发 player.stream.*)───
  @override
  Stream<bool> get playing => _player.stream.playing;
  @override
  Stream<bool> get buffering => _player.stream.buffering;
  @override
  Stream<bool> get completed => _player.stream.completed;
  @override
  Stream<Duration> get position => _player.stream.position;
  @override
  Stream<Duration> get duration => _player.stream.duration;
  @override
  Stream<Duration> get buffer => _player.stream.buffer;
  @override
  Stream<double> get volume => _player.stream.volume; // 0-100 media_kit 语义
  @override
  Stream<double> get rate => _player.stream.rate;

  // ─── 初始快照(1:1 转发 player.state.*)───
  @override
  bool get isPlayingNow => _player.state.playing;
  @override
  bool get isBufferingNow => _player.state.buffering;
  @override
  Duration get positionNow => _player.state.position;
  @override
  Duration get durationNow => _player.state.duration;
  @override
  double get volumeNow => _player.state.volume; // 0-100
  @override
  double get rateNow => _player.state.rate;

  // ─── 纯播放控制(直写 player,Future<void> → unawaited)───
  @override
  void playOrPause() => unawaited(_player.playOrPause());

  @override
  void seek(Duration position) => unawaited(_player.seek(position));

  @override
  void setRate(double rate) => unawaited(_player.setRate(rate));
}
