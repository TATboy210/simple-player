/// PlayerServices unit tests — pure Dart, no mdk.dll dependency.
///
/// Tests the DI container construction and dispose lifecycle.
/// Note: init() cannot be tested in headless CI because it creates MediaKitEngine
/// (requires libmpv). Only construction and dispose behavior are tested.
library;

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
    });

    group('dispose', () {
      test(
        'dispose before init is safe and does not dispose borrowed window',
        () {
          final windowService = FakeWindowService();
          final services = PlayerServices(windowService: windowService);

          // init() owns playback resources; the composition root owns the bridge.
          expect(() => services.dispose(), returnsNormally);
          expect(() => windowService.mode.value, returnsNormally);
          windowService.dispose();
        },
      );
    });
  });
}
