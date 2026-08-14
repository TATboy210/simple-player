/// [MetricSample] 和 [MemorySnapshot] 数据类单元测试。
///
/// Ports tests from test/kernel/utils/memory_monitor_test.dart to use
/// the new diagnostics/ import path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/memory_snapshot.dart';

void main() {
  group('MetricSample', () {
    test('stores rssBytes and timestamp', () {
      final ts = DateTime(2026, 7, 15, 12, 0);
      final sample = MetricSample(rssBytes: 1024, timestamp: ts);
      expect(sample.rssBytes, 1024);
      expect(sample.timestamp, ts);
    });

    test('toJson exports both fields', () {
      final ts = DateTime(2026, 7, 15, 12, 0, 0);
      final sample = MetricSample(rssBytes: 2048, timestamp: ts);
      final json = sample.toJson();
      expect(json['rssBytes'], 2048);
      expect(json['timestamp'], '2026-07-15T12:00:00.000');
    });
  });

  group('MemorySnapshot', () {
    test('stores all fields', () {
      final ts = DateTime(2026, 7, 15, 12, 0);
      final history = [
        MetricSample(rssBytes: 100, timestamp: ts),
        MetricSample(rssBytes: 200, timestamp: ts),
      ];
      final snap = MemorySnapshot(
        rssBytes: 200,
        maxRssBytes: 300,
        deltaBytes: 100,
        history: history,
        timestamp: ts,
      );
      expect(snap.rssBytes, 200);
      expect(snap.maxRssBytes, 300);
      expect(snap.deltaBytes, 100);
      expect(snap.history, hasLength(2));
      expect(snap.timestamp, ts);
    });

    test('toJson includes computed MB fields', () {
      final ts = DateTime(2026, 7, 15, 12, 0, 0);
      final snap = MemorySnapshot(
        rssBytes: 100 * 1024 * 1024,
        maxRssBytes: 150 * 1024 * 1024,
        deltaBytes: 10 * 1024 * 1024,
        history: [],
        timestamp: ts,
      );
      final json = snap.toJson();
      expect(json['rssBytes'], 100 * 1024 * 1024);
      expect(json['maxRssBytes'], 150 * 1024 * 1024);
      expect(json['deltaBytes'], 10 * 1024 * 1024);
      expect(json['rssMB'], '100.0');
      expect(json['maxRssMB'], '150.0');
      expect(json['historyCount'], 0);
      expect(json['history'], isEmpty);
      expect(json['timestamp'], '2026-07-15T12:00:00.000');
    });

    test('toJson includes history entries', () {
      final ts = DateTime(2026, 7, 15, 12, 0, 0);
      final history = [
        MetricSample(rssBytes: 100, timestamp: ts),
        MetricSample(rssBytes: 200, timestamp: ts),
      ];
      final snap = MemorySnapshot(
        rssBytes: 200,
        maxRssBytes: 200,
        deltaBytes: 100,
        history: history,
        timestamp: ts,
      );
      final json = snap.toJson();
      expect(json['historyCount'], 2);
      expect(json['history'], hasLength(2));
    });
  });
}
