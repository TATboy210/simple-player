import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import 'package:player_engine/player_engine.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/playlist/playlist.dart';
import '../../kernel/window/aspect_ratio_service.dart';
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
  final ValueNotifier<bool> _playlistVisible = ValueNotifier(false);
  final ValueNotifier<bool> _playlistMounted = ValueNotifier(false);

  /// 视频加载后自动调整窗口比例（仅窗口模式）
  ///
  /// mpv 风格：先锁定窗口宽高比（WM_SIZING 拖拽时自动约束），
  /// 再调整窗口尺寸以匹配视频。
  void _onAspectRatioChanged() {
    final ratio = widget.engine.aspectRatio.value;
    if (ratio <= 0 || !ratio.isFinite) return;
    // 全屏时不调整窗口尺寸
    if (widget.windowService.mode.value.isFullscreen) return;
    // 锁定窗口宽高比（拖拽时自动约束）
    AspectRatioService.I.matchVideo(ratio);
    // 调整窗口尺寸以匹配视频
    _fitWindowToVideo(ratio);
  }

  Future<void> _fitWindowToVideo(double ratio) async {
    try {
      final currentSize = await windowManager.getSize();
      // 保持当前高度，按视频比例计算宽度
      double w = currentSize.height * ratio;
      double h = currentSize.height;
      // 合理范围限制（1920*0.9 ≈ 1728）
      if (w > 1728) {
        w = 1728;
        h = w / ratio;
      }
      if (h > 1080) {
        h = 1080;
        w = h * ratio;
      }
      await windowManager.setSize(Size(w, h));
      await windowManager.center();
    } catch (_) {
      // 静默失败，不影响播放
    }
  }

  void _togglePlaylist() {
    final nowVisible = !_playlistVisible.value;
    _playlistVisible.value = nowVisible;
    if (nowVisible) _playlistMounted.value = true;
    widget.onTogglePlaylist?.call();
  }

  void _closePlaylist() {
    _playlistVisible.value = false;
    // 延迟卸载，等待淡出动画完成
    Future.delayed(const Duration(milliseconds: Tokens.durationSlide), () {
      if (mounted && !_playlistVisible.value) {
        _playlistMounted.value = false;
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
    widget.engine.aspectRatio.addListener(_onAspectRatioChanged);
  }

  @override
  void dispose() {
    widget.engine.aspectRatio.removeListener(_onAspectRatioChanged);
    _playlistVisible.dispose();
    _playlistMounted.dispose();
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
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _playlistVisible,
                    builder: (context, playlistVisible, videoContent) =>
                      ValueListenableBuilder<bool>(
                    valueListenable: _playlistMounted,
                    builder: (context, mounted, _) => Stack(
                      children: [
                        videoContent!,
                        if (mounted)
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
                              resizing: widget.windowService.isResizing,
                            ),
                          ),
                      ],
                    ),
                  ),
                    child: _buildVideoContent(isVideo, modeIcon, modeLabel),
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
