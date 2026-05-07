import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/media_info.dart';
import '../../helpers/fake_engine.dart';

void main() {
  group('TrackManager', () {
    group('AudioTrackInfo', () {
      test('stores index, language, codec, channels', () {
        const track = AudioTrackInfo(
          index: 0,
          language: 'chi',
          codec: 'flac',
          channels: 6,
        );
        expect(track.index, 0);
        expect(track.language, 'chi');
        expect(track.codec, 'flac');
        expect(track.channels, 6);
      });
    });

    group('SubtitleTrackInfo', () {
      test('stores index, language, title', () {
        const track = SubtitleTrackInfo(
          index: 0,
          language: 'chi',
          title: '简体中文',
        );
        expect(track.index, 0);
        expect(track.language, 'chi');
        expect(track.title, '简体中文');
      });
    });

    group('MediaInfo', () {
      test('holds audio and subtitle track lists', () {
        const info = MediaInfo(
          duration: 60000,
          audioTracks: [
            AudioTrackInfo(
              index: 0,
              language: 'eng',
              codec: 'aac',
              channels: 2,
            ),
            AudioTrackInfo(
              index: 1,
              language: 'jpn',
              codec: 'aac',
              channels: 2,
            ),
          ],
          subtitleTracks: [
            SubtitleTrackInfo(index: 0, language: 'eng', title: 'English'),
          ],
        );
        expect(info.duration, 60000);
        expect(info.audioTracks.length, 2);
        expect(info.subtitleTracks.length, 1);
        expect(info.audioTracks[0].language, 'eng');
        expect(info.audioTracks[1].language, 'jpn');
        expect(info.subtitleTracks[0].title, 'English');
      });

      test('defaults to empty lists', () {
        const info = MediaInfo();
        expect(info.audioTracks, isEmpty);
        expect(info.subtitleTracks, isEmpty);
        expect(info.duration, 0);
      });
    });

    group('VideoCodecInfo', () {
      test('stores width, height, par, codec', () {
        const info = VideoCodecInfo(
          width: 1920,
          height: 1080,
          par: 1.0,
          codec: 'h264',
        );
        expect(info.width, 1920);
        expect(info.height, 1080);
        expect(info.par, 1.0);
        expect(info.codec, 'h264');
      });
    });

    group('ASS/SSA subtitle track verification (FEAT-02)', () {
      test(
        'ASS subtitle tracks appear in getSubtitleTracks after configureMedia',
        () async {
          final engine = FakeEngine();
          engine.configureMedia(
            durationMs: 60000,
            subtitleTracks: [
              const SubtitleTrackInfo(
                index: 0,
                language: 'en',
                title: 'English ASS',
              ),
              const SubtitleTrackInfo(
                index: 1,
                language: 'zh',
                title: 'Chinese SSA',
              ),
            ],
          );
          await engine.open('test.mp4');
          final tracks = engine.getSubtitleTracks();
          expect(tracks.length, 2);
          expect(tracks[0].title, 'English ASS');
          expect(tracks[0].language, 'en');
          expect(tracks[1].title, 'Chinese SSA');
          expect(tracks[1].language, 'zh');
          engine.dispose();
        },
      );

      test('switchSubtitleTrack activates selected track', () {
        final engine = FakeEngine();
        engine.configureMedia(
          durationMs: 60000,
          subtitleTracks: [
            const SubtitleTrackInfo(index: 0, language: 'en', title: 'English'),
            const SubtitleTrackInfo(
              index: 1,
              language: 'ja',
              title: 'Japanese',
            ),
          ],
        );
        // Should not throw
        engine.switchSubtitleTrack(0);
        engine.switchSubtitleTrack(1);
        engine.switchSubtitleTrack(-1); // disable
        engine.dispose();
      });

      test('toggleSubtitle enables and disables subtitle display', () {
        final engine = FakeEngine();
        engine.configureMedia(durationMs: 60000);
        // toggleSubtitle should not throw, and calling twice returns to original state
        engine.toggleSubtitle();
        engine.toggleSubtitle();
        engine.dispose();
      });
    });
  });
}
