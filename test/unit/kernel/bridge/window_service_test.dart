import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/bridge/window_service.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
    // WindowService callback methods use KernelLogger.I — must init first
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
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

  // =========================================================================
  // Deep coverage: WindowState fields
  // =========================================================================
  group('WindowState', () {
    test('windowSize defaults to 1280x752', () {
      final service = WindowService();
      expect(service.state.windowSize.value.width, 1280);
      expect(service.state.windowSize.value.height, 752);
      service.dispose();
    });

    test('mode defaults to windowed', () {
      final service = WindowService();
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('isResizing defaults to false', () {
      final service = WindowService();
      expect(service.state.isResizing.value, isFalse);
      service.dispose();
    });

    test('isAlwaysOnTop defaults to false', () {
      final service = WindowService();
      expect(service.state.isAlwaysOnTop.value, isFalse);
      service.dispose();
    });
  });

  // =========================================================================
  // Deep coverage: mode transitions
  // =========================================================================
  group('mode transitions', () {
    test('setting mode to same value does not fire extra notification', () {
      final service = WindowService();
      var count = 0;
      service.state.mode.addListener(() => count++);
      service.state.mode.value = WindowMode.maximized; // fires once
      service.state.mode.value = WindowMode.maximized; // same value — no fire
      expect(count, 1);
      service.dispose();
    });

    test('windowed → maximized → windowed cycle', () {
      final service = WindowService();
      expect(service.state.mode.value, WindowMode.windowed);

      service.state.mode.value = WindowMode.maximized;
      expect(service.state.mode.value, WindowMode.maximized);
      expect(service.isFullscreen, isFalse);

      service.state.mode.value = WindowMode.windowed;
      expect(service.state.mode.value, WindowMode.windowed);

      service.dispose();
    });

    test('windowed → fullscreen → windowed cycle', () {
      final service = WindowService();
      service.state.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);

      service.state.mode.value = WindowMode.windowed;
      expect(service.isFullscreen, isFalse);

      service.dispose();
    });
  });

  // =========================================================================
  // Deep coverage: WindowListener callback details
  // =========================================================================
  group('WindowListener callback deep', () {
    test('onWindowMaximize is idempotent when already maximized', () {
      final service = WindowService();
      service.state.mode.value = WindowMode.maximized;
      service.onWindowMaximize();
      expect(service.state.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('onWindowUnmaximize from non-maximized is no-op', () {
      final service = WindowService();
      expect(service.state.mode.value, WindowMode.windowed);
      service.onWindowUnmaximize();
      expect(service.state.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('onWindowResize after dispose is no-op', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.onWindowResize(), returnsNormally);
    });
  });

  // =========================================================================
  // Deep coverage: dispose safety expanded
  // =========================================================================
  group('dispose safety expanded', () {
    test('triple dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      service.dispose();
      service.dispose();
    });

    test('all callbacks are safe after dispose', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.onWindowMaximize(), returnsNormally);
      expect(() => service.onWindowUnmaximize(), returnsNormally);
      expect(() => service.onWindowResize(), returnsNormally);
    });
  });

  // =========================================================================
  // Deep coverage: WindowMode enum
  // =========================================================================
  group('WindowMode enum', () {
    test('has 4 values', () {
      expect(WindowMode.values, hasLength(4));
    });

    test('windowed isFullscreen is false', () {
      expect(WindowMode.windowed.isFullscreen, isFalse);
    });

    test('fullscreen isFullscreen is true', () {
      expect(WindowMode.fullscreen.isFullscreen, isTrue);
    });

    test('maximized isMaximized is true', () {
      expect(WindowMode.maximized.isMaximized, isTrue);
    });

    test('minimized isMinimized is true', () {
      expect(WindowMode.minimized.isMinimized, isTrue);
    });

    test('windowed isWindowed is true', () {
      expect(WindowMode.windowed.isWindowed, isTrue);
    });

    test('enum names are correct', () {
      expect(WindowMode.windowed.name, 'windowed');
      expect(WindowMode.maximized.name, 'maximized');
      expect(WindowMode.fullscreen.name, 'fullscreen');
      expect(WindowMode.minimized.name, 'minimized');
    });
  });

  // =========================================================================
  // Deep coverage: ValueNotifier listeners
  // =========================================================================
  group('ValueNotifier listeners', () {
    test('mode notifier fires listeners', () {
      final service = WindowService();
      var notified = false;
      service.state.mode.addListener(() => notified = true);

      service.state.mode.value = WindowMode.maximized;
      expect(notified, isTrue);

      service.dispose();
    });

    test('windowSize notifier fires listeners', () {
      final service = WindowService();
      var notified = false;
      service.state.windowSize.addListener(() => notified = true);

      service.state.windowSize.value = const Size(1920, 1080);
      expect(notified, isTrue);

      service.dispose();
    });

    test('isResizing notifier fires listeners', () {
      final service = WindowService();
      var notified = false;
      service.state.isResizing.addListener(() => notified = true);

      service.state.isResizing.value = true;
      expect(notified, isTrue);

      service.dispose();
    });

    test('isAlwaysOnTop notifier fires listeners', () {
      final service = WindowService();
      var notified = false;
      service.state.isAlwaysOnTop.addListener(() => notified = true);

      service.state.isAlwaysOnTop.value = true;
      expect(notified, isTrue);

      service.dispose();
    });
  });
}
