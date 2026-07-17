import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// EngineStateView contract tests (D13 parameterized over a factory).
///
/// Mirrors the frozen `///` contract tags on [EngineStateView]
/// (`requires: 无（所有 getter 幂等、无参数、永不 throw）`) — every getter
/// must be safely readable before `open()` is ever called, with no
/// exceptions and no dependence on prior state transitions.
///
/// D13: this function accepts a `MediaEngine Function()` factory instead of
/// instantiating a concrete engine directly, so Phase 21 can mount the same
/// assertions against `NewFvpEngine` by swapping only the factory passed in
/// from the mount point (`test/engine/fvp_engine_contract_test.dart`).
void runEngineStateViewContractTests(MediaEngine Function() createEngine) {
  group('EngineStateView contract', () {
    late MediaEngine engine;

    setUp(() {
      engine = createEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    group('getters — callable before open() (requires: 无)', () {
      test('textureId is accessible and returnsNormally', () {
        expect(() => engine.textureId, returnsNormally);
      });

      test('state is accessible and returnsNormally', () {
        expect(() => engine.state, returnsNormally);
      });

      test('position is accessible and returnsNormally', () {
        expect(() => engine.position, returnsNormally);
      });

      test('duration is accessible and returnsNormally', () {
        expect(() => engine.duration, returnsNormally);
      });

      test('volume is accessible and returnsNormally', () {
        expect(() => engine.volume, returnsNormally);
      });

      test('isMuted is accessible and returnsNormally', () {
        expect(() => engine.isMuted, returnsNormally);
      });

      test('isBuffering is accessible and returnsNormally', () {
        expect(() => engine.isBuffering, returnsNormally);
      });

      test('isSeeking is accessible and returnsNormally', () {
        expect(() => engine.isSeeking, returnsNormally);
      });

      test('subtitleText is accessible and returnsNormally', () {
        expect(() => engine.subtitleText, returnsNormally);
      });

      test('buffered is accessible and returnsNormally', () {
        expect(() => engine.buffered, returnsNormally);
      });

      test('aspectRatio is accessible and returnsNormally', () {
        expect(() => engine.aspectRatio, returnsNormally);
      });

      test('lastError is accessible and returnsNormally', () {
        expect(() => engine.lastError, returnsNormally);
      });

      test('playbackSpeed is accessible and returnsNormally', () {
        expect(() => engine.playbackSpeed, returnsNormally);
      });

      test('mediaInfo is accessible and returnsNormally', () {
        expect(() => engine.mediaInfo, returnsNormally);
      });
    });

    group('initial values — before any open()', () {
      test('state starts as idle', () {
        expect(engine.state.value, MediaState.idle);
      });

      test('position starts at 0', () {
        expect(engine.position.value, 0);
      });

      test('duration starts at 0', () {
        expect(engine.duration.value, 0);
      });

      test('lastError starts null', () {
        expect(engine.lastError.value, isNull);
      });

      test('isBuffering starts false', () {
        expect(engine.isBuffering.value, isFalse);
      });

      test('isSeeking starts false', () {
        expect(engine.isSeeking.value, isFalse);
      });
    });

    group('dispose (modifies: 无 during normal reads)', () {
      test('dispose completes without error', () {
        final disposable = createEngine();
        expect(disposable.dispose, returnsNormally);
      });
    });
  });
}
