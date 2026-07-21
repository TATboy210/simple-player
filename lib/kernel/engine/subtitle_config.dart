import 'package:simple_player_flutter/kernel/engine/models/subtitle_track_info.dart';

/// 字幕配置接口
///
/// 包含字幕轨道管理、外部字幕加载、字幕延迟调整、均衡器设置。
/// 只包含控制方法；subtitleText 状态由 [EngineStateView] 提供。
///
/// Contract:
/// - Control methods delegate to the underlying engine — no ValueNotifier mutation.
/// - Pure read members return safe defaults when the engine is disposed.
abstract class SubtitleConfig {
  /// 获取所有可用字幕轨道
  ///
  /// - Returns: snapshot of available subtitle tracks for the current media.
  /// - Pure read: no side effects.
  List<SubtitleTrackInfo> getSubtitleTracks();

  /// 切换到指定字幕轨道
  ///
  /// - `trackId`: target subtitle track index; out-of-range handled internally.
  /// - Side effect: updates the active subtitle track.
  /// - No-op when the engine is disposed.
  void switchSubtitleTrack(int trackId);

  /// 切换字幕开/关
  ///
  /// - Side effect: toggles subtitle between enabled (non-empty tracks) and disabled (empty).
  /// - No-op when the engine is disposed.
  void toggleSubtitle();

  /// 加载外部字幕文件
  ///
  /// - `path`: file system path to the external subtitle file.
  /// - Side effect: loads the subtitle file into the underlying engine.
  /// - No-op when the engine is disposed.
  void setExternalSubtitle(String path);

  /// 设置字幕延迟（毫秒，正值延后，负值提前）
  ///
  /// - `delay`: delay in milliseconds; positive = later, negative = earlier.
  /// - Side effect: updates subtitle timing in the underlying engine.
  /// - No-op when the engine is disposed.
  void setSubtitleDelay(int delay);

  /// 设置音频均衡器预设
  ///
  /// - `preset`: EQ preset string; format constrained by the underlying af filter syntax.
  /// - Side effect: applies the EQ preset to the underlying player.
  /// - No-op when the engine is disposed.
  void setEqualizer(String preset);

  /// 当前字幕延迟（毫秒）
  ///
  /// - Returns: current subtitle delay in ms; 0 when disposed.
  /// - Pure read: no side effects.
  int get subtitleDelay;

  /// 当前活跃字幕轨道索引列表（空 = 字幕关闭）
  ///
  /// - Returns: currently active subtitle track IDs; empty list when disposed or disabled.
  /// - Pure read: no side effects.
  List<int> get activeSubtitleTracks;
}
