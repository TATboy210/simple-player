import 'dart:io';

import 'app_settings.dart';

/// 导出数据的 JSON 结构模型 — 包含元数据和完整设置映射。
///
/// 序列化为 JSON 后可供用户保存到文件，导入时反序列化回设置。
/// 元数据包含格式版本号、导出时间、应用版本、平台和设置项数量。
///
/// ```dart
/// final data = ExportData.fromSettings(
///   settings: appSettings, locale: 'zh', themeIndex: 0, shortcuts: {},
/// );
/// final json = jsonEncode(data.toMap());
/// ```
class ExportData {
  /// 格式版本号 — 用于向前兼容的版本判断。
  final int settingsVersion;

  /// 导出时间 (ISO 8601 UTC 格式)。
  final String exportedAt;

  /// 应用版本号 (来自 pubspec.yaml)。
  final String appVersion;

  /// 操作系统平台标识 (e.g. 'windows', 'linux', 'macos')。
  final String platform;

  /// 设置映射中的键值对数量 — 用于完整性校验。
  final int settingsCount;

  /// 完整设置映射 — 包含所有 AppSettings 字段 + locale + themeIndex + shortcuts。
  final Map<String, dynamic> settings;

  const ExportData({
    required this.settingsVersion,
    required this.exportedAt,
    required this.appVersion,
    required this.platform,
    required this.settingsCount,
    required this.settings,
  });

  /// 应用版本常量 — 与 pubspec.yaml version 字段保持一致。
  /// 硬编码以避免引入 package_info_plus 依赖。
  static const appVersionConst = '1.0.0-rc.1';

  /// 从当前应用设置构建导出数据。
  ///
  /// 将 [AppSettings] 的所有字段 + locale/themeIndex/shortcuts 序列化为 Map，
  /// 并附加元数据 (版本号、导出时间、平台、设置数量)。
  factory ExportData.fromSettings({
    required AppSettings settings,
    required String locale,
    required int themeIndex,
    required Map<String, String> shortcuts,
  }) {
    // 构建完整设置映射 — 包含所有 23 个 AppSettings 字段 + 3 个额外字段
    final settingsMap = <String, dynamic>{
      'volume': settings.volume,
      'lastFile': settings.lastFile,
      'windowWidth': settings.windowWidth,
      'windowHeight': settings.windowHeight,
      'windowX': settings.windowX,
      'windowY': settings.windowY,
      'isMaximized': settings.isMaximized,
      'playMode': settings.playMode,
      'isMuted': settings.isMuted,
      'isAlwaysOnTop': settings.isAlwaysOnTop,
      'subtitleFontSize': settings.subtitleFontSize,
      'subtitleColorIndex': settings.subtitleColorIndex,
      'subtitleBottomOffset': settings.subtitleBottomOffset,
      'videoBrightness': settings.videoBrightness,
      'videoContrast': settings.videoContrast,
      'videoSaturation': settings.videoSaturation,
      'videoHue': settings.videoHue,
      'videoRotation': settings.videoRotation,
      'videoAspectRatioIndex': settings.videoAspectRatioIndex,
      'videoDeinterlace': settings.videoDeinterlace,
      'playbackSpeed': settings.playbackSpeed,
      'd3d11Sync': settings.d3d11Sync,
      'hardwareDecoding': settings.hardwareDecoding,
      'locale': locale,
      'themeIndex': themeIndex,
      'shortcuts': shortcuts,
    };

    return ExportData(
      settingsVersion: 1,
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      appVersion: appVersionConst,
      platform: Platform.operatingSystem,
      settingsCount: settingsMap.length,
      settings: settingsMap,
    );
  }

  /// 序列化为 JSON 兼容的 Map — 可直接传给 [jsonEncode]。
  Map<String, dynamic> toMap() => {
    'settingsVersion': settingsVersion,
    'exportedAt': exportedAt,
    'appVersion': appVersion,
    'platform': platform,
    'settingsCount': settingsCount,
    'settings': settings,
  };
}
