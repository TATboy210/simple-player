import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_persistence.dart';

void main() {
  group('WindowPersistence', () {
    late WindowPersistence persistence;

    setUp(() {
      persistence = WindowPersistence(debounceMs: 50);
    });

    tearDown(() {
      persistence.dispose();
    });

    group('construction', () {
      test('default debounce is 150ms', () {
        final p = WindowPersistence();
        expect(p.debounceMs, 150);
        p.dispose();
      });

      test('custom debounce', () {
        final p = WindowPersistence(debounceMs: 100);
        expect(p.debounceMs, 100);
        p.dispose();
      });
    });

    group('saveWindowGeometry', () {
      test('does not throw', () {
        expect(
          () => persistence.saveWindowGeometry(
            x: 100,
            y: 200,
            width: 1920,
            height: 1080,
            isMaximized: false,
          ),
          returnsNormally,
        );
      });

      test('multiple rapid calls do not throw', () {
        for (var i = 0; i < 10; i++) {
          persistence.saveWindowGeometry(
            x: 100 + i.toDouble(),
            y: 200 + i.toDouble(),
            width: 1920,
            height: 1080,
            isMaximized: false,
          );
        }
      });
    });

    group('cancelDebounce', () {
      test('does not throw', () {
        persistence.saveWindowGeometry(
          x: 0,
          y: 0,
          width: 800,
          height: 600,
          isMaximized: false,
        );
        expect(() => persistence.cancelDebounce(), returnsNormally);
      });
    });

    group('dispose', () {
      test('does not throw', () {
        expect(() => persistence.dispose(), returnsNormally);
      });

      test('idempotent', () {
        persistence.dispose();
        expect(() => persistence.dispose(), returnsNormally);
      });
    });
  });
}
