import 'package:simple_player_flutter/kernel/engine/models/subtitle_track_info.dart';

/// 字幕配置接口
///
/// 包含字幕轨道管理、外部字幕加载、字幕延迟调整、均衡器设置。
/// 只包含控制方法；subtitleText 状态由 [EngineStateView] 提供。
abstract class SubtitleConfig {
  /// 获取所有可用字幕轨道
  ///
  /// requires: 无
  /// ensures: 返回当前媒体的字幕轨道元信息快照（委托 TrackManager）
  /// modifies: 无（纯读取）
  List<SubtitleTrackInfo> getSubtitleTracks();

  /// 切换到指定字幕轨道
  ///
  /// requires: 无（disposed 时 no-op；trackId 越界由 TrackManager 内部处理）
  /// ensures: 活跃字幕轨道切换为 trackId
  /// modifies: activeSubtitleTracks（委托 TrackManager，不经 ValueNotifier）
  void switchSubtitleTrack(int trackId);

  /// 切换字幕开/关
  ///
  /// requires: 无（disposed 时 no-op）
  /// ensures: activeSubtitleTracks 在空/非空之间切换
  /// modifies: activeSubtitleTracks（委托 TrackManager）
  void toggleSubtitle();

  /// 加载外部字幕文件
  ///
  /// requires: 无（path 有效性由底层引擎处理）
  /// ensures: 底层引擎加载指定外部字幕文件
  /// modifies: 无 ValueNotifier（仅委托底层引擎，不反映到状态视图）
  void setExternalSubtitle(String path);

  /// 设置字幕延迟（毫秒，正值延后，负值提前）
  ///
  /// requires: 无
  /// ensures: subtitleDelay == delay
  /// modifies: 无 ValueNotifier（subtitleDelay 为普通 getter，非 ValueNotifier）
  void setSubtitleDelay(int delay);

  /// 设置音频均衡器预设
  ///
  /// requires: 无（preset 格式由底层 af filter 语法约束）
  /// ensures: 底层播放器应用指定均衡器 af filter
  /// modifies: 无 ValueNotifier（仅委托底层引擎）
  void setEqualizer(String preset);

  /// 当前字幕延迟（毫秒）
  ///
  /// requires: 无
  /// ensures: disposed 后返回 0，否则返回底层引擎当前延迟值
  /// modifies: 无（纯读取）
  int get subtitleDelay;

  /// 当前活跃字幕轨道索引列表（空 = 字幕关闭）
  ///
  /// requires: 无
  /// ensures: disposed 后返回空列表 []，否则返回 TrackManager 当前活跃字幕轨道
  /// modifies: 无（纯读取）
  List<int> get activeSubtitleTracks;
}
