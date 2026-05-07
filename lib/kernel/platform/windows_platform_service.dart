import 'package:flutter/foundation.dart';

import '../services/platform_service.dart';
import '../window/window_manager_service.dart';

/// Windows implementation of PlatformService
///
/// Delegates all operations to the existing WindowManagerService singleton.
/// This preserves all production-hardened behavior (debounced persistence,
/// fullscreen reentry guard, bounds checking, etc.) while providing a
/// clean abstract interface for UI code.
class WindowsPlatformService implements PlatformService {
  final WindowManagerService _wm = WindowManagerService.I;

  @override
  Future<void> minimize() => _wm.minimize();

  @override
  Future<void> toggleMaximize() => _wm.toggleMaximize();

  @override
  Future<void> close() => _wm.close();

  @override
  Future<void> startDragging() => _wm.startDragging();

  @override
  Future<void> toggleFullscreen() => _wm.toggleFullscreen();

  @override
  Future<void> exitFullscreen() => _wm.exitFullscreen();

  @override
  Future<void> toggleAlwaysOnTop() => _wm.toggleAlwaysOnTop();

  @override
  ValueNotifier<WindowMode> get mode => _wm.mode;

  @override
  ValueNotifier<bool> get isAlwaysOnTop => _wm.isAlwaysOnTop;

  @override
  ValueNotifier<bool> get isMaximized => _wm.isMaximized;

  @override
  ValueNotifier<bool> get isResizing => _wm.isResizing;

  @override
  Future<void> initService() => _wm.init();

  @override
  Future<void> dispose() => _wm.dispose();
}
