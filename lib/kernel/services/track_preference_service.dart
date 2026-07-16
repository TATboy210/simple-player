/// 轨道偏好管理 — 加载、保存、恢复用户选择的音频/字幕轨道
///
/// 本文件实现 [TrackPreferenceService] 作为轨道偏好的持久化管理者：
/// 1. 初始化时从 [SettingsStore] 加载轨道偏好
/// 2. open() 成功后自动恢复用户的音频/字幕轨道选择
/// 3. 销毁时异步保存当前轨道偏好到 [SettingsStore]
///
/// 架构位置：PlaybackController → **TrackPreferenceService** → MediaEngine (TrackControl + SubtitleConfig)
library;

import '../engine/engine_state.dart';
import '../models/track_preferences.dart';
import '../persistence/settings_store.dart';
import '../utils/log.dart';

/// 轨道偏好服务 — 加载、保存、恢复用户选择的音频/字幕轨道和字幕延迟
class TrackPreferenceService {
  TrackPreferenceService(this._engine);

  final MediaEngine _engine;
  TrackPreferences _current = TrackPreferences.empty;

  /// 当前偏好（只读，供测试断言）
  TrackPreferences get current => _current;

  /// 从 [SettingsStore] 加载轨道偏好
  Future<void> load() async {
    try {
      _current = await SettingsStore.loadTrackPreferences();
    } on Exception catch (e) {
      log.e('TrackPreferenceService.load failed: $e');
      _current = TrackPreferences.empty;
    }
  }

  /// 在 open() 成功后恢复轨道偏好
  ///
  /// 边界处理：偏好索引超出当前文件轨道数 → 静默忽略
  void restoreAfterOpen(MediaInfo mediaInfo) {
    // 恢复音频轨道
    if (_current.audioTrackIndex != null) {
      final idx = _current.audioTrackIndex!;
      if (idx >= 0 && idx < mediaInfo.audioTracks.length) {
        _engine.switchAudioTrack(idx);
      }
    }

    // 恢复字幕轨道
    if (_current.subtitleTrackIndex != null) {
      final idx = _current.subtitleTrackIndex!;
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

  /// 记录用户当前的音频轨道选择
  void recordAudioTrack(int index) {
    _current = _current.copyWith(audioTrackIndex: index);
  }

  /// 记录用户当前的字幕轨道选择（-1 表示关闭字幕）
  void recordSubtitleTrack(int index) {
    _current = _current.copyWith(subtitleTrackIndex: index);
  }

  /// 记录用户当前的字幕延迟
  void recordSubtitleDelay(int delay) {
    _current = _current.copyWith(subtitleDelay: delay);
  }

  /// 持久化当前偏好到 [SettingsStore]
  Future<void> save() async {
    try {
      await SettingsStore.saveTrackPreferences(_current);
    } on Exception catch (e) {
      log.e('TrackPreferenceService.save failed: $e');
    }
  }
}
