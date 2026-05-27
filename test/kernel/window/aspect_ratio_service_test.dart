import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/window/aspect_ratio_service.dart';

// WIN-03 (DPI adaptation): Verified manually.
// Native handler in win32_window.cpp processes WM_DPICHANGED with SetWindowPos.
// Flutter's PerMonitorV2 DPI awareness handles surface recreation automatically.
// Manual test: move window between monitors with different DPI, verify layout adapts.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AspectRatioService constants', () {
    test('ratio16x9 is correct', () {
      expect(AspectRatioService.ratio16x9, closeTo(16.0 / 9.0, 0.001));
    });

    test('ratio4x3 is correct', () {
      expect(AspectRatioService.ratio4x3, closeTo(4.0 / 3.0, 0.001));
    });
  });

  group('AspectRatioService', () {
    late AspectRatioService service;
    late List<double> applied;

    setUp(() {
      applied = [];
      service = AspectRatioService.test((ratio) async {
        applied.add(ratio);
      });
    });

    tearDown(() {
      service.dispose();
    });

    test('initial current ratio is 0', () {
      expect(service.current, 0.0);
    });

    test('setAspectRatio updates current ratio', () async {
      await service.setAspectRatio(1.5);
      expect(service.current, 1.5);
    });

    test('setAspectRatio sends ratio to apply function', () async {
      await service.setAspectRatio(1.5);
      expect(applied, [1.5]);
    });

    test('setAspectRatio skips if ratio unchanged', () async {
      await service.setAspectRatio(1.5);
      applied.clear();

      await service.setAspectRatio(1.5);
      expect(applied, isEmpty);
    });

    test('lock16x9 sends 16:9 ratio', () async {
      await service.lock16x9();
      expect(applied, hasLength(1));
      expect(applied.first, closeTo(16.0 / 9.0, 0.001));
    });

    test('lock4x3 sends 4:3 ratio', () async {
      await service.lock4x3();
      expect(applied, hasLength(1));
      expect(applied.first, closeTo(4.0 / 3.0, 0.001));
    });

    test('matchVideo sends video ratio', () async {
      await service.matchVideo(2.35);
      expect(applied, [2.35]);
    });

    test('matchVideo with zero ratio is no-op', () async {
      await service.matchVideo(0);
      expect(applied, isEmpty);
    });

    test('matchVideo with negative ratio is no-op', () async {
      await service.matchVideo(-1);
      expect(applied, isEmpty);
    });

    test('unlock sends 0 to remove constraint', () async {
      await service.setAspectRatio(1.5);
      applied.clear();

      await service.unlock();

      expect(applied, [0.0]);
      expect(service.current, 0.0);
    });

    test('setAspectRatio rolls back on exception', () async {
      // Create service that throws
      final failService = AspectRatioService.test((ratio) async {
        throw Exception('platform error');
      });

      await failService.setAspectRatio(1.5);
      // Should roll back to 0.0
      expect(failService.current, 0.0);
      failService.dispose();
    });

    test('multiple ratio changes track current correctly', () async {
      await service.setAspectRatio(1.0);
      expect(service.current, 1.0);

      await service.setAspectRatio(1.5);
      expect(service.current, 1.5);

      await service.setAspectRatio(2.0);
      expect(service.current, 2.0);

      expect(applied, [1.0, 1.5, 2.0]);
    });
  });

  group('AspectRatioService currentLabel', () {
    late AspectRatioService service;

    setUp(() {
      service = AspectRatioService.test((_) async {});
    });

    tearDown(() {
      service.dispose();
    });

    test('returns 自由 for 0.0', () {
      expect(service.currentLabel, '自由');
    });

    test('returns 16:9 for 16/9', () async {
      await service.setAspectRatio(16 / 9);
      expect(service.currentLabel, '16:9');
    });

    test('returns 4:3 for 4/3', () async {
      await service.setAspectRatio(4 / 3);
      expect(service.currentLabel, '4:3');
    });

    test('returns 21:9 for 21/9', () async {
      await service.setAspectRatio(21 / 9);
      expect(service.currentLabel, '21:9');
    });

    test('returns {ratio}:1 for custom ratio', () async {
      await service.setAspectRatio(2.35);
      expect(service.currentLabel, '2.35:1');
    });
  });

  group('AspectRatioService ratioNotifier', () {
    late AspectRatioService service;

    setUp(() {
      service = AspectRatioService.test((_) async {});
    });

    tearDown(() {
      service.dispose();
    });

    test('fires on setAspectRatio', () async {
      final values = <double>[];
      service.ratioNotifier.addListener(() {
        values.add(service.ratioNotifier.value);
      });

      await service.setAspectRatio(1.5);
      expect(values, contains(1.5));
    });

    test('fires on rollback', () async {
      var shouldThrow = false;
      final failService = AspectRatioService.test((ratio) async {
        if (shouldThrow) throw Exception('fail');
      });

      await failService.setAspectRatio(1.5);
      shouldThrow = true;

      final values = <double>[];
      failService.ratioNotifier.addListener(() {
        values.add(failService.ratioNotifier.value);
      });

      await failService.setAspectRatio(2.0);
      // Rollback fires notifier with previous value (1.5)
      expect(values, contains(1.5));
      failService.dispose();
    });
  });
}
