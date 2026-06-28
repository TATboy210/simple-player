import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/memory_monitor.dart';

void main() {
  group('MemoryMonitor', () {
    tearDown(() {
      MemoryMonitor.stop();
    });

    group('lifecycle', () {
      test('start does not throw', () {
        expect(() => MemoryMonitor.start(), returnsNormally);
      });

      test('stop does not throw without prior start', () {
        expect(() => MemoryMonitor.stop(), returnsNormally);
      });

      test('start followed by stop does not throw', () {
        MemoryMonitor.start();
        expect(() => MemoryMonitor.stop(), returnsNormally);
      });

      test('calling start twice is idempotent', () {
        MemoryMonitor.start();
        expect(() => MemoryMonitor.start(), returnsNormally);
      });

      test('calling stop twice is idempotent', () {
        MemoryMonitor.start();
        MemoryMonitor.stop();
        expect(() => MemoryMonitor.stop(), returnsNormally);
      });

      test('can restart after stop', () {
        MemoryMonitor.start();
        MemoryMonitor.stop();
        expect(() => MemoryMonitor.start(), returnsNormally);
      });
    });

    group('snapshot', () {
      test('returns null before start', () {
        final snap = MemoryMonitor.snapshot();
        expect(snap, isNull);
      });

      test('returns non-null snapshot after start', () {
        MemoryMonitor.start();
        final snap = MemoryMonitor.snapshot();
        expect(snap, isNotNull);
        expect(snap!.rssBytes, greaterThan(0));
        expect(snap.maxRssBytes, greaterThan(0));
        expect(snap.history, isNotEmpty);
      });

      test('history contains at least one sample after start', () {
        MemoryMonitor.start();
        final snap = MemoryMonitor.snapshot();
        expect(snap!.history.length, greaterThanOrEqualTo(1));
      });

      test('peak rss is at least as large as current rss', () {
        MemoryMonitor.start();
        final snap = MemoryMonitor.snapshot();
        expect(snap!.maxRssBytes, greaterThanOrEqualTo(snap.rssBytes));
      });
    });

    group('exportJson', () {
      test('returns empty JSON before start', () {
        final json = MemoryMonitor.exportJson();
        expect(json, '{}');
      });

      test('returns valid JSON after start', () {
        MemoryMonitor.start();
        final jsonStr = MemoryMonitor.exportJson();
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        expect(parsed.containsKey('rssBytes'), isTrue);
        expect(parsed.containsKey('maxRssBytes'), isTrue);
        expect(parsed.containsKey('history'), isTrue);
        expect(parsed.containsKey('timestamp'), isTrue);
      });

      test('JSON history is a list', () {
        MemoryMonitor.start();
        final jsonStr = MemoryMonitor.exportJson();
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        expect(parsed['history'], isA<List>());
      });

      test('JSON rssMB is a string', () {
        MemoryMonitor.start();
        final jsonStr = MemoryMonitor.exportJson();
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        expect(parsed['rssMB'], isA<String>());
      });
    });

    group('MetricSample', () {
      test('toJson contains expected fields', () {
        final sample = MetricSample(
          rssBytes: 1024 * 1024,
          timestamp: DateTime(2026, 6, 28, 12, 0, 0),
        );
        final json = sample.toJson();
        expect(json['rssBytes'], 1024 * 1024);
        expect(json.containsKey('timestamp'), isTrue);
      });
    });

    group('MemorySnapshot', () {
      test('toJson contains all fields', () {
        final snap = MemorySnapshot(
          rssBytes: 100 * 1024 * 1024,
          maxRssBytes: 150 * 1024 * 1024,
          deltaBytes: 10 * 1024 * 1024,
          history: const [],
          timestamp: DateTime(2026, 6, 28, 12, 0, 0),
        );
        final json = snap.toJson();
        expect(json['rssBytes'], 100 * 1024 * 1024);
        expect(json['maxRssBytes'], 150 * 1024 * 1024);
        expect(json['deltaBytes'], 10 * 1024 * 1024);
        expect(json['rssMB'], isA<String>());
        expect(json['maxRssMB'], isA<String>());
        expect(json['historyCount'], 0);
        expect(json['history'], isA<List>());
      });
    });

    group('onTick callback', () {
      test('is called after start', () async {
        MemorySnapshot? received;
        MemoryMonitor.start(
          interval: const Duration(milliseconds: 50),
          onTick: (snap) => received = snap,
        );
        // 等待至少一个 tick
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(received, isNotNull);
        expect(received!.rssBytes, greaterThan(0));
      });
    });

    group('history capacity', () {
      test('history does not exceed 200 entries', () {
        MemoryMonitor.start();
        final snap = MemoryMonitor.snapshot();
        expect(snap!.history.length, lessThanOrEqualTo(200));
      });
    });
  });
}
