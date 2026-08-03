import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../kernel/engine/engine_state.dart';
import '../../kernel/playlist/playlist.dart';
import '../theme/tokens.dart';
import '../shared/osd_overlay.dart';
import 'auto_hide_controller.dart';
import 'control_bar.dart';
import 'error_banner.dart';
import 'player_actions.dart';

/// ValueNotifier 重建审计参考模式（02-02 审计结果）
///
/// 审计范围：ui/ 目录下所有 ValueListenableBuilder 实例
/// 审计维度：child 缓存、notifier 合并、重建基线、不必要的监听
///
/// 结论：所有实例均已优化，无需修改。
///
/// - controls_overlay: child 缓存 Stack（静态子树）
/// - control_bar: AnimatedBuilder + opacity child（D-13 模式）
/// - progress_bar: MergedListenable（position+duration+drag），
///   hover tooltip 无法缓存（依赖 hover 状态）
/// - volume_controls: ValueListenableBuilder2 双 notifier，Slider 依赖 volume
/// - speed_button: 箭头为 StatelessWidget 局部变量引用（不重建），中间段依赖 speed
/// - playlist_panel: 内容依赖 _selectedTab，无法缓存
/// - player_screen: playlistVisible 的 child 缓存 videoContent，
///   emptyState 的 child 缓存 Positioned.fill(emptyState)
///
/// D-12 目标：child 缓存 + MergedListenable 已在位，定性分析支持现有优化。

/// 控制栏容器 — 鼠标移动时显示，静止后自动隐藏
///
/// 手势统一处理：单击空白区域隐藏控制栏，双击切换全屏。
/// ControlBar 按钮通过子 GestureDetector 优先赢得手势竞技场，不触发隐藏。
///
/// 住进 media_kit `Video.controls` builder 后，本控件必须**自驱动**重建：
/// builder 在 Video 渲染时调用，不在 PlayerScreen build 上下文，故 build 内部用
/// `ListenableBuilder(merge[engine.state, currentFileName])` 自行监听状态变化，
/// 算 isIdle / title / emptyStateActive。`isFullscreen` 不需监听 — 窗口态与全屏态
/// 是两个不同的 Video 实例，各自 builder 在构建时拿到正确的 `state.isFullscreen()`。
class ControlsOverlay extends StatefulWidget {
  // 对齐 media_kit 原生 onTapUp 400ms 双击窗口(原 250ms 偏短)
  static const _clickDelayMs = 400; // 等待可能的双击
  final MediaEngine engine;
  final PlayerActions actions;

  /// 活动文件名 — 驱动 ControlBar 标题 + 空状态判定(hasMedia 依赖它)。
  final ValueListenable<String> currentFileName;

  /// 播放列表 — playMode 下沉到 LeftButtonGroup 内部读 mode。
  final Playlist playlist;

  /// 播放模式间接驱动源 — 切换 mode 时 generation++ 触发 LeftButtonGroup 重建。
  final ValueListenable<int> playlistGeneration;

  /// 空状态页 — 空状态(idle && !hasMedia)时在 Stack 最底层渲染。
  /// 住进 builder 后必须随控件内化，否则外层 emptyState 会盖住 ControlBar。
  final Widget? emptyState;

  /// 打开文件入口可用性 — 空置页刚出现时隔离打开入口，等待旧媒体纹理退场。
  final ValueListenable<bool> openFileEnabled;

  /// 全屏状态 — 传递给 AutoHideController 控制隐藏延迟
  final bool isFullscreen;

  /// 本实例的 media_kit [VideoState] — 用于走原生全屏 route 切换.
  ///
  /// 症状④根因:`actions.onToggleFullscreen` 闭包在 PlayerScreen initState
  /// 构造, 拿不到全屏态 VideoState(另一实例), 只能用窗口态 `_videoKey` →
  /// `isFullscreen()` 永远 false → 退出全屏反而再 enter → route 冲突 →
  /// 渲染出错. 改为每实例用自己的 [videoState]: 窗口态 `isFullscreen()=false`
  /// →enter, 全屏态 `=true`→exit, 自动正确分支.
  /// 见 memory [[project_fullscreen_minimal_fix]] 症状④.
  final VideoState? videoState;

  /// 窗口 resize 信号 — 传递给 ControlBar 跳过 BackdropFilter
  final ValueListenable<bool>? resizing;

  /// 控件可见性同步 sink — 单向(_autoHide.visible → sink),供 PlayerScreen
  /// 联动全屏鼠标隐藏 + 字幕上移. sink 不回写,防回环.
  final ValueNotifier<bool>? visibleSink;

  const ControlsOverlay({
    super.key,
    required this.engine,
    required this.currentFileName,
    required this.playlist,
    required this.playlistGeneration,
    required this.openFileEnabled,
    this.actions = const PlayerActions(),
    this.emptyState,
    this.isFullscreen = false,
    this.videoState,
    this.resizing,
    this.visibleSink,
  });

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay>
    with TickerProviderStateMixin {
  /// TickerProviderStateMixin: AutoHideController + _animController 各需一个 ticker
  late final AutoHideController _autoHide;
  final _popupCloseNotifier = ValueNotifier<int>(0);
  Timer? _clickTimer;

  /// 共享 AnimationController — 驱动 resize 淡出/淡入和 decoration 状态切换
  /// 150ms，初始 value=1.0（不 resize 时完全可见）
  late final AnimationController _animController;

  /// CurvedAnimation — easeOut 曲线，用于 resize 期间的 opacity 渐变（D-05/D-07）
  late final Animation<double> _resizeOpacity;

  /// resize 状态标记 — resize 期间忽略 engine 状态变化，避免 controller 竞争（Pitfall 2）
  bool _isResizing = false;

  /// 全屏切换过渡标记 — 跳过 isResizing 触发的控制栏淡出。
  ///
  /// 全屏切换 (F键/双击) 触发 isResizing=true 时，reverse() 会让控制栏
  /// 闪烁消失。此标记在 isFullscreen 变化时设置，在 resize 结束时清除。
  bool _isFullscreenTransition = false;

  /// 同步 _autoHide.visible 到外部 sink — 单向(_autoHide.visible → sink),防回环.
  /// 供 PlayerScreen 联动全屏鼠标隐藏 + 字幕上移.
  void _syncVisible() {
    widget.visibleSink?.value = _autoHide.visible.value;
  }

  /// 切换全屏 — 双击与全屏按钮共用入口.
  ///
  /// 两步:① `actions.onToggleFullscreen` 同步 WindowService mode(守卫 + 鼠标
  /// 隐藏联动);② `videoState.toggleFullscreen()` 走 media_kit 原生 route
  /// (push/pop PageRouteBuilder). 关键:用**本实例**的 [widget.videoState] 而非
  /// PlayerScreen 的窗口态 `_videoKey` — 窗口态 isFullscreen()=false→enter,
  /// 全屏态 isFullscreen()=true→exit, 自动正确分支(修复症状④退出渲染出错).
  void _toggleFullscreen() {
    widget.actions.onToggleFullscreen?.call();
    widget.videoState?.toggleFullscreen();
  }

  @override
  void initState() {
    super.initState();
    _autoHide = AutoHideController(
      vsync: this,
      engineState: widget.engine.state,
      isFullscreen: widget.isFullscreen,
      popupCloseNotifier: _popupCloseNotifier,
    );
    widget.engine.state.addListener(_onEngineStateChanged);
    _autoHide.init();

    // 创建共享 AnimationController — 初始 value=1.0（不 resize 时完全可见）
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationNormal),
      value: 1.0,
    );
    _resizeOpacity = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    // 监听 resize 信号变化
    widget.resizing?.addListener(_onResizeChanged);
    // CB-06: 防御性同步 — widget 创建时 resizing 可能已为 true
    if (widget.resizing?.value == true) _onResizeChanged();

    // 同步控件可见性到外部 sink(全屏鼠标隐藏 + 字幕上移联动)
    _autoHide.visible.addListener(_syncVisible);
    _syncVisible(); // 立即同步初始状态
  }

  // TODO: 消费 Tokens.tapJitterThreshold — 当前使用 GestureDetector.onTap，
  // 未来如需区分 tap/drag（添加 _onPointerDown/_onPointerUp），用此常量作为 18px 抖动容差
  void _handleTap() {
    if (_clickTimer?.isActive ?? false) {
      // 第二次点击在延迟内 → 双击，切换全屏
      _clickTimer?.cancel();
      _toggleFullscreen();
    } else {
      // D-04: 第一次点击 → 立即隐藏（不等 250ms 延迟）
      if (widget.engine.state.value != MediaState.idle) {
        _autoHide.hide();
      }
      // Timer 仅用于双击检测窗口（250ms 内第二次点击 → 全屏切换）
      // 空回调 — Timer.isActive 用于判断是否在双击窗口内，超时自动失效
      _clickTimer = Timer(
        const Duration(milliseconds: ControlsOverlay._clickDelayMs),
        () {},
      );
    }
  }

  /// resize 信号变化回调 — resizing=true 时 reverse() 淡出，false 时根据 engine 状态恢复装饰（D-07）
  ///
  /// T3: 全屏切换期间 (isFullscreenTransition=true) 跳过 reverse()，
  /// 避免控制栏因 isResizing 信号闪烁消失。
  void _onResizeChanged() {
    final resizing = widget.resizing?.value ?? false;
    // CB-06: 同步 AutoHideController — resize 期间冻结隐藏计时器
    _autoHide.resizing = resizing;
    if (resizing) {
      _isResizing = true;
      if (!_isFullscreenTransition) {
        // 仅用户拖拽调整窗口大小时淡出，全屏切换不触发
        _animController.reverse(); // 1.0 → 0.0，150ms easeOut
      }
    } else {
      _isResizing = false;
      _isFullscreenTransition = false; // 清除标记，恢复正常 resize 行为
      // resize 结束后根据 engine 状态恢复正确装饰
      final isIdle = widget.engine.state.value == MediaState.idle;
      if (isIdle) {
        _animController.reverse(); // 恢复到 idle 装饰
      } else {
        _animController.forward(); // 恢复到 playing 装饰
      }
    }
  }

  void _onEngineStateChanged() {
    // resize 期间忽略 engine 状态变化，避免 controller 竞争（Pitfall 2）
    if (_isResizing) return;
    _autoHide.onEngineStateChanged();

    // engine 状态变化驱动 decoration 切换：idle→reverse（淡出），playing→forward（淡入）
    final isIdle = widget.engine.state.value == MediaState.idle;
    if (isIdle) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFullscreen != widget.isFullscreen) {
      _autoHide.isFullscreen = widget.isFullscreen;
      // T3: 标记全屏切换过渡 — 下次 isResizing=true 时跳过 reverse()
      _isFullscreenTransition = true;
    }
    // resizing 监听迁移 — 旧值移除，新值添加（CB-06: 同步当前值）
    if (oldWidget.resizing != widget.resizing) {
      oldWidget.resizing?.removeListener(_onResizeChanged);
      widget.resizing?.addListener(_onResizeChanged);
      _onResizeChanged();
    }
    // visibleSink 变化 — 立即同步一次到新 sink(listener 仍在 _autoHide.visible 上)
    if (oldWidget.visibleSink != widget.visibleSink) {
      _syncVisible();
    }
  }

  @override
  void dispose() {
    widget.engine.state.removeListener(_onEngineStateChanged);
    widget.resizing?.removeListener(_onResizeChanged);
    _autoHide.visible.removeListener(_syncVisible);
    _clickTimer?.cancel();
    _popupCloseNotifier.dispose();
    _animController.dispose();
    _autoHide.dispose();
    super.dispose();
  }

  /// 空状态页 — 仅 idle && !hasMedia 时渲染，IgnorePointer 透传让 ControlBar 可点。
  /// openFileEnabled VLB 自驱动：空置页刚出现时隔离打开入口，等待旧媒体纹理退场。
  Widget _buildEmptyState(bool active) {
    if (!active) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: widget.openFileEnabled,
      builder: (_, enabled, _) => IgnorePointer(
        ignoring: !enabled,
        child: widget.emptyState!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 自驱动：builder 化后不依赖外层 ListenableBuilder，本控件自行监听
    // engine.state(算 isIdle) + currentFileName(算 title + hasMedia 判定)。
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.engine.state,
        widget.currentFileName,
      ]),
      builder: (context, _) {
        final isIdle = widget.engine.state.value == MediaState.idle;
        // emptyStatePresent 等价判定：idle && !hasMedia（hasMedia 依赖 currentFileName）
        final emptyActive =
            widget.emptyState != null && isIdle && !widget.engine.hasMedia;
        final fileName = widget.currentFileName.value;
        final title = fileName.isEmpty ? null : fileName;
        // idle + emptyState 时只对上方空白区域禁用手势，ControlBar 始终可交互
        final gestureActive = !emptyActive;
        return Stack(
          children: [
            // 最底层:空状态页(空状态时显示,在 ControlBar 之下).
            // 住进 builder 后必须在此渲染 — 否则外层 emptyState 会盖住 ControlBar.
            if (widget.emptyState != null)
              Positioned.fill(child: _buildEmptyState(emptyActive)),
            // 手势区:单击/双击 — 仅覆盖 ControlBar 上方空白(不覆盖 ControlBar,
            // 按钮可点). emptyActive 时 IgnorePointer 让下方空状态页收点击.
            Positioned.fill(
              bottom: Tokens.controlBarMarginBottom + Tokens.controlBarHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: gestureActive ? _handleTap : null,
                child: IgnorePointer(
                  ignoring: emptyActive,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            // 下层控制栏区域 — OSD / ControlBar / ErrorBanner 各自独立 Positioned，
            // 不再用单一 IgnorePointer 包裹整层（原方案在 visible=false 时连累
            // ErrorBanner 不可点 —— P3 根因）。
            RepaintBoundary(
              child: Stack(
                children: [
                  // OSD — 独立,不受控制栏可见性影响
                  Positioned(
                    bottom:
                        Tokens.controlBarMarginBottom +
                        Tokens.controlBarHeight +
                        12,
                    left: Tokens.controlBarMarginH,
                    right: Tokens.controlBarMarginH,
                    child: OsdOverlay(resizing: widget.resizing),
                  ),
                  // ControlBar — visible=false 时 Visibility 从 hit-test 树移除,
                  // 避免透明 ControlBar 抢点击;FadeTransition 仅驱动淡入/淡出动画。
                  // visible 在 fade-out dismissed 后才变 false,故淡出动画完整播放后再移除。
                  ValueListenableBuilder<bool>(
                    valueListenable: _autoHide.visible,
                    builder: (_, isVisible, _) => Positioned(
                      left: Tokens.controlBarMarginH,
                      right: Tokens.controlBarMarginH,
                      bottom: Tokens.controlBarMarginBottom,
                      child: Visibility(
                        visible: isVisible,
                        maintainState: true,
                        maintainAnimation: true,
                        child: FadeTransition(
                          opacity: _autoHide.opacity,
                          child: ControlBar(
                            engine: widget.engine,
                            actions: widget.actions,
                            playlist: widget.playlist,
                            playlistGeneration: widget.playlistGeneration,
                            isIdle: isIdle,
                            title: title,
                            opacity: _resizeOpacity,
                            enableBlur: isVisible,
                            decoration: _animController,
                            resizing: widget.resizing,
                            // 全屏切换 — 传 _toggleFullscreen 而非 actions.onToggleFullscreen:
                            // 需同时做 setMode 同步 + 本实例 videoState route 切换.
                            onToggleFullscreen: _toggleFullscreen,
                            // seek 钩子 — 拖动进度条期间冻结 auto-hide
                            onSeekStart: _autoHide.onSeekStart,
                            onSeekEnd: _autoHide.onSeekEnd,
                            // 音量等非 seek 子控件复用同一交互会话，避免各自维护 Timer。
                            onInteractionStart: _autoHide.onInteractionStart,
                            onInteractionEnd: _autoHide.onInteractionEnd,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ErrorBanner — 独立可见且始终可点,不被控制栏可见性连累(P3 修复)
                  Positioned(
                    left: Tokens.controlBarMarginH + 16,
                    right: Tokens.controlBarMarginH + 16,
                    bottom:
                        Tokens.controlBarMarginBottom + Tokens.controlBarHeight + 8,
                    child: RepaintBoundary(
                      child: ErrorBanner(
                        engine: widget.engine,
                        onOpenFile: widget.actions.onOpenFile,
                        onRetry: widget.actions.onOpenFile,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 顶层:整区 MouseRegion — opaque=false 不阻止 ControlBar 收 tap/hover,
            // 但跟踪鼠标进出整个 Video. 修复"鼠标从空白移到 ControlBar 触发 onExit
            // → 3s 后控件消失"的现有 bug:整区覆盖 ControlBar,移入不 onExit,
            // _hovering 保持 true, timer 到期 if(!_hovering) hide() 不执行.
            // onHover 仍仅底部 150px 唤起(保留用户"底部触发"意图); onEnter/onExit 整区.
            Positioned.fill(
              child: MouseRegion(
                opaque: false,
                hitTestBehavior: HitTestBehavior.translucent,
                onHover: (event) {
                  // D-03: 仅底部区域触发 — 鼠标在距底部 150px 内才唤起控制栏
                  final size = context.size;
                  if (size == null) return;
                  final mouseFromBottom = size.height - event.localPosition.dy;
                  if (mouseFromBottom < Tokens.bottomTriggerZoneHeight) {
                    _autoHide.onMouseMove();
                  }
                },
                onEnter: (_) => _autoHide.onMouseEnter(),
                onExit: (_) => _autoHide.onMouseExit(),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}
