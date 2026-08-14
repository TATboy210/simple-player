/// 轨道运行时状态管理 — 记录并恢复当前会话中的音频/字幕选择。
///
/// 跨会话用户设置已移除；该服务只保留播放会话内的轨道状态。
///
/// Architecture: PlaybackController → **TrackPreferenceService** → MediaEngine (TrackControl + SubtitleConfig).
library;

import '../engine/engine_state.dart';
import '../models/track_preferences.dart';

/// 轨道偏好服务 — 加载、保存、恢复用户选择的音频/字幕轨道和字幕延迟.
///
/// Track preference service — loads, saves, restores audio/subtitle track
/// selections and subtitle delay.
class TrackPreferenceService {
  TrackPreferenceService(this._engine);

  final MediaEngine _engine;
  TrackPreferences _current = TrackPreferences.empty;

  /// 当前偏好（只读，供测试断言）.
  ///
  /// Current preferences (read-only, for test assertions).
  TrackPreferences get current => _current;

  /// 在 open() 成功后恢复轨道偏好.
  ///
  /// Restores track preferences after successful open().
  /// Out-of-range preference indices are silently ignored.
  void restoreAfterOpen(MediaInfo mediaInfo) {
    // 恢复音频轨道 — if-case 绑定非 null idx, 消除字段 `!`
    if (_current.audioTrackIndex case final idx?) {
      if (idx >= 0 && idx < mediaInfo.audioTracks.length) {
        _engine.switchAudioTrack(idx);
      }
    }

    // 恢复字幕轨道 — if-case 绑定非 null idx, 消除字段 `!`
    if (_current.subtitleTrackIndex case final idx?) {
      if (idx == -1) {
        _engine.switchSubtitleTrack(-1);
      } else if (idx >= 0 && idx < mediaInfo.subtitleTracks.length) {
        _engine.switchSubtitleTrack(idx);
      }
    }

    // 恢复字幕延迟
    if (_current.subtitleDelay != 0) {
      _engine.setSubtitleDelay(_current.subtitleDelay);
    }
  }

  /// 记录用户当前的音频轨道选择.
  ///
  /// Records user's current audio track selection.
  void recordAudioTrack(int index) {
    _current = _current.copyWith(audioTrackIndex: index);
  }

  /// 记录用户当前的字幕轨道选择（-1 表示关闭字幕）.
  ///
  /// Records user's current subtitle track selection (-1 = disabled).
  void recordSubtitleTrack(int index) {
    _current = _current.copyWith(subtitleTrackIndex: index);
  }

  /// 记录用户当前的字幕延迟.
  ///
  /// Records user's current subtitle delay.
  void recordSubtitleDelay(int delay) {
    _current = _current.copyWith(subtitleDelay: delay);
  }
}
