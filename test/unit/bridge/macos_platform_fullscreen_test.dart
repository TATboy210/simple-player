/// macOS 平台全屏单元测试 — 通过 TestDefaultBinaryMessengerBinding 模拟 MethodChannel。
///
/// 测试覆盖:
/// - enter() 调用 getWindowRect + enterFullscreen，返回正确快照
/// - exit() 调用 exitFullscreen
/// - requiresStyleSave = false
/// - getWindowRect 返回 null 时的默认值回退
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/macos/macos_platform_fullscreen.dart';
import 'package:simple_player_flutter/kernel/bridge/platform_fullscreen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MacosPlatformFullscreen platform;
  late List<MethodCall> calls;

  setUp(() {
    platform = MacosPlatformFullscreen();
    calls = [];
  });

  /// 注册 mock handler 模拟 Swift 端响应。
  void registerMockHandler({Map<String, double>? rect}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.simple_player/fullscreen'),
      (MethodCall call) async {
        calls.add(call);
        switch (call.method) {
          case 'getWindowRect':
            return rect;
          case 'enterFullscreen':
            return null;
          case 'exitFullscreen':
            return null;
          default:
            throw MissingPluginException('Unknown: ${call.method}');
        }
      },
    );
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.simple_player/fullscreen'),
      null,
    );
  });

  group('MacosPlatformFullscreen', () {
    test('requiresStyleSave is false', () {
      expect(platform.requiresStyleSave, isFalse);
    });

    test('enter() calls getWindowRect then enterFullscreen', () async {
      registerMockHandler(rect: {
        'x': 100.0,
        'y': 200.0,
        'width': 1920.0,
        'height': 1080.0,
      });

      final snapshot = await platform.enter();

      expect(calls, hasLength(2));
      expect(calls[0].method, 'getWindowRect');
      expect(calls[1].method, 'enterFullscreen');
      expect(snapshot.windowStyle, 0);
      expect(snapshot.position, const Offset(100, 200));
      expect(snapshot.size, const Size(1920, 1080));
    });

    test('enter() uses default rect when getWindowRect returns null', () async {
      registerMockHandler(rect: null);

      final snapshot = await platform.enter();

      expect(snapshot.position, Offset.zero);
      expect(snapshot.size, const Size(1280, 720));
    });

    test('exit() calls exitFullscreen', () async {
      registerMockHandler();
      const snapshot = FullscreenSnapshot(
        windowStyle: 0,
        position: Offset(100, 200),
        size: Size(1920, 1080),
      );

      platform.exit(snapshot);

      expect(calls, hasLength(1));
      expect(calls[0].method, 'exitFullscreen');
    });

    test('enter() propagates platform exceptions', () async {
      // 模拟 Swift 端 toggleFullScreen 失败
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.simple_player/fullscreen'),
        (MethodCall call) async {
          calls.add(call);
          if (call.method == 'getWindowRect') {
            return {'x': 0.0, 'y': 0.0, 'width': 800.0, 'height': 600.0};
          }
          if (call.method == 'enterFullscreen') {
            throw PlatformException(
              code: 'ERROR',
              message: 'toggleFullScreen failed',
            );
          }
          return null;
        },
      );

      expect(
        () => platform.enter(),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
