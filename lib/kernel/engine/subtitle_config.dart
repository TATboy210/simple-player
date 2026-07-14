import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/engine/models/subtitle_track_info.dart';

/// 字幕配置接口
///
/// 包含字幕轨道管理、外部字幕加载、字幕延迟调整、均衡器设置。
/// subtitleText getter 返回与 [EngineStateView] 相同的 ValueNotifier 实例。
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

  /// 当前字幕文本 — 与 EngineStateView.subtitleText 同一实例
  ValueNotifier<String> get subtitleText;

  /// 当前字幕延迟（毫秒）
  int get subtitleDelay;
}
