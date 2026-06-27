import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_validator.dart';

void main() {
  group('SettingsValidator constants', () {
    test('window defaults are reasonable', () {
      expect(SettingsValidator.windowWidthDefault, 1280);
      expect(SettingsValidator.windowHeightDefault, 752);
    });

    test('window min < default < max', () {
      expect(SettingsValidator.windowWidthMin, lessThan(SettingsValidator.windowWidthDefault));
      expect(SettingsValidator.windowWidthDefault, lessThan(SettingsValidator.windowWidthMax));
      expect(SettingsValidator.windowHeightMin, lessThan(SettingsValidator.windowHeightDefault));
      expect(SettingsValidator.windowHeightDefault, lessThan(SettingsValidator.windowHeightMax));
    });

    test('subtitle font size range is valid', () {
      expect(SettingsValidator.subtitleFontSizeMin, lessThan(SettingsValidator.subtitleFontSizeMax));
      expect(SettingsValidator.subtitleFontSizeDefault, inInclusiveRange(
        SettingsValidator.subtitleFontSizeMin,
        SettingsValidator.subtitleFontSizeMax,
      ));
    });

    test('subtitle offset range is valid', () {
      expect(SettingsValidator.subtitleOffsetMin, lessThan(SettingsValidator.subtitleOffsetMax));
      expect(SettingsValidator.subtitleOffsetDefault, inInclusiveRange(
        SettingsValidator.subtitleOffsetMin,
        SettingsValidator.subtitleOffsetMax,
      ));
    });

    test('video effect range is symmetric', () {
      expect(SettingsValidator.videoEffectMin, -1);
      expect(SettingsValidator.videoEffectMax, 1);
    });
  });

  group('SettingsValidator.sanitizeDimension', () {
    test('clamps normal value within range', () {
      expect(SettingsValidator.sanitizeDimension(1500, 1280, 1024, 8192), 1500);
    });

    test('clamps value below min to min', () {
      expect(SettingsValidator.sanitizeDimension(500, 1280, 1024, 8192), 1024);
    });

    test('clamps value above max to max', () {
      expect(SettingsValidator.sanitizeDimension(10000, 1280, 1024, 8192), 8192);
    });

    test('returns fallback for NaN', () {
      expect(SettingsValidator.sanitizeDimension(double.nan, 1280, 1024, 8192), 1280);
    });

    test('returns fallback for infinity', () {
      expect(SettingsValidator.sanitizeDimension(double.infinity, 1280, 1024, 8192), 1280);
    });

    test('returns fallback for negative', () {
      expect(SettingsValidator.sanitizeDimension(-100, 1280, 1024, 8192), 1280);
    });

    test('returns fallback for zero', () {
      expect(SettingsValidator.sanitizeDimension(0, 1280, 1024, 8192), 1280);
    });
  });

  group('SettingsValidator.sanitizeCoordinate', () {
    test('clamps normal coordinate', () {
      expect(SettingsValidator.sanitizeCoordinate(500, 0), 500);
    });

    test('clamps negative coordinate', () {
      expect(SettingsValidator.sanitizeCoordinate(-50000, 0), -30000);
    });

    test('clamps positive coordinate', () {
      expect(SettingsValidator.sanitizeCoordinate(50000, 0), 30000);
    });

    test('returns fallback for NaN', () {
      expect(SettingsValidator.sanitizeCoordinate(double.nan, 0), 0);
    });

    test('returns fallback for infinity', () {
      expect(SettingsValidator.sanitizeCoordinate(double.infinity, 0), 0);
    });
  });

  group('SettingsValidator.sanitizeRotation', () {
    test('accepts valid rotations', () {
      expect(SettingsValidator.sanitizeRotation(0), 0);
      expect(SettingsValidator.sanitizeRotation(90), 90);
      expect(SettingsValidator.sanitizeRotation(180), 180);
      expect(SettingsValidator.sanitizeRotation(270), 270);
    });

    test('returns 0 for invalid rotation', () {
      expect(SettingsValidator.sanitizeRotation(45), 0);
      expect(SettingsValidator.sanitizeRotation(360), 0);
      expect(SettingsValidator.sanitizeRotation(-90), 0);
    });
  });

  group('SettingsValidator per-field validators', () {
    test('volume clamps to [0.0, 1.0]', () {
      expect(SettingsValidator.volume(0.5), 0.5);
      expect(SettingsValidator.volume(-0.1), 0.0);
      expect(SettingsValidator.volume(1.5), 1.0);
    });

    test('playMode clamps to valid range', () {
      expect(SettingsValidator.playMode(0), 0);
      expect(SettingsValidator.playMode(1), 1);
      expect(SettingsValidator.playMode(-1), 0);
      expect(SettingsValidator.playMode(999), PlayMode.values.length - 1);
    });

    test('themeIndex clamps to [0, themeIndexMax]', () {
      expect(SettingsValidator.themeIndex(0), 0);
      expect(SettingsValidator.themeIndex(2), 2);
      expect(SettingsValidator.themeIndex(-1), 0);
      expect(SettingsValidator.themeIndex(10), SettingsValidator.themeIndexMax);
    });

    test('subtitleFontSize clamps to valid range', () {
      expect(SettingsValidator.subtitleFontSize(17), 17);
      expect(SettingsValidator.subtitleFontSize(10), 14);
      expect(SettingsValidator.subtitleFontSize(40), 28);
    });

    test('subtitleColorIndex clamps to [0, subtitleColorIndexMax]', () {
      expect(SettingsValidator.subtitleColorIndex(0), 0);
      expect(SettingsValidator.subtitleColorIndex(2), 2);
      expect(SettingsValidator.subtitleColorIndex(-1), 0);
      expect(SettingsValidator.subtitleColorIndex(10), 2);
    });

    test('subtitleOffset clamps to valid range', () {
      expect(SettingsValidator.subtitleOffset(80), 80);
      expect(SettingsValidator.subtitleOffset(10), 60);
      expect(SettingsValidator.subtitleOffset(300), 200);
    });

    test('videoEffect clamps to [-1, 1]', () {
      expect(SettingsValidator.videoEffect(0), 0);
      expect(SettingsValidator.videoEffect(-2), -1);
      expect(SettingsValidator.videoEffect(2), 1);
    });

    test('videoAspectRatioIndex clamps to valid range', () {
      expect(SettingsValidator.videoAspectRatioIndex(0), 0);
      expect(SettingsValidator.videoAspectRatioIndex(-1), 0);
      expect(SettingsValidator.videoAspectRatioIndex(999), AspectRatioMode.values.length - 1);
    });
  });
}
