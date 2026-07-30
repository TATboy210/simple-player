import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// media_kit 视频控件 + 自定义 bottomButtonBar.
///
/// media_kit 是唯一后端: [Video] + [MaterialDesktopVideoControls].
/// 默认快捷键全禁用 (默认 ←→±2s / Space / ↑↓ / F / Esc / 媒体键),
/// 全交项目 [KeyboardHandler]: 保留 ±5s 语义、避免双触发、经 engine
/// 走 generation guard (切歌时取消残留 seek). 焦点冒泡保证可行 —
/// [Video] 内部 Focus 抢到 primaryFocus 时, 空 bindings 的
/// CallbackShortcuts 返回 ignored, 事件冒泡到外层 KeyboardHandler.
///
/// bottomButtonBar 自定义入口: 上/下一首接 [PlaybackController] (media_kit
/// 默认 SkipPrevious/SkipNext 因 player.playlist 为空而自动隐藏, 故用
/// [MaterialDesktopCustomButton] 显式接线); 其余为打开文件/字幕/播放列表/设置/全屏.
class MediaKitControlBar extends StatelessWidget {
  const MediaKitControlBar({
    super.key,
    required this.controller,
    required this.videoKey,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenFile,
    required this.onOpenSubtitle,
    required this.onTogglePlaylist,
    required this.onOpenSettings,
  });

  final VideoController controller;
  final GlobalKey<VideoState> videoKey;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onOpenFile;
  final VoidCallback onOpenSubtitle;
  final VoidCallback onTogglePlaylist;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return MaterialDesktopVideoControlsTheme(
      // normal/fullscreen 共用同一控件配置 (按键全禁用 + 自定义 bottomButtonBar).
      normal: _themeData(),
      fullscreen: _themeData(),
      child: Video(
        key: videoKey,
        controller: controller,
        controls: MaterialDesktopVideoControls,
      ),
    );
  }

  MaterialDesktopVideoControlsThemeData _themeData() =>
      MaterialDesktopVideoControlsThemeData(
        keyboardShortcuts: const <ShortcutActivator, VoidCallback>{},
        bottomButtonBar: _buildBottomBar(),
      );

  /// bottomButtonBar 按钮序列: 上/下一首 · 播放暂停 · 音量 · 位置 ·
  /// 打开文件 · 外挂字幕 · 播放列表 · 设置 · 全屏.
  List<Widget> _buildBottomBar() => [
    MaterialDesktopCustomButton(
      icon: const Icon(Icons.skip_previous),
      onPressed: onPrevious,
    ),
    const MaterialDesktopPlayOrPauseButton(),
    MaterialDesktopCustomButton(
      icon: const Icon(Icons.skip_next),
      onPressed: onNext,
    ),
    const MaterialDesktopVolumeButton(),
    const MaterialDesktopPositionIndicator(),
    const Spacer(),
    MaterialDesktopCustomButton(
      icon: const Icon(Icons.folder_open),
      onPressed: () => onOpenFile?.call(),
    ),
    // 外挂字幕文件 (srt/ass/ssa/sub/vtt).
    MaterialDesktopCustomButton(
      icon: const Icon(Icons.subtitles),
      onPressed: onOpenSubtitle,
    ),
    MaterialDesktopCustomButton(
      icon: const Icon(Icons.playlist_play),
      onPressed: onTogglePlaylist,
    ),
    MaterialDesktopCustomButton(
      icon: const Icon(Icons.settings),
      onPressed: onOpenSettings,
    ),
    const MaterialDesktopFullscreenButton(),
  ];
}
