import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/window/aspect_ratio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AspectRatioService singleton', () {
    test('I returns same instance', () {
      final a = AspectRatioService.I;
      final b = AspectRatioService.I;
      expect(identical(a, b), isTrue);
    });

    test('initial current ratio is 0', () {
      // Must run before other tests modify state
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
      await service.setAspectRatio(1.5);
      calls.clear();

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
      await service.matchVideo(2.35);

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
      await service.setAspectRatio(1.5);
      calls.clear();

      await service.unlock();

      expect(calls, hasLength(1));
      expect(calls.first.method, 'setAspectRatio');
      expect(calls.first.arguments, 0.0);
      expect(service.current, 0.0);
    });

    test('setAspectRatio rolls back on platform exception', () async {
      await service.setAspectRatio(1.5);
      expect(service.current, 1.5);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.simple_player/aspect_ratio'),
            (MethodCall methodCall) async {
              throw PlatformException(code: 'ERROR', message: 'test error');
            },
          );

      await service.setAspectRatio(2.0);
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
    test('cycles through 16:9, 4:3, 21:9, free', () async {
      final service = AspectRatioService.I;
      final List<MethodCall> calls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.simple_player/aspect_ratio'),
            (MethodCall methodCall) async {
              calls.add(methodCall);
              return null;
            },
          );

      // Reset to known state
      await service.unlock();
      calls.clear();

      await service.cycleRatio();
      expect(service.current, closeTo(16.0 / 9.0, 0.01));

      await service.cycleRatio();
      expect(service.current, closeTo(4.0 / 3.0, 0.01));

      await service.cycleRatio();
      expect(service.current, closeTo(21.0 / 9.0, 0.01));

      await service.cycleRatio();
      expect(service.current, 0.0);

      // Wraps around
      await service.cycleRatio();
      expect(service.current, closeTo(16.0 / 9.0, 0.01));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.simple_player/aspect_ratio'),
            null,
          );
    });
  });

  group('AspectRatioService currentLabel', () {
    test('returns correct labels', () async {
      final service = AspectRatioService.I;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.simple_player/aspect_ratio'),
            (MethodCall methodCall) async => null,
          );

      await service.unlock();
      expect(service.currentLabel, '自由');

      await service.lock16x9();
      expect(service.currentLabel, '16:9');

      await service.lock4x3();
      expect(service.currentLabel, '4:3');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.simple_player/aspect_ratio'),
            null,
          );
    });
  });
}
