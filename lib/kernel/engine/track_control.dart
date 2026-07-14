import 'package:simple_player_flutter/kernel/engine/models/audio_track_info.dart';

/// 音轨控制接口
///
/// 支持查询可用音轨、切换音轨、获取当前活跃音轨。
/// 与旧 mixin 不同，此接口包含实际方法签名而非空标记。
abstract class TrackControl {
  /// 获取所有可用音轨
  List<AudioTrackInfo> getAudioTracks();

  /// 切换到指定音轨
  void switchAudioTrack(int trackId);

  /// 当前活跃音轨 ID 列表
  List<int> get activeAudioTracks;
}
