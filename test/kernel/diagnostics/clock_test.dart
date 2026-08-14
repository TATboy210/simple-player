/// Diagnostics small modules unit tests — pure Dart, no native dependency.
///
/// Tests Clock and RssProvider — the foundational diagnostics primitives.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/rss_provider.dart';

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
}
