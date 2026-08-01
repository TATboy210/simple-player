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
      // 对齐 media_kit 原生 150ms 控件淡入淡出(原 durationFade=400ms 偏慢)
      duration: const Duration(milliseconds: Tokens.durationControlsFade),
      value: 1,
    );
    // D-02: easeInOut 对称曲线 — 出现和消失速度一致
    _opacity = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
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

  /// 正在进行的子控件交互数量。
  ///
  /// 进度条、音量滑块和 popup 可能重叠；使用计数而不是单个 bool，确保任一
  /// 交互仍活跃时不会过早恢复自动隐藏。
  int _activeInteractionCount = 0;
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

  /// 取消旧 Timer 再设新的，避免多次鼠标移动导致 Timer 堆积。
  ///
  /// 只有 playing 状态、未 resize 且没有活跃子控件交互时才允许自动隐藏；所有
  /// 调用方均经过此处，避免窗口状态变化绕开交互会话保护。
  void scheduleHide() {
    _hideTimer?.cancel();
    if (_engineState.value != MediaState.playing ||
        _resizing ||
        _activeInteractionCount > 0) {
      return;
    }
    _hideTimer = Timer(_hideDelay, () {
      if (!_hovering && _activeInteractionCount == 0) hide();
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
  ///
  /// 状态策略(对齐 media_kit 原生 + 增强):
  /// - idle: 永显(空状态共存)
  /// - opening: 永显直到 playing(打开文件不过早隐藏控件)
  /// - playing: show + scheduleHide(唯一自动隐藏状态)
  /// - paused/completed/error: 永显(用户需操作)
  void onEngineStateChanged() {
    final s = _engineState.value;
    if (s == MediaState.idle) {
      // 新媒体打开会中断旧手势序列，清除计数避免下一次播放永久不自动隐藏。
      _activeInteractionCount = 0;
      _hideTimer?.cancel();
      if (!visible.value) {
        visible.value = true;
        _animController.forward();
      }
      return;
    }
    // 仅 playing 自动隐藏 — opening/paused/completed/error 永显
    if (s == MediaState.playing) {
      show();
      // 无论当前是否可见，始终重置隐藏定时器
      scheduleHide();
      return;
    }
    // opening/paused/completed/error:永显
    if (!visible.value) {
      show();
    }
    _hideTimer?.cancel();
  }

  /// 开始一个子控件交互会话，并冻结 playing 状态的自动隐藏。
  ///
  /// UI 子组件只报告交互边界，不自行维护隐藏 Timer，避免拖拽、悬停和 popup
  /// 的异步结束顺序造成控制栏提前消失。idle 没有可自动隐藏的控件，保持 no-op。
  void onInteractionStart() {
    if (_engineState.value == MediaState.idle) return;
    _activeInteractionCount++;
    show();
    _hideTimer?.cancel();
  }

  /// 结束一个子控件交互会话；最后一个会话结束后恢复既有隐藏策略。
  void onInteractionEnd() {
    if (_engineState.value == MediaState.idle || _activeInteractionCount == 0) {
      return;
    }
    _activeInteractionCount--;
    if (_activeInteractionCount == 0 && !_resizing) scheduleHide();
  }

  /// 用户开始拖动进度条 — 显示控件并冻结隐藏计时(seek 期间不隐藏).
  ///
  /// 对齐 media_kit 原生 onSeekStart，并复用统一交互会话以保证其他子控件
  /// 同时交互时也不会提前恢复自动隐藏。
  void onSeekStart() => onInteractionStart();

  /// 用户结束拖动进度条 — 在最后一个活跃交互结束后重启隐藏计时。
  void onSeekEnd() => onInteractionEnd();

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
