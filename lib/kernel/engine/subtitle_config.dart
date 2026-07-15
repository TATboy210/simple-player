import 'package:simple_player_flutter/kernel/engine/models/subtitle_track_info.dart';

/// 字幕配置接口
///
/// 包含字幕轨道管理、外部字幕加载、字幕延迟调整、均衡器设置。
/// 只包含控制方法；subtitleText 状态由 [EngineStateView] 提供。
abstract class SubtitleConfig {
  /// 获取所有可用字幕轨道
  List<SubtitleTrackInfo> getSubtitleTracks();

  /// 切换到指定字幕轨道
  void switchSubtitleTrack(int trackId);

  /// 切换字幕开/关
  void toggleSubtitle();

  /// 加载外部字幕文件
  void setExternalSubtitle(String path);

  /// 设置字幕延迟（毫秒，正值延后，负值提前）
  void setSubtitleDelay(int delay);

  /// 设置音频均衡器预设
  void setEqualizer(String preset);

  /// 当前字幕延迟（毫秒）
  int get subtitleDelay;

  /// 当前活跃字幕轨道索引列表（空 = 字幕关闭）
  List<int> get activeSubtitleTracks;
}
