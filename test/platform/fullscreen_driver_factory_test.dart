// DesktopFullscreenDriverFactory 单元测试。
//
// 测试验证:
// - 工厂根据当前平台 (Platform.isXXX) 返回正确驱动类型
// - 工厂方法不抛出异常
// - capabilities() 返回有效值
// - onNativeStateChanged setter 在默认实现下不抛出异常
//
// 注: Platform.isXXX 在测试环境中固定为当前 OS (Windows)，
// 因此只测试当前平台的分支。跨平台分支在 CI 矩阵中覆盖。

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/desktop_fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/bridge/desktop_fullscreen_driver_factory.dart';
import 'package:simple_player_flutter/kernel/bridge/platform/windows_fullscreen_driver.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/win32_fullscreen_ffi.dart';

void main() {
  // 初始化 Flutter test binding — windowManager 单例需要 binaryMessenger。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopFullscreenDriverFactory', () {
    test('create() does not throw', () {
      expect(() => DesktopFullscreenDriverFactory.create(), returnsNormally);
    });

    test('create() returns a FullscreenDriver instance', () {
      final driver = DesktopFullscreenDriverFactory.create();
      // FullscreenDriver 是抽象类，工厂应返回具体实现
      expect(driver, isNotNull);
    });

    // 当前测试环境为 Windows，默认 flag 下应返回 DesktopFullscreenDriver
    // (USE_WINDOWS_NATIVE_FULLSCREEN 默认 false)
    test('create() returns DesktopFullscreenDriver on Windows (default flag)',
        () {
      final driver = DesktopFullscreenDriverFactory.create();
      expect(driver, isA<DesktopFullscreenDriver>());
    });

    test('create() returns driver with default capabilities', () {
      final driver = DesktopFullscreenDriverFactory.create();
      final caps = driver.capabilities();
      // 所有驱动都应支持全屏
      expect(caps.supportsFullscreen, isTrue);
    });
  });

  // ─── T5: 工厂运行时降级 ───

  group('DesktopFullscreenDriverFactory — runtime fallback (T5)', () {
    test('createWindowsNative returns WindowsFullscreenDriver when HWND is valid', () {
      // 默认 mock API: hwnd=12345, isWindow=true
      final driver = DesktopFullscreenDriverFactory.createWindowsNative();
      expect(driver, isA<WindowsFullscreenDriver>());
    });

    test('createWindowsNative falls back when HWND is 0', () {
      final driver = DesktopFullscreenDriverFactory.createWindowsNative(
        apiOverride: _MockApiHwnd0(),
      );
      expect(driver, isA<DesktopFullscreenDriver>());
    });

    test('createWindowsNative falls back when isWindow returns false', () {
      final driver = DesktopFullscreenDriverFactory.createWindowsNative(
        apiOverride: _MockApiNotWindow(),
      );
      expect(driver, isA<DesktopFullscreenDriver>());
    });

    test('createWindowsNative falls back when getFlutterHwnd throws', () {
      final driver = DesktopFullscreenDriverFactory.createWindowsNative(
        apiOverride: _MockApiThrows(),
      );
      expect(driver, isA<DesktopFullscreenDriver>());
    });
  });

  group('FullscreenDriver interface extensions', () {
    test('capabilities() returns FullscreenCapability', () {
      final driver = DesktopFullscreenDriverFactory.create();
      final caps = driver.capabilities();
      expect(caps.supportsFullscreen, isA<bool>());
      expect(caps.supportsMultiWindow, isA<bool>());
      expect(caps.supportsMultiDisplay, isA<bool>());
    });

    test('onNativeStateChanged setter does not throw', () {
      final driver = DesktopFullscreenDriverFactory.create();
      // 默认实现应接受回调但不做任何事
      expect(
        () => driver.onNativeStateChanged = (id, fs) {},
        returnsNormally,
      );
    });

    test('onNativeStateChanged accepts null', () {
      final driver = DesktopFullscreenDriverFactory.create();
      expect(
        () => driver.onNativeStateChanged = null,
        returnsNormally,
      );
    });
  });
}

// ─── T5 mock APIs ───

/// HWND=0 — 模拟无窗口环境。
class _MockApiHwnd0 extends Win32FullscreenApiWrapper {
  @override
  int getFlutterHwnd() => 0;
  @override
  bool isWindow(int hwnd) => false;
}

/// isWindow=false — 模拟窗口已销毁。
class _MockApiNotWindow extends Win32FullscreenApiWrapper {
  @override
  int getFlutterHwnd() => 12345;
  @override
  bool isWindow(int hwnd) => false;
}

/// getFlutterHwnd 抛异常 — 模拟 FFI 初始化失败。
class _MockApiThrows extends Win32FullscreenApiWrapper {
  @override
  int getFlutterHwnd() => throw Exception('FFI DLL not loaded');
}
