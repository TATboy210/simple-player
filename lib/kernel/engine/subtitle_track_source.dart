import 'models/subtitle_track_info.dart';

/// 字幕轨道查询/切换接口
///
/// 从 TrackManager 提取的字幕轨道方法，供 SubtitleConfigurator 依赖。
/// 避免 SubtitleConfigurator 直接依赖 TrackManager 具体类。
abstract class SubtitleTrackSource {
  /// 获取所有可用字幕轨道
  List<SubtitleTrackInfo> getSubtitleTracks();

  /// 切换到指定字幕轨道
  void switchSubtitleTrack(int trackId);

  /// 切换字幕开/关
  void toggleSubtitle();

  /// 当前活跃字幕轨道索引列表（空 = 字幕关闭）
  List<int> get activeSubtitleTracks;
}
