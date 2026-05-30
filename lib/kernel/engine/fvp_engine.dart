import 'dart:async';
import 'dart:developer';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;

import '../models/media_error_type.dart';
import '../models/media_state.dart';
import '../models/media_info.dart';
import '../models/video_effect_type.dart';
import '../services/path_validator.dart';
import '../utils/path_utils.dart';
import 'fvp_callback_handler.dart';
import 'media_engine.dart';
import 'position_poller.dart';
import 'track_manager.dart';

/// fvp/MDK 引擎实现
///
/// 封装 fvp/MDK 播放器，暴露 Flutter 友好的 ValueNotifier 接口。
/// 由 3 个 helper 组合而成:
///   - FvpCallbackHandler: mdk 回调注册、状态映射、主线程调度
///   - PositionPoller: 250ms 定时器轮询播放位置
///   - TrackManager: 音频/字幕轨道选择与切换
///
/// fvp 底层使用 FFmpeg + Windows D3D11 渲染
///   ARM/x86 均通过 FFmpeg 软解或硬件加速支持
class FvpEngine implements MediaEngine {
  final mdk.Player _player = mdk.Player();
  bool _disposed = false;

  // ─── Constants ───

  static const _prepareTimeoutSeconds = 10;
  static const _textureTimeoutSeconds = 5;
  static const _defaultSkipSeconds = 10;
  static const _minPlaybackRate = 0.25;
  static const _maxPlaybackRate = 4.0;

  // 网络流常量 — 仅对 URL 生效，本地文件不受影响
  static const _networkTimeoutMs = 10000;
  static const _networkProbeSize = 1000000; // 1MB
  static const _networkAnalyzeDurationUs = 5000000; // 5s
  static const _rtspProbeSize = 500000; // 500KB — RTSP 快速探测

  // ─── Helpers ───

  late final FvpCallbackHandler _callbackHandler;
  late final PositionPoller _positionPoller;
  late final TrackManager _trackManager;

  // ─── ValueNotifier 实现 ───

  @override
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);

  @override
  final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(
    MediaState.idle,
  );

  @override
  final ValueNotifier<int> position = ValueNotifier<int>(0);

  @override
  final ValueNotifier<int> duration = ValueNotifier<int>(0);

  @override
  final ValueNotifier<double> volume = ValueNotifier<double>(1.0);

  @override
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  @override
  final ValueNotifier<bool> isBuffering = ValueNotifier<bool>(false);

  @override
  final ValueNotifier<String> subtitleText = ValueNotifier<String>('');

  @override
  final ValueNotifier<int> buffered = ValueNotifier<int>(0);

  @override
  final ValueNotifier<double> aspectRatio = ValueNotifier<double>(16 / 9);

  @override
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  MediaErrorType _errorType = MediaErrorType.unknown;
  @override
  MediaErrorType get errorType => _errorType;

  @override
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);

  // ─── 内部状态 ───

  String _currentPath = '';
  bool _isOpening = false;

  @override
  MediaInfo get mediaInfo => _trackManager.mediaInfo;

  FvpEngine() {
    _callbackHandler = FvpCallbackHandler(
      _player,
      state: state,
      isBuffering: isBuffering,
      onStopPositionPolling: () => _positionPoller.stop(),
    );
    _positionPoller = PositionPoller(
      _player,
      position: position,
      buffered: buffered,
      currentPathGetter: () => _currentPath,
    );
    _trackManager = TrackManager(_player);

    _player.textureId.addListener(_onTextureIdChanged);
    _callbackHandler.init();
  }

  void _onTextureIdChanged() {
    textureId.value = _player.textureId.value;
  }

  /// 为 URL 源配置 FFmpeg 网络参数
  ///
  /// 仅对 http/https/rtmp/rtsp 等 URL 生效，本地文件不调用。
  /// 设置超时、探测大小、分析时长和协议特定参数。
  void _configureNetworkOptions(String url) {
    // 通用网络超时
    _player.setProperty('timeout', _networkTimeoutMs.toString());

    // FFmpeg 流探测参数 — 减少首帧延迟
    _player.setProperty('avformat.probesize', _networkProbeSize.toString());
    _player.setProperty(
      'avformat.analyzeduration',
      _networkAnalyzeDurationUs.toString(),
    );

    // RTSP 低延迟配置
    if (url.startsWith('rtsp://')) {
      _player.setProperty('avformat.probesize', _rtspProbeSize.toString());
      _player.setProperty('avformat.fflags', '+nobuffer');
      _player.setProperty('avformat.fpsprobesize', '0');
      _player.setProperty('avformat.avioflags', 'direct');
      // RTSP 实时流：min=0, max=MAX, drop=true (低延迟丢帧)
      _player.setBufferRange(min: 0, max: 0, drop: true);
    }

    // RTMP 低延迟配置
    if (url.startsWith('rtmp://')) {
      _player.setProperty('avformat.fflags', '+nobuffer');
      _player.setProperty('avformat.fpsprobesize', '0');
      _player.setBufferRange(min: 0, max: 0, drop: true);
    }

    // SRT 低延迟配置
    if (url.startsWith('srt://')) {
      _player.setProperty('avformat.fflags', '+nobuffer');
      _player.setProperty('avformat.fpsprobesize', '0');
      _player.setBufferRange(min: 0, max: 0, drop: true);
    }

    // UDP/TCP 实时流低延迟
    if (url.startsWith('udp://') || url.startsWith('tcp://')) {
      _player.setProperty('avformat.fflags', '+nobuffer');
      _player.setProperty('avformat.fpsprobesize', '0');
      _player.setBufferRange(min: 0, max: 0, drop: true);
    }

    // HTTP/HTTPS 启用解复用缓存（加速 seek）
    if (url.startsWith('http://') || url.startsWith('https://')) {
      _player.setProperty('demux.buffer.ranges', '1');
    }
  }

  /// 通用守卫：disposed 检查 + try-catch + debugPrint
  void _guardedAction(String name, void Function() action) {
    if (_disposed) return;
    try {
      action();
    } on Exception catch (e) {
      debugPrint('FvpEngine.$name error: $e');
      _errorType = MediaErrorType.playback;
      errorMessage.value = '$name 失败: $e';
    }
  }

  // ─── 播放控制 ───

  @override
  Future<void> open(String path) async {
    if (_disposed) return;
    if (_isOpening) {
      debugPrint('FvpEngine.open() blocked — already opening');
      return;
    }

    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      state.value = MediaState.error;
      _errorType = MediaErrorType.file;
      errorMessage.value = '文件路径为空';
      return;
    }

    // 非 URL 路径检查文件是否存在
    if (!PathValidator.isUrl(trimmed)) {
      try {
        final file = File(trimmed);
        if (!await file.exists()) {
          state.value = MediaState.error;
          _errorType = MediaErrorType.file;
          errorMessage.value = '文件不存在: ${PathUtils.basename(trimmed)}';
          return;
        }
      } on Exception catch (e) {
        state.value = MediaState.error;
        _errorType = MediaErrorType.file;
        errorMessage.value = '路径无效: $e';
        return;
      }
    }
    if (_disposed) return;

    _isOpening = true;
    state.value = MediaState.loading;
    _currentPath = trimmed;

    Timeline.startSync('fvp.open');
    try {
      _player.media = trimmed;

      // URL 源自动配置网络参数，本地文件跳过
      if (PathValidator.isUrl(trimmed)) {
        _configureNetworkOptions(trimmed);
      }

      final prepareResult = await _player.prepare().timeout(
        const Duration(seconds: _prepareTimeoutSeconds),
        onTimeout: () => -99,
      );
      if (_disposed) return;
      if (prepareResult < 0) {
        state.value = MediaState.error;
        _errorType = prepareResult == -99
            ? (PathValidator.isUrl(trimmed)
                ? MediaErrorType.network
                : MediaErrorType.file)
            : MediaErrorType.codec;
        errorMessage.value = prepareResult == -99
            ? '打开超时: ${PathUtils.basename(trimmed)}'
            : '无法解码: ${PathUtils.basename(trimmed)} (code: $prepareResult)';
        return;
      }

      final info = _player.mediaInfo;
      duration.value = info.duration;

      // PAR 修正：物理像素宽高比 ≠ 显示宽高比
      final videos = info.video;
      VideoCodecInfo? videoInfo;
      if (videos != null && videos.isNotEmpty) {
        final vc = videos.first.codec;
        if (vc.width > 0 && vc.height > 0) {
          aspectRatio.value = (vc.width * vc.par) / vc.height;
          videoInfo = VideoCodecInfo(
            width: vc.width,
            height: vc.height,
            par: vc.par,
            codec: vc.codec,
          );
        }
      }

      // 音轨信息
      final audioTracks = <AudioTrackInfo>[];
      final audio = info.audio;
      if (audio != null) {
        for (final t in audio) {
          audioTracks.add(
            AudioTrackInfo(
              index: t.index,
              language: t.metadata['language'] ?? '',
              codec: t.codec.codec,
              channels: t.codec.channels,
            ),
          );
        }
      }

      // 字幕轨道信息
      final subtitleTracks = <SubtitleTrackInfo>[];
      final subtitle = info.subtitle;
      if (subtitle != null) {
        for (final t in subtitle) {
          subtitleTracks.add(
            SubtitleTrackInfo(
              index: t.index,
              language: t.metadata['language'] ?? '',
              title: t.metadata['title'] ?? '',
            ),
          );
        }
      }

      _trackManager.updateMediaInfo(
        MediaInfo(
          duration: info.duration,
          video: videoInfo,
          audioTracks: audioTracks,
          subtitleTracks: subtitleTracks,
        ),
      );

      final textureResult = await _player.updateTexture().timeout(
        const Duration(seconds: _textureTimeoutSeconds),
        onTimeout: () => -99,
      );
      if (_disposed) return;
      if (textureResult < 0) {
        state.value = MediaState.error;
        _errorType = MediaErrorType.codec;
        errorMessage.value = textureResult == -99
            ? '纹理创建超时: ${PathUtils.basename(trimmed)}'
            : '纹理创建失败: ${PathUtils.basename(trimmed)}';
        return;
      }

      position.value = 0;
      _errorType = MediaErrorType.unknown;
      errorMessage.value = null;
    } on Exception catch (e) {
      state.value = MediaState.error;
      _errorType = PathValidator.isUrl(trimmed)
          ? MediaErrorType.network
          : MediaErrorType.playback;
      errorMessage.value = '无法打开: ${PathUtils.basename(path)}\n$e';
    } finally {
      Timeline.finishSync();
      isBuffering.value = false;
      _isOpening = false;
    }
  }

  @override
  void play() {
    if (_disposed) return;
    try {
      _player.state = mdk.PlaybackState.playing;
      state.value = MediaState.playing;
      _positionPoller.start();
    } on Exception catch (e) {
      state.value = MediaState.error;
      _errorType = MediaErrorType.playback;
      errorMessage.value = '播放失败: $e';
    }
  }

  @override
  void pause() {
    if (_disposed) return;
    try {
      _player.state = mdk.PlaybackState.paused;
      state.value = MediaState.paused;
      _positionPoller.stop();
    } on Exception catch (e) {
      debugPrint('FvpEngine.pause error: $e');
    }
  }

  @override
  void stop() {
    if (_disposed) return;
    try {
      _player.state = mdk.PlaybackState.stopped;
      state.value = MediaState.stopped;
      position.value = 0;
      _positionPoller.stop();
    } on Exception catch (e) {
      debugPrint('FvpEngine.stop error: $e');
    }
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_disposed) return;
    if (state.value == MediaState.idle || duration.value <= 0) return;
    final clamped = milliseconds.clamp(0, duration.value);
    final wasPlaying = _player.state == mdk.PlaybackState.playing;
    _positionPoller.seeking = true;
    state.value = MediaState.seeking;
    Timeline.startSync('fvp.seek');
    try {
      await _player.seek(position: clamped);
      if (_disposed) return;
      position.value = clamped;
    } on Exception catch (e) {
      if (_disposed) return;
      _errorType = MediaErrorType.playback;
      errorMessage.value = '跳转失败: $e';
      position.value = _player.position;
    } finally {
      Timeline.finishSync();
      _positionPoller.seeking = false;
    }
    if (_disposed) return;
    if (state.value == MediaState.seeking ||
        state.value == MediaState.buffering) {
      state.value = wasPlaying ? MediaState.playing : MediaState.paused;
    }
  }

  @override
  void setVolume(double value) {
    _guardedAction('setVolume', () {
      final clamped = value.clamp(0.0, 1.0);
      _player.volume = clamped;
      volume.value = clamped;
      if (clamped == 0 && !isMuted.value) {
        _player.mute = true;
        isMuted.value = true;
      } else if (clamped > 0 && isMuted.value) {
        _player.mute = false;
        isMuted.value = false;
      }
    });
  }

  @override
  void setMute(bool mute) {
    _guardedAction('setMute', () {
      _player.mute = mute;
      isMuted.value = mute;
    });
  }

  @override
  void togglePlayPause() {
    if (_disposed) return;
    if (state.value == MediaState.playing) {
      pause();
    } else if (state.value == MediaState.paused ||
        state.value == MediaState.stopped ||
        state.value == MediaState.idle ||
        state.value == MediaState.completed) {
      play();
    }
  }

  @override
  void skipForward([int seconds = _defaultSkipSeconds]) {
    seekTo((position.value + seconds * 1000).clamp(0, duration.value));
  }

  @override
  void skipBack([int seconds = _defaultSkipSeconds]) {
    seekTo((position.value - seconds * 1000).clamp(0, duration.value));
  }

  @override
  void setPlaybackRate(double rate) {
    _guardedAction('setPlaybackRate', () {
      final clamped = rate.clamp(_minPlaybackRate, _maxPlaybackRate);
      _player.playbackRate = clamped;
      playbackSpeed.value = clamped;
    });
  }

  @override
  void setRange({required int from, int to = -1}) {
    _guardedAction('setRange', () {
      if (from >= 0 && to >= 0 && from > to) {
        final tmp = from;
        from = to;
        to = tmp;
      }
      final dur = duration.value;
      if (dur > 0) {
        if (from >= 0) from = from.clamp(0, dur);
        if (to >= 0) to = to.clamp(0, dur);
      }
      _player.setRange(from: from, to: to);
    });
  }

  // ─── 音轨/字幕 (delegated to TrackManager) ───

  @override
  List<AudioTrackInfo> getAudioTracks() => _trackManager.getAudioTracks();

  @override
  void switchAudioTrack(int trackIndex) {
    if (_disposed) return;
    _trackManager.switchAudioTrack(trackIndex);
  }

  @override
  List<int> get activeAudioTracks =>
      _disposed ? [] : _trackManager.activeAudioTracks;

  @override
  List<SubtitleTrackInfo> getSubtitleTracks() =>
      _trackManager.getSubtitleTracks();

  @override
  void switchSubtitleTrack(int trackIndex) {
    if (_disposed) return;
    _trackManager.switchSubtitleTrack(trackIndex);
  }

  @override
  void toggleSubtitle() {
    if (_disposed) return;
    _trackManager.toggleSubtitle();
  }

  // ─── 外挂字幕 ───

  @override
  void setExternalSubtitle(String path) {
    _guardedAction('setExternalSubtitle', () {
      _player.setProperty('subtitle.external', path);
    });
  }

  // ─── 字幕时间偏移 ───

  @override
  void setSubtitleDelay(int milliseconds) {
    _guardedAction('setSubtitleDelay', () {
      _player.setProperty('subtitle.delay', milliseconds.toString());
    });
  }

  @override
  int get subtitleDelay {
    try {
      return int.parse(_player.getProperty('subtitle.delay') ?? '0');
    } on Exception catch (_) {
      return 0;
    }
  }

  // ─── 均衡器 ───

  @override
  void setEqualizer(String afFilter) {
    _guardedAction('setEqualizer', () {
      _player.setProperty('af', afFilter);
    });
  }

  // ─── 视频处理 ───

  @override
  void setVideoEffect(VideoEffectType effect, double value) {
    _guardedAction('setVideoEffect', () {
      final clamped = value.clamp(-1.0, 1.0);
      final mdkEffect = switch (effect) {
        VideoEffectType.brightness => mdk.VideoEffect.brightness,
        VideoEffectType.contrast => mdk.VideoEffect.contrast,
        VideoEffectType.hue => mdk.VideoEffect.hue,
        VideoEffectType.saturation => mdk.VideoEffect.saturation,
      };
      _player.setVideoEffect(mdkEffect, [clamped]);
    });
  }

  @override
  void rotate(int degree) {
    _guardedAction('rotate', () {
      // mdk 只接受 0/90/180/270
      final valid = {0, 90, 180, 270};
      if (!valid.contains(degree)) {
        debugPrint(
          'FvpEngine.rotate invalid degree: $degree, expected 0/90/180/270',
        );
        return;
      }
      _player.rotate(degree);
    });
  }

  @override
  void setAspectRatio(double ratio) {
    _guardedAction('setAspectRatio', () {
      _player.setAspectRatio(ratio);
    });
  }

  @override
  void setDeinterlace(bool enable) {
    _guardedAction('setDeinterlace', () {
      // yadif 仅对软件解码器生效（硬件解码器忽略此设置）
      _player.setProperty(
        'video.avfilter',
        enable ? 'yadif=mode=send_frame:deint=all' : '',
      );
    });
  }

  // ─── 生命周期 ───

  @override
  void dispose() {
    _disposed = true;
    _positionPoller.dispose();
    _callbackHandler.dispose();

    _player.textureId.removeListener(_onTextureIdChanged);
    _player.dispose();

    textureId.dispose();
    state.dispose();
    position.dispose();
    duration.dispose();
    volume.dispose();
    isMuted.dispose();
    isBuffering.dispose();
    subtitleText.dispose();
    buffered.dispose();
    aspectRatio.dispose();
    errorMessage.dispose();
    playbackSpeed.dispose();
  }
}
