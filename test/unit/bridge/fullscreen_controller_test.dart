import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_controller.dart';
import 'package:simple_player_flutter/kernel/bridge/platform_fullscreen.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/bridge/window_state.dart';

/// 测试替身 — 模拟窗口操作，无需真实平台。
class FakeWindowOps implements WindowOps {
  bool isFullScreenValue = false;
  Offset position = const Offset(100, 100);
  Size size = const Size(1280, 720);

  int setPositionCalls = 0;
  int setSizeCalls = 0;

  @override
  Future<bool> isFullScreen() async => isFullScreenValue;

  @override
  Future<void> setFullScreen(bool value) async {
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

/// 平台全屏测试替身 — 可配置行为。
class FakePlatformFullscreen implements PlatformFullscreen {
  int enterCallCount = 0;
  int exitCallCount = 0;
  bool shouldThrowOnEnter = false;
  FullscreenSnapshot? lastExitSnapshot;

  @override
  bool get requiresStyleSave => true;

  @override
  Future<FullscreenSnapshot> enter() async {
    enterCallCount++;
    if (shouldThrowOnEnter) throw Exception('enter failed');
    return const FullscreenSnapshot(
      windowStyle: 0x00CF0000,
      position: Offset(100, 100),
      size: Size(1280, 720),
    );
  }

  @override
  void exit(FullscreenSnapshot snapshot) {
    exitCallCount++;
    lastExitSnapshot = snapshot;
  }
}

void main() {
  group('FullscreenController', () {
    late WindowState state;
    late FakeWindowOps ops;
    late FakePlatformFullscreen platform;
    late FullscreenController ctrl;

    setUp(() {
      state = WindowState();
      ops = FakeWindowOps();
      platform = FakePlatformFullscreen();
      ctrl = FullscreenController(state: state, platform: platform, ops: ops);
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
      expect(platform.enterCallCount, 0);
    });

    test('toggle switches between fullscreen and windowed', () async {
      await ctrl.toggle();
      expect(state.mode.value, WindowMode.fullscreen);
      expect(platform.enterCallCount, 1);
      await ctrl.toggle();
      expect(state.mode.value, WindowMode.windowed);
      expect(platform.exitCallCount, 1);
    });

    test('enter fullscreen calls platform.enter()', () async {
      await ctrl.setFullscreen(true);
      expect(platform.enterCallCount, 1);
    });

    test('exit fullscreen calls platform.exit() with snapshot', () async {
      await ctrl.setFullscreen(true);
      await ctrl.setFullscreen(false);
      expect(platform.exitCallCount, 1);
      expect(platform.lastExitSnapshot, isNotNull);
    });

    test('exit fullscreen restores original position and size via snapshot',
        () async {
      ops.position = const Offset(200, 150);
      ops.size = const Size(1000, 700);
      await ctrl.setFullscreen(true);
      await ctrl.setFullscreen(false);
      // 控制器保存的位置/大小通过 _buildExitSnapshot 合并到快照中
      expect(platform.lastExitSnapshot!.position, const Offset(200, 150));
      expect(platform.lastExitSnapshot!.size, const Size(1000, 700));
    });

    test('exit fullscreen restores previous maximized mode', () async {
      state.mode.value = WindowMode.maximized;
      await ctrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.fullscreen);
      await ctrl.setFullscreen(false);
      expect(state.mode.value, WindowMode.maximized);
    });

    test('rollback on enter failure restores windowed mode', () async {
      platform.shouldThrowOnEnter = true;
      final failCtrl = FullscreenController(
        state: state,
        platform: platform,
        ops: ops,
      );
      await failCtrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.windowed);
      expect(failCtrl.isAnimating, isFalse);
    });

    test('concurrent setFullscreen calls are blocked by mutex', () async {
      final first = ctrl.setFullscreen(true);
      await ctrl.setFullscreen(true); // 被 mutex 阻塞，应为 no-op
      await first;
      expect(platform.enterCallCount, 1);
    });

    test('no-op when entering fullscreen while already fullscreen', () async {
      await ctrl.setFullscreen(true);
      platform.enterCallCount = 0;
      await ctrl.setFullscreen(true); // 已经是 fullscreen，应 no-op
      expect(platform.enterCallCount, 0);
    });

    test('exit with no saved snapshot still sets windowed mode', () async {
      await ctrl.setFullscreen(false);
      expect(state.mode.value, WindowMode.windowed);
      expect(platform.exitCallCount, 0);
    });
  });
}
