import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// VideoEffectControl contract tests (D13 parameterized over a factory).
///
/// Mirrors the frozen `///` contract tags on [VideoEffectControl]:
/// `setVideoEffect`/`rotate`/`setAspectRatio`/`setDeinterlace` all have
/// `modifies: 无 ValueNotifier` — none of them write back to any
/// [EngineStateView] getter (notably `setAspectRatio` does NOT update
/// `EngineStateView.aspectRatio`, a documented contract-implementation gap,
/// out of Phase 15's fix scope per do_not_touch/D16). All four are
/// therefore asserted via `returnsNormally` only (D20 static-behavior-only
/// — no rendering-pipeline side effect is observable without a live
/// texture/surface).
///
/// D13: parameterized over a `MediaEngine Function()` factory — never
/// instantiates a concrete engine directly, so Phase 21 can reuse this
/// exact test body against `NewFvpEngine`.
void runVideoEffectControlContractTests(MediaEngine Function() createEngine) {
  group('VideoEffectControl contract', () {
    late MediaEngine engine;

    setUp(() {
      engine = createEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    group('setVideoEffect()', () {
      test('returns normally for a valid effect type + value (modifies: 无 ValueNotifier)', () {
        expect(
          () => engine.setVideoEffect(VideoEffectType.brightness, 0.5),
          returnsNormally,
        );
      });
    });

    group('rotate()', () {
      test('returns normally for a valid rotation degree (modifies: 无 ValueNotifier)', () {
        expect(() => engine.rotate(90), returnsNormally);
      });
    });

    group('setAspectRatio()', () {
      test('returns normally without writing back to EngineStateView.aspectRatio '
          '(documented contract-implementation gap, out of Phase 15 fix scope)', () {
        final before = engine.aspectRatio.value;

        expect(() => engine.setAspectRatio(1.777), returnsNormally);

        // ensures/modifies: 无 ValueNotifier — setAspectRatio does not push
        // into EngineStateView.aspectRatio (that ValueNotifier is only
        // computed by a successful open()). Documenting the current gap
        // as baseline, not asserting new intended behavior (D16/D20).
        expect(engine.aspectRatio.value, before);
      });
    });

    group('setDeinterlace()', () {
      test('returns normally for both enable states (modifies: 无 ValueNotifier)', () {
        expect(() => engine.setDeinterlace(true), returnsNormally);
        expect(() => engine.setDeinterlace(false), returnsNormally);
      });
    });
  });
}
