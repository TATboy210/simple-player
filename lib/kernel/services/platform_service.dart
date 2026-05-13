import 'package:flutter/foundation.dart';

import '../bridge/window_bridge.dart';

/// Abstract platform service interface
///
/// UI code depends on this interface, never on concrete implementations.
/// Singleton pattern: access via PlatformService.I throughout the app.
///
/// When no explicit implementation is injected via PlatformService.init(),
/// the accessor returns a transparent _Proxy that delegates to WindowBridge.I.
/// This ensures existing consumers (e.g. CustomTitleBar) continue to work
/// without changes after WindowManagerService deletion.
abstract class PlatformService {
  /// Singleton accessor — returns _Proxy if no explicit implementation set
  static PlatformService get I => _instance ?? _Proxy();

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

/// Transparent proxy that delegates all operations to WindowBridge.I
///
/// Used as the default when no explicit PlatformService implementation is
/// injected. WindowBridge.I returns NoopWindowBridge before WindowBootstrap
/// initializes, so the proxy never throws.
class _Proxy implements PlatformService {
  WindowBridge get _bridge => WindowBridge.I;

  @override
  Future<void> minimize() => _bridge.minimize();

  @override
  Future<void> toggleMaximize() => _bridge.toggleMaximize();

  @override
  Future<void> close() => _bridge.close();

  @override
  Future<void> startDragging() => _bridge.startDragging();

  @override
  Future<void> toggleFullscreen() => _bridge.toggleFullscreen();

  @override
  Future<void> exitFullscreen() => _bridge.exitFullscreen();

  @override
  Future<void> toggleAlwaysOnTop() => _bridge.toggleAlwaysOnTop();

  @override
  ValueNotifier<WindowMode> get mode => _bridge.mode;

  @override
  ValueNotifier<bool> get isAlwaysOnTop => _bridge.isAlwaysOnTop;

  @override
  ValueNotifier<bool> get isMaximized => _bridge.isMaximized;

  @override
  ValueNotifier<bool> get isResizing => _bridge.isResizing;

  @override
  Future<void> initService() => Future.value();

  @override
  Future<void> dispose() => Future.value();
}
