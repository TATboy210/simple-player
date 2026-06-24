import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings', () {
    test('default isAlwaysOnTop is false', () {
      const settings = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
      );
      expect(settings.isAlwaysOnTop, isFalse);
    });

    test('copyWith no args returns equal instance', () {
      const original = AppSettings(
        volume: 0.8,
        lastFile: 'test.mp4',
        windowWidth: 1920,
        windowHeight: 1080,
        windowX: 100.0,
        windowY: 200.0,
        playMode: 1,
        isMuted: true,
      );
      final copy = original.copyWith();
      expect(copy, equals(original));
      expect(copy.hashCode, equals(original.hashCode));
    });

    test('copyWith replaces only specified fields', () {
      const original = AppSettings(
        volume: 0.5,
        lastFile: 'a.mp4',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
      );
      final copy = original.copyWith(volume: 0.9, isMuted: true);
      expect(copy.volume, 0.9);
      expect(copy.isMuted, isTrue);
      expect(copy.lastFile, 'a.mp4');
      expect(copy.windowWidth, 1280);
    });

    test('copyWith can set nullable fields to null', () {
      const original = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        windowX: 50.0,
        windowY: 60.0,
        playMode: 0,
        isMuted: false,
      );
      final copy = original.copyWith(windowX: null, windowY: null);
      expect(copy.windowX, isNull);
      expect(copy.windowY, isNull);
      expect(copy.volume, 1.0);
    });

    test('== returns true for identical field values', () {
      const a = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
      );
      const b = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
      );
      expect(a, equals(b));
    });

    test('== returns false when single field differs', () {
      const a = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
      );
      const b = AppSettings(
        volume: 0.5,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
      );
      expect(a == b, isFalse);
    });

    test('hashCode is consistent for equal objects', () {
      const a = AppSettings(
        volume: 1.0,
        lastFile: 'x.mp4',
        windowWidth: 1280,
        windowHeight: 720,
        windowX: 10.0,
        playMode: 2,
        isMuted: true,
        videoBrightness: 0.3,
      );
      const b = AppSettings(
        volume: 1.0,
        lastFile: 'x.mp4',
        windowWidth: 1280,
        windowHeight: 720,
        windowX: 10.0,
        playMode: 2,
        isMuted: true,
        videoBrightness: 0.3,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('SettingsStore isAlwaysOnTop persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load reads isAlwaysOnTop from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'isAlwaysOnTop': true});
      final settings = await SettingsStore.load();
      expect(settings.isAlwaysOnTop, isTrue);
    });

    test('load defaults isAlwaysOnTop to false when absent', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsStore.load();
      expect(settings.isAlwaysOnTop, isFalse);
    });

    test('saveIsAlwaysOnTop writes to SharedPreferences', () async {
      await SettingsStore.saveIsAlwaysOnTop(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isAlwaysOnTop'), isTrue);
    });

    test('saveIsAlwaysOnTop false writes to SharedPreferences', () async {
      await SettingsStore.saveIsAlwaysOnTop(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isAlwaysOnTop'), isFalse);
    });
  });

  group('SettingsStore saveAll includes new fields', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveAll persists isAlwaysOnTop', () async {
      const settings = AppSettings(
        volume: 0.5,
        lastFile: 'test.mp4',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
        isAlwaysOnTop: true,
      );
      await SettingsStore.saveAll(settings);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isAlwaysOnTop'), isTrue);
    });
  });

  group('SettingsStore video processing persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load defaults video processing to zero/false', () async {
      final settings = await SettingsStore.load();
      expect(settings.videoBrightness, 0.0);
      expect(settings.videoContrast, 0.0);
      expect(settings.videoSaturation, 0.0);
      expect(settings.videoHue, 0.0);
      expect(settings.videoRotation, 0);
      expect(settings.videoAspectRatioIndex, 0);
      expect(settings.videoDeinterlace, false);
    });

    test('load reads video processing from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'videoBrightness': 0.5,
        'videoContrast': -0.3,
        'videoSaturation': 0.8,
        'videoHue': -0.1,
        'videoRotation': 90,
        'videoAspectRatio': 3,
        'videoDeinterlace': true,
      });
      final settings = await SettingsStore.load();
      expect(settings.videoBrightness, closeTo(0.5, 0.01));
      expect(settings.videoContrast, closeTo(-0.3, 0.01));
      expect(settings.videoSaturation, closeTo(0.8, 0.01));
      expect(settings.videoHue, closeTo(-0.1, 0.01));
      expect(settings.videoRotation, 90);
      expect(settings.videoAspectRatioIndex, 3);
      expect(settings.videoDeinterlace, true);
    });

    test('load clamps out-of-range video values', () async {
      SharedPreferences.setMockInitialValues({
        'videoBrightness': 5.0,
        'videoContrast': -5.0,
        'videoAspectRatio': 99,
        'videoRotation': 45,
      });
      final settings = await SettingsStore.load();
      expect(settings.videoBrightness, 1.0);
      expect(settings.videoContrast, -1.0);
      expect(settings.videoAspectRatioIndex, AspectRatioMode.values.length - 1);
      expect(settings.videoRotation, 0); // 45 is not valid
    });

    test('saveVideoBrightness writes to SharedPreferences', () async {
      await SettingsStore.saveVideoBrightness(0.7);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('videoBrightness'), closeTo(0.7, 0.01));
    });

    test('saveVideoRotation writes to SharedPreferences', () async {
      await SettingsStore.saveVideoRotation(270);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('videoRotation'), 270);
    });

    test('saveVideoDeinterlace writes to SharedPreferences', () async {
      await SettingsStore.saveVideoDeinterlace(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('videoDeinterlace'), true);
    });

    test('saveAll persists all video processing fields', () async {
      const settings = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
        videoBrightness: 0.4,
        videoContrast: -0.2,
        videoSaturation: 0.6,
        videoHue: -0.3,
        videoRotation: 180,
        videoAspectRatioIndex: 4,
        videoDeinterlace: true,
      );
      await SettingsStore.saveAll(settings);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('videoBrightness'), closeTo(0.4, 0.01));
      expect(prefs.getDouble('videoContrast'), closeTo(-0.2, 0.01));
      expect(prefs.getDouble('videoSaturation'), closeTo(0.6, 0.01));
      expect(prefs.getDouble('videoHue'), closeTo(-0.3, 0.01));
      expect(prefs.getInt('videoRotation'), 180);
      expect(prefs.getInt('videoAspectRatio'), 4);
      expect(prefs.getBool('videoDeinterlace'), true);
    });
  });

  group('SettingsStore locale/theme persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadLocale defaults to zh', () async {
      final locale = await SettingsStore.loadLocale();
      expect(locale, 'zh');
    });

    test('saveLocale/loadLocale round-trip', () async {
      await SettingsStore.saveLocale('en');
      final locale = await SettingsStore.loadLocale();
      expect(locale, 'en');
    });

    test('loadThemeIndex defaults to 0', () async {
      final index = await SettingsStore.loadThemeIndex();
      expect(index, 0);
    });

    test('saveThemeIndex/loadThemeIndex round-trip', () async {
      await SettingsStore.saveThemeIndex(2);
      final index = await SettingsStore.loadThemeIndex();
      expect(index, 2);
    });

    test('loadThemeIndex clamps to 0..2', () async {
      SharedPreferences.setMockInitialValues({'themeIndex': 99});
      final index = await SettingsStore.loadThemeIndex();
      expect(index, 2);
    });
  });

  group('SettingsStore shortcuts persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadShortcuts returns empty map when absent', () async {
      final shortcuts = await SettingsStore.loadShortcuts();
      expect(shortcuts, isEmpty);
    });

    test('loadShortcuts returns empty map on corrupt JSON', () async {
      SharedPreferences.setMockInitialValues({'shortcuts': 'not valid json'});
      final shortcuts = await SettingsStore.loadShortcuts();
      expect(shortcuts, isEmpty);
    });

    test('loadShortcuts returns empty map on empty string', () async {
      SharedPreferences.setMockInitialValues({'shortcuts': ''});
      final shortcuts = await SettingsStore.loadShortcuts();
      expect(shortcuts, isEmpty);
    });

    test('saveShortcuts/loadShortcuts round-trip', () async {
      final bindings = {'play_pause': 'space', 'next': 'n'};
      await SettingsStore.saveShortcuts(bindings);
      final loaded = await SettingsStore.loadShortcuts();
      expect(loaded, bindings);
    });
  });

  group('SettingsStore performance settings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadD3d11SyncEnabled defaults to true', () async {
      final value = await SettingsStore.loadD3d11SyncEnabled();
      expect(value, true);
    });

    test('saveD3d11SyncEnabled/loadD3d11SyncEnabled round-trip', () async {
      await SettingsStore.saveD3d11SyncEnabled(false);
      final value = await SettingsStore.loadD3d11SyncEnabled();
      expect(value, false);
    });

    test('loadHardwareDecoding defaults to true', () async {
      final value = await SettingsStore.loadHardwareDecoding();
      expect(value, true);
    });

    test('saveHardwareDecoding/loadHardwareDecoding round-trip', () async {
      await SettingsStore.saveHardwareDecoding(false);
      final value = await SettingsStore.loadHardwareDecoding();
      expect(value, false);
    });
  });

  group('SettingsStore saveAll RC-8 window position', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveAll with windowX/windowY set persists coordinates', () async {
      const settings = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
        windowX: 100.0,
        windowY: 200.0,
      );
      await SettingsStore.saveAll(settings);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('windowX'), closeTo(100.0, 0.01));
      expect(prefs.getDouble('windowY'), closeTo(200.0, 0.01));
    });

    test('saveAll with null windowX/windowY removes keys', () async {
      // First set values
      SharedPreferences.setMockInitialValues({
        'windowX': 500.0,
        'windowY': 600.0,
      });
      const settings = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
        // windowX and windowY default to null
      );
      await SettingsStore.saveAll(settings);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('windowX'), isNull);
      expect(prefs.getDouble('windowY'), isNull);
    });
  });

  group('SettingsStore prewarm', () {
    test('prewarm caches SharedPreferences instance', () async {
      SharedPreferences.setMockInitialValues({'volume': 0.8});
      final prefs = await SharedPreferences.getInstance();
      SettingsStore.prewarm(prefs);
      final settings = await SettingsStore.load();
      expect(settings.volume, closeTo(0.8, 0.01));
      SettingsStore.resetPrewarm();
    });

    test('resetPrewarm clears cached instance', () {
      SettingsStore.resetPrewarm();
      // Should not crash, next load creates new instance
    });
  });

  group('SettingsStore individual save methods', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveLastFile writes path', () async {
      await SettingsStore.saveLastFile('/test/video.mp4');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastFile'), '/test/video.mp4');
    });

    test('savePlayMode writes mode', () async {
      await SettingsStore.savePlayMode(2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('playMode'), 2);
    });

    test('saveIsMuted writes value', () async {
      await SettingsStore.saveIsMuted(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isMuted'), true);
    });

    test('saveSubtitleFontSize writes value', () async {
      await SettingsStore.saveSubtitleFontSize(20.0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('subtitleFontSize'), closeTo(20.0, 0.01));
    });

    test('saveSubtitleColorIndex writes value', () async {
      await SettingsStore.saveSubtitleColorIndex(1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('subtitleColorIndex'), 1);
    });

    test('saveSubtitleBottomOffset writes value', () async {
      await SettingsStore.saveSubtitleBottomOffset(100.0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('subtitleBottomOffset'), closeTo(100.0, 0.01));
    });

    test('saveVideoContrast writes value', () async {
      await SettingsStore.saveVideoContrast(0.5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('videoContrast'), closeTo(0.5, 0.01));
    });

    test('saveVideoSaturation writes value', () async {
      await SettingsStore.saveVideoSaturation(-0.3);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('videoSaturation'), closeTo(-0.3, 0.01));
    });

    test('saveVideoHue writes value', () async {
      await SettingsStore.saveVideoHue(0.7);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('videoHue'), closeTo(0.7, 0.01));
    });

    test('saveVideoAspectRatioIndex writes value', () async {
      await SettingsStore.saveVideoAspectRatioIndex(2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('videoAspectRatio'), 2);
    });
  });

  group('SettingsStore load edge cases', () {
    test('load returns defaults on empty prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsStore.load();
      expect(settings.volume, 1.0);
      expect(settings.lastFile, '');
      expect(settings.windowWidth, 1280);
      expect(settings.windowHeight, 752);
      expect(settings.windowX, isNull);
      expect(settings.windowY, isNull);
      expect(settings.isMaximized, false);
      expect(settings.playMode, 0);
      expect(settings.isMuted, false);
      expect(settings.subtitleFontSize, 17.0);
      expect(settings.subtitleColorIndex, 0);
      expect(settings.subtitleBottomOffset, 80.0);
    });

    test('load reads windowX/windowY when present', () async {
      SharedPreferences.setMockInitialValues({
        'windowX': 150.0,
        'windowY': 250.0,
      });
      final settings = await SettingsStore.load();
      expect(settings.windowX, closeTo(150.0, 0.01));
      expect(settings.windowY, closeTo(250.0, 0.01));
    });

    test('load sanitizes infinite window coordinates', () async {
      SharedPreferences.setMockInitialValues({
        'windowX': double.infinity,
        'windowY': double.negativeInfinity,
      });
      final settings = await SettingsStore.load();
      expect(settings.windowX, 0); // fallback
      expect(settings.windowY, 0); // fallback
    });
  });

  group('SettingsStore sanitize helpers', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load rejects NaN window dimensions', () async {
      SharedPreferences.setMockInitialValues({
        'windowWidth': double.nan,
        'windowHeight': double.nan,
      });
      final settings = await SettingsStore.load();
      expect(settings.windowWidth, 1280);
      expect(settings.windowHeight, 752);
    });

    test('load rejects negative window dimensions', () async {
      SharedPreferences.setMockInitialValues({
        'windowWidth': -100.0,
        'windowHeight': -200.0,
      });
      final settings = await SettingsStore.load();
      expect(settings.windowWidth, 1280);
      expect(settings.windowHeight, 752);
    });

    test('saveWindowGeometry sanitizes inputs', () async {
      await SettingsStore.saveWindowGeometry(
        width: double.nan,
        height: 99999.0,
        x: double.infinity,
        y: 100.0,
        isMaximized: true,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('windowWidth'), 1280); // NaN → fallback
      expect(prefs.getDouble('windowHeight'), 4608); // clamped to max
      expect(prefs.getDouble('windowX'), 0); // Infinity → fallback
      expect(prefs.getDouble('windowY'), closeTo(100.0, 0.01));
      expect(prefs.getBool('isMaximized'), true);
    });

    test('saveVolume clamps to 0..1', () async {
      await SettingsStore.saveVolume(1.5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('volume'), 1.0);
    });
  });

  group('SettingsStore catch blocks (SharedPreferences failure)', () {
    setUp(() {
      SettingsStore.resetPrewarm();
      // Override platform channel to throw on getInstance()
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (call) async =>
            throw PlatformException(code: 'TEST', message: 'mock error'),
      );
    });

    tearDown(() {
      // Restore normal mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        null,
      );
      SharedPreferences.setMockInitialValues({});
      SettingsStore.resetPrewarm();
    });

    test('loadLocale returns default zh on exception', () async {
      final locale = await SettingsStore.loadLocale();
      expect(locale, 'zh');
    });

    test('loadThemeIndex returns default 0 on exception', () async {
      final index = await SettingsStore.loadThemeIndex();
      expect(index, 0);
    });

    test('loadD3d11SyncEnabled returns default true on exception', () async {
      final value = await SettingsStore.loadD3d11SyncEnabled();
      expect(value, true);
    });

    test('loadHardwareDecoding returns default true on exception', () async {
      final value = await SettingsStore.loadHardwareDecoding();
      expect(value, true);
    });
  });
}
