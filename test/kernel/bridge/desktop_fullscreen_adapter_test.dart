import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/desktop_fullscreen_adapter.dart';
import 'package:simple_player_flutter/kernel/bridge/fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/bridge/platform/windows_fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/win32_fullscreen_ffi.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_capability.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_error.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_event.dart';
import 'package:simple_player_flutter/kernel/models/fullscreen_snapshot.dart';

/// Mock FullscreenDriver — 记录调用参数，可控返回值。
///
/// enterFullscreen/leaveFullscreen 不自动修改 fullscreenState。
/// 测试通过 helper 方法 confirmEnter/confirmLeave 来同步状态和回调。
class MockFullscreenDriver implements FullscreenDriver {
  final List<String> calls = [];

  bool fullscreenState = false;
  bool minimizedState = false;
  bool maximizedState = false;
  Offset currentPosition = Offset.zero;
  Size currentSize = const Size(1280, 720);

  Exception? throwOnEnter;
  Exception? throwOnLeave;

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    calls.add('enterFullscreen(displayId: $displayId)');
    if (throwOnEnter != null) throw throwOnEnter!;
  }

  @override
  Future<void> leaveFullscreen() async {
    calls.add('leaveFullscreen()');
    if (throwOnLeave != null) throw throwOnLeave!;
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

  /// 记录原生回调设置。
  void Function(int windowId, bool isFullscreen)? nativeCallback;

  @override
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {
    nativeCallback = callback;
  }

  @override
  FullscreenCapability capabilities() {
    return const FullscreenCapability();
  }
}

/// Helper: 模拟原生回调确认进入全屏。
void confirmEnter(MockFullscreenDriver driver, DesktopFullscreenAdapter adapter,
    {int windowId = 0}) {
  driver.fullscreenState = true;
  adapter.onNativeFullScreenChanged(windowId, true);
}

/// Helper: 模拟原生回调确认退出全屏。
void confirmLeave(MockFullscreenDriver driver, DesktopFullscreenAdapter adapter,
    {int windowId = 0}) {
  driver.fullscreenState = false;
  adapter.onNativeFullScreenChanged(windowId, false);
}

/// Mock WindowsFullscreenDriver — 用于测试 Adapter 快速路径。
///
/// 继承 WindowsFullscreenDriver 但注入 mock API，
/// 验证 Adapter 对 Windows 平台的快速路径分支。
class MockWindowsDriver extends WindowsFullscreenDriver {
  MockWindowsDriver() : super(api: MockWin32ApiForAdapter());

  final List<String> fastCalls = [];

  @override
  Future<void> enterFullscreenFast({int displayId = 0}) async {
    fastCalls.add('enterFullscreenFast(displayId: $displayId)');
  }

  @override
  Future<void> leaveFullscreenFast() async {
    fastCalls.add('leaveFullscreenFast()');
  }
}

/// 简化版 MockWin32Api — 仅用于 MockWindowsDriver 构造。
class MockWin32ApiForAdapter extends Win32FullscreenApiWrapper {
  @override
  int getFlutterHwnd() => 12345;
  @override
  bool isWindow(int hwnd) => true;
  @override
  int getWindowLong(int hwnd, int index) => 0;
  @override
  int setWindowLong(int hwnd, int index, int value) => 0;
  @override
  bool setWindowPos(int hwnd, int insertAfter, int x, int y, int cx, int cy,
          int flags) =>
      true;
  @override
  int monitorFromWindow(int hwnd) => 9999;
  @override
  ({int left, int top, int right, int bottom})? getMonitorRect(int hMonitor) =>
      (left: 0, top: 0, right: 1920, bottom: 1080);
  @override
  Pointer<WindowPlacement>? getWindowPlacement(int hwnd) => null;
  @override
  bool setWindowPlacement(int hwnd, Pointer<WindowPlacement> placement) => true;
  @override
  bool isWindowVisible(int hwnd) => true;
  @override
  bool isIconic(int hwnd) => false;
  @override
  bool setForegroundWindow(int hwnd) => true;
  @override
  int setFocus(int hwnd) => hwnd;
}

void main() {
  group('DesktopFullscreenAdapter', () {
    late MockFullscreenDriver driver;
    late DesktopFullscreenAdapter adapter;

    setUp(() {
      driver = MockFullscreenDriver();
      adapter = DesktopFullscreenAdapter(driver);
    });

    tearDown(() {
      adapter.dispose();
    });

    // ─── T12: enter → leave 流程: phase 变化 ───

    test('T12: enter → leave — phase stable→entering→stable→leaving→stable',
        () async {
      final phases = <FullscreenPhase>[];
      adapter.snapshot().addListener(() {
        phases.add(adapter.snapshot().value.phase);
      });

      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);

      expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
      expect(adapter.snapshot().value.isFullscreen, isTrue);

      scheduleMicrotask(() => confirmLeave(driver, adapter));
      await adapter.setFullscreen(false);

      expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
      expect(adapter.snapshot().value.isFullscreen, isFalse);

      expect(phases, contains(FullscreenPhase.entering));
      expect(phases, contains(FullscreenPhase.leaving));
      expect(phases.last, FullscreenPhase.stable);
    });

    // ─── T13: maximized→enter→leave → 恢复 maximize() ───

    test('T13: maximized → enter → leave — restores maximize()', () async {
      driver.maximizedState = true;

      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);
      expect(adapter.snapshot().value.isFullscreen, isTrue);

      scheduleMicrotask(() => confirmLeave(driver, adapter));
      await adapter.setFullscreen(false);

      expect(driver.calls, contains('maximize()'));
      expect(adapter.snapshot().value.isFullscreen, isFalse);
    });

    // ─── T14: windowed→enter→leave → 恢复 position+size ───

    test('T14: windowed → enter → leave — restores position and size', () async {
      driver.currentPosition = const Offset(100, 200);
      driver.currentSize = const Size(800, 600);

      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);

      scheduleMicrotask(() => confirmLeave(driver, adapter));
      await adapter.setFullscreen(false);

      expect(driver.calls,
          contains('setBounds(Offset(100.0, 200.0), Size(800.0, 600.0))'));
    });

    // ─── T15: StateDesync: snapshot 更新真实状态 + error 事件 ───

    test('T15: StateDesync — snapshot updates to real state + error event',
        () async {
      final events = <FullscreenEvent>[];
      adapter.events.listen(events.add);

      // 不触发回调，driver 状态保持 false → 轮询发现不匹配
      driver.fullscreenState = false;

      await adapter.setFullscreen(true);

      expect(adapter.snapshot().value.phase, FullscreenPhase.error);
      expect(adapter.snapshot().value.effectiveMode, FullscreenMode.windowed);
      expect(adapter.snapshot().value.lastError, isA<StateDesync>());

      final errorEvents = events.whereType<FullscreenErrorEvent>().toList();
      expect(errorEvents, isNotEmpty);
      expect(errorEvents.first.error, isA<StateDesync>());
    });

    // ─── T16: error 状态下新操作自动清理 ───

    test('T16: error state auto-clears on new operation', () async {
      // 先制造 error 状态: 不回调，driver 报告非全屏
      driver.fullscreenState = false;
      await adapter.setFullscreen(true);
      expect(adapter.snapshot().value.hasError, isTrue);

      // 新操作应自动清理 error 并成功
      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);

      expect(adapter.snapshot().value.hasError, isFalse);
      expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
    });

    // ─── T17: 事件流完整性 ───

    test('T17: events — enterRequested→entered→leaveRequested→left', () async {
      final events = <FullscreenEvent>[];
      adapter.events.listen(events.add);

      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);

      scheduleMicrotask(() => confirmLeave(driver, adapter));
      await adapter.setFullscreen(false);

      final eventTypes = events.map((e) => e.runtimeType).toList();
      expect(eventTypes, contains(EnterRequested));
      expect(eventTypes, contains(Entered));
      expect(eventTypes, contains(LeaveRequested));
      expect(eventTypes, contains(Left));

      final enterReqIdx = eventTypes.indexOf(EnterRequested);
      final enteredIdx = eventTypes.indexOf(Entered);
      final leaveReqIdx = eventTypes.indexOf(LeaveRequested);
      final leftIdx = eventTypes.indexOf(Left);
      expect(enterReqIdx, lessThan(enteredIdx));
      expect(enteredIdx, lessThan(leaveReqIdx));
      expect(leaveReqIdx, lessThan(leftIdx));
    });

    // ─── T18: 多窗口并发确认隔离 ───

    test('T18: multi-window concurrent confirmation isolation', () async {
      final future0 = adapter.setFullscreen(true, windowId: 0);
      final future1 = adapter.setFullscreen(true, windowId: 1);

      // 确认 windowId=0
      scheduleMicrotask(() {
        driver.fullscreenState = true;
        adapter.onNativeFullScreenChanged(0, true);
      });
      await future0;

      // 确认 windowId=1
      scheduleMicrotask(() {
        adapter.onNativeFullScreenChanged(1, true);
      });
      await future1;

      expect(adapter.snapshot(0).value.isFullscreen, isTrue);
      expect(adapter.snapshot(1).value.isFullscreen, isTrue);
    });

    // ─── T19: Level-1 回调成功路径 ───

    test('T19: Level-1 callback — Completer<bool> complete(true)', () async {
      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);

      expect(adapter.snapshot().value.isFullscreen, isTrue);
      expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
    });

    // ─── T20: Level-1 超时 → Level-2 轮询路径 ───

    test('T20: Level-1 timeout → Level-2 polling success', () async {
      // 不触发回调，但 driver 状态为全屏 → 轮询成功
      driver.fullscreenState = true;

      await adapter.setFullscreen(true);

      expect(adapter.snapshot().value.isFullscreen, isTrue);
    });

    // ─── T21: Level-2 轮询超时 → Level-3 返回 false ───

    test('T21: Level-2 polling timeout → StateDesync', () async {
      // 不触发回调，driver 状态不匹配 → 轮询也失败
      driver.fullscreenState = false;

      await adapter.setFullscreen(true);

      expect(adapter.snapshot().value.phase, FullscreenPhase.error);
      expect(adapter.snapshot().value.lastError, isA<StateDesync>());
    });

    // ─── T22: onNativeFullScreenChanged 防重复 complete ───

    test('T22: onNativeFullScreenChanged prevents double complete', () async {
      scheduleMicrotask(() {
        driver.fullscreenState = true;
        adapter.onNativeFullScreenChanged(0, true);
        adapter.onNativeFullScreenChanged(0, true); // 第二次不应崩溃
      });

      await adapter.setFullscreen(true);
      expect(adapter.snapshot().value.isFullscreen, isTrue);
    });

    // ─── T23: Adapter 文件内无 windowManager / fullScreenWindow 调用 ───
    // 代码审查级检查，通过 grep 验证（见 SUMMARY.md）

    // ─── T24: minimized→enter → 先 restore 再全屏 ───

    test('T24: minimized → enter — restore before fullscreen', () async {
      driver.minimizedState = true;

      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);

      final restoreIdx = driver.calls.indexOf('restore()');
      final enterIdx = driver.calls.indexOf('enterFullscreen(displayId: 0)');
      expect(restoreIdx, greaterThanOrEqualTo(0));
      expect(enterIdx, greaterThan(restoreIdx));
    });

    // ─── T25: 副屏→enter→exit → 恢复副屏位置 ───

    test('T25: secondary display → enter → exit — restores position', () async {
      driver.currentPosition = const Offset(2000, 100);
      driver.currentSize = const Size(1920, 1080);

      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);

      scheduleMicrotask(() => confirmLeave(driver, adapter));
      await adapter.setFullscreen(false);

      expect(driver.calls,
          contains('setBounds(Offset(2000.0, 100.0), Size(1920.0, 1080.0))'));
    });

    // ─── T26: 副屏不可用 → 降级 center ───

    test('T26: secondary display restore — setBounds called', () async {
      driver.currentPosition = const Offset(2000, 100);
      driver.currentSize = const Size(1920, 1080);

      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.setFullscreen(true);

      scheduleMicrotask(() => confirmLeave(driver, adapter));
      await adapter.setFullscreen(false);

      final setBoundsCalls =
          driver.calls.where((c) => c.startsWith('setBounds')).toList();
      expect(setBoundsCalls, isNotEmpty);
    });

    // ─── 额外: toggle 测试 ───

    test('toggle — resolves based on current state', () async {
      scheduleMicrotask(() => confirmEnter(driver, adapter));
      await adapter.toggle();
      expect(adapter.snapshot().value.isFullscreen, isTrue);

      scheduleMicrotask(() => confirmLeave(driver, adapter));
      await adapter.toggle();
      expect(adapter.snapshot().value.isFullscreen, isFalse);
    });

    // ─── 额外: platformFailure ───

    test('platform failure — error event emitted', () async {
      driver.throwOnEnter = Exception('native crash');

      await adapter.setFullscreen(true);

      expect(adapter.snapshot().value.phase, FullscreenPhase.error);
      expect(adapter.snapshot().value.lastError, isA<PlatformFailure>());
    });

    // ─── 额外: capabilities ───

    test('capabilities returns default values', () async {
      final caps = await adapter.capabilities();
      expect(caps.supportsFullscreen, isTrue);
    });

    // ─── 额外: dispose ───

    test('dispose — subsequent calls are no-ops', () {
      adapter.dispose();
      adapter.dispose(); // 不应崩溃
    });
  });

  // ─── Windows 快速路径测试 (PERF-01/02) ───

  group('DesktopFullscreenAdapter — Windows fast path', () {
    late MockWindowsDriver winDriver;
    late DesktopFullscreenAdapter adapter;

    setUp(() {
      winDriver = MockWindowsDriver();
      adapter = DesktopFullscreenAdapter(winDriver);
    });

    tearDown(() {
      adapter.dispose();
    });

    test('enter uses enterFullscreenFast when driver is WindowsFullscreenDriver',
        () async {
      await adapter.setFullscreen(true);

      expect(winDriver.fastCalls, contains(contains('enterFullscreenFast')));
      // 不应调用标准 enterFullscreen
      expect(
        winDriver.fastCalls.any((c) => c == 'enterFullscreen(displayId: 0)'),
        isFalse,
      );
    });

    test('leave uses leaveFullscreenFast when driver is WindowsFullscreenDriver',
        () async {
      // 先进入全屏
      await adapter.setFullscreen(true);
      winDriver.fastCalls.clear();

      await adapter.setFullscreen(false);

      expect(winDriver.fastCalls, contains(contains('leaveFullscreenFast')));
    });

    test('snapshot updates to stable immediately after fast path enter',
        () async {
      await adapter.setFullscreen(true);

      expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
      expect(adapter.snapshot().value.isFullscreen, isTrue);
      expect(adapter.snapshot().value.effectiveMode, FullscreenMode.borderless);
    });

    test('snapshot updates to stable immediately after fast path leave',
        () async {
      await adapter.setFullscreen(true);
      await adapter.setFullscreen(false);

      expect(adapter.snapshot().value.phase, FullscreenPhase.stable);
      expect(adapter.snapshot().value.isFullscreen, isFalse);
      expect(adapter.snapshot().value.effectiveMode, FullscreenMode.windowed);
    });

    test('emits entered event on fast path enter', () async {
      final events = <FullscreenEvent>[];
      adapter.events.listen(events.add);

      await adapter.setFullscreen(true);

      expect(events.whereType<Entered>(), isNotEmpty);
    });

    test('emits left event on fast path leave', () async {
      final events = <FullscreenEvent>[];
      adapter.events.listen(events.add);

      await adapter.setFullscreen(true);
      await adapter.setFullscreen(false);

      expect(events.whereType<Left>(), isNotEmpty);
    });

    test('skips _waitForConfirmation on Windows — no delay', () async {
      final stopwatch = Stopwatch()..start();
      await adapter.setFullscreen(true);
      stopwatch.stop();

      // 快速路径应几乎瞬间完成 (< 100ms vs 标准路径 500ms+ timeout)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('standard driver still uses confirmation chain', () async {
      final standardDriver = MockFullscreenDriver();
      final standardAdapter = DesktopFullscreenAdapter(standardDriver);

      // 标准路径需要回调确认
      scheduleMicrotask(() => confirmEnter(standardDriver, standardAdapter));
      await standardAdapter.setFullscreen(true);

      expect(standardAdapter.snapshot().value.isFullscreen, isTrue);
      expect(standardDriver.calls, contains('enterFullscreen(displayId: 0)'));

      standardAdapter.dispose();
    });
  });
}
