import 'package:flutter/material.dart';

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

  /// media_kit 完成真实全屏切换后同步窗口语义状态。
  final void Function(bool isFullscreen)? onFullscreenStateChanged;

  /// O 键或菜单“打开文件”。
  final VoidCallback? onOpenFile;

  /// F 键或双击视频区域切换全屏。
  final VoidCallback? onToggleFullscreen;

  /// 字幕选择按钮。
  final VoidCallback? onOpenSubtitle;

  /// 文件拖放完成回调。
  final void Function(List<String> paths)? onFilesDropped;

  /// 拖拽悬停状态变化。
  final void Function(bool hovering)? onDragHoverChanged;

  const PlayerActions({
    this.onPlayPause,
    this.onSeekBack,
    this.onSeekForward,
    this.onStop,
    this.onFullscreenStateChanged,
    this.onOpenFile,
    this.onToggleFullscreen,
    this.onOpenSubtitle,
    this.onFilesDropped,
    this.onDragHoverChanged,
  });
}
