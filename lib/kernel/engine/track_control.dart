import 'package:simple_player_flutter/kernel/engine/models/audio_track_info.dart';

/// 音轨控制接口
///
/// 支持查询可用音轨、切换音轨、获取当前活跃音轨。
/// 与旧 mixin 不同，此接口包含实际方法签名而非空标记。
abstract class TrackControl {
  /// 获取所有可用音轨
  ///
  /// requires: 无（disposed 后返回空列表，见基线实现）
  /// ensures: 返回当前媒体的音轨元信息快照
  /// modifies: 无（纯读取，委托 TrackManager）
  List<AudioTrackInfo> getAudioTracks();

  /// 切换到指定音轨
  ///
  /// requires: 无（disposed 时 no-op；trackId 越界由 TrackManager 内部处理）
  /// ensures: 活跃音轨切换为 trackId
  /// modifies: activeAudioTracks（委托 TrackManager，不经 ValueNotifier）
  void switchAudioTrack(int trackId);

  /// 当前活跃音轨 ID 列表
  ///
  /// requires: 无
  /// ensures: disposed 后返回空列表 []，否则返回 TrackManager 当前活跃音轨
  /// modifies: 无（纯读取）
  List<int> get activeAudioTracks;
}
