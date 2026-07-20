/// Diagnostics small modules unit tests — pure Dart, no mdk.dll dependency.
///
/// Tests Clock, RssProvider, NullMetricsSlot, and NullEventLogSlot
/// — the foundational diagnostics primitives.
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/rss_provider.dart';
import 'package:simple_player_flutter/kernel/diagnostics/metrics_slot.dart';
import 'package:simple_player_flutter/kernel/diagnostics/event_log_slot.dart';

void main() {
  group('SystemClock', () {
    test('now returns a DateTime', () {
      const clock = SystemClock();
      final now = clock.now();
      expect(now, isA<DateTime>());
    });

    test('now returns reasonable time (after 2020)', () {
      const clock = SystemClock();
      final now = clock.now();
      expect(now.isAfter(DateTime(2020)), isTrue);
    });

    test('is const constructible', () {
      const clock1 = SystemClock();
      const clock2 = SystemClock();
      expect(clock1.now().year, clock2.now().year);
    });
  });

  group('FakeClock', () {
    test('defaults to epoch (2026)', () {
      final clock = FakeClock();
      expect(clock.now().year, 2026);
    });

    test('accepts custom initial time', () {
      final custom = DateTime(2025, 6, 15);
      final clock = FakeClock(custom);
      expect(clock.now(), custom);
    });

    test('currentTime setter updates now()', () {
      final clock = FakeClock();
      final newTime = DateTime(2030, 1, 1);
      clock.currentTime = newTime;
      expect(clock.now(), newTime);
    });

    test('time does not advance automatically', () {
      final clock = FakeClock(DateTime(2026, 1, 1));
      final t1 = clock.now();
      final t2 = clock.now();
      expect(t1, equals(t2));
    });

    test('multiple setter calls work', () {
      final clock = FakeClock();
      clock.currentTime = DateTime(2025, 1, 1);
      expect(clock.now().year, 2025);
      clock.currentTime = DateTime(2030, 6, 15);
      expect(clock.now().year, 2030);
      expect(clock.now().month, 6);
    });

    test('implements Clock interface', () {
      final clock = FakeClock();
      expect(clock, isA<Clock>());
    });
  });

  group('ProcessInfoRssProvider', () {
    test('currentRss returns positive value', () {
      const provider = ProcessInfoRssProvider();
      expect(provider.currentRss, greaterThan(0));
    });

    test('is const constructible', () {
      const provider = ProcessInfoRssProvider();
      expect(provider.currentRss, greaterThan(0));
    });
  });

  group('FakeRssProvider', () {
    test('defaults to 0', () {
      final provider = FakeRssProvider();
      expect(provider.currentRss, 0);
    });

    test('accepts custom initial value', () {
      final provider = FakeRssProvider(1024);
      expect(provider.currentRss, 1024);
    });

    test('value setter updates currentRss', () {
      final provider = FakeRssProvider();
      provider.value = 2048;
      expect(provider.currentRss, 2048);
    });
  });

  group('NullMetricsSlot', () {
    test('recordOpen does not throw', () {
      const slot = NullMetricsSlot();
      expect(() => slot.recordOpen(success: true), returnsNormally);
      expect(() => slot.recordOpen(success: false), returnsNormally);
    });

    test('recordSeek does not throw', () {
      const slot = NullMetricsSlot();
      expect(() => slot.recordSeek(const Duration(milliseconds: 100)), returnsNormally);
    });

    test('recordFrameDrop does not throw', () {
      const slot = NullMetricsSlot();
      expect(() => slot.recordFrameDrop(), returnsNormally);
      expect(() => slot.recordFrameDrop(5), returnsNormally);
    });

    test('recordDecodeError does not throw', () {
      const slot = NullMetricsSlot();
      expect(() => slot.recordDecodeError(), returnsNormally);
    });

    test('recordBufferUnderrun does not throw', () {
      const slot = NullMetricsSlot();
      expect(() => slot.recordBufferUnderrun(), returnsNormally);
    });

    test('reset does not throw', () {
      const slot = NullMetricsSlot();
      expect(() => slot.reset(), returnsNormally);
    });

    test('toJson returns empty map', () {
      const slot = NullMetricsSlot();
      expect(slot.toJson(), isEmpty);
    });

    test('dispose does not throw', () {
      const slot = NullMetricsSlot();
      expect(() => slot.dispose(), returnsNormally);
    });
  });

  group('NullEventLogSlot', () {
    test('add does not throw', () {
      const slot = NullEventLogSlot();
      expect(() => slot.add('test'), returnsNormally);
      expect(() => slot.add('test', {'key': 'value'}), returnsNormally);
    });

    test('entries returns empty list', () {
      const slot = NullEventLogSlot();
      expect(slot.entries, isEmpty);
    });

    test('clear does not throw', () {
      const slot = NullEventLogSlot();
      expect(() => slot.clear(), returnsNormally);
    });

    test('toJson returns empty list', () {
      const slot = NullEventLogSlot();
      expect(slot.toJson(), isEmpty);
    });

    test('dispose does not throw', () {
      const slot = NullEventLogSlot();
      expect(() => slot.dispose(), returnsNormally);
    });
  });
}
