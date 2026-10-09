import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/sizemove_bridge.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('SizemoveSnapshot.decode — runner 打包布局解码', () {
    test('active=true — bit0 置位', () {
      final snapshot = SizemoveSnapshot.decode(1);
      expect(snapshot.isActive, isTrue);
      expect(snapshot.exitLagMs, 0);
    });

    test('active=false + exitLagMs=500 — 拖拽已结束 500ms', () {
      final snapshot = SizemoveSnapshot.decode(500 << 1);
      expect(snapshot.isActive, isFalse);
      expect(snapshot.exitLagMs, 500);
    });

    test('enterTick 往返 — bits17-48 无损', () {
      const tick = 0x12345678;
      final raw = 1 | (0 << 1) | (tick << 17);
      final snapshot = SizemoveSnapshot.decode(raw);
      expect(snapshot.isActive, isTrue);
      expect(snapshot.enterTick, tick);
    });

    test('enterTick=0 — 解码为 null（本次运行从未进入过）', () {
      final snapshot = SizemoveSnapshot.decode(0);
      expect(snapshot.isActive, isFalse);
      expect(snapshot.exitLagMs, 0);
      expect(snapshot.enterTick, isNull);
    });

    test('exitLagMs 16 位掩码 — 高位不泄漏', () {
      // lag 0xFFFF 满档 + 高位垃圾位应被掩掉。
      final raw = (0x1FFFF << 1) | (0xABCD << 17);
      final snapshot = SizemoveSnapshot.decode(raw);
      expect(snapshot.exitLagMs, 0xFFFF);
      expect(snapshot.enterTick, 0xABCD);
    });
  });

  // Win32 查询路径入口有 Platform.isWindows gate (fake functions 绕不过
  // dart:io 的真实平台判定) — 仅 Windows runner 执行; decode group 为
  // 纯 Dart 布局解码, 全平台保留.
  group('Win32SizemoveBridge — WM_APP 查询消息投递', skip: !Platform.isWindows, () {
    // 消息常量须与 runner 侧 sizemove_bridge_messages.h 对偶 — 双向锁定.
    const messageId = 0x8000 + 0x4A; // WM_APP + 0x4A
    const smtoAbortIfHung = 0x0002;

    late int? runnerHwnd;
    late int? sendRawResult;
    late List<({int hwnd, int message, int wparam, int flags, int timeoutMs})>
    sendCalls;

    Win32SizemoveFunctions fakeFns() => Win32SizemoveFunctions(
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
        return sendRawResult;
      },
    );

    setUp(() {
      runnerHwnd = 0x1234;
      sendRawResult = 1;
      sendCalls = [];
    });

    test('query — 投递 WM_APP 查询消息且透传打包状态', () {
      // 模拟拖拽中：active=true + enterTick。
      sendRawResult = 1 | (0x1000 << 17);
      final bridge = Win32SizemoveBridge(functions: fakeFns());

      final snapshot = bridge.query();

      expect(snapshot, isNotNull);
      expect(snapshot!.isActive, isTrue);
      expect(snapshot.enterTick, 0x1000);
      expect(sendCalls, hasLength(1));
      final call = sendCalls.single;
      expect(call.hwnd, 0x1234);
      expect(
        call.message,
        messageId,
        reason: '与 runner 侧 kAppQuerySizemove 对偶',
      );
      expect(call.wparam, 0);
      expect(call.flags, smtoAbortIfHung);
      expect(call.timeoutMs, 1000);
    });

    test('handler 返回 0 — 合法状态（未进入过）而非投递失败', () {
      // 与 ime_bridge 的语义差异：打包状态 0 是合法快照，不能当失败。
      sendRawResult = 0;
      final bridge = Win32SizemoveBridge(functions: fakeFns());

      final snapshot = bridge.query();

      expect(snapshot, isNotNull);
      expect(snapshot!.isActive, isFalse);
      expect(snapshot.enterTick, isNull);
    });

    test('窗口定位失败 — 返回 null 且不投递消息', () {
      runnerHwnd = null;
      final bridge = Win32SizemoveBridge(functions: fakeFns());

      expect(bridge.query(), isNull);
      expect(sendCalls, isEmpty);
    });

    test('投递失败（超时/挂死）— 返回 null', () {
      sendRawResult = null;
      final bridge = Win32SizemoveBridge(functions: fakeFns());

      expect(bridge.query(), isNull);
    });

    // 261009-fio H1: @Native external 绑定首调才解析, 解析失败抛
    // ArgumentError — Error 族。SizemoveProbe 契约 (:84-90) 要求查询失败
    // 返回 null 不抛; fake 在 FFI 束边界抛 ArgumentError 锁定该降级。
    test('FindWindowW 绑定解析抛 ArgumentError — 降级 null 不抛', () {
      final bridge = Win32SizemoveBridge(
        functions: Win32SizemoveFunctions(
          findWindow: (_) => throw ArgumentError('user32 binding unavailable'),
          sendMessageTimeout: (_, _, _, _, _) => 1,
        ),
      );

      expect(bridge.query(), isNull);
    });

    test(
      'FindWindowW OK 但 SendMessageTimeoutW 解析抛 ArgumentError — 降级 null 不抛',
      () {
        final bridge = Win32SizemoveBridge(
          functions: Win32SizemoveFunctions(
            findWindow: (_) => 0x1234,
            sendMessageTimeout: (_, _, _, _, _) =>
                throw ArgumentError('send binding unavailable'),
          ),
        );

        expect(bridge.query(), isNull);
      },
    );
  });
}
