/// 应用偏好持久化 — 播放/视频/音频/断点设置 (v0.0.6).
///
/// App settings persistence — playback/video/audio/resume preferences.
///
/// shared_preferences 存储 (WindowPersistence 同风格), **每 key 独立写**
/// — 无读改写竞态; 调用方 (AppSettingsService) 负责防抖.
/// 本类是纯持久化层: 无 notifier、无业务编排, 读写均逐字段容错回退默认.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/player/models/video_processing_state.dart';
import '../models/aspect_ratio_mode.dart';

/// 应用偏好快照 — 一次 load 的不可变结果.
///
/// 各字段缺省即默认值: 音量 1.0 / 非静音 / 倍速 1.0 / 记住断点开 /
/// 硬解开 / 无延迟 / 视频效果全零.
final class AppSettingsData {
  const AppSettingsData({
    this.volume = 1.0,
    this.isMuted = false,
    this.playbackRate = 1.0,
    this.resumeEnabled = true,
    this.hardwareDecoding = true,
    this.audioDelayMs = 0,
    this.subtitleDelayMs = 0,
    this.video = VideoProcessingState.defaults,
  });

  /// 音量 (0.0 ~ 1.0).
  final double volume;

  /// 静音.
  final bool isMuted;

  /// 播放倍速 (0.25 ~ 4.0).
  final double playbackRate;

  /// 断点续播总开关 (记住播放位置).
  final bool resumeEnabled;

  /// 硬件解码 (mpv hwdec auto/no).
  final bool hardwareDecoding;

  /// 音频延迟 (毫秒).
  final int audioDelayMs;

  /// 字幕延迟 (毫秒).
  final int subtitleDelayMs;

  /// 视频处理状态 (亮度/对比度/饱和度/色调/去隔行/旋转/宽高比).
  final VideoProcessingState video;
}

/// 应用偏好存储 — 纯读写, 无状态编排.
final class AppSettingsStore {
  /// [_preferences] 可注入以隔离测试; 默认 shared_preferences 单例
  /// (WindowPersistence 同款私有初始化形参模式).
  AppSettingsStore({this._preferences});

  static const _volumeKey = 'settingsVolume';
  static const _mutedKey = 'settingsMuted';
  static const _rateKey = 'settingsPlaybackRate';
  static const _resumeKey = 'settingsResumeEnabled';
  static const _hwdecKey = 'settingsHardwareDecoding';
  static const _audioDelayKey = 'settingsAudioDelayMs';
  static const _subtitleDelayKey = 'settingsSubtitleDelayMs';
  static const _videoKey = 'settingsVideoProcessing';

  final SharedPreferences? _preferences;

  /// 读取快照 — 任一字段损坏/缺失回退该字段默认, 绝不抛出.
  Future<AppSettingsData> load() async {
    try {
      final prefs = await _getPreferences();
      return AppSettingsData(
        volume: (prefs.getDouble(_volumeKey) ?? 1.0).clamp(0.0, 1.0),
        isMuted: prefs.getBool(_mutedKey) ?? false,
        playbackRate: (prefs.getDouble(_rateKey) ?? 1.0).clamp(0.25, 4.0),
        resumeEnabled: prefs.getBool(_resumeKey) ?? true,
        hardwareDecoding: prefs.getBool(_hwdecKey) ?? true,
        audioDelayMs: prefs.getInt(_audioDelayKey) ?? 0,
        subtitleDelayMs: prefs.getInt(_subtitleDelayKey) ?? 0,
        video: _parseVideo(prefs.getString(_videoKey)),
      );
    } on Exception {
      // 存储不可用视作无历史 — 默认值不阻断启动.
      return const AppSettingsData();
    }
  }

  Future<void> saveVolume(double v) => _write(_volumeKey, v.clamp(0.0, 1.0));

  Future<void> saveMuted(bool v) => _write(_mutedKey, v);

  Future<void> savePlaybackRate(double v) =>
      _write(_rateKey, v.clamp(0.25, 4.0));

  Future<void> saveResumeEnabled(bool v) => _write(_resumeKey, v);

  Future<void> saveHardwareDecoding(bool v) => _write(_hwdecKey, v);

  Future<void> saveAudioDelayMs(int v) => _write(_audioDelayKey, v);

  Future<void> saveSubtitleDelayMs(int v) => _write(_subtitleDelayKey, v);

  /// 视频处理状态 — 序列化为单 key JSON blob (原子整体写).
  Future<void> saveVideo(VideoProcessingState v) => _write(_videoKey, jsonEncode({
    'brightness': v.brightness,
    'contrast': v.contrast,
    'saturation': v.saturation,
    'hue': v.hue,
    'deinterlaceEnabled': v.deinterlaceEnabled,
    'rotation': v.rotation,
    'aspectRatioMode': v.aspectRatioMode.name,
  }));

  Future<void> _write(String key, Object value) async {
    try {
      final prefs = await _getPreferences();
      switch (value) {
        case final double v:
          await prefs.setDouble(key, v);
        case final bool v:
          await prefs.setBool(key, v);
        case final int v:
          await prefs.setInt(key, v);
        case final String v:
          await prefs.setString(key, v);
      }
    } on Exception {
      // 写失败仅丢偏好 — 播放流程不受阻 (与 PlaylistStore 同哲学).
    }
  }

  Future<SharedPreferences> _getPreferences() async {
    final prefs = _preferences;
    if (prefs != null) return prefs;
    return SharedPreferences.getInstance();
  }

  /// 视频状态 JSON 反序列化 — 逐字段容错, 未知/缺失回退默认.
  static VideoProcessingState _parseVideo(String? raw) {
    if (raw == null) return VideoProcessingState.defaults;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return VideoProcessingState.defaults;
    }
    if (decoded is! Map<String, dynamic>) return VideoProcessingState.defaults;
    final modeName = decoded['aspectRatioMode'];
    final mode = AspectRatioMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => AspectRatioMode.keepOriginal,
    );
    return VideoProcessingState(
      brightness: _asDouble(decoded['brightness']),
      contrast: _asDouble(decoded['contrast']),
      saturation: _asDouble(decoded['saturation']),
      hue: _asDouble(decoded['hue']),
      deinterlaceEnabled: decoded['deinterlaceEnabled'] is bool
          ? decoded['deinterlaceEnabled'] as bool
          : false,
      rotation: _asInt(decoded['rotation']),
      aspectRatioMode: mode,
    );
  }

  static double _asDouble(Object? v) => v is num ? v.toDouble() : 0.0;

  static int _asInt(Object? v) => v is num ? v.toInt() : 0;
}
