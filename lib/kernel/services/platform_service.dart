import 'package:flutter/foundation.dart';

/// Window mode enumeration
enum WindowMode { windowed, fullscreen }

/// Abstract platform service interface
///
/// UI code depends on this interface, never on concrete implementations.
/// Factory singleton pattern: call PlatformService.init() in main(),
/// access via PlatformService.I throughout the app.
///
/// To add a new platform:
/// 1. Create lib/kernel/platform/{platform}_platform_service.dart
/// 2. Implement all methods in this interface
/// 3. Call PlatformService.init(NewPlatformService()) in main()
/// 4. No UI code changes needed
abstract class PlatformService {
  /// Singleton accessor — throws if not initialized
  static PlatformService get I {
    if (_instance == null) {
      throw StateError(
        'PlatformService not initialized. Call PlatformService.init() first.',
      );
    }
    return _instance!;
  }

  static PlatformService? _instance;

  /// Whether the singleton has been initialized (safe for test guards)
  static bool get isInitialized => _instance != null;

  /// Initialize with platform-specific implementation
  static void init(PlatformService impl) => _instance = impl;

  /// Reset singleton (for testing only)
  @visibleForTesting
  static void reset() => _instance = null;

  // ── Window Management ──

  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
  Future<void> startDragging();
  Future<void> toggleFullscreen();
  Future<void> exitFullscreen();
  Future<void> toggleAlwaysOnTop();

  // ── Reactive State ──

  ValueNotifier<WindowMode> get mode;
  ValueNotifier<bool> get isAlwaysOnTop;
  ValueNotifier<bool> get isMaximized;
  ValueNotifier<bool> get isResizing;

  // ── Lifecycle ──

  Future<void> initService();
  Future<void> dispose();
}
