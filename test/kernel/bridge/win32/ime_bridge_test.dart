import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/ime_bridge.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('Win32ImeBridge — hwnd 定位与关联逻辑', () {
    late int? foregroundHwnd;
    late String? foregroundClassName;
    late List<(int hwnd, int context, int flags)> associateExCalls;
    late List<(int hwnd, int context)> associateCalls;
    late int associateExResult;
    late int associateResult;

    Win32ImeFunctions fakeFns() => Win32ImeFunctions(
          foregroundWindow: () => foregroundHwnd ?? 0,
          windowClassNameMatches: (hwnd, expected) =>
              foregroundClassName == expected,
          associateContext: (hwnd, context) {
            associateCalls.add((hwnd, context));
            return associateResult;
          },
          associateContextEx: (hwnd, context, flags) {
            associateExCalls.add((hwnd, context, flags));
            return associateExResult;
          },
        );

    setUp(() {
      foregroundHwnd = 0x1234;
      foregroundClassName = 'FLUTTER_RUNNER_WIN32_WINDOW';
      associateExCalls = [];
      associateCalls = [];
      associateExResult = 1;
      associateResult = 1;
    });

    test('enable — 前台为 runner 窗口时走 ImmAssociateContextEx(IACE_DEFAULT)', () {
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.enable(), isTrue);
      expect(associateExCalls, hasLength(1));
      final (hwnd, context, flags) = associateExCalls.single;
      expect(hwnd, 0x1234);
      expect(context, 0);
      expect(flags, 0x0001, reason: 'IACE_DEFAULT — 恢复系统默认输入法上下文');
      expect(associateCalls, isEmpty);
    });

    test('disable — 走 ImmAssociateContext 解除上下文', () {
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.disable(), isTrue);
      expect(associateCalls, hasLength(1));
      final (hwnd, context) = associateCalls.single;
      expect(hwnd, 0x1234);
      expect(context, 0, reason: '解除 = 关联空上下文');
      expect(associateExCalls, isEmpty);
    });

    test('前台窗口类名不匹配 — 拒绝操作且不调用任何关联 API', () {
      foregroundClassName = 'OTHER_WINDOW';
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.enable(), isFalse);
      expect(bridge.disable(), isFalse);
      expect(associateExCalls, isEmpty);
      expect(associateCalls, isEmpty);
    });

    test('无前台窗口（句柄 0）— 拒绝操作', () {
      foregroundHwnd = null;
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.enable(), isFalse);
      expect(bridge.disable(), isFalse);
      expect(associateExCalls, isEmpty);
      expect(associateCalls, isEmpty);
    });

    test('API 返回 0 — 透传失败', () {
      associateExResult = 0;
      associateResult = 0;
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.enable(), isFalse);
      expect(bridge.disable(), isFalse);
    });
  });

  group('withImeRestored — 文件对话框期间的 IME 临时恢复', () {
    testWidgets('action 正常执行且返回值透传', (tester) async {
      // 测试进程无 runner 窗口 — enable 走"前台不匹配"失败分支,
      // 锁定「enable 失败时 action 仍执行」的降级语义.
      final result = await Win32ImeBridge.withImeRestored(() async => 42);

      expect(result, 42);
    });

    testWidgets('action 抛异常 — 原样传播不吞', (tester) async {
      await expectLater(
        Win32ImeBridge.withImeRestored(() async => throw StateError('boom')),
        throwsStateError,
      );
    });

    // 普通 test（非 testWidgets）— Future.delayed 需真实时钟推进.
    test('Future 延迟完成 — 等待 action 结束才返回', () async {
      var completed = false;
      final result = await Win32ImeBridge.withImeRestored(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        completed = true;
        return 'done';
      });

      expect(completed, isTrue);
      expect(result, 'done');
    });
  });
}
