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

    test('isFullscreen proxy reads from state.mode', () {
      final service = WindowService();
      expect(service.isFullscreen.value, false);
      service.state.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen.value, true);
      service.dispose();
    });

    test('isMaximized proxy reads from state.mode', () {
      final service = WindowService();
      expect(service.isMaximized.value, false);
      service.state.mode.value = WindowMode.maximized;
      expect(service.isMaximized.value, true);
      service.dispose();
    });

    test('lastInteractionTime defaults to 0', () {
      final service = WindowService();
      expect(service.lastInteractionTime.value, 0);
      service.dispose();
    });

    test('state windowSize defaults to 1280x720', () {
      final service = WindowService();
      expect(service.state.windowSize.value.width, 1280);
      expect(service.state.windowSize.value.height, 720);
      service.dispose();
    });
  });

  group('WindowListener callbacks', () {
    test('onWindowMaximize sets mode to maximized', () {
      final service = WindowService();
      service.onWindowMaximize();
      expect(service.state.mode.value, WindowMode.maximized);
      expect(service.isMaximized.value, true);
      service.dispose();
    });

    test('onWindowUnmaximize sets mode to windowed', () {
      final service = WindowService();
      service.state.mode.value = WindowMode.maximized;
      service.onWindowUnmaximize();
      expect(service.state.mode.value, WindowMode.windowed);
      expect(service.isMaximized.value, false);
      service.dispose();
    });

    test('onWindowMaximize updates lastInteractionTime', () {
      final service = WindowService();
      service.onWindowMaximize();
      expect(service.lastInteractionTime.value, greaterThan(0));
      service.dispose();
    });

    test('onWindowUnmaximize updates lastInteractionTime', () {
      final service = WindowService();
      service.state.mode.value = WindowMode.maximized;
      service.onWindowUnmaximize();
      expect(service.lastInteractionTime.value, greaterThan(0));
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
}
