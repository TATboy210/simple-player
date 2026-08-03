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
import '../dialogs/settings/settings_overlay_shell.dart';
import '../dialogs/settings/settings_panel_controller.dart';
import '../playlist/playlist_panel.dart';
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
///
/// 控制栏住进 media_kit `Video.controls` builder (渐进路径·核心闭环):
/// 全屏 route 复制 builder 时自动携带 ControlsOverlay, 解决全屏控制栏消失.
/// 数据源/控制出口暂留 engine (不切 player.stream), 避免破坏 ProgressBar
/// 「修 C 事件驱动 v2」精密逻辑.
class PlayerScreen extends StatefulWidget {
  final MediaEngine engine;

  /// media_kit [VideoController] — UI 用 [Video] widget. 透传自 PlayerServices.
  ///
  /// 生产组合层必须提供该控制器；仅当 [videoSurfaceBuilder] 注入测试渲染面时可为 null，
  /// 避免 widget test 绑定 MDK/libmpv 原生运行时。
  final VideoController? mediaKitController;

  /// 可替换的视频渲染面；默认路径仍使用 media_kit [Video]，不改变其生命周期。
  final Widget Function(GlobalKey<VideoState> videoKey)? videoSurfaceBuilder;

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
    this.mediaKitController,
    this.videoSurfaceBuilder,
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
  }) : assert(mediaKitController != null || videoSurfaceBuilder != null);

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
  ///
  /// 双实例竞争警告:窗口态与全屏态两个 ControlsOverlay 实例都写此 sink.
  /// 当前阶段暂留(值跳变但不崩溃),拆解留待下一步(对齐 plan 阶段 2).
  final ValueNotifier<bool> _controlsVisible = ValueNotifier(true);

  /// 空置页刚出现时暂时隔离所有“打开文件”入口，等待旧媒体纹理完全退场。
  static const _openFileDelay = Duration(seconds: 2);
  Timer? _openFileDelayTimer;

  /// 打开文件入口可用性 — ValueNotifier 驱动 ControlsOverlay 内的空状态页
  /// IgnorePointer（builder 化后需自驱动，不再靠本层 setState 重建）。
  final ValueNotifier<bool> _isOpenFileEnabled = ValueNotifier(false);

  /// 稳定化的播放器回调集合 — initState 构造一次，供 ControlsOverlay 闭包捕获。
  /// builder 化后 actions 不能每次 build 重建（Video.controls builder 不在
  /// build 上下文），playModeIcon/Label 已下沉到 LeftButtonGroup 内部计算。
  late final PlayerActions _actions;

  bool get _isEmptyState =>
      widget.engine.state.value == MediaState.idle && !widget.engine.hasMedia;

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
    // 稳定化 actions — initState 构造一次,纯播放/项目回调闭包现读 widget 字段
    // 避免陈旧捕获. playModeIcon/Label 已下沉, 不需 l10n/context.
    _actions = PlayerActions(
      onPrevious: () => widget.controller.playPrevious(),
      onNext: () => widget.controller.playNext(),
      // 不能直接调用 engine.stop：控制器会在确认卸载后清空活动标题。
      onStop: () => unawaited(widget.controller.stopCurrentMedia()),
      // 控制栏与快捷键共用空置态的资源释放隔离窗口。
      onOpenFile: _openFileWhenReady,
      onOpenSubtitle: _openSubtitle,
      onTogglePlaylist: _togglePlaylist,
      onSettings: widget.settingsPanelController.open,
      onSettingsSecondary: widget.onSettingsSecondary,
      onTogglePlayMode: widget.onTogglePlayMode,
      // setMode 仅同步 WindowService mode(守卫 + 鼠标隐藏联动). media_kit route
      // 切换改由 ControlsOverlay._toggleFullscreen 用各实例自己的 videoState 完成
      // (修复症状④: 窗口态 _videoKey isFullscreen() 永远 false → 退出反而 enter).
      // 闭包内现读 mode.value 避免陈旧捕获.
      onToggleFullscreen: () {
        final m = widget.windowService.mode.value;
        final entering = m != WindowMode.fullscreen;
        widget.windowService.setMode(
          entering ? WindowMode.fullscreen : WindowMode.windowed,
        );
      },
      onFilesDropped: widget.onFilesDropped,
      onShowProperties: widget.onShowProperties,
      isVideo: true,
    );
    _controlsVisible.addListener(_onControlsVisibleChanged);
    widget.engine.state.addListener(_syncOpenFileAvailability);
    // Stop 成功会清空活动标题；它也是 hasMedia 从 true 变 false 后的可靠 UI 通知。
    widget.controller.currentFileName.addListener(_syncOpenFileAvailability);
    _syncOpenFileAvailability();
    // Video 挂载后初始上移字幕(控件初始可见). post-frame 确保 _videoKey 已挂载.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onControlsVisibleChanged(),
    );
  }

  /// idle 既可能表示尚未加载，也可能表示 stop 正在卸载；两种情况都先隔离打开入口。
  void _syncOpenFileAvailability() {
    _openFileDelayTimer?.cancel();
    if (widget.engine.state.value != MediaState.idle) {
      _isOpenFileEnabled.value = true;
      return;
    }

    _isOpenFileEnabled.value = false;
    if (!_isEmptyState) return;
    _openFileDelayTimer = Timer(_openFileDelay, () {
      if (!mounted || !_isEmptyState) return;
      _isOpenFileEnabled.value = true;
    });
  }

  /// 将所有项目层打开入口收敛到空置态稳定窗口之后。
  void _openFileWhenReady() {
    if (!_isOpenFileEnabled.value) return;
    widget.onOpenFile?.call();
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
    _openFileDelayTimer?.cancel();
    widget.controller.currentFileName.removeListener(_syncOpenFileAvailability);
    widget.engine.state.removeListener(_syncOpenFileAvailability);
    _controlsVisible.removeListener(_onControlsVisibleChanged);
    _controlsVisible.dispose();
    _isOpenFileEnabled.dispose();
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
                          child: _buildVideoContent(context),
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
          // O 键与空置页按钮共享同一稳定窗口，不能绕过媒体释放延迟。
          onOpenFile: _openFileWhenReady,
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

  /// 视频内容区 — DropHandler 包裹 media_kit [Video] (controls 住进 builder).
  ///
  /// 渐进路径核心:ControlsOverlay + emptyState 都住进 Video.controls builder,
  /// media_kit 全屏 route 复制 builder 时自动携带控制栏(解决全屏控制栏消失).
  /// engine/VideoController/videoKey/全屏机制不变,数据源暂留 engine.
  Widget _buildVideoContent(BuildContext context) => Row(
    children: [
      Expanded(
        child: DropHandler(
          onFilesDropped: widget.onFilesDropped ?? (_) {},
          onHoverChanged: widget.onDragHoverChanged,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video.controls builder 内含 ControlsOverlay + emptyState,
              // 全屏 route 复制 builder 时自动携带. 生产路径 media_kit 纯渲染；
              // 测试可注入无原生依赖 surface (videoSurfaceBuilder).
              _buildVideoSurface(),
            ],
          ),
        ),
      ),
    ],
  );

  /// 构建视频渲染面；默认实现保持原有 media_kit [Video] 生命周期不变。
  ///
  /// controls 传 [_buildControls] builder — media_kit 全屏 route 会复制此 builder
  /// (fullscreen.dart:63), 使全屏态自动获得同一份 ControlsOverlay.
  Widget _buildVideoSurface() {
    final testSurface = widget.videoSurfaceBuilder;
    if (testSurface != null) return testSurface(_videoKey);

    final controller = widget.mediaKitController;
    if (controller == null) return const SizedBox.expand();
    return Video(
      key: _videoKey,
      controller: controller,
      controls: _buildControls,
    );
  }

  /// Video.controls builder — 符合 `Widget Function(VideoState)` 签名.
  ///
  /// 闭包捕获稳定对象(engine/_actions/playlist/currentFileName 等),在 Video
  /// 渲染时(含全屏 route)调用. isFullscreen 从 VideoState 现取,不陈旧
  /// (窗口态/全屏态是不同 Video 实例,各自 builder 拿到正确值).
  Widget _buildControls(VideoState state) {
    return ControlsOverlay(
      engine: widget.engine,
      actions: _actions,
      currentFileName: widget.controller.currentFileName,
      playlist: widget.playlist,
      playlistGeneration: widget.playlistGeneration,
      openFileEnabled: _isOpenFileEnabled,
      emptyState: widget.emptyState,
      isFullscreen: state.isFullscreen(),
      // 传本实例 VideoState — _toggleFullscreen 用它做 route 切换(每实例自动
      // enter/exit, 修复症状④). 窗口态/全屏态是不同 Video 实例, 各自传各自的 state.
      videoState: state,
      resizing: widget.windowService.isResizing,
      visibleSink: _controlsVisible,
    );
  }
}
