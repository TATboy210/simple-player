// LinuxFullscreenDriver 单元测试。
//
// Linux window-state-event 信号在 Flutter test 环境中不可用，
// 通过构造函数注入 mock FullScreenWindowPlatform 测试驱动逻辑。
//
// WindowManager 使用真实 windowManager 实例 (单例，无法 mock)，
// 窗口管理方法的委托由编译器保证类型安全。

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fullscreen_window/fullscreen_window_platform_interface.dart';
import 'package:simple_player_flutter/kernel/bridge/platform/linux_fullscreen_driver.dart';

/// Mock FullScreenWindowPlatform — 可控的全屏操作和回调流。
class MockFullScreenWindowPlatform extends FullScreenWindowPlatform {
  MockFullScreenWindowPlatform();

  /// 模拟的全屏状态。
  bool isFullScreenValue = false;

  /// 记录 setFullScreen 调用参数。
  final List<bool> setFullScreenCalls = [];

  /// 模拟 isFullScreen 抛出异常。
  bool throwOnIsFullScreen = false;

  /// 回调流控制器。
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Future<void> setFullScreen(bool isFullScreen) async {
    setFullScreenCalls.add(isFullScreen);
  }

  @override
  Stream<bool> get onFullScreenChanged => controller.stream;

  @override
  Future<bool> isFullScreen() async {
    if (throwOnIsFullScreen) {
      throw Exception('plugin unavailable');
    }
    return isFullScreenValue;
  }

  @override
  Future<Size> getScreenSize(BuildContext? context) async {
    return const Size(1920, 1080);
  }
}

void main() {
  // 初始化 Flutter test binding — windowManager 单例需要 binaryMessenger。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinuxFullscreenDriver', () {
    late MockFullScreenWindowPlatform plugin;
    late LinuxFullscreenDriver driver;

    setUp(() {
      plugin = MockFullScreenWindowPlatform();
      driver = LinuxFullscreenDriver(plugin: plugin);
    });

    tearDown(() {
      driver.dispose();
      plugin.controller.close();
    });

    // ─── enterFullscreen ───

    group('enterFullscreen', () {
      test('calls plugin.setFullScreen(true)', () async {
        await driver.enterFullscreen();

        expect(plugin.setFullScreenCalls, [true]);
      });

      test('returns immediately without waiting for confirmation', () async {
        // enterFullscreen 应立即返回，不等待信号确认
        final stopwatch = Stopwatch()..start();
        await driver.enterFullscreen();
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    // ─── leaveFullscreen ───

    group('leaveFullscreen', () {
      test('calls plugin.setFullScreen(false)', () async {
        await driver.leaveFullscreen();

        expect(plugin.setFullScreenCalls, [false]);
      });
    });

    // ─── queryFullscreen ───

    group('queryFullscreen', () {
      test('returns true when plugin reports fullscreen', () async {
        plugin.isFullScreenValue = true;
        final result = await driver.queryFullscreen();

        expect(result, isTrue);
      });

      test('returns false when plugin reports not fullscreen', () async {
        plugin.isFullScreenValue = false;
        final result = await driver.queryFullscreen();

        expect(result, isFalse);
      });

      test('falls back to window_manager when plugin throws', () async {
        plugin.throwOnIsFullScreen = true;
        // window_manager 默认返回 false (非全屏状态)
        final result = await driver.queryFullscreen();

        expect(result, isFalse);
      });
    });

    // ─── 原生回调桥接 (D-P12) ───

    group('native callback bridge (D-P12)', () {
      test('forwards plugin onFullScreenChanged to onNativeStateChanged',
          () async {
        final List<(int, bool)> callbacks = [];
        driver.onNativeStateChanged = (windowId, isFullscreen) {
          callbacks.add((windowId, isFullscreen));
        };

        // 模拟 GdkWindow state-changed 信号回调
        plugin.controller.add(true);
        await Future<void>.delayed(Duration.zero);

        expect(callbacks, hasLength(1));
        expect(callbacks[0].$1, 0); // windowId=0 单窗口
        expect(callbacks[0].$2, true); // isFullscreen
      });

      test('forwards exit-fullscreen callback', () async {
        final List<(int, bool)> callbacks = [];
        driver.onNativeStateChanged = (windowId, isFullscreen) {
          callbacks.add((windowId, isFullscreen));
        };

        // 模拟退出全屏的 state-changed 信号
        plugin.controller.add(false);
        await Future<void>.delayed(Duration.zero);

        expect(callbacks, hasLength(1));
        expect(callbacks[0].$2, false);
      });

      test('multiple callbacks are forwarded in order', () async {
        final List<bool> states = [];
        driver.onNativeStateChanged = (windowId, isFullscreen) {
          states.add(isFullscreen);
        };

        plugin.controller.add(true);
        plugin.controller.add(false);
        plugin.controller.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(states, [true, false, true]);
      });

      test('no crash when onNativeStateChanged not set', () async {
        // 未设置回调不应崩溃
        plugin.controller.add(true);
        await Future<void>.delayed(Duration.zero);
        // 只要不抛异常即通过
      });

      test('callback is not called after dispose', () async {
        final List<bool> callbacks = [];
        driver.onNativeStateChanged = (_, isFullscreen) {
          callbacks.add(isFullscreen);
        };

        driver.dispose();

        plugin.controller.add(true);
        await Future<void>.delayed(Duration.zero);
        expect(callbacks, isEmpty);
      });
    });

    // ─── capabilities ───

    group('capabilities', () {
      test('returns Linux-specific capability values', () {
        final caps = driver.capabilities();

        expect(caps.supportsFullscreen, isTrue);
        expect(caps.supportsMultiDisplay, isTrue);
        expect(caps.supportsMultiWindow, isFalse);
        expect(caps.supportsExclusive, isFalse);
        expect(caps.requiresUserGesture, isFalse);
      });

      test('platformNotes contains GTK and WM detection info', () {
        final caps = driver.capabilities();

        expect(caps.platformNotes, contains('GTK fullscreen'));
        expect(caps.platformNotes, contains('Three-tier confirmation'));
        expect(caps.platformNotes, contains('WM:'));
      });

      test('platformNotes contains tiling WM warning', () {
        final caps = driver.capabilities();

        expect(caps.platformNotes, contains('Tiling WMs'));
        expect(caps.platformNotes, contains('i3'));
        expect(caps.platformNotes, contains('Sway'));
      });
    });

    // ─── dispose ───

    group('dispose', () {
      test('cancels stream subscription on dispose', () async {
        final List<bool> callbacks = [];
        driver.onNativeStateChanged = (_, isFullscreen) {
          callbacks.add(isFullscreen);
        };

        driver.dispose();

        // 流已取消，回调不应到达
        plugin.controller.add(true);
        await Future<void>.delayed(Duration.zero);
        expect(callbacks, isEmpty);
      });

      test('clears onNativeStateChanged on dispose', () async {
        final List<bool> callbacks = [];
        driver.onNativeStateChanged = (_, isFullscreen) {
          callbacks.add(isFullscreen);
        };

        driver.dispose();

        // callback 引用已清除
        plugin.controller.add(true);
        await Future<void>.delayed(Duration.zero);
        expect(callbacks, isEmpty);
      });
    });

    // ─── WM 检测 (D-P13) ───

    group('WM detection (D-P13)', () {
      test('does not crash when environment variables are missing', () {
        // 在 test 环境中 XDG 环境变量通常未设置
        // _detectWindowManager 应返回包含 "unknown" 的字符串
        final caps = driver.capabilities();

        // platformNotes 包含 WM 信息（可能全部是 "unknown"）
        expect(caps.platformNotes, isNotNull);
        expect(caps.platformNotes, contains('WM:'));
      });
    });
  });
}
