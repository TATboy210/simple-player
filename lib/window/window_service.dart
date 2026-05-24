import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../kernel/persistence/settings_store.dart';
import '../kernel/window/aspect_ratio_service.dart';
import 'window_state.dart';

// ═══════════════════════════════════════════════════════════════════════
// WindowService — Concrete 实现, UI 不直接访问
// ═══════════════════════════════════════════════════════════════════════

class WindowService {
  WindowService(this._s);
  final WindowState _s;

  // ── 内部状态 ──

  bool _initialized = false;
  bool _disposed = false;
  Completer<void>? _initCompleter;
  bool _togglingFullscreen = false;
  bool _closing = false;
  double _savedRatio = 0.0;

  late SharedPreferences _prefs;
  Timer? _persistDebounce;
  Completer<void>? _persistInFlight;
  Timer? _resizeDebounce;

  // ═══════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════

  Future<void> init(SharedPreferences prefs) async {
    if (_initialized) return;
    _prefs = prefs;
    _initCompleter = Completer<void>();

    try {
      final geo = _loadGeometry();
      final clamped = _clampToVisibleBounds(geo);

      await windowManager.ensureInitialized();

      final windowOptions = WindowOptions(
        size: Size(clamped[kWWidth]!, clamped[kWHeight]!),
        center: !_prefs.containsKey(kWPosX),
        backgroundColor: Colors.black,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility:
            defaultTargetPlatform == TargetPlatform.macOS,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (_disposed) return;
        try {
          await windowManager.setMinimumSize(kWMinSize);

          if (_prefs.containsKey(kWPosX)) {
            await windowManager.setPosition(
              Offset(clamped[kWPosX]!, clamped[kWPosY]!),
            );
          }

          if (clamped[kWMaximized] == true) {
            await windowManager.maximize();
          }

          await windowManager.setPreventClose(true);
          await windowManager.setAsFrameless();
          await windowManager.show();
          await windowManager.focus();

          if (clamped[kWFullscreen] == true) {
            await windowManager.setFullScreen(true);
          }

          windowManager.addListener(_WindowListener(this));
          _initialized = true;
        } on Exception catch (e) {
          debugPrint('[WindowState] init failed: $e');
          _initialized = true;
        } finally {
          if (!_initCompleter!.isCompleted) _initCompleter!.complete();
        }
      });
    } on Exception catch (e) {
      debugPrint('[WindowState] init setup failed: $e');
      _initialized = true;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      await _initCompleter!.future;
    }
    await _flush();
    _resizeDebounce?.cancel();
    _s.mode.dispose();
    _s.isAlwaysOnTop.dispose();
    _s.isMaximized.dispose();
    _s.interaction.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // Commands
  // ═══════════════════════════════════════════════════════════════════

  Future<void> minimize() async {
    try {
      await windowManager.minimize();
    } on Exception catch (e) {
      debugPrint('[WindowState] minimize failed: $e');
    }
  }

  Future<void> toggleMaximize() async {
    try {
      if (_s.isMaximized.value) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } on Exception catch (e) {
      debugPrint('[WindowState] toggleMaximize failed: $e');
    }
  }

  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    try {
      await _flush();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } on Exception catch (e) {
      debugPrint('[WindowState] close failed: $e');
    }
  }

  Future<void> startDragging() async {
    try {
      await windowManager.startDragging();
    } on Exception catch (e) {
      debugPrint('[WindowState] startDragging failed: $e');
    }
  }

  Future<void> toggleAlwaysOnTop() async {
    try {
      final next = !_s.isAlwaysOnTop.value;
      await windowManager.setAlwaysOnTop(next);
      _s.isAlwaysOnTop.value = next;
    } on Exception catch (e) {
      debugPrint('[WindowState] toggleAlwaysOnTop failed: $e');
    }
  }

  Future<void> toggleFullscreen() async {
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      if (_s.mode.value == WindowMode.fullscreen) {
        await _exitFullscreen();
      } else {
        await _enterFullscreen();
      }
    } on Exception catch (e) {
      debugPrint('[WindowState] toggleFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
      _onResizeEnd();
    }
  }

  Future<void> exitFullscreen() async {
    if (_s.mode.value != WindowMode.fullscreen) return;
    if (_togglingFullscreen || _disposed) return;
    _togglingFullscreen = true;
    try {
      await _exitFullscreen();
    } on Exception catch (e) {
      debugPrint('[WindowState] exitFullscreen failed: $e');
    } finally {
      _togglingFullscreen = false;
      _onResizeEnd();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Fullscreen (内联, 原 FullscreenManager)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _enterFullscreen() async {
    _savedRatio = AspectRatioService.I.current;
    if (_savedRatio > 0) await AspectRatioService.I.unlock();
    await windowManager.setFullScreen(true);
  }

  Future<void> _exitFullscreen() async {
    await windowManager.setFullScreen(false);
    if (_savedRatio > 0) {
      await AspectRatioService.I.setAspectRatio(_savedRatio);
      _savedRatio = 0.0;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Geometry Persistence
  // ═══════════════════════════════════════════════════════════════════

  Map<String, double> _loadGeometry() {
    return {
      kWWidth: _prefs.getDouble(kWWidth) ?? kWDefaultWidth,
      kWHeight: _prefs.getDouble(kWHeight) ?? kWDefaultHeight,
      kWPosX: _prefs.getDouble(kWPosX) ?? 10.0,
      kWPosY: _prefs.getDouble(kWPosY) ?? 10.0,
    };
  }

  Map<String, dynamic> _clampToVisibleBounds(Map<String, double> geo) {
    final result = <String, dynamic>{
      kWWidth: geo[kWWidth],
      kWHeight: geo[kWHeight],
      kWPosX: geo[kWPosX],
      kWPosY: geo[kWPosY],
      kWMaximized: _prefs.getBool(kWMaximized) ?? false,
      kWFullscreen: _prefs.getBool(kWFullscreen) ?? false,
    };
    try {
      final display = PlatformDispatcher.instance.views.first;
      final screenW =
          display.physicalSize.width / display.devicePixelRatio;
      final screenH =
          display.physicalSize.height / display.devicePixelRatio;

      final w = geo[kWWidth]!;
      final h = geo[kWHeight]!;
      final x = geo[kWPosX]!;
      final y = geo[kWPosY]!;

      final isOffScreen = x + w < kWMinVisible ||
          y + h < kWMinVisible ||
          x > screenW - kWMinVisible ||
          y > screenH - kWMinVisible;

      if (isOffScreen) {
        result[kWPosX] =
            ((screenW - w) / 2).clamp(0, screenW - kWMinVisible);
        result[kWPosY] =
            ((screenH - h) / 2).clamp(0, screenH - kWMinVisible);
      }
    } on Exception catch (e) {
      debugPrint('[WindowState] bounds check failed: $e');
    }
    return result;
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: kWResizeDebounceMs),
      _persistNow,
    );
  }

  Future<void> _persistNow() async {
    if (_persistInFlight != null) return _persistInFlight!.future;
    _persistInFlight = Completer<void>();
    try {
      final results = await Future.wait([
        windowManager.getSize(),
        windowManager.getPosition(),
      ]);
      final size = results[0] as Size;
      final position = results[1] as Offset;
      await Future.wait([
        _prefs.setDouble(kWWidth, size.width),
        _prefs.setDouble(kWHeight, size.height),
        _prefs.setDouble(kWPosX, position.dx),
        _prefs.setDouble(kWPosY, position.dy),
        _prefs.setBool(kWMaximized, _s.isMaximized.value),
      ]);
      _persistInFlight!.complete();
    } on Exception catch (e) {
      debugPrint('[WindowState] persist failed: $e');
      if (!_persistInFlight!.isCompleted) _persistInFlight!.complete();
    } finally {
      _persistInFlight = null;
    }
  }

  void _saveFullscreen(bool value) {
    _prefs.setBool(kWFullscreen, value);
    SettingsStore.saveIsFullscreen(value);
  }

  Future<void> _flush() async {
    _persistDebounce?.cancel();
    if (_persistInFlight != null && !_persistInFlight!.isCompleted) {
      await _persistInFlight!.future;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Resize Debounce
  // ═══════════════════════════════════════════════════════════════════

  void _onResizeStart() {
    if (_s.interaction.value != WindowInteractionState.resizing) {
      _s.interaction.value = WindowInteractionState.resizing;
    }
    _resizeDebounce?.cancel();
  }

  void _onResizeEnd() {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(
      const Duration(milliseconds: kWResizeDebounceMs),
      () => _s.interaction.value = WindowInteractionState.idle,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WindowListener — 引用 WindowService
// ═══════════════════════════════════════════════════════════════════════

class _WindowListener extends WindowListener {
  _WindowListener(this._svc);
  final WindowService _svc;

  @override
  void onWindowClose() => _svc.close();

  @override
  void onWindowResize() => _svc._onResizeStart();

  @override
  void onWindowResized() {
    _svc._onResizeEnd();
    _svc._schedulePersist();
  }

  @override
  void onWindowMove() => _svc._schedulePersist();

  @override
  void onWindowMoved() => _svc._schedulePersist();

  @override
  void onWindowMaximize() {
    _svc._s.isMaximized.value = true;
    _svc._persistNow();
  }

  @override
  void onWindowUnmaximize() {
    _svc._s.isMaximized.value = false;
    _svc._persistNow();
  }

  @override
  void onWindowEnterFullScreen() {
    _svc._s.mode.value = WindowMode.fullscreen;
    _svc._saveFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    _svc._s.mode.value = WindowMode.windowed;
    _svc._saveFullscreen(false);
  }

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
