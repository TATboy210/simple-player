import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_bridge.dart';

void main() {
  group('WindowBridge', () {
    tearDown(() {
      // Reset injection between tests
      if (WindowBridge.I is! NoopWindowBridge) {
        WindowBridge.inject(NoopWindowBridge());
      }
    });

    test('I returns NoopWindowBridge when not injected', () {
      expect(WindowBridge.I, isA<NoopWindowBridge>());
    });

    test('inject replaces the instance', () {
      final noop = WindowBridge.I as NoopWindowBridge;
      WindowBridge.inject(_FakeWindowBridge());
      expect(WindowBridge.I, isNot(same(noop)));
    });
  });

  group('NoopWindowBridge', () {
    late NoopWindowBridge bridge;

    setUp(() {
      bridge = NoopWindowBridge();
    });

    test('default mode is windowed', () {
      expect(bridge.mode.value, WindowMode.windowed);
    });

    test('default isAlwaysOnTop is false', () {
      expect(bridge.isAlwaysOnTop.value, false);
    });

    test('default isMaximized is false', () {
      expect(bridge.isMaximized.value, false);
    });

    test('default isResizing is false', () {
      expect(bridge.isResizing.value, false);
    });

    test('all commands complete without error', () async {
      await bridge.minimize();
      await bridge.toggleMaximize();
      await bridge.close();
      await bridge.startDragging();
      await bridge.toggleFullscreen();
      await bridge.exitFullscreen();
      await bridge.toggleAlwaysOnTop();
      await bridge.init();
      await bridge.dispose();
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
