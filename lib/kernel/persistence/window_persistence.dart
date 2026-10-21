import 'dart:convert';
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
/// 1280×720 launch geometry rather than preventing the application from
/// opening. Storage is a single JSON blob key — one file rewrite per save,
/// atomic by construction — replacing six per-field writes per save. Legacy
/// per-field keys from older installs are still read as a fallback and are
/// cleaned up on the first save after migration.
final class WindowPersistence {
  /// Creates persistence backed by [_preferences], when supplied for tests.
  WindowPersistence({this._preferences});

  /// 快照 blob key — 窗口几何整体存为一个 JSON 字符串。Windows 平台上
  /// SharedPreferences 每次 set 都整文件重写, 旧逐字段方案每次落盘要
  /// 重写 6 次; 单 blob 收敛为 1 次, 且天然原子 (消除部分重排快照)。
  static const _snapshotKey = 'windowSnapshot';

  // 旧逐字段 key — 仅用于读取未迁移安装的存量数据; save 时一次性迁入
  // blob 后清除 (见 [_removeLegacyKeys])。
  static const _widthKey = 'windowWidth';
  static const _heightKey = 'windowHeight';
  static const _xKey = 'windowX';
  static const _yKey = 'windowY';
  static const _alwaysOnTopKey = 'isAlwaysOnTop';
  static const _maximizedKey = 'isMaximized';

  static const List<String> _legacyKeys = <String>[
    _widthKey,
    _heightKey,
    _xKey,
    _yKey,
    _alwaysOnTopKey,
    _maximizedKey,
  ];

  static const _maximumDimension = 16384.0;
  static const _maximumCoordinate = 100000.0;

  final SharedPreferences? _preferences;

  /// Loads a safe persisted snapshot, returning defaults when storage is absent.
  Future<PersistedWindowState> load() async {
    try {
      final preferences = await _getPreferences();
      // blob 优先; 缺失或损坏回退旧逐字段 key (升级迁移窗口期), 再损坏
      // 回退稳定默认几何 — 与旧版「损坏偏好回退 720p」语义一致。
      return _decodeSnapshot(preferences.getString(_snapshotKey)) ??
          _loadLegacyKeys(preferences);
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
      await preferences.setString(
        _snapshotKey,
        jsonEncode(<String, Object?>{
          'width': _dimension(
            size.width,
            defaultWindowSize.width,
            minimumWindowSize.width,
          ),
          'height': _dimension(
            size.height,
            defaultWindowSize.height,
            minimumWindowSize.height,
          ),
          'x': position == null ? null : _coordinate(position.dx),
          'y': position == null ? null : _coordinate(position.dy),
          'alwaysOnTop': state.alwaysOnTop,
          'isMaximized': state.isMaximized,
        }),
      );
      await _removeLegacyKeys(preferences);
    } on Exception {
      // Persistence is optional; a failed write must not block window controls.
    }
  }

  /// 旧 key 一次性迁移清理 — containsKey 为内存读; key 清除后本循环
  /// 短路, 后续每次 save 不再产生任何额外写盘。
  Future<void> _removeLegacyKeys(SharedPreferences preferences) async {
    for (final key in _legacyKeys) {
      if (preferences.containsKey(key)) {
        await preferences.remove(key);
      }
    }
  }

  /// 解码快照 blob — 缺失、损坏或字段非法一律返回 null, 由调用方走旧
  /// key 回退路径。外部数据零信任: 非数值字段按缺失处理, 布尔用严格
  /// `== true`, 绝不 `as` 强转。
  static PersistedWindowState? _decodeSnapshot(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      double? field(String name) {
        final value = decoded[name];
        return value is num ? value.toDouble() : null;
      }

      final x = field('x');
      final y = field('y');
      return PersistedWindowState(
        size: Size(
          _dimension(
            field('width'),
            defaultWindowSize.width,
            minimumWindowSize.width,
          ),
          _dimension(
            field('height'),
            defaultWindowSize.height,
            minimumWindowSize.height,
          ),
        ),
        position: x == null || y == null
            ? null
            : Offset(_coordinate(x), _coordinate(y)),
        alwaysOnTop: decoded['alwaysOnTop'] == true,
        isMaximized: decoded['isMaximized'] == true,
      );
    } on Exception {
      return null;
    }
  }

  /// 旧逐字段 key 读取路径 — 升级前安装的存量数据。
  static PersistedWindowState _loadLegacyKeys(SharedPreferences preferences) {
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
  }

  Future<SharedPreferences> _getPreferences() {
    final preferences = _preferences;
    if (preferences != null) {
      return Future<SharedPreferences>.value(preferences);
    }
    return SharedPreferences.getInstance();
  }

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
