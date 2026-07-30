// SettingsStore 音频偏好持久化测试 — Phase 33 AUDIO-07。
//
// 镜像 settings_store_test.dart 的范式：setMockInitialValues setUp +
// loadX/saveX 往返 + 边界 clamp。验证 4 个音频原始值（EQ 预设 / balance /
// syncMs / normalization）的持久化与校验。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('SettingsStore audio EQ preset persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadAudioEqPreset defaults to 0', () async {
      expect(await SettingsStore.loadAudioEqPreset(), 0);
    });

    test('saveAudioEqPreset/loadAudioEqPreset round-trip', () async {
      await SettingsStore.saveAudioEqPreset(3);
      expect(await SettingsStore.loadAudioEqPreset(), 3);
    });

    test('loadAudioEqPreset clamps 99 to 4', () async {
      SharedPreferences.setMockInitialValues({'audioEqPreset': 99});
      expect(await SettingsStore.loadAudioEqPreset(), 4);
    });

    test('loadAudioEqPreset clamps -5 to 0', () async {
      SharedPreferences.setMockInitialValues({'audioEqPreset': -5});
      expect(await SettingsStore.loadAudioEqPreset(), 0);
    });

    test('saveAudioEqPreset clamps out-of-range on write', () async {
      await SettingsStore.saveAudioEqPreset(99);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('audioEqPreset'), 4);
    });
  });

  group('SettingsStore audio balance persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadAudioBalance defaults to 0.0', () async {
      expect(await SettingsStore.loadAudioBalance(), 0.0);
    });

    test('saveAudioBalance/loadAudioBalance round-trip', () async {
      await SettingsStore.saveAudioBalance(0.5);
      expect(await SettingsStore.loadAudioBalance(), closeTo(0.5, 0.001));
    });

    test('loadAudioBalance clamps 5.0 to 1.0', () async {
      SharedPreferences.setMockInitialValues({'audioBalance': 5.0});
      expect(await SettingsStore.loadAudioBalance(), closeTo(1.0, 0.001));
    });

    test('loadAudioBalance clamps -5.0 to -1.0', () async {
      SharedPreferences.setMockInitialValues({'audioBalance': -5.0});
      expect(await SettingsStore.loadAudioBalance(), closeTo(-1.0, 0.001));
    });
  });

  group('SettingsStore audio sync ms persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadAudioSyncMs defaults to 0', () async {
      expect(await SettingsStore.loadAudioSyncMs(), 0);
    });

    test('saveAudioSyncMs/loadAudioSyncMs round-trip', () async {
      await SettingsStore.saveAudioSyncMs(500);
      expect(await SettingsStore.loadAudioSyncMs(), 500);
    });

    test('loadAudioSyncMs clamps 99999 to 10000', () async {
      SharedPreferences.setMockInitialValues({'audioSyncMs': 99999});
      expect(await SettingsStore.loadAudioSyncMs(), 10000);
    });

    test('loadAudioSyncMs clamps -100 to 0', () async {
      SharedPreferences.setMockInitialValues({'audioSyncMs': -100});
      expect(await SettingsStore.loadAudioSyncMs(), 0);
    });

    test('saveAudioSyncMs clamps out-of-range on write', () async {
      await SettingsStore.saveAudioSyncMs(99999);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('audioSyncMs'), 10000);
    });
  });

  group('SettingsStore audio normalization persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadAudioNormalization defaults to false', () async {
      expect(await SettingsStore.loadAudioNormalization(), isFalse);
    });

    test('saveAudioNormalization/loadAudioNormalization round-trip true', () async {
      await SettingsStore.saveAudioNormalization(true);
      expect(await SettingsStore.loadAudioNormalization(), isTrue);
    });

    test('saveAudioNormalization/loadAudioNormalization round-trip false', () async {
      await SettingsStore.saveAudioNormalization(true);
      expect(await SettingsStore.loadAudioNormalization(), isTrue);
      await SettingsStore.saveAudioNormalization(false);
      expect(await SettingsStore.loadAudioNormalization(), isFalse);
    });

    test('loadAudioNormalization reads true from prefs', () async {
      SharedPreferences.setMockInitialValues({'audioNormalization': true});
      expect(await SettingsStore.loadAudioNormalization(), isTrue);
    });

    test('saveAudioNormalization writes bool to prefs', () async {
      await SettingsStore.saveAudioNormalization(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('audioNormalization'), isTrue);
    });
  });
}
