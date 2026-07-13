// WindowsFullscreenDriver 单元测试。
//
// Win32 FFI 无法在 Flutter test 环境运行，
// 通过构造函数注入 mock Win32FullscreenApiWrapper 测试驱动逻辑。

import 'dart:ffi' hide Size;

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/platform/windows_fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/win32_fullscreen_ffi.dart';

/// Mock Win32FullscreenApiWrapper — 记录调用参数，可控返回值。
///
/// 模拟 Win32 API 行为: 样式读写、窗口位置、状态查询。
class MockWin32Api extends Win32FullscreenApiWrapper {
  MockWin32Api();

  final List<String> calls = [];

  /// 模拟的 HWND — 0 表示无效。
  int hwnd = 12345;

  /// 模拟的窗口样式。
  int style = 0x00CF0000; // WS_OVERLAPPEDWINDOW
  int exStyle = 0x00000100; // WS_EX_WINDOWEDGE

  /// 模拟的窗口状态。
  bool visible = true;
  bool iconic = false;
  bool zoomed = false;

  /// 模拟的显示器矩形 (物理像素)。
  ({int left, int top, int right, int bottom}) monitorRect =
      (left: 0, top: 0, right: 1920, bottom: 1080);

  /// 模拟的窗口矩形 (物理像素)。
  ({int left, int top, int right, int bottom}) windowRect =
      (left: 100, top: 100, right: 900, bottom: 700);

  /// 进入全屏后记录的样式值 (用于验证剥离)。
  int? lastSetStyle;
  int? lastSetExStyle;

  /// 最后一次 setWindowPos 参数。
  int? lastSetWindowPosHwnd;
  int? lastSetWindowPosInsertAfter;

  @override
  int getFlutterHwnd() {
    calls.add('getFlutterHwnd()');
    return hwnd;
  }

  @override
  int getWindowLong(int hwnd, int index) {
    calls.add('getWindowLong($hwnd, $index)');
    return index == gwlStyle ? style : exStyle;
  }

  @override
  int setWindowLong(int hwnd, int index, int value) {
    calls.add('setWindowLong($hwnd, $index, 0x${value.toRadixString(16)})');
    // Win32 SetWindowLong 返回旧值并设置新值 — mock 需同步更新状态
    final oldValue = index == gwlStyle ? style : exStyle;
    if (index == gwlStyle) {
      lastSetStyle = value;
      style = value;
    } else {
      lastSetExStyle = value;
      exStyle = value;
    }
    return oldValue;
  }

  @override
  bool setWindowPos(int hwnd, int insertAfter, int x, int y, int cx, int cy,
      int flags) {
    calls.add(
        'setWindowPos($hwnd, $insertAfter, $x, $y, $cx, $cy, 0x${flags.toRadixString(16)})');
    lastSetWindowPosHwnd = hwnd;
    lastSetWindowPosInsertAfter = insertAfter;
    return true;
  }

  @override
  ({int left, int top, int right, int bottom})? getWindowRect(int hwnd) {
    calls.add('getWindowRect($hwnd)');
    return windowRect;
  }

  @override
  bool setForegroundWindow(int hwnd) {
    calls.add('setForegroundWindow($hwnd)');
    return true;
  }

  @override
  int setFocus(int hwnd) {
    calls.add('setFocus($hwnd)');
    return hwnd;
  }

  @override
  bool isWindow(int hwnd) {
    calls.add('isWindow($hwnd)');
    return hwnd != 0;
  }

  @override
  bool isWindowVisible(int hwnd) {
    calls.add('isWindowVisible($hwnd)');
    return visible;
  }

  @override
  bool isIconic(int hwnd) {
    calls.add('isIconic($hwnd)');
    return iconic;
  }

  @override
  bool isZoomed(int hwnd) {
    calls.add('isZoomed($hwnd)');
    return zoomed;
  }

  @override
  int monitorFromWindow(int hwnd) {
    calls.add('monitorFromWindow($hwnd)');
    return hwnd != 0 ? 9999 : 0;
  }

  @override
  ({int left, int top, int right, int bottom})? getMonitorRect(int hMonitor) {
    calls.add('getMonitorRect($hMonitor)');
    return monitorRect;
  }

  @override
  Pointer<WindowPlacement>? getWindowPlacement(int hwnd) {
    calls.add('getWindowPlacement($hwnd)');
    final p = calloc<WindowPlacement>();
    p.ref.length = sizeOf<WindowPlacement>();
    p.ref.rcNormalPosition.left = 100;
    p.ref.rcNormalPosition.top = 100;
    p.ref.rcNormalPosition.right = 900;
    p.ref.rcNormalPosition.bottom = 700;
    return p;
  }

  @override
  bool setWindowPlacement(int hwnd, Pointer<WindowPlacement> placement) {
    calls.add('setWindowPlacement($hwnd)');
    // 不 free — driver 负责释放 _savedPlacement
    return true;
  }

  @override
  bool maximizeWindow(int hwnd) {
    calls.add('maximizeWindow($hwnd)');
    zoomed = true;
    return true;
  }

  @override
  bool restoreWindow(int hwnd) {
    calls.add('restoreWindow($hwnd)');
    zoomed = false;
    iconic = false;
    return true;
  }
}

void main() {
  group('WindowsFullscreenDriver', () {
    late MockWin32Api api;
    late WindowsFullscreenDriver driver;

    setUp(() {
      api = MockWin32Api();
      driver = WindowsFullscreenDriver(api: api);
    });

    // ─── enterFullscreen ───

    group('enterFullscreen', () {
      test('strips WS_THICKFRAME, WS_CAPTION, and WS_MAXIMIZE from style', () async {
        await driver.enterFullscreen();

        // 验证 setWindowLong 被调用来修改样式
        expect(api.lastSetStyle, isNotNull);
        // WS_THICKFRAME (0x00040000), WS_CAPTION (0x00C00000), WS_MAXIMIZE (0x01000000) 应全部被剥离
        expect(api.lastSetStyle! & wsThickframe, 0);
        expect(api.lastSetStyle! & wsCaption, 0);
        expect(api.lastSetStyle! & wsMaximize, 0);
      });

      test('sets WS_EX_TOPMOST on extended style', () async {
        await driver.enterFullscreen();

        expect(api.lastSetExStyle, isNotNull);
        expect(api.lastSetExStyle! & wsExTopmost, wsExTopmost);
      });

      test('covers entire monitor area via SetWindowPos', () async {
        await driver.enterFullscreen();

        // 验证 SetWindowPos 使用 HWND_TOPMOST 覆盖整个显示器
        expect(api.lastSetWindowPosInsertAfter, hwndTopmost);
        expect(
          api.calls,
          contains(contains('setWindowPos')),
        );
      });

      test('does nothing when HWND is 0', () async {
        api.hwnd = 0;
        await driver.enterFullscreen();

        // 不应调用任何样式修改
        expect(api.lastSetStyle, isNull);
        expect(api.lastSetExStyle, isNull);
      });

      test('saves window placement before entering fullscreen', () async {
        await driver.enterFullscreen();

        // getWindowPlacement 应在 setWindowLong 之前被调用
        final placementIdx =
            api.calls.indexWhere((c) => c.startsWith('getWindowPlacement'));
        final setStyleIdx =
            api.calls.indexWhere((c) => c.startsWith('setWindowLong'));
        expect(placementIdx, lessThan(setStyleIdx));
      });

      test('call order: setWindowLong → setWindowLong → getWindowLong (verify) → setWindowPos', () async {
        await driver.enterFullscreen();

        // 收集所有调用的索引，避免 indexOf 因重复字符串返回错误位置
        final setLongIndices = <int>[];
        final getLongIndices = <int>[];
        int? posIndex;
        for (var i = 0; i < api.calls.length; i++) {
          if (api.calls[i].startsWith('setWindowLong')) setLongIndices.add(i);
          if (api.calls[i].startsWith('getWindowLong')) getLongIndices.add(i);
          if (api.calls[i].startsWith('setWindowPos')) posIndex = i;
        }

        // 2 次 setWindowLong (剥离 gwlStyle + 设置 gwlExStyle)
        expect(setLongIndices.length, 2);
        // 4 次 getWindowLong: 2 次保存初始样式 + 2 次诊断验证
        expect(getLongIndices.length, 4);
        expect(posIndex, isNotNull);

        final lastSetIdx = setLongIndices.last;

        // setWindowPos 应在最后一次 setWindowLong 之后
        expect(posIndex, greaterThan(lastSetIdx));

        // 第 3 和第 4 次 getWindowLong (诊断验证) 应在 setWindowLong 之后、setWindowPos 之前
        expect(getLongIndices[2], greaterThan(lastSetIdx));
        expect(posIndex, greaterThan(getLongIndices[3]));
      });

      test('diagnostic read-back confirms all border bits are cleared', () async {
        // 设置初始样式包含所有边框位
        api.style = wsCaption | wsThickframe | wsMaximize;
        await driver.enterFullscreen();

        // 进入全屏后读取的样式不应包含任何边框位
        // lastSetStyle 是写入的值，诊断读取应确认边框已清除
        expect(api.lastSetStyle, isNotNull);
        expect(api.lastSetStyle! & (wsCaption | wsThickframe | wsMaximize), 0);

        // 验证诊断 getWindowLong 被调用 (回读确认)
        final verifyCalls = api.calls
            .where((c) => c.startsWith('getWindowLong'))
            .toList();
        // 至少 4 次: 2 次保存初始样式 + 2 次诊断验证
        expect(verifyCalls.length, greaterThanOrEqualTo(4));
      });
    });

    // ─── enterFullscreenFast ───

    group('enterFullscreenFast', () {
      test('uses fewer FFI calls than enterFullscreen', () async {
        // 标准路径: 11 FFI calls (含 2 次诊断回读)
        await driver.enterFullscreen();
        final standardCalls = List<String>.from(api.calls);
        api.calls.clear();

        // 快速路径: 6 FFI calls (跳过诊断回读, HWND cache miss on new driver)
        final driver2 = WindowsFullscreenDriver(api: api);
        await driver2.enterFullscreenFast();
        final fastCalls = List<String>.from(api.calls);

        // 快速路径应比标准路径少 2 次 getWindowLong (诊断回读)
        final standardGetLong =
            standardCalls.where((c) => c.startsWith('getWindowLong')).length;
        final fastGetLong =
            fastCalls.where((c) => c.startsWith('getWindowLong')).length;
        expect(fastGetLong, lessThan(standardGetLong));
        // 标准路径 4 次 getWindowLong，快速路径 2 次
        expect(standardGetLong, 4);
        expect(fastGetLong, 2);
      });

      test('still strips WS_THICKFRAME, WS_CAPTION, and WS_MAXIMIZE', () async {
        await driver.enterFullscreenFast();

        expect(api.lastSetStyle, isNotNull);
        expect(api.lastSetStyle! & wsThickframe, 0);
        expect(api.lastSetStyle! & wsCaption, 0);
        expect(api.lastSetStyle! & wsMaximize, 0);
      });

      test('skips WS_EX_TOPMOST setWindowLong (setWindowPos handles Z-order)', () async {
        await driver.enterFullscreenFast();

        // fast path 不再设置 WS_EX_TOPMOST — setWindowPos(HWND_TOPMOST) 已处理
        // lastSetExStyle 应为 null（无 setWindowLong(gwlExStyle) 调用）
        expect(api.lastSetExStyle, isNull);
      });

      test('sets HWND_TOPMOST via setWindowPos', () async {
        await driver.enterFullscreenFast();

        expect(api.lastSetWindowPosInsertAfter, hwndTopmost);
      });

      test('saves placement before modifying styles', () async {
        await driver.enterFullscreenFast();

        final placementIdx =
            api.calls.indexWhere((c) => c.startsWith('getWindowPlacement'));
        final setStyleIdx =
            api.calls.indexWhere((c) => c.startsWith('setWindowLong'));
        expect(placementIdx, lessThan(setStyleIdx));
      });

      test('does nothing when HWND is 0', () async {
        api.hwnd = 0;
        await driver.enterFullscreenFast();

        expect(api.lastSetStyle, isNull);
        expect(api.lastSetExStyle, isNull);
      });

      test('uses exactly 5 FFI calls on second toggle (same driver)', () async {
        // First call: populate caches (HWND + HMONITOR)
        await driver.enterFullscreenFast();
        await driver.leaveFullscreenFast();
        api.calls.clear();

        // Third operation: HWND cached from previous calls, HMONITOR cached
        await driver.enterFullscreenFast();

        // Expected: getWindowLong x2 + getWindowPlacement + setWindowLong + setWindowPos = 5
        // No getFlutterHwnd (HWND cached), no monitorFromWindow/getMonitorRect (HMONITOR cached)
        expect(api.calls.length, 5,
          reason: 'Same driver, second enter: HWND + HMONITOR both cached = 5 FFI');
        expect(api.calls.where((c) => c.startsWith('getFlutterHwnd')), isEmpty,
          reason: 'HWND should be cached');
        expect(api.calls.where((c) => c.startsWith('monitorFromWindow')), isEmpty,
          reason: 'HMONITOR should be cached');
        expect(api.calls.where((c) => c.startsWith('getMonitorRect')), isEmpty,
          reason: 'Monitor rect should be cached');
      });
    });

    // ─── leaveFullscreenFast ───

    group('leaveFullscreenFast', () {
      test('restores original window style', () async {
        await driver.enterFullscreenFast();
        api.calls.clear();

        await driver.leaveFullscreenFast();

        final setStyleCalls =
            api.calls.where((c) => c.startsWith('setWindowLong')).toList();
        // leave 恢复 style + exStyle = 2 次
        expect(setStyleCalls.length, 2);
      });

      test('clears TopMost via HWND_NOTOPMOST', () async {
        await driver.enterFullscreenFast();
        api.calls.clear();

        await driver.leaveFullscreenFast();

        expect(
          api.calls.any(
              (c) => c.startsWith('setWindowPos') && c.contains('$hwndNotopmost')),
          isTrue,
        );
      });

      test('restores window placement', () async {
        await driver.enterFullscreenFast();
        api.calls.clear();

        await driver.leaveFullscreenFast();

        expect(
          api.calls.any((c) => c.startsWith('setWindowPlacement')),
          isTrue,
        );
      });

      test('recovers focus when window is visible and not iconic', () async {
        api.visible = true;
        api.iconic = false;

        await driver.enterFullscreenFast();
        api.calls.clear();

        await driver.leaveFullscreenFast();

        expect(
          api.calls.any((c) => c.startsWith('setForegroundWindow')),
          isTrue,
        );
      });

      test('skips focus recovery when window is not visible', () async {
        api.visible = false;

        await driver.enterFullscreenFast();
        api.calls.clear();

        await driver.leaveFullscreenFast();

        expect(
          api.calls.any((c) => c.startsWith('setForegroundWindow')),
          isFalse,
        );
      });

      test('does nothing when HWND is 0', () async {
        api.hwnd = 0;
        await driver.enterFullscreenFast();
        api.calls.clear();

        await driver.leaveFullscreenFast();

        expect(api.calls.where((c) => c.startsWith('setWindowLong')), isEmpty);
      });

      test('uses exactly 4 FFI calls with cached HWND (core path)', () async {
        await driver.enterFullscreenFast();
        api.calls.clear();

        await driver.leaveFullscreenFast();

        // Core path: setWindowLong x2 + setWindowPos + setWindowPlacement = 4
        // Focus recovery adds 4 more (isWindowVisible, isIconic, setForegroundWindow, setFocus)
        // Total = 8, but core leave logic = 4 FFI
        expect(api.calls.where((c) => c.startsWith('getFlutterHwnd')), isEmpty,
          reason: 'HWND should be cached');
        expect(api.calls.where((c) => c.startsWith('setWindowLong')).length, 2,
          reason: 'Restore style + exStyle = 2 setWindowLong');
        expect(api.calls.where((c) => c.startsWith('setWindowPos')).length, 1,
          reason: 'Clear TopMost = 1 setWindowPos');
        expect(api.calls.where((c) => c.startsWith('setWindowPlacement')).length, 1,
          reason: 'Restore placement = 1 setWindowPlacement');
      });
    });

    // ─── leaveFullscreen ───

    group('leaveFullscreen', () {
      test('restores original window style', () async {
        await driver.enterFullscreen();
        await driver.leaveFullscreen();

        // enter 和 leave 各调用一次 setWindowLong (gwlStyle=-16 和 gwlExStyle=-20)
        // 共 4 次: enter 2 次 (style + exStyle) + leave 2 次
        final setStyleCalls = api.calls
            .where((c) => c.startsWith('setWindowLong'))
            .toList();
        expect(setStyleCalls.length, greaterThanOrEqualTo(4));
      });

      test('restores original extended style', () async {
        await driver.enterFullscreen();
        await driver.leaveFullscreen();

        // 验证 setWindowLong 被调用来恢复 exStyle (index=-20)
        final setStyleCalls = api.calls
            .where((c) => c.startsWith('setWindowLong'))
            .toList();
        // enter 2 次 + leave 2 次 = 至少 4 次
        expect(setStyleCalls.length, greaterThanOrEqualTo(4));
      });

      test('clears TopMost via HWND_NOTOPMOST', () async {
        await driver.enterFullscreen();
        api.calls.clear();

        await driver.leaveFullscreen();

        // 验证 SetWindowPos 使用 HWND_NOTOPMOST
        expect(
          api.calls.any(
              (c) => c.startsWith('setWindowPos') && c.contains('$hwndNotopmost')),
          isTrue,
        );
      });

      test('restores window placement', () async {
        await driver.enterFullscreen();
        api.calls.clear();

        await driver.leaveFullscreen();

        expect(
          api.calls.any((c) => c.startsWith('setWindowPlacement')),
          isTrue,
        );
      });

      test('recovers focus when window is visible and not iconic', () async {
        api.visible = true;
        api.iconic = false;

        await driver.enterFullscreen();
        api.calls.clear();

        await driver.leaveFullscreen();

        expect(
          api.calls.any((c) => c.startsWith('setForegroundWindow')),
          isTrue,
        );
        expect(
          api.calls.any((c) => c.startsWith('setFocus')),
          isTrue,
        );
      });

      test('skips focus recovery when window is not visible', () async {
        api.visible = false;

        await driver.enterFullscreen();
        api.calls.clear();

        await driver.leaveFullscreen();

        expect(
          api.calls.any((c) => c.startsWith('setForegroundWindow')),
          isFalse,
        );
      });

      test('skips focus recovery when window is iconic (minimized)', () async {
        api.iconic = true;

        await driver.enterFullscreen();
        api.calls.clear();

        await driver.leaveFullscreen();

        expect(
          api.calls.any((c) => c.startsWith('setForegroundWindow')),
          isFalse,
        );
      });

      test('does nothing when HWND is 0', () async {
        api.hwnd = 0;
        await driver.enterFullscreen();
        api.calls.clear();

        await driver.leaveFullscreen();

        // 不应调用任何恢复操作
        expect(api.calls.where((c) => c.startsWith('setWindowLong')), isEmpty);
      });

      test('forces Flutter layout refresh after placement restore', () async {
        await driver.enterFullscreen();
        api.calls.clear();

        await driver.leaveFullscreen();

        // setWindowPos 应被调用用于布局刷新 (SWP_NOZORDER | SWP_NOACTIVATE)
        final posCalls =
            api.calls.where((c) => c.startsWith('setWindowPos')).toList();
        expect(posCalls.length, greaterThanOrEqualTo(2));
      });
    });

    // ─── queryFullscreen ───

    group('queryFullscreen', () {
      test('returns true when WS_THICKFRAME is absent (fullscreen style)', () async {
        // 模拟已进入全屏: style 中无 WS_THICKFRAME
        api.style = 0x00C00000; // WS_OVERLAPPEDWINDOW minus WS_THICKFRAME
        final result = await driver.queryFullscreen();
        expect(result, isTrue);
      });

      test('returns false when WS_THICKFRAME is present (windowed style)', () async {
        // 默认 style 包含 WS_THICKFRAME → 非全屏
        api.style = 0x00CF0000; // WS_OVERLAPPEDWINDOW
        final result = await driver.queryFullscreen();
        expect(result, isFalse);
      });

      test('uses getWindowLong to verify actual window style (T3)', () async {
        await driver.queryFullscreen();

        expect(
          api.calls.any((c) => c.startsWith('getWindowLong')),
          isTrue,
        );
      });

      test('auto-corrects _isFullscreen on desync (T3)', () async {
        // 先进入全屏 (设置 _isFullscreen=true, 剥离 WS_THICKFRAME)
        await driver.enterFullscreenFast();
        expect(await driver.queryFullscreen(), isTrue);

        // 模拟外部操作恢复了 WS_THICKFRAME (如 Win+↑ 最大化)
        api.style = 0x00CF0000; // WS_OVERLAPPEDWINDOW 含 WS_THICKFRAME
        final result = await driver.queryFullscreen();
        // 应自动修正: _isFullscreen 变为 false
        expect(result, isFalse);
      });

      test('falls back to internal state when HWND is 0', () async {
        api.hwnd = 0;
        // 内部状态为 false (未进入全屏)
        final result = await driver.queryFullscreen();
        expect(result, isFalse);
      });
    });

    // ─── monitor cache (T1) ───

    group('monitor cache (T1)', () {
      test('enterFullscreenFast caches monitor rect on first call', () async {
        await driver.enterFullscreenFast();
        api.calls.clear();

        // 第二次全屏应使用缓存，不调用 getMonitorRect
        await driver.leaveFullscreenFast();
        await driver.enterFullscreenFast();

        final getRectCalls = api.calls
            .where((c) => c.startsWith('getMonitorRect'))
            .toList();
        expect(getRectCalls, isEmpty);
      });

      test('enterFullscreen caches monitor rect on first call', () async {
        await driver.enterFullscreen();
        api.calls.clear();

        await driver.leaveFullscreen();
        await driver.enterFullscreen();

        final getRectCalls = api.calls
            .where((c) => c.startsWith('getMonitorRect'))
            .toList();
        expect(getRectCalls, isEmpty);
      });

      test('clearMonitorCache forces re-query on next enter', () async {
        await driver.enterFullscreenFast();
        driver.clearMonitorCache();
        api.calls.clear();

        await driver.leaveFullscreenFast();
        await driver.enterFullscreenFast();

        final getRectCalls = api.calls
            .where((c) => c.startsWith('getMonitorRect'))
            .toList();
        expect(getRectCalls, isNotEmpty);
      });

      test('HMONITOR cached — monitorFromWindow skipped on second call', () async {
        await driver.enterFullscreenFast();
        api.calls.clear();

        await driver.leaveFullscreenFast();
        await driver.enterFullscreenFast();

        // HMONITOR 已缓存，第二次 enterFullscreenFast 应跳过 monitorFromWindow
        final monitorCalls = api.calls
            .where((c) => c.startsWith('monitorFromWindow'))
            .toList();
        expect(monitorCalls, isEmpty);
      });
    });

    // ─── HWND cache ───

    group('HWND cache', () {
      test('caches HWND after first getFlutterHwnd call', () async {
        await driver.enterFullscreenFast();
        final firstCallCount = api.calls.where((c) => c.startsWith('getFlutterHwnd')).length;
        expect(firstCallCount, 1, reason: 'First call fetches HWND');

        api.calls.clear();
        await driver.leaveFullscreenFast();
        final secondCallCount = api.calls.where((c) => c.startsWith('getFlutterHwnd')).length;
        expect(secondCallCount, 0, reason: 'Second call uses cached HWND');
      });

      test('clearMonitorCache also clears HWND cache', () async {
        await driver.enterFullscreenFast();
        api.calls.clear();

        driver.clearMonitorCache();

        await driver.enterFullscreenFast();
        expect(api.calls.where((c) => c.startsWith('getFlutterHwnd')).length, 1,
          reason: 'After cache clear, HWND re-fetched');
      });

      test('dispose clears HWND cache', () async {
        await driver.enterFullscreenFast();
        driver.dispose();
        api.calls.clear();

        final driver2 = WindowsFullscreenDriver(api: api);
        await driver2.enterFullscreenFast();
        expect(api.calls.where((c) => c.startsWith('getFlutterHwnd')).length, 1,
          reason: 'New driver instance fetches HWND after dispose cleared cache');
      });
    });

    // ─── capabilities ───

    group('capabilities', () {
      test('returns Windows-specific capability with multi-display support',
          () {
        final caps = driver.capabilities();

        expect(caps.supportsFullscreen, isTrue);
        expect(caps.supportsMultiDisplay, isTrue);
        expect(caps.supportsMultiWindow, isFalse);
        expect(caps.supportsExclusive, isFalse);
        expect(caps.requiresUserGesture, isFalse);
      });

      test('platformNotes mentions WS_THICKFRAME, focus recovery, TopMost',
          () {
        final caps = driver.capabilities();

        expect(caps.platformNotes, contains('WS_THICKFRAME'));
        expect(caps.platformNotes, contains('focus recovery'));
        expect(caps.platformNotes, contains('TopMost'));
      });
    });

    // ─── window management (v3: removed from Driver, now in WindowService) ───
    // isMaximized/isMinimized/maximize/restore/focus 已移至 WindowService 直接调用 windowManager
  });
}
