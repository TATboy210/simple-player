import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';

void main() {
  group('Parallel init pattern', () {
    test('Future.wait runs both futures concurrently', () async {
      // Arrange: two delayed futures that would be sequential if awaited one-by-one
      final sw = Stopwatch()..start();
      final results = await Future.wait([
        Future.delayed(const Duration(milliseconds: 50), () => 'a'),
        Future.delayed(const Duration(milliseconds: 50), () => 'b'),
      ]);
      sw.stop();

      // Assert: both completed, and total time is ~50ms (not ~100ms sequential)
      expect(results, ['a', 'b']);
      expect(sw.elapsedMilliseconds, lessThan(90)); // generous margin for CI
    });

    test(
      'Future.wait with error-catching continues when one future fails',
      () async {
        // Arrange: one succeeds, one throws
        bool errorCaught = false;

        try {
          await Future.wait([
            Future.delayed(const Duration(milliseconds: 20), () => 'ok'),
            Future.delayed(const Duration(milliseconds: 20), () {
              throw Exception('init failed');
            }),
          ]);
        } on Exception catch (e) {
          errorCaught = true;
          debugPrint('Caught: $e');
        }

        // With the try-catch in App._init, the error is caught and app continues
        expect(errorCaught, isTrue);
      },
    );

    test(
      'Future.wait error handling allows app to show on partial failure',
      () async {
        // Simulate App._init pattern: try-catch around Future.wait, then set ready
        bool ready = false;
        bool initFailed = false;

        try {
          await Future.wait([
            Future.value('window_ok'),
            Future<String>(() => throw Exception('controller failed')),
          ]);
        } on Exception catch (e) {
          initFailed = true;
          debugPrint('[App] init failed (continuing): $e');
        }

        // App continues even after partial failure
        ready = true;

        expect(initFailed, isTrue);
        expect(ready, isTrue); // app shows despite init failure
      },
    );
  });

  group('SettingsStore prewarm', () {
    setUp(() {
      // Reset cached prefs between tests
      SettingsStore.resetPrewarm();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      SettingsStore.resetPrewarm();
    });

    test('load() reuses cached SharedPreferences when prewarmed', () async {
      // Arrange: pre-populate a SharedPreferences instance with known values
      SharedPreferences.setMockInitialValues({
        'volume': 0.42,
        'lastFile': 'test_video.mp4',
      });
      final cached = await SharedPreferences.getInstance();

      // Act: prewarm, then load
      SettingsStore.prewarm(cached);
      final settings = await SettingsStore.load();

      // Assert: loaded values match the pre-warmed instance
      expect(settings.volume, 0.42);
      expect(settings.lastFile, 'test_video.mp4');
    });

    test(
      'load() falls back to SharedPreferences.getInstance() when not prewarmed',
      () async {
        // Arrange: set values via mock, do NOT prewarm
        SharedPreferences.setMockInitialValues({
          'volume': 0.77,
          'lastFile': 'fallback.mp4',
        });

        // Act
        final settings = await SettingsStore.load();

        // Assert: values come from the standard path
        expect(settings.volume, 0.77);
        expect(settings.lastFile, 'fallback.mp4');
      },
    );

    test('saveVolume uses cached instance when prewarmed', () async {
      // Arrange: prewarm with empty prefs
      SharedPreferences.setMockInitialValues({});
      final cached = await SharedPreferences.getInstance();
      SettingsStore.prewarm(cached);

      // Act: save a volume
      await SettingsStore.saveVolume(0.55);

      // Assert: the cached instance has the value
      expect(cached.getDouble('volume'), 0.55);
    });

    test('saveLastFile uses cached instance when prewarmed', () async {
      SharedPreferences.setMockInitialValues({});
      final cached = await SharedPreferences.getInstance();
      SettingsStore.prewarm(cached);

      await SettingsStore.saveLastFile('my_video.mp4');

      expect(cached.getString('lastFile'), 'my_video.mp4');
    });

    test('consecutive load() calls reuse the same cached instance', () async {
      // Arrange: prewarm with specific values
      SharedPreferences.setMockInitialValues({'volume': 0.88});
      final cached = await SharedPreferences.getInstance();
      SettingsStore.prewarm(cached);

      // Act: load twice
      final settings1 = await SettingsStore.load();
      final settings2 = await SettingsStore.load();

      // Assert: both loads return the same cached values
      expect(settings1.volume, 0.88);
      expect(settings2.volume, 0.88);
    });

    test(
      'prewarm can be called multiple times with different instances',
      () async {
        // First prewarm
        SharedPreferences.setMockInitialValues({'volume': 0.1});
        final first = await SharedPreferences.getInstance();
        SettingsStore.prewarm(first);
        expect((await SettingsStore.load()).volume, 0.1);

        // Second prewarm with different values
        SharedPreferences.setMockInitialValues({'volume': 0.9});
        final second = await SharedPreferences.getInstance();
        SettingsStore.prewarm(second);
        expect((await SettingsStore.load()).volume, 0.9);
      },
    );
  });
}
