/// 高风险回归测试套件 — 覆盖 D-35 高风险场景。
///
/// 测试目标:
/// - 快速连按 F 10/20 次不出现状态错位
/// - maximized -> fullscreen -> exit 恢复到 maximized
/// - StateDesync 后手动重试可恢复
/// - 回调缺失超时行为
/// - per-window 隔离（独立 adapter 互不污染）
///
/// 确认策略: 通过 Level-2 轮询确认（设置 driver.fullscreenState）。
/// 每次 toggle/setFullscreen 前翻转 driver 状态，轮询首次命中（~100ms 延迟）。
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/desktop_fullscreen_adapter.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_capability.dart';

// ─── 测试替身 ───

/// Mock FullscreenDriver — 记录调用参数，可控返回值和失败注入。
class _MockFullscreenDriver implements FullscreenDriver {
  final List<String> calls = [];

  bool fullscreenState = false;
  bool minimizedState = false;
  bool maximizedState = false;
  Offset currentPosition = const Offset(100, 100);
  Size currentSize = const Size(1280, 720);

  Exception? throwOnEnter;
  bool shouldDelayEnter = false;

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    calls.add('enterFullscreen(displayId: $displayId)');
    if (throwOnEnter != null) throw throwOnEnter!;
    if (shouldDelayEnter) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Future<void> leaveFullscreen() async {
    calls.add('leaveFullscreen()');
  }

  @override
  Future<bool> queryFullscreen() async {
    calls.add('queryFullscreen()');
    return fullscreenState;
  }

  @override
  Future<Offset> getPosition() async {
    calls.add('getPosition()');
    return currentPosition;
  }

  @override
  Future<Size> getSize() async {
    calls.add('getSize()');
    return currentSize;
  }

  @override
  Future<void> setBounds(Offset? position, Size? size) async {
    calls.add('setBounds($position, $size)');
    if (position != null) currentPosition = position;
    if (size != null) currentSize = size;
  }

  @override
  Future<void> maximize() async {
    calls.add('maximize()');
    maximizedState = true;
  }

  @override
  Future<void> restore() async {
    calls.add('restore()');
    minimizedState = false;
    maximizedState = false;
  }

  @override
  Future<void> focus() async {
    calls.add('focus()');
  }

  @override
  Future<bool> isMaximized() async {
    calls.add('isMaximized()');
    return maximizedState;
  }

  @override
  Future<bool> isMinimized() async {
    calls.add('isMinimized()');
    return minimizedState;
  }

  @override
  Future<({bool isMaximized, Offset position, Size size})> captureSnapshot() async {
    calls.add('captureSnapshot()');
    return (isMaximized: maximizedState, position: currentPosition, size: currentSize);
  }

  @override
  void clearMonitorCache() {}

  @override
  void dispose() {}

  @override
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {
    // 空实现 — 测试通过 Level-2 轮询确认
  }

  @override
  FullscreenCapability capabilities() {
    return const FullscreenCapability();
  }

  @override
  bool get supportsFastPath => false;

  @override
  bool get supportsBatchSnapshot => false;

  @override
  Future<void> enterFullscreenFast({int displayId = 0}) async {
    calls.add('enterFullscreenFast(displayId: $displayId)');
  }

  @override
  Future<void> leaveFullscreenFast() async {
    calls.add('leaveFullscreenFast()');
  }
}

// ─── 高风险测试 ───

void main() {
  group('High Risk Suite', () {
    late _MockFullscreenDriver driver;
    late DesktopFullscreenAdapter adapter;

    setUp(() {
      driver = _MockFullscreenDriver();
      adapter = DesktopFullscreenAdapter(driver);
    });

    tearDown(() {
      adapter.dispose();
    });

    // HR-001: 快速连按 F 10 次 — 验证最终状态正确
    // 每次 toggle 前翻转 driver 状态，Level-2 轮询首次命中
    test('rapid toggle 10 times ends in correct state', () async {
      for (var i = 0; i < 10; i++) {
        driver.fullscreenState = !driver.fullscreenState;
        await adapter.toggle();
      }

      // 10 次 toggle（偶数）从 windowed 开始 → 最终 windowed
      expect(adapter.isFullscreen.value, isFalse);
    });

    // HR-002: 快速连按 F 20 次 — 验证命令队列不崩溃
    // 每次 toggle 耗时 ~600ms（500ms Level-1 超时 + 100ms 首次轮询），总计 ~12s
    test(
      'rapid toggle 20 times does not crash',
      () async {
        for (var i = 0; i < 20; i++) {
          driver.fullscreenState = !driver.fullscreenState;
          await adapter.toggle();
        }

        // 20 次 toggle（偶数）后应恢复到稳定状态
        expect(adapter.isFullscreen.value, isFalse);
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    // HR-003: maximized -> fullscreen -> exit 恢复到 maximized
    test('maximized -> fullscreen -> exit restores maximized', () async {
      // 先设为 maximized 状态
      driver.maximizedState = true;

      // 进入全屏
      driver.fullscreenState = true;
      await adapter.setFullscreen(true);
      expect(adapter.isFullscreen.value, isTrue);

      // 退出全屏，应恢复到 maximized
      driver.fullscreenState = false;
      await adapter.setFullscreen(false);
      expect(adapter.isFullscreen.value, isFalse);

      // 验证调用了 maximize() 恢复
      expect(driver.calls, contains('maximize()'));
    });

    // HR-004: StateDesync 后手动重试可恢复
    // 模拟：enter 失败 → error 状态 → 重试 enter 成功
    test('StateDesync recovery: fail then retry succeeds', () async {
      // 第一次 enter 失败（模拟平台异常）
      driver.throwOnEnter = Exception('platform failure');
      await adapter.setFullscreen(true);
      // 失败后 isFullscreen 应为 false
      expect(adapter.isFullscreen.value, isFalse);

      // 修复平台，重试 enter
      driver.throwOnEnter = null;
      driver.fullscreenState = true;
      await adapter.setFullscreen(true);
      expect(adapter.isFullscreen.value, isTrue);
    });

    // HR-005: 回调缺失超时 — 平台 enter 延迟但 Level-2 轮询成功
    // driver 操作有 200ms 延迟，但 Level-2 轮询在 500ms 后开始
    // 在延迟期间设置 driver 状态 → 轮询首次命中
    test('delayed driver enter + polling confirmation succeeds', () async {
      driver.shouldDelayEnter = true;

      // scheduleMicrotask 在 adapter 内部第一个 await 时触发（isMinimized 检查）
      // 此时设置 driver 状态 → 200ms 后 driver 完成 → 500ms 后轮询开始 → 首次命中
      scheduleMicrotask(() {
        driver.fullscreenState = true;
      });

      await adapter.setFullscreen(true);
      expect(adapter.isFullscreen.value, isTrue);
    });

    // HR-006: per-window 隔离 — 两个独立 adapter 互不污染
    test('per-window isolation: two adapters do not interfere', () async {
      final driver1 = _MockFullscreenDriver();
      final driver2 = _MockFullscreenDriver();
      final adapter1 = DesktopFullscreenAdapter(driver1);
      final adapter2 = DesktopFullscreenAdapter(driver2);

      try {
        // adapter1 进入全屏
        driver1.fullscreenState = true;
        await adapter1.setFullscreen(true);
        expect(adapter1.isFullscreen.value, isTrue);
        // adapter2 应保持 windowed
        expect(adapter2.isFullscreen.value, isFalse);

        // adapter2 进入全屏
        driver2.fullscreenState = true;
        await adapter2.setFullscreen(true);
        expect(adapter2.isFullscreen.value, isTrue);
        // adapter1 仍为 fullscreen
        expect(adapter1.isFullscreen.value, isTrue);

        // adapter1 退出全屏
        driver1.fullscreenState = false;
        await adapter1.setFullscreen(false);
        expect(adapter1.isFullscreen.value, isFalse);
        // adapter2 仍为 fullscreen
        expect(adapter2.isFullscreen.value, isTrue);

        // adapter2 退出全屏
        driver2.fullscreenState = false;
        await adapter2.setFullscreen(false);
        expect(adapter2.isFullscreen.value, isFalse);
      } finally {
        adapter1.dispose();
        adapter2.dispose();
      }
    });
  });
}
