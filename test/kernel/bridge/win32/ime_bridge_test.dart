import 'dart:io' show Platform;

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
        sendCalls.add((
          hwnd: hwnd,
          message: message,
          wparam: wparam,
          flags: flags,
          timeoutMs: timeoutMs,
        ));
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
      expect(
        call.message,
        messageId,
        reason: '与 runner 侧 kAppSetImeEnabled 对偶',
      );
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

  group('Win32ImeBridge — @Native assetId 解析失败降级 (261009-fio H1)', () {
    // @Native external 绑定首调才解析, 解析失败 (DLL/符号缺失) 抛
    // ArgumentError — Error 族, on Exception 捕获不到。fake 直接在 FFI 束
    // 边界抛 ArgumentError 模拟该环境性失败; 桥必须降级 false 而非穿透。
    test('enable — FindWindowW 绑定解析抛 ArgumentError — 降级 false 不抛', () {
      final bridge = Win32ImeBridge(
        functions: Win32ImeFunctions(
          findWindow: (_) => throw ArgumentError('user32 binding unavailable'),
          sendMessageTimeout: (_, _, _, _, _) => true,
        ),
      );

      expect(bridge.enable(), isFalse);
    });

    test('disable — FindWindowW 绑定解析抛 ArgumentError — 降级 false 不抛', () {
      final bridge = Win32ImeBridge(
        functions: Win32ImeFunctions(
          findWindow: (_) => throw ArgumentError('user32 binding unavailable'),
          sendMessageTimeout: (_, _, _, _, _) => true,
        ),
      );

      expect(bridge.disable(), isFalse);
    });

    test('enable — FindWindowW OK 但 SendMessageTimeoutW 解析抛 ArgumentError — 降级 false 不抛', () {
      final bridge = Win32ImeBridge(
        functions: Win32ImeFunctions(
          findWindow: (_) => 0x1234,
          sendMessageTimeout: (_, _, _, _, _) =>
              throw ArgumentError('send binding unavailable'),
        ),
      );

      expect(bridge.enable(), isFalse);
    });
  });

  // enable/disable 的临时恢复链路带 Platform.isWindows gate — 非 Windows
  // 透传路径的直调组 (上方 group) 全平台保留, 本组仅 Windows runner 执行.
  group('withImeRestored — 文件对话框期间的 IME 临时恢复', skip: !Platform.isWindows, () {
    // 注入 fake — 测试进程若恰有真 runner 窗口在运行, 真实 FFI 会向其
    // 投递消息; 密闭 fake 保证单测零副作用.
    Win32ImeFunctions fakeFns({
      required bool findSucceeds,
      bool sendOk = true,
    }) => Win32ImeFunctions(
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

    // 261009-fio H1: enable 的绑定解析失败 (ArgumentError, Error 族) 不得
    // 中断 action — 降级为「未恢复」, action 照跑且跳过收尾 disable.
    testWidgets('enable 抛 ArgumentError — action 仍执行一次且不收尾 disable', (
      tester,
    ) async {
      var actionCalls = 0;
      var sendCalls = 0;
      final result = await Win32ImeBridge.withImeRestored(
        () async {
          actionCalls++;
          return 'value';
        },
        functions: Win32ImeFunctions(
          findWindow: (_) => throw ArgumentError('user32 binding unavailable'),
          sendMessageTimeout: (_, _, _, _, _) {
            sendCalls++;
            return true;
          },
        ),
      );

      expect(result, 'value');
      expect(actionCalls, 1, reason: '绑定失败不得中断包裹的 action');
      expect(sendCalls, 0, reason: 'IME 从未恢复过, 不得投递收尾 disable');
    });

    // 261009-fio H1: 非对称 fake — enable 成功后 disable 阶段解析失败,
    // _deliver 的 Error 防御须兜住 finally 内的 disable, action 结果原样透传.
    testWidgets('enable 成功后 disable 抛 ArgumentError — action 结果仍透传', (
      tester,
    ) async {
      final wparams = <int>[];
      final result = await Win32ImeBridge.withImeRestored(
        () async => 'kept',
        functions: Win32ImeFunctions(
          findWindow: (_) => 0x42,
          sendMessageTimeout: (_, _, wparam, _, _) {
            wparams.add(wparam);
            if (wparam == 0) {
              throw ArgumentError('send binding unavailable');
            }
            return true;
          },
        ),
      );

      expect(result, 'kept');
      expect(wparams, [1, 0], reason: 'enable 正常投递, disable 触发解析失败降级');
    });
  });

  // 261009-roy S4/F17 — 未 init WR-02 探针防御: KernelLogger 未初始化且未
  // 注入 logger 时, 桥公开入口降级安全 no-op, 绝不让 KernelLogger.I 的
  // StateError 外溢（照 kernel_logger WR-02 先例 / media_kit_engine 与
  // keyboard_handler 的 isInitialized 探针同族）。
  group('Win32ImeBridge — 未 init WR-02 探针降级 (261009-roy S4/F17)', () {
    setUp(() {
      // 进入未 init 场景 — 现行为: 构造即抛 StateError → RED
      KernelLoggerImpl.resetForTesting();
    });

    tearDown(() {
      // 还原全局 init 态 — 文件级 setUpAll 只跑一次, 其余组依赖已 init 态
      KernelLoggerImpl.resetForTesting();
      KernelLoggerImpl.init();
    });

    test('未 init — enable 安全 false no-op, 不抛 StateError 且不触达 FFI', () {
      var ffiTouched = false;
      final bridge = Win32ImeBridge(
        functions: Win32ImeFunctions(
          findWindow: (_) {
            ffiTouched = true;
            return 0;
          },
          sendMessageTimeout: (_, _, _, _, _) {
            ffiTouched = true;
            return true;
          },
        ),
      );

      expect(bridge.enable(), isFalse);
      expect(ffiTouched, isFalse, reason: '未 init 安全 no-op, 不得触达 FFI');
    });

    test('未 init — disable 同样安全 false no-op', () {
      final bridge = Win32ImeBridge(
        functions: Win32ImeFunctions(
          findWindow: (_) => 0x1234,
          sendMessageTimeout: (_, _, _, _, _) => true,
        ),
      );

      expect(bridge.disable(), isFalse);
    });

    test('未 init — withImeRestored 直接透传 action 不抛（Windows）', () async {
      var actionCalls = 0;
      final result = await Win32ImeBridge.withImeRestored(() async {
        actionCalls++;
        return 'passthrough';
      },
      functions: Win32ImeFunctions(
        findWindow: (_) => 0x1234,
        sendMessageTimeout: (_, _, _, _, _) => true,
      ));

      expect(result, 'passthrough');
      expect(actionCalls, 1, reason: '未 init 降级为纯透传, action 照跑一次');
      // 非 Windows 由平台门先透传, 探针分支仅 Windows 可辨 — 与 group 3 同门
    }, skip: !Platform.isWindows ? '非 Windows 由平台门透传' : null);

    test('isInitialized 探针与 KernelLoggerImpl 初始态一致', () {
      expect(Win32ImeBridge.isInitialized, isFalse);
      KernelLoggerImpl.init();
      expect(Win32ImeBridge.isInitialized, isTrue);
    });
  });
}
