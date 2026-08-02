import 'dart:async';

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
import '../../l10n/app_localizations.dart';
import '../dialogs/settings/settings_overlay_shell.dart';
import '../dialogs/settings/settings_panel_controller.dart';
import '../playlist/playlist_panel.dart';
import '../shared/play_mode_utils.dart';
import '../theme/tokens.dart';
import '../window/custom_title_bar.dart';
import 'controls_overlay.dart';
import 'drop_handler.dart';
import 'player_actions.dart';
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
  /// media_kit Video 的 state key — 供 setSubtitleViewPadding 调用
  /// (控件可见性联动字幕上移). 不再用于全屏切换 (改走 WindowService.setMode).
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();

  /// (visible, mounted) — 合并为单一 notifier 消除嵌套 VLB.
  final ValueNotifier<(bool, bool)> _playlistState = ValueNotifier((
    false,
    false,
  ));

  /// 控件可见性 — 从 ControlsOverlay 单向同步,驱动全屏鼠标隐藏 + 字幕上移.
  final ValueNotifier<bool> _controlsVisible = ValueNotifier(true);

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

  /// 通过播放控制器删除条目，确保当前媒体先完成安全停止。
  ///
  /// 面板不能直接修改 [Playlist]，否则会绕过 stop 失败保护和活动标题收尾。
  Future<void> _removePlaylistItem(int index) async {
    await widget.controller.removeAt(index);
    if (!mounted) return;
    widget.playlistGeneration.value++;
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
    _controlsVisible.addListener(_onControlsVisibleChanged);
    // Video 挂载后初始上移字幕(控件初始可见). post-frame 确保 _videoKey 已挂载.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onControlsVisibleChanged(),
    );
  }

  /// 控件可见性变化 — 联动字幕上移(控件可见时上移避免被 ControlBar 遮挡,
  /// 隐藏时还原 base). 对齐 media_kit 原生 material_desktop shift/unshift 逻辑.
  void _onControlsVisibleChanged() {
    final videoState = _videoKey.currentState;
    if (videoState == null) return;
    final base = videoState.widget.subtitleViewConfiguration.padding;
    if (_controlsVisible.value) {
      videoState.setSubtitleViewPadding(
        base +
            const EdgeInsets.only(
              bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
            ),
      );
    } else {
      videoState.setSubtitleViewPadding(base);
    }
  }

  @override
  void dispose() {
    _controlsVisible.removeListener(_onControlsVisibleChanged);
    _controlsVisible.dispose();
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
                              onRemoveIndex: (index) {
                                unawaited(_removePlaylistItem(index));
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
                          child: _buildVideoContent(
                            context,
                            isFullscreen: isFullscreen,
                          ),
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
        return ValueListenableBuilder<bool>(
          valueListenable: _controlsVisible,
          builder: (_, controlsVisible, _) {
            // 全屏 + 控件隐藏 → 隐藏鼠标(沉浸);否则全屏 basic / 窗口 defer
            final cursor = (isFullscreen && !controlsVisible)
                ? SystemMouseCursors.none
                : (isFullscreen ? SystemMouseCursors.basic : MouseCursor.defer);
            return MouseRegion(
              cursor: cursor,
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

  /// 视频内容区 — DropHandler 包裹 media_kit 纯渲染 + 空状态层 + 自定义控制外套.
  ///
  /// 三层 Stack: 底层 [Video](`NoVideoControls` 纯渲染, 身体不动) →
  /// 中层 emptyState(idle 时显示, 在 ControlsOverlay 之下供手势透传) →
  /// 顶层 [ControlsOverlay](自定义玻璃外套: ControlBar + AutoHideController +
  /// OSD + ErrorBanner + 手势). media_kit 引擎(VideoController/videoKey/全屏)不变.
  Widget _buildVideoContent(
    BuildContext context, {
    required bool isFullscreen,
  }) => Row(
    children: [
      Expanded(
        child: DropHandler(
          onFilesDropped: widget.onFilesDropped ?? (_) {},
          onHoverChanged: widget.onDragHoverChanged,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 底层: media_kit 纯渲染 — 脱掉控件外套 (NoVideoControls),
              // VideoState 仍创建, toggleFullscreen 仍可用 (身体不动).
              Video(
                key: _videoKey,
                controller: widget.mediaKitController,
                controls: (_) => const SizedBox.shrink(),
              ),
              // 中层: emptyState (idle 时显示). 置于 ControlsOverlay 之下,
              // 让 ControlsOverlay.emptyStatePresent 的手势透传命中 emptyState 按钮.
              if (widget.emptyState != null)
                ValueListenableBuilder<MediaState>(
                  valueListenable: widget.engine.state,
                  builder: (_, state, child) => state == MediaState.idle
                      ? child!
                      : const SizedBox.shrink(),
                  child: Positioned.fill(child: widget.emptyState!),
                ),
              // 顶层: 自定义玻璃外套. 借 playlistGeneration 间接刷新
              // playModeIcon (Playlist.mode 非 ValueNotifier, 见 _buildPlayerActions).
              ValueListenableBuilder<int>(
                valueListenable: widget.playlistGeneration,
                builder: (ctx, _, _) => ControlsOverlay(
                  engine: widget.engine,
                  actions: _buildPlayerActions(ctx),
                  isFullscreen: isFullscreen,
                  resizing: widget.windowService.isResizing,
                  emptyStatePresent: widget.emptyState != null,
                  visibleSink: _controlsVisible,
                  // 视频名 — 从 playlist 当前项 basename 取 (恢复 14b68165^ 接线,
                  // CB-04 隐藏 title row 时移除). 借 playlistGeneration VLB 刷新
                  // (切歌 onNeedRebuild→generation++).
                  title: widget.playlist.current?.name,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  /// 构造播放器回调集合 — 从 PlayerScreen 现有回调填充 [PlayerActions].
  ///
  /// `playModeIcon`/`playModeLabel` 从 `widget.playlist.mode` 经 PlayModeUtils
  /// 计算. `Playlist.mode` 是普通 getter (非 ValueNotifier), 借外层
  /// `playlistGeneration` ValueListenableBuilder 间接驱动刷新 — 若播放模式
  /// 切换未触发 generation++, 图标不实时更新 (已知限制, 不阻塞主目标).
  /// `onToggleFullscreen` 走 `WindowService.setMode` (统一全屏通道, 同步 mode).
  PlayerActions _buildPlayerActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = widget.playlist.mode;
    return PlayerActions(
      onPrevious: () => widget.controller.playPrevious(),
      onNext: () => widget.controller.playNext(),
      onOpenFile: widget.onOpenFile,
      onOpenSubtitle: _openSubtitle,
      onTogglePlaylist: _togglePlaylist,
      onSettings: widget.settingsPanelController.open,
      onSettingsSecondary: widget.onSettingsSecondary,
      onTogglePlayMode: widget.onTogglePlayMode,
      // 方案 B: setMode 设 intent+mode (守卫同步 mode), videoKey.toggleFullscreen
      // 走 media_kit 原生全屏. 闭包内现读 mode.value 避免陈旧捕获 (此 builder 在
      // playlistGeneration VLB 内, 拿不到外层 AnimatedBuilder 的 isFullscreen).
      onToggleFullscreen: () {
        final m = widget.windowService.mode.value;
        final entering = m != WindowMode.fullscreen;
        widget.windowService.setMode(
          entering ? WindowMode.fullscreen : WindowMode.windowed,
        );
        _videoKey.currentState?.toggleFullscreen();
      },
      onFilesDropped: widget.onFilesDropped,
      onShowProperties: widget.onShowProperties,
      playModeIcon: playModeIcon(mode),
      playModeLabel: playModeLabel(mode, l10n),
      isVideo: true,
    );
  }
}
