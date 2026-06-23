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
  });
}
