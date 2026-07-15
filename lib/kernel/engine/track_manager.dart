import 'package:fvp/mdk.dart' as mdk;
import 'models/audio_track_info.dart';
import 'models/media_info.dart';
import 'models/subtitle_track_info.dart';
import 'track_control.dart';
import 'subtitle_track_source.dart';

import '../utils/log.dart';

/// Manages audio and subtitle track selection for a media player.
///
/// MDK uses index-based track selection — tracks are numbered 0..N in the
/// order reported by the demuxer. Track indices are NOT stable across files;
/// always query the current track list before switching.
///
/// Responsibilities:
///   - Query available audio/subtitle tracks
///   - Switch active audio/subtitle track by index
///   - Toggle subtitle on/off
class TrackManager implements TrackControl, SubtitleTrackSource {
  final mdk.Player _player;
  MediaInfo _mediaInfo = const MediaInfo();

  TrackManager(this._player);

  /// 当前媒体信息（open 后更新）
  MediaInfo get mediaInfo => _mediaInfo;

  /// 更新媒体信息（由 FvpEngine.open 调用）
  void updateMediaInfo(MediaInfo info) {
    _mediaInfo = info;
  }

  /// Returns the list of available audio tracks for the current media.
  @override
  List<AudioTrackInfo> getAudioTracks() => _mediaInfo.audioTracks;

  /// Switches to the audio track at [trackIndex].
  ///
  /// Index must be in range [0, trackCount). Out-of-range indices are
  /// silently ignored — MDK crashes on invalid track index, so we
  /// defensively check bounds first.
  @override
  void switchAudioTrack(int trackIndex) {
    final tracks = _mediaInfo.audioTracks;
    if (tracks.isEmpty || trackIndex < 0 || trackIndex >= tracks.length) return;
    try {
      _player.activeAudioTracks = [trackIndex];
    } on Exception catch (e) {
      log.e('TrackManager.switchAudioTrack error: $e');
    }
  }

  /// Returns the currently active audio track indices.
  @override
  List<int> get activeAudioTracks => _player.activeAudioTracks;

  @override
  List<int> get activeSubtitleTracks => _player.activeSubtitleTracks;

  /// Returns the list of available subtitle tracks for the current media.
  @override
  List<SubtitleTrackInfo> getSubtitleTracks() => _mediaInfo.subtitleTracks;

  /// Switches to the subtitle track at [trackIndex].
  ///
  /// Pass -1 (or any negative value) to disable subtitle output.
  /// Under the hood, passing empty list `[]` disables subtitle — this is
  /// MDK's convention, not a special "track -1".
  @override
  void switchSubtitleTrack(int trackIndex) {
    try {
      if (trackIndex < 0) {
        _player.activeSubtitleTracks = [];
      } else {
        _player.activeSubtitleTracks = [trackIndex];
      }
    } on Exception catch (e) {
      log.e('TrackManager.switchSubtitleTrack error: $e');
    }
  }

  /// Toggles subtitle on/off.
  ///
  /// Cycles between "first subtitle track" and "no subtitle" (not all tracks).
  /// Most content has one subtitle track, so cycling through all tracks
  /// would add unnecessary complexity for minimal benefit.
  @override
  void toggleSubtitle() {
    final tracks = _player.activeSubtitleTracks;
    if (tracks.isEmpty) {
      if (_mediaInfo.subtitleTracks.isNotEmpty) {
        _player.activeSubtitleTracks = [0];
      }
    } else {
      _player.activeSubtitleTracks = [];
    }
  }
}
