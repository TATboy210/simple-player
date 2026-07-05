import 'package:flutter/material.dart';
import '../../kernel/models/playlist_item.dart';

/// 播放器回调集合 — 替代 PlayerScreen/ControlsOverlay/ControlBar 的散落回调参数
///
/// PlayerScreen 在 build() 中构造，沿链路传递给 ControlsOverlay → ControlBar。
/// engine 等状态对象不包含在内（它们是 required 独立参数）。
class PlayerActions {
  /// N 键或控制栏"上一曲"按钮。
  final VoidCallback? onPrevious;

  /// P 键或控制栏"下一曲"按钮。
  final VoidCallback? onNext;

  /// 播放列表面板切换按钮。
  final VoidCallback? onTogglePlaylist;

  /// 设置面板打开按钮。
  final VoidCallback? onSettings;

  /// 右键打开设置面板（携带点击位置，用于 showMenu 定位）。
  final void Function(BuildContext context, TapUpDetails details)?
  onSettingsSecondary;

  /// O 键或菜单"打开文件"。
  final VoidCallback? onOpenFile;

  /// F 键或双击视频区域切换全屏。
  final VoidCallback? onToggleFullscreen;

  /// 控制栏播放模式按钮（顺序/循环/随机切换）。
  final VoidCallback? onTogglePlayMode;

  /// 字幕选择按钮。
  final VoidCallback? onOpenSubtitle;

  /// 文件拖放完成回调（由 DropHandler 调用）。
  final void Function(List<String> paths)? onFilesDropped;

  /// 拖拽悬停状态变化（用于联动子组件动效）。
  final void Function(bool hovering)? onDragHoverChanged;

  /// 文件夹扫描完成回调（传递扫描到的视频文件列表）。
  final void Function(String folderPath, List<PlaylistItem> scanned)?
  onFolderScanned;

  /// 清空播放历史。
  final VoidCallback? onClearHistory;

  /// 显示文件属性对话框。
  final void Function(String path)? onShowProperties;

  /// 播放模式图标（如 repeat/shuffle）
  final IconData? playModeIcon;

  /// 播放模式名称（如"顺序播放"、"列表循环"）
  final String? playModeLabel;

  /// 是否为视频媒体（影响 prev/next 按钮的 tooltip）
  final bool isVideo;

  const PlayerActions({
    this.onPrevious,
    this.onNext,
    this.onTogglePlaylist,
    this.onSettings,
    this.onSettingsSecondary,
    this.onOpenFile,
    this.onToggleFullscreen,
    this.onTogglePlayMode,
    this.onOpenSubtitle,
    this.onFilesDropped,
    this.onDragHoverChanged,
    this.onFolderScanned,
    this.onClearHistory,
    this.onShowProperties,
    this.playModeIcon,
    this.playModeLabel,
    this.isVideo = false,
  });
}
