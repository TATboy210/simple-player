import 'models/subtitle_track_info.dart';

/// 字幕轨道查询/切换接口
///
/// Contract:
/// - Extracted from TrackManager so SubtitleConfigurator depends on
///   this interface rather than the concrete class.
/// - Implementations must return current-state snapshots; callers must
///   not assume the returned lists are live views.
/// - After dispose, all getters return empty lists and mutators are no-ops.
abstract class SubtitleTrackSource {
  /// 获取所有可用字幕轨道
  ///
  /// Contract:
  /// - Returns a snapshot of available subtitle tracks for the current media.
  /// - Returns an empty list if no media is loaded or after dispose.
  List<SubtitleTrackInfo> getSubtitleTracks();

  /// 切换到指定字幕轨道
  ///
  /// Contract:
  /// - [trackId] is the index into the track list returned by [getSubtitleTracks].
  /// - No-op if [trackId] is out of range or after dispose.
  void switchSubtitleTrack(int trackId);

  /// 切换字幕开/关
  ///
  /// Contract:
  /// - Toggles subtitle rendering on/off.
  /// - No-op after dispose.
  void toggleSubtitle();

  /// 当前活跃字幕轨道索引列表（空 = 字幕关闭）
  ///
  /// Contract:
  /// - Returns active subtitle track indices, or empty list if subtitles
  ///   are off or after dispose.
  List<int> get activeSubtitleTracks;
}
