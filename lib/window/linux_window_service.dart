import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../kernel/bridge/window_bridge.dart';
import '../kernel/persistence/settings_store.dart';
import '../kernel/window/aspect_ratio_service.dart';
import 'geometry_store.dart';

/// Linux 窗口管理服务 — 实现 WindowBridge
///
/// 使用 window_manager 跨平台 API（X11/Wayland）。
/// 无需 GTK FFI — window_manager 内部处理 X11/Wayland 差异。
class LinuxWindowService implements WindowBridge {
  LinuxWindowService(this._prefs);

  final SharedPreferences _prefs;
  late final WindowGeometryStore _geometry;

  // ─── Reactive State ───

  @override
  final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
  @override
  final isAlwaysOnTop = ValueNotifier<bool>(false);
  @override
  final isMaximized = ValueNotifier<bool>(false);
  @override
  final isResizing = ValueNotifier<bool>(false);

  // ─── Constants ───

  static const _minSize = Size(800, 450);
  static const _resizeDebounceMs = 500;

  // ─── Internal ───

  bool _initialized = false;
  bool _disposed = false;
  Completer<void>? _initCompleter;

  Timer? _resizeEndDebounce;
  Timer? _persistDebounce;

  bool _togglingFullscreen = false;
  bool _closing = false;
  Completer<void>? _persistInFlight;

  // ─── Lifecycle ───

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initCompleter = Completer<void>();

    try {
      _geometry = WindowGeometryStore(_prefs);
      final saved = _geometry.load();
      final clamped = WindowGeometryStore.clampToVisibleBounds(saved);

      await windowManager.ensureInitialized();

      final windowOptions = WindowOptions(
        size: clamped.size,
        center: !_geometry.hasSavedPosition,
        backgroundColor: Colors.black,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (_disposed) return;
        try {
          await windowManager.setMinimumSize(_minSize);

          if (_geometry.hasSavedPosition) {
            await windowManager.setPosition(clamped.position);
          }

          if (clamped.isMaximized) {
            await windowManager.maximize();
          }

          await windowManager.setPreventClose(true);
          await windowManager.setAsFrameless();

          await windowManager.show();
          await windowManager.focus();

          if (saved.isFullscreen) {
            await windowManager.setFullScreen(true);
            mode.value = WindowMode.fullscreen;
          }

          windowManager.addListener(_WindowListener(this));
          _initialized = true;
        } on Exception catch (e) {
          debugPrint('[LinuxWindowService] init failed: $e');
          _initialized = true;
        } finally {
          if (!_initCompleter!.isCompleted) _initCompleter!.complete();
        }
      });
    } on Exception catch (e) {
      debugPrint('[LinuxWindowService] init setup failed: $e');
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

    _resizeEndDebounce?.cancel();
    _persistDebounce?.cancel();
    await _geometry.flush();

    mode.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    isResizing.dispose();
    _geometry.dispose();
  }

  // ─── Commands ───

  @override
  Future<void> minimize() async {
    try {
      await windowManager.minimize();
    } on Exception catch (e) {
      debugPrint('[LinuxWindowService] minimize failed: $e');
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
      debugPrint('[LinuxWindowService] toggleMaximize failed: $e');
    }
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    try {
      await _geometry.flush();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } on Exception catch (e) {
      debugPrint('[LinuxWindowService] close failed: $e');
    }
  }

  @override
  Future<void> startDragging() async {
    try {
      await windowManager.startDragging();
    } on Exception catch (e) {
      debugPrint('[LinuxWindowService] startDragging failed: $e');
    }
  }

  // ─── Fullscreen ───

  @override
  Future<void> toggleFullscreen() async {
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      final entering = mode.value != WindowMode.fullscreen;

      if (entering) {
        await AspectRatioService.I.unlock();
      }

      await windowManager.setFullScreen(entering);
      mode.value = entering ? WindowMode.fullscreen : WindowMode.windowed;
      await SettingsStore.saveIsFullscreen(entering);
    } on Exception catch (e) {
      debugPrint('[LinuxWindowService] toggleFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
      _resizeEndDebounce?.cancel();
      isResizing.value = false;
    }
  }

  @override
  Future<void> exitFullscreen() async {
    if (mode.value != WindowMode.fullscreen) return;
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      await windowManager.setFullScreen(false);
      mode.value = WindowMode.windowed;
      await SettingsStore.saveIsFullscreen(false);
    } on Exception catch (e) {
      debugPrint('[LinuxWindowService] exitFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
      _resizeEndDebounce?.cancel();
      isResizing.value = false;
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
      debugPrint('[LinuxWindowService] toggleAlwaysOnTop failed: $e');
    }
  }

  // ─── Resize/move debounce ───

  void _onResizeStart() {
    if (!isResizing.value) isResizing.value = true;
    _resizeEndDebounce?.cancel();
  }

  void _onResizeEnd() {
    _resizeEndDebounce?.cancel();
    _resizeEndDebounce = Timer(
      const Duration(milliseconds: _resizeDebounceMs),
      () {
        isResizing.value = false;
      },
    );
    _schedulePersist();
  }

  void _onMove() {
    _schedulePersist();
  }

  // ─── Persistence ───

  static const _persistDebounceMs = 500;

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: _persistDebounceMs),
      _persistWindowState,
    );
  }

  Future<void> _persistWindowState() async {
    if (_disposed) return;
    if (_persistInFlight != null) return _persistInFlight!.future;
    _persistInFlight = Completer<void>();
    try {
      final results = await Future.wait([
        windowManager.getSize(),
        windowManager.getPosition(),
        windowManager.isMaximized(),
      ]);
      final size = results[0] as Size;
      final position = results[1] as Offset;
      final maximized = results[2] as bool;

      if (mode.value != WindowMode.fullscreen) {
        _geometry.saveDebounced(
          size: size,
          position: position,
          isMaximized: maximized,
        );
      }
      _persistInFlight!.complete();
    } on Exception catch (e) {
      debugPrint('[LinuxWindowService] persist failed: $e');
      if (!_persistInFlight!.isCompleted) _persistInFlight!.complete();
    } finally {
      _persistInFlight = null;
    }
  }
}

class _WindowListener extends WindowListener {
  _WindowListener(this._service);
  final LinuxWindowService _service;

  @override
  void onWindowClose() => _service.close();

  @override
  void onWindowResize() => _service._onResizeStart();

  @override
  void onWindowResized() => _service._onResizeEnd();

  @override
  void onWindowMove() => _service._onMove();

  @override
  void onWindowMoved() => _service._onMove();

  @override
  void onWindowEvent(String eventName) {}
  @override
  void onWindowFocus() {}
  @override
  void onWindowBlur() {}
  @override
  void onWindowMaximize() {
    _service.isMaximized.value = true;
    _service._persistWindowState();
  }

  @override
  void onWindowUnmaximize() {
    _service.isMaximized.value = false;
    _service._persistWindowState();
  }

  @override
  void onWindowEnterFullScreen() {
    _service._geometry.saveFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    _service._geometry.saveFullscreen(false);
  }

  @override
  void onWindowMinimize() {}
  @override
  void onWindowRestore() {}
  @override
  void onWindowDocked() {}
  @override
  void onWindowUndocked() {}
}
