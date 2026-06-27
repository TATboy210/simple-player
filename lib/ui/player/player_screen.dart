import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import 'package:player_engine/player_engine.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/playlist/playlist.dart';
import '../../features/player/services/playback_controller.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../playlist/playlist_panel.dart';
import '../shared/play_mode_utils.dart';
import 'controls_overlay.dart';
import '../window/custom_title_bar.dart';
import 'drop_handler.dart';
import 'keyboard_handler.dart';
import 'player_actions.dart';
import 'video_surface.dart';

/// 播放器主屏幕 — 组合层，接线键盘 + 控制层
///
/// 宽屏（≥600dp）: Row 布局，面板在右侧
/// 窄屏（<600dp）: 面板叠加为 overlay
class PlayerScreen extends StatefulWidget {
  final PlayerEngine engine;
  final PlaybackController controller;
  final Playlist playlist;
  final ValueNotifier<int> playlistGeneration;
  final Map<String, String> customBindings;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final void Function(BuildContext context, TapUpDetails details)?
  onSettingsSecondary;
  final VoidCallback? onOpenFile;
  final VoidCallback? onTogglePlayMode;
  final void Function(List<String> paths)? onFilesDropped;
  final void Function(bool hovering)? onDragHoverChanged;
  final Widget? emptyState;

  final void Function(String folderPath, List<PlaylistItem> scanned)?
  onFolderScanned;
  final VoidCallback? onClearHistory;
  final void Function(String path)? onShowProperties;
  final WindowBridge windowService;

  const PlayerScreen({
    super.key,
    required this.engine,
    required this.controller,
    required this.playlist,
    required this.playlistGeneration,
    required this.windowService,
    this.customBindings = const {},
    this.onTogglePlaylist,
    this.onSettings,
    this.onSettingsSecondary,
    this.onOpenFile,
    this.onTogglePlayMode,
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
  /// (visible, mounted) — 合并为单一 notifier 消除嵌套 VLB
  final ValueNotifier<(bool, bool)> _playlistState =
      ValueNotifier((false, false));

  /// B: 视频加载后锁定窗口比例 — OS 级约束，拖边框自动保持比例
  // 窗口自由缩放 — 不锁定宽高比，VideoSurface 用 FittedBox(contain) 自适应

  void _togglePlaylist() {
    final (visible, mounted) = _playlistState.value;
    final nowVisible = !visible;
    _playlistState.value = (nowVisible, nowVisible || mounted);
    widget.onTogglePlaylist?.call();
  }

  void _closePlaylist() {
    _playlistState.value = (false, _playlistState.value.$2);
    // 延迟卸载，等待淡出动画完成
    Future.delayed(const Duration(milliseconds: Tokens.durationSlide), () {
      if (mounted && !_playlistState.value.$1) {
        _playlistState.value = (false, false);
      }
    });
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
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _playlistState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: widget.engine.textureId,
      builder: (context, textureId, _) {
        final isVideo = textureId != null;
        final l10n = AppLocalizations.of(context);
        final modeIcon = playModeIcon(widget.playlist.mode);
        final modeLabel = playModeLabel(widget.playlist.mode, l10n);

        final keyboardHandler = KeyboardHandler(
          customBindings: widget.customBindings,
          onPlayPause: () => widget.engine.togglePlayPause(),
          onSeekBackward: () => _seek(widget.engine, -5000),
          onSeekForward: () => _seek(widget.engine, 5000),
          onVolumeUp: () =>
              widget.engine.setVolume(widget.engine.volume.value + 0.05),
          onVolumeDown: () =>
              widget.engine.setVolume(widget.engine.volume.value - 0.05),
          onToggleMute: () =>
              widget.engine.setMute(!widget.engine.isMuted.value),
          onPrevious: () => widget.controller.playPrevious(),
          onNext: () => widget.controller.playNext(),
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
          onExitFullscreen: () => widget.windowService.setMode(WindowMode.windowed),
          child: Scaffold(
            backgroundColor: Tokens.bgBase,
            body: Column(
              children: [
                CustomTitleBar(windowService: widget.windowService),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      return ValueListenableBuilder<(bool, bool)>(
                        valueListenable: _playlistState,
                        builder: (context, state, videoContent) {
                          final (playlistVisible, playlistMounted) = state;
                          final useRow = w >= Tokens.breakpointWide && playlistMounted;

                          final playlistPanel = PlaylistPanel(
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
                            resizing: widget.windowService.isResizing,
                            availableWidth: w,
                          );

                          if (useRow) {
                            // 宽屏: Row 布局，视频左、播放列表右
                            return Row(
                              children: [
                                Expanded(child: RepaintBoundary(child: videoContent!)),
                                RepaintBoundary(
                                  child: IgnorePointer(
                                    ignoring: !playlistVisible,
                                    child: playlistPanel,
                                  ),
                                ),
                              ],
                            );
                          }

                          // 窄屏: Stack overlay
                          return Stack(
                            children: [
                              RepaintBoundary(child: videoContent!),
                              if (playlistMounted)
                                RepaintBoundary(
                                  child: IgnorePointer(
                                    ignoring: !playlistVisible,
                                    child: playlistPanel,
                                  ),
                                ),
                            ],
                          );
                        },
                        child: _buildVideoContent(isVideo, modeIcon, modeLabel),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        return AnimatedBuilder(
          animation: widget.windowService.mode,
          builder: (context, child) {
            final m = widget.windowService.mode.value;
            if (m.isFullscreen || m.isMaximized) {
              return MouseRegion(
                cursor: SystemMouseCursors.basic,
                child: child,
              );
            }
            return DragToResizeArea(child: child!);
          },
          child: keyboardHandler,
        );
      },
    );
  }

  Widget _buildVideoContent(
    bool isVideo,
    IconData modeIcon,
    String modeLabel,
  ) => Row(
    children: [
      Expanded(
        child: DropHandler(
            onFilesDropped: widget.onFilesDropped ?? (_) {},
            onHoverChanged: widget.onDragHoverChanged,
            child: Stack(
              fit: StackFit.expand,
              children: [
              VideoSurface(engine: widget.engine),
              if (widget.emptyState != null)
                ValueListenableBuilder<MediaState>(
                  valueListenable: widget.engine.state,
                  builder: (_, state, child) => state == MediaState.idle
                      ? child!
                      : const SizedBox.shrink(),
                  child: Positioned.fill(child: widget.emptyState!),
                ),
              AnimatedBuilder(
                animation: widget.windowService.mode,
                builder: (context, _) {
                  final isFullscreen = widget.windowService.mode.value.isFullscreen;
                  return ControlsOverlay(
                  engine: widget.engine,
                  actions: PlayerActions(
                    onPrevious: () => widget.controller.playPrevious(),
                    onNext: () => widget.controller.playNext(),
                    onTogglePlaylist: _togglePlaylist,
                    onSettings: widget.onSettings,
                    onSettingsSecondary: widget.onSettingsSecondary,
                    onOpenFile: widget.onOpenFile,
                    onToggleFullscreen: () =>
                        widget.windowService.setMode(isFullscreen ? WindowMode.windowed : WindowMode.fullscreen),
                    onTogglePlayMode: widget.onTogglePlayMode,
                    onOpenSubtitle: _openSubtitle,
                    onFilesDropped: widget.onFilesDropped,
                    onDragHoverChanged: widget.onDragHoverChanged,
                    onFolderScanned: widget.onFolderScanned,
                    onClearHistory: widget.onClearHistory,
                    onShowProperties: widget.onShowProperties,
                    playModeIcon: modeIcon,
                    playModeLabel: modeLabel,
                    isVideo: isVideo,
                  ),
                  emptyStatePresent: widget.emptyState != null,
                  isFullscreen: isFullscreen,
                  resizing: widget.windowService.isResizing,
                  title: widget.playlist.current?.name,
                );
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );

  void _seek(PlayerEngine engine, int deltaMs) {
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
