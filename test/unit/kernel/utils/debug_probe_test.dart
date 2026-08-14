import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/debug_probe.dart';

void main() {
  group('ProbeEvent', () {
    test('toJson contains label and timestamp', () {
      final event = ProbeEvent(
        label: 'test',
        timestamp: DateTime(2026, 6, 28, 12, 0, 0),
      );
      final json = event.toJson();
      expect(json['label'], 'test');
      expect(json.containsKey('timestamp'), isTrue);
    });

    test('toJson includes elapsed when present', () {
      final event = ProbeEvent(
        label: 'test',
        timestamp: DateTime(2026, 6, 28, 12, 0, 0),
        elapsed: const Duration(milliseconds: 42),
      );
      final json = event.toJson();
      expect(json['elapsedUs'], 42000);
      expect(json['elapsedMs'], closeTo(42.0, 0.1));
    });

    test('toJson excludes elapsed when null', () {
      final event = ProbeEvent(
        label: 'test',
        timestamp: DateTime(2026, 6, 28, 12, 0, 0),
      );
      final json = event.toJson();
      expect(json.containsKey('elapsedUs'), isFalse);
    });

    test('toJson includes data when present', () {
      final event = ProbeEvent(
        label: 'test',
        timestamp: DateTime(2026, 6, 28, 12, 0, 0),
        data: {'key': 'value'},
      );
      final json = event.toJson();
      expect(json['data'], {'key': 'value'});
    });
  });

  group('DebugProbe', () {
    test('measure returns function result', () {
      final probe = DebugProbe('test');
      final result = probe.measure('add', () => 1 + 2);
      expect(result, 3);
    });

    test('measure records event with elapsed time', () {
      final probe = DebugProbe('test');
      probe.measure('work', () {
        // 模拟一些工作
        for (var i = 0; i < 1000; i++) {}
      });
      expect(probe.eventCount, 1);
      expect(probe.events.first.label, 'work');
      expect(probe.events.first.elapsed, isNotNull);
    });

    test('measureAsync returns future result', () async {
      final probe = DebugProbe('test');
      final result = await probe.measureAsync('fetch', () async => 42);
      expect(result, 42);
    });

    test('measureAsync records event', () async {
      final probe = DebugProbe('test');
      await probe.measureAsync('fetch', () async {});
      expect(probe.eventCount, 1);
      expect(probe.events.first.elapsed, isNotNull);
    });

    test('record adds event without elapsed', () {
      final probe = DebugProbe('test');
      probe.record('stateChanged', {'from': 'idle', 'to': 'playing'});
      expect(probe.eventCount, 1);
      expect(probe.events.first.elapsed, isNull);
      expect(probe.events.first.data, {'from': 'idle', 'to': 'playing'});
    });

    test('record without data works', () {
      final probe = DebugProbe('test');
      probe.record('tick');
      expect(probe.eventCount, 1);
      expect(probe.events.first.data, isNull);
    });

    test('events list is unmodifiable', () {
      final probe = DebugProbe('test');
      probe.record('a');
      expect(
        () =>
            probe.events.add(ProbeEvent(label: 'b', timestamp: DateTime.now())),
        throwsUnsupportedError,
      );
    });

    test('clear removes all events', () {
      final probe = DebugProbe('test');
      probe.record('a');
      probe.record('b');
      expect(probe.eventCount, 2);
      probe.clear();
      expect(probe.eventCount, 0);
    });

    test('exportJson returns valid JSON', () {
      final probe = DebugProbe('test');
      probe.record('a');
      final json = probe.exportJson();
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['name'], 'test');
      expect(parsed['eventCount'], 1);
      expect(parsed['events'], isA<List<dynamic>>());
    });

    test('eventCount reflects events', () {
      final probe = DebugProbe('test');
      expect(probe.eventCount, 0);
      probe.record('a');
      expect(probe.eventCount, 1);
      probe.record('b');
      expect(probe.eventCount, 2);
    });
  });

  group('DebugProbeRegistry', () {
    tearDown(() {
      DebugProbeRegistry.clearAll();
    });

    test('register creates new probe', () {
      final probe = DebugProbeRegistry.register('test');
      expect(probe.name, 'test');
      expect(probe.eventCount, 0);
    });

    test('register returns existing probe for same name', () {
      final probe1 = DebugProbeRegistry.register('test');
      probe1.record('a');
      final probe2 = DebugProbeRegistry.register('test');
      expect(identical(probe1, probe2), isTrue);
      expect(probe2.eventCount, 1);
    });

    test('lookup returns probe by name', () {
      DebugProbeRegistry.register('test');
      final found = DebugProbeRegistry.lookup('test');
      expect(found, isNotNull);
      expect(found!.name, 'test');
    });

    test('lookup returns null for unknown name', () {
      expect(DebugProbeRegistry.lookup('unknown'), isNull);
    });

    test('all returns all registered probes', () {
      DebugProbeRegistry.register('a');
      DebugProbeRegistry.register('b');
      expect(DebugProbeRegistry.all.length, 2);
    });

    test('summary returns map of probe stats', () {
      final probe = DebugProbeRegistry.register('test');
      probe.record('event');
      final summary = DebugProbeRegistry.summary();
      expect(summary.containsKey('test'), isTrue);
      expect(summary['test']!['eventCount'], 1);
    });

    test('exportAllJson returns valid JSON', () {
      DebugProbeRegistry.register('a').record('event');
      final json = DebugProbeRegistry.exportAllJson();
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed.containsKey('probes'), isTrue);
      expect(parsed.containsKey('summary'), isTrue);
      expect(parsed.containsKey('exportedAt'), isTrue);
    });

    test('clearAll removes all probes and events', () {
      DebugProbeRegistry.register('a').record('event');
      DebugProbeRegistry.register('b').record('event');
      DebugProbeRegistry.clearAll();
      expect(DebugProbeRegistry.all, isEmpty);
    });
  });
}
