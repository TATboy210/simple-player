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

  group('AspectRatioService cycleRatio', () {
    late AspectRatioService service;
    final List<MethodCall> calls = [];

    setUp(() {
      service = AspectRatioService.I;
      calls.clear();
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

    test('cycleRatio from 16:9 goes to 4:3', () async {
      await service.setAspectRatio(16 / 9);
      calls.clear();

      await service.cycleRatio();

      expect(calls, hasLength(1));
      expect(calls.first.arguments, closeTo(4.0 / 3.0, 0.01));
    });

    test('cycleRatio from 4:3 goes to 21:9', () async {
      await service.setAspectRatio(4.0 / 3.0);
      calls.clear();

      await service.cycleRatio();

      expect(calls, hasLength(1));
      expect(calls.first.arguments, closeTo(21.0 / 9.0, 0.01));
    });

    test('cycleRatio from 21:9 goes to free (0.0)', () async {
      await service.setAspectRatio(21.0 / 9.0);
      calls.clear();

      await service.cycleRatio();

      expect(calls, hasLength(1));
      expect(calls.first.arguments, 0.0);
    });

    test('cycleRatio from free goes to 16:9', () async {
      await service.setAspectRatio(0.0);
      calls.clear();

      await service.cycleRatio();

      expect(calls, hasLength(1));
      expect(calls.first.arguments, closeTo(16.0 / 9.0, 0.01));
    });

    test('cycleRatio from unknown ratio goes to 16:9', () async {
      await service.setAspectRatio(2.35); // Cinema, not in cycle
      calls.clear();

      await service.cycleRatio();

      // Unknown ratio: indexOf returns -1, (-1+1) % 4 = 0 → ratio16x9
      expect(calls, hasLength(1));
      expect(calls.first.arguments, closeTo(16.0 / 9.0, 0.01));
    });
  });

  group('AspectRatioService currentLabel', () {
    late AspectRatioService service;
    final List<MethodCall> calls = [];

    setUp(() {
      service = AspectRatioService.I;
      calls.clear();
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

    test('currentLabel returns 自由 for 0.0', () async {
      await service.setAspectRatio(0.0);
      expect(service.currentLabel, '自由');
    });

    test('currentLabel returns 16:9 for 16/9', () async {
      await service.setAspectRatio(16 / 9);
      expect(service.currentLabel, '16:9');
    });

    test('currentLabel returns 4:3 for 4/3', () async {
      await service.setAspectRatio(4 / 3);
      expect(service.currentLabel, '4:3');
    });

    test('currentLabel returns 21:9 for 21/9', () async {
      await service.setAspectRatio(21 / 9);
      expect(service.currentLabel, '21:9');
    });

    test('currentLabel returns {ratio}:1 for custom ratio', () async {
      await service.setAspectRatio(2.35);
      expect(service.currentLabel, '2.35:1');
    });
  });

  group('AspectRatioService ratioNotifier', () {
    late AspectRatioService service;
    final List<MethodCall> calls = [];

    setUp(() {
      service = AspectRatioService.I;
      calls.clear();
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

    test('ratioNotifier fires on setAspectRatio', () async {
      final values = <double>[];
      service.ratioNotifier.addListener(() {
        values.add(service.ratioNotifier.value);
      });

      await service.setAspectRatio(1.5);

      expect(values, contains(1.5));
    });

    test('ratioNotifier fires on rollback', () async {
      await service.setAspectRatio(1.5);

      // Override with error handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.simple_player/aspect_ratio'),
            (MethodCall methodCall) async {
              throw PlatformException(code: 'ERROR', message: 'test');
            },
          );

      final values = <double>[];
      service.ratioNotifier.addListener(() {
        values.add(service.ratioNotifier.value);
      });

      await service.setAspectRatio(2.0);

      // Rollback should fire notifier with previous value (1.5)
      expect(values, contains(1.5));
    });
  });
}
