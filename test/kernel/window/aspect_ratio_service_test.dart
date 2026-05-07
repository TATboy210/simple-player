import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window/aspect_ratio_service.dart';

// WIN-03 (DPI adaptation): Verified manually.
// Native handler in win32_window.cpp processes WM_DPICHANGED with SetWindowPos.
// Flutter's PerMonitorV2 DPI awareness handles surface recreation automatically.
// Manual test: move window between monitors with different DPI, verify layout adapts.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AspectRatioService singleton', () {
    test('I returns same instance', () {
      final a = AspectRatioService.I;
      final b = AspectRatioService.I;
      expect(identical(a, b), isTrue);
    });

    test('initial current ratio is 0', () {
      expect(AspectRatioService.I.current, 0.0);
    });
  });

  group('AspectRatioService constants', () {
    test('ratio16x9 is correct', () {
      expect(AspectRatioService.ratio16x9, closeTo(16.0 / 9.0, 0.001));
    });

    test('ratio4x3 is correct', () {
      expect(AspectRatioService.ratio4x3, closeTo(4.0 / 3.0, 0.001));
    });
  });

  group('AspectRatioService MethodChannel', () {
    late AspectRatioService service;
    final List<MethodCall> calls = [];

    setUp(() {
      service = AspectRatioService.I;
      calls.clear();

      // Reset internal state by creating fresh mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.simple_player/aspect_ratio'),
        (MethodCall methodCall) async {
          calls.add(methodCall);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.simple_player/aspect_ratio'),
        null,
      );
    });

    test('setAspectRatio sends correct method call', () async {
      await service.setAspectRatio(1.5);

      expect(calls, hasLength(1));
      expect(calls.first.method, 'setAspectRatio');
      expect(calls.first.arguments, 1.5);
    });

    test('setAspectRatio updates current ratio', () async {
      await service.setAspectRatio(1.5);
      expect(service.current, 1.5);
    });

    test('setAspectRatio skips if ratio unchanged', () async {
      // First call sets current to 1.5
      await service.setAspectRatio(1.5);
      calls.clear();

      // Same ratio should be skipped
      await service.setAspectRatio(1.5);
      expect(calls, isEmpty);
    });

    test('lock16x9 sends 16:9 ratio', () async {
      await service.lock16x9();

      expect(calls, hasLength(1));
      expect(calls.first.method, 'setAspectRatio');
      expect(calls.first.arguments, closeTo(16.0 / 9.0, 0.001));
    });

    test('lock4x3 sends 4:3 ratio', () async {
      await service.lock4x3();

      expect(calls, hasLength(1));
      expect(calls.first.method, 'setAspectRatio');
      expect(calls.first.arguments, closeTo(4.0 / 3.0, 0.001));
    });

    test('matchVideo sends video ratio', () async {
      await service.matchVideo(2.35); // Cinema aspect ratio

      expect(calls, hasLength(1));
      expect(calls.first.method, 'setAspectRatio');
      expect(calls.first.arguments, 2.35);
    });

    test('matchVideo with zero ratio is no-op', () async {
      await service.matchVideo(0);
      expect(calls, isEmpty);
    });

    test('matchVideo with negative ratio is no-op', () async {
      await service.matchVideo(-1);
      expect(calls, isEmpty);
    });

    test('unlock sends 0 to remove constraint', () async {
      // First set a ratio
      await service.setAspectRatio(1.5);
      calls.clear();

      await service.unlock();

      expect(calls, hasLength(1));
      expect(calls.first.method, 'setAspectRatio');
      expect(calls.first.arguments, 0.0);
      expect(service.current, 0.0);
    });

    test('setAspectRatio rolls back on platform exception', () async {
      // First set a known ratio
      await service.setAspectRatio(1.5);
      expect(service.current, 1.5);

      // Override with error handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.simple_player/aspect_ratio'),
        (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR', message: 'test error');
        },
      );

      // Should not throw, but should roll back
      await service.setAspectRatio(2.0);
      // RC-6: current should roll back to previous value on failure
      expect(service.current, 1.5);
    });

    test('multiple ratio changes track current correctly', () async {
      await service.setAspectRatio(1.0);
      expect(service.current, 1.0);

      await service.setAspectRatio(1.5);
      expect(service.current, 1.5);

      await service.setAspectRatio(2.0);
      expect(service.current, 2.0);

      expect(calls, hasLength(3));
    });
  });
}
