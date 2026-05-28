import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:window_manager/window_manager.dart';

/// Window management service — wraps window_manager package.
///
/// Provides ValueNotifier state for reactive UI binding via
/// ValueListenableBuilder. Delegates all window operations to
/// the windowManager singleton.
///
/// Uses WindowListener mixin to receive events and update ValueNotifiers.
class WindowService with WindowListener {
  WindowService();

  bool _disposed = false;

  // ─── State (ValueNotifier pattern) ───

  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> isMaximized = ValueNotifier(false);
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(960, 540));

  /// Initialize event listener — call after construction.
  void init() {
    windowManager.addListener(this);
  }

  // ─── WindowListener callbacks → update ValueNotifiers ───

  @override
  void onWindowMaximize() {
    if (!_disposed) isMaximized.value = true;
  }

  @override
  void onWindowUnmaximize() {
    if (!_disposed) isMaximized.value = false;
  }

  @override
  void onWindowEnterFullScreen() {
    if (!_disposed) isFullscreen.value = true;
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!_disposed) isFullscreen.value = false;
  }

  @override
  void onWindowResize() {
    if (_disposed) return;
    windowManager.getSize().then((size) {
      if (!_disposed) windowSize.value = size;
    });
  }

  // ─── Commands (delegate to windowManager) ───

  Future<void> setFullscreen(bool value) =>
      windowManager.setFullScreen(value);

  Future<void> setAlwaysOnTop(bool value) =>
      windowManager.setAlwaysOnTop(value);

  Future<void> setSize(double width, double height) =>
      windowManager.setSize(Size(width, height));

  Future<void> setMinSize(double width, double height) =>
      windowManager.setMinimumSize(Size(width, height));

  Future<void> minimize() => windowManager.minimize();

  Future<void> maximize() => windowManager.maximize();

  Future<void> restore() => windowManager.restore();

  Future<void> close() => windowManager.close();

  Future<void> center() => windowManager.center();

  Future<void> startDragging() => windowManager.startDragging();

  void dispose() {
    _disposed = true;
    windowManager.removeListener(this);
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
