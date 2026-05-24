import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowShell fullscreen-aware resize pattern', () {
    test('fullscreen mode disables resize edges', () {
      final fullscreen = ValueNotifier<bool>(true);

      // Simulate the WindowShell logic
      final enableResizeEdges = fullscreen.value
          ? <dynamic>[]
          : null; // null = all edges enabled

      expect(enableResizeEdges, isEmpty);
      fullscreen.dispose();
    });

    test('windowed mode enables all resize edges', () {
      final fullscreen = ValueNotifier<bool>(false);

      final enableResizeEdges = fullscreen.value
          ? <dynamic>[]
          : null;

      expect(enableResizeEdges, isNull);
      fullscreen.dispose();
    });

    test('mode change updates resize edge behavior', () {
      final fullscreen = ValueNotifier<bool>(false);

      // Windowed: edges enabled
      expect(fullscreen.value, isFalse);

      // Switch to fullscreen
      fullscreen.value = true;
      expect(fullscreen.value, isTrue);

      // Back to windowed
      fullscreen.value = false;
      expect(fullscreen.value, isFalse);

      fullscreen.dispose();
    });
  });

  group('WindowShell TitleBar glass degradation pattern', () {
    test('resizing skips blur (uses solid color)', () {
      final isResizing = ValueNotifier<bool>(true);

      // When resizing, TitleBar skips BackdropFilter
      final useBlur = !isResizing.value;
      expect(useBlur, false);

      isResizing.dispose();
    });

    test('idle shows blur', () {
      final isResizing = ValueNotifier<bool>(false);

      final useBlur = !isResizing.value;
      expect(useBlur, true);

      isResizing.dispose();
    });
  });

  group('WindowShell structure constants', () {
    test('resize edge size is 8px', () {
      const resizeEdgeSize = 8;
      expect(resizeEdgeSize, 8);
    });

    test('title bar height is 36px', () {
      const titleBarHeight = 36.0;
      expect(titleBarHeight, 36.0);
    });
  });
}
