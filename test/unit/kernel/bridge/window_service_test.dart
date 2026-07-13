import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/bridge/window_service.dart';

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('WindowService composition', () {
    test('state.mode defaults to windowed', () {
      final service = WindowService();
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('mode getter delegates to state.mode', () {
      final service = WindowService();
      expect(service.mode.value, WindowMode.windowed);
      service.state.mode.value = WindowMode.maximized;
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('state windowSize defaults to 1280x752', () {
      final service = WindowService();
      expect(service.state.windowSize.value.width, 1280);
      expect(service.state.windowSize.value.height, 752);
      service.dispose();
    });
  });

  group('WindowListener callbacks', () {
    test('onWindowMaximize sets mode to maximized', () {
      final service = WindowService();
      service.onWindowMaximize();
      expect(service.state.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('onWindowUnmaximize sets mode to windowed', () {
      final service = WindowService();
      service.state.mode.value = WindowMode.maximized;
      service.onWindowUnmaximize();
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

  });

  group('dispose safety', () {
    test('callback after dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.onWindowMaximize(), returnsNormally);
      expect(() => service.onWindowUnmaximize(), returnsNormally);
      expect(() => service.onWindowResize(), returnsNormally);
    });

    test('double dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.dispose(), returnsNormally);
    });
  });

  // TODO: Phase 4 — rewrite driver creation tests without FullscreenDriver
  // WindowService no longer accepts driver parameter (Phase 1 removed it).

  // TODO: Phase 4 — rewrite FullscreenResult tests
  // FullscreenResult/FullscreenSuccess/FullscreenFailure sealed class deleted in Phase 1.

  // TODO: Phase 4 — rewrite confirmation chain tests
  // FullscreenDriver mock and WindowService(driver:) constructor deleted in Phase 1.

  group('isFullscreen derives from mode', () {
    test('isFullscreen returns false when mode is windowed', () {
      final service = WindowService();
      expect(service.isFullscreen, isFalse);
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('isFullscreen returns true when mode is fullscreen', () {
      final service = WindowService();
      service.state.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);
      service.dispose();
    });

    test('isFullscreen tracks mode changes', () {
      final service = WindowService();
      expect(service.isFullscreen, isFalse);
      service.state.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);
      service.state.mode.value = WindowMode.windowed;
      expect(service.isFullscreen, isFalse);
      service.dispose();
    });
  });
}
