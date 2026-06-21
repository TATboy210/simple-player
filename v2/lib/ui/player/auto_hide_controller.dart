import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/events/player_events.dart';
import '../../core/state/playback_state.dart';
import '../../infra/event_bus/event_bus.dart';
import '../theme/tokens.dart';

/// 自动隐藏控制器 — 管理控制栏可见性、淡入淡出动画、自动隐藏定时器
///
/// 从 v1 移植，适配 v2 EventBus 架构。
/// idle 状态下控制栏永久显示，不自动隐藏。
class AutoHideController {
  AutoHideController({
    required TickerProvider vsync,
    required EventBus bus,
    required bool isFullscreen,
  }) : _bus = bus,
       _isFullscreen = isFullscreen {
    _animController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: Tokens.durationFade),
      value: 1,
    );
    _opacity = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.addStatusListener(_onAnimStatus);
    _sub = _bus.on<StateChanged>().listen((e) {
      _state = e.state;
      _onStateChanged();
    });
  }

  final EventBus _bus;
  late final StreamSubscription<StateChanged> _sub;
  PlaybackState _state = PlaybackState.idle;
  bool _isFullscreen;
  late final AnimationController _animController;
  late final Animation<double> _opacity;

  bool _hovering = false;
  Timer? _hideTimer;
  DateTime _lastHoverTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _hoverThrottle = Duration(milliseconds: 100);

  final ValueNotifier<bool> visible = ValueNotifier(true);
  Animation<double> get opacity => _opacity;

  set isFullscreen(bool value) {
    _isFullscreen = value;
    scheduleHide();
  }

  Duration get _hideDelay => _isFullscreen
      ? const Duration(seconds: Tokens.hideDelayFullscreen)
      : const Duration(seconds: Tokens.hideDelayWindowed);

  void show() {
    if (!visible.value) {
      visible.value = true;
      _animController.forward();
    }
  }

  void hide() {
    if (_state == PlaybackState.idle) return;
    if (visible.value && !_hovering) {
      _animController.reverse();
    }
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      visible.value = false;
    }
  }

  void scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!_hovering) hide();
    });
  }

  void onMouseMove() {
    if (_state == PlaybackState.idle) return;
    final now = DateTime.now();
    if (now.difference(_lastHoverTime) < _hoverThrottle) return;
    _lastHoverTime = now;
    show();
    scheduleHide();
  }

  void onMouseEnter() {
    _hovering = true;
    show();
  }

  void onMouseExit() {
    _hovering = false;
    if (_state != PlaybackState.idle) scheduleHide();
  }

  void _onStateChanged() {
    switch (_state) {
      case PlaybackState.idle:
        _hideTimer?.cancel();
        if (!visible.value) {
          visible.value = true;
          _animController.forward();
        }
      case PlaybackState.playing:
      case PlaybackState.opening:
      case PlaybackState.buffering:
        if (!visible.value) {
          show();
          scheduleHide();
        }
      case PlaybackState.paused:
      case PlaybackState.ended:
      case PlaybackState.error:
        if (!visible.value) {
          show();
          _hideTimer?.cancel();
        }
      case PlaybackState.seeking:
        break;
    }
  }

  void init() {
    if (_state == PlaybackState.idle) {
      visible.value = true;
      _animController.value = 1;
    } else {
      scheduleHide();
    }
  }

  void dispose() {
    _sub.cancel();
    _hideTimer?.cancel();
    _animController.removeStatusListener(_onAnimStatus);
    visible.dispose();
    _animController.dispose();
  }
}
