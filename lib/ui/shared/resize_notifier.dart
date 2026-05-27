import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../window/window_lifecycle.dart';
import '../../window/window_service.dart';

/// Resize 期间的窗口尺寸快照
class ResizeState {
  final bool isResizing;
  final Size? currentSize;
  final Size? previousSize;
  const ResizeState({this.isResizing = false, this.currentSize, this.previousSize});
}

/// UI 层共享的 resize 状态（singleton）。
///
/// 委托给 [WindowLifecycleBus.isOperating]，resize **或 move** 期间都为 true。
/// 保留原有 [ValueNotifier<bool>] 接口，现有消费者无需改动。
/// 额外暴露 [resizeDetails] 携带窗口尺寸信息。
class ResizeNotifier extends ValueNotifier<bool> {
  ResizeNotifier._() : super(false) {
    WindowLifecycleBus.instance.isOperating.addListener(_syncFromBus);
    _sub = WindowService.instance.onResize.listen((v) {
      if (value != v) value = v;
    });
    _eventSub = WindowLifecycleBus.instance.events.listen(_onWindowEvent);
  }

  static final ResizeNotifier instance = ResizeNotifier._();

  late final StreamSubscription<bool> _sub;
  late final StreamSubscription<WindowEvent> _eventSub;

  /// 携带窗口尺寸的 resize 状态
  final ValueNotifier<ResizeState> resizeDetails =
      ValueNotifier(const ResizeState());

  Size? _lastSize;

  void _syncFromBus() {
    final busVal = WindowLifecycleBus.instance.isOperating.value;
    if (value != busVal) value = busVal;
  }

  void _onWindowEvent(WindowEvent event) {
    if (event.isResize) {
      if (event.isStart) {
        _lastSize = event.size;
        resizeDetails.value = ResizeState(
          isResizing: true,
          currentSize: event.size,
          previousSize: _lastSize,
        );
      } else {
        resizeDetails.value = ResizeState(
          isResizing: false,
          currentSize: event.size,
          previousSize: _lastSize,
        );
        _lastSize = event.size;
      }
    }
  }

  @override
  void dispose() {
    WindowLifecycleBus.instance.isOperating.removeListener(_syncFromBus);
    _sub.cancel();
    _eventSub.cancel();
    resizeDetails.dispose();
    super.dispose();
  }
}
