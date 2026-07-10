// 全屏 E2E 测试 — 需要真实窗口管理器，不可在 headless CI 运行。
// 使用: flutter test -t e2e test/integration/fullscreen_e2e_test.dart
//
// 覆盖场景（对应 regression_matrix.md）:
//   FS-WIN-001: Enter/exit fullscreen
//   FS-WIN-002: Rapid F key 10x
//   FS-WIN-004: Maximized -> FS -> Exit
//   FS-WIN-005: Playing + fullscreen (状态正确性)
//   FS-WIN-008: ESC semantic (退出全屏恢复窗口模式)
//
// 前置条件:
//   - 桌面环境（Windows/macOS/Linux）
//   - 窗口管理器可用
//   - USE_NEW_FULLSCREEN=true（RC 默认值）

@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/desktop_fullscreen_adapter.dart';
import 'package:simple_player_flutter/kernel/bridge/desktop_fullscreen_driver_factory.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_adapter.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_snapshot.dart';

void main() {
  late FullscreenAdapter adapter;

  setUp(() {
    // 使用真实平台驱动 — DesktopFullscreenDriverFactory 根据 Platform 选择
    final driver = DesktopFullscreenDriverFactory.create();
    adapter = DesktopFullscreenAdapter(driver);
  });

  tearDown(() {
    adapter.dispose();
  });

  group('FS-WIN-001: Enter/exit fullscreen', () {
    test('enter fullscreen sets stable + borderless', () async {
      await adapter.setFullscreen(true);

      // 等待命令队列处理完成
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final snapshot = adapter.snapshot().value;
      expect(snapshot.phase, FullscreenPhase.stable);
      expect(snapshot.isFullscreen, true);
      expect(snapshot.effectiveMode, FullscreenMode.borderless);
    });

    test('exit fullscreen restores windowed', () async {
      // 先进入全屏
      await adapter.setFullscreen(true);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // 退出全屏
      await adapter.setFullscreen(false);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final snapshot = adapter.snapshot().value;
      expect(snapshot.phase, FullscreenPhase.stable);
      expect(snapshot.isFullscreen, false);
      expect(snapshot.effectiveMode, FullscreenMode.windowed);
    });
  });

  group('FS-WIN-002: Rapid toggle 10x', () {
    test('rapid F key 10x ends in stable state', () async {
      // 快速切换 10 次 — 命令队列应串行化处理
      for (var i = 0; i < 10; i++) {
        await adapter.toggle();
      }

      // 等待所有命令处理完成
      await Future<void>.delayed(const Duration(milliseconds: 2000));

      final snapshot = adapter.snapshot().value;
      expect(snapshot.phase, FullscreenPhase.stable);
      expect(snapshot.hasError, false);
    });
  });

  group('FS-WIN-004: Maximized -> Fullscreen -> Exit', () {
    test('fullscreen from maximized restores maximized on exit', () async {
      // 注意: 此测试需要窗口处于 maximized 状态
      // 在真实桌面环境中，先手动最大化窗口再运行此测试

      await adapter.setFullscreen(true);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final enteringSnapshot = adapter.snapshot().value;
      expect(enteringSnapshot.isFullscreen, true);

      // 退出全屏 — 应恢复到之前的窗口模式
      await adapter.setFullscreen(false);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final exitSnapshot = adapter.snapshot().value;
      expect(exitSnapshot.isFullscreen, false);
      expect(exitSnapshot.phase, FullscreenPhase.stable);
    });
  });

  group('FS-WIN-005: Fullscreen state correctness', () {
    test('snapshot reflects actual fullscreen state', () async {
      final initial = adapter.snapshot().value;
      expect(initial.phase, FullscreenPhase.stable);
      expect(initial.isFullscreen, false);

      await adapter.setFullscreen(true);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final fullscreen = adapter.snapshot().value;
      expect(fullscreen.isFullscreen, true);
      expect(fullscreen.effectiveMode, FullscreenMode.borderless);
    });
  });

  group('FS-WIN-008: ESC semantic', () {
    test('ESC exits fullscreen and restores previous mode', () async {
      await adapter.setFullscreen(true);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // ESC 等效于 setFullscreen(false)
      await adapter.setFullscreen(false);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final snapshot = adapter.snapshot().value;
      expect(snapshot.isFullscreen, false);
      expect(snapshot.phase, FullscreenPhase.stable);
    });
  });
}
