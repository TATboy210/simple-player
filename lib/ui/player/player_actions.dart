import 'package:flutter/material.dart';
import '../../kernel/models/playlist_item.dart';

/// 播放器回调集合 — 替代 PlayerScreen/ControlsOverlay/ControlBar 的散落回调参数
///
/// PlayerScreen 在 build() 中构造，沿链路传递给 ControlsOverlay → ControlBar。
/// engine 等状态对象不包含在内（它们是 required 独立参数）。
class PlayerActions {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final void Function(BuildContext context, TapUpDetails details)?
  onSettingsSecondary;
  final VoidCallback? onOpenFile;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onTogglePlayMode;
  final VoidCallback? onOpenSubtitle;
  final void Function(List<String> paths)? onFilesDropped;
  final void Function(bool hovering)? onDragHoverChanged;
  final void Function(String folderPath, List<PlaylistItem> scanned)?
  onFolderScanned;
  final VoidCallback? onClearHistory;
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
