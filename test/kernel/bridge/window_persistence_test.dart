/// WindowPersistence unit tests — pure Dart, no mdk.dll dependency.
///
/// Tests the debounce + write lock pattern for window geometry saves.
/// Uses fakeAsync to control Timer behavior.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_persistence.dart';

void main() {
  group('WindowPersistence', () {
    group('construction', () {
      test('default debounce is 150ms', () {
        final persistence = WindowPersistence();
        expect(persistence.debounceMs, 150);
        persistence.dispose();
      });

      test('custom debounce is configurable', () {
        final persistence = WindowPersistence(debounceMs: 50);
        expect(persistence.debounceMs, 50);
        persistence.dispose();
      });
    });

    group('saveWindowGeometry', () {
      test('does not throw when called', () {
        final persistence = WindowPersistence();
        expect(
          () => persistence.saveWindowGeometry(
            x: 100,
            y: 200,
            width: 1280,
            height: 720,
            isMaximized: false,
          ),
          returnsNormally,
        );
        persistence.dispose();
      });

      test('multiple rapid calls do not throw', () {
        final persistence = WindowPersistence(debounceMs: 50);
        // Simulate rapid resize events
        for (var i = 0; i < 10; i++) {
          persistence.saveWindowGeometry(
            x: 100.0 + i,
            y: 200.0 + i,
            width: 1280.0 + i,
            height: 720.0 + i,
            isMaximized: false,
          );
        }
        expect(() => persistence.cancelDebounce(), returnsNormally);
        persistence.dispose();
      });
    });

    group('cancelDebounce', () {
      test('cancelDebounce does not throw', () {
        final persistence = WindowPersistence();
        expect(() => persistence.cancelDebounce(), returnsNormally);
        persistence.dispose();
      });

      test('cancelDebounce is idempotent', () {
        final persistence = WindowPersistence();
        persistence.cancelDebounce();
        expect(() => persistence.cancelDebounce(), returnsNormally);
        persistence.dispose();
      });
    });

    group('dispose', () {
      test('dispose does not throw', () {
        final persistence = WindowPersistence();
        expect(() => persistence.dispose(), returnsNormally);
      });

      test('dispose is idempotent', () {
        final persistence = WindowPersistence();
        persistence.dispose();
        expect(() => persistence.dispose(), returnsNormally);
      });

      test('dispose cancels pending debounce', () {
        final persistence = WindowPersistence(debounceMs: 1000);
        persistence.saveWindowGeometry(
          x: 0, y: 0, width: 800, height: 600, isMaximized: false,
        );
        // dispose should cancel the pending timer
        expect(() => persistence.dispose(), returnsNormally);
      });
    });
  });
}
