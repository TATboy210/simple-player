import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:player_engine/player_engine.dart';
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
    with SingleTickerProviderStateMixin {
  late final AutoHideController _autoHide;
  final _popupCloseNotifier = ValueNotifier<int>(0);
  Timer? _clickTimer;

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
  }

  Offset? _pointerDownPos;

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPos = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    final downPos = _pointerDownPos;
    _pointerDownPos = null;
    if (downPos == null) return;

    // 允许 18px 的手指抖动容差
    final dx = (event.localPosition.dx - downPos.dx).abs();
    final dy = (event.localPosition.dy - downPos.dy).abs();
    if (dx > 18 || dy > 18) return;

    if (_clickTimer?.isActive ?? false) {
      _clickTimer?.cancel();
      // 控制栏区域内的双击不触发全屏（留给倍速重置等子控件处理）
      if (!_isInControlBar(event.localPosition)) {
        widget.actions.onToggleFullscreen?.call();
      }
    } else {
      // 第一次点击 → 等待可能的第二次点击
      // 控制栏区域内的点击不触发隐藏（留给按钮处理）
      if (!_isInControlBar(event.localPosition)) {
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
  }

  /// 判断点击位置是否在控制栏区域内（精确边界匹配）
  bool _isInControlBar(Offset local) {
    final size = context.size;
    if (size == null) return false;
    final cbLeft = Tokens.controlBarMarginH;
    final cbRight = size.width - Tokens.controlBarMarginH;
    final cbBottom = size.height - Tokens.controlBarMarginBottom;
    final cbTop = cbBottom - Tokens.controlBarHeight;
    return local.dx >= cbLeft &&
        local.dx <= cbRight &&
        local.dy >= cbTop &&
        local.dy <= cbBottom;
  }

  void _onEngineStateChanged() => _autoHide.onEngineStateChanged();

  @override
  void didUpdateWidget(covariant ControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFullscreen != widget.isFullscreen) {
      _autoHide.isFullscreen = widget.isFullscreen;
    }
  }

  @override
  void dispose() {
    widget.engine.state.removeListener(_onEngineStateChanged);
    _clickTimer?.cancel();
    _popupCloseNotifier.dispose();
    _autoHide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 直接监听 engine.state — 状态变化自动触发重建，不依赖手动 setState
    return ValueListenableBuilder<MediaState>(
      valueListenable: widget.engine.state,
      builder: (context, engineState, _) {
        final isIdle = engineState == MediaState.idle;
        // 有空状态且引擎空闲时，控制栏不拦截 hit test
        final blockInteraction = widget.emptyStatePresent && isIdle;
        // Listener 接收原始指针事件，不参与手势竞技场 —
        // 子控件按钮的 InkWell 独立处理点击，两者互不干扰。
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: blockInteraction ? null : _onPointerDown,
          onPointerUp: blockInteraction ? null : _onPointerUp,
          child: IgnorePointer(
            ignoring: blockInteraction,
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
                        child: Offstage(
                          offstage: blockInteraction,
                          child: FadeTransition(
                            opacity: _autoHide.opacity,
                            child: ControlBar(
                              engine: widget.engine,
                              actions: widget.actions,
                              isIdle: isIdle,
                              title: widget.title,
                              opacity: _autoHide.opacity,
                              enableBlur: true,
                              resizing: widget.resizing,
                            ),
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
      },
    );
  }
}
