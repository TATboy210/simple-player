import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../kernel/window_bridge/window_manager_service.dart';
import '../../kernel/diagnostics/resize_frame_metrics.dart';
import '../../kernel/diagnostics/video_texture_resize_probe.dart';
import '../../kernel/engine/engine_state.dart';
import '../../kernel/services/playback_controller.dart';
import '../../kernel/services/subtitle_path_validator.dart';
import '../theme/tokens.dart';
import '../dialogs/settings/settings_dialog.dart';
import '../window/custom_title_bar.dart';
import 'player_video_controls.dart';
import 'drop_handler.dart';
import 'player_actions.dart';
import 'player_keyboard_actions.dart';

/// 播放器主屏幕 — 组合窗口壳、视频 surface、键盘与控制层。
///
/// 控制栏位于 media_kit `Video.controls` builder 内，因此全屏 route 会复制同一
/// 控制结构；视频 key、测试 surface 注入和 resize 期间 Element identity 均保持稳定。
class PlayerScreen extends StatefulWidget {
  final MediaEngine engine;

  /// media_kit [VideoController] — UI 用 [Video] widget. 透传自 PlayerServices.
  ///
  /// 生产组合层必须提供该控制器；仅当 [videoSurfaceBuilder] 注入测试渲染面时可为 null，
  /// 避免 widget test 绑定 MDK/libmpv 原生运行时。
  final VideoController? mediaKitController;

  /// 可替换的视频渲染面；默认路径仍使用 media_kit [Video]，不改变其生命周期。
  final Widget Function(GlobalKey<VideoState> videoKey)? videoSurfaceBuilder;

  /// 测试渲染面配套的 controls 端口；仅在 [videoSurfaceBuilder] 注入时使用。
  ///
  /// 生产路径必须由 `Video.controls` 提供当前 route 的 [VideoState]，因此禁止单独
  /// 注入本端口，避免绕过 media_kit 默认 fullscreen route。
  final VideoControlsPort? testVideoControls;

  final PlaybackController controller;
  final WindowBridge windowService;
  final Map<String, String> customBindings;
  final VoidCallback? onOpenFile;
  final void Function(List<String> paths)? onFilesDropped;

  /// 拖拽悬停状态回调，转发给 [DropHandler] 驱动空状态视觉反馈。
  final void Function(bool hovering)? onDragHoverChanged;

  /// 测试可注入字幕选择器，避免 widget test 依赖原生 FilePicker 平台通道。
  ///
  /// `null` 表示用户取消选择；生产路径省略时由 [_pickSubtitlePath] 打开系统选择器。
  final Future<String?> Function()? pickSubtitlePath;
  final Widget? emptyState;

  const PlayerScreen({
    super.key,
    required this.engine,
    this.mediaKitController,
    this.videoSurfaceBuilder,
    this.testVideoControls,
    required this.controller,
    required this.windowService,
    this.customBindings = const {},
    this.onOpenFile,
    this.onFilesDropped,
    this.onDragHoverChanged,
    this.pickSubtitlePath,
    this.emptyState,
  }) : assert(mediaKitController != null || videoSurfaceBuilder != null),
       assert(testVideoControls == null || videoSurfaceBuilder != null);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  /// media_kit Video 的 state key — 供 setSubtitleViewPadding 调用
  /// (控件可见性联动字幕上移). 不再用于全屏切换 (改走 WindowService.setMode).
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();

  /// 空置页刚出现时暂时隔离所有“打开文件”入口的倒计时机制已移除 —
  /// 打开入口常驻可用（用户决策：去倒计时、按钮常驻）。

  /// 主动停止的消散过渡动画 — 驱动视频面淡出+后缩（渐退后缩），完成后
  /// 才执行真正的 stopCurrentMedia，衔接空置态的三段入场编排。
  late final AnimationController _stopExitAnim;
  late final CurvedAnimation _stopExitFade;
  late final Animation<double> _stopExitScale;

  /// 拖窗纹理重建诊断探针 — 并联 ResizeFrameMetrics, 区分 native 纹理重建(甲)
  /// vs 纯合成缩放(乙). 仅 debug 生效; controller 为 null (测试注入 surface) 时跳过.
  VideoTextureResizeProbe? _textureProbe;

  /// resize 帧时序采集器 — 并联 [_textureProbe] 的纹理信号,debug/profile 自启、
  /// release 禁用。每次拖窗 drag+settle 会话输出 build/raster/totalSpan 的
  /// P50/P95/P99 + 60/30fps jank 比例,作为代码侧可重复基线。
  ResizeFrameMetrics? _resizeMetrics;

  /// 稳定化的播放器回调集合 — initState 构造一次，供 controls builder 捕获。
  ///
  /// builder 不在本 State 的 build 上下文内执行，因此回调对象保持稳定，易变播放
  /// 状态继续由 PlayerVideoControls 订阅的 stream/listenable 驱动。
  late final PlayerActions _actions;

  /// 缓存标题栏 widget，避免窗口模式或 resize 导致父级 build 时重新创建标题栏子树。
  ///
  /// 标题栏内部仍自行监听窗口状态；这里只固定外层 widget identity，缩小无关
  /// 重建范围，不冻结全屏透明度、置顶图标和最大化图标等必要更新。
  late Widget _titleBar;

  /// 打开系统字幕选择器并返回用户选择的本地路径。
  Future<String?> _pickSubtitlePath() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'ass', 'ssa', 'sub', 'vtt'],
    );
    return result?.files.single.path;
  }

  /// 选择并加载外部字幕；取消或不可加载的路径不会传给底层解析器。
  Future<void> _openSubtitle() async {
    final selectPath = widget.pickSubtitlePath ?? _pickSubtitlePath;
    final path = await selectPath();
    if (path == null || !mounted) return;

    // 文件可能在 picker 返回后被替换，因此紧邻原生加载前复核类型与大小。
    final isLoadable = await SubtitlePathValidator.isLoadableLocalFile(path);
    if (!isLoadable || !mounted) return;

    widget.engine.setExternalSubtitle(path);
  }

  @override
  void initState() {
    super.initState();
    // 稳定化 actions — initState 构造一次,纯播放/项目回调闭包现读 widget 字段
    // 避免陈旧捕获. playModeIcon/Label 已下沉, 不需 l10n/context.
    _titleBar = RepaintBoundary(
      child: CustomTitleBar(windowService: widget.windowService),
    );
    _stopExitAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.stopExitDurationMs),
      // value 语义: 1 = 正常可见, 0 = 消散完成。初始必须为可见态 —
      // Video.controls 的输出(控制栏/空置态)同属 Video 子树, 若初始为 0
      // 整个内容区会被 opacity 隐藏(实机黑屏回归教训)。
      value: 1,
    );
    _stopExitFade = CurvedAnimation(
      parent: _stopExitAnim,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _stopExitScale = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(_stopExitFade);
    _actions = PlayerActions(
      // actions 保持同一实例以保护 Video subtree identity，但在调用时读取当前
      // widget，避免 controller replacement 后继续把用户命令发送给旧数据源。
      onPlayPause: () => widget.controller.togglePlayPause(),
      onSeekBack: (milliseconds) => widget.controller.skipBack(milliseconds),
      onSeekForward: (milliseconds) =>
          widget.controller.skipForward(milliseconds),
      // 主动停止 → 消散过渡（画面淡出+后缩）完成后再真正卸载媒体，
      // 衔接空置态的三段入场（极光缓入 → 停 1 秒 → 内容显现）。
      onStop: () => unawaited(_stopWithTransition()),
      onOpenFile: () => widget.onOpenFile?.call(),
      onOpenSubtitle: () => unawaited(_openSubtitle()),
      // 设置窗口壳 — 纯 UI 弹层，不改播放状态，无需空置态隔离。
      onOpenSettings: () => unawaited(SettingsDialog.show(context)),
      // setMode 仅同步 WindowService mode(守卫 + 鼠标隐藏联动). media_kit route
      // 切换改由 PlayerVideoControls._toggleFullscreen 用各实例自己的 videoState 完成。
      onToggleFullscreen: () {
        final m = widget.windowService.mode.value;
        final entering = m != WindowMode.fullscreen;
        widget.windowService.setMode(
          entering ? WindowMode.fullscreen : WindowMode.windowed,
        );
      },
      onFilesDropped: (paths) => widget.onFilesDropped?.call(paths),
      onDragHoverChanged: (hovering) =>
          widget.onDragHoverChanged?.call(hovering),
    );
    // 阶段2:字幕 padding 由 PlayerVideoControls 内 _autoHide.visible 自驱
    // (每实例调自己 VideoState),不再需本层 _onControlsVisibleChanged 联动.
    // 拖窗纹理重建诊断 — 并联 ResizeFrameMetrics，分类只描述 Dart 侧
    // controller 信号。测试渲染面没有 controller 时仍创建 probe，以输出
    // probeUnavailable 摘要而非将观测源缺失误记成无信号变化。
    _createTextureProbe();
  }

  /// 主动停止的过渡序列 — 消散（画面淡出+后缩 300ms）→ 卸载媒体 →
  /// 空置态接手（极光缓入 + 内容延迟显现）。重入期间忽略再次触发。
  ///
  /// reverse() 把可见度从 1 渐推到 0；卸载完成后 reset 回 1，与空置态
  /// 出现在同一帧，避免恢复可见时闪现旧内容。
  Future<void> _stopWithTransition() async {
    if (_stopExitAnim.isAnimating) return;
    if (!widget.engine.hasMedia) return;
    await _stopExitAnim.reverse();
    await widget.controller.stopCurrentMedia();
    if (mounted) _stopExitAnim.reset();
  }

  /// 创建与当前窗口桥和视频控制器绑定的 resize 诊断探针。
  ///
  /// windowMode 注入后,会话摘要按模式跨越分类(fullscreen-enter/exit/
  /// resize/drag+settle) — 全屏退出单帧异常的取证维度(C3):退出会话若
  /// 伴随 textureId 变化,指向 native 纹理重建;否则指向合成/布局侧。
  void _createTextureProbe() {
    final controller = widget.mediaKitController;
    _textureProbe = VideoTextureResizeProbe(
      isResizing: widget.windowService.isResizing,
      resizeSessionId: widget.windowService.resizeSessionId,
      rect: controller?.rect,
      textureId: controller?.id,
      windowMode: widget.windowService.mode,
    );
    // 并联纹理探针:采集同一 resize 会话的 build/raster 帧时序(debug/profile)。
    // 复用探针已绑定的 isResizing/resizeSessionId 信号源;dispose 在 dispose() 内。
    _resizeMetrics?.dispose();
    _resizeMetrics = ResizeFrameMetrics(
      isResizing: widget.windowService.isResizing,
      resizeSessionId: widget.windowService.resizeSessionId,
    );
  }

  /// idle 既可能表示尚未加载，也可能表示 stop 正在卸载；两种情况都先隔离打开入口。
  /// （倒计时门禁已随“打开入口常驻”需求移除 — 打开入口不再有任何隔离窗口。）

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowService != widget.windowService) {
      // WindowBridge 是标题栏和 resize probe 的外部依赖；替换时一起迁移，
      // 避免稳定 widget identity 继续持有旧窗口服务的 notifier。
      _titleBar = RepaintBoundary(
        child: CustomTitleBar(windowService: widget.windowService),
      );
    }

    // probe 同时监听窗口 resize 与 controller 的 rect/id；任一来源替换时
    // 都必须解除旧监听，否则诊断会把新窗口会话与旧纹理状态混合。
    if (oldWidget.windowService != widget.windowService ||
        oldWidget.mediaKitController != widget.mediaKitController) {
      _textureProbe?.dispose();
      _createTextureProbe();
    }
  }

  @override
  void dispose() {
    // 探针先于其余 listener 移除 — 它监听 windowService.isResizing 与
    // controller.rect/id, 须在二者 dispose 前解除绑定 (此处二者生命周期更长,
    // 但保持 dispose 顺序一致性).
    _textureProbe?.dispose();
    _resizeMetrics?.dispose();
    _stopExitFade.dispose();
    _stopExitAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 缓存视频子树，使窗口模式变化只重组外层窗口壳，不重新创建 Video。
    // resize 期间的画质切换由视频子树内部 listenable 驱动，Element identity 保持稳定。
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
              // 标题栏 widget identity 在 initState 固定；窗口模式变化只更新
              // 标题栏内部真正依赖 mode 的局部节点，不重建整棵标题栏子树。
              _titleBar,
              Expanded(
                child: Stack(
                  children: [
                    // v1.8 单文件模式不再维护播放列表侧栏，视频 surface 始终占满内容区。
                    RepaintBoundary(child: cachedVideoContent),
                  ],
                ),
              ),
            ],
          ),
        );

        final keyboardHandler = buildPlayerKeyboardActions(
          engine: widget.engine,
          controller: widget.controller,
          actions: _actions,
          windowService: widget.windowService,
          customBindings: widget.customBindings,
          videoKey: _videoKey,
          isFullscreen: isFullscreen,
          context: context,
          // O 键与空置页按钮共享同一稳定窗口，不能绕过媒体释放延迟。
          onOpenFile: () => widget.onOpenFile?.call(),
          child: scaffold,
        );

        // 边缘缩放由 Windows 原生 WM_NCHITTEST 处理；Flutter 层只负责
        // 标题栏/视频内容交互，避免手势层与原生窗口 resize loop 竞争。
        // 全屏鼠标隐藏由 PlayerVideoControls 内 _autoHide.visible 驱动。
        return MouseRegion(
          cursor: isFullscreen ? SystemMouseCursors.basic : MouseCursor.defer,
          child: keyboardHandler,
        );
      },
    );
  }

  /// 视频内容区 — DropHandler 包裹 media_kit [Video] (controls 住进 builder).
  ///
  /// 渐进路径核心:PlayerVideoControls + emptyState 都住进 Video.controls builder,
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
              // Video.controls builder 内含 PlayerVideoControls + emptyState,
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
  /// (fullscreen.dart:63), 使全屏态自动获得同一份 PlayerVideoControls.
  Widget _buildVideoSurface() {
    final testSurface = widget.videoSurfaceBuilder;
    if (testSurface != null) {
      final surface = testSurface(_videoKey);
      final testVideo = widget.testVideoControls;
      if (testVideo == null) return surface;

      // 测试模式叠加真实 controls widget，但端口由纯 Dart fake 提供，既覆盖
      // PlayerScreen 装配，又不初始化 MDK/libmpv。生产路径不会进入该分支。
      return Stack(
        fit: StackFit.expand,
        children: [surface, _buildTestControls(testVideo)],
      );
    }

    final controller = widget.mediaKitController;
    if (controller == null) return const SizedBox.expand();
    return ValueListenableBuilder<bool>(
      valueListenable: widget.windowService.isResizing,
      builder: (_, resizing, _) => FadeTransition(
        // 主动停止的消散过渡 — 淡出 + 0.97 后缩（渐退后缩），paint 阶段
        // 变换不触发布局；完成后 stopCurrentMedia 卸载媒体衔接空置态。
        opacity: _stopExitFade,
        child: ScaleTransition(
          scale: _stopExitScale,
          child: Video(
            key: _videoKey,
            controller: controller,
            controls: _buildControls,
            // resize 期间用 none 跳过双线性重采样 (raster 尖峰, 根因乙纯合成缩放)。
            // Video.didUpdateWidget (video_texture.dart:258-260) 处理 filterQuality
            // 变化，Element 与语义子树均保持挂载；静止时恢复 low 画质。
            filterQuality: resizing ? FilterQuality.none : FilterQuality.low,
          ),
        ),
      ),
    );
  }

  /// 测试 surface 使用的 controls 装配；生产仍只走 [_buildControls]。
  Widget _buildTestControls(VideoControlsPort video) {
    return PlayerVideoControls(
      video: video,
      engine: widget.engine,
      actions: _actions,
      currentFileName: widget.controller.currentFileName,
      windowMode: widget.windowService.mode,
      emptyState: widget.emptyState,
      resizing: widget.windowService.isResizing,
    );
  }

  /// Video.controls builder — 符合 `Widget Function(VideoState)` 签名.
  ///
  /// 闭包捕获稳定对象（engine、actions 与当前文件名），在 Video 渲染时
  ///（含全屏 route）调用；全屏状态由各 route 的 [VideoState] 实例实时提供。
  Widget _buildControls(VideoState state) {
    // 路径B:返回 playerVideoControls(直连 player.stream),非 PlayerVideoControls.
    // isFullscreen/videoState 不再显式传 — PlayerVideoControls 内部从 state
    // 现取(每实例独立,修复"图标不动态"). 闭包捕获的其余稳定对象不变.
    return playerVideoControls(
      state,
      engine: widget.engine,
      actions: _actions,
      currentFileName: widget.controller.currentFileName,
      windowMode: widget.windowService.mode,
      emptyState: widget.emptyState,
      resizing: widget.windowService.isResizing,
    );
  }
}
