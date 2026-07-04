import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
export '../models/app_settings.dart';
import '../utils/log.dart';
import 'settings_validator.dart';

/// 应用设置持久化 (shared_preferences)
///
/// 所有 save 方法 try-catch 防御磁盘满/权限错误。
/// load() 失败返回安全默认值，永不崩溃。
///
/// RC-3: 窗口几何验证 — 防止 NaN/Infinity/负值永久损坏持久化数据。
///
/// PERF: 启动预热 — prewarm() 在 main.dart 中调用，缓存 SharedPreferences 实例，
/// 避免 load()/save() 重复调用 SharedPreferences.getInstance() 的平台 I/O 开销。
class SettingsStore {
  // ── 常量已迁移至 SettingsValidator ──

  SettingsStore._(SharedPreferences? prefs) : _cachedPrefs = prefs;

  /// 创建独立实例 — 测试注入 SharedPreferences，生产环境使用 prewarm()
  ///
  /// ```dart
  /// final store = SettingsStore.create(prefs);
  /// final settings = await store.load();
  /// ```
  factory SettingsStore.create(SharedPreferences prefs) {
    return SettingsStore._(prefs);
  }

  /// 默认实例 — 生产环境使用
  static SettingsStore? _instance;

  /// 预热缓存的 SharedPreferences 实例（由 main.dart 在 runApp 前设置）
  final SharedPreferences? _cachedPrefs;

  /// 预热：缓存已获取的 SharedPreferences 实例，避免后续重复 getInstance() 调用
  static void prewarm(SharedPreferences prefs) {
    _instance = SettingsStore._(prefs);
  }

  /// 重置预热缓存（仅供测试使用）
  ///
  /// 可选 [newInstance] 替换默认实例（用于注入自定义 SharedPreferences）。
  @visibleForTesting
  static void resetPrewarm({SettingsStore? newInstance}) {
    _instance = newInstance;
  }

  /// 获取 SharedPreferences 实例（优先使用缓存）
  Future<SharedPreferences> _getPrefs() async =>
      _cachedPrefs ?? await SharedPreferences.getInstance();

  static const _keyVolume = 'volume';
  static const _keyLastFile = 'lastFile';
  static const _keyWindowWidth = 'windowWidth';
  static const _keyWindowHeight = 'windowHeight';
  static const _keyPlayMode = 'playMode';
  static const _keyIsMuted = 'isMuted';
  static const _keySubtitleFontSize = 'subtitleFontSize';
  static const _keySubtitleColorIndex = 'subtitleColorIndex';
  static const _keySubtitleBottomOffset = 'subtitleBottomOffset';
  static const _keyWindowX = 'windowX';
  static const _keyWindowY = 'windowY';
  static const _keyIsMaximized = 'isMaximized';
  static const _keyIsAlwaysOnTop = 'isAlwaysOnTop';
  static const _keyIsFullscreen = 'isFullscreen';
  static const _keyVideoBrightness = 'videoBrightness';
  static const _keyVideoContrast = 'videoContrast';
  static const _keyVideoSaturation = 'videoSaturation';
  static const _keyVideoHue = 'videoHue';
  static const _keyVideoRotation = 'videoRotation';
  static const _keyVideoAspectRatio = 'videoAspectRatio';
  static const _keyVideoDeinterlace = 'videoDeinterlace';
  static const _keyD3d11Sync = 'd3d11Sync';
  static const _keyHardwareDecoding = 'hardwareDecoding';
  static const _keyPlaybackSpeed = 'playbackSpeed';
  static const _keyLocale = 'locale';
  static const _keyThemeIndex = 'themeIndex';
  static const _keyShortcuts = 'shortcuts';

  static Future<AppSettings> load() async => (_instance ?? SettingsStore._(null))._loadImpl();

  Future<AppSettings> _loadImpl() async {
    try {
      final prefs = await _getPrefs();
      
      return AppSettings(
        volume: SettingsValidator.volume(prefs.getDouble(_keyVolume) ?? 1.0),
        lastFile: prefs.getString(_keyLastFile) ?? '',
        // RC-3: 验证窗口尺寸 — 防止 NaN/损坏数据导致启动失败
        windowWidth: SettingsValidator.sanitizeDimension(
          prefs.getDouble(_keyWindowWidth) ?? SettingsValidator.windowWidthDefault,
          SettingsValidator.windowWidthDefault,
          SettingsValidator.windowWidthMin,
          SettingsValidator.windowWidthMax,
        ),
        windowHeight: SettingsValidator.sanitizeDimension(
          prefs.getDouble(_keyWindowHeight) ?? SettingsValidator.windowHeightDefault,
          SettingsValidator.windowHeightDefault,
          SettingsValidator.windowHeightMin,
          SettingsValidator.windowHeightMax,
        ),
        windowX: prefs.getDouble(_keyWindowX) != null
            ? SettingsValidator.sanitizeCoordinate(prefs.getDouble(_keyWindowX)!, 0)
            : null,
        windowY: prefs.getDouble(_keyWindowY) != null
            ? SettingsValidator.sanitizeCoordinate(prefs.getDouble(_keyWindowY)!, 0)
            : null,
        isMaximized: prefs.getBool(_keyIsMaximized) ?? false,
        playMode: SettingsValidator.playMode(prefs.getInt(_keyPlayMode) ?? 0),
        isMuted: prefs.getBool(_keyIsMuted) ?? false,
        isAlwaysOnTop: prefs.getBool(_keyIsAlwaysOnTop) ?? false,
        subtitleFontSize: SettingsValidator.subtitleFontSize(
          prefs.getDouble(_keySubtitleFontSize) ?? SettingsValidator.subtitleFontSizeDefault,
        ),
        subtitleColorIndex: SettingsValidator.subtitleColorIndex(
          prefs.getInt(_keySubtitleColorIndex) ?? 0,
        ),
        subtitleBottomOffset: SettingsValidator.subtitleOffset(
          prefs.getDouble(_keySubtitleBottomOffset) ?? SettingsValidator.subtitleOffsetDefault,
        ),
        // 视频处理 — 防篡改：clamp 到有效范围，解析失败用默认值
        videoBrightness: SettingsValidator.videoEffect(prefs.getDouble(_keyVideoBrightness) ?? 0.0),
        videoContrast: SettingsValidator.videoEffect(prefs.getDouble(_keyVideoContrast) ?? 0.0),
        videoSaturation: SettingsValidator.videoEffect(prefs.getDouble(_keyVideoSaturation) ?? 0.0),
        videoHue: SettingsValidator.videoEffect(prefs.getDouble(_keyVideoHue) ?? 0.0),
        videoRotation: SettingsValidator.sanitizeRotation(prefs.getInt(_keyVideoRotation) ?? 0),
        videoAspectRatioIndex: SettingsValidator.videoAspectRatioIndex(
          prefs.getInt(_keyVideoAspectRatio) ?? 0,
        ),
        videoDeinterlace: prefs.getBool(_keyVideoDeinterlace) ?? false,
        d3d11Sync: prefs.getBool(_keyD3d11Sync) ?? true,
        hardwareDecoding: prefs.getBool(_keyHardwareDecoding) ?? true,
      );
    } on Exception catch (e) {
      log.e('SettingsStore.load failed: $e');
      return const AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: SettingsValidator.windowWidthDefault,
        windowHeight: SettingsValidator.windowHeightDefault,
        playMode: 0,
        isMuted: false,
        isAlwaysOnTop: false,
        subtitleFontSize: SettingsValidator.subtitleFontSizeDefault,
        subtitleColorIndex: 0,
        subtitleBottomOffset: SettingsValidator.subtitleOffsetDefault,
        videoBrightness: 0.0,
        videoContrast: 0.0,
        videoSaturation: 0.0,
        videoHue: 0.0,
        videoRotation: 0,
        videoAspectRatioIndex: 0,
        videoDeinterlace: false,
        d3d11Sync: true,
        hardwareDecoding: true,
      );
    }
  }

  /// 通用 save 辅助 — 消除 SharedPreferences.getInstance + try-catch 样板
  Future<void> _saveImpl(
    String method,
    Future<void> Function(SharedPreferences prefs) op,
  ) async {
    try {
      final prefs = await _getPrefs();
      await op(prefs);
    } on Exception catch (e) {
      log.e('SettingsStore.$method failed: $e');
    }
  }

  /// 默认实例的 _save 包装
  static Future<void> _save(
    String method,
    Future<void> Function(SharedPreferences prefs) op,
  ) async => (_instance ?? SettingsStore._(null))._saveImpl(method, op);

  static Future<void> saveVolume(double value) => _save(
    'saveVolume',
    (p) => p.setDouble(_keyVolume, SettingsValidator.volume(value)),
  );

  static Future<void> saveLastFile(String path) =>
      _save('saveLastFile', (p) => p.setString(_keyLastFile, path));

  /// 保存窗口几何（位置 + 大小 + 最大化状态）
  ///
  /// RC-3: 验证输入防止 NaN/Infinity 损坏持久化数据。
  /// RC-4: 顺序写入替代 Future.wait — 保证数据一致性（~4ms 延迟差可忽略）。
  static Future<void> saveWindowGeometry({
    required double width,
    required double height,
    required double x,
    required double y,
    required bool isMaximized,
  }) => _save('saveWindowGeometry', (p) async {
    
    final safeWidth = SettingsValidator.sanitizeDimension(width, SettingsValidator.windowWidthDefault, SettingsValidator.windowWidthMin, SettingsValidator.windowWidthMax);
    final safeHeight = SettingsValidator.sanitizeDimension(height, SettingsValidator.windowHeightDefault, SettingsValidator.windowHeightMin, SettingsValidator.windowHeightMax);
    final safeX = SettingsValidator.sanitizeCoordinate(x, 0);
    final safeY = SettingsValidator.sanitizeCoordinate(y, 0);
    // RC-4: 顺序写入 — 避免 Future.wait 部分成功导致数据不一致
    await p.setDouble(_keyWindowWidth, safeWidth);
    await p.setDouble(_keyWindowHeight, safeHeight);
    await p.setDouble(_keyWindowX, safeX);
    await p.setDouble(_keyWindowY, safeY);
    await p.setBool(_keyIsMaximized, isMaximized);
  });

  static Future<void> savePlayMode(int mode) => _save(
    'savePlayMode',
    (p) => p.setInt(_keyPlayMode, SettingsValidator.playMode(mode)),
  );

  static Future<void> saveIsMuted(bool value) =>
      _save('saveIsMuted', (p) => p.setBool(_keyIsMuted, value));

  static Future<void> saveIsAlwaysOnTop(bool value) =>
      _save('saveIsAlwaysOnTop', (p) => p.setBool(_keyIsAlwaysOnTop, value));

  static Future<void> saveIsFullscreen(bool value) =>
      _save('saveIsFullscreen', (p) => p.setBool(_keyIsFullscreen, value));

  /// 加载语言偏好，默认 'zh'（中文）
  static Future<String> loadLocale() async => (_instance ?? SettingsStore._(null))._loadLocaleImpl();

  Future<String> _loadLocaleImpl() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(_keyLocale) ?? SettingsValidator.defaultLocale;
    } on Exception catch (e) {
      log.e('SettingsStore.loadLocale failed: $e');
      return 'zh';
    }
  }

  /// 保存语言偏好
  static Future<void> saveLocale(String localeCode) =>
      _save('saveLocale', (p) => p.setString(_keyLocale, localeCode));

  /// 加载主题索引，默认 0（Midnight）
  static Future<int> loadThemeIndex() async => (_instance ?? SettingsStore._(null))._loadThemeIndexImpl();

  Future<int> _loadThemeIndexImpl() async {
    try {
      final prefs = await _getPrefs();
      return SettingsValidator.themeIndex(prefs.getInt(_keyThemeIndex) ?? 0);
    } on Exception catch (e) {
      log.e('SettingsStore.loadThemeIndex failed: $e');
      return 0;
    }
  }

  /// 保存主题索引
  static Future<void> saveThemeIndex(int index) => _save(
    'saveThemeIndex',
    (p) => p.setInt(_keyThemeIndex, SettingsValidator.themeIndex(index)),
  );

  /// 加载自定义快捷键映射 (action → LogicalKeyboardKey.keyName)
  static Future<Map<String, String>> loadShortcuts() async => (_instance ?? SettingsStore._(null))._loadShortcutsImpl();

  Future<Map<String, String>> _loadShortcutsImpl() async {
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_keyShortcuts);
      if (json == null || json.isEmpty) return {};
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } on Exception catch (e) {
      log.e('SettingsStore.loadShortcuts failed: $e');
      return {};
    }
  }

  /// 保存自定义快捷键映射
  static Future<void> saveShortcuts(Map<String, String> bindings) => _save(
    'saveShortcuts',
    (p) => p.setString(_keyShortcuts, jsonEncode(bindings)),
  );

  static Future<void> saveSubtitleFontSize(double value) => _save(
    'saveSubtitleFontSize',
    (p) => p.setDouble(_keySubtitleFontSize, SettingsValidator.subtitleFontSize(value)),
  );

  static Future<void> saveSubtitleColorIndex(int index) => _save(
    'saveSubtitleColorIndex',
    (p) => p.setInt(_keySubtitleColorIndex, SettingsValidator.subtitleColorIndex(index)),
  );

  static Future<void> saveSubtitleBottomOffset(double value) => _save(
    'saveSubtitleBottomOffset',
    (p) => p.setDouble(_keySubtitleBottomOffset, SettingsValidator.subtitleOffset(value)),
  );

  // ─── 视频处理持久化 ───

  static Future<void> saveVideoBrightness(double value) => _save(
    'saveVideoBrightness',
    (p) => p.setDouble(_keyVideoBrightness, SettingsValidator.videoEffect(value)),
  );

  static Future<void> saveVideoContrast(double value) => _save(
    'saveVideoContrast',
    (p) => p.setDouble(_keyVideoContrast, SettingsValidator.videoEffect(value)),
  );

  static Future<void> saveVideoSaturation(double value) => _save(
    'saveVideoSaturation',
    (p) => p.setDouble(_keyVideoSaturation, SettingsValidator.videoEffect(value)),
  );

  static Future<void> saveVideoHue(double value) => _save(
    'saveVideoHue',
    (p) => p.setDouble(_keyVideoHue, SettingsValidator.videoEffect(value)),
  );

  static Future<void> saveVideoRotation(int degree) => _save(
    'saveVideoRotation',
    (p) => p.setInt(_keyVideoRotation, SettingsValidator.sanitizeRotation(degree)),
  );

  static Future<void> saveVideoAspectRatioIndex(int index) => _save(
    'saveVideoAspectRatioIndex',
    (p) => p.setInt(
      _keyVideoAspectRatio,
      SettingsValidator.videoAspectRatioIndex(index),
    ),
  );

  static Future<void> saveVideoDeinterlace(bool enable) => _save(
    'saveVideoDeinterlace',
    (p) => p.setBool(_keyVideoDeinterlace, enable),
  );

  // ─── 性能设置持久化 ───

  static Future<void> saveD3d11SyncEnabled(bool value) =>
      _save('saveD3d11SyncEnabled', (p) => p.setBool(_keyD3d11Sync, value));

  static Future<void> saveHardwareDecoding(bool value) => _save(
    'saveHardwareDecoding',
    (p) => p.setBool(_keyHardwareDecoding, value),
  );

  // ─── 播放速度持久化 ───

  static Future<void> savePlaybackSpeed(double value) => _save(
    'savePlaybackSpeed',
    (p) => p.setDouble(_keyPlaybackSpeed, SettingsValidator.playbackSpeed(value)),
  );

  static Future<double> loadPlaybackSpeed() async =>
      (_instance ?? SettingsStore._(null))._loadPlaybackSpeedImpl();

  Future<double> _loadPlaybackSpeedImpl() async {
    try {
      final prefs = await _getPrefs();
      return SettingsValidator.playbackSpeed(
        prefs.getDouble(_keyPlaybackSpeed) ?? SettingsValidator.playbackSpeedDefault,
      );
    } on Exception catch (e) {
      log.e('SettingsStore.loadPlaybackSpeed failed: $e');
      return SettingsValidator.playbackSpeedDefault;
    }
  }

  /// 加载 D3D11 同步设置，默认 true（同步模式）
  static Future<bool> loadD3d11SyncEnabled() async => (_instance ?? SettingsStore._(null))._loadD3d11SyncEnabledImpl();

  Future<bool> _loadD3d11SyncEnabledImpl() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_keyD3d11Sync) ?? true;
    } on Exception catch (e) {
      log.e('SettingsStore.loadD3d11SyncEnabled failed: $e');
      return true;
    }
  }

  /// 加载硬件解码设置，默认 true（硬件解码优先）
  static Future<bool> loadHardwareDecoding() async => (_instance ?? SettingsStore._(null))._loadHardwareDecodingImpl();

  Future<bool> _loadHardwareDecodingImpl() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_keyHardwareDecoding) ?? true;
    } on Exception catch (e) {
      log.e('SettingsStore.loadHardwareDecoding failed: $e');
      return true;
    }
  }

  /// 批量保存所有设置（顺序写入保证一致性）
  ///
  /// RC-3: 窗口尺寸验证。
  /// RC-4: 顺序写入。
  /// RC-8: windowX/windowY 为 null 时显式清除旧键。
  static Future<void> saveAll(AppSettings s) => _save('saveAll', (p) async {
    
    await p.setDouble(_keyVolume, SettingsValidator.volume(s.volume));
    await p.setString(_keyLastFile, s.lastFile);
    // RC-3: 验证窗口尺寸
    await p.setDouble(
      _keyWindowWidth,
      SettingsValidator.sanitizeDimension(s.windowWidth, SettingsValidator.windowWidthDefault, SettingsValidator.windowWidthMin, SettingsValidator.windowWidthMax),
    );
    await p.setDouble(
      _keyWindowHeight,
      SettingsValidator.sanitizeDimension(s.windowHeight, SettingsValidator.windowHeightDefault, SettingsValidator.windowHeightMin, SettingsValidator.windowHeightMax),
    );
    await p.setInt(_keyPlayMode, SettingsValidator.playMode(s.playMode));
    await p.setBool(_keyIsMuted, s.isMuted);
    await p.setDouble(_keySubtitleFontSize, SettingsValidator.subtitleFontSize(s.subtitleFontSize));
    await p.setInt(_keySubtitleColorIndex, SettingsValidator.subtitleColorIndex(s.subtitleColorIndex));
    await p.setDouble(_keySubtitleBottomOffset, SettingsValidator.subtitleOffset(s.subtitleBottomOffset));
    await p.setBool(_keyIsMaximized, s.isMaximized);
    await p.setBool(_keyIsAlwaysOnTop, s.isAlwaysOnTop);
    // 视频处理
    await p.setDouble(_keyVideoBrightness, SettingsValidator.videoEffect(s.videoBrightness));
    await p.setDouble(_keyVideoContrast, SettingsValidator.videoEffect(s.videoContrast));
    await p.setDouble(_keyVideoSaturation, SettingsValidator.videoEffect(s.videoSaturation));
    await p.setDouble(_keyVideoHue, SettingsValidator.videoEffect(s.videoHue));
    await p.setInt(_keyVideoRotation, SettingsValidator.sanitizeRotation(s.videoRotation));
    await p.setInt(_keyVideoAspectRatio, SettingsValidator.videoAspectRatioIndex(s.videoAspectRatioIndex));
    await p.setBool(_keyVideoDeinterlace, s.videoDeinterlace);
    // 性能设置
    await p.setBool(_keyD3d11Sync, s.d3d11Sync);
    await p.setBool(_keyHardwareDecoding, s.hardwareDecoding);
    // RC-8: null 时显式清除旧键，防止残留值导致下次启动位置错误
    if (s.windowX != null) {
      await p.setDouble(_keyWindowX, SettingsValidator.sanitizeCoordinate(s.windowX!, 0));
    } else {
      await p.remove(_keyWindowX);
    }
    if (s.windowY != null) {
      await p.setDouble(_keyWindowY, SettingsValidator.sanitizeCoordinate(s.windowY!, 0));
    } else {
      await p.remove(_keyWindowY);
    }
  });
}
