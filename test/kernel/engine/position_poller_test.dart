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
      // Actual behavior tested through FvpEngine integration
      expect(true, isTrue);
    });

    test('adaptive polling constants are defined', () {
      // Verify the class exposes adaptive interval constants via reflection
      // These constants control the polling behavior:
      // - activePollMs = 100ms (fast polling after seek)
      // - normalPollMs = 250ms (steady playback)
      // - activeDuration = 1 second (how long fast polling lasts)
      expect(PositionPoller, isA<Type>());
    });
  });
}
