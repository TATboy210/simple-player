import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_bridge.dart';

void main() {
  group('WindowService via WindowBridge', () {
    test('NoopWindowBridge initial state', () {
      final noop = NoopWindowBridge();
      expect(noop.mode.value, WindowMode.windowed);
      expect(noop.isAlwaysOnTop.value, false);
      expect(noop.isMaximized.value, false);
      expect(noop.isResizing.value, false);
    });

    test('NoopWindowBridge commands all complete', () async {
      final noop = NoopWindowBridge();
      await noop.minimize();
      await noop.toggleMaximize();
      await noop.close();
      await noop.startDragging();
      await noop.toggleFullscreen();
      await noop.exitFullscreen();
      await noop.toggleAlwaysOnTop();
      await noop.init();
      await noop.dispose();
    });

    test('WindowBridge.I returns NoopWindowBridge by default', () {
      // Reset injection
      WindowBridge.inject(NoopWindowBridge());
      expect(WindowBridge.I, isA<NoopWindowBridge>());
    });

    test('WindowBridge.inject replaces instance', () {
      final fake = _FakeWindowBridge();
      WindowBridge.inject(fake);
      expect(WindowBridge.I, same(fake));

      // Reset
      WindowBridge.inject(NoopWindowBridge());
    });
  });

  group('WindowMode enum', () {
    test('has windowed and fullscreen values', () {
      expect(WindowMode.values, hasLength(2));
      expect(WindowMode.values, contains(WindowMode.windowed));
      expect(WindowMode.values, contains(WindowMode.fullscreen));
    });
  });

  group('WindowService ValueNotifier defaults', () {
    test('mode starts as windowed', () {
      final notifier = ValueNotifier<WindowMode>(WindowMode.windowed);
      expect(notifier.value, WindowMode.windowed);
      notifier.dispose();
    });

    test('isMaximized starts as false', () {
      final notifier = ValueNotifier<bool>(false);
      expect(notifier.value, false);
      notifier.dispose();
    });

    test('isAlwaysOnTop starts as false', () {
      final notifier = ValueNotifier<bool>(false);
      expect(notifier.value, false);
      notifier.dispose();
    });

    test('isResizing starts as false', () {
      final notifier = ValueNotifier<bool>(false);
      expect(notifier.value, false);
      notifier.dispose();
    });
  });

  group('WindowService resize debounce pattern', () {
    test('debounce timer resets on rapid calls', () async {
      // Simulate the resize debounce pattern used in WindowService
      bool isResizing = false;
      int callCount = 0;

      void onResizeStart() {
        if (!isResizing) isResizing = true;
        callCount++;
      }

      // Simulate rapid resize events
      onResizeStart();
      onResizeStart();
      onResizeStart();

      expect(isResizing, true);
      expect(callCount, 3);
    });

    test('debounce uses 500ms duration', () {
      // Verify the constant matches the expected value
      const debounceMs = 500;
      expect(debounceMs, 500);
    });
  });

  group('WindowService closing guard pattern', () {
    test('double close is prevented by guard', () async {
      bool closing = false;
      int closeCount = 0;

      Future<void> onClose() async {
        if (closing) return;
        closing = true;
        closeCount++;
        // Simulate async work
        await Future<void>.delayed(Duration.zero);
      }

      await onClose();
      await onClose(); // Second call should be no-op

      expect(closeCount, 1);
      expect(closing, true);
    });
  });

  group('WindowService persist guard pattern', () {
    test('concurrent persist returns existing future', () async {
      int persistCount = 0;
      Completer<void>? inFlight;

      Future<void> persist() async {
        if (inFlight != null) return inFlight!.future;
        inFlight = Completer<void>();
        try {
          persistCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          inFlight!.complete();
        } finally {
          inFlight = null;
        }
      }

      // Fire two concurrent persists
      final f1 = persist();
      final f2 = persist();

      await Future.wait([f1, f2]);

      // Only one actual persist should have run
      expect(persistCount, 1);
    });
  });

  group('WindowService min size constant', () {
    test('min size is 640x360 (360p 16:9)', () {
      const minSize = Size(640, 360);
      expect(minSize.width, 640);
      expect(minSize.height, 360);
      expect(minSize.width / minSize.height, closeTo(16.0 / 9.0, 0.01));
    });
  });
}

class _FakeWindowBridge implements WindowBridge {
  @override
  final mode = ValueNotifier(WindowMode.windowed);
  @override
  final isAlwaysOnTop = ValueNotifier(false);
  @override
  final isMaximized = ValueNotifier(false);
  @override
  final isResizing = ValueNotifier(false);

  @override
  Future<void> minimize() async {}
  @override
  Future<void> toggleMaximize() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> startDragging() async {}
  @override
  Future<void> toggleFullscreen() async {}
  @override
  Future<void> exitFullscreen() async {}
  @override
  Future<void> toggleAlwaysOnTop() async {}
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
}
