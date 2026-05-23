import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../kernel/persistence/settings_store.dart';
import 'geometry_store.dart';

/// Shared window geometry persistence — debounce + in-flight guard.
///
/// Composed by platform WindowService implementations.
/// Handles geometry save/load, fullscreen flag, and SettingsStore sync.
class WindowPersistenceService {
  WindowPersistenceService(SharedPreferences prefs) {
    _geometry = WindowGeometryStore(prefs);
  }

  late final WindowGeometryStore _geometry;

  WindowGeometryStore get geometry => _geometry;

  /// Load saved geometry, clamped to visible monitor bounds.
  WindowGeometry loadAndClamp() {
    final saved = _geometry.load();
    return WindowGeometryStore.clampToVisibleBounds(saved);
  }

  // ─── Persist Debounce ───

  static const _persistDebounceMs = 500;

  Timer? _persistDebounce;
  Completer<void>? _persistInFlight;

  /// Schedule a debounced persist of current window state.
  void schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: _persistDebounceMs),
      persistNow,
    );
  }

  /// Persist immediately — reads size/position/maximized from window_manager.
  Future<void> persistNow() async {
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

      _geometry.saveDebounced(
        size: size,
        position: position,
        isMaximized: maximized,
      );
      _persistInFlight!.complete();
    } on Exception catch (e) {
      debugPrint('[WindowPersistence] persist failed: $e');
      if (!_persistInFlight!.isCompleted) _persistInFlight!.complete();
    } finally {
      _persistInFlight = null;
    }
  }

  /// Save fullscreen flag to both geometry store and SettingsStore.
  void saveFullscreen(bool isFullscreen) {
    _geometry.saveFullscreen(isFullscreen);
    SettingsStore.saveIsFullscreen(isFullscreen);
  }

  /// Cancel debounce and wait for in-flight persist.
  Future<void> flush() async {
    _persistDebounce?.cancel();
    await _geometry.flush();
  }

  void dispose() {
    _persistDebounce?.cancel();
    _geometry.dispose();
  }
}
