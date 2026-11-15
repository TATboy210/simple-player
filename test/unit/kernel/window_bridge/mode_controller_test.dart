import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/service/mode_controller.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';

import '../../../helpers/fake_native_window.dart';

/// 窗口模式控制（契约 4）的行为锁定：
/// 「意图立即提交，原生状态在下一几何边沿现查校准」。
void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeNativeWindow window;
  late ModeController controller;

  setUp(() {
    window = FakeNativeWindow();
    controller = ModeController(
      mode: ValueNotifier(WindowMode.windowed),
      window: () => window,
    );
  });

  group('ModeController.setMode', () {
    test('windowed → maximize：意图提交 + 原生命令下发', () async {
      await controller.setMode(WindowMode.maximized);
      expect(controller.mode.value, WindowMode.maximized);
      expect(window.calls, contains('maximize'));
      expect(window.isMaximized, isTrue);
    });

    test('同模式重复提交是 no-op — 不重复下发原生命令', () async {
      await controller.setMode(WindowMode.windowed);
      expect(window.calls, isEmpty);
    });

    test('fullscreen：意图先置 + 模式先写，再执行原生全屏（同步落定）',
        () async {
      await controller.setMode(WindowMode.fullscreen);
      expect(controller.fullscreenIntent, isTrue);
      expect(controller.mode.value, WindowMode.fullscreen);
      expect(window.calls, ['fullScreen=true']);
      expect(window.isFullScreen, isTrue);
    });

    test('fullscreen 中重复进入全屏是 no-op', () async {
      await controller.setMode(WindowMode.fullscreen);
      window.calls.clear();
      await controller.setMode(WindowMode.fullscreen);
      expect(window.calls, isEmpty);
    });

    test('退出全屏到 windowed：先写意图 false，再关原生全屏', () async {
      await controller.setMode(WindowMode.fullscreen);
      window.calls.clear();
      await controller.setMode(WindowMode.windowed);
      expect(controller.fullscreenIntent, isFalse);
      expect(controller.mode.value, WindowMode.windowed);
      expect(window.calls, ['fullScreen=false']);
    });

    test('退出全屏到 windowed 但宿主实际是最大化 — 落回 maximized', () async {
      await controller.setMode(WindowMode.fullscreen);
      // 原生在进入前是最大化：退出全屏后宿主恢复最大化形态。
      window.maximized = true;
      await controller.setMode(WindowMode.windowed);
      expect(controller.mode.value, WindowMode.maximized);
    });

    test('maximize → unmaximize：命令即返，模式意图值立即更新', () async {
      await controller.setMode(WindowMode.maximized);
      window.calls.clear();
      await controller.setMode(WindowMode.windowed);
      expect(controller.mode.value, WindowMode.windowed);
      expect(window.calls, ['unmaximize']);
    });

    test('窗口未绑定（init 前降级）— setMode 静默无效，不抛', () async {
      final detached = ModeController(
        mode: ValueNotifier(WindowMode.windowed),
        window: () => null,
      );
      await detached.setMode(WindowMode.maximized);
      expect(detached.mode.value, WindowMode.windowed);
      expect(detached.fullscreenIntent, isFalse);
    });
  });

  group('ModeController.syncFromNative（几何边沿现查校准）', () {
    test('引擎指标说最大化 → 校准为 maximized', () {
      window.completeMaximize();
      controller.syncFromNative(revealed: true);
      expect(controller.mode.value, WindowMode.maximized);
    });

    test('引擎指标说 windowed → 校准为 windowed', () async {
      await controller.setMode(WindowMode.maximized);
      window.completeUnmaximize();
      controller.syncFromNative(revealed: true);
      expect(controller.mode.value, WindowMode.windowed);
    });

    test('外部改动（Win+↑/Snap）在下一个几何边沿被校准', () async {
      // 用户经系统快捷键最大化 — Dart 侧只有模式意图是 windowed。
      expect(controller.mode.value, WindowMode.windowed);
      window.completeMaximize(); // 原生形态已变，无命令发出
      expect(window.calls, isNot(contains('maximize')));
      controller.syncFromNative(revealed: true);
      expect(controller.mode.value, WindowMode.maximized);
    });

    test('全屏意图期间校准让位 — 原生中间态不把 fullscreen 冲成 windowed',
        () async {
      await controller.setMode(WindowMode.fullscreen);
      // 全屏的原生形态不是最大化：现查 isMaximized=false，但意图让位。
      window.maximized = false;
      controller.syncFromNative(revealed: true);
      expect(controller.mode.value, WindowMode.fullscreen);
      expect(controller.fullscreenIntent, isTrue);
    });

    test('reveal 前不校准（隐藏态几何恢复引发的边沿）', () {
      window.completeMaximize();
      controller.syncFromNative(revealed: false);
      expect(controller.mode.value, WindowMode.windowed);
    });

    test('窗口未绑定 — 静默返回', () {
      final detached = ModeController(
        mode: ValueNotifier(WindowMode.windowed),
        window: () => null,
      );
      detached.syncFromNative(revealed: true);
      expect(detached.mode.value, WindowMode.windowed);
    });
  });
}
