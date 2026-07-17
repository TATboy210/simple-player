import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// VolumeControl contract tests (D13 parameterized over a factory).
///
/// The 7th ISP group — omitted from D14's original text, added per
/// RESEARCH OpenQ2 / Pitfall 4.
///
/// Mirrors the frozen `///` contract tags on [VolumeControl]: `setVolume`
/// clamps into [0.0, 1.0] and conditionally toggles `isMuted` only when
/// crossing the 0 boundary (UX convenience — muting on 0, unmuting when
/// raised above 0); `setMute` sets `isMuted` directly with no volume
/// side-effect.
///
/// D13: parameterized over a `MediaEngine Function()` factory — never
/// instantiates a concrete engine directly, so Phase 21 can reuse this
/// exact test body against `NewFvpEngine`.
void runVolumeControlContractTests(MediaEngine Function() createEngine) {
  group('VolumeControl contract', () {
    late MediaEngine engine;

    setUp(() {
      engine = createEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    group('setVolume()', () {
      test('clamps into [0.0, 1.0] (ensures: volume == clamp(value, 0.0, 1.0))', () {
        engine.setVolume(2.0);
        expect(engine.volume.value, 1.0);

        engine.setVolume(-1.0);
        expect(engine.volume.value, 0.0);
      });

      test('crossing to 0 auto-mutes; raising above 0 auto-unmutes '
          '(modifies: [volume], [isMuted] — conditional on 0 boundary)', () {
        engine.setVolume(0.5);
        expect(engine.isMuted.value, isFalse);

        engine.setVolume(0);
        expect(engine.volume.value, 0);
        expect(engine.isMuted.value, isTrue);

        engine.setVolume(0.8);
        expect(engine.isMuted.value, isFalse);
      });
    });

    group('setMute()', () {
      test('sets isMuted directly without a volume side-effect (modifies: [isMuted])', () {
        final before = engine.volume.value;

        engine.setMute(true);
        expect(engine.isMuted.value, isTrue);
        expect(engine.volume.value, before);

        engine.setMute(false);
        expect(engine.isMuted.value, isFalse);
        expect(engine.volume.value, before);
      });
    });

    group('volume / isMuted getters', () {
      test('reflect the most recent setVolume/setMute write (ensures: 纯读取)', () {
        engine.setVolume(0.42);
        expect(engine.volume.value, 0.42);

        engine.setMute(true);
        expect(engine.isMuted.value, isTrue);
      });
    });
  });
}
