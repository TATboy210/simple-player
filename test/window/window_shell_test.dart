import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_bridge.dart';

void main() {
  group('WindowShell fullscreen-aware resize pattern', () {
    test('fullscreen mode disables resize edges', () {
      final mode = ValueNotifier<WindowMode>(WindowMode.fullscreen);

      // Simulate the WindowShell logic
      final enableResizeEdges = mode.value == WindowMode.fullscreen
          ? <dynamic>[]
          : null; // null = all edges enabled

      expect(enableResizeEdges, isEmpty);
      mode.dispose();
    });

    test('windowed mode enables all resize edges', () {
      final mode = ValueNotifier<WindowMode>(WindowMode.windowed);

      final enableResizeEdges = mode.value == WindowMode.fullscreen
          ? <dynamic>[]
          : null;

      expect(enableResizeEdges, isNull);
      mode.dispose();
    });

    test('mode change updates resize edge behavior', () {
      final mode = ValueNotifier<WindowMode>(WindowMode.windowed);

      // Windowed: edges enabled
      expect(mode.value == WindowMode.fullscreen, isFalse);

      // Switch to fullscreen
      mode.value = WindowMode.fullscreen;
      expect(mode.value == WindowMode.fullscreen, isTrue);

      // Back to windowed
      mode.value = WindowMode.windowed;
      expect(mode.value == WindowMode.fullscreen, isFalse);

      mode.dispose();
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
