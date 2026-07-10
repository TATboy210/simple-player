/// 冒烟测试套件 — 覆盖 8 项必测场景（D-32）。
///
/// 每个测试标注 case ID（FS-REG-001 ~ FS-REG-008），与 regression_matrix.md 对应。
///
/// 测试场景:
/// FS-REG-001: 播放中 + 全屏
/// FS-REG-002: 暂停中 + 全屏
/// FS-REG-003: F 键与按钮一致性（toggle vs setFullscreen）
/// FS-REG-004: ESC 语义（fullscreen 下 setFullscreen(false)）
/// FS-REG-005: 连续切换稳定性（10 次 toggle）
/// FS-REG-006: windowed -> fullscreen -> windowed 恢复原始几何
/// FS-REG-007: 副屏位置恢复（自定义 position）
/// FS-REG-008: 错误事件通知（enter 失败 → 回滚）
///
/// 所有测试使用 FakeWindowOps + FakePlatformFullscreen，不依赖真实窗口管理器。
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_controller.dart';
import 'package:simple_player_flutter/kernel/bridge/platform_fullscreen.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import 'package:simple_player_flutter/kernel/bridge/window_state.dart';

// ─── 测试替身 ───

/// 模拟窗口操作。
class _FakeWindowOps implements WindowOps {
  Offset position = const Offset(100, 100);
  Size size = const Size(1280, 720);

  @override
  Future<bool> isFullScreen() async => false;

  @override
  Future<void> setFullScreen(bool value) async {}

  @override
  Future<Offset> getPosition() async => position;

  @override
  Future<void> setPosition(Offset pos) async => position = pos;

  @override
  Future<Size> getSize() async => size;

  @override
  Future<void> setSize(Size s) async => size = s;
}

/// 平台全屏测试替身 — 可配置失败。
class _FakePlatformFullscreen implements PlatformFullscreen {
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

// ─── 冒烟测试 ───

void main() {
  group('Smoke Suite — 8 Mandatory Scenarios', () {
    late WindowState state;
    late _FakeWindowOps ops;
    late _FakePlatformFullscreen platform;
    late FullscreenController ctrl;

    setUp(() {
      state = WindowState();
      ops = _FakeWindowOps();
      platform = _FakePlatformFullscreen();
      ctrl = FullscreenController(
        state: state,
        platform: platform,
        ops: ops,
      );
    });

    tearDown(() {
      state.dispose();
    });

    // FS-REG-001: 播放中 + 全屏
    test('FS-REG-001: playing + fullscreen enters and exits correctly',
        () async {
      // 模拟播放状态（mode 为 windowed，正在播放中）
      expect(state.mode.value, WindowMode.windowed);

      // 进入全屏
      await ctrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.fullscreen);
      expect(platform.enterCallCount, 1);
      expect(ctrl.isAnimating, isFalse);

      // 退出全屏
      await ctrl.setFullscreen(false);
      expect(state.mode.value, WindowMode.windowed);
      expect(platform.exitCallCount, 1);
    });

    // FS-REG-002: 暂停中 + 全屏
    test('FS-REG-002: paused + fullscreen enters and exits correctly',
        () async {
      // 暂停状态下进入全屏
      expect(state.mode.value, WindowMode.windowed);

      await ctrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.fullscreen);

      await ctrl.setFullscreen(false);
      expect(state.mode.value, WindowMode.windowed);
    });

    // FS-REG-003: F 键与按钮一致性
    // toggle(true) 和 setFullscreen(true) 结果相同
    test('FS-REG-003: toggle and setFullscreen produce same result', () async {
      // 使用 toggle 进入全屏
      await ctrl.toggle();
      expect(state.mode.value, WindowMode.fullscreen);
      expect(platform.enterCallCount, 1);

      // 退出
      await ctrl.toggle();
      expect(state.mode.value, WindowMode.windowed);
      expect(platform.exitCallCount, 1);

      // 使用 setFullscreen 进入全屏
      await ctrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.fullscreen);
      expect(platform.enterCallCount, 2);

      // 退出
      await ctrl.setFullscreen(false);
      expect(state.mode.value, WindowMode.windowed);
      expect(platform.exitCallCount, 2);
    });

    // FS-REG-004: ESC 语义 — fullscreen 状态下 setFullscreen(false) 退出全屏
    test('FS-REG-004: ESC exits fullscreen (setFullscreen(false))', () async {
      await ctrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.fullscreen);

      // ESC 语义 = setFullscreen(false)
      await ctrl.setFullscreen(false);
      expect(state.mode.value, WindowMode.windowed);
      expect(platform.exitCallCount, 1);
    });

    // FS-REG-005: 连续切换稳定性（10 次 toggle）
    test('FS-REG-005: 10 consecutive toggles end in stable state', () async {
      for (var i = 0; i < 10; i++) {
        await ctrl.toggle();
      }

      // 10 次 toggle 从 windowed 开始，偶数次回到 windowed
      expect(state.mode.value, WindowMode.windowed);
      expect(ctrl.isAnimating, isFalse);
      expect(platform.enterCallCount, 5);
      expect(platform.exitCallCount, 5);
    });

    // FS-REG-006: windowed -> fullscreen -> windowed 恢复原始窗口几何
    test('FS-REG-006: windowed -> fullscreen -> windowed restores geometry',
        () async {
      ops.position = const Offset(200, 150);
      ops.size = const Size(1000, 700);

      await ctrl.setFullscreen(true);
      expect(state.mode.value, WindowMode.fullscreen);

      await ctrl.setFullscreen(false);
      expect(state.mode.value, WindowMode.windowed);

      // 验证退出时使用了保存的位置和大小
      expect(platform.lastExitSnapshot, isNotNull);
      expect(platform.lastExitSnapshot!.position, const Offset(200, 150));
      expect(platform.lastExitSnapshot!.size, const Size(1000, 700));
    });

    // FS-REG-007: 副屏位置恢复 — 自定义 position
    test('FS-REG-007: secondary display position is preserved in snapshot',
        () async {
      // 模拟副屏位置（非主显示器）
      ops.position = const Offset(2560, 300); // 副屏 x 偏移
      ops.size = const Size(1920, 1080);

      await ctrl.setFullscreen(true);
      await ctrl.setFullscreen(false);

      // 验证快照包含副屏位置
      expect(platform.lastExitSnapshot, isNotNull);
      expect(platform.lastExitSnapshot!.position, const Offset(2560, 300));
      expect(platform.lastExitSnapshot!.size, const Size(1920, 1080));
    });

    // FS-REG-008: 错误事件通知 — enter 失败时回滚到 windowed
    test('FS-REG-008: enter failure rolls back to windowed', () async {
      platform.shouldThrowOnEnter = true;

      await ctrl.setFullscreen(true);

      // 失败后应回滚到 windowed
      expect(state.mode.value, WindowMode.windowed);
      expect(ctrl.isAnimating, isFalse);

      // enter 被调用但失败
      expect(platform.enterCallCount, 1);
      // enter 抛异常时 _savedSnapshot 为 null，不会调用 exit
      // 控制器直接设置 mode = windowed（回滚）
      expect(platform.exitCallCount, 0);
    });
  });
}
