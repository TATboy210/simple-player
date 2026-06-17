import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/bridge/window_bootstrap.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('clampToVisibleBounds', () {
    test('returns original offset when window is within visible area', () {
      // Window at (100, 100), size 800x600 — well within any reasonable screen
      final result = WindowBootstrap.clampToVisibleBounds(
        x: 100,
        y: 100,
        width: 800,
        height: 600,
      );
      expect(result, equals(const Offset(100, 100)));
    });

    test(
      'returns original offset when window is near screen edge but visible',
      () {
        // Window at (50, 50), size 200x200 — 250px from origin, > 100 minVisible
        final result = WindowBootstrap.clampToVisibleBounds(
          x: 50,
          y: 50,
          width: 200,
          height: 200,
        );
        expect(result, equals(const Offset(50, 50)));
      },
    );

    test('centers when window is off left edge', () {
      // Window at (-700, 100), size 800x600 — x+w = 100, which is exactly
      // at the minVisible threshold. With < minVisible check, this is off-screen.
      // Actually: x + width = -700 + 800 = 100. The check is < _minVisible (100).
      // 100 < 100 is false, so this is NOT off-screen. Let's use -701.
      final result = WindowBootstrap.clampToVisibleBounds(
        x: -701,
        y: 100,
        width: 800,
        height: 600,
      );
      // Should be centered — not equal to original
      expect(result, isNot(equals(const Offset(-701, 100))));
      // Centered x should be positive
      expect(result.dx, greaterThanOrEqualTo(0));
    });

    test('centers when window is off top edge', () {
      final result = WindowBootstrap.clampToVisibleBounds(
        x: 100,
        y: -501,
        width: 800,
        height: 600,
      );
      expect(result, isNot(equals(const Offset(100, -501))));
      expect(result.dy, greaterThanOrEqualTo(0));
    });

    test('returns original offset for zero position', () {
      final result = WindowBootstrap.clampToVisibleBounds(
        x: 0,
        y: 0,
        width: 800,
        height: 600,
      );
      expect(result, equals(const Offset(0, 0)));
    });
  });

  group('clearFullscreenIfSaved', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('clears isFullscreen flag when true', () async {
      SharedPreferences.setMockInitialValues({'isFullscreen': true});

      final settings = const AppSettings(
        volume: 1,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
        isFullscreen: true,
      );

      await WindowBootstrap.clearFullscreenIfSaved(settings);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isFullscreen'), isFalse);
    });

    test('is no-op when isFullscreen is already false', () async {
      SharedPreferences.setMockInitialValues({'isFullscreen': false});

      final settings = const AppSettings(
        volume: 1,
        lastFile: '',
        windowWidth: 1280,
        windowHeight: 720,
        playMode: 0,
        isMuted: false,
        isFullscreen: false,
      );

      await WindowBootstrap.clearFullscreenIfSaved(settings);

      final prefs = await SharedPreferences.getInstance();
      // Should remain false — no save was triggered
      expect(prefs.getBool('isFullscreen'), isFalse);
    });
  });
}
