import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../window/window_service.dart';

/// UI 层共享的 resize 状态（singleton）。
/// 订阅 WindowService.onResize stream，暴露 ValueNotifier<bool>。
class ResizeNotifier extends ValueNotifier<bool> {
  ResizeNotifier._() : super(false) {
    _sub = WindowService.instance.onResize.listen((v) => value = v);
  }

  static final ResizeNotifier instance = ResizeNotifier._();

  late final StreamSubscription<bool> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
