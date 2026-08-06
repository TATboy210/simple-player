import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/win32_display_enumerator.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/bridge/window_mode.dart';
import '../../kernel/diagnostics/video_texture_resize_probe.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/playlist/playlist.dart';
import '../../kernel/services/playback_controller.dart';
import '../dialogs/settings/settings_overlay_shell.dart';
import '../dialogs/settings/settings_panel_controller.dart';
import '../playlist/playlist_panel.dart';
import '../theme/tokens.dart';
import '../window/custom_title_bar.dart';
import 'player_video_controls.dart';
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

  /// 空置页刚出现时暂时隔离所有“打开文件”入口，等待旧媒体纹理完全退场。
  static const _openFileDelay = Duration(seconds: 2);
  Timer? _openFileDelayTimer;

  /// 打开文件入口可用性 — ValueNotifier 驱动 ControlsOverlay 内的空状态页
  /// IgnorePointer（builder 化后需自驱动，不再靠本层 setState 重建）。
  final ValueNotifier<bool> _isOpenFileEnabled = ValueNotifier(false);

  /// 拖窗纹理重建诊断探针 — 并联 ResizeFrameMetrics, 区分 native 纹理重建(甲)
  /// vs 纯合成缩放(乙). 仅 debug 生效; controller 为 null (测试注入 surface) 时跳过.
  VideoTextureResizeProbe? _textureProbe;

  /// resize 期间锁定的 useRow — 避免跨 breakpointWide 时 Row↔Stack 翻转
  /// 触发 Element 重新挂载 (build 54ms 尖峰, RepaintBoundary 不挡 mount)。
  /// null=未锁定; resize 开始由 listener 置 null, 首次 build 计算并锁定。
  bool? _lockedUseRow;
  bool _resizeLayoutLockActive = false;

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
    // local 捕获 path 消除字段链 `!` (result.files.single.path 不提升)
    if (result != null) {
      final path = result.files.single.path;
      if (path != null) {
        widget.engine.setExternalSubtitle(path);
      }
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
      onOpenSubtitle: () => unawaited(_openSubtitle()),
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
    widget.engine.state.addListener(_syncOpenFileAvailability);
    // Stop 成功会清空活动标题；它也是 hasMedia 从 true 变 false 后的可靠 UI 通知。
    widget.controller.currentFileName.addListener(_syncOpenFileAvailability);
    _syncOpenFileAvailability();
    // resize 边沿锁定 useRow — 防跨 breakpointWide 翻转 (build 54ms 尖峰)。
    widget.windowService.isResizing.addListener(_onResizeForLayoutLock);
    // 阶段2:字幕 padding 由 PlayerVideoControls 内 _autoHide.visible 自驱
    // (每实例调自己 VideoState),不再需本层 _onControlsVisibleChanged 联动.
    // 拖窗纹理重建诊断 — 并联 ResizeFrameMetrics, 区分 resize 延迟根因
    // (native 纹理重建 vs 纯合成缩放). 仅 debug 生效; controller 为 null
    // (测试注入 videoSurfaceBuilder) 时跳过, 不阻塞测试.
    final controller = widget.mediaKitController;
    if (controller != null) {
      _textureProbe = VideoTextureResizeProbe(
        isResizing: widget.windowService.isResizing,
        rect: controller.rect,
        textureId: controller.id,
      );
    }
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

  /// resize 边沿 — 锁定/释放 useRow, 防跨 breakpointWide 翻转 (build 54ms 尖峰)。
  ///
  /// resize 开始: 标记 active, _lockedUseRow 置 null (待首次 LayoutBuilder.build
  ///   计算 — 此处无 constraints, 无法取宽度)。
  /// resize 结束: 清除锁定 + setState 刷新 — LayoutBuilder 此刻可能不重建
  ///   (窗口已稳定无 constraints 变化), 须主动触发用真实宽度重判 useRow。
  void _onResizeForLayoutLock() {
    if (widget.windowService.isResizing.value) {
      _resizeLayoutLockActive = true;
      _lockedUseRow = null;
    } else if (_resizeLayoutLockActive) {
      _resizeLayoutLockActive = false;
      _lockedUseRow = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _openFileDelayTimer?.cancel();
    // 探针先于其余 listener 移除 — 它监听 windowService.isResizing 与
    // controller.rect/id, 须在二者 dispose 前解除绑定 (此处二者生命周期更长,
    // 但保持 dispose 顺序一致性).
    _textureProbe?.dispose();
    widget.controller.currentFileName.removeListener(_syncOpenFileAvailability);
    widget.engine.state.removeListener(_syncOpenFileAvailability);
    widget.windowService.isResizing.removeListener(_onResizeForLayoutLock);
    _isOpenFileEnabled.dispose();
    _playlistState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 缓存视频子树 — LayoutBuilder 无 child 参数,constraints 变化时 builder 每帧执行;
    // 提到 build() 顶层后,LayoutBuilder.builder 闭包捕获此变量复用同一 Video 实例,
    // 不再每帧 new Video → controls → PlayerVideoControls → 整 Stack 重建。
    // 拖窗时 State.build() 不调(isResizing 不传顶层),此变量不重建;
    // widget 真正变化时(PlayerFeature rebuild)build() 自然重调,cachedVideoContent 自然重建。
    final cachedVideoContent = _buildVideoContent(context);
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
              // RepaintBoundary: resize 期间根 layout 变, 标题栏内容静态
              // (标题+4按钮, mode/isAlwaysOnTop 不变则不重建), layer 复用
              // 跳过 repaint — 与 videoContent/PlaylistPanel/SettingsShell
              // 的隔离模式一致.
              RepaintBoundary(child: CustomTitleBar(windowService: widget.windowService)),
              Expanded(
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        return ValueListenableBuilder<(bool, bool)>(
                          valueListenable: _playlistState,
                          builder: (context, state, videoContent) {
                            // videoContent 是 VLB child 参数 (Widget?), 由
                            // cachedVideoContent 传入必非空; early check 提升
                            // 为非空消除 `!` (P0 缓存逻辑不变)
                            if (videoContent == null) {
                              return const SizedBox.shrink();
                            }
                            final (playlistVisible, playlistMounted) = state;
                            final realUseRow =
                                w >= Tokens.breakpointWide && playlistMounted;
                            // resize 期间锁定 useRow — 首次 build 计算, 之后复用,
                            // 防跨 breakpointWide 时 Row↔Stack 翻转触发 Element
                            // 重新挂载 (build 54ms 尖峰, RepaintBoundary 不挡 mount)。
                            final useRow = _resizeLayoutLockActive
                                ? (_lockedUseRow ??= realUseRow)
                                : realUseRow;

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
                                      child: videoContent,
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
                                RepaintBoundary(child: videoContent),
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
                          child: cachedVideoContent,
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

        // resize 期间排除整个 Scaffold 语义树 — AXTree "will not be in the tree"
        // 是 Flutter engine accessibility_bridge 语义更新竞争 (已知 bug, 9+ GH issues)。
        // 根因: resize 时 widget 重建 + media_kit D3D11 纹理重建触发
        // markNeedsSemanticsUpdate, engine 语义树父子关系断裂 → 刷屏。
        // 上一轮 ExcludeSemantics 只包 Video, 但错误源 (node 18) 在 Video 之外
        // (标题栏/播放列表/设置壳 resize 重建) → 扩大到整个 Scaffold。
        // ExcludeSemantics(excluding: resizing) 让子树不参与语义 → 不传播更新 →
        // engine AXTree 不刷新 → 消噪。仅 resize 时排除 (isResizing 驱动),
        // 静止时保留无障碍语义。VLB child 缓存 scaffold, isResizing 仅开始/结束
        // 各变化 1 次 (非每帧重建)。gesture/focus/hit-test 走独立通道不受影响。
        // 代价: resize 期间控制栏/标题栏按钮 tooltip/label 暂不可读 (拖窗时无意义)。
        // 边界点 (isResizing 翻转) 可能各残留 1 次语义树重建 — 持续刷消除。
        final scaffoldSemanticsGuard = ValueListenableBuilder<bool>(
          valueListenable: widget.windowService.isResizing,
          builder: (_, resizing, child) => ExcludeSemantics(
            excluding: resizing,
            // child 由 VLB child 参数传入 (scaffold, 必非空); `??` 兜底消除 `!`
            child: child ?? const SizedBox.shrink(),
          ),
          child: scaffold,
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
          child: scaffoldSemanticsGuard,
        );

        // T1: 始终返回 SmartDragToResizeArea — 保持 Widget 类型一致.
        // 全屏时 enabled=false (IgnorePointer 禁用拖拽但不改类型),
        // canUpdate 始终 true, Element 复用, Texture 子树不被销毁.
        // 阶段2:全屏鼠标隐藏由 PlayerVideoControls 内 _autoHide.visible 驱动
        // (controls MouseRegion cursor)。本层仅窗口态 defer / 全屏 basic。
        return MouseRegion(
          cursor: isFullscreen ? SystemMouseCursors.basic : MouseCursor.defer,
          child: SmartDragToResizeArea(
            enabled: !isFullscreen,
            child: keyboardHandler,
          ),
        );
      },
    );
  }

  /// 视频内容区 — DropHandler 包裹 media_kit [Video] (controls 住进 builder).
  ///
  /// 渐进路径核心:ControlsOverlay + emptyState 都住进 Video.controls builder,
  /// media_kit 全屏 route 复制 builder 时自动携带控制栏(解决全屏控制栏消失).
  /// engine/VideoController/videoKey/全屏机制不变,数据源暂留 engine.
  // context 参数保留以维持签名一致性 (Video.controls builder 契约),
  // 但 _buildVideoContent 提到 build() 顶层后不再使用 — 命名 _ 豁免 DCM avoid-unused-parameters.
  Widget _buildVideoContent(BuildContext _) => Row(
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
    // ExcludeSemantics: media_kit Video 拖窗时 D3D11 纹理重建触发 markNeedsSemanticsUpdate,
    // engine AXTree 更新 race 致 "will not be in the tree" 刷屏 (Flutter engine 已知 bug,
    // 零功能影响)。排除 Video 子树 semantics → texture 重建不再触发 semantics 更新 → 消噪。
    // 代价: Video.controls 内控制栏 tooltip/label 一并排除 (视频播放器无障碍优先级低)。
    // gesture/focus/hit-test 不受影响 (走独立通道,非 semantics),按钮仍可点可聚焦。
    return ExcludeSemantics(
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.windowService.isResizing,
        builder: (_, resizing, _) => Video(
          key: _videoKey,
          controller: controller,
          controls: _buildControls,
          // resize 期间用 none 跳过双线性重采样 (raster 尖峰, 根因乙纯合成缩放)。
          // Video.didUpdateWidget (video_texture.dart:258-260) 处理 filterQuality
          // 变化, Element 复用不重新挂载。静止用 low 保画质。isResizing 仅开始/结束各变 1 次。
          filterQuality:
              resizing ? FilterQuality.none : FilterQuality.low,
        ),
      ),
    );
  }

  /// Video.controls builder — 符合 `Widget Function(VideoState)` 签名.
  ///
  /// 闭包捕获稳定对象(engine/_actions/playlist/currentFileName 等),在 Video
  /// 渲染时(含全屏 route)调用. isFullscreen 从 VideoState 现取,不陈旧
  /// (窗口态/全屏态是不同 Video 实例,各自 builder 拿到正确值).
  Widget _buildControls(VideoState state) {
    // 路径B:返回 playerVideoControls(直连 player.stream),非 ControlsOverlay.
    // isFullscreen/videoState 不再显式传 — PlayerVideoControls 内部从 state
    // 现取(每实例独立,修复"图标不动态"). 闭包捕获的其余稳定对象不变.
    return playerVideoControls(
      state,
      engine: widget.engine,
      actions: _actions,
      currentFileName: widget.controller.currentFileName,
      playlist: widget.playlist,
      playlistGeneration: widget.playlistGeneration,
      openFileEnabled: _isOpenFileEnabled,
      emptyState: widget.emptyState,
      resizing: widget.windowService.isResizing,
    );
  }
}
