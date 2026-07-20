import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/perf_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PerfMonitor', () {
    late PerfMonitor monitor;

    setUp(() {
      monitor = PerfMonitor.instance;
      monitor.reset();
    });

    test('exportStats returns empty map when no frames recorded', () {
      final stats = monitor.exportStats();
      expect(stats, isEmpty);
    });

    test('reset clears all state', () {
      monitor.reset();
      final stats = monitor.exportStats();
      expect(stats, isEmpty);
    });

    test('reset is idempotent', () {
      monitor.reset();
      monitor.reset();
      final stats = monitor.exportStats();
      expect(stats, isEmpty);
    });
  });

  group('PerfMonitor singleton', () {
    test('instance returns same object', () {
      final a = PerfMonitor.instance;
      final b = PerfMonitor.instance;
      expect(identical(a, b), isTrue);
    });

    test('instance is PerfMonitor type', () {
      expect(PerfMonitor.instance, isA<PerfMonitor>());
    });
  });

  group('PerfMonitor reset', () {
    late PerfMonitor monitor;

    setUp(() {
      monitor = PerfMonitor.instance;
    });

    test('reset can be called multiple times safely', () {
      expect(() {
        monitor.reset();
        monitor.reset();
        monitor.reset();
      }, returnsNormally);
    });

    test('exportStats after reset returns empty', () {
      monitor.reset();
      final stats = monitor.exportStats();
      expect(stats, isEmpty);
    });

    test('reset followed by exportStats has zero frame count', () {
      monitor.reset();
      final stats = monitor.exportStats();
      expect(stats.containsKey('frameCount'), isFalse);
    });
  });

  group('PerfMonitor exportStats', () {
    late PerfMonitor monitor;

    setUp(() {
      monitor = PerfMonitor.instance;
      monitor.reset();
    });

    test('exportStats returns Map type', () {
      final stats = monitor.exportStats();
      expect(stats, isA<Map<String, dynamic>>());
    });

    test('exportStats with no frames has no keys', () {
      final stats = monitor.exportStats();
      expect(stats.keys, isEmpty);
    });
  });

  group('PerfMonitor enable/disable', () {
    late PerfMonitor monitor;

    setUp(() {
      monitor = PerfMonitor.instance;
      monitor.reset();
    });

    test('enable does not throw', () {
      expect(() => monitor.enable(), returnsNormally);
      monitor.disable();
    });

    test('enable followed by disable does not throw', () {
      monitor.enable();
      expect(() => monitor.disable(), returnsNormally);
    });

    test('double enable is idempotent', () {
      monitor.enable();
      expect(() => monitor.enable(), returnsNormally);
      monitor.disable();
    });
  });
}
