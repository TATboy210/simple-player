import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_Bridge/window_manager_service.dart';

void main() {
  group('WindowState', () {
    late WindowState state;

    setUp(() {
      state = WindowState();
    });

    tearDown(() {
      state.dispose();
    });

    test('initial mode is windowed', () {
      expect(state.mode.value, WindowMode.windowed);
    });

    test('initial windowSize is 1280x752', () {
      expect(state.windowSize.value, const Size(1280, 752));
    });

    test('custom initialSize is applied', () {
      final custom = WindowState(initialSize: const Size(1920, 1080));
      expect(custom.windowSize.value, const Size(1920, 1080));
      custom.dispose();
    });

    test('mode can be set to maximized', () {
      state.mode.value = WindowMode.maximized;
      expect(state.mode.value.isMaximized, isTrue);
    });

    test('mode notifies listeners on change', () {
      final modes = <WindowMode>[];
      state.mode.addListener(() => modes.add(state.mode.value));
      state.mode.value = WindowMode.maximized;
      state.mode.value = WindowMode.windowed;
      expect(modes, [WindowMode.maximized, WindowMode.windowed]);
    });

    test('dispose sets disposed flag', () {
      expect(state.disposed, isFalse);
      state.dispose();
      expect(state.disposed, isTrue);
    });

    test('dispose is idempotent', () {
      state.dispose();
      state.dispose(); // should not throw
      expect(state.disposed, isTrue);
    });
  });
}
