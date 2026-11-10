import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/platform/platform_profile.dart';

void main() {
  group('WindowPlatformProfile.detect', () {
    test('windows 10 drops the DWM frame', () {
      final profile = WindowPlatformProfile.detect(
        operatingSystem: () => 'windows',
        osVersion: () => '"Windows 10 Pro" 10.0 (Build 19045)',
        environment: () => const <String, String>{},
      );

      expect(profile.dropDwmFrame, isTrue);
      expect(profile.supportsWindowPositioning, isTrue);
      expect(profile.needsResizeHotZones, isFalse);
    });

    test('windows 11 keeps the DWM frame', () {
      final profile = WindowPlatformProfile.detect(
        operatingSystem: () => 'windows',
        osVersion: () => '"Windows 11 Home" 10.0 (Build 26300)',
        environment: () => const <String, String>{},
      );

      expect(profile.dropDwmFrame, isFalse);
    });

    test('unparseable windows version keeps the frame (fail-safe)', () {
      final profile = WindowPlatformProfile.detect(
        operatingSystem: () => 'windows',
        osVersion: () => 'garbage without build number',
        environment: () => const <String, String>{},
      );

      // 解析失败 → 不当作 Win10 处理（去 frame 是不可逆的视觉降级）。
      expect(profile.dropDwmFrame, isFalse);
    });

    test('linux wayland disables positioning and needs resize hot zones', () {
      final profile = WindowPlatformProfile.detect(
        operatingSystem: () => 'linux',
        environment: () => const <String, String>{'WAYLAND_DISPLAY': 'wayland-0'},
      );

      expect(profile.supportsWindowPositioning, isFalse);
      expect(profile.needsResizeHotZones, isTrue);
      expect(profile.dropDwmFrame, isFalse);
    });

    test('linux x11 keeps positioning and still needs hot zones', () {
      final profile = WindowPlatformProfile.detect(
        operatingSystem: () => 'linux',
        environment: () => const <String, String>{'DISPLAY': ':0'},
      );

      expect(profile.supportsWindowPositioning, isTrue);
      // frameless 后无系统 resize 边缘 — X11 同样需要 UI 热区。
      expect(profile.needsResizeHotZones, isTrue);
    });

    test('macos gets full support without hot zones', () {
      final profile = WindowPlatformProfile.detect(
        operatingSystem: () => 'macos',
        osVersion: () => 'Version 15.1 (Build 24B83)',
        environment: () => const <String, String>{},
      );

      expect(profile.dropDwmFrame, isFalse);
      expect(profile.supportsWindowPositioning, isTrue);
      // macOS titleBarStyle.hidden 保留 frame — 系统 resize 边缘仍在。
      expect(profile.needsResizeHotZones, isFalse);
    });
  });
}
