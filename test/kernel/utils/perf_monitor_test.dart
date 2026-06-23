import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/perf_monitor.dart';

void main() {
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
}
