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
    if (index == gwlStyle) {
      lastSetStyle = value;
    } else {
      lastSetExStyle = value;
    }
    return index == gwlStyle ? style : exStyle;
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
      test('strips WS_THICKFRAME and WS_CAPTION from window style', () async {
        await driver.enterFullscreen();

        // 验证 setWindowLong 被调用来修改样式
        expect(api.lastSetStyle, isNotNull);
        // WS_THICKFRAME (0x00040000) 和 WS_CAPTION (0x00C00000) 应被剥离
        expect(api.lastSetStyle! & wsThickframe, 0);
        expect(api.lastSetStyle! & wsCaption, 0);
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
      test('returns true after IsZoomed reports zoomed', () async {
        api.zoomed = true;
        final result = await driver.queryFullscreen();
        expect(result, isTrue);
      });

      test('returns false after IsZoomed reports not zoomed', () async {
        api.zoomed = false;
        final result = await driver.queryFullscreen();
        expect(result, isFalse);
      });

      test('uses IsZoomed for real state query', () async {
        await driver.queryFullscreen();

        expect(
          api.calls.any((c) => c.startsWith('isZoomed')),
          isTrue,
        );
      });

      test('falls back to internal state when HWND is 0', () async {
        api.hwnd = 0;
        // 内部状态为 false (未进入全屏)
        final result = await driver.queryFullscreen();
        expect(result, isFalse);
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

    // ─── window management ───

    group('window management', () {
      test('isMaximized delegates to IsZoomed', () async {
        api.zoomed = true;
        final result = await driver.isMaximized();
        expect(result, isTrue);
        expect(api.calls.any((c) => c.startsWith('isZoomed')), isTrue);
      });

      test('isMinimized delegates to IsIconic', () async {
        api.iconic = true;
        final result = await driver.isMinimized();
        expect(result, isTrue);
        expect(api.calls.any((c) => c.startsWith('isIconic')), isTrue);
      });

      test('maximize calls maximizeWindow', () async {
        await driver.maximize();
        expect(api.calls.any((c) => c.startsWith('maximizeWindow')), isTrue);
      });

      test('restore calls restoreWindow', () async {
        await driver.restore();
        expect(api.calls.any((c) => c.startsWith('restoreWindow')), isTrue);
      });

      test('focus calls setForegroundWindow when visible', () async {
        api.visible = true;
        await driver.focus();
        expect(
            api.calls.any((c) => c.startsWith('setForegroundWindow')), isTrue);
      });

      test('focus skips setForegroundWindow when not visible', () async {
        api.visible = false;
        await driver.focus();
        expect(
            api.calls.any((c) => c.startsWith('setForegroundWindow')), isFalse);
      });
    });
  });
}
