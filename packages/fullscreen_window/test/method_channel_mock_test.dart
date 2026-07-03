import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fullscreen_window/fullscreen_window_method_channel.dart';

/// Method Channel 级 Mock 测试
///
/// 在二进制层模拟各平台原生代码的返回值，比平台接口级 mock 更接近真实行为。
/// 可以验证：
/// - 参数传递是否正确（序列化/反序列化）
/// - 返回值解析是否正确
/// - 异常传播是否正确
/// - 各平台的实际返回格式差异
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFullscreenWindow();

  group('Method Channel — Windows 模拟', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          switch (call.method) {
            case 'setFullScreen':
              return null;
            case 'getScreenSize':
              return <String, dynamic>{'width': 1920, 'height': 1080};
            default:
              throw MissingPluginException(
                  'No implementation for ${call.method}');
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('setFullScreen 传递正确参数', () async {
      await platform.setFullScreen(true);
    });

    test('getScreenSize 返回正确尺寸', () async {
      final size = await platform.getScreenSize(null);
      expect(size.width, 1920.0);
      expect(size.height, 1080.0);
    });

    test('getScreenSize 高 DPI 场景', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          if (call.method == 'getScreenSize') {
            return <String, dynamic>{'width': 3840, 'height': 2160};
          }
          return null;
        },
      );

      final sizeWithoutContext = await platform.getScreenSize(null);
      expect(sizeWithoutContext.width, 3840.0);
      expect(sizeWithoutContext.height, 2160.0);
    });
  });

  group('Method Channel — Linux 模拟', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          switch (call.method) {
            case 'setFullScreen':
              return null;
            case 'getScreenSize':
              return <String, dynamic>{'width': 1920, 'height': 1080};
            default:
              throw MissingPluginException(
                  'No implementation for ${call.method}');
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('setFullScreen 正常工作', () async {
      await platform.setFullScreen(true);
      await platform.setFullScreen(false);
    });

    test('getScreenSize 返回主显示器尺寸', () async {
      final size = await platform.getScreenSize(null);
      expect(size.width, 1920.0);
      expect(size.height, 1080.0);
    });
  });

  group('Method Channel — macOS 修改版模拟', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          switch (call.method) {
            case 'setFullScreen':
              return null;
            case 'getScreenSize':
              return <String, dynamic>{'width': 2560, 'height': 1600};
            default:
              throw MissingPluginException(
                  'No implementation for ${call.method}');
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('setFullScreen 正常工作', () async {
      await platform.setFullScreen(true);
      await platform.setFullScreen(false);
    });

    test('getScreenSize 返回 Retina 尺寸', () async {
      final size = await platform.getScreenSize(null);
      expect(size.width, 2560.0);
      expect(size.height, 1600.0);
    });
  });

  group('Method Channel — macOS 原版模拟（无实现）', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          throw MissingPluginException(
            'No implementation found for method ${call.method} on channel fullscreen_window',
          );
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('setFullScreen 抛出 MissingPluginException', () async {
      expect(
        () => platform.setFullScreen(true),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('getScreenSize 抛出 MissingPluginException', () async {
      expect(
        () => platform.getScreenSize(null),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });

  group('Method Channel — 错误场景', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('平台返回 null 不崩溃', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async => null,
      );

      await platform.setFullScreen(true);
    });

    test('平台返回空 map 导致异常', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          if (call.method == 'getScreenSize') {
            return <String, dynamic>{};
          }
          return null;
        },
      );

      expect(
        () => platform.getScreenSize(null),
        throwsA(anything),
      );
    });

    test('PlatformException 正确传播', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          throw PlatformException(
            code: 'NO_WINDOW',
            message: 'No main window found',
            details: null,
          );
        },
      );

      expect(
        () => platform.setFullScreen(true),
        throwsA(isA<PlatformException>()),
      );
    });

    test('快速连续调用不冲突', () async {
      int callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          callCount++;
          return null;
        },
      );

      await Future.wait([
        platform.setFullScreen(true),
        platform.setFullScreen(false),
        platform.setFullScreen(true),
      ]);

      expect(callCount, 3);
    });
  });

  group('Method Channel — 参数验证', () {
    test('setFullScreen 传递布尔参数', () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          capturedCall = call;
          return null;
        },
      );

      await platform.setFullScreen(true);
      expect(capturedCall?.method, 'setFullScreen');
      expect(capturedCall?.arguments, {'isFullScreen': true});

      await platform.setFullScreen(false);
      expect(capturedCall?.arguments, {'isFullScreen': false});
    });

    test('getScreenSize 传递空参数', () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall call) async {
          capturedCall = call;
          return <String, dynamic>{'width': 1920, 'height': 1080};
        },
      );

      await platform.getScreenSize(null);
      expect(capturedCall?.method, 'getScreenSize');
      expect(capturedCall?.arguments, isA<Map>());
    });
  });
}
