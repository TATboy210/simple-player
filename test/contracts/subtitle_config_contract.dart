import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// SubtitleConfig contract tests (D13 parameterized over a factory).
///
/// Mirrors the frozen `///` contract tags on [SubtitleConfig]:
/// `getSubtitleTracks`/`activeSubtitleTracks` return snapshot/empty-list
/// before any media is loaded; `switchSubtitleTrack`/`toggleSubtitle`/
/// `setExternalSubtitle`/`setSubtitleDelay`/`setEqualizer` are all no-op-safe
/// with no ValueNotifier side effects reflected in [EngineStateView]
/// (per the `modifies: 无 ValueNotifier` tags) except `subtitleDelay`,
/// whose plain-getter contract (`ensures: subtitleDelay == delay`) IS
/// directly testable since it is not gated by media state.
///
/// D13: parameterized over a `MediaEngine Function()` factory — never
/// instantiates a concrete engine directly, so Phase 21 can reuse this
/// exact test body against `NewFvpEngine`.
void runSubtitleConfigContractTests(MediaEngine Function() createEngine) {
  group('SubtitleConfig contract', () {
    late MediaEngine engine;

    setUp(() {
      engine = createEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    group('getSubtitleTracks()', () {
      test('returns an empty list before any open() (ensures: 快照, no media yet)', () {
        expect(engine.getSubtitleTracks(), isEmpty);
      });
    });

    group('activeSubtitleTracks', () {
      // Deviation from interface doc (baseline-capture, D16/D20 — not
      // fixed): same gap as TrackControl.activeAudioTracks — this getter
      // delegates directly to the raw mdk.Player getter, which defaults
      // to [0] before any media is opened, not [] as the interface's
      // `ensures: disposed 后返回空列表 []` doc comment states (that tag
      // only documents the POST-DISPOSE case, not pre-open()/no-media).
      // Asserting real current behavior, not the aspirational doc
      // comment.
      test('returns [0] before any open() (MDK default active-index, not []'
          ' — documented interface/implementation gap, out of Phase 15 fix'
          ' scope)', () {
        expect(engine.activeSubtitleTracks, [0]);
      });
    });

    group('switchSubtitleTrack()', () {
      test('is a safe no-op before any open() (requires: 无 — TrackManager handles bounds)', () {
        expect(() => engine.switchSubtitleTrack(0), returnsNormally);
      });
    });

    group('toggleSubtitle()', () {
      test('is a safe no-op before any open() (modifies: activeSubtitleTracks)', () {
        expect(engine.toggleSubtitle, returnsNormally);
      });
    });

    group('setExternalSubtitle()', () {
      test('is a safe no-op call (modifies: 无 ValueNotifier — delegates to underlying engine)', () {
        expect(
          () => engine.setExternalSubtitle('test/fixtures/not_a_video.txt'),
          returnsNormally,
        );
      });
    });

    group('setSubtitleDelay() / subtitleDelay', () {
      test('setSubtitleDelay updates subtitleDelay getter (ensures: subtitleDelay == delay)', () {
        engine.setSubtitleDelay(500);
        expect(engine.subtitleDelay, 500);

        engine.setSubtitleDelay(-250);
        expect(engine.subtitleDelay, -250);
      });
    });

    group('setEqualizer()', () {
      test('is a safe no-op call (modifies: 无 ValueNotifier — delegates to underlying engine)', () {
        expect(() => engine.setEqualizer('flat'), returnsNormally);
      });
    });
  });
}
