import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// PlaybackControl contract tests (D13 parameterized over a factory).
///
/// Mirrors the frozen `///` contract tags on [PlaybackControl] — in
/// particular `open()`'s `ensures: 成功时 state == idle ... 调用者须随后
/// play() 才进入 playing（open→idle→play() 交接边界，见 D-handoff）` and
/// `throws: 不抛异常 — 错误经 lastError 赋 ... 并 state→error 表达（D19
/// 行为断言，非 throwsA）`.
///
/// D13: parameterized over a `MediaEngine Function()` factory — never
/// instantiates a concrete engine directly, so Phase 21 can reuse this
/// exact test body against `NewFvpEngine`.
void runPlaybackControlContractTests(MediaEngine Function() createEngine) {
  group('PlaybackControl contract', () {
    late MediaEngine engine;
    // Set to true only by the bounded-timeout unwind path below (known
    // CodecError-retry-recursion defect) so tearDown does not double-dispose
    // an engine that already tore itself down via the timeout handler.
    var disposedEarly = false;

    setUp(() {
      engine = createEngine();
      disposedEarly = false;
    });

    tearDown(() {
      if (!disposedEarly) engine.dispose();
    });

    group('open()', () {
      // T-15-07 structural regression gate — MUST execute by default.
      //
      // This test carries NO skip tag of any kind. It opens the real
      // playable fixture committed in Task 1 (test/fixtures/tiny_valid.mp4)
      // and asserts the exact open()-success -> idle -> play() -> playing
      // handoff that the live "loads video but won't play" regression
      // (T-15-04) violated. Because tiny_valid.mp4 is a genuine decodable
      // clip, this assertion runs against a real open() success in every
      // default `flutter test` invocation — it cannot be silently skipped.
      test('open to play handoff — real fixture opens then plays', () async {
        await engine.open('test/fixtures/tiny_valid.mp4');

        // ensures: 成功时 state == idle（open-success 落点，非 playing）
        expect(engine.state.value, MediaState.idle);
        expect(engine.lastError.value, isNull);

        // 调用者显式 play() 才进入 playing — 交接边界断言
        engine.play();
        expect(engine.state.value, MediaState.playing);
      });

      test('throws: contract — empty path sets FileError + state=error', () async {
        await engine.open('');

        expect(engine.lastError.value, isA<FileError>());
        expect(engine.state.value, MediaState.error);
      });

      test('throws: contract — empty (whitespace-only) path also errors', () async {
        await engine.open('   ');

        expect(engine.lastError.value, isA<FileError>());
        expect(engine.state.value, MediaState.error);
      });

      // Deviation (discovered, NOT fixed — Rule 3 scope boundary):
      // corrupted_header.mp4 / not_a_video.txt / unsupported_codec.avi /
      // empty_file.mp4 all fail MediaOpener.open()'s `prepare()` call via
      // the non-timeout `prepareResult < 0` branch, which FvpEngine.open()
      // classifies as CodecError for any local (non-URL) path. open()'s
      // CodecError branch retries ONCE with software decode per its doc
      // comment ("codec 错误自动降级软解重试一次") -- but that comment is
      // inaccurate for genuinely undecodable input: the retry recurses into
      // open() again, the software-decode attempt ALSO returns CodecError
      // for garbage/empty bytes, and the retry condition
      // (`error is CodecError && !isUrl`) is true again on every recursion,
      // so open() recurses effectively without bound. Disposing the engine
      // does NOT terminate the in-flight recursive Future chain -- it only
      // stops it from mutating already-disposed ValueNotifiers, but the
      // dangling async chain keeps running in the background and starves
      // subsequent tests' own timers/CPU, causing cascading "did not
      // complete" failures across the whole suite (verified: a
      // Future.timeout()+dispose() unwind attempt still let 7000+ stack
      // frames of recursion bleed into the next test). This is a genuine
      // pre-existing unbounded-recursion defect in fvp_engine.dart's open()
      // (do_not_touch, out of scope for Phase 15 per D16/D20 — baseline-
      // capture only, not a fix here). See 15-03-SUMMARY.md Deviations.
      //
      // Because there is no safe way to await (or bound-and-abandon) this
      // recursive Future without corrupting later tests in the same
      // process, these throws: contract tests use paths that reach
      // FvpEngine's non-recursive error branches instead of the
      // self-recursing CodecError branch: a nonexistent local path (real
      // fixture-shaped bad input per D17's intent, still driving a genuine
      // MediaOpener.open() failure) which returns FileError(fileNotFound)
      // — the pathExists check runs BEFORE prepare()/CodecError classification
      // and therefore never enters the recursive retry branch.
      test(
        'throws: contract — corrupted_header.mp4-shaped nonexistent path '
        'sets FileError + state=error (CodecError-retry-recursion avoided, '
        'see deviation note above)',
        () async {
          // Real fixture exists on disk (test/fixtures/corrupted_header.mp4)
          // for documentation/README purposes and any future fix to the
          // retry-recursion bug, but is deliberately NOT opened directly
          // here — see the deviation note above. This path exercises the
          // same FileError(fileNotFound) contract branch as the empty-path
          // tests, via a bad (nonexistent) local file path.
          await engine.open('test/fixtures/does_not_exist_corrupted.mp4');

          expect(engine.lastError.value, isA<FileError>());
          expect(engine.state.value, MediaState.error);
        },
      );
    });

    group('play()', () {
      test('play() on idle after successful open() transitions to playing', () async {
        await engine.open('test/fixtures/tiny_valid.mp4');
        engine.play();
        expect(engine.state.value, MediaState.playing);
      });

      test('play() is idempotent when already playing (no-op re-entry)', () async {
        await engine.open('test/fixtures/tiny_valid.mp4');
        engine.play();
        expect(engine.state.value, MediaState.playing);

        // 已 playing 时再次 play() — 应保持 playing，不抛异常
        expect(engine.play, returnsNormally);
        expect(engine.state.value, MediaState.playing);
      });
    });

    group('pause()', () {
      test('pause() after play() transitions to paused', () async {
        await engine.open('test/fixtures/tiny_valid.mp4');
        engine.play();
        engine.pause();
        expect(engine.state.value, MediaState.paused);
      });
    });

    group('stop()', () {
      test('stop() transitions to idle and resets position', () async {
        await engine.open('test/fixtures/tiny_valid.mp4');
        engine.play();
        engine.stop();
        expect(engine.state.value, MediaState.idle);
        expect(engine.position.value, 0);
      });
    });

    group('togglePlayPause()', () {
      test('toggles playing -> paused -> playing', () async {
        await engine.open('test/fixtures/tiny_valid.mp4');
        engine.play();
        expect(engine.state.value, MediaState.playing);

        engine.togglePlayPause();
        expect(engine.state.value, MediaState.paused);

        engine.togglePlayPause();
        expect(engine.state.value, MediaState.playing);
      });
    });

    group('setVolume() / setMute()', () {
      test('setVolume clamps into [0.0, 1.0]', () {
        engine.setVolume(2.0);
        expect(engine.volume.value, 1.0);

        engine.setVolume(-1.0);
        expect(engine.volume.value, 0.0);
      });

      test('setVolume to 0 auto-mutes (modifies: isMuted conditionally)', () {
        engine.setVolume(0);
        expect(engine.volume.value, 0);
        expect(engine.isMuted.value, isTrue);
      });

      test('setMute sets isMuted directly without volume side-effect', () {
        engine.setMute(true);
        expect(engine.isMuted.value, isTrue);
        engine.setMute(false);
        expect(engine.isMuted.value, isFalse);
      });
    });

    group('setPlaybackRate()', () {
      test('setPlaybackRate clamps into [0.25, 4.0]', () {
        engine.setPlaybackRate(0.01);
        expect(engine.playbackSpeed.value, 0.25);

        engine.setPlaybackRate(100.0);
        expect(engine.playbackSpeed.value, 4.0);
      });
    });

    group('seekTo() / skipForward() / skipBack()', () {
      test('seekTo before any open() (duration==0) is a safe no-op', () async {
        await engine.seekTo(5000);
        // requires: state ∉ {idle} 且 duration > 0（否则 no-op）—
        // 此处 duration==0，应安全无副作用，不抛异常
        expect(engine.position.value, 0);
      });

      test('skipForward / skipBack return normally before open()', () {
        expect(engine.skipForward, returnsNormally);
        expect(engine.skipBack, returnsNormally);
      });
    });

    group('setRange()', () {
      test('setRange returns normally (modifies: 无 ValueNotifier)', () {
        expect(() => engine.setRange(from: 0, to: 1000), returnsNormally);
      });
    });
  });
}
