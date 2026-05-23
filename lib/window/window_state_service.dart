import 'dart:async';

import 'package:flutter/foundation.dart';

import '../kernel/bridge/window_bridge.dart';

/// Shared window state — 3 ValueNotifiers + interaction state + resize debounce.
///
/// Composed by platform WindowService implementations.
/// WindowListener drives state; commands never write state directly (P0).
class WindowStateService {
  // ─── Reactive State ───

  final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
  final isAlwaysOnTop = ValueNotifier<bool>(false);
  final isMaximized = ValueNotifier<bool>(false);

  /// 窗口交互状态 — resize/moving session 模型，替代 bool debounce。
  ///
  /// idle → resizing/moving → idle 生命周期，
  /// 500ms debounce 防止拖拽期间反复 toggle。
  final interaction =
      ValueNotifier<WindowInteractionState>(WindowInteractionState.idle);

  // ─── Resize Debounce ───

  static const _resizeDebounceMs = 500;

  Timer? _resizeEndDebounce;

  void onResizeStart() {
    if (interaction.value != WindowInteractionState.resizing) {
      interaction.value = WindowInteractionState.resizing;
    }
    _resizeEndDebounce?.cancel();
  }

  void onResizeEnd() {
    _resizeEndDebounce?.cancel();
    _resizeEndDebounce = Timer(
      const Duration(milliseconds: _resizeDebounceMs),
      () {
        interaction.value = WindowInteractionState.idle;
      },
    );
  }

  // ─── Lifecycle ───

  void dispose() {
    _resizeEndDebounce?.cancel();
    mode.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    interaction.dispose();
  }
}
