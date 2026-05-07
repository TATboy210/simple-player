import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/platform_service.dart';
import 'package:simple_player_flutter/kernel/window/window_manager_service.dart';

void main() {
  group('WindowMode', () {
    test('has windowed and fullscreen values', () {
      expect(WindowMode.values, hasLength(2));
      expect(WindowMode.values, contains(WindowMode.windowed));
      expect(WindowMode.values, contains(WindowMode.fullscreen));
    });
  });

  group('WindowManagerService singleton', () {
    test('I returns same instance', () {
      final a = WindowManagerService.I;
      final b = WindowManagerService.I;
      expect(identical(a, b), isTrue);
    });

    test('initial mode is windowed', () {
      expect(WindowManagerService.I.mode.value, WindowMode.windowed);
    });

    test('initial isAlwaysOnTop is false', () {
      expect(WindowManagerService.I.isAlwaysOnTop.value, isFalse);
    });

    test('initial isMaximized is false', () {
      expect(WindowManagerService.I.isMaximized.value, isFalse);
    });

    test('initial isResizing is false', () {
      expect(WindowManagerService.I.isResizing.value, isFalse);
    });
  });

  group('WindowManagerService WindowListener callbacks', () {
    late WindowManagerService wm;

    setUp(() {
      wm = WindowManagerService.I;
      // Reset state
      wm.mode.value = WindowMode.windowed;
      wm.isMaximized.value = false;
      wm.isAlwaysOnTop.value = false;
      wm.isResizing.value = false;
    });

    test('onWindowMaximize sets isMaximized to true', () {
      wm.onWindowMaximize();
      expect(wm.isMaximized.value, isTrue);
    });

    test('onWindowUnmaximize sets isMaximized to false', () {
      wm.isMaximized.value = true;
      wm.onWindowUnmaximize();
      expect(wm.isMaximized.value, isFalse);
    });

    test('onWindowEnterFullScreen sets mode to fullscreen', () {
      wm.onWindowEnterFullScreen();
      expect(wm.mode.value, WindowMode.fullscreen);
    });

    test('onWindowLeaveFullScreen sets mode to windowed', () {
      wm.mode.value = WindowMode.fullscreen;
      wm.onWindowLeaveFullScreen();
      expect(wm.mode.value, WindowMode.windowed);
    });

    test('onWindowResize sets isResizing to true on first frame', () {
      expect(wm.isResizing.value, isFalse);
      wm.onWindowResize();
      expect(wm.isResizing.value, isTrue);
    });

    test('onWindowResize is idempotent when already resizing', () {
      wm.isResizing.value = true;
      // Should not throw or cause issues
      wm.onWindowResize();
      expect(wm.isResizing.value, isTrue);
    });
  });

  group('WindowManagerService minSize', () {
    test('minSize is 640x360 (360p 16:9)', () {
      expect(WindowManagerService.minSize.width, 640.0);
      expect(WindowManagerService.minSize.height, 360.0);
    });

    test('minSize aspect ratio is 16:9', () {
      final ratio = WindowManagerService.minSize.width /
          WindowManagerService.minSize.height;
      expect(ratio, closeTo(16.0 / 9.0, 0.01));
    });
  });

  group('WindowManagerService state transitions', () {
    late WindowManagerService wm;

    setUp(() {
      wm = WindowManagerService.I;
      wm.mode.value = WindowMode.windowed;
      wm.isMaximized.value = false;
      wm.isResizing.value = false;
    });

    test('mode ValueNotifier notifies listeners on change', () {
      final values = <WindowMode>[];
      wm.mode.addListener(() => values.add(wm.mode.value));

      wm.mode.value = WindowMode.fullscreen;
      wm.mode.value = WindowMode.windowed;

      expect(values, [WindowMode.fullscreen, WindowMode.windowed]);
    });

    test('isMaximized ValueNotifier notifies listeners', () {
      final values = <bool>[];
      wm.isMaximized.addListener(() => values.add(wm.isMaximized.value));

      wm.isMaximized.value = true;
      wm.isMaximized.value = false;

      expect(values, [true, false]);
    });

    test('isResizing ValueNotifier notifies listeners', () {
      final values = <bool>[];
      wm.isResizing.addListener(() => values.add(wm.isResizing.value));

      wm.isResizing.value = true;
      wm.isResizing.value = false;

      expect(values, [true, false]);
    });

    test('onWindowEnterFullScreen is idempotent', () {
      wm.onWindowEnterFullScreen();
      wm.onWindowEnterFullScreen();
      expect(wm.mode.value, WindowMode.fullscreen);
    });

    test('onWindowLeaveFullScreen is idempotent', () {
      wm.onWindowLeaveFullScreen();
      wm.onWindowLeaveFullScreen();
      expect(wm.mode.value, WindowMode.windowed);
    });

    test('full cycle: windowed -> fullscreen -> windowed', () {
      expect(wm.mode.value, WindowMode.windowed);

      wm.onWindowEnterFullScreen();
      expect(wm.mode.value, WindowMode.fullscreen);

      wm.onWindowLeaveFullScreen();
      expect(wm.mode.value, WindowMode.windowed);
    });

    test('full cycle: unmaximized -> maximized -> unmaximized', () {
      expect(wm.isMaximized.value, isFalse);

      wm.onWindowMaximize();
      expect(wm.isMaximized.value, isTrue);

      wm.onWindowUnmaximize();
      expect(wm.isMaximized.value, isFalse);
    });
  });

  group('WIN-05: alwaysOnTop and fullscreen persistence wiring', () {
    late WindowManagerService wm;

    setUp(() {
      wm = WindowManagerService.I;
      wm.isAlwaysOnTop.value = false;
      wm.mode.value = WindowMode.windowed;
    });

    test('isAlwaysOnTop is a ValueNotifier for UI binding', () {
      expect(wm.isAlwaysOnTop, isA<ValueNotifier<bool>>());
    });

    test('initial isAlwaysOnTop is false', () {
      expect(wm.isAlwaysOnTop.value, isFalse);
    });

    test('isAlwaysOnTop can be toggled via value', () {
      expect(wm.isAlwaysOnTop.value, isFalse);
      wm.isAlwaysOnTop.value = true;
      expect(wm.isAlwaysOnTop.value, isTrue);
      wm.isAlwaysOnTop.value = false;
      expect(wm.isAlwaysOnTop.value, isFalse);
    });

    test('isAlwaysOnTop ValueNotifier notifies listeners', () {
      final values = <bool>[];
      wm.isAlwaysOnTop.addListener(() => values.add(wm.isAlwaysOnTop.value));
      wm.isAlwaysOnTop.value = true;
      wm.isAlwaysOnTop.value = false;
      expect(values, [true, false]);
    });
  });

  group('WIN-04: Fullscreen sequence verification', () {
    late WindowManagerService wm;

    setUp(() {
      wm = WindowManagerService.I;
      wm.mode.value = WindowMode.windowed;
    });

    test('onWindowEnterFullScreen changes mode to fullscreen', () {
      wm.mode.value = WindowMode.windowed;
      wm.onWindowEnterFullScreen();
      expect(wm.mode.value, WindowMode.fullscreen);
    });

    test('onWindowLeaveFullScreen changes mode to windowed', () {
      wm.mode.value = WindowMode.fullscreen;
      wm.onWindowLeaveFullScreen();
      expect(wm.mode.value, WindowMode.windowed);
    });

    test('enter+exit cycle returns to windowed', () {
      wm.mode.value = WindowMode.windowed;
      wm.onWindowEnterFullScreen();
      expect(wm.mode.value, WindowMode.fullscreen);
      wm.onWindowLeaveFullScreen();
      expect(wm.mode.value, WindowMode.windowed);
    });
  });

  group('WIN-01: isResizing verification', () {
    late WindowManagerService wm;

    setUp(() {
      wm = WindowManagerService.I;
      wm.isResizing.value = false;
    });

    test('isResizing is a ValueNotifier for UI binding', () {
      expect(wm.isResizing, isA<ValueNotifier<bool>>());
    });
  });

  group('WindowManagerService resize debouncing', () {
    late WindowManagerService wm;

    setUp(() {
      wm = WindowManagerService.I;
      wm.isResizing.value = false;
    });

    testWidgets('isResizing resets after 100ms debounce',
        (WidgetTester tester) async {
      wm.onWindowResize();
      expect(wm.isResizing.value, isTrue);

      // onWindowResized schedules 100ms debounce to reset + 500ms persist
      wm.onWindowResized();

      // Still true immediately
      expect(wm.isResizing.value, isTrue);

      // Wait for all timers (100ms resize + 500ms persist)
      await tester.pump(const Duration(milliseconds: 600));
      expect(wm.isResizing.value, isFalse);
    });

    testWidgets('rapid resize events reset only once',
        (WidgetTester tester) async {
      // Simulate rapid resize
      wm.onWindowResize();
      wm.onWindowResized();
      wm.onWindowResize();
      wm.onWindowResized();
      wm.onWindowResize();
      wm.onWindowResized();

      expect(wm.isResizing.value, isTrue);

      // Wait for all timers (100ms resize + 500ms persist)
      await tester.pump(const Duration(milliseconds: 600));
      expect(wm.isResizing.value, isFalse);
    });
  });
}
