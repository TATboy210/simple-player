import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/models/track_preferences.dart';
import 'package:simple_player_flutter/kernel/services/track_preference_service.dart';

import '../../helpers/fake_engine.dart';

void main() {
  group('TrackPreferenceService', () {
    late FakeEngine engine;
    late TrackPreferenceService service;

    setUp(() {
      engine = FakeEngine();
      service = TrackPreferenceService(engine);
    });

    test('initial state is empty preferences', () {
      expect(service.current, TrackPreferences.empty);
    });

    group('restoreAfterOpen', () {
      test('restores audio track when index is valid', () {
        engine.configureMedia(
          audioTracks: [
            const AudioTrackInfo(index: 0, language: 'en'),
            const AudioTrackInfo(index: 1, language: 'zh'),
          ],
        );
        service.recordAudioTrack(1);
        // Should not throw
        service.restoreAfterOpen(engine.mediaInfo);
      });

      test('ignores audio track when index is out of range', () {
        engine.configureMedia(
          audioTracks: [const AudioTrackInfo(index: 0, language: 'en')],
        );
        service.recordAudioTrack(5);
        // Should not throw
        service.restoreAfterOpen(engine.mediaInfo);
      });

      test('restores subtitle track when index is valid', () {
        engine.configureMedia(
          subtitleTracks: [
            const SubtitleTrackInfo(index: 0, language: 'en', title: 'English'),
            const SubtitleTrackInfo(index: 1, language: 'zh', title: 'Chinese'),
          ],
        );
        service.recordSubtitleTrack(1);
        service.restoreAfterOpen(engine.mediaInfo);
      });

      test('restores subtitle off (-1) even with no tracks', () {
        engine.configureMedia(subtitleTracks: []);
        service.recordSubtitleTrack(-1);
        service.restoreAfterOpen(engine.mediaInfo);
      });

      test('restores subtitle delay', () {
        service.recordSubtitleDelay(500);
        service.restoreAfterOpen(engine.mediaInfo);
        expect(engine.subtitleDelay, 500);
      });

      test('does not restore delay when it is 0', () {
        service.recordSubtitleDelay(0);
        service.restoreAfterOpen(engine.mediaInfo);
        expect(engine.subtitleDelay, 0);
      });

      test('ignores subtitle track when index is out of range', () {
        engine.configureMedia(
          subtitleTracks: [const SubtitleTrackInfo(index: 0, language: 'en', title: 'English')],
        );
        service.recordSubtitleTrack(5);
        service.restoreAfterOpen(engine.mediaInfo);
      });
    });

    group('record methods', () {
      test('recordAudioTrack updates current preference', () {
        service.recordAudioTrack(2);
        expect(service.current.audioTrackIndex, 2);
      });

      test('recordSubtitleTrack updates current preference', () {
        service.recordSubtitleTrack(-1);
        expect(service.current.subtitleTrackIndex, -1);
      });

      test('recordSubtitleDelay updates current preference', () {
        service.recordSubtitleDelay(1000);
        expect(service.current.subtitleDelay, 1000);
      });
    });
  });
}
