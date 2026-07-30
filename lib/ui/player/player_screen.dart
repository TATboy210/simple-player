import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/win32_display_enumerator.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/playlist/playlist.dart';
import '../../kernel/services/playback_controller.dart';
import '../theme/tokens.dart';
import '../dialogs/settings/settings_overlay_shell.dart';
import '../dialogs/settings/settings_panel_controller.dart';
import '../playlist/playlist_panel.dart';
import '../window/custom_title_bar.dart';
import 'drop_handler.dart';
import 'media_kit_control_bar.dart';
import 'player_keyboard_actions.dart';
import 'smart_drag_to_resize_area.dart';

/// 播放器主屏幕 — 组合层, 接线键盘 + 控制层 + 播放列表.
///
/// 宽屏 (≥breakpointWide): Row 布局, 播放列表在右侧.
/// 窄屏: 播放列表叠加为 overlay.
class PlayerScreen extends StatefulWidget {
  final MediaEngine engine;

  /// media_kit [VideoController] — UI 用 [Video] widget. 透传自 PlayerServices.
  final VideoController mediaKitController;
  final PlaybackController controller;
  final Playlist playlist;
  final ValueNotifier<int> playlistGeneration;
  final WindowBridge windowService;
  final Map<String, String> customBindings;
  final VoidCallback? onTogglePlaylist;
  final SettingsPanelController settingsPanelController;
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

  const PlayerScreen({
    super.key,
    required this.engine,
    required this.mediaKitController,
    required this.controller,
    required this.playlist,
    required this.playlistGeneration,
    required this.windowService,
    required this.settingsPanelController,
    this.customBindings = const {},
    this.onTogglePlaylist,
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
  /// media_kit Video 的 state key — 供 F 键全屏回调调无参
  /// [VideoState.toggleFullscreen] (绕过 context 陷阱: 顶层 toggleFullscreen
  /// 需 Video 子树 context, 而 KeyboardHandler 在 Video 外层).
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();

  /// (visible, mounted) — 合并为单一 notifier 消除嵌套 VLB.
  final ValueNotifier<(bool, bool)> _playlistState = ValueNotifier((
    false,
    false,
  ));

  void _togglePlaylist() {
    final (visible, mounted) = _playlistState.value;
    final nowVisible = !visible;
    _playlistState.value = (nowVisible, nowVisible || mounted);
    widget.onTogglePlaylist?.call();
  }

  void _closePlaylist() {
    _playlistState.value = (false, _playlistState.value.$2);
    // 延迟卸载, 等待淡出动画完成.
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
  void dispose() {
    _playlistState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.windowService.mode,
      builder: (context, _) {
        final m = widget.windowService.mode.value;
        // BUG-02: isFullscreen 仅在真正全屏时为 true,
        // 最大化不应触发全屏 auto-hide 和禁用拖拽.
        final isFullscreen = m == WindowMode.fullscreen;

        final scaffold = Scaffold(
          backgroundColor: Tokens.bgBase,
          body: Column(
            children: [
              CustomTitleBar(windowService: widget.windowService),
              Expanded(
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        return ValueListenableBuilder<(bool, bool)>(
                          valueListenable: _playlistState,
                          builder: (context, state, videoContent) {
                            final (playlistVisible, playlistMounted) = state;
                            final useRow =
                                w >= Tokens.breakpointWide && playlistMounted;

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
                              // 宽屏: Row 布局, 视频左、播放列表右.
                              return Row(
                                children: [
                                  Expanded(
                                    child: RepaintBoundary(
                                      child: videoContent!,
                                    ),
                                  ),
                                  RepaintBoundary(
                                    child: IgnorePointer(
                                      ignoring: !playlistVisible,
                                      child: playlistPanel,
                                    ),
                                  ),
                                ],
                              );
                            }

                            // 窄屏: Stack overlay.
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
                          child: _buildVideoContent(),
                        );
                      },
                    ),
                    // 设置覆盖层壳 — 内容区 Stack 顶层, CustomTitleBar 之下.
                    // 注入 Win32DisplayAdapter + windowManager.getPosition tear-off,
                    // drag session 缓存真实窗口屏幕坐标做 workArea clamp;
                    // FFI 异常 / null display 走对称 MediaQuery fallback.
                    SettingsOverlayShell(
                      controller: widget.settingsPanelController,
                      resizing: widget.windowService.isResizing,
                      displayEnumerator: Win32DisplayAdapter(),
                      windowPositionReader: windowManager.getPosition,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final keyboardHandler = buildPlayerKeyboardActions(
          engine: widget.engine,
          controller: widget.controller,
          windowService: widget.windowService,
          customBindings: widget.customBindings,
          videoKey: _videoKey,
          isFullscreen: isFullscreen,
          context: context,
          onOpenFile: widget.onOpenFile,
          child: scaffold,
        );

        // T1: 始终返回 SmartDragToResizeArea — 保持 Widget 类型一致.
        // 全屏时 enabled=false (IgnorePointer 禁用拖拽但不改类型),
        // canUpdate 始终 true, Element 复用, Texture 子树不被销毁.
        return MouseRegion(
          cursor: isFullscreen
              ? SystemMouseCursors.basic
              : MouseCursor.defer,
          child: SmartDragToResizeArea(
            enabled: !isFullscreen,
            child: keyboardHandler,
          ),
        );
      },
    );
  }

  /// 视频内容区 — DropHandler 包裹 media_kit 控件 + 空状态层.
  Widget _buildVideoContent() => Row(
    children: [
      Expanded(
        child: DropHandler(
          onFilesDropped: widget.onFilesDropped ?? (_) {},
          onHoverChanged: widget.onDragHoverChanged,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaKitControlBar(
                controller: widget.mediaKitController,
                videoKey: _videoKey,
                onPrevious: () => widget.controller.playPrevious(),
                onNext: () => widget.controller.playNext(),
                onOpenFile: widget.onOpenFile,
                onOpenSubtitle: _openSubtitle,
                onTogglePlaylist: _togglePlaylist,
                onOpenSettings: widget.settingsPanelController.open,
              ),
              if (widget.emptyState != null)
                ValueListenableBuilder<MediaState>(
                  valueListenable: widget.engine.state,
                  builder: (_, state, child) => state == MediaState.idle
                      ? child!
                      : const SizedBox.shrink(),
                  child: Positioned.fill(child: widget.emptyState!),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
