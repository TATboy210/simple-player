import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'dart:ffi' hide Size;

import '../kernel/bridge/window_bridge.dart';
import 'geometry_store.dart';

const int _wsThickFrame = 0x00040000;

final _user32 = DynamicLibrary.open('user32.dll');
final _getWindowLongPtrW = _user32.lookupFunction<
    IntPtr Function(IntPtr, Int32),
    int Function(int, int)>('GetWindowLongPtrW');
final _setWindowLongPtrW = _user32.lookupFunction<
    IntPtr Function(IntPtr, Int32, IntPtr),
    int Function(int, int, int)>('SetWindowLongPtrW');
final _getForegroundWindow = _user32.lookupFunction<
    IntPtr Function(),
    int Function()>('GetForegroundWindow');

/// Restore WS_THICKFRAME after setAsFrameless() strips it.
/// Without this, WM_NCHITTEST resize borders don't work.
void _restoreThickFrame() {
  final hwnd = _getForegroundWindow();
  if (hwnd == 0) return;
  final style = _getWindowLongPtrW(hwnd, -16); // GWL_STYLE
  if ((style & _wsThickFrame) == 0) {
    _setWindowLongPtrW(hwnd, -16, style | _wsThickFrame);
  }
}

/// 绐楀彛绠＄悊鏈嶅姟 鈥?Singleton锛屽疄鐜?WindowBridge
///
/// Runtime operations (fullscreen, drag, minimize, etc.) go through a unified
/// MethodChannel `com.simple_player/window` 鈫?native C++ handler.
/// window_manager is only used for one-time initial setup.
///
/// Reactive state via ValueNotifier, UI binds with ValueListenableBuilder.
class WindowService implements WindowBridge {
  WindowService(this._prefs);

  final SharedPreferences _prefs;
  late final WindowGeometryStore _geometry;

  // 鈹€鈹€鈹€ Reactive State 鈹€鈹€鈹€

  @override
  final mode = ValueNotifier<WindowMode>(WindowMode.windowed);
  @override
  final isAlwaysOnTop = ValueNotifier<bool>(false);
  @override
  final isMaximized = ValueNotifier<bool>(false);
  @override
  final isResizing = ValueNotifier<bool>(false);

  // 鈹€鈹€鈹€ Constants 鈹€鈹€鈹€

  static const _minSize = Size(640, 360);
  static const _resizeDebounceMs = 500;

  /// Unified MethodChannel 鈥?all runtime window operations + C++ events
  static const _channel = MethodChannel('com.simple_player/window');

  // 鈹€鈹€鈹€ Internal 鈹€鈹€鈹€

  bool _initialized = false;
  bool _disposed = false;
  Completer<void>? _initCompleter;

  Timer? _resizeEndDebounce;
  Timer? _persistDebounce;

  bool _togglingFullscreen = false;
  bool _closing = false;
  Completer<void>? _persistInFlight;

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

          // Restore fullscreen after frameless is confirmed
          if (saved.isFullscreen) {
            await windowManager.setFullScreen(true);
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
      case 'onModeChanged':
        final modeStr = call.arguments as String;
        mode.value = modeStr == 'fullscreen'
            ? WindowMode.fullscreen
            : WindowMode.windowed;
        if (modeStr == 'fullscreen') {
          await _geometry.saveFullscreen(true);
        } else {
          await _geometry.saveFullscreen(false);
        }
        break;
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
        await windowManager.setFullScreen(false);
      } else {
        await windowManager.setFullScreen(true);
      }
    } on Exception catch (e) {
      debugPrint('[WindowService] toggleFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
    }
  }

  @override
  Future<void> exitFullscreen() async {
    if (mode.value != WindowMode.fullscreen) return;
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
        await windowManager.setFullScreen(false);
    } on Exception catch (e) {
      debugPrint('[WindowService] exitFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
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
    _service.mode.value = WindowMode.fullscreen;
  }

  @override
  void onWindowLeaveFullScreen() {
    _service.mode.value = WindowMode.windowed;
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


