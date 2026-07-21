import 'package:simple_player_flutter/kernel/engine/models/audio_track_info.dart';

/// 音轨控制接口
///
/// 支持查询可用音轨、切换音轨、获取当前活跃音轨。
/// 与旧 mixin 不同，此接口包含实际方法签名而非空标记。
///
/// Contract:
/// - All methods delegate to [TrackManager] — no direct engine mutation.
/// - Pure read methods return empty lists when the engine is disposed.
abstract class TrackControl {
  /// 获取所有可用音轨
  ///
  /// - Returns: snapshot of available audio tracks for the current media.
  /// - Returns empty list when the engine is disposed.
  /// - Pure read: no side effects.
  List<AudioTrackInfo> getAudioTracks();

  /// 切换到指定音轨
  ///
  /// - `trackId`: target track index; out-of-range handled internally by TrackManager.
  /// - Side effect: updates the active audio track.
  /// - No-op when the engine is disposed.
  void switchAudioTrack(int trackId);

  /// 当前活跃音轨 ID 列表
  ///
  /// - Returns: currently active audio track IDs; empty list when disposed.
  /// - Pure read: no side effects.
  List<int> get activeAudioTracks;
}
