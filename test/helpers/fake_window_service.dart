import 'package:simple_player_flutter/kernel/bridge/window_service.dart';

/// Test double for WindowService — no FFI, no window_manager.
///
/// Overrides all methods that touch Win32 APIs or windowManager.
/// Provides call tracking for test assertions.
class FakeWindowService extends WindowService {
  // ─── Call tracking ───

  int fullscreenCallCount = 0;
  bool? lastFullscreenValue;
  int alwaysOnTopCallCount = 0;
  bool? lastAlwaysOnTopValue;
  int maximizeCallCount = 0;
  int restoreCallCount = 0;

  @override
  void init() {
    // No-op: skip windowManager.addListener and _removeBorder.
  }

  @override
  Future<void> setFullscreen(bool value) async {
    fullscreenCallCount++;
    lastFullscreenValue = value;
    isFullscreen.value = value;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    alwaysOnTopCallCount++;
    lastAlwaysOnTopValue = value;
    isAlwaysOnTop.value = value;
  }

  @override
  Future<void> maximize() async {
    maximizeCallCount++;
    isMaximized.value = true;
  }

  @override
  Future<void> restore() async {
    restoreCallCount++;
    isMaximized.value = false;
  }

  @override
  Future<void> minimize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> startDragging() async {}

  @override
  void dispose() {
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
