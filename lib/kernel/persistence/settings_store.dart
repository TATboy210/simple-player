import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/aspect_ratio_mode.dart';
import '../models/play_mode.dart';
export '../models/app_settings.dart';
import '../utils/log.dart';

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
  /// 预热缓存的 SharedPreferences 实例（由 main.dart 在 runApp 前设置）
  static SharedPreferences? _cachedPrefs;

  /// 预热：缓存已获取的 SharedPreferences 实例，避免后续重复 getInstance() 调用
  static void prewarm(SharedPreferences prefs) => _cachedPrefs = prefs;

  /// 重置预热缓存（仅供测试使用）
  @visibleForTesting
  static void resetPrewarm() => _cachedPrefs = null;

  /// 获取 SharedPreferences 实例（优先使用缓存）
  static Future<SharedPreferences> _getPrefs() async =>
      _cachedPrefs ?? await SharedPreferences.getInstance();

  /// RC-3: 验证并修正窗口尺寸 — 防止 NaN/Infinity/负值损坏持久化数据
  static double _sanitizeDimension(
    double v,
    double fallback,
    double min,
    double max,
  ) {
    if (v.isNaN || v.isInfinite || v <= 0) return fallback;
    return v.clamp(min, max);
  }

  /// RC-3: 验证并修正窗口坐标 — 防止 NaN/Infinity 损坏持久化数据
  static double _sanitizeCoordinate(double v, double fallback) {
    if (v.isNaN || v.isInfinite) return fallback;
    return v.clamp(-30000.0, 30000.0); // 覆盖多显示器场景
  }

  /// 验证旋转角度 — 仅允许 0/90/180/270
  static int _sanitizeRotation(int v) {
    const valid = [0, 90, 180, 270];
    return valid.contains(v) ? v : 0;
  }

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
  static const _keyVideoBrightness = 'videoBrightness';
  static const _keyVideoContrast = 'videoContrast';
  static const _keyVideoSaturation = 'videoSaturation';
  static const _keyVideoHue = 'videoHue';
  static const _keyVideoRotation = 'videoRotation';
  static const _keyVideoAspectRatio = 'videoAspectRatio';
  static const _keyVideoDeinterlace = 'videoDeinterlace';
  static const _keyD3d11Sync = 'd3d11Sync';
  static const _keyHardwareDecoding = 'hardwareDecoding';
  static const _keyLocale = 'locale';
  static const _keyThemeIndex = 'themeIndex';
  static const _keyShortcuts = 'shortcuts';

  static Future<AppSettings> load() async {
    try {
      final prefs = await _getPrefs();
      return AppSettings(
        volume: (prefs.getDouble(_keyVolume) ?? 1.0).clamp(0.0, 1.0),
        lastFile: prefs.getString(_keyLastFile) ?? '',
        // RC-3: 验证窗口尺寸 — 防止 NaN/损坏数据导致启动失败
        windowWidth: _sanitizeDimension(
          prefs.getDouble(_keyWindowWidth) ?? 1280,
          1280,
          1024,
          8192,
        ),
        windowHeight: _sanitizeDimension(
          prefs.getDouble(_keyWindowHeight) ?? 752,
          752,
          513,
          4608,
        ),
        windowX: prefs.getDouble(_keyWindowX) != null
            ? _sanitizeCoordinate(prefs.getDouble(_keyWindowX)!, 0)
            : null,
        windowY: prefs.getDouble(_keyWindowY) != null
            ? _sanitizeCoordinate(prefs.getDouble(_keyWindowY)!, 0)
            : null,
        isMaximized: prefs.getBool(_keyIsMaximized) ?? false,
        playMode: (prefs.getInt(_keyPlayMode) ?? 0).clamp(
          0,
          PlayMode.values.length - 1,
        ),
        isMuted: prefs.getBool(_keyIsMuted) ?? false,
        isAlwaysOnTop: prefs.getBool(_keyIsAlwaysOnTop) ?? false,
        subtitleFontSize: (prefs.getDouble(_keySubtitleFontSize) ?? 17.0).clamp(
          14.0,
          28.0,
        ),
        subtitleColorIndex: (prefs.getInt(_keySubtitleColorIndex) ?? 0).clamp(
          0,
          2,
        ),
        subtitleBottomOffset:
            (prefs.getDouble(_keySubtitleBottomOffset) ?? 80.0).clamp(
              60.0,
              200.0,
            ),
        // 视频处理 — 防篡改：clamp 到有效范围，解析失败用默认值
        videoBrightness: (prefs.getDouble(_keyVideoBrightness) ?? 0.0).clamp(
          -1.0,
          1.0,
        ),
        videoContrast: (prefs.getDouble(_keyVideoContrast) ?? 0.0).clamp(
          -1.0,
          1.0,
        ),
        videoSaturation: (prefs.getDouble(_keyVideoSaturation) ?? 0.0).clamp(
          -1.0,
          1.0,
        ),
        videoHue: (prefs.getDouble(_keyVideoHue) ?? 0.0).clamp(-1.0, 1.0),
        videoRotation: _sanitizeRotation(prefs.getInt(_keyVideoRotation) ?? 0),
        videoAspectRatioIndex: (prefs.getInt(_keyVideoAspectRatio) ?? 0).clamp(
          0,
          AspectRatioMode.values.length - 1,
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
        windowWidth: 1280,
        windowHeight: 752,
        playMode: 0,
        isMuted: false,
        isAlwaysOnTop: false,
        subtitleFontSize: 17.0,
        subtitleColorIndex: 0,
        subtitleBottomOffset: 80.0,
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
  static Future<void> _save(
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

  static Future<void> saveVolume(double value) => _save(
    'saveVolume',
    (p) => p.setDouble(_keyVolume, value.clamp(0.0, 1.0)),
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
    final safeWidth = _sanitizeDimension(width, 1280, 1024, 8192);
    final safeHeight = _sanitizeDimension(height, 752, 513, 4608);
    final safeX = _sanitizeCoordinate(x, 0);
    final safeY = _sanitizeCoordinate(y, 0);
    // RC-4: 顺序写入 — 避免 Future.wait 部分成功导致数据不一致
    await p.setDouble(_keyWindowWidth, safeWidth);
    await p.setDouble(_keyWindowHeight, safeHeight);
    await p.setDouble(_keyWindowX, safeX);
    await p.setDouble(_keyWindowY, safeY);
    await p.setBool(_keyIsMaximized, isMaximized);
  });

  static Future<void> savePlayMode(int mode) => _save(
    'savePlayMode',
    (p) => p.setInt(_keyPlayMode, mode.clamp(0, PlayMode.values.length - 1)),
  );

  static Future<void> saveIsMuted(bool value) =>
      _save('saveIsMuted', (p) => p.setBool(_keyIsMuted, value));

  static Future<void> saveIsAlwaysOnTop(bool value) =>
      _save('saveIsAlwaysOnTop', (p) => p.setBool(_keyIsAlwaysOnTop, value));

  /// 加载语言偏好，默认 'zh'（中文）
  static Future<String> loadLocale() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(_keyLocale) ?? 'zh';
    } on Exception catch (e) {
      log.e('SettingsStore.loadLocale failed: $e');
      return 'zh';
    }
  }

  /// 保存语言偏好
  static Future<void> saveLocale(String localeCode) =>
      _save('saveLocale', (p) => p.setString(_keyLocale, localeCode));

  /// 加载主题索引，默认 0（Midnight）
  static Future<int> loadThemeIndex() async {
    try {
      final prefs = await _getPrefs();
      return (prefs.getInt(_keyThemeIndex) ?? 0).clamp(0, 2);
    } on Exception catch (e) {
      log.e('SettingsStore.loadThemeIndex failed: $e');
      return 0;
    }
  }

  /// 保存主题索引
  static Future<void> saveThemeIndex(int index) => _save(
    'saveThemeIndex',
    (p) => p.setInt(_keyThemeIndex, index.clamp(0, 2)),
  );

  /// 加载自定义快捷键映射 (action → LogicalKeyboardKey.keyName)
  static Future<Map<String, String>> loadShortcuts() async {
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
    (p) => p.setDouble(_keySubtitleFontSize, value.clamp(14.0, 28.0)),
  );

  static Future<void> saveSubtitleColorIndex(int index) => _save(
    'saveSubtitleColorIndex',
    (p) => p.setInt(_keySubtitleColorIndex, index.clamp(0, 2)),
  );

  static Future<void> saveSubtitleBottomOffset(double value) => _save(
    'saveSubtitleBottomOffset',
    (p) => p.setDouble(_keySubtitleBottomOffset, value.clamp(60.0, 200.0)),
  );

  // ─── 视频处理持久化 ───

  static Future<void> saveVideoBrightness(double value) => _save(
    'saveVideoBrightness',
    (p) => p.setDouble(_keyVideoBrightness, value.clamp(-1.0, 1.0)),
  );

  static Future<void> saveVideoContrast(double value) => _save(
    'saveVideoContrast',
    (p) => p.setDouble(_keyVideoContrast, value.clamp(-1.0, 1.0)),
  );

  static Future<void> saveVideoSaturation(double value) => _save(
    'saveVideoSaturation',
    (p) => p.setDouble(_keyVideoSaturation, value.clamp(-1.0, 1.0)),
  );

  static Future<void> saveVideoHue(double value) => _save(
    'saveVideoHue',
    (p) => p.setDouble(_keyVideoHue, value.clamp(-1.0, 1.0)),
  );

  static Future<void> saveVideoRotation(int degree) => _save(
    'saveVideoRotation',
    (p) => p.setInt(_keyVideoRotation, _sanitizeRotation(degree)),
  );

  static Future<void> saveVideoAspectRatioIndex(int index) => _save(
    'saveVideoAspectRatioIndex',
    (p) => p.setInt(
      _keyVideoAspectRatio,
      index.clamp(0, AspectRatioMode.values.length - 1),
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

  /// 加载 D3D11 同步设置，默认 true（同步模式）
  static Future<bool> loadD3d11SyncEnabled() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_keyD3d11Sync) ?? true;
    } on Exception catch (e) {
      log.e('SettingsStore.loadD3d11SyncEnabled failed: $e');
      return true;
    }
  }

  /// 加载硬件解码设置，默认 true（硬件解码优先）
  static Future<bool> loadHardwareDecoding() async {
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
    await p.setDouble(_keyVolume, s.volume.clamp(0.0, 1.0));
    await p.setString(_keyLastFile, s.lastFile);
    // RC-3: 验证窗口尺寸
    await p.setDouble(
      _keyWindowWidth,
      _sanitizeDimension(s.windowWidth, 1280, 1024, 8192),
    );
    await p.setDouble(
      _keyWindowHeight,
      _sanitizeDimension(s.windowHeight, 752, 513, 4608),
    );
    await p.setInt(
      _keyPlayMode,
      s.playMode.clamp(0, PlayMode.values.length - 1),
    );
    await p.setBool(_keyIsMuted, s.isMuted);
    await p.setDouble(
      _keySubtitleFontSize,
      s.subtitleFontSize.clamp(14.0, 28.0),
    );
    await p.setInt(_keySubtitleColorIndex, s.subtitleColorIndex.clamp(0, 2));
    await p.setDouble(
      _keySubtitleBottomOffset,
      s.subtitleBottomOffset.clamp(60.0, 200.0),
    );
    await p.setBool(_keyIsMaximized, s.isMaximized);
    await p.setBool(_keyIsAlwaysOnTop, s.isAlwaysOnTop);
    // 视频处理
    await p.setDouble(_keyVideoBrightness, s.videoBrightness.clamp(-1.0, 1.0));
    await p.setDouble(_keyVideoContrast, s.videoContrast.clamp(-1.0, 1.0));
    await p.setDouble(_keyVideoSaturation, s.videoSaturation.clamp(-1.0, 1.0));
    await p.setDouble(_keyVideoHue, s.videoHue.clamp(-1.0, 1.0));
    await p.setInt(_keyVideoRotation, _sanitizeRotation(s.videoRotation));
    await p.setInt(
      _keyVideoAspectRatio,
      s.videoAspectRatioIndex.clamp(0, AspectRatioMode.values.length - 1),
    );
    await p.setBool(_keyVideoDeinterlace, s.videoDeinterlace);
    // 性能设置
    await p.setBool(_keyD3d11Sync, s.d3d11Sync);
    await p.setBool(_keyHardwareDecoding, s.hardwareDecoding);
    // RC-8: null 时显式清除旧键，防止残留值导致下次启动位置错误
    if (s.windowX != null) {
      await p.setDouble(_keyWindowX, _sanitizeCoordinate(s.windowX!, 0));
    } else {
      await p.remove(_keyWindowX);
    }
    if (s.windowY != null) {
      await p.setDouble(_keyWindowY, _sanitizeCoordinate(s.windowY!, 0));
    } else {
      await p.remove(_keyWindowY);
    }
  });
}
