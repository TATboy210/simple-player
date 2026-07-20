/// Unit tests for [EngineEvent] and [EngineEventLog].
///
/// Covers: event construction, toJson, toString, ring buffer add/entries/clear,
/// wraparound behavior, capacity edge cases.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_event_log.dart';

void main() {
  group('EngineEvent', () {
    test('stores type and timestamp', () {
      final now = DateTime(2026, 7, 15, 12, 0);
      final event = EngineEvent(type: 'play', timestamp: now);
      expect(event.type, 'play');
      expect(event.timestamp, now);
      expect(event.data, isNull);
    });

    test('stores optional data', () {
      final now = DateTime(2026, 7, 15, 12, 0);
      final event = EngineEvent(
        type: 'seek',
        timestamp: now,
        data: {'position': 5000},
      );
      expect(event.data, {'position': 5000});
    });

    test('toJson includes type and ISO timestamp', () {
      final now = DateTime(2026, 7, 15, 12, 0, 0);
      final event = EngineEvent(type: 'open', timestamp: now);
      final json = event.toJson();
      expect(json['type'], 'open');
      expect(json['timestamp'], '2026-07-15T12:00:00.000');
      expect(json.containsKey('data'), isFalse);
    });

    test('toJson includes data when present', () {
      final now = DateTime(2026, 7, 15, 12, 0);
      final event = EngineEvent(
        type: 'error',
        timestamp: now,
        data: {'message': 'codec not found'},
      );
      final json = event.toJson();
      expect(json['data'], {'message': 'codec not found'});
    });

    test('toString shows type and timestamp', () {
      final now = DateTime(2026, 7, 15, 12, 0);
      final event = EngineEvent(type: 'pause', timestamp: now);
      expect(event.toString(), 'EngineEvent(pause, 2026-07-15 12:00:00.000)');
    });
  });

  group('EngineEventLog', () {
    late EngineEventLog log;

    setUp(() {
      log = EngineEventLog();
    });

    group('initial state', () {
      test('starts empty', () {
        expect(log.length, 0);
        expect(log.isEmpty, isTrue);
        expect(log.isFull, isFalse);
      });

      test('entries returns empty list', () {
        expect(log.entries, isEmpty);
      });
    });

    group('add', () {
      test('increments length', () {
        log.add('play');
        expect(log.length, 1);
        expect(log.isEmpty, isFalse);
      });

      test('adds event with data', () {
        log.add('seek', {'position': 1000});
        expect(log.length, 1);
        expect(log.entries.first.data, {'position': 1000});
      });

      test('adds multiple events', () {
        log.add('open');
        log.add('play');
        log.add('pause');
        expect(log.length, 3);
      });
    });

    group('entries ordering', () {
      test('returns events from oldest to newest', () {
        log.add('first');
        log.add('second');
        log.add('third');
        final entries = log.entries;
        expect(entries[0].type, 'first');
        expect(entries[1].type, 'second');
        expect(entries[2].type, 'third');
      });
    });

    group('ring buffer wraparound', () {
      test('overwrites oldest when capacity reached', () {
        final smallLog = EngineEventLog(capacity: 3);
        smallLog.add('a');
        smallLog.add('b');
        smallLog.add('c');
        expect(smallLog.length, 3);
        expect(smallLog.isFull, isTrue);

        smallLog.add('d');
        expect(smallLog.length, 3);
        final entries = smallLog.entries;
        expect(entries[0].type, 'b');
        expect(entries[1].type, 'c');
        expect(entries[2].type, 'd');
      });

      test('maintains order after multiple wraps', () {
        final smallLog = EngineEventLog(capacity: 2);
        smallLog.add('a');
        smallLog.add('b');
        smallLog.add('c'); // overwrites a
        smallLog.add('d'); // overwrites b
        expect(smallLog.length, 2);
        final entries = smallLog.entries;
        expect(entries[0].type, 'c');
        expect(entries[1].type, 'd');
      });
    });

    group('clear', () {
      test('resets to empty state', () {
        log.add('play');
        log.add('pause');
        log.clear();
        expect(log.length, 0);
        expect(log.isEmpty, isTrue);
        expect(log.isFull, isFalse);
        expect(log.entries, isEmpty);
      });

      test('allows adding after clear', () {
        log.add('play');
        log.clear();
        log.add('new');
        expect(log.length, 1);
        expect(log.entries.first.type, 'new');
      });
    });

    group('toJson', () {
      test('exports all events', () {
        log.add('play');
        log.add('pause');
        final json = log.toJson();
        expect(json, hasLength(2));
        expect(json[0]['type'], 'play');
        expect(json[1]['type'], 'pause');
      });

      test('returns empty list when empty', () {
        expect(log.toJson(), isEmpty);
      });
    });

    group('defaultCapacity', () {
      test('is 100', () {
        expect(EngineEventLog.defaultCapacity, 100);
      });

      test('default log has capacity 100', () {
        expect(log.capacity, 100);
      });
    });

    group('custom capacity', () {
      test('accepts custom capacity', () {
        final customLog = EngineEventLog(capacity: 5);
        expect(customLog.capacity, 5);
      });

      test('custom capacity limits entries', () {
        final customLog = EngineEventLog(capacity: 3);
        customLog.add('a');
        customLog.add('b');
        customLog.add('c');
        customLog.add('d'); // overwrites 'a'
        expect(customLog.length, 3);
        expect(customLog.entries.first.type, 'b');
      });
    });

    group('add with data', () {
      test('data is preserved in entries', () {
        log.add('seek', {'position': 5000, 'duration': 10000});
        final entry = log.entries.first;
        expect(entry.data, {'position': 5000, 'duration': 10000});
      });

      test('data is included in toJson', () {
        log.add('error', {'message': 'codec not found'});
        final json = log.toJson();
        expect(json.first['data'], {'message': 'codec not found'});
      });
    });

    group('clear idempotency', () {
      test('clear on empty log is no-op', () {
        log.clear();
        expect(log.isEmpty, isTrue);
        log.clear();
        expect(log.isEmpty, isTrue);
      });
    });

    group('isFull', () {
      test('isFull is false when not at capacity', () {
        log.add('test');
        expect(log.isFull, isFalse);
      });

      test('isFull is true at capacity', () {
        final smallLog = EngineEventLog(capacity: 2);
        smallLog.add('a');
        smallLog.add('b');
        expect(smallLog.isFull, isTrue);
      });
    });
  });
}
