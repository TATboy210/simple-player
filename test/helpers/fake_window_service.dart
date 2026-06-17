import 'package:simple_player_flutter/kernel/bridge/window_service.dart';

/// Test double for WindowService — no window_manager.
///
/// Overrides all methods that touch windowManager.
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
  Future<void> init() async {
    // No-op: skip windowManager.ensureInitialized and listener registration.
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
  void dispose() {
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
