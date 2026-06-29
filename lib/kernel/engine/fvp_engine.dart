import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'media_error_type.dart';
import 'media_state.dart';
import 'models/audio_track_info.dart';
import 'models/media_info.dart';
import 'models/subtitle_track_info.dart';
import 'player_engine_base.dart';
import 'video_effect_type.dart';

import '../services/path_validator.dart';
import '../utils/path_utils.dart';
import 'fvp_callback_handler.dart';
import 'media_opener.dart';
import 'open_result.dart';
import 'position_poller.dart';
import '../utils/log.dart';
import 'track_manager.dart';
import 'video_effect_controller.dart';
import 'volume_controller.dart';
import 'subtitle_configurator.dart';
import 'd3d11_configurator.dart';
import 'mdk_player_proxy.dart';

/// fvp/MDK 引擎实现
///
/// 封装 fvp/MDK 播放器，暴露 Flutter 友好的 ValueNotifier 接口。
/// 由 6 个 helper 组合而成:
///   - FvpCallbackHandler: mdk 回调注册、状态映射、主线程调度
///   - PositionPoller: 250ms 定时器轮询播放位置
///   - TrackManager: 音频/字幕轨道选择与切换
///   - VolumeController: 音量/静音控制
///   - SubtitleConfigurator: 外挂字幕、字幕延迟、均衡器
///   - D3D11Configurator: D3D11 渲染管线配置
///
/// fvp 底层使用 FFmpeg + Windows D3D11 渲染
///   ARM/x86 均通过 FFmpeg 软解或硬件加速支持
class FvpEngine extends PlayerEngine {
  mdk.Player? _playerInstance;
  mdk.Player get _player => _playerInstance ??= _createPlayer();
  bool _disposed = false;

  // ─── Constants ───

  static const _minPlaybackRate = 0.25;
  static const _maxPlaybackRate = 4.0;

  // ─── Helpers ───

  late FvpCallbackHandler _callbackHandler;
  late PositionPoller _positionPoller;
  late TrackManager _trackManager;
  late MediaOpener _mediaOpener;
  late VideoEffectController _videoEffectController;
  late VolumeController _volumeController;
  late SubtitleConfigurator _subtitleConfigurator;
  late D3D11Configurator _d3d11Configurator;

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

  FvpEngine();

  mdk.Player _createPlayer() {
    final p = mdk.Player();
    _callbackHandler = FvpCallbackHandler(
      p,
      state: state,
      isBuffering: isBuffering,
      onStopPositionPolling: () => _positionPoller.stop(),
    );
    _positionPoller = PositionPoller(
      p,
      position: position,
      buffered: buffered,
      currentPathGetter: () => _currentPath,
    );
    _trackManager = TrackManager(p);
    _videoEffectController = VideoEffectController(p);
    _mediaOpener = MediaOpener(p, _trackManager);
    final proxy = MdkPlayerProxy(p);
    _volumeController = VolumeController(proxy, volume: volume, isMuted: isMuted);
    _subtitleConfigurator = SubtitleConfigurator(proxy);
    _d3d11Configurator = D3D11Configurator(proxy);

    p.textureId.addListener(_onTextureIdChanged);
    _callbackHandler.init();

    // D3D11 性能参数 via D3D11Configurator — 在 init 后、open 前设置
    _d3d11Configurator.applyDefaults();

    return p;
  }

  void _onTextureIdChanged() {
    textureId.value = _player.textureId.value;
  }

  /// 通用守卫：disposed 检查 + try-catch + log
  void _guardedAction(String name, void Function() action) {
    if (_disposed) return;
    try {
      action();
    } on Exception catch (e) {
      log.e('FvpEngine.$name error: $e');
      _errorType = MediaErrorType.playback;
      errorMessage.value = '$name 失败: $e';
    }
  }

  // ─── 播放控制 ───

  @override
  Future<void> open(String path) async {
    if (_disposed) return;
    if (_isOpening) {
      log.w('FvpEngine.open() blocked — already opening');
      return;
    }

    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      state.value = MediaState.error;
      _errorType = MediaErrorType.file;
      errorMessage.value = '文件路径为空';
      return;
    }

    _isOpening = true;
    state.value = MediaState.loading;
    _currentPath = trimmed;

    Timeline.startSync('fvp.open');
    try {
      final result = await _mediaOpener.open(trimmed);
      if (_disposed) return;

      switch (result) {
        case OpenSuccess(:final mediaInfo):
          duration.value = mediaInfo.duration;
          final video = mediaInfo.video;
          if (video != null && video.width > 0 && video.height > 0) {
            aspectRatio.value = (video.width * video.par) / video.height;
          }
          position.value = 0;
          state.value = MediaState.idle;
          _errorType = MediaErrorType.unknown;
          errorMessage.value = null;
          logEngine.i('open() success — ${PathUtils.basename(trimmed)} '
              '${video?.width}x${video?.height} '
              '${mediaInfo.duration}ms');
        case OpenError(:final type, :final message):
          state.value = MediaState.error;
          _errorType = type;
          errorMessage.value = message;
          logEngine.e('open() error — ${PathUtils.basename(trimmed)}: $message');
      }
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
      _positionPoller.startSilent();
      logEngine.d('play() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e) {
      state.value = MediaState.error;
      _errorType = MediaErrorType.playback;
      errorMessage.value = '播放失败: $e';
      logEngine.e('play() error: $e');
    }
  }

  @override
  void pause() {
    if (_disposed) return;
    try {
      _player.state = mdk.PlaybackState.paused;
      state.value = MediaState.paused;
      _positionPoller.stop();
      logEngine.d('pause() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e) {
      logEngine.e('pause() error: $e');
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
      logEngine.d('stop() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e) {
      logEngine.e('stop() error: $e');
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
      _volumeController.setVolume(value);
    });
  }

  @override
  void setMute(bool mute) {
    _guardedAction('setMute', () {
      _volumeController.setMute(mute);
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
  void setPlaybackRate(double rate) {
    _guardedAction('setPlaybackRate', () {
      final clamped = rate.clamp(_minPlaybackRate, _maxPlaybackRate);
      _player.playbackRate = clamped;
      playbackSpeed.value = clamped;
    });
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
      _subtitleConfigurator.setExternalSubtitle(path);
    });
  }

  // ─── 字幕时间偏移 ───

  @override
  void setSubtitleDelay(int milliseconds) {
    _guardedAction('setSubtitleDelay', () {
      _subtitleConfigurator.setSubtitleDelay(milliseconds);
    });
  }

  @override
  int get subtitleDelay {
    if (_disposed) return 0;
    return _subtitleConfigurator.getSubtitleDelay();
  }

  // ─── 均衡器 ───

  @override
  void setEqualizer(String afFilter) {
    _guardedAction('setEqualizer', () {
      _subtitleConfigurator.setEqualizer(afFilter);
    });
  }

  // ─── 视频处理 (delegated to VideoEffectController) ───

  @override
  void setVideoEffect(VideoEffectType effect, double value) {
    _guardedAction('setVideoEffect', () {
      _videoEffectController.setEffect(effect, value);
    });
  }

  @override
  void rotate(int degree) {
    _guardedAction('rotate', () {
      _videoEffectController.rotate(degree);
    });
  }

  @override
  void setAspectRatio(double ratio) {
    _guardedAction('setAspectRatio', () {
      _videoEffectController.setAspectRatio(ratio);
    });
  }

  @override
  void setDeinterlace(bool enable) {
    _guardedAction('setDeinterlace', () {
      _videoEffectController.setDeinterlace(enable);
    });
  }

  // ─── D3D11 性能参数 ───

  @override
  void setD3d11SyncEnabled(bool enabled) {
    _guardedAction('setD3d11SyncEnabled', () {
      _d3d11Configurator.setSyncEnabled(enabled);
    });
  }

  @override
  void setHardwareDecoding(bool enabled) {
    _guardedAction('setHardwareDecoding', () {
      _d3d11Configurator.setHardwareDecoding(enabled);
    });
  }

  // ─── 生命周期 ───

  @override
  void dispose() {
    _disposed = true;
    final p = _playerInstance;
    if (p != null) {
      _positionPoller.dispose();
      _callbackHandler.dispose();
      p.textureId.removeListener(_onTextureIdChanged);
      p.dispose();
    }

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
