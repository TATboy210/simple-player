/// BreakpointSaver unit tests — pure Dart, no mdk.dll dependency.
///
/// Tests the observer pattern: listens to MediaState.paused and saves
/// playback position to Playlist via PlaylistStore. Also tests the
/// dispose() fallback save logic.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/services/breakpoint_saver.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late Playlist playlist;
  late BreakpointSaver saver;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    saver = BreakpointSaver(engine: engine, playlist: playlist);
  });

  tearDown(() {
    saver.dispose();
    engine.dispose();
  });

  group('BreakpointSaver', () {
    group('init', () {
      test('registers state change listener', () {
        // init() should not throw when registering listener
        expect(() => saver.init(), returnsNormally);
      });

      test('does not save on non-paused state transitions', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = 0;
        saver.init();
        // Transition to playing — should NOT trigger save
        engine.state.value = MediaState.playing;
        // Position should remain at default (no updatePosition called)
        expect(playlist.items[0].positionMs, isNull);
      });
    });

    group('onStateChanged (paused trigger)', () {
      test('saves position when state becomes paused and currentIndex >= 0', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = 0;
        engine.position.value = 15000;
        engine.duration.value = 60000;
        saver.init();

        // Trigger paused state
        engine.state.value = MediaState.paused;

        // Verify position was saved to playlist item
        expect(playlist.items[0].positionMs, 15000);
        expect(playlist.items[0].durationMs, 60000);
      });

      test('does not save when state is not paused', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = 0;
        engine.position.value = 15000;
        saver.init();

        // Transition to error — should NOT save
        engine.state.value = MediaState.error;
        expect(playlist.items[0].positionMs, isNull);

        // Transition to completed — should NOT save
        engine.state.value = MediaState.completed;
        expect(playlist.items[0].positionMs, isNull);
      });

      test('does not save when currentIndex < 0 (no current item)', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = -1; // no current item
        engine.position.value = 15000;
        saver.init();

        // Trigger paused state — should NOT save
        engine.state.value = MediaState.paused;
        expect(playlist.items[0].positionMs, isNull);
      });

      test('saves duration along with position', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = 0;
        engine.position.value = 30000;
        engine.duration.value = 120000;
        saver.init();

        engine.state.value = MediaState.paused;

        expect(playlist.items[0].positionMs, 30000);
        expect(playlist.items[0].durationMs, 120000);
      });
    });

    group('dispose', () {
      test('removes state listener', () {
        saver.init();
        // dispose should not throw when removing listener
        expect(() => saver.dispose(), returnsNormally);
      });

      test('saves position if position > 0 and currentIndex >= 0', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = 0;
        engine.position.value = 25000;
        engine.duration.value = 60000;

        saver.dispose();

        expect(playlist.items[0].positionMs, 25000);
        expect(playlist.items[0].durationMs, 60000);
      });

      test('does not save if position is 0 (never played)', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = 0;
        engine.position.value = 0; // never played

        saver.dispose();

        // position 0 should NOT trigger save (no meaningful progress)
        expect(playlist.items[0].positionMs, isNull);
      });

      test('does not save if currentIndex < 0', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = -1;
        engine.position.value = 25000;

        saver.dispose();

        // No current item — should NOT save
        expect(playlist.items[0].positionMs, isNull);
      });

      test('is idempotent (safe to call twice)', () {
        playlist.add('C:/a.mp4');
        playlist.currentIndex = 0;
        engine.position.value = 10000;

        saver.dispose();
        // Second dispose should not throw
        expect(() => saver.dispose(), returnsNormally);
      });
    });
  });
}
