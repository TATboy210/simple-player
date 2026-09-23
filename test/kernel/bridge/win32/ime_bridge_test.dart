import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/ime_bridge.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('Win32ImeBridge — 窗口定位与 WM_APP 消息投递', () {
    // 消息常量须与 runner 侧 ime_bridge_messages.h 对偶 — 双向锁定.
    const messageId = 0x8000 + 0x49; // WM_APP + 0x49
    const smtoAbortIfHung = 0x0002;

    late int? runnerHwnd;
    late bool sendResult;
    late List<({int hwnd, int message, int wparam, int flags, int timeoutMs})>
    sendCalls;

    Win32ImeFunctions fakeFns() => Win32ImeFunctions(
          findWindow: (className) {
            expect(
              className,
              'FLUTTER_RUNNER_WIN32_WINDOW',
              reason: '类名必须与 win32_window.cpp 的 kWindowClassName 对齐',
            );
            return runnerHwnd ?? 0;
          },
          sendMessageTimeout: (hwnd, message, wparam, flags, timeoutMs) {
            sendCalls.add(
              (
                hwnd: hwnd,
                message: message,
                wparam: wparam,
                flags: flags,
                timeoutMs: timeoutMs,
              ),
            );
            return sendResult;
          },
        );

    setUp(() {
      runnerHwnd = 0x1234;
      sendResult = true;
      sendCalls = [];
    });

    test('enable — 投递 WM_APP 消息且 wparam=1（恢复 IMC）', () {
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.enable(), isTrue);
      expect(sendCalls, hasLength(1));
      final call = sendCalls.single;
      expect(call.hwnd, 0x1234);
      expect(call.message, messageId, reason: '与 runner 侧 kAppSetImeEnabled 对偶');
      expect(call.wparam, 1, reason: 'runner 侧解读为 IACE_DEFAULT|IACE_CHILDREN');
      expect(call.flags, smtoAbortIfHung);
      expect(call.timeoutMs, 1000);
    });

    test('disable — 投递 WM_APP 消息且 wparam=0（解除 IMC）', () {
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.disable(), isTrue);
      expect(sendCalls, hasLength(1));
      expect(sendCalls.single.wparam, 0);
    });

    test('窗口定位失败（类名无匹配）— 拒绝操作且不投递消息', () {
      runnerHwnd = null;
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.enable(), isFalse);
      expect(bridge.disable(), isFalse);
      expect(sendCalls, isEmpty);
    });

    test('消息投递失败（超时/挂死）— 透传失败', () {
      sendResult = false;
      final bridge = Win32ImeBridge(functions: fakeFns());

      expect(bridge.enable(), isFalse);
      expect(bridge.disable(), isFalse);
    });
  });

  group('withImeRestored — 文件对话框期间的 IME 临时恢复', () {
    // 注入 fake — 测试进程若恰有真 runner 窗口在运行, 真实 FFI 会向其
    // 投递消息; 密闭 fake 保证单测零副作用.
    Win32ImeFunctions fakeFns({required bool findSucceeds, bool sendOk = true}) =>
        Win32ImeFunctions(
          findWindow: (_) => findSucceeds ? 0x42 : 0,
          sendMessageTimeout: (_, _, _, _, _) => sendOk,
        );

    testWidgets('action 正常执行且返回值透传', (tester) async {
      // enable 失败 — 锁定「enable 失败时 action 仍执行」的降级语义.
      final result = await Win32ImeBridge.withImeRestored(
        () async => 42,
        functions: fakeFns(findSucceeds: false),
      );

      expect(result, 42);
    });

    testWidgets('enable 成功 — action 结束后收尾 disable', (tester) async {
      final calls = <int>[];
      final result = await Win32ImeBridge.withImeRestored(
        () async => 'ok',
        functions: Win32ImeFunctions(
          findWindow: (_) => 0x42,
          sendMessageTimeout: (_, _, wparam, _, _) {
            calls.add(wparam);
            return true;
          },
        ),
      );

      expect(result, 'ok');
      expect(calls, [1, 0], reason: '先 enable(wparam=1) 后 disable(wparam=0)');
    });

    testWidgets('action 抛异常 — 原样传播不吞', (tester) async {
      await expectLater(
        Win32ImeBridge.withImeRestored(
          () async => throw StateError('boom'),
          functions: fakeFns(findSucceeds: false),
        ),
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
      }, functions: fakeFns(findSucceeds: false));

      expect(completed, isTrue);
      expect(result, 'done');
    });
  });
}
