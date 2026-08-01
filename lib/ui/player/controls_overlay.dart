import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
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
class ControlsOverlay extends StatefulWidget {
  // 对齐 media_kit 原生 onTapUp 400ms 双击窗口(原 250ms 偏短)
  static const _clickDelayMs = 400; // 等待可能的双击
  final MediaEngine engine;
  final PlayerActions actions;

  /// 空状态存在时，控制栏不拦截 hit test（让下层 EmptyState 按钮可点击）
  final bool emptyStatePresent;

  /// 全屏状态 — 传递给 AutoHideController 控制隐藏延迟
  final bool isFullscreen;

  /// 窗口 resize 信号 — 传递给 ControlBar 跳过 BackdropFilter
  final ValueListenable<bool>? resizing;

  /// 视频标题（传递给 ControlBar Row 1 左侧）
  final String? title;

  /// 控件可见性同步 sink — 单向(_autoHide.visible → sink),供 PlayerScreen
  /// 联动全屏鼠标隐藏 + 字幕上移. sink 不回写,防回环.
  final ValueNotifier<bool>? visibleSink;

  const ControlsOverlay({
    super.key,
    required this.engine,
    this.actions = const PlayerActions(),
    this.emptyStatePresent = false,
    this.isFullscreen = false,
    this.resizing,
    this.title,
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
      widget.actions.onToggleFullscreen?.call();
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

  @override
  Widget build(BuildContext context) {
    final isIdle = widget.engine.state.value == MediaState.idle;
    // idle + emptyState 时只对上方空白区域禁用手势，ControlBar 始终可交互
    final gestureActive = !(widget.emptyStatePresent && isIdle);
    return Stack(
      children: [
        // 底层:单击/双击手势区 — 仅覆盖 ControlBar 上方空白(不覆盖 ControlBar,
        // 按钮可点). idle+emptyState 时 IgnorePointer 让下方 EmptyState 收点击.
        Positioned.fill(
          bottom: Tokens.controlBarMarginBottom + Tokens.controlBarHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: gestureActive ? _handleTap : null,
            child: IgnorePointer(
              ignoring: widget.emptyStatePresent && isIdle,
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
                        isIdle: isIdle,
                        title: widget.title,
                        opacity: _resizeOpacity,
                        enableBlur: isVisible,
                        decoration: _animController,
                        resizing: widget.resizing,
                        // seek 钩子 — 拖动进度条期间冻结 auto-hide
                        onSeekStart: _autoHide.onSeekStart,
                        onSeekEnd: _autoHide.onSeekEnd,
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
  }
}
