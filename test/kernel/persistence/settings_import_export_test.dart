import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/models/app_settings.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsStore.exportSettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'volume': 0.8,
        'lastFile': 'video.mp4',
        'windowWidth': 1920.0,
        'windowHeight': 1080.0,
        'windowX': 100.0,
        'windowY': 200.0,
        'isMaximized': true,
        'playMode': 1,
        'isMuted': false,
        'isAlwaysOnTop': true,
        'subtitleFontSize': 20.0,
        'subtitleColorIndex': 1,
        'subtitleBottomOffset': 100.0,
        'videoBrightness': 0.3,
        'videoContrast': -0.2,
        'videoSaturation': 0.5,
        'videoHue': -0.1,
        'videoRotation': 90,
        'videoAspectRatio': 2,
        'videoDeinterlace': true,
        'playbackSpeed': 1.5,
        'd3d11Sync': false,
        'hardwareDecoding': false,
        'locale': 'en',
        'themeIndex': 2,
        'shortcuts': jsonEncode({'play_pause': 'space', 'next': 'n'}),
      });
    });

    test('produces valid JSON with all metadata fields', () async {
      final jsonStr = await SettingsStore.exportSettings();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['settingsVersion'], 1);
      expect(map['exportedAt'], isA<String>());
      expect(map['appVersion'], '1.0.0-rc.1');
      expect(map['platform'], isA<String>());
      expect(map['settingsCount'], isA<int>());
      expect(map['settings'], isA<Map>());
    });

    test('includes all AppSettings fields plus locale/themeIndex/shortcuts', () async {
      final jsonStr = await SettingsStore.exportSettings();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final s = map['settings'] as Map<String, dynamic>;

      // 验证 AppSettings 字段
      expect(s['volume'], closeTo(0.8, 0.01));
      expect(s['lastFile'], 'video.mp4');
      expect(s['windowWidth'], closeTo(1920, 0.01));
      expect(s['windowHeight'], closeTo(1080, 0.01));
      expect(s['windowX'], closeTo(100, 0.01));
      expect(s['windowY'], closeTo(200, 0.01));
      expect(s['isMaximized'], true);
      expect(s['playMode'], 1);
      expect(s['isMuted'], false);
      expect(s['isAlwaysOnTop'], true);
      expect(s['subtitleFontSize'], closeTo(20, 0.01));
      expect(s['subtitleColorIndex'], 1);
      expect(s['subtitleBottomOffset'], closeTo(100, 0.01));
      expect(s['videoBrightness'], closeTo(0.3, 0.01));
      expect(s['videoContrast'], closeTo(-0.2, 0.01));
      expect(s['videoSaturation'], closeTo(0.5, 0.01));
      expect(s['videoHue'], closeTo(-0.1, 0.01));
      expect(s['videoRotation'], 90);
      expect(s['videoAspectRatioIndex'], 2);
      expect(s['videoDeinterlace'], true);
      expect(s['playbackSpeed'], closeTo(1.5, 0.01));
      expect(s['d3d11Sync'], false);
      expect(s['hardwareDecoding'], false);
      // 额外字段
      expect(s['locale'], 'en');
      expect(s['themeIndex'], 2);
      expect(s['shortcuts'], isA<Map>());
    });

    test('settingsCount matches actual settings map length', () async {
      final jsonStr = await SettingsStore.exportSettings();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final settingsMap = map['settings'] as Map;

      expect(map['settingsCount'], settingsMap.length);
    });
  });

  group('SettingsStore.importSettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('valid JSON returns ImportSuccess with correct values', () async {
      final jsonStr = jsonEncode({
        'settingsVersion': 1,
        'exportedAt': '2026-07-13T10:00:00Z',
        'appVersion': '1.0.0-rc.1',
        'platform': 'windows',
        'settingsCount': 26,
        'settings': {
          'volume': 0.6,
          'lastFile': 'imported.mp4',
          'windowWidth': 1600.0,
          'windowHeight': 900.0,
          'windowX': 50.0,
          'windowY': 60.0,
          'isMaximized': false,
          'playMode': 2,
          'isMuted': true,
          'isAlwaysOnTop': false,
          'subtitleFontSize': 18.0,
          'subtitleColorIndex': 2,
          'subtitleBottomOffset': 90.0,
          'videoBrightness': 0.1,
          'videoContrast': -0.1,
          'videoSaturation': 0.2,
          'videoHue': 0.0,
          'videoRotation': 180,
          'videoAspectRatioIndex': 1,
          'videoDeinterlace': false,
          'playbackSpeed': 2.0,
          'd3d11Sync': true,
          'hardwareDecoding': true,
          'locale': 'en',
          'themeIndex': 1,
          'shortcuts': {'play_pause': 'space'},
        },
      });

      final result = await SettingsStore.importSettings(jsonStr);

      expect(result, isA<ImportSuccess>());
      final success = result as ImportSuccess;
      expect(success.settings.volume, closeTo(0.6, 0.01));
      expect(success.settings.lastFile, 'imported.mp4');
      expect(success.settings.windowWidth, closeTo(1600, 0.01));
      expect(success.settings.windowHeight, closeTo(900, 0.01));
      expect(success.settings.windowX, closeTo(50, 0.01));
      expect(success.settings.windowY, closeTo(60, 0.01));
      expect(success.settings.playMode, 2);
      expect(success.settings.isMuted, true);
      expect(success.settings.subtitleFontSize, closeTo(18, 0.01));
      expect(success.settings.videoRotation, 180);
      expect(success.settings.playbackSpeed, closeTo(2.0, 0.01));
      expect(success.locale, 'en');
      expect(success.themeIndex, 1);
      expect(success.shortcuts, {'play_pause': 'space'});
    });

    test('invalid JSON returns ImportFailure', () async {
      final result = await SettingsStore.importSettings('not valid json {{{');

      expect(result, isA<ImportFailure>());
      final failure = result as ImportFailure;
      expect(failure.error, contains('JSON'));
    });

    test('missing settings key returns ImportFailure', () async {
      final jsonStr = jsonEncode({
        'settingsVersion': 1,
        'exportedAt': '2026-07-13T10:00:00Z',
        'appVersion': '1.0.0-rc.1',
        // 没有 'settings' key
      });

      final result = await SettingsStore.importSettings(jsonStr);

      expect(result, isA<ImportFailure>());
      final failure = result as ImportFailure;
      expect(failure.error, contains('settings'));
    });

    test('ignores unknown fields for forward compatibility', () async {
      final jsonStr = jsonEncode({
        'settingsVersion': 1,
        'exportedAt': '2026-07-13T10:00:00Z',
        'appVersion': '1.0.0-rc.1',
        'platform': 'windows',
        'settingsCount': 1,
        'settings': {
          'volume': 0.5,
          'futureField': 'should be ignored',
          'anotherNewField': 42,
        },
      });

      final result = await SettingsStore.importSettings(jsonStr);

      // 不应因未知字段失败
      expect(result, isA<ImportSuccess>());
    });

    test('fills missing fields with AppSettings defaults', () async {
      final jsonStr = jsonEncode({
        'settingsVersion': 1,
        'exportedAt': '2026-07-13T10:00:00Z',
        'appVersion': '1.0.0-rc.1',
        'platform': 'windows',
        'settingsCount': 1,
        'settings': {
          'volume': 0.5,
          // 其他字段全部缺失
        },
      });

      final result = await SettingsStore.importSettings(jsonStr);

      expect(result, isA<ImportSuccess>());
      final success = result as ImportSuccess;
      // 缺失字段应使用 AppSettings 默认值
      expect(success.settings.lastFile, '');
      expect(success.settings.windowWidth, SettingsValidator.windowWidthDefault);
      expect(success.settings.windowHeight, SettingsValidator.windowHeightDefault);
      expect(success.settings.isMaximized, false);
      expect(success.settings.playMode, 0);
      expect(success.settings.isMuted, false);
      expect(success.settings.isAlwaysOnTop, false);
      expect(success.settings.subtitleFontSize, SettingsValidator.subtitleFontSizeDefault);
      expect(success.settings.subtitleColorIndex, 0);
      expect(success.settings.subtitleBottomOffset, SettingsValidator.subtitleOffsetDefault);
      expect(success.settings.videoBrightness, 0.0);
      expect(success.settings.videoContrast, 0.0);
      expect(success.settings.videoSaturation, 0.0);
      expect(success.settings.videoHue, 0.0);
      expect(success.settings.videoRotation, 0);
      expect(success.settings.videoAspectRatioIndex, 0);
      expect(success.settings.videoDeinterlace, false);
      expect(success.settings.playbackSpeed, SettingsValidator.playbackSpeedDefault);
      expect(success.settings.d3d11Sync, true);
      expect(success.settings.hardwareDecoding, true);
      expect(success.locale, SettingsValidator.defaultLocale);
      expect(success.themeIndex, 0);
      expect(success.shortcuts, isEmpty);
    });

    test('validates fields through SettingsValidator (volume clamped)', () async {
      final jsonStr = jsonEncode({
        'settingsVersion': 1,
        'exportedAt': '2026-07-13T10:00:00Z',
        'appVersion': '1.0.0-rc.1',
        'platform': 'windows',
        'settingsCount': 1,
        'settings': {
          'volume': 5.0, // 超出范围，应被 clamp 到 1.0
          'playMode': 999, // 超出范围
          'videoRotation': 45, // 无效值
          'themeIndex': 99, // 超出范围
          'videoBrightness': 3.0, // 超出范围
        },
      });

      final result = await SettingsStore.importSettings(jsonStr);

      expect(result, isA<ImportSuccess>());
      final success = result as ImportSuccess;
      expect(success.settings.volume, 1.0); // clamped
      expect(success.settings.playMode, SettingsValidator.playMode(999));
      expect(success.settings.videoRotation, 0); // 45 invalid → 0
      expect(success.themeIndex, SettingsValidator.themeIndex(99));
      expect(success.settings.videoBrightness, 1.0); // clamped
    });

    test('validates locale as non-empty string', () async {
      final jsonStr = jsonEncode({
        'settingsVersion': 1,
        'exportedAt': '2026-07-13T10:00:00Z',
        'appVersion': '1.0.0-rc.1',
        'platform': 'windows',
        'settingsCount': 1,
        'settings': {
          'volume': 0.5,
          'locale': 'en',
        },
      });

      final result = await SettingsStore.importSettings(jsonStr);

      expect(result, isA<ImportSuccess>());
      final success = result as ImportSuccess;
      expect(success.locale, 'en');
    });

    test('validates shortcuts as Map<String, String>', () async {
      final jsonStr = jsonEncode({
        'settingsVersion': 1,
        'exportedAt': '2026-07-13T10:00:00Z',
        'appVersion': '1.0.0-rc.1',
        'platform': 'windows',
        'settingsCount': 1,
        'settings': {
          'volume': 0.5,
          'shortcuts': {'play_pause': 'space', 'next': 'n'},
        },
      });

      final result = await SettingsStore.importSettings(jsonStr);

      expect(result, isA<ImportSuccess>());
      final success = result as ImportSuccess;
      expect(success.shortcuts, {'play_pause': 'space', 'next': 'n'});
    });

    test('handles null windowX/windowY gracefully', () async {
      final jsonStr = jsonEncode({
        'settingsVersion': 1,
        'exportedAt': '2026-07-13T10:00:00Z',
        'appVersion': '1.0.0-rc.1',
        'platform': 'windows',
        'settingsCount': 1,
        'settings': {
          'volume': 0.5,
          'windowX': null,
          'windowY': null,
        },
      });

      final result = await SettingsStore.importSettings(jsonStr);

      expect(result, isA<ImportSuccess>());
      final success = result as ImportSuccess;
      expect(success.settings.windowX, isNull);
      expect(success.settings.windowY, isNull);
    });
  });

  group('SettingsStore.applyImportedSettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists all settings to SharedPreferences', () async {
      final success = ImportSuccess(
        settings: const AppSettings(
          volume: 0.9,
          lastFile: 'imported.mp4',
          windowWidth: 1600,
          windowHeight: 900,
          windowX: 50,
          windowY: 60,
          isMaximized: true,
          playMode: 2,
          isMuted: true,
          isAlwaysOnTop: true,
          subtitleFontSize: 22.0,
          subtitleColorIndex: 2,
          subtitleBottomOffset: 120.0,
          videoBrightness: 0.4,
          videoContrast: -0.3,
          videoSaturation: 0.6,
          videoHue: 0.1,
          videoRotation: 270,
          videoAspectRatioIndex: 3,
          videoDeinterlace: true,
          playbackSpeed: 2.0,
          d3d11Sync: false,
          hardwareDecoding: false,
        ),
        locale: 'en',
        themeIndex: 2,
        shortcuts: {'play_pause': 'space'},
      );

      await SettingsStore.applyImportedSettings(success);

      // 验证持久化
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('volume'), closeTo(0.9, 0.01));
      expect(prefs.getString('lastFile'), 'imported.mp4');
      expect(prefs.getDouble('windowWidth'), closeTo(1600, 0.01));
      expect(prefs.getDouble('windowHeight'), closeTo(900, 0.01));
      expect(prefs.getDouble('windowX'), closeTo(50, 0.01));
      expect(prefs.getDouble('windowY'), closeTo(60, 0.01));
      expect(prefs.getBool('isMaximized'), true);
      expect(prefs.getInt('playMode'), 2);
      expect(prefs.getBool('isMuted'), true);
      expect(prefs.getBool('isAlwaysOnTop'), true);
      expect(prefs.getDouble('subtitleFontSize'), closeTo(22, 0.01));
      expect(prefs.getInt('subtitleColorIndex'), 2);
      expect(prefs.getDouble('subtitleBottomOffset'), closeTo(120, 0.01));
      expect(prefs.getDouble('videoBrightness'), closeTo(0.4, 0.01));
      expect(prefs.getDouble('videoContrast'), closeTo(-0.3, 0.01));
      expect(prefs.getDouble('videoSaturation'), closeTo(0.6, 0.01));
      expect(prefs.getDouble('videoHue'), closeTo(0.1, 0.01));
      expect(prefs.getInt('videoRotation'), 270);
      expect(prefs.getInt('videoAspectRatio'), 3);
      expect(prefs.getBool('videoDeinterlace'), true);
      expect(prefs.getDouble('playbackSpeed'), closeTo(2.0, 0.01));
      expect(prefs.getBool('d3d11Sync'), false);
      expect(prefs.getBool('hardwareDecoding'), false);
      expect(prefs.getString('locale'), 'en');
      expect(prefs.getInt('themeIndex'), 2);
      expect(prefs.getString('shortcuts'), isNotNull);
    });
  });
}
