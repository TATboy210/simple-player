import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_controller.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/bridge/window_state.dart';

/// 测试替身 — 模拟窗口操作，无需真实平台。
class FakeWindowOps implements WindowOps {
  bool isFullScreenValue = false;
  Offset position = const Offset(100, 100);
  Size size = const Size(1280, 720);

  int setFullScreenCalls = 0;
  int setPositionCalls = 0;
  int setSizeCalls = 0;
  bool? lastSetFullScreenValue;

  @override
  Future<bool> isFullScreen() async => isFullScreenValue;

  @override
  Future<void> setFullScreen(bool value) async {
    setFullScreenCalls++;
    lastSetFullScreenValue = value;
    isFullScreenValue = value;
  }

  @override
  Future<Offset> getPosition() async => position;

  @override
  Future<void> setPosition(Offset pos) async {
    setPositionCalls++;
    position = pos;
  }

  @override
  Future<Size> getSize() async => size;

  @override
  Future<void> setSize(Size s) async {
    setSizeCalls++;
    size = s;
  }
}

/// 故障注入 — setFullScreen 抛异常。
class FailingWindowOps extends FakeWindowOps {
  @override
  Future<void> setFullScreen(bool value) async {
    throw Exception('setFullScreen failed');
  }
}

void main() {
  group('FullscreenController', () {
    late WindowState state;
    late FakeWindowOps ops;
    late FullscreenController ctrl;

    setUp(() {
      state = WindowState();
      ops = FakeWindowOps();
      ctrl = FullscreenController(state: state, ops: ops);
    });

    tearDown(() {
      state.dispose();
    });

    test('initial state is not animating', () {
      expect(ctrl.isAnimating, isFalse);
    });

    test('setFullscreen(true) sets mode to fullscreen', () async {
      await ctrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.fullscreen);
      expect(ctrl.isAnimating, isFalse);
    });

    test('setFullscreen(false) sets mode to windowed', () async {
      await ctrl.setFullscreen(true);
      await ctrl.setFullscreen(false);
      expect(state.mode.value, WindowMode.windowed);
    });

    test('setFullscreen is no-op when already in target mode', () async {
      await ctrl.setFullscreen(false);
      expect(ops.setFullScreenCalls, 0);
    });

    test('toggle switches between fullscreen and windowed', () async {
      await ctrl.toggle();
      expect(state.mode.value, WindowMode.fullscreen);
      await ctrl.toggle();
      expect(state.mode.value, WindowMode.windowed);
    });

    test('enter fullscreen calls setFullScreen(true)', () async {
      await ctrl.setFullscreen(true);
      expect(ops.setFullScreenCalls, 1);
      expect(ops.lastSetFullScreenValue, true);
    });

    test('exit fullscreen calls setFullScreen(false)', () async {
      await ctrl.setFullscreen(true);
      await ctrl.setFullscreen(false);
      expect(ops.setFullScreenCalls, 2);
      expect(ops.lastSetFullScreenValue, false);
    });

    test('exit fullscreen restores original position and size', () async {
      ops.position = const Offset(200, 150);
      ops.size = const Size(1000, 700);
      await ctrl.setFullscreen(true);
      // Simulate window moved/resized during fullscreen
      ops.position = const Offset(0, 0);
      ops.size = const Size(2560, 1440);
      await ctrl.setFullscreen(false);
      expect(ops.position, const Offset(200, 150));
      expect(ops.size, const Size(1000, 700));
      expect(ops.setPositionCalls, 1);
      expect(ops.setSizeCalls, 1);
    });

    test('rollback on enter failure restores windowed mode', () async {
      final failingOps = FailingWindowOps();
      final failCtrl = FullscreenController(
        state: state,
        ops: failingOps,
      );
      await failCtrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.windowed);
      expect(failCtrl.isAnimating, isFalse);
    });
  });
}
