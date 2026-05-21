import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';

import '../kernel/bridge/window_bridge.dart';
import '../kernel/persistence/settings_store.dart';
import '../kernel/window/aspect_ratio_service.dart';
import 'geometry_store.dart';

/// Windows 窗口管理服务 — 实现 WindowBridge
///
/// Runtime operations (fullscreen, drag, minimize, etc.) go through a unified
/// MethodChannel `com.simple_player/window` ← native C++ handler.
/// window_manager is only used for one-time initial setup.
///
/// Reactive state via ValueNotifier, UI binds with ValueListenableBuilder.
class WindowService implements WindowBridge {
  WindowService(this._prefs);

  final SharedPreferences _prefs;
  late final WindowGeometryStore _geometry;

  // ─── Win32 FFI (lazy — only initialized on first use) ───

  static const _wsThickFrame = 0x00040000;
  static const _wsCaption = 0x00C00000;
  static const _gwlStyle = -16;
  static const _hwndTop = 0;
  static const _swpFrameChanged = 0x0020;
  static const _swpNoOwnerZOrder = 0x0200;
  static const _monitorDefaultToNearest = 2;

  static DynamicLibrary? _user32Lib;
  static DynamicLibrary get _user32 =>
      _user32Lib ??= DynamicLibrary.open('user32.dll');

  static final _getWindowLongPtrW = _user32.lookupFunction<
      IntPtr Function(IntPtr, Int32),
      int Function(int, int)>('GetWindowLongPtrW');

  static final _setWindowLongPtrW = _user32.lookupFunction<
      IntPtr Function(IntPtr, Int32, IntPtr),
      int Function(int, int, int)>('SetWindowLongPtrW');

  static final _getForegroundWindow = _user32.lookupFunction<
      IntPtr Function(),
      int Function()>('GetForegroundWindow');

  static final _monitorFromWindow = _user32.lookupFunction<
      IntPtr Function(IntPtr, Uint32),
      int Function(int, int)>('MonitorFromWindow');

  static final _getMonitorInfoW = _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Void>),
      int Function(int, Pointer<Void>)>('GetMonitorInfoW');

  static final _setWindowPos = _user32.lookupFunction<
      Int32 Function(
          IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
      int Function(int, int, int, int, int, int, int)>('SetWindowPos');

  /// Restore WS_THICKFRAME after setAsFrameless() strips it.
  static void _restoreThickFrame() {
    final hwnd = _getForegroundWindow();
    if (hwnd == 0) return;
    final style = _getWindowLongPtrW(hwnd, _gwlStyle);
    if ((style & _wsThickFrame) == 0) {
      _setWindowLongPtrW(hwnd, _gwlStyle, style | _wsThickFrame);
    }
  }

  /// Get the monitor rect that covers the entire screen (including taskbar).
  static RECT _getFullscreenMonitorRect(int hwnd) {
    final monitor = _monitorFromWindow(hwnd, _monitorDefaultToNearest);
    // MONITORINFO: cbSize(4) + rcMonitor(16) + rcWork(16) + dwFlags(4) = 40
    final mi = calloc.allocate<Uint8>(40);
    mi.cast<Uint32>().value = 40;
    final ok = _getMonitorInfoW(monitor, mi.cast());
    if (ok == 0) {
      calloc.free(mi);
      throw Exception('GetMonitorInfoW failed');
    }
    final base = mi.cast<Int32>();
    final rect = RECT()
      ..left = (base + 1).value
      ..top = (base + 2).value
      ..right = (base + 3).value
      ..bottom = (base + 4).value;
    calloc.free(mi);
    return rect;
  }

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

  /// Unified MethodChannel — all runtime window operations + C++ events
  static const _channel = MethodChannel('com.simple_player/window');

  // 鈹€鈹€鈹€ Internal 鈹€鈹€鈹€

  bool _initialized = false;
  bool _disposed = false;
  Completer<void>? _initCompleter;

  Timer? _resizeEndDebounce;
  Timer? _persistDebounce;

  bool _togglingFullscreen = false;
  double _savedRatio = 0.0;
  Size? _windowedSize;
  Offset? _windowedPosition;
  bool _closing = false;
  Completer<void>? _persistInFlight;
  int _hwnd = 0;

  // 鈹€鈹€鈹€ Lifecycle 鈹€鈹€鈹€

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initCompleter = Completer<void>();

    // Listen for C++ 鈫?Dart events on the unified channel
    _channel.setMethodCallHandler(_onNativeEvent);

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
          _restoreThickFrame();

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

          // Cache HWND for Win32 fullscreen operations
          _hwnd = _getForegroundWindow();

          // Restore fullscreen after frameless is confirmed
          if (saved.isFullscreen) {
            await _enterFullscreenInternal();
          }

          // Register window_manager listener for resize/move debounce
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

    _channel.setMethodCallHandler(null);
    _resizeEndDebounce?.cancel();
    _persistDebounce?.cancel();
    await _geometry.flush();

    mode.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    isResizing.dispose();
    _geometry.dispose();
  }

  // 鈹€鈹€鈹€ C++ 鈫?Dart event handler 鈹€鈹€鈹€

  Future<void> _onNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'onMaximizeChanged':
        isMaximized.value = call.arguments as bool;
        _persistWindowState();
        break;
    }
  }

  // 鈹€鈹€鈹€ Commands 鈫?C++ 鈹€鈹€鈹€

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
      await _geometry.flush();
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

  // 鈹€鈹€鈹€ Fullscreen 鈹€鈹€鈹€

  @override
  Future<void> toggleFullscreen() async {
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      if (mode.value == WindowMode.fullscreen) {
        await _exitFullscreenInternal();
      } else {
        await _enterFullscreenInternal();
      }
    } on Exception catch (e) {
      debugPrint('[WindowService] toggleFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
      _resizeEndDebounce?.cancel();
      isResizing.value = false;
    }
  }

  // PORTING: _enterFullscreenInternal/_exitFullscreenInternal use raw Win32.
  // Linux: use window_manager.setFullScreen(true) or X11 _NET_WM_STATE_FULLSCREEN.
  // macOS: use window_manager.setFullScreen(true) or NSWindow.toggleFullScreen.
  Future<void> _enterFullscreenInternal() async {
    if (_hwnd == 0) {
      debugPrint('[WindowService] enterFullscreen: HWND not available');
      return;
    }

    // Unlock aspect ratio so WM_SIZING won't constrain the resize
    _savedRatio = AspectRatioService.I.current;
    if (_savedRatio > 0) await AspectRatioService.I.unlock();

    // Cache windowed geometry for restore
    _windowedSize = await windowManager.getSize();
    _windowedPosition = await windowManager.getPosition();

    try {
      // 1. Get the monitor rect (covers entire screen including taskbar)
      final rect = _getFullscreenMonitorRect(_hwnd);

      // 2. Strip window border styles for true borderless fullscreen
      final style = _getWindowLongPtrW(_hwnd, _gwlStyle);
      _setWindowLongPtrW(
          _hwnd, _gwlStyle, style & ~(_wsCaption | _wsThickFrame));

      // 3. Atomically set position + size to cover entire monitor
      _setWindowPos(
        _hwnd,
        _hwndTop,
        rect.left,
        rect.top,
        rect.right - rect.left,
        rect.bottom - rect.top,
        _swpFrameChanged | _swpNoOwnerZOrder,
      );

      // 4. Update state after window has been resized
      mode.value = WindowMode.fullscreen;
      await SettingsStore.saveIsFullscreen(true);
    } on Exception catch (e) {
      // Rollback on failure
      mode.value = WindowMode.windowed;
      if (_savedRatio > 0) {
        await AspectRatioService.I.setAspectRatio(_savedRatio);
        _savedRatio = 0.0;
      }
      debugPrint('[WindowService] enterFullscreen failed: $e');
    }
  }

  Future<void> _exitFullscreenInternal() async {
    if (_hwnd == 0) {
      debugPrint('[WindowService] exitFullscreen: HWND not available');
      return;
    }

    try {
      // 1. Restore WS_THICKFRAME for window resize borders
      final style = _getWindowLongPtrW(_hwnd, _gwlStyle);
      _setWindowLongPtrW(_hwnd, _gwlStyle, style | _wsThickFrame);

      // 2. Restore windowed geometry atomically (avoids size→position flash)
      if (_windowedSize != null && _windowedPosition != null) {
        _setWindowPos(
          _hwnd,
          _hwndTop,
          _windowedPosition!.dx.toInt(),
          _windowedPosition!.dy.toInt(),
          _windowedSize!.width.toInt(),
          _windowedSize!.height.toInt(),
          _swpFrameChanged | _swpNoOwnerZOrder,
        );
      }

      await windowManager.setHasShadow(true);

      // 3. Restore aspect ratio
      if (_savedRatio > 0) {
        await AspectRatioService.I.setAspectRatio(_savedRatio);
        _savedRatio = 0.0;
      }

      // 4. Update state after window has been restored
      mode.value = WindowMode.windowed;
      await SettingsStore.saveIsFullscreen(false);
    } on Exception catch (e) {
      // Rollback on failure
      mode.value = WindowMode.fullscreen;
      debugPrint('[WindowService] exitFullscreen failed: $e');
    }
  }

  @override
  Future<void> exitFullscreen() async {
    if (mode.value != WindowMode.fullscreen) return;
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      await _exitFullscreenInternal();
    } on Exception catch (e) {
      debugPrint('[WindowService] exitFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
      _resizeEndDebounce?.cancel();
      isResizing.value = false;
    }
  }

  // 鈹€鈹€鈹€ Always on Top 鈹€鈹€鈹€

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

  // 鈹€鈹€鈹€ Resize/move debounce (from window_manager listener) 鈹€鈹€鈹€

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

  // 鈹€鈹€鈹€ Persistence 鈹€鈹€鈹€

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
      // Fullscreen: skip saving 鈥?C++ caches windowed_rect_ for restore
      _persistInFlight!.complete();
    } on Exception catch (e) {
      debugPrint('[WindowService] persist failed: $e');
      if (!_persistInFlight!.isCompleted) _persistInFlight!.complete();
    } finally {
      _persistInFlight = null;
    }
  }
}

class RECT {
  int left = 0;
  int top = 0;
  int right = 0;
  int bottom = 0;
}

/// WindowListener adapter 鈥?routes resize/move events to WindowService
class _WindowListener extends WindowListener {
  _WindowListener(this._service);
  final WindowService _service;

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

  // No-op overrides
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
    // Manual fullscreen handles mode.value directly — only persist here
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
