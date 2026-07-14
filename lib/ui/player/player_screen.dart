import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/playlist/playlist.dart';
import '../../kernel/services/playback_controller.dart';
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

/// 包装 DragToResizeArea，增加 enabled 属性
///
/// 解决 canUpdate 问题：全屏/窗口模式切换时，始终返回同一 Widget 类型，
/// 避免 Element 销毁重建导致 Texture 子树丢失（黑帧闪烁根因之一）。
/// enabled=false 时用 IgnorePointer 禁用拖拽交互。
class SmartDragToResizeArea extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const SmartDragToResizeArea({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // 始终使用 DragToResizeArea 保持 Widget 类型一致
    // enabled=false 时用 IgnorePointer 禁用所有拖拽交互
    final dragArea = DragToResizeArea(child: child);
    if (enabled) return dragArea;
    return IgnorePointer(child: dragArea);
  }
}

/// 播放器主屏幕 — 组合层，接线键盘 + 控制层
///
/// 宽屏（≥600dp）: Row 布局，面板在右侧
/// 窄屏（<600dp）: 面板叠加为 overlay
class PlayerScreen extends StatefulWidget {
  final MediaEngine engine;
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

        // T5: AnimatedBuilder 包裹整个子树 — 读取 isFullscreen 后传入 _buildVideoContent。
        // 移除内层 AnimatedBuilder，消除同一 notifier 触发两次 markNeedsBuild。
        // isFullscreen 通过参数传递，ControlsOverlay 直接使用，无需独立监听 mode。
        return AnimatedBuilder(
          animation: widget.windowService.mode,
          builder: (context, child) {
            final m = widget.windowService.mode.value;
            // BUG-02 修正: isFullscreen 仅在真正全屏时为 true，
            // 最大化不应触发全屏 auto-hide 和禁用拖拽。
            final isFullscreen = m == WindowMode.fullscreen;

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
                // 录制字幕延迟偏好 — 跨会话恢复
                widget.controller.trackPreferenceService
                    ?.recordSubtitleDelay(delay + 500);
              },
              onSubtitleDelayBackward: () {
                final delay = widget.engine.subtitleDelay;
                widget.engine.setSubtitleDelay(delay - 500);
                widget.controller.trackPreferenceService
                    ?.recordSubtitleDelay(delay - 500);
              },
              onMediaPlayPause: () => widget.engine.togglePlayPause(),
              onMediaNext: () => widget.controller.playNext(),
              onMediaPrevious: () => widget.controller.playPrevious(),
              // BUG-01 修正: F 键快捷键接线 — 切换全屏/窗口
              onToggleFullscreen: () {
                widget.windowService.setMode(
                  isFullscreen ? WindowMode.windowed : WindowMode.fullscreen,
                );
              },
              onExitFullscreen: () {
                if (isFullscreen) {
                  widget.windowService.setMode(WindowMode.windowed);
                }
              },
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
                            child: _buildVideoContent(isVideo, modeIcon, modeLabel, isFullscreen),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );

            // T1: 始终返回 SmartDragToResizeArea — 保持 Widget 类型一致
            // 全屏时 enabled=false，通过 IgnorePointer 禁用拖拽但不改变类型
            // 这样 canUpdate 始终返回 true，Element 复用，Texture 子树不被销毁
            return MouseRegion(
              cursor: isFullscreen ? SystemMouseCursors.basic : MouseCursor.defer,
              child: SmartDragToResizeArea(
                enabled: !isFullscreen,
                child: keyboardHandler,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideoContent(
    bool isVideo,
    IconData modeIcon,
    String modeLabel,
    bool isFullscreen,
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
              // T5: 直接使用外层 AnimatedBuilder 传入的 isFullscreen，
              // 移除内层 AnimatedBuilder 消除同一 notifier 的冗余 markNeedsBuild。
              ControlsOverlay(
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
              ),
            ],
          ),
        ),
      ),
    ],
  );

  void _seek(MediaEngine engine, int deltaMs) {
    final target = engine.position.value + deltaMs;
    engine.seekTo(target.clamp(0, engine.duration.value));
  }

  static void _showShortcutsHelp(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const _ShortcutsHelpDialog());
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
