import 'package:flutter/foundation.dart';

import '../../kernel/models/play_mode.dart';

/// 播放器稳定回调集合，沿 `Video.controls` 构建链共享。
class PlayerActions {
  /// 播放/暂停切换。
  final VoidCallback? onPlayPause;

  /// 快退指定毫秒数。
  final void Function(int milliseconds)? onSeekBack;

  /// 快进指定毫秒数。
  final void Function(int milliseconds)? onSeekForward;

  /// 停止并卸载当前媒体。
  final VoidCallback? onStop;

  /// O 键或菜单“打开文件”。
  final VoidCallback? onOpenFile;

  /// F 键或双击视频区域切换全屏。
  final VoidCallback? onToggleFullscreen;

  /// 字幕选择按钮。
  final VoidCallback? onOpenSubtitle;

  /// 设置按钮 — 打开设置窗口（本轮仅 UI 壳，无实际功能）。
  final VoidCallback? onOpenSettings;

  /// 文件拖放完成回调。
  final void Function(List<String> paths)? onFilesDropped;

  /// 拖拽悬停状态变化。
  final void Function(bool hovering)? onDragHoverChanged;

  /// ── v0.0.5 播放列表 ──

  /// L 键 / 控制栏按钮 — 开关播放列表面板。
  final VoidCallback? onTogglePlaylist;

  /// 跳到队列上一个条目。
  final VoidCallback? onPreviousEntry;

  /// 跳到队列下一个条目。
  final VoidCallback? onNextEntry;

  /// 循环切换播放模式 (loopAll → loopSingle → shuffle)。
  final VoidCallback? onCyclePlayMode;

  /// 当前播放模式 — 驱动模式按钮图标 (null 时按钮隐藏)。
  final ValueListenable<PlayMode>? playMode;

  /// Esc 键分派 — 面板可见时关闭面板并返回 true; 返回 false 走全屏退出。
  final bool Function()? onEscapePressed;

  const PlayerActions({
    this.onPlayPause,
    this.onSeekBack,
    this.onSeekForward,
    this.onStop,
    this.onOpenFile,
    this.onToggleFullscreen,
    this.onOpenSubtitle,
    this.onOpenSettings,
    this.onFilesDropped,
    this.onDragHoverChanged,
    this.onTogglePlaylist,
    this.onPreviousEntry,
    this.onNextEntry,
    this.onCyclePlayMode,
    this.playMode,
    this.onEscapePressed,
  });
}
