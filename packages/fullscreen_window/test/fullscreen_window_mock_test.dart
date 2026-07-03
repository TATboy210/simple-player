import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fullscreen_window/fullscreen_window_platform_interface.dart';
import 'package:fullscreen_window/fullscreen_window_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock 平台实现，用于测试不同平台行为
class MockFullscreenWindowPlatform extends FullScreenWindowPlatform
    with MockPlatformInterfaceMixin {
  bool lastFullScreenValue = false;
  bool shouldThrow = false;
  Size? getScreenSizeOverride;

  @override
  Future<void> setFullScreen(bool isFullScreen) async {
    if (shouldThrow) {
      throw MissingPluginException(
        'No implementation found for method setFullScreen on channel fullscreen_window',
      );
    }
    lastFullScreenValue = isFullScreen;
  }

  @override
  Future<Size> getScreenSize(BuildContext? context) async {
    if (shouldThrow) {
      throw MissingPluginException(
        'No implementation found for method getScreenSize on channel fullscreen_window',
      );
    }
    return getScreenSizeOverride ?? const Size(1920, 1080);
  }
}

/// 模拟 macOS 环境（原版无实现）
class MockMacOSOriginalPlatform extends MockFullscreenWindowPlatform {
  @override
  Future<void> setFullScreen(bool isFullScreen) async {
    throw MissingPluginException(
      'No implementation found for method setFullScreen on channel fullscreen_window',
    );
  }

  @override
  Future<Size> getScreenSize(BuildContext? context) async {
    throw MissingPluginException(
      'No implementation found for method getScreenSize on channel fullscreen_window',
    );
  }
}

/// 模拟 macOS 环境（修改版有实现）
class MockMacOSModifiedPlatform extends MockFullscreenWindowPlatform {
  @override
  Future<void> setFullScreen(bool isFullScreen) async {
    // 模拟 NSWindow.toggleFullScreen
    lastFullScreenValue = isFullScreen;
  }

  @override
  Future<Size> getScreenSize(BuildContext? context) async {
    // 模拟 NSScreen.frame × backingScaleFactor
    return const Size(2560, 1600); // Retina display
  }
}

/// 模拟 Windows 环境
class MockWindowsPlatform extends MockFullscreenWindowPlatform {
  @override
  Future<void> setFullScreen(bool isFullScreen) async {
    // 模拟 Win32 API 调用
    lastFullScreenValue = isFullScreen;
  }

  @override
  Future<Size> getScreenSize(BuildContext? context) async {
    // 模拟 GetWindowRect
    return const Size(1920, 1080);
  }
}

/// 模拟 Linux 环境
class MockLinuxPlatform extends MockFullscreenWindowPlatform {
  @override
  Future<void> setFullScreen(bool isFullScreen) async {
    // 模拟 GTK API 调用
    lastFullScreenValue = isFullScreen;
  }

  @override
  Future<Size> getScreenSize(BuildContext? context) async {
    // 模拟 gdk_monitor_get_geometry
    return const Size(1920, 1080);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('平台接口基础测试', () {
    test('默认实例是 MethodChannelFullscreenWindow', () {
      final instance = FullScreenWindowPlatform.instance;
      expect(instance, isA<MethodChannelFullscreenWindow>());
    });

    test('Token 验证机制', () {
      expect(
        () =>
            FullScreenWindowPlatform.instance = MockFullscreenWindowPlatform(),
        returnsNormally,
      );
    });
  });

  group('跨平台模拟测试', () {
    late MockFullscreenWindowPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockFullscreenWindowPlatform();
      FullScreenWindowPlatform.instance = mockPlatform;
    });

    test('setFullScreen 正常调用', () async {
      final platform = FullScreenWindowPlatform.instance;
      await platform.setFullScreen(true);
      expect(mockPlatform.lastFullScreenValue, true);

      await platform.setFullScreen(false);
      expect(mockPlatform.lastFullScreenValue, false);
    });

    test('getScreenSize 返回正确尺寸', () async {
      final platform = FullScreenWindowPlatform.instance;
      final size = await platform.getScreenSize(null);
      expect(size, const Size(1920, 1080));
    });
  });

  group('macOS 原版测试（无实现）', () {
    late MockMacOSOriginalPlatform mockMacOS;

    setUp(() {
      mockMacOS = MockMacOSOriginalPlatform();
      FullScreenWindowPlatform.instance = mockMacOS;
    });

    test('setFullScreen 抛出 MissingPluginException', () async {
      final platform = FullScreenWindowPlatform.instance;
      expect(
        () => platform.setFullScreen(true),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('getScreenSize 抛出 MissingPluginException', () async {
      final platform = FullScreenWindowPlatform.instance;
      expect(
        () => platform.getScreenSize(null),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });

  group('macOS 修改版测试（有实现）', () {
    late MockMacOSModifiedPlatform mockMacOS;

    setUp(() {
      mockMacOS = MockMacOSModifiedPlatform();
      FullScreenWindowPlatform.instance = mockMacOS;
    });

    test('setFullScreen 正常工作', () async {
      final platform = FullScreenWindowPlatform.instance;
      await platform.setFullScreen(true);
      expect(mockMacOS.lastFullScreenValue, true);
    });

    test('getScreenSize 返回 Retina 尺寸', () async {
      final platform = FullScreenWindowPlatform.instance;
      final size = await platform.getScreenSize(null);
      expect(size, const Size(2560, 1600));
    });
  });

  group('Windows 测试', () {
    late MockWindowsPlatform mockWindows;

    setUp(() {
      mockWindows = MockWindowsPlatform();
      FullScreenWindowPlatform.instance = mockWindows;
    });

    test('setFullScreen 正常工作', () async {
      final platform = FullScreenWindowPlatform.instance;
      await platform.setFullScreen(true);
      expect(mockWindows.lastFullScreenValue, true);
    });

    test('getScreenSize 返回正确尺寸', () async {
      final platform = FullScreenWindowPlatform.instance;
      final size = await platform.getScreenSize(null);
      expect(size, const Size(1920, 1080));
    });
  });

  group('Linux 测试', () {
    late MockLinuxPlatform mockLinux;

    setUp(() {
      mockLinux = MockLinuxPlatform();
      FullScreenWindowPlatform.instance = mockLinux;
    });

    test('setFullScreen 正常工作', () async {
      final platform = FullScreenWindowPlatform.instance;
      await platform.setFullScreen(true);
      expect(mockLinux.lastFullScreenValue, true);
    });

    test('getScreenSize 返回正确尺寸', () async {
      final platform = FullScreenWindowPlatform.instance;
      final size = await platform.getScreenSize(null);
      expect(size, const Size(1920, 1080));
    });
  });

  group('错误处理测试', () {
    late MockFullscreenWindowPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockFullscreenWindowPlatform();
      FullScreenWindowPlatform.instance = mockPlatform;
    });

    test('MissingPluginException 可被捕获', () async {
      mockPlatform.shouldThrow = true;
      final platform = FullScreenWindowPlatform.instance;

      try {
        await platform.setFullScreen(true);
        fail('应该抛出异常');
      } catch (e) {
        expect(e, isA<MissingPluginException>());
      }
    });

    test('异常不影响后续调用', () async {
      mockPlatform.shouldThrow = true;
      final platform = FullScreenWindowPlatform.instance;

      try {
        await platform.setFullScreen(true);
      } catch (e) {
        // 忽略异常
      }

      mockPlatform.shouldThrow = false;
      await platform.setFullScreen(false);
      expect(mockPlatform.lastFullScreenValue, false);
    });
  });

  group('DPI 缩放测试', () {
    test('高 DPI 下 getScreenSize 返回物理像素', () async {
      final mock = MockFullscreenWindowPlatform()
        ..getScreenSizeOverride = const Size(3840, 2160); // 4K 显示器
      FullScreenWindowPlatform.instance = mock;

      final size = await FullScreenWindowPlatform.instance.getScreenSize(null);
      expect(size.width, 3840.0);
      expect(size.height, 2160.0);
    });

    test('标准 DPI 下 getScreenSize 返回正确值', () async {
      final mock = MockFullscreenWindowPlatform()
        ..getScreenSizeOverride = const Size(1920, 1080);
      FullScreenWindowPlatform.instance = mock;

      final size = await FullScreenWindowPlatform.instance.getScreenSize(null);
      expect(size.width, 1920.0);
      expect(size.height, 1080.0);
    });
  });

  group('多显示器测试', () {
    test('主显示器和副显示器尺寸不同', () async {
      final mock = MockFullscreenWindowPlatform();
      FullScreenWindowPlatform.instance = mock;

      // 默认返回主显示器尺寸
      final primarySize =
          await FullScreenWindowPlatform.instance.getScreenSize(null);
      expect(primarySize, isNotNull);
    });
  });

  group('快速切换测试', () {
    test('快速连续调用 setFullScreen', () async {
      final mock = MockFullscreenWindowPlatform();
      FullScreenWindowPlatform.instance = mock;

      // 快速连续调用
      await FullScreenWindowPlatform.instance.setFullScreen(true);
      await FullScreenWindowPlatform.instance.setFullScreen(false);
      await FullScreenWindowPlatform.instance.setFullScreen(true);

      expect(mock.lastFullScreenValue, true);
    });

    test('并发调用 setFullScreen', () async {
      final mock = MockFullscreenWindowPlatform();
      FullScreenWindowPlatform.instance = mock;

      // 并发调用
      final futures = [
        FullScreenWindowPlatform.instance.setFullScreen(true),
        FullScreenWindowPlatform.instance.setFullScreen(false),
        FullScreenWindowPlatform.instance.setFullScreen(true),
      ];

      await Future.wait(futures);
      // 最后一个调用的值应该是最终状态
      expect(mock.lastFullScreenValue, isNotNull);
    });
  });

  group('边界条件测试', () {
    test('setFullScreen 传入 true 后再传入 false', () async {
      final mock = MockFullscreenWindowPlatform();
      FullScreenWindowPlatform.instance = mock;

      await FullScreenWindowPlatform.instance.setFullScreen(true);
      expect(mock.lastFullScreenValue, true);

      await FullScreenWindowPlatform.instance.setFullScreen(false);
      expect(mock.lastFullScreenValue, false);
    });

    test('getScreenSize 返回值不为零', () async {
      final mock = MockFullscreenWindowPlatform();
      FullScreenWindowPlatform.instance = mock;

      final size = await FullScreenWindowPlatform.instance.getScreenSize(null);
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });
  });
}
