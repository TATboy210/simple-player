import 'package:flutter/material.dart';
import '../../kernel/models/playlist_item.dart';

/// 播放器回调集合 — 替代 PlayerScreen/ControlsOverlay/ControlBar 的散落回调参数
///
/// PlayerScreen 在 initState 中构造一次（稳定化），沿链路传递给
/// ControlsOverlay → ControlBar。engine 等状态对象不包含在内（它们是
/// required 独立参数）。
///
/// 稳定化原因：ControlsOverlay 住进 media_kit `Video.controls` builder 后，
/// builder 在 Video 渲染时调用，不在 PlayerScreen build 上下文 — 故 actions
/// 必须是稳定引用，不能每次 build 重建。playModeIcon/Label 已下沉到
/// LeftButtonGroup 内部用 playlist.mode + playlistGeneration 计算。
class PlayerActions {
  /// 播放/暂停切换；统一进入项目播放控制门面。
  final VoidCallback? onPlayPause;

  /// 快退指定毫秒数。
  final void Function(int milliseconds)? onSeekBack;

  /// 快进指定毫秒数。
  final void Function(int milliseconds)? onSeekForward;

  /// N 键或控制栏"上一曲"按钮。
  final VoidCallback? onPrevious;

  /// P 键或控制栏"下一曲"按钮。
  final VoidCallback? onNext;

  /// 停止并卸载当前媒体；由控制器统一收尾标题和空置态。
  final VoidCallback? onStop;

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

  /// 是否为视频媒体（影响 prev/next 按钮的 tooltip）
  final bool isVideo;

  const PlayerActions({
    this.onPlayPause,
    this.onSeekBack,
    this.onSeekForward,
    this.onPrevious,
    this.onNext,
    this.onStop,
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
    this.isVideo = false,
  });
}
