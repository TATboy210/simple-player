import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../kernel/engine/engine_state.dart';

import 'engine_constants.dart';
import '../utils/log.dart';
import '../utils/path_utils.dart';

// ─── 调试事件 ───

/// MockEngine 操作事件 — 记录每次播放控制调用。
class MockEvent {
  const MockEvent({
    required this.type,
    required this.timestamp,
    this.path = '',
    this.data,
  });

  final String type;
  final String path;
  final DateTime timestamp;
  final Map<String, Object>? data;

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
    if (path.isNotEmpty) json['path'] = path;
    if (data != null) json['data'] = data!;
    return json;
  }
}

/// 模拟播放引擎 — 用于开发调试，无需真实视频文件即可测试完整 UI 流程。
///
/// 用法：
/// ```dart
/// // 在 app.dart 或 main.dart 中替换 FvpEngine
/// final engine = MockEngine();
/// engine.configureMedia(durationMs: 120000, width: 1920, height: 1080);
/// ```
///
/// 特性：
/// - 播放时 position 自动递增（模拟真实播放）
/// - 完整状态机：idle → loading → playing ↔ paused → stopped/completed
/// - 可配置 open 延迟、错误注入
/// - 状态变化历史记录（调试用）
class MockEngine with EngineState, TrackControl, VideoEffects, RendererConfig {
  bool _disposed = false;
  Timer? _positionTimer;

  MockEngine({
    this.openDelay = const Duration(milliseconds: 200),
    this.autoPlay = true,
  });

  // ─── 配置 ───

  /// open() 模拟延迟
  final Duration openDelay;

  /// open() 后自动进入 playing 状态
  final bool autoPlay;

  // ─── 非 mixin 状态 ───

  @override
  MediaErrorType errorType = MediaErrorType.unknown;

  // ─── 内部状态 ───

  MediaInfo _mediaInfo = const MediaInfo();

  @override
  MediaInfo get mediaInfo => _mediaInfo;

  String _currentPath = '';

  // ─── 状态历史（调试用） ───

  final List<MediaState> _stateHistory = [];

  /// 状态变化历史
  List<MediaState> get stateHistory => List.unmodifiable(_stateHistory);

  // ─── 事件流（调试用） ───

  static const int _maxEventHistory = 500;

  final List<MockEvent> _eventHistory = [];

  /// 操作事件历史
  List<MockEvent> get eventHistory => List.unmodifiable(_eventHistory);

  /// 最新事件 — UI 层可通过 ValueListenableBuilder 监听。
  final ValueNotifier<MockEvent?> onEvent = ValueNotifier<MockEvent?>(null);

  // ─── 错误注入 ───

  /// 设置后下一次 open() 会模拟失败
  String? failNextOpenWith;

  // ─── 媒体配置 ───

  /// 预配置模拟媒体信息
  void configureMedia({
    int durationMs = 120000,
    List<AudioTrackInfo>? audioTracks,
    List<SubtitleTrackInfo>? subtitleTracks,
  }) {
    _mediaInfo = MediaInfo(
      duration: durationMs,
      audioTracks: audioTracks ?? const [],
      subtitleTracks: subtitleTracks ?? const [],
    );
  }

  // ─── 播放控制 ───

  @override
  Future<void> open(String path) async {
    if (_disposed) return;
    _currentPath = path;
    _recordState(MediaState.loading);
    state.value = MediaState.loading;
    logEngine.d('[Mock] open() — ${PathUtils.basename(path)}');
    _recordEvent('open', {'path': path});

    await Future<void>.delayed(openDelay);
    if (_disposed) return;

    if (failNextOpenWith != null) {
      final msg = failNextOpenWith!;
      failNextOpenWith = null;
      state.value = MediaState.error;
      errorMessage.value = msg;
      errorType = MediaErrorType.file;
      logEngine.e('[Mock] open() error: $msg');
      return;
    }

    duration.value = _mediaInfo.duration;
    position.value = 0;
    buffered.value = _mediaInfo.duration; // 模拟已全部缓冲
    errorMessage.value = null;
    logEngine.i(
      '[Mock] open() success — ${PathUtils.basename(path)} '
      '${_mediaInfo.duration}ms',
    );

    if (autoPlay) {
      play();
    } else {
      state.value = MediaState.idle;
    }
  }

  @override
  void play() {
    if (_disposed) return;
    _recordState(MediaState.playing);
    state.value = MediaState.playing;
    _startPositionTimer();
    logEngine.d('[Mock] play() — ${PathUtils.basename(_currentPath)}');
    _recordEvent('play');
  }

  @override
  void pause() {
    if (_disposed) return;
    _recordState(MediaState.paused);
    state.value = MediaState.paused;
    _stopPositionTimer();
    logEngine.d('[Mock] pause() — ${PathUtils.basename(_currentPath)}');
    _recordEvent('pause');
  }

  @override
  void stop() {
    if (_disposed) return;
    _recordState(MediaState.stopped);
    state.value = MediaState.stopped;
    position.value = 0;
    _stopPositionTimer();
    logEngine.d('[Mock] stop() — ${PathUtils.basename(_currentPath)}');
    _recordEvent('stop');
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_disposed) return;
    final clamped = milliseconds.clamp(0, duration.value);
    position.value = clamped;
    logEngine.d('[Mock] seekTo($clamped)');
    _recordEvent('seek', {'position': clamped});
  }

  @override
  void setVolume(double value) {
    if (_disposed) return;
    volume.value = value.clamp(0.0, 1.0);
    isMuted.value = volume.value == 0;
  }

  @override
  void setMute(bool mute) {
    if (_disposed) return;
    isMuted.value = mute;
  }

  @override
  void togglePlayPause() {
    if (_disposed) return;
    if (state.value == MediaState.playing) {
      pause();
    } else {
      play();
    }
  }

  @override
  void setPlaybackRate(double rate) {
    if (_disposed) return;
    playbackSpeed.value = rate.clamp(
      EngineConstants.minPlaybackRate,
      EngineConstants.maxPlaybackRate,
    );
  }

  @override
  void skipForward([int ms = 10000]) {
    seekTo((position.value + ms).clamp(0, duration.value));
  }

  @override
  void skipBack([int ms = 10000]) {
    seekTo((position.value - ms).clamp(0, duration.value));
  }

  @override
  void setRange({required int from, int to = -1}) {
    // Mock: no-op
  }

  // ─── 音轨/字幕（Mock 实现） ───

  @override
  List<AudioTrackInfo> getAudioTracks() => [];

  @override
  void switchAudioTrack(int trackIndex) {}

  @override
  List<int> get activeAudioTracks => [];

  @override
  List<SubtitleTrackInfo> getSubtitleTracks() => [];

  @override
  void switchSubtitleTrack(int trackIndex) {}

  @override
  void toggleSubtitle() {}

  @override
  void setExternalSubtitle(String path) {}

  @override
  void setSubtitleDelay(int milliseconds) {}

  @override
  int get subtitleDelay => 0;

  // ─── 视频效果（Mock 实现） ───

  @override
  void setEqualizer(String afFilter) {}

  @override
  void setVideoEffect(VideoEffectType effect, double value) {}

  @override
  void rotate(int degree) {}

  @override
  void setAspectRatio(double ratio) {
    if (_disposed) return;
    aspectRatio.value = ratio;
  }

  @override
  void setDeinterlace(bool enable) {}

  // ─── D3D11 性能 ───

  @override
  void setD3d11SyncEnabled(bool enabled) {}

  @override
  void setHardwareDecoding(bool enabled) {}

  // ─── 生命周期 ───

  @override
  void dispose() {
    _disposed = true;
    _stopPositionTimer();
    textureId.dispose();
    state.dispose();
    position.dispose();
    duration.dispose();
    volume.dispose();
    isMuted.dispose();
    isBuffering.dispose();
    subtitleText.dispose();
    buffered.dispose();
    aspectRatio.value = 1.0;
    errorMessage.dispose();
    playbackSpeed.dispose();
    onEvent.dispose();
    logEngine.d('[Mock] dispose()');
  }

  // ─── 内部方法 ───

  void _recordState(MediaState s) {
    _stateHistory.add(s);
    if (_stateHistory.length > 100) _stateHistory.removeAt(0);
  }

  void _recordEvent(String type, [Map<String, Object>? data]) {
    final event = MockEvent(
      type: type,
      path: _currentPath,
      timestamp: DateTime.now(),
      data: data,
    );
    _eventHistory.add(event);
    while (_eventHistory.length > _maxEventHistory) {
      _eventHistory.removeAt(0);
    }
    onEvent.value = event;
  }

  // ─── 调试数据导出 ───

  /// 导出完整调试数据 — 当前状态 + 事件历史 + 状态转换历史。
  Map<String, Object> exportDebugData() {
    return {
      'currentPath': _currentPath,
      'state': state.value.name,
      'position': position.value,
      'duration': duration.value,
      'volume': volume.value,
      'isMuted': isMuted.value,
      'playbackSpeed': playbackSpeed.value,
      'aspectRatio': aspectRatio.value,
      'errorMessage': errorMessage.value ?? '',
      'config': {'openDelay': openDelay.inMilliseconds, 'autoPlay': autoPlay},
      'stateHistory': _stateHistory.map((s) => s.name).toList(),
      'eventHistory': _eventHistory.map((e) => e.toJson()).toList(),
      'eventCount': _eventHistory.length,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 导出 JSON 字符串。
  String exportDebugJson() => jsonEncode(exportDebugData());

  /// 播放时每 250ms 递增 position，模拟真实播放
  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_disposed) return;
      final next = position.value + (250 * playbackSpeed.value).round();
      if (next >= duration.value) {
        position.value = duration.value;
        _stopPositionTimer();
        _recordState(MediaState.completed);
        state.value = MediaState.completed;
        logEngine.d('[Mock] playback completed');
      } else {
        position.value = next;
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
}
