import 'package:flutter/material.dart';

/// 播放器稳定回调集合，沿 `Video.controls` 构建链共享。
///
/// 仅承载单文件播放器仍有效的基础传输、文件、字幕、设置、全屏与拖放动作；
/// 易变播放状态继续由独立的 listenable/stream 提供。
class PlayerActions {
  /// 播放/暂停切换；统一进入项目播放控制门面。
  final VoidCallback? onPlayPause;

  /// 快退指定毫秒数。
  final void Function(int milliseconds)? onSeekBack;

  /// 快进指定毫秒数。
  final void Function(int milliseconds)? onSeekForward;

  /// 停止并卸载当前媒体；由控制器统一收尾标题和空置态。
  final VoidCallback? onStop;

  /// 设置面板打开按钮。
  final VoidCallback? onSettings;

  /// 右键打开设置面板（携带点击位置，用于 showMenu 定位）。
  final void Function(BuildContext context, TapUpDetails details)?
  onSettingsSecondary;

  /// O 键或菜单“打开文件”。
  final VoidCallback? onOpenFile;

  /// F 键或双击视频区域切换全屏。
  final VoidCallback? onToggleFullscreen;

  /// 字幕选择按钮。
  final VoidCallback? onOpenSubtitle;

  /// 文件拖放完成回调（由 DropHandler 调用）。
  final void Function(List<String> paths)? onFilesDropped;

  /// 拖拽悬停状态变化（用于联动子组件动效）。
  final void Function(bool hovering)? onDragHoverChanged;

  const PlayerActions({
    this.onPlayPause,
    this.onSeekBack,
    this.onSeekForward,
    this.onStop,
    this.onSettings,
    this.onSettingsSecondary,
    this.onOpenFile,
    this.onToggleFullscreen,
    this.onOpenSubtitle,
    this.onFilesDropped,
    this.onDragHoverChanged,
  });
}
