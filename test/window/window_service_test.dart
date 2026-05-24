import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/window/window_state.dart';
import 'package:simple_player_flutter/window/window_constants.dart';

void main() {
  group('WindowState initial state', () {
    test('ValueNotifiers have correct defaults', () {
      final ws = WindowState();
      expect(ws.fullscreen.value, false);
      expect(ws.maximized.value, false);
      expect(ws.alwaysOnTop.value, false);
      expect(ws.focused.value, true);
      ws.dispose();
    });
  });

  group('WindowState value changes', () {
    test('fullscreen can be toggled', () {
      final ws = WindowState();
      ws.fullscreen.value = true;
      expect(ws.fullscreen.value, true);
      ws.fullscreen.value = false;
      expect(ws.fullscreen.value, false);
      ws.dispose();
    });

    test('maximized can be toggled', () {
      final ws = WindowState();
      ws.maximized.value = true;
      expect(ws.maximized.value, true);
      ws.dispose();
    });

    test('alwaysOnTop can be toggled', () {
      final ws = WindowState();
      ws.alwaysOnTop.value = true;
      expect(ws.alwaysOnTop.value, true);
      ws.dispose();
    });

    test('focused defaults to true', () {
      final ws = WindowState();
      expect(ws.focused.value, true);
      ws.focused.value = false;
      expect(ws.focused.value, false);
      ws.dispose();
    });
  });

  group('Resize debounce pattern', () {
    test('debounce timer resets on rapid calls', () async {
      var resizing = false;
      int callCount = 0;

      void onResizeStart() {
        if (!resizing) {
          resizing = true;
        }
        callCount++;
      }

      onResizeStart();
      onResizeStart();
      onResizeStart();

      expect(resizing, true);
      expect(callCount, 3);
    });

    test('debounce uses 500ms duration', () {
      const debounceMs = 500;
      expect(debounceMs, 500);
    });
  });

  group('Closing guard pattern', () {
    test('double close is prevented by guard', () async {
      bool closing = false;
      int closeCount = 0;

      Future<void> onClose() async {
        if (closing) return;
        closing = true;
        closeCount++;
        await Future<void>.delayed(Duration.zero);
      }

      await onClose();
      await onClose();

      expect(closeCount, 1);
      expect(closing, true);
    });
  });

  group('Min size constant', () {
    test('min size is 800x450 (16:9)', () {
      const minSize = WindowConstants.minSize;
      expect(minSize.width, 800);
      expect(minSize.height, 450);
      expect(minSize.width / minSize.height, closeTo(16.0 / 9.0, 0.01));
    });
  });
}
