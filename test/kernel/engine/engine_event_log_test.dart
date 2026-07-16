/// Unit tests for [EngineEvent] and [EngineEventLog].
///
/// Covers: event construction, toJson, toString, ring buffer add/entries/clear,
/// wraparound behavior, capacity edge cases.
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
  });
}
