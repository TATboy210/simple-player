import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;

import '../models/media_info.dart';

/// 轨道管理器 — 音频/字幕轨道选择与切换
///
/// 职责:
///   - 获取可用音轨/字幕轨列表
///   - 切换音轨/字幕轨
///   - 切换字幕开关
class TrackManager {
  final mdk.Player _player;
  MediaInfo _mediaInfo = const MediaInfo();

  TrackManager(this._player);

  /// 当前媒体信息（open 后更新）
  MediaInfo get mediaInfo => _mediaInfo;

  /// 更新媒体信息（由 FvpEngine.open 调用）
  void updateMediaInfo(MediaInfo info) {
    _mediaInfo = info;
  }

  /// 获取可用音轨列表
  List<AudioTrackInfo> getAudioTracks() => _mediaInfo.audioTracks;

  /// 切换到指定音轨索引
  void switchAudioTrack(int trackIndex) {
    final tracks = _mediaInfo.audioTracks;
    if (tracks.isEmpty || trackIndex < 0 || trackIndex >= tracks.length) return;
    try {
      _player.activeAudioTracks = [trackIndex];
    } on Exception catch (e) {
      debugPrint('TrackManager.switchAudioTrack error: $e');
    }
  }

  /// 获取当前激活的音轨索引列表
  List<int> get activeAudioTracks => _player.activeAudioTracks;

  /// 获取可用字幕轨道列表
  List<SubtitleTrackInfo> getSubtitleTracks() => _mediaInfo.subtitleTracks;

  /// 切换到指定字幕轨道，传 -1 关闭字幕
  void switchSubtitleTrack(int trackIndex) {
    try {
      if (trackIndex < 0) {
        _player.activeSubtitleTracks = [];
      } else {
        _player.activeSubtitleTracks = [trackIndex];
      }
    } on Exception catch (e) {
      debugPrint('TrackManager.switchSubtitleTrack error: $e');
    }
  }

  /// 切换字幕开关
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
