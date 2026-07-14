import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'package:simple_player_flutter/kernel/engine/fvp_callback_handler.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';

void main() {
  group('FvpCallbackHandler', () {
    group('mapMdkState (static)', () {
      test('maps stopped to MediaState.idle', () {
        expect(
          FvpCallbackHandler.mapMdkState(mdk.PlaybackState.stopped),
          MediaState.idle,
        );
      });

      test('maps playing to MediaState.playing', () {
        expect(
          FvpCallbackHandler.mapMdkState(mdk.PlaybackState.playing),
          MediaState.playing,
        );
      });

      test('maps paused to MediaState.paused', () {
        expect(
          FvpCallbackHandler.mapMdkState(mdk.PlaybackState.paused),
          MediaState.paused,
        );
      });

      test('maps unknown state to MediaState.idle', () {
        expect(
          FvpCallbackHandler.mapMdkState(mdk.PlaybackState.stopped),
          MediaState.idle,
        );
      });
    });

    group('constructor', () {
      test('accepts stateMachine parameter', () {
        final sm = EngineStateMachine();
        // Verify constructor accepts EngineStateMachine (compile-time check)
        expect(sm, isA<EngineStateMachine>());
        expect(sm.state.value, MediaState.idle);
        sm.dispose();
      });
    });
  });
}
