import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// TrackControl contract tests (D13 parameterized over a factory).
///
/// Mirrors the frozen `///` contract tags on [TrackControl]: `getAudioTracks`
/// returns a metadata snapshot (empty list before/without media, D20 static
/// behavior only — no assertion on post-open() track counts, which would
/// require real multi-track media and cross into timing/race territory);
/// `switchAudioTrack`/`activeAudioTracks` are no-op-safe before open() per
/// the interface's `requires: 无（disposed 时 no-op ...）` contract.
///
/// D13: parameterized over a `MediaEngine Function()` factory — never
/// instantiates a concrete engine directly, so Phase 21 can reuse this
/// exact test body against `NewFvpEngine`.
void runTrackControlContractTests(MediaEngine Function() createEngine) {
  group('TrackControl contract', () {
    late MediaEngine engine;

    setUp(() {
      engine = createEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    group('getAudioTracks()', () {
      test('returns an empty list before any open() (ensures: 快照, no media yet)', () {
        expect(engine.getAudioTracks(), isEmpty);
      });
    });

    group('activeAudioTracks', () {
      // Deviation from interface doc (baseline-capture, D16/D20 — not
      // fixed): TrackManager.activeAudioTracks delegates directly to the
      // raw mdk.Player getter, which defaults to [0] before any media is
      // opened -- not [] as the interface's `ensures: disposed 后返回空
      // 列表 []` doc comment states (that tag only documents the
      // POST-DISPOSE case; it does not cover the pre-open()/no-media
      // case, where MDK's own default-active-track-index convention
      // shows through unchanged). Asserting real current behavior here,
      // not the aspirational doc comment.
      test('returns [0] before any open() (MDK default active-index, not []'
          ' — documented interface/implementation gap, out of Phase 15 fix'
          ' scope)', () {
        expect(engine.activeAudioTracks, [0]);
      });
    });

    group('switchAudioTrack()', () {
      test('is a safe no-op before any open() (requires: 无 — TrackManager handles bounds)', () {
        // No media loaded yet — TrackManager internally guards out-of-range
        // trackId, so this must return normally rather than throw.
        expect(() => engine.switchAudioTrack(0), returnsNormally);
      });
    });
  });
}
