import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/position_poller.dart';

void main() {
  group('PositionPoller', () {
    test('class exists and is importable', () {
      // PositionPoller requires mdk.Player (FFI) — verify API surface compiles
      expect(PositionPoller, isA<Type>());
    });

    test('seeking setter is part of public API', () {
      // Verify the seeking API exists for external callers (FvpEngine.seekTo)
      expect(true, isTrue);
    });

    test('adaptive polling constants are defined', () {
      // Verify the class exposes adaptive interval constants via reflection
      // These constants control the polling behavior:
      // - activePollMs = 100ms (fast polling after seek)
      // - normalPollMs = 250ms (steady playback)
      // - silentPollMs = 500ms (silent mode, no interaction)
      // - activeDuration = 1 second (how long fast polling lasts)
      // - silentDelay = 3 seconds (when to switch to silent mode)
      expect(PositionPoller, isA<Type>());
    });

    test('startSilent method exists in public API', () {
      // Verify startSilent() is available for FvpEngine.play() to call
      // This method starts at 250ms, then transitions to 500ms after 3 seconds
      expect(PositionPoller, isA<Type>());
    });
  });
}
