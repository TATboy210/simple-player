/// Unit tests for [AppSettings].
///
/// Covers: defaults, copyWith (including sentinel pattern for nullable
/// windowX/windowY), equality, hashCode.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/app_settings.dart';

/// Helper to create a fully-specified AppSettings for testing.
AppSettings _fullSettings() => const AppSettings(
  volume: 75,
  lastFile: r'C:\test\video.mp4',
  windowWidth: 1280,
  windowHeight: 720,
  windowX: 100,
  windowY: 200,
  isMaximized: true,
  playMode: 2,
  isMuted: true,
  isAlwaysOnTop: true,
  subtitleFontSize: 24,
  subtitleColorIndex: 3,
  subtitleBottomOffset: 100,
  videoBrightness: 0.5,
  videoContrast: -0.3,
  videoSaturation: 0.8,
  videoHue: 45,
  videoRotation: 90,
  videoAspectRatioIndex: 2,
  videoDeinterlace: true,
  playbackSpeed: 1.5,
  d3d11Sync: false,
  hardwareDecoding: false,
);

void main() {
  group('AppSettings', () {
    group('defaults', () {
      test('has correct default values', () {
        const settings = AppSettings(
          volume: 50,
          lastFile: '',
          windowWidth: 960,
          windowHeight: 540,
          playMode: 0,
          isMuted: false,
        );
        expect(settings.volume, 50);
        expect(settings.lastFile, '');
        expect(settings.windowWidth, 960);
        expect(settings.windowHeight, 540);
        expect(settings.windowX, isNull);
        expect(settings.windowY, isNull);
        expect(settings.isMaximized, isFalse);
        expect(settings.playMode, 0);
        expect(settings.isMuted, isFalse);
        expect(settings.isAlwaysOnTop, isFalse);
        expect(settings.subtitleFontSize, 17.0);
        expect(settings.subtitleColorIndex, 0);
        expect(settings.subtitleBottomOffset, 80.0);
        expect(settings.videoBrightness, 0.0);
        expect(settings.videoContrast, 0.0);
        expect(settings.videoSaturation, 0.0);
        expect(settings.videoHue, 0.0);
        expect(settings.videoRotation, 0);
        expect(settings.videoAspectRatioIndex, 0);
        expect(settings.videoDeinterlace, isFalse);
        expect(settings.playbackSpeed, 1.0);
        expect(settings.d3d11Sync, isTrue);
        expect(settings.hardwareDecoding, isTrue);
      });

      test('const constructor works', () {
        const settings = AppSettings(
          volume: 0,
          lastFile: '',
          windowWidth: 0,
          windowHeight: 0,
          playMode: 0,
          isMuted: false,
        );
        expect(settings.volume, 0);
      });
    });

    group('copyWith', () {
      test('copies single field', () {
        final original = _fullSettings();
        final copied = original.copyWith(volume: 99);
        expect(copied.volume, 99);
        expect(copied.lastFile, original.lastFile);
        expect(copied.windowWidth, original.windowWidth);
      });

      test('copies multiple fields', () {
        final original = _fullSettings();
        final copied = original.copyWith(volume: 10, isMuted: false);
        expect(copied.volume, 10);
        expect(copied.isMuted, isFalse);
        expect(copied.windowWidth, original.windowWidth);
      });

      test('preserves all fields when no arguments', () {
        final original = _fullSettings();
        final copied = original.copyWith();
        expect(copied, equals(original));
      });

      group('sentinel pattern for nullable windowX/windowY', () {
        test('keeps windowX when not provided', () {
          final original = _fullSettings();
          expect(original.windowX, 100);
          final copied = original.copyWith(volume: 50);
          expect(copied.windowX, 100);
        });

        test('sets windowX to null when explicitly passed', () {
          final original = _fullSettings();
          expect(original.windowX, 100);
          final copied = original.copyWith(windowX: null);
          expect(copied.windowX, isNull);
        });

        test('keeps windowY when not provided', () {
          final original = _fullSettings();
          expect(original.windowY, 200);
          final copied = original.copyWith(volume: 50);
          expect(copied.windowY, 200);
        });

        test('sets windowY to null when explicitly passed', () {
          final original = _fullSettings();
          expect(original.windowY, 200);
          final copied = original.copyWith(windowY: null);
          expect(copied.windowY, isNull);
        });

        test('can set windowX to a new value', () {
          final original = _fullSettings();
          final copied = original.copyWith(windowX: 999.0);
          expect(copied.windowX, 999);
        });

        test('can set both windowX and windowY to null', () {
          final original = _fullSettings();
          final copied = original.copyWith(windowX: null, windowY: null);
          expect(copied.windowX, isNull);
          expect(copied.windowY, isNull);
        });
      });

      test('copies video processing fields', () {
        final original = _fullSettings();
        final copied = original.copyWith(
          videoBrightness: 1.0,
          videoRotation: 180,
          videoDeinterlace: false,
        );
        expect(copied.videoBrightness, 1.0);
        expect(copied.videoRotation, 180);
        expect(copied.videoDeinterlace, isFalse);
        expect(copied.videoContrast, original.videoContrast);
        expect(copied.videoSaturation, original.videoSaturation);
      });

      test('copies playbackSpeed', () {
        final original = _fullSettings();
        final copied = original.copyWith(playbackSpeed: 2.0);
        expect(copied.playbackSpeed, 2.0);
      });
    });

    group('equality', () {
      test('equal when all fields match', () {
        final a = _fullSettings();
        final b = _fullSettings();
        expect(a, equals(b));
      });

      test('not equal when volume differs', () {
        final a = _fullSettings();
        final b = a.copyWith(volume: 99);
        expect(a, isNot(equals(b)));
      });

      test('not equal when windowX differs', () {
        final a = _fullSettings();
        final b = a.copyWith(windowX: 999.0);
        expect(a, isNot(equals(b)));
      });

      test('not equal when windowX null vs value', () {
        final a = _fullSettings();
        final b = a.copyWith(windowX: null);
        expect(a, isNot(equals(b)));
      });

      test('identical instances are equal', () {
        final a = _fullSettings();
        expect(a, equals(a));
      });

      test('not equal to non-AppSettings', () {
        final a = _fullSettings();
        // ignore: unrelated_type_equality_checks
        expect(a == 'not settings', isFalse);
      });
    });

    group('hashCode', () {
      test('consistent for equal instances', () {
        final a = _fullSettings();
        final b = _fullSettings();
        expect(a.hashCode, b.hashCode);
      });

      test('different when fields differ', () {
        final a = _fullSettings();
        final b = a.copyWith(volume: 99);
        expect(a.hashCode == b.hashCode, isFalse);
      });
    });
  });
}
