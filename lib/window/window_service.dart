import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../kernel/bridge/window_bridge.dart';
import 'fullscreen_controller.dart';
import 'window_persistence_service.dart';
import 'window_state_service.dart';

/// Windows 窗口管理服务 — 实现 WindowBridge
///
/// Fullscreen via FullscreenController (Win32 FFI).
/// Other operations via window_manager.
///
/// Composes WindowStateService + WindowPersistenceService.
class WindowService implements WindowBridge {
  WindowService(this._prefs);

  final SharedPreferences _prefs;

  late final WindowStateService _state;
  late final WindowPersistenceService _persistence;
  FullscreenController? _fullscreen;

  // ─── Reactive State (delegate to _state) ───

  @override
  ValueNotifier<WindowMode> get mode => _state.mode;
  @override
  ValueNotifier<bool> get isAlwaysOnTop => _state.isAlwaysOnTop;
  @override
  ValueNotifier<bool> get isMaximized => _state.isMaximized;
  @override
  ValueNotifier<WindowInteractionState> get interaction => _state.interaction;
  @override
  bool get isResizing => _state.interaction.value == WindowInteractionState.resizing;

  // ─── Constants ───

  static const _minSize = Size(800, 450);

  // ─── Internal ───

  bool _initialized = false;
  bool _disposed = false;
  Completer<void>? _initCompleter;
  bool _togglingFullscreen = false;
  bool _closing = false;

  // ─── Lifecycle ───

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initCompleter = Completer<void>();

    _state = WindowStateService();
    _persistence = WindowPersistenceService(_prefs);

    try {
      final clamped = _persistence.loadAndClamp();

      await windowManager.ensureInitialized();

      final windowOptions = WindowOptions(
        size: clamped.size,
        center: !_persistence.geometry.hasSavedPosition,

        backgroundColor: Colors.black,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (_disposed) return;
        try {
          await windowManager.setMinimumSize(_minSize);

          if (_persistence.geometry.hasSavedPosition) {
            await windowManager.setPosition(clamped.position);
          }

          if (clamped.isMaximized) {
            await windowManager.maximize();
          }

          await windowManager.setPreventClose(true);
          await windowManager.setAsFrameless();
          FullscreenController.restoreThickFrame();

          // Force layout + redraw after frameless
          try {
            final size = await windowManager.getSize();
            if (size.width > 0 && size.height > 0) {
              await windowManager.setSize(size);
            }
          } on Exception catch (e) {
            debugPrint('[WindowService] force layout failed: $e');
          }

          await windowManager.show();
          await windowManager.focus();

          _fullscreen = FullscreenController.init();

          if (clamped.isFullscreen) {
            await _fullscreen!.enter();
          }

          windowManager.addListener(_WindowListener(this));
          _initialized = true;
        } on Exception catch (e) {
          debugPrint('[WindowService] init failed: $e');
          _initialized = true;
        } finally {
          if (!_initCompleter!.isCompleted) _initCompleter!.complete();
        }
      });
    } on Exception catch (e) {
      debugPrint('[WindowService] init setup failed: $e');
      _initialized = true;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      await _initCompleter!.future;
    }

    await _persistence.flush();
    _state.dispose();
    _persistence.dispose();
  }

  // ─── Commands ───

  @override
  Future<void> minimize() async {
    try {
      await windowManager.minimize();
    } on Exception catch (e) {
      debugPrint('[WindowService] minimize failed: $e');
    }
  }

  @override
  Future<void> toggleMaximize() async {
    try {
      if (isMaximized.value) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } on Exception catch (e) {
      debugPrint('[WindowService] toggleMaximize failed: $e');
    }
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    try {
      await _persistence.flush();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } on Exception catch (e) {
      debugPrint('[WindowService] close failed: $e');
    }
  }

  @override
  Future<void> startDragging() async {
    try {
      await windowManager.startDragging();
    } on Exception catch (e) {
      debugPrint('[WindowService] startDragging failed: $e');
    }
  }

  // ─── Fullscreen ───

  @override
  Future<void> toggleFullscreen() async {
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      final fc = _fullscreen;
      if (fc == null) return;
      if (mode.value == WindowMode.fullscreen) {
        await fc.exit();
      } else {
        await fc.enter();
      }
    } on Exception catch (e) {
      debugPrint('[WindowService] toggleFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
      _state.onResizeEnd();
    }
  }

  @override
  Future<void> exitFullscreen() async {
    if (mode.value != WindowMode.fullscreen) return;
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      await _fullscreen?.exit();
    } on Exception catch (e) {
      debugPrint('[WindowService] exitFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
      _state.onResizeEnd();
    }
  }

  // ─── Always on Top ───

  @override
  Future<void> toggleAlwaysOnTop() async {
    try {
      final next = !isAlwaysOnTop.value;
      await windowManager.setAlwaysOnTop(next);
      isAlwaysOnTop.value = next;
    } on Exception catch (e) {
      debugPrint('[WindowService] toggleAlwaysOnTop failed: $e');
    }
  }
}

/// WindowListener adapter — routes events to WindowService + shared services.
class _WindowListener extends WindowListener {
  _WindowListener(this._service);
  final WindowService _service;

  @override
  void onWindowClose() => _service.close();

  @override
  void onWindowResize() => _service._state.onResizeStart();

  @override
  void onWindowResized() {
    _service._state.onResizeEnd();
    _service._persistence.schedulePersist();
  }

  @override
  void onWindowMove() => _service._persistence.schedulePersist();

  @override
  void onWindowMoved() => _service._persistence.schedulePersist();

  @override
  void onWindowMaximize() {
    _service.isMaximized.value = true;
    _service._persistence.persistNow();
  }

  @override
  void onWindowUnmaximize() {
    _service.isMaximized.value = false;
    _service._persistence.persistNow();
  }

  @override
  void onWindowEnterFullScreen() {
    _service.mode.value = WindowMode.fullscreen;
    _service._persistence.saveFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    _service.mode.value = WindowMode.windowed;
    _service._persistence.saveFullscreen(false);
  }

  // No-op overrides
  @override
  void onWindowEvent(String eventName) {}
  @override
  void onWindowFocus() {}
  @override
  void onWindowBlur() {}
  @override
  void onWindowMinimize() {}
  @override
  void onWindowRestore() {}
  @override
  void onWindowDocked() {}
  @override
  void onWindowUndocked() {}
}
