import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'player_video_controls.dart';

/// 生产环境 [PlayerPort] — 包装 media_kit 真实 [Player]。
///
/// 控制栏展示状态直连 `player.stream`/`player.state`，基础播放命令由项目
/// `PlaybackController` 门面负责。本端口仅保留进度条 seek-hold 与倍速所需的
/// 直接 Player 操作；volume/mute 仍由 [MediaEngine] 维护项目语义。
///
/// stream + state 字段名完全镜像 media_kit 1.2.6 的 `PlayerStream` 与
/// `PlayerState`。`seek`/`setRate` 返回 `Future<void>`，适配器用 [unawaited]
/// 明确表达 fire-and-forget。
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

  // ─── 精细交互控制(直写 player,Future<void> → unawaited)───
  @override
  void seek(Duration position) => unawaited(_player.seek(position));

  @override
  void setRate(double rate) => unawaited(_player.setRate(rate));
}
