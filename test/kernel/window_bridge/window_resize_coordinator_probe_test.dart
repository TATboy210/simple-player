import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/sizemove_bridge.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_resize_coordinator.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_service_state.dart';

/// SizemoveProbe fake — 记录查询次数与返回预设快照。
class FakeProbe implements SizemoveProbe {
  FakeProbe({this.snapshot, this.throwOnQuery = false});

  SizemoveSnapshot? snapshot;
  bool throwOnQuery;
  int queryCount = 0;

  @override
  SizemoveSnapshot? query() {
    queryCount++;
    if (throwOnQuery) throw Exception('probe boom');
    return snapshot;
  }
}

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('WindowResizeCoordinator — SizemoveProbe 取证接线', () {
    const debounce = Duration(milliseconds: 500);
    late WindowServiceState state;
    late List<Size> persistedSizes;
    int persistCalls = 0;

    WindowResizeCoordinator buildCoordinator({SizemoveProbe? probe}) =>
        WindowResizeCoordinator(
          state: state,
          readSize: () async => const Size(800, 600),
          persistSize: (size) async {
            persistCalls++;
            persistedSizes.add(size);
          },
          sizemoveProbe: probe,
        );

    setUp(() {
      state = WindowServiceState();
      persistedSizes = [];
      persistCalls = 0;
    });

    tearDown(() => state.dispose());

    testWidgets('probe 未接线 — settle 行为与旧版等价', (tester) async {
      final coordinator = buildCoordinator();

      coordinator.onResize();
      expect(state.isResizing.value, isTrue);
      expect(state.resizeSessionId.value, 1);

      await tester.pump(debounce);
      expect(state.isResizing.value, isFalse);
      expect(persistCalls, 1, reason: '防抖结束后照常持久化');
    });

    testWidgets('probe 接线 — 会话首查 + settle 关键点查，共 2 次', (
      tester,
    ) async {
      const snapshot = SizemoveSnapshot(isActive: true, enterTick: 0x1000);
      final probe = FakeProbe(snapshot: snapshot);
      final coordinator = buildCoordinator(probe: probe);

      coordinator.onResize();
      await tester.pump(debounce);

      expect(probe.queryCount, 2, reason: 'session-start 一次 + settle 一次');
      expect(state.isResizing.value, isFalse, reason: '纯观测 — 不改变 settle 行为');
      expect(persistCalls, 1);
    });

    testWidgets('同会话连续 onResize — 上升沿之外不再查询', (tester) async {
      final probe = FakeProbe(snapshot: const SizemoveSnapshot(isActive: true));
      final coordinator = buildCoordinator(probe: probe);

      coordinator.onResize();
      await tester.pump(const Duration(milliseconds: 100));
      coordinator.onResize();
      await tester.pump(const Duration(milliseconds: 100));
      coordinator.onResize();
      await tester.pump(debounce);

      expect(state.resizeSessionId.value, 1, reason: '同一拖拽会话');
      // 首事件 1 次 + 仅最后一次 debounce 到点的 settle 1 次 = 2 次。
      expect(probe.queryCount, 2);
    });

    testWidgets('probe 抛异常 — settle 正常完成不中断', (tester) async {
      final probe = FakeProbe(throwOnQuery: true);
      final coordinator = buildCoordinator(probe: probe);

      coordinator.onResize();
      await tester.pump(debounce);

      expect(state.isResizing.value, isFalse, reason: '取证查询失败不影响主流程');
      expect(persistCalls, 1);
    });

    testWidgets('probe 报告 settle 时原生仍在拖拽 — 行为仍按防抖收敛（纯观测锁定）', (
      tester,
    ) async {
      // 关键契约：当前阶段只取证不修复 — 即使原生模态循环仍在进行
      // （settle 误判场景），isResizing 也照常清除。修复 B（settle 重臂）
      // 须待实机证据裁决后另行实施。
      const snapshot = SizemoveSnapshot(isActive: true, exitLagMs: 0);
      final probe = FakeProbe(snapshot: snapshot);
      final coordinator = buildCoordinator(probe: probe);

      coordinator.onResize();
      await tester.pump(debounce);

      expect(state.isResizing.value, isFalse);
      expect(persistCalls, 1);
    });

    testWidgets('dispose 后 onResize — 不触发 probe 查询', (tester) async {
      final probe = FakeProbe(snapshot: const SizemoveSnapshot(isActive: true));
      final coordinator = buildCoordinator(probe: probe);

      coordinator.dispose();
      coordinator.onResize();
      await tester.pump(debounce);

      expect(probe.queryCount, 0);
      expect(state.isResizing.value, isFalse);
    });
  });
}
