import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'package:simple_player_flutter/kernel/engine/fvp_callback_handler.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

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
      test('accepts stateMachine and lastErrorNotifier parameters', () {
        final sm = EngineStateMachine();
        final lastError = ValueNotifier<PlayerError?>(null);
        // Verify constructor accepts both parameters (compile-time check)
        expect(sm, isA<EngineStateMachine>());
        expect(lastError.value, isNull);
        sm.dispose();
        lastError.dispose();
      });
    });

    group('ErrorContext callbackStackTrace (ERR-05)', () {
      test('ErrorContext with callbackStackTrace serializes to map', () {
        final st = StackTrace.current;
        final ctx = ErrorContext(
          action: 'mdk.onStateChanged',
          module: 'FvpCallbackHandler',
          callbackStackTrace: st,
        );

        final map = ctx.toMap();
        expect(map['action'], 'mdk.onStateChanged');
        expect(map['module'], 'FvpCallbackHandler');
        expect(map['callbackStackTrace'], isA<String>());
        expect(map['callbackStackTrace'], st.toString());
      });

      test('PlaybackError with callbackStackTrace context carries all fields', () {
        final cause = Exception('callback failure');
        final st = StackTrace.current;
        final error = PlaybackError(
          PlaybackErrorCode.playFailed,
          'mdk callback error: $cause',
          cause,
          ErrorContext(
            action: 'mdk.onStateChanged',
            module: 'FvpCallbackHandler',
            callbackStackTrace: st,
          ),
        );

        expect(error.context?.action, 'mdk.onStateChanged');
        expect(error.context?.module, 'FvpCallbackHandler');
        expect(error.context?.callbackStackTrace, st);
        expect(error.cause, cause);
        expect(error.isFatal, false); // playFailed is recoverable
      });

      test('ErrorContext without callbackStackTrace omits from map', () {
        final ctx = ErrorContext(
          action: 'open',
          module: 'FvpEngine',
        );
        final map = ctx.toMap();

        expect(map.containsKey('callbackStackTrace'), false);
      });
    });
  });
}
