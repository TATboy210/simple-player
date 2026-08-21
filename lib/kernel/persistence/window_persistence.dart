import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../window_bridge/window_constants.dart';

/// A validated window snapshot restored between application sessions.
final class PersistedWindowState {
  /// Creates a window snapshot from the last settled desktop window state.
  const PersistedWindowState({
    required this.size,
    required this.position,
    required this.alwaysOnTop,
    required this.isMaximized,
  });

  /// Window outer size in logical pixels.
  final Size size;

  /// Window top-left position in logical pixels.
  final Offset? position;

  /// Whether the window remains above other windows.
  final bool alwaysOnTop;

  /// Whether the window was maximized when the snapshot was saved.
  final bool isMaximized;
}

/// Stores the small amount of desktop window state that survives restarts.
///
/// Invalid or unavailable preferences deliberately fall back to the stable
/// 1280×752 launch geometry rather than preventing the application from opening.
final class WindowPersistence {
  /// Creates persistence backed by [preferences], when supplied for tests.
  WindowPersistence({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _widthKey = 'windowWidth';
  static const _heightKey = 'windowHeight';
  static const _xKey = 'windowX';
  static const _yKey = 'windowY';
  static const _alwaysOnTopKey = 'isAlwaysOnTop';
  static const _maximizedKey = 'isMaximized';

  static const _maximumDimension = 16384.0;
  static const _maximumCoordinate = 100000.0;

  final SharedPreferences? _preferences;

  /// Loads a safe persisted snapshot, returning defaults when storage is absent.
  Future<PersistedWindowState> load() async {
    try {
      final preferences = await _getPreferences();
      return PersistedWindowState(
        size: Size(
          _dimension(
            preferences.getDouble(_widthKey),
            defaultWindowSize.width,
            minimumWindowSize.width,
          ),
          _dimension(
            preferences.getDouble(_heightKey),
            defaultWindowSize.height,
            minimumWindowSize.height,
          ),
        ),
        position: _position(preferences),
        alwaysOnTop: preferences.getBool(_alwaysOnTopKey) ?? false,
        isMaximized: preferences.getBool(_maximizedKey) ?? false,
      );
    } on Exception {
      return const PersistedWindowState(
        size: defaultWindowSize,
        position: null,
        alwaysOnTop: false,
        isMaximized: false,
      );
    }
  }

  /// Persists the latest settled geometry and always-on-top choice.
  Future<void> save(PersistedWindowState state) async {
    try {
      final preferences = await _getPreferences();
      final size = state.size;
      final position = state.position;
      // Sequential writes avoid a partially reordered geometry snapshot.
      await preferences.setDouble(
        _widthKey,
        _dimension(size.width, defaultWindowSize.width, minimumWindowSize.width),
      );
      await preferences.setDouble(
        _heightKey,
        _dimension(size.height, defaultWindowSize.height, minimumWindowSize.height),
      );
      if (position == null) {
        await preferences.remove(_xKey);
        await preferences.remove(_yKey);
      } else {
        await preferences.setDouble(_xKey, _coordinate(position.dx));
        await preferences.setDouble(_yKey, _coordinate(position.dy));
      }
      await preferences.setBool(_alwaysOnTopKey, state.alwaysOnTop);
      await preferences.setBool(_maximizedKey, state.isMaximized);
    } on Exception {
      // Persistence is optional; a failed write must not block window controls.
    }
  }

  Future<SharedPreferences> _getPreferences() async =>
      _preferences ?? SharedPreferences.getInstance();

  static double _dimension(double? value, double fallback, double minimum) {
    if (value == null || !value.isFinite || value < minimum) return fallback;
    return value.clamp(minimum, _maximumDimension).toDouble();
  }

  static Offset? _position(SharedPreferences preferences) {
    final x = preferences.getDouble(_xKey);
    final y = preferences.getDouble(_yKey);
    if (x == null || y == null || !x.isFinite || !y.isFinite) return null;
    return Offset(_coordinate(x), _coordinate(y));
  }

  static double _coordinate(double value) =>
      value.clamp(-_maximumCoordinate, _maximumCoordinate).toDouble();
}
