// MacosFullscreenDriver 单元测试。
//
// macOS NSWindowDelegate 回调在 Flutter test 环境中不可用，
// 通过构造函数注入 mock FullScreenWindowPlatform 测试驱动逻辑。
//
// WindowManager 使用真实 windowManager 实例 (单例，无法 mock)，
// 窗口管理方法的委托由编译器保证类型安全。

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fullscreen_window/fullscreen_window_platform_interface.dart';
import 'package:simple_player_flutter/kernel/bridge/platform/macos_fullscreen_driver.dart';

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

  group('MacosFullscreenDriver', () {
    late MockFullScreenWindowPlatform plugin;
    late MacosFullscreenDriver driver;

    setUp(() {
      plugin = MockFullScreenWindowPlatform();
      driver = MacosFullscreenDriver(plugin: plugin);
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

      test('returns immediately without waiting for animation', () async {
        // enterFullscreen 应立即返回，不等待 ~700ms delegate 回调
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

    // ─── 原生回调桥接 (D-P09) ───

    group('native callback bridge (D-P09)', () {
      test('forwards plugin onFullScreenChanged to onNativeStateChanged',
          () async {
        final List<(int, bool)> callbacks = [];
        driver.onNativeStateChanged = (windowId, isFullscreen) {
          callbacks.add((windowId, isFullscreen));
        };

        // 模拟 NSWindowDelegate windowDidEnterFullScreen 回调
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

        // 模拟 NSWindowDelegate windowDidExitFullScreen 回调
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
      test('returns macOS-specific capability values', () {
        final caps = driver.capabilities();

        expect(caps.supportsFullscreen, isTrue);
        expect(caps.supportsMultiDisplay, isTrue);
        expect(caps.supportsMultiWindow, isFalse);
        expect(caps.supportsExclusive, isFalse);
        expect(caps.requiresUserGesture, isFalse);
      });

      test('platformNotes describes native macOS behavior', () {
        final caps = driver.capabilities();

        expect(caps.platformNotes, contains('Native macOS fullscreen'));
        expect(caps.platformNotes, contains('NSWindow delegate'));
        expect(caps.platformNotes, contains('700ms'));
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
  });
}
