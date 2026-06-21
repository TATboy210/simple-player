import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_v2/core/events/player_events.dart';
import 'package:simple_player_v2/core/state/playback_state.dart';

void main() {
  group('PlayerEvent', () {
    test('StateChanged carries state', () {
      const e = StateChanged(PlaybackState.playing);
      expect(e.state, PlaybackState.playing);
    });

    test('PositionChanged carries position and duration', () {
      const e = PositionChanged(1000, 5000);
      expect(e.positionMs, 1000);
      expect(e.durationMs, 5000);
    });

    test('TrackChanged carries type and id', () {
      const e = TrackChanged('audio', 2);
      expect(e.trackType, 'audio');
      expect(e.trackId, 2);
    });

    test('TrackChanged id is optional', () {
      const e = TrackChanged('sub');
      expect(e.trackType, 'sub');
      expect(e.trackId, isNull);
    });

    test('TrackInfo is immutable', () {
      const info = TrackInfo(id: 1, type: 'audio', title: 'English', lang: 'en');
      expect(info.id, 1);
      expect(info.type, 'audio');
      expect(info.title, 'English');
      expect(info.lang, 'en');
      expect(info.selected, false);
    });

    test('ErrorOccurred carries message and optional code', () {
      const e1 = ErrorOccurred('fail');
      expect(e1.message, 'fail');
      expect(e1.code, isNull);

      const e2 = ErrorOccurred('fail', 'E001');
      expect(e2.code, 'E001');
    });
  });
}
