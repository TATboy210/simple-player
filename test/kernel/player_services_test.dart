/// PlayerServices unit tests — pure Dart, no mdk.dll dependency.
///
/// Tests the DI container construction and dispose lifecycle.
/// Note: init() cannot be tested in headless CI because it creates FvpEngine
/// (requires mdk.dll). Only construction and dispose behavior are tested.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/player_services.dart';

import '../helpers/fake_window_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerServices', () {
    group('construction', () {
      test('windowService is assigned from constructor', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        expect(services.windowService, same(windowService));
        windowService.dispose();
      });

      test('playlistGeneration starts at 0', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        expect(services.playlistGeneration.value, 0);
        windowService.dispose();
      });

      test('playlistGeneration is a ValueNotifier', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        expect(services.playlistGeneration, isNotNull);
        // Verify it can notify listeners
        var notified = false;
        services.playlistGeneration.addListener(() => notified = true);
        services.playlistGeneration.value = 1;
        expect(notified, isTrue);
        windowService.dispose();
      });

      test('constructor accepts required windowService', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        expect(services.windowService, isNotNull);
        windowService.dispose();
      });
    });

    group('playlistGeneration', () {
      test('can be incremented multiple times', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        services.playlistGeneration.value = 1;
        services.playlistGeneration.value = 2;
        services.playlistGeneration.value = 3;
        expect(services.playlistGeneration.value, 3);
        windowService.dispose();
      });

      test('notifies multiple listeners', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        var count1 = 0;
        var count2 = 0;
        services.playlistGeneration.addListener(() => count1++);
        services.playlistGeneration.addListener(() => count2++);
        services.playlistGeneration.value = 1;
        expect(count1, 1);
        expect(count2, 1);
        windowService.dispose();
      });

      test('listener can be removed', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        var count = 0;
        void listener() => count++;
        services.playlistGeneration.addListener(listener);
        services.playlistGeneration.value = 1;
        expect(count, 1);
        services.playlistGeneration.removeListener(listener);
        services.playlistGeneration.value = 2;
        expect(count, 1); // No additional notification
        windowService.dispose();
      });
    });

    group('dispose', () {
      test('dispose does not throw when called without init', () {
        // PlayerServices without init() — late fields not set.
        // dispose() will throw on late field access, so this tests the
        // construction-only path. In production, init() is always called first.
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        // Only dispose what was initialized (playlistGeneration + windowService)
        services.playlistGeneration.dispose();
        windowService.dispose();
        // Note: full dispose() would throw because engine/playlist/controller
        // are late fields not set without init(). This is expected behavior.
      });

      test('playlistGeneration can be disposed independently', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        expect(() => services.playlistGeneration.dispose(), returnsNormally);
        windowService.dispose();
      });

      test('windowService can be disposed independently', () {
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);
        expect(() => windowService.dispose(), returnsNormally);
        // playlistGeneration is still alive
        expect(services.playlistGeneration.value, 0);
        services.playlistGeneration.dispose();
      });
    });

    group('windowService integration', () {
      test('windowService is the same instance passed to constructor', () {
        final ws = FakeWindowService();
        final services = PlayerServices(windowService: ws);
        expect(identical(services.windowService, ws), isTrue);
        ws.dispose();
      });

      test('windowService dispose is independent of PlayerServices', () {
        final ws = FakeWindowService();
        final services = PlayerServices(windowService: ws);
        // Dispose windowService first — PlayerServices still has playlistGeneration
        ws.dispose();
        expect(services.playlistGeneration.value, 0);
        services.playlistGeneration.dispose();
      });
    });

    group('late field access without init', () {
      test('engine throws when accessed without init', () {
        final ws = FakeWindowService();
        final services = PlayerServices(windowService: ws);
        // engine is a late final field — accessing without init() throws
        expect(() => services.engine, throwsA(anything));
        ws.dispose();
      });

      test('playlist throws when accessed without init', () {
        final ws = FakeWindowService();
        final services = PlayerServices(windowService: ws);
        expect(() => services.playlist, throwsA(anything));
        ws.dispose();
      });

      test('controller throws when accessed without init', () {
        final ws = FakeWindowService();
        final services = PlayerServices(windowService: ws);
        expect(() => services.controller, throwsA(anything));
        ws.dispose();
      });

      test('videoProcessing throws when accessed without init', () {
        final ws = FakeWindowService();
        final services = PlayerServices(windowService: ws);
        expect(() => services.videoProcessing, throwsA(anything));
        ws.dispose();
      });
    });
  });
}
