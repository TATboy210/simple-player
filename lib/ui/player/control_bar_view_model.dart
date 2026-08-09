import 'package:flutter/foundation.dart';

/// 控制栏数据视图模型 — 解耦子组件与 [MediaEngine]。
///
/// 路径B Commit1:数据源仍由 engine 派生本 vm。
/// Commit2 将由 `PlayerVideoControls` 从 `PlayerControlsState`(player.stream)
/// 提供同结构 vm,子组件零改动切换数据源。
///
/// position/duration 用 int ms(对齐 `ProgressBar` seek-hold 的 int 差值比较,
/// 零改动迁移);volume 用 0-1(项目语义)。
///
/// 无 buffered 字段 — 原 ProgressBar/TimeRangeDisplay 都未消费 engine.buffered,
/// YAGNI 不引入。
class ControlBarViewModel {
  const ControlBarViewModel({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.volume,
    required this.isMuted,
    required this.rate,
    required this.isFullscreen,
    required this.onSeek,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onToggleMute,
    required this.onSetVolume,
    required this.onSetRate,
  });

  /// 播放中(驱动播放/暂停图标)。
  final ValueListenable<bool> isPlaying;

  /// 当前位置(ms)— seek-hold 监听它到达目标容差。
  final ValueListenable<int> position;

  /// 总时长(ms)— <=0 视为禁用态。
  final ValueListenable<int> duration;

  /// 音量(0-1)。
  final ValueListenable<double> volume;

  /// 静音状态。
  final ValueListenable<bool> isMuted;

  /// 倍速。
  final ValueListenable<double> rate;

  /// 全屏状态(驱动全屏按钮图标 fullscreen/exit)。
  final ValueListenable<bool> isFullscreen;

  // ─── 控制回调 ───

  /// seek 到指定 ms(乐观更新由上层负责)。
  final void Function(int ms) onSeek;

  /// 播放/暂停切换。
  final VoidCallback onPlayPause;

  /// 后退 ms(中央组后退按钮)。
  final void Function(int ms) onSeekBack;

  /// 前进 ms(中央组前进按钮)。
  final void Function(int ms) onSeekForward;

  /// 静音切换(写走 engine,保 _preMuteVolume 语义)。
  final VoidCallback onToggleMute;

  /// 设置音量(0-1)。
  final void Function(double v) onSetVolume;

  /// 设置倍速。
  final void Function(double rate) onSetRate;
}
