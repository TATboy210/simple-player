import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/app_settings.dart';
import 'package:simple_player_flutter/kernel/models/export_data.dart';

void main() {
  /// 创建测试用 AppSettings 实例（所有字段填充值便于验证序列化完整性）
  AppSettings testSettings() => const AppSettings(
    volume: 0.75,
    lastFile: 'test.mp4',
    windowWidth: 1920,
    windowHeight: 1080,
    windowX: 100,
    windowY: 200,
    isMaximized: true,
    playMode: 1,
    isMuted: true,
    isAlwaysOnTop: true,
    subtitleFontSize: 20.0,
    subtitleColorIndex: 1,
    subtitleBottomOffset: 100.0,
    videoBrightness: 0.3,
    videoContrast: -0.2,
    videoSaturation: 0.5,
    videoHue: -0.1,
    videoRotation: 90,
    videoAspectRatioIndex: 2,
    videoDeinterlace: true,
    playbackSpeed: 1.5,
    d3d11Sync: false,
    hardwareDecoding: false,
  );

  group('ExportData', () {
    test('toMap() returns correct structure with all metadata fields', () {
      final data = const ExportData(
        settingsVersion: 1,
        exportedAt: '2026-07-13T10:00:00.000Z',
        appVersion: '1.0.0-rc.1',
        platform: 'windows',
        settingsCount: 26,
        settings: {'volume': 0.5},
      );

      final map = data.toMap();
      expect(map['settingsVersion'], 1);
      expect(map['exportedAt'], '2026-07-13T10:00:00.000Z');
      expect(map['appVersion'], '1.0.0-rc.1');
      expect(map['platform'], 'windows');
      expect(map['settingsCount'], 26);
      expect(map['settings'], {'volume': 0.5});
    });

    test('fromSettings() correctly maps all AppSettings fields', () {
      final settings = testSettings();
      final data = ExportData.fromSettings(
        settings: settings,
        locale: 'en',
        themeIndex: 2,
        shortcuts: {'play_pause': 'space', 'next': 'n'},
      );

      final s = data.settings;
      // 验证所有 23 个 AppSettings 字段
      expect(s['volume'], 0.75);
      expect(s['lastFile'], 'test.mp4');
      expect(s['windowWidth'], 1920);
      expect(s['windowHeight'], 1080);
      expect(s['windowX'], 100);
      expect(s['windowY'], 200);
      expect(s['isMaximized'], true);
      expect(s['playMode'], 1);
      expect(s['isMuted'], true);
      expect(s['isAlwaysOnTop'], true);
      expect(s['subtitleFontSize'], 20.0);
      expect(s['subtitleColorIndex'], 1);
      expect(s['subtitleBottomOffset'], 100.0);
      expect(s['videoBrightness'], 0.3);
      expect(s['videoContrast'], -0.2);
      expect(s['videoSaturation'], 0.5);
      expect(s['videoHue'], -0.1);
      expect(s['videoRotation'], 90);
      expect(s['videoAspectRatioIndex'], 2);
      expect(s['videoDeinterlace'], true);
      expect(s['playbackSpeed'], 1.5);
      expect(s['d3d11Sync'], false);
      expect(s['hardwareDecoding'], false);
      // 额外字段：locale, themeIndex, shortcuts
      expect(s['locale'], 'en');
      expect(s['themeIndex'], 2);
      expect(s['shortcuts'], {'play_pause': 'space', 'next': 'n'});
    });

    test('fromSettings() sets metadata correctly', () {
      final data = ExportData.fromSettings(
        settings: testSettings(),
        locale: 'zh',
        themeIndex: 0,
        shortcuts: {},
      );

      expect(data.settingsVersion, 1);
      expect(data.appVersion, '1.0.0-rc.1');
      expect(data.platform, isNotEmpty);
      // exportedAt 是 ISO 8601 格式
      expect(data.exportedAt, contains('T'));
      expect(data.exportedAt, contains('Z'));
    });

    test('settingsCount matches number of keys in settings map', () {
      final data = ExportData.fromSettings(
        settings: testSettings(),
        locale: 'zh',
        themeIndex: 0,
        shortcuts: {'a': 'b'},
      );

      expect(data.settingsCount, data.settings.length);
    });

    test('fromSettings() with null windowX/windowY includes null in map', () {
      const settings = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
      );
      final data = ExportData.fromSettings(
        settings: settings,
        locale: 'zh',
        themeIndex: 0,
        shortcuts: {},
      );

      expect(data.settings['windowX'], isNull);
      expect(data.settings['windowY'], isNull);
    });
  });
}
