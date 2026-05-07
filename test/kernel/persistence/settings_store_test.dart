import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';

void main() {
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

    test('default isFullscreen is false', () {
      const settings = AppSettings(
        volume: 1.0,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
      );
      expect(settings.isFullscreen, isFalse);
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

  group('SettingsStore isFullscreen persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load reads isFullscreen from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'isFullscreen': true});
      final settings = await SettingsStore.load();
      expect(settings.isFullscreen, isTrue);
    });

    test('load defaults isFullscreen to false when absent', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsStore.load();
      expect(settings.isFullscreen, isFalse);
    });

    test('saveIsFullscreen writes to SharedPreferences', () async {
      await SettingsStore.saveIsFullscreen(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isFullscreen'), isTrue);
    });

    test('saveIsFullscreen false writes to SharedPreferences', () async {
      await SettingsStore.saveIsFullscreen(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isFullscreen'), isFalse);
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
        isFullscreen: true,
      );
      await SettingsStore.saveAll(settings);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isAlwaysOnTop'), isTrue);
      expect(prefs.getBool('isFullscreen'), isTrue);
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
}
