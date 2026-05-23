import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/media_engine.dart';
import '../../kernel/models/media_state.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/playlist/playlist.dart';
import '../../kernel/services/playback_controller.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../playlist/playlist_panel.dart';
import '../shared/play_mode_utils.dart';
import '../../kernel/window/aspect_ratio_service.dart';
import 'controls_overlay.dart';
import '../../kernel/ui/window/custom_title_bar.dart';
import 'drop_handler.dart';
import 'keyboard_handler.dart';
import 'video_surface.dart';

/// 播放器主屏幕 — 组合层，接线窗口管理 + 键盘 + 标题栏
///
/// 宽屏（≥600dp）: Row 布局，面板在右侧
/// 窄屏（<600dp）: 面板叠加为 overlay
/// 全屏: 隐藏标题栏
class PlayerScreen extends StatefulWidget {
  final MediaEngine engine;
  final PlaybackController controller;
  final Playlist playlist;
  final ValueNotifier<int> playlistGeneration;
  final Map<String, String> customBindings;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final void Function(BuildContext context, TapUpDetails details)? onSettingsSecondary;
  final VoidCallback? onOpenFile;
  final VoidCallback? onTogglePlayMode;
  final bool isVideo;
  final void Function(List<String> paths)? onFilesDropped;
  final void Function(bool hovering)? onDragHoverChanged;
  final Widget? emptyState;

  final void Function(String folderPath, List<PlaylistItem> scanned)?
      onFolderScanned;
  final VoidCallback? onClearHistory;
  final void Function(String path)? onShowProperties;

  const PlayerScreen({
    super.key,
    required this.engine,
    required this.controller,
    required this.playlist,
    required this.playlistGeneration,
    this.customBindings = const {},
    this.onPrevious,
    this.onNext,
    this.onTogglePlaylist,
    this.onSettings,
    this.onSettingsSecondary,
    this.onOpenFile,
    this.onTogglePlayMode,
    this.isVideo = false,
    this.onFilesDropped,
    this.onDragHoverChanged,
    this.emptyState,
    this.onFolderScanned,
    this.onClearHistory,
    this.onShowProperties,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final ValueNotifier<bool> _playlistVisible = ValueNotifier(false);
  bool _playlistMounted = false;

  void _togglePlaylist() {
    final nowVisible = !_playlistVisible.value;
    _playlistVisible.value = nowVisible;
    if (nowVisible) _playlistMounted = true;
    widget.onTogglePlaylist?.call();
  }

  void _closePlaylist() {
    _playlistVisible.value = false;
    // 延迟卸载，等待淡出动画完成
    Future.delayed(
      const Duration(milliseconds: Tokens.durationSlide),
      () {
        if (mounted && !_playlistVisible.value) {
          setState(() => _playlistMounted = false);
        }
      },
    );
  }

  Future<void> _openSubtitle() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'ass', 'ssa', 'sub', 'vtt'],
    );
    if (result != null && result.files.single.path != null) {
      widget.engine.setExternalSubtitle(result.files.single.path!);
    }
  }

  @override
  void dispose() {
    _playlistVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wm = WindowBridge.I;

    return ValueListenableBuilder<WindowMode>(
      valueListenable: wm.mode,
      builder: (context, windowMode, _) {
        final isFullscreen = windowMode == WindowMode.fullscreen;

        return KeyboardHandler(
          customBindings: widget.customBindings,
          onPlayPause: () => widget.engine.togglePlayPause(),
          onSeekBackward: () => _seek(widget.engine, -5000),
          onSeekForward: () => _seek(widget.engine, 5000),
          onVolumeUp: () =>
              widget.engine.setVolume(widget.engine.volume.value + 0.05),
          onVolumeDown: () =>
              widget.engine.setVolume(widget.engine.volume.value - 0.05),
          onToggleFullscreen: wm.toggleFullscreen,
          onExitFullscreen: isFullscreen ? wm.exitFullscreen : null,
          onToggleMute: () =>
              widget.engine.setMute(!widget.engine.isMuted.value),
          onPrevious: widget.onPrevious,
          onNext: widget.onNext,
          onOpenFile: widget.onOpenFile,
          onToggleSubtitle: widget.engine.toggleSubtitle,
          onShowHelp: () => _showShortcutsHelp(context),
          onSubtitleDelayForward: () {
            final delay = widget.engine.subtitleDelay;
            widget.engine.setSubtitleDelay(delay + 500);
          },
          onSubtitleDelayBackward: () {
            final delay = widget.engine.subtitleDelay;
            widget.engine.setSubtitleDelay(delay - 500);
          },
          onMediaPlayPause: () => widget.engine.togglePlayPause(),
          onMediaNext: () => widget.controller.playNext(),
          onMediaPrevious: () => widget.controller.playPrevious(),
          onCycleAspectRatio: () => AspectRatioService.I.cycleRatio(),
          child: DragToResizeArea(
            enableResizeEdges: isFullscreen ? [] : null,
            child: Scaffold(
              backgroundColor: Tokens.bgBase,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 标题栏：全屏时跳过构建（Offstage 仍运行 BackdropFilter）
                  if (!isFullscreen)
                    CustomTitleBar(
                      fileName: widget.controller.currentFileName,
                      onOpenFile: widget.onOpenFile,
                    ),

                  // 主内容区
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _playlistVisible,
                      builder: (context, playlistVisible, _) => Stack(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropHandler(
                                  onFilesDropped:
                                      widget.onFilesDropped ?? (_) {},
                                  onHoverChanged: widget.onDragHoverChanged,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      VideoSurface(engine: widget.engine),
                                      if (widget.emptyState != null)
                                        ValueListenableBuilder<MediaState>(
                                          valueListenable:
                                              widget.engine.state,
                                          builder: (_, state, child) =>
                                              state == MediaState.idle
                                              ? child!
                                              : const SizedBox.shrink(),
                                          child: Positioned.fill(
                                            child: widget.emptyState!,
                                          ),
                                        ),
                                      ValueListenableBuilder<int>(
                                        valueListenable:
                                            widget.playlistGeneration,
                                        builder: (context, _, _) {
                                          final l10n = AppLocalizations.of(
                                            context,
                                          );
                                          return ControlsOverlay(
                                            engine: widget.engine,
                                            isFullscreen: isFullscreen,
                                            emptyStatePresent:
                                                widget.emptyState != null,
                                            onPrevious: widget.onPrevious,
                                            onNext: widget.onNext,
                                            onTogglePlaylist:
                                                _togglePlaylist,
                                            onSettings: widget.onSettings,
                                            onSettingsSecondary:
                                                widget.onSettingsSecondary,
                                            onOpenFile: widget.onOpenFile,
                                            onToggleFullscreen:
                                                wm.toggleFullscreen,
                                            onTogglePlayMode:
                                                widget.onTogglePlayMode,
                                            onOpenSubtitle: _openSubtitle,
                                            playModeIcon: playModeIcon(
                                              widget.playlist.mode,
                                            ),
                                            playModeLabel: playModeLabel(
                                              widget.playlist.mode,
                                              l10n,
                                            ),
                                            isVideo: widget.isVideo,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // 沉浸式浮窗播放列表
                          if (_playlistMounted)
                            IgnorePointer(
                              ignoring: !playlistVisible,
                              child: PlaylistPanel(
                                playlist: widget.playlist,
                                visible: playlistVisible,
                                onClose: _closePlaylist,
                                onSelectIndex: (i) {
                                  widget.controller.playIndex(i);
                                  _closePlaylist();
                                },
                                onRemoveIndex: (i) {
                                  widget.playlist.removeAt(i);
                                  widget.playlistGeneration.value++;
                                },
                                onShowProperties: widget.onShowProperties,
                                onFolderScanned: widget.onFolderScanned,
                                onClearHistory: widget.onClearHistory,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _seek(MediaEngine engine, int deltaMs) {
    final target = engine.position.value + deltaMs;
    engine.seekTo(target.clamp(0, engine.duration.value));
  }

  static void _showShortcutsHelp(BuildContext context) {
    showDialog(context: context, builder: (_) => const _ShortcutsHelpDialog());
  }
}

/// 快捷键帮助对话框
class _ShortcutsHelpDialog extends StatelessWidget {
  const _ShortcutsHelpDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: Tokens.bgPanel,
      title: Text(
        l10n.shortcutsHelpTitle,
        style: const TextStyle(color: Tokens.textPrimary),
      ),
      content: SizedBox(
        width: 300,
        child: Table(
          columnWidths: const {0: FixedColumnWidth(100), 1: FlexColumnWidth()},
          children: shortcutDefinitions(l10n)
              .map(
                (s) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        s.$1,
                        style: const TextStyle(
                          color: Tokens.accent,
                          fontSize: Tokens.fontCaption,
                          fontWeight: Tokens.weightMedium,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        s.$2,
                        style: const TextStyle(
                          color: Tokens.textSecondary,
                          fontSize: Tokens.fontCaption,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close, style: const TextStyle(color: Tokens.accent)),
        ),
      ],
    );
  }
}
