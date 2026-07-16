import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/track_preferences.dart';

void main() {
  group('TrackPreferences', () {
    test('empty has default values', () {
      const prefs = TrackPreferences.empty;
      expect(prefs.audioTrackIndex, isNull);
      expect(prefs.subtitleTrackIndex, isNull);
      expect(prefs.subtitleDelay, 0);
    });

    test('copyWith overrides specified fields', () {
      const original = TrackPreferences(
        audioTrackIndex: 1,
        subtitleTrackIndex: 2,
        subtitleDelay: 500,
      );
      final copy = original.copyWith(audioTrackIndex: 3);
      expect(copy.audioTrackIndex, 3);
      expect(copy.subtitleTrackIndex, 2); // unchanged
      expect(copy.subtitleDelay, 500); // unchanged
    });

    test('copyWith can set nullable fields to null', () {
      const original = TrackPreferences(
        audioTrackIndex: 1,
        subtitleTrackIndex: 2,
      );
      final copy = original.copyWith(
        audioTrackIndex: null,
        subtitleTrackIndex: null,
      );
      expect(copy.audioTrackIndex, isNull);
      expect(copy.subtitleTrackIndex, isNull);
    });

    test('equality works correctly', () {
      const a = TrackPreferences(audioTrackIndex: 1, subtitleTrackIndex: 2, subtitleDelay: 300);
      const b = TrackPreferences(audioTrackIndex: 1, subtitleTrackIndex: 2, subtitleDelay: 300);
      const c = TrackPreferences(audioTrackIndex: 1, subtitleTrackIndex: 3, subtitleDelay: 300);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString includes all fields', () {
      const prefs = TrackPreferences(
        audioTrackIndex: 0,
        subtitleTrackIndex: -1,
        subtitleDelay: 500,
      );
      expect(prefs.toString(), contains('audio: 0'));
      expect(prefs.toString(), contains('subtitle: -1'));
      expect(prefs.toString(), contains('delay: 500ms'));
    });
  });
}
