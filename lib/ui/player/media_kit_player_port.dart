import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// media_kit [Player] 的可测试端口 — 抽象出 `PlayerControlsState` 所需的
/// stream、快照与精细交互控制。
///
/// 控制栏展示状态直连 `player.stream`，避免引擎镜像状态带来的帧间延迟；基础
/// 播放命令则经 [PlayerActions] 统一进入项目播放控制门面。本端口只保留
/// 进度条 seek-hold 与倍速所需的直接 Player 操作。
abstract interface class PlayerPort {
  /// 播放状态流
  Stream<bool> get playing;
  Stream<bool> get buffering;

  /// 位置流(Duration)
  Stream<Duration> get position;
  Stream<Duration> get duration;

  /// 音量(0-100 media_kit 语义)/倍速流
  Stream<double> get volume;
  Stream<double> get rate;

  /// 初始快照(init 时读一次,避免首帧空白)
  bool get isPlayingNow;
  bool get isBufferingNow;
  Duration get positionNow;
  Duration get durationNow;
  double get volumeNow; // 0-100
  double get rateNow;

  /// 进度条与倍速的精细交互仍直达 player。
  void seek(Duration position);
  void setRate(double rate);
}

/// 当前 media_kit `Video.controls` 实例的可测试端口。
///
/// 生产实现始终包装当前 route 的 [VideoState]，确保全屏切换与字幕 padding 不会
/// 错发到窗口态的旧实例；测试实现可使用纯 Dart [PlayerPort]，避免加载 libmpv。
abstract interface class VideoControlsPort {
  /// 当前视频实例共享的播放器状态与精细交互端口。
  PlayerPort get player;

  /// 当前 controls 是否位于 media_kit fullscreen route。
  bool get isFullscreen;

  /// 包装的 VideoState 是否仍可安全接收字幕 padding 更新。
  bool get isMounted;

  /// 当前字幕配置的基础 padding。
  EdgeInsets get subtitlePadding;

  /// 使用当前 VideoState 切换 media_kit 原生全屏 route。
  void toggleFullscreen();

  /// 使用当前 VideoState 退出 media_kit 原生全屏 route。
  void exitFullscreen();

  /// 更新当前 VideoState 的字幕安全区。
  void setSubtitleViewPadding(EdgeInsets padding);
}

/// 将 media_kit [VideoState] 适配为 [VideoControlsPort]。
final class MediaKitVideoControlsPort implements VideoControlsPort {
  MediaKitVideoControlsPort(this._state)
    : player = MediaKitPlayerPort(_state.widget.controller.player);

  final VideoState _state;

  @override
  final PlayerPort player;

  @override
  bool get isFullscreen => _state.isFullscreen();

  @override
  bool get isMounted => _state.mounted;

  @override
  EdgeInsets get subtitlePadding =>
      _state.widget.subtitleViewConfiguration.padding;

  @override
  void toggleFullscreen() => _state.toggleFullscreen();

  @override
  void exitFullscreen() => _state.exitFullscreen();

  @override
  void setSubtitleViewPadding(EdgeInsets padding) =>
      _state.setSubtitleViewPadding(padding);
}

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
/// 本类无单元测试 — 构造需真实 [Player](FFI libmpv),headless 环境无法构造
/// (见 memory [[reference_mdk_dll_headless_test_failures]])。核心逻辑测试覆盖
/// 落在 PlayerControlsState(用 FakePlayerControls),生产接线由 flutter analyze
/// + 实机验证。
class MediaKitPlayerPort implements PlayerPort {
  MediaKitPlayerPort(this._player);

  final Player _player;

  // ─── 6 个 stream(1:1 转发 player.stream.*)───
  @override
  Stream<bool> get playing => _player.stream.playing;
  @override
  Stream<bool> get buffering => _player.stream.buffering;
  @override
  Stream<Duration> get position => _player.stream.position;
  @override
  Stream<Duration> get duration => _player.stream.duration;
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
