import '../../kernel/engine/engine_state.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 自动隐藏控制器 — 管理控制栏可见性、淡入淡出动画、自动隐藏定时器、鼠标悬停节流
///
/// 从 ControlsOverlay 提取，独立可测试。
/// idle 状态下控制栏永久显示，不自动隐藏。
class AutoHideController {
  AutoHideController({
    required TickerProvider vsync,
    required ValueNotifier<MediaState> engineState,
    required bool isFullscreen,
    ValueNotifier<int>? popupCloseNotifier,
  }) : _engineState = engineState,
       _isFullscreen = isFullscreen,
       _popupCloseNotifier = popupCloseNotifier {
    _animController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: Tokens.durationFade),
      value: 1,
    );
    // D-02: easeInOut 对称曲线 — 出现和消失速度一致
    _opacity = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    // fade-out 完成后立即关闭 hit test，避免透明 overlay 拦截点击
    _animController.addStatusListener(_onAnimStatus);
  }

  final ValueNotifier<MediaState> _engineState;
  final ValueNotifier<int>? _popupCloseNotifier;
  bool _isFullscreen;
  late final AnimationController _animController;
  late final Animation<double> _opacity;

  bool _hovering = false;
  bool _resizing = false;
  Timer? _hideTimer;
  DateTime _lastHoverTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _hoverThrottle = Duration(milliseconds: 100);

  /// 可见性通知器（用于 ValueListenableBuilder 局部重建）
  final ValueNotifier<bool> visible = ValueNotifier(true);

  /// 淡入淡出动画（用于 FadeTransition）
  Animation<double> get opacity => _opacity;

  /// 是否正在悬停
  bool get isHovering => _hovering;

  /// 更新全屏状态（窗口/全屏切换时调用）
  set isFullscreen(bool value) {
    _isFullscreen = value;
    scheduleHide();
  }

  Duration get _hideDelay => _isFullscreen
      ? const Duration(seconds: Tokens.hideDelayFullscreen)
      : const Duration(seconds: Tokens.hideDelayWindowed);

  /// 显示控制栏（带动画）
  void show() {
    if (!visible.value) {
      visible.value = true;
      _animController.forward();
    }
  }

  /// 隐藏控制栏（带动画，idle 时不隐藏）
  void hide() {
    if (_engineState.value == MediaState.idle) return;
    if (visible.value) {
      _popupCloseNotifier?.value++;
      _animController.reverse();
    }
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      visible.value = false;
    }
  }

  /// 取消旧 Timer 再设新的，避免多次鼠标移动导致 Timer 堆积
  void scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!_hovering) hide();
    });
  }

  /// 更新 resize 状态 — resize 期间冻结自动隐藏逻辑
  set resizing(bool value) {
    _resizing = value;
    if (value) {
      _hideTimer?.cancel();
    } else {
      scheduleHide();
    }
  }

  /// 鼠标移动（节流 100ms）
  void onMouseMove() {
    if (_engineState.value == MediaState.idle || _resizing) return;
    final now = DateTime.now();
    if (now.difference(_lastHoverTime) < _hoverThrottle) return;
    _lastHoverTime = now;
    show();
    scheduleHide();
  }

  /// 鼠标进入
  void onMouseEnter() {
    _hovering = true;
    show();
    scheduleHide();
  }

  /// 鼠标离开
  void onMouseExit() {
    _hovering = false;
    if (_engineState.value != MediaState.idle) scheduleHide();
  }

  /// 引擎状态变化处理
  void onEngineStateChanged() {
    final s = _engineState.value;
    if (s == MediaState.idle) {
      _hideTimer?.cancel();
      if (!visible.value) {
        visible.value = true;
        _animController.forward();
      }
      return;
    }
    if (s == MediaState.opening || s == MediaState.playing) {
      show();
      // 无论当前是否可见，始终重置隐藏定时器
      scheduleHide();
      return;
    }
    // completed/error/paused 状态下永久显示控制栏，不自动隐藏
    final alwaysShow =
        s == MediaState.paused ||
        s == MediaState.completed ||
        s == MediaState.error;
    if (alwaysShow && !visible.value) {
      show();
      _hideTimer?.cancel();
    }
  }

  /// 初始状态：idle 时永久显示，否则启动自动隐藏
  void init() {
    if (_engineState.value == MediaState.idle) {
      visible.value = true;
      _animController.value = 1;
    } else {
      scheduleHide();
    }
  }

  /// 清理资源
  void dispose() {
    _hideTimer?.cancel();
    _animController.removeStatusListener(_onAnimStatus);
    visible.dispose();
    _animController.dispose();
  }
}
