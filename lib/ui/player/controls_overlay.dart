import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:player_engine/player_engine.dart';
import '../theme/tokens.dart';
import '../shared/osd_overlay.dart';
import '../shared/transmitted_light.dart';
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
/// - progress_bar: MergedListenable（position+duration+buffered+drag），
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
  static const _clickDelayMs = 250; // 等待可能的双击
  final PlayerEngine engine;
  final PlayerActions actions;

  /// 空状态存在时，控制栏不拦截 hit test（让下层 EmptyState 按钮可点击）
  final bool emptyStatePresent;

  /// 全屏状态 — 传递给 AutoHideController 控制隐藏延迟
  final bool isFullscreen;

  /// 窗口 resize 信号 — 传递给 ControlBar 跳过 BackdropFilter
  final ValueListenable<bool>? resizing;

  /// 视频标题（传递给 ControlBar Row 1 左侧）
  final String? title;

  const ControlsOverlay({
    super.key,
    required this.engine,
    this.actions = const PlayerActions(),
    this.emptyStatePresent = false,
    this.isFullscreen = false,
    this.resizing,
    this.title,
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
  }

  void _handleTap() {
    if (_clickTimer?.isActive ?? false) {
      // 第二次点击在延迟内 → 双击，切换全屏
      _clickTimer?.cancel();
      widget.actions.onToggleFullscreen?.call();
    } else {
      // 第一次点击 → 等待可能的第二次点击
      _clickTimer = Timer(
        const Duration(milliseconds: ControlsOverlay._clickDelayMs),
        () {
          if (!mounted) return;
          if (widget.engine.state.value == MediaState.idle) return;
          _autoHide.hide();
        },
      );
    }
  }

  /// resize 信号变化回调 — resizing=true 时 reverse() 淡出，false 时 forward() 淡入（D-07）
  void _onResizeChanged() {
    final resizing = widget.resizing?.value ?? false;
    if (resizing) {
      _isResizing = true;
      _animController.reverse(); // 1.0 → 0.0，150ms easeOut
    } else {
      _isResizing = false;
      _animController.forward(); // 0.0 → 1.0，150ms easeOut
    }
  }

  void _onEngineStateChanged() {
    // resize 期间忽略 engine 状态变化，避免 controller 竞争（Pitfall 2）
    if (_isResizing) return;
    _autoHide.onEngineStateChanged();
  }

  @override
  void didUpdateWidget(covariant ControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFullscreen != widget.isFullscreen) {
      _autoHide.isFullscreen = widget.isFullscreen;
    }
    // resizing 监听迁移 — 旧值移除，新值添加
    if (oldWidget.resizing != widget.resizing) {
      oldWidget.resizing?.removeListener(_onResizeChanged);
      widget.resizing?.addListener(_onResizeChanged);
    }
  }

  @override
  void dispose() {
    widget.engine.state.removeListener(_onEngineStateChanged);
    widget.resizing?.removeListener(_onResizeChanged);
    _clickTimer?.cancel();
    _popupCloseNotifier.dispose();
    _animController.dispose();
    _autoHide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIdle = widget.engine.state.value == MediaState.idle;
    final gestureActive = !(widget.emptyStatePresent && isIdle);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: gestureActive ? _handleTap : null,
      child: IgnorePointer(
        // idle 时让 EmptyState 接收点击；播放中控制栏必须可交互
        ignoring: widget.emptyStatePresent && isIdle,
        child: MouseRegion(
          opaque: false,
          hitTestBehavior: HitTestBehavior.translucent,
          onHover: (_) => _autoHide.onMouseMove(),
          onEnter: (_) => _autoHide.onMouseEnter(),
          onExit: (_) => _autoHide.onMouseExit(),
          child: ValueListenableBuilder<bool>(
            valueListenable: _autoHide.visible,
            builder: (_, isVisible, child) =>
                IgnorePointer(ignoring: !isVisible, child: child),
            child: RepaintBoundary(
              child: Stack(
                children: [
                  // 光透射效果 — 控制栏下方的蓝色辉光
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: Tokens.controlBarHeight + 60,
                    child: TransmittedLight(
                      type: TransmissionType.bottom,
                      intensity: 0.6,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    bottom:
                        Tokens.controlBarMarginBottom +
                        Tokens.controlBarHeight +
                        12,
                    left: Tokens.controlBarMarginH,
                    right: Tokens.controlBarMarginH,
                    child: OsdOverlay(resizing: widget.resizing),
                  ),
                  Positioned(
                    left: Tokens.controlBarMarginH,
                    right: Tokens.controlBarMarginH,
                    bottom: Tokens.controlBarMarginBottom,
                    child: FadeTransition(
                      opacity: _autoHide.opacity,
                      child: ControlBar(
                        engine: widget.engine,
                        actions: widget.actions,
                        isIdle: isIdle,
                        title: widget.title,
                        opacity: _autoHide.opacity,
                        enableBlur: _autoHide.visible.value,
                        resizing: widget.resizing,
                        decoration: _animController,
                      ),
                    ),
                  ),
                  Positioned(
                    left: Tokens.controlBarMarginH + 16,
                    right: Tokens.controlBarMarginH + 16,
                    bottom:
                        Tokens.controlBarMarginBottom +
                        Tokens.controlBarHeight +
                        8,
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
          ),
        ),
      ),
    );
  }
}
