import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mpv_kit_video/mpv_kit_video.dart';

import '../../kernel/engine/mpv_kit_engine.dart';
import '../../kernel/window_bridge/window_bridge.dart';

/// mpv_kit [Player] 的可测试端口 — 抽象出 `PlayerControlsState` 所需的
/// stream、快照与精细交互控制。
///
/// 控制栏展示状态直连 Player 的 MpvState 流，避免引擎镜像状态带来的帧间延迟；基础
/// 播放命令则经 [PlayerActions] 统一进入项目播放控制门面。本端口只保留
/// 进度条 seek-hold 与倍速所需的直接 Player 操作。
abstract interface class PlayerPort {
  /// 播放状态流
  Stream<bool> get playing;
  Stream<bool> get buffering;

  /// 位置流(Duration)
  Stream<Duration> get position;
  Stream<Duration> get duration;

  /// 音量(0-100 mpv 语义)/倍速流
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

/// 视频控制层的可测试端口 (全屏状态 + 字幕避让)。
///
/// 生产实现 [MpvKitVideoControlsPort] 由窗口模式驱动全屏、由 mpv 属性实现字幕
/// 避让；测试实现可使用纯 Dart [PlayerPort]，避免加载 libmpv。
abstract interface class VideoControlsPort {
  /// 当前视频实例共享的播放器状态与精细交互端口。
  PlayerPort get player;

  /// 当前是否处于全屏窗口模式。
  bool get isFullscreen;

  /// 视频面是否仍可安全接收字幕避让更新。
  bool get isMounted;

  /// 当前字幕配置的基础 padding。
  EdgeInsets get subtitlePadding;

  /// 全屏切换的视频面侧钩子 (原生全屏由窗口模式驱动, 生产实现为 no-op)。
  void toggleFullscreen();

  /// 退出全屏的视频面侧钩子 (同上)。
  void exitFullscreen();

  /// 更新字幕安全区 (生产实现换算为 mpv sub-margin-y)。
  void setSubtitleViewPadding(EdgeInsets padding);
}

/// 生产 [VideoControlsPort] — mpv_kit 视频面没有 media_kit 的全屏 route 与
/// SubtitleView, 两项能力改由宿主提供:
/// - 全屏: [WindowMode] 驱动原生全屏 (WindowModeCoordinator), 控制层经
///   `actions.onToggleFullscreen` 切模式, 本端口的 toggle/exit 无事可做;
/// - 字幕避让: 字幕由 libass 画进纹理, padding 换算为 mpv `sub-margin-y`.
final class MpvKitVideoControlsPort implements VideoControlsPort {
  MpvKitVideoControlsPort({
    required MpvKitEngine engine,
    required this._windowMode,
    required this._surfaceHeight,
  }) : _engine = engine,
       player = MpvKitPlayerPort(engine.player);

  final MpvKitEngine _engine;
  final ValueListenable<WindowMode> _windowMode;

  /// 视频面当前逻辑高度 — sub-margin-y 换算基准 (宿主 LayoutBuilder 记录).
  final double Function() _surfaceHeight;

  @override
  final PlayerPort player;

  @override
  bool get isFullscreen => _windowMode.value.isFullscreen;

  @override
  bool get isMounted => true;

  /// 基础 padding 为零 — mpv 自身的默认边距 (22) 由引擎叠加.
  @override
  EdgeInsets get subtitlePadding => EdgeInsets.zero;

  @override
  void toggleFullscreen() {}

  @override
  void exitFullscreen() {}

  @override
  void setSubtitleViewPadding(EdgeInsets padding) =>
      _engine.setSubtitleBottomInset(padding.bottom, _surfaceHeight());
}

/// 生产环境 [PlayerPort] — 包装 mpv_kit 真实 [Player].
///
/// 流来自 [MpvState.stream] (不回放当前值), 快照来自 [MpvState.value];
/// `playing` 取 `!paused`. 基础播放命令由 PlaybackController 门面负责, 本端口
/// 只保留进度条 seek-hold 与倍速所需的直接操作.
class MpvKitPlayerPort implements PlayerPort {
  MpvKitPlayerPort(this._player);

  final Player _player;

  @override
  Stream<bool> get playing => _player.paused.stream.map((p) => !p);
  @override
  Stream<bool> get buffering => _player.buffering.stream;
  @override
  Stream<Duration> get position => _player.position.stream;
  @override
  Stream<Duration> get duration => _player.duration.stream;
  @override
  Stream<double> get volume => _player.volume.stream; // 0-100
  @override
  Stream<double> get rate => _player.speed.stream;

  @override
  bool get isPlayingNow => !_player.paused.value;
  @override
  bool get isBufferingNow => _player.buffering.value;
  @override
  Duration get positionNow => _player.position.value;
  @override
  Duration get durationNow => _player.duration.value;
  @override
  double get volumeNow => _player.volume.value;
  @override
  double get rateNow => _player.speed.value;

  // 进度条 seek 走 mpv 默认精确绝对 seek (与引擎 seekTo 一致).
  @override
  void seek(Duration position) => unawaited(
    _player.mpv
        .commandAsync(['seek', '${position.inMicroseconds / 1e6}', 'absolute'])
        .result
        .then((_) {}, onError: (Object e) => debugPrint('seek 失败: $e')),
  );

  @override
  void setRate(double rate) => _player.setSpeed(rate);
}
