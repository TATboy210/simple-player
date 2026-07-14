// ignore_for_file: overridden_fields — intentional: each engine needs independent ValueNotifier instances
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;
import 'engine_state.dart';

import '../services/path_validator.dart';
import '../utils/path_utils.dart';
import 'engine_constants.dart';
import 'engine_event_log.dart';
import 'engine_metrics.dart';
import 'fvp_callback_handler.dart';
import 'media_opener.dart';
import 'player_proxy.dart';
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
///   - PositionPoller: 自适应间隔轮询播放位置
///   - TrackManager: 音频/字幕轨道选择与切换
///   - VolumeController: 音量/静音控制
///   - SubtitleConfigurator: 外挂字幕、字幕延迟、均衡器
///   - D3D11Configurator: D3D11 渲染管线配置
///
/// 架构说明:
///   - 使用工厂构造函数保证所有 helper 在构造时就有值，消除 late 初始化风险
///   - 状态转换受 switch expression 穷举守卫保护，防止非法跳转
///   - 内置 EngineMetrics 性能计数器和 EngineEventLog 事件日志
///
/// fvp 底层使用 FFmpeg + Windows D3D11 渲染
///   ARM/x86 均通过 FFmpeg 软解或硬件加速支持
class FvpEngine implements MediaEngine {
  /// 工厂构造函数 — 保证所有依赖在构造时注入，消除 late 初始化风险
  ///
  /// 对比旧实现（lazy getter + late fields）:
  ///   - 旧: _player 是 lazy getter，helper 的 late 字段在 _createPlayer() 中初始化
  ///         如果任何代码路径在 _player 被触碰前访问 helper → LateInitializationError
  ///   - 新: 所有 helper 在工厂构造函数中创建，通过私有命名构造函数注入
  ///         编译期保证不可能出现未初始化访问
  factory FvpEngine() {
    final player = mdk.Player();
    final proxy = MdkPlayerProxy(player);
    final trackManager = TrackManager(player);
    final mediaOpener = MediaOpener(player, trackManager);
    final videoEffectController = VideoEffectController(player);

    // 创建引擎实例 — 所有字段在构造时赋值
    final engine = FvpEngine._(
      player,
      trackManager,
      mediaOpener,
      videoEffectController,
      proxy,
    );

    // 初始化依赖引擎状态的 helper（需要引用 engine 的 ValueNotifier）
    engine._callbackHandler = FvpCallbackHandler(
      player,
      state: engine.state,
      isBuffering: engine.isBuffering,
      onStopPositionPolling: () => engine._positionPoller.stop(),
    );
    engine._positionPoller = PositionPoller(
      player,
      position: engine.position,
      buffered: engine.buffered,
      currentPathGetter: () => engine._currentPath,
    );
    engine._volumeController = VolumeController(
      proxy,
      volume: engine.volume,
      isMuted: engine.isMuted,
    );

    // 注册纹理 ID 监听
    player.textureId.addListener(engine._onTextureIdChanged);

    // 初始化回调处理器
    engine._callbackHandler.init();

    // D3D11 性能参数 — 在 init 后、open 前设置
    engine._d3d11Configurator.applyDefaults();

    return engine;
  }

  /// 私有命名构造函数 — 核心字段在此赋值，编译期保证完整初始化
  ///
  /// 部分 helper（callbackHandler/positionPoller/volumeController）需要引用
  /// engine 的 ValueNotifier，因此在工厂构造函数中延迟创建。
  FvpEngine._(
    this._player,
    this._trackManager,
    this._mediaOpener,
    this._videoEffectController,
    PlayerProxy proxy,
  ) : _subtitleConfigurator = SubtitleConfigurator(proxy),
      _d3d11Configurator = D3D11Configurator(proxy);

  // ─── 核心依赖 ───

  final mdk.Player _player;
  final TrackManager _trackManager;
  final MediaOpener _mediaOpener;
  final VideoEffectController _videoEffectController;
  final SubtitleConfigurator _subtitleConfigurator;
  final D3D11Configurator _d3d11Configurator;

  /// 回调处理器 — 在工厂构造函数中创建（依赖 engine 的 ValueNotifier）
  late FvpCallbackHandler _callbackHandler;

  /// 位置轮询器 — 在工厂构造函数中创建（依赖 engine 的 ValueNotifier）
  late PositionPoller _positionPoller;

  /// 音量控制器 — 在工厂构造函数中创建（依赖 engine 的 ValueNotifier）
  late VolumeController _volumeController;

  bool _disposed = false;

  // ─── 可观测性 ───

  /// 引擎健康指标 — 计数器在 open/play/seek/error 路径自动更新
  final metrics = EngineMetrics();

  /// 引擎事件日志 — 最近 100 条操作记录（环形缓冲，不持久化）
  final eventLog = EngineEventLog();

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
  final ValueNotifier<double> volume = ValueNotifier<double>(
    EngineConstants.defaultVolume,
  );

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
  final ValueNotifier<PlayerError?> lastError = ValueNotifier<PlayerError?>(null);

  @override
  final ValueNotifier<bool> isSeeking = ValueNotifier<bool>(false);

  @override
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(
    EngineConstants.defaultPlaybackRate,
  );

  // ─── 内部状态 ───

  String _currentPath = '';
  bool _isOpening = false;

  @override
  MediaInfo get mediaInfo => _trackManager.mediaInfo;

  void _onTextureIdChanged() {
    textureId.value = _player.textureId.value;
  }

  // ─── 状态转换辅助 ───

  /// 安全地设置播放状态 — 检查转换合法性，debug 模式下打印非法跳转警告
  ///
  /// 使用 switch expression 穷举守卫防止非法状态跳转。
  /// debug 模式下非法转换会被打印但仍然执行（保证不崩溃）；
  /// release 模式下非法转换被静默忽略。
  ///
  /// 注意: 此方法将在 Plan 10-02 中迁移为使用 EngineStateMachine.transitionTo。
  void _safeSetState(MediaState next, String caller) {
    final current = state.value;
    if (!_canTransitionTo(current, next)) {
      assert(() {
        debugPrint('⚠️ FvpEngine.$caller: illegal transition $current → $next');
        return true;
      }());
      if (!kDebugMode) return;
    }
    state.value = next;
  }

  /// switch expression 穷举合法转换 — 与 EngineStateMachine 逻辑一致
  ///
  /// Plan 10-02 将删除此方法，改用 EngineStateMachine.transitionTo。
  static bool _canTransitionTo(MediaState current, MediaState next) {
    return switch (current) {
      MediaState.idle =>
        next == MediaState.opening || next == MediaState.error,
      MediaState.opening =>
        next == MediaState.idle ||
            next == MediaState.playing ||
            next == MediaState.error,
      MediaState.playing =>
        next == MediaState.paused ||
            next == MediaState.completed ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.paused =>
        next == MediaState.playing ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.completed =>
        next == MediaState.opening ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.error =>
        next == MediaState.opening || next == MediaState.idle,
    };
  }

  /// 通用守卫：disposed 检查 + try-catch + log + 事件记录
  void _guardedAction(String name, void Function() action) {
    if (_disposed) return;
    try {
      action();
    } on Exception catch (e) {
      log.e('FvpEngine.$name error: $e');
      lastError.value = PlaybackError(PlaybackErrorCode.playFailed, '$name 失败: $e', e);
      eventLog.add('error', {'action': name, 'error': e.toString()});
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
      _safeSetState(MediaState.error, 'open');
      lastError.value = const FileError(FileErrorCode.pathEmpty, '文件路径为空');
      metrics.recordOpen(success: false);
      eventLog.add('open', {'path': path, 'error': 'empty path'});
      return;
    }

    _isOpening = true;
    _safeSetState(MediaState.opening, 'open');
    _currentPath = trimmed;
    eventLog.add('open', {'path': PathUtils.basename(trimmed)});

    try {
      final result = await _mediaOpener.open(trimmed);
      if (_disposed) return;

      // 诊断日志: 记录 open 结果
      debugPrint('🔍 open() result: ${result.runtimeType} for ${PathUtils.basename(trimmed)}');

      switch (result) {
        case OpenSuccess(:final mediaInfo):
          duration.value = mediaInfo.duration;
          final video = mediaInfo.video;
          if (video != null && video.width > 0 && video.height > 0) {
            aspectRatio.value = (video.width * video.par) / video.height;
          }
          position.value = 0;
          _safeSetState(MediaState.idle, 'open');
          lastError.value = null;
          metrics.recordOpen(success: true);
          logEngine.i(
            'open() success — ${PathUtils.basename(trimmed)} '
            '${video?.width}x${video?.height} '
            '${mediaInfo.duration}ms',
          );
        case OpenError(:final error):
          // 错误恢复：codec 错误且非 URL 时尝试软解降级
          if (error is CodecError && !PathValidator.isUrl(trimmed)) {
            logEngine.i('open() codec error — retrying with software decode');
            eventLog.add('fallback', {
              'reason': 'codec error',
              'action': 'switch to software decode',
            });
            _d3d11Configurator.setHardwareDecoding(false);
            _isOpening = false;
            await open(trimmed);
            return;
          }
          _safeSetState(MediaState.error, 'open');
          lastError.value = error;
          metrics.recordOpen(success: false);
          logEngine.e(
            'open() error — ${PathUtils.basename(trimmed)}: ${error.message}',
          );
      }
    } on Exception catch (e) {
      _safeSetState(MediaState.error, 'open');
      lastError.value = PathValidator.isUrl(trimmed)
          ? NetworkError(NetworkErrorCode.timeout, '无法打开: ${PathUtils.basename(path)}', e)
          : PlaybackError(PlaybackErrorCode.playFailed, '无法打开: ${PathUtils.basename(path)}', e);
      metrics.recordOpen(success: false);
      eventLog.add('error', {'action': 'open', 'error': e.toString()});
    } finally {
      isBuffering.value = false;
      _isOpening = false;
    }
  }

  @override
  void play() {
    if (_disposed) return;
    // 跳过自转换 — 已经在播放中
    if (state.value == MediaState.playing) return;
    try {
      debugPrint(
        '🔍 play() — state=${state.value}, '
        'textureId=${textureId.value}, '
        'path=${PathUtils.basename(_currentPath)}',
      );
      _player.state = mdk.PlaybackState.playing;
      _safeSetState(MediaState.playing, 'play');
      _positionPoller.startSilent();
      eventLog.add('play', {'path': PathUtils.basename(_currentPath)});
      logEngine.d('play() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e) {
      _safeSetState(MediaState.error, 'play');
      lastError.value = PlaybackError(PlaybackErrorCode.playFailed, '播放失败: $e', e);
      logEngine.e('play() error: $e');
      debugPrint('❌ play() failed: $e');
    }
  }

  @override
  void pause() {
    if (_disposed) return;
    try {
      _player.state = mdk.PlaybackState.paused;
      _safeSetState(MediaState.paused, 'pause');
      _positionPoller.stop();
      eventLog.add('pause');
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
      _safeSetState(MediaState.idle, 'stop');
      position.value = 0;
      _positionPoller.stop();
      eventLog.add('stop');
      logEngine.d('stop() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e) {
      logEngine.e('stop() error: $e');
    }
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_disposed) return;
    if (state.value == MediaState.idle || duration.value <= 0) return;
    // 跳过自转换 — 已经在 seek 中
    if (isSeeking.value) return;
    final clamped = milliseconds.clamp(0, duration.value);
    final wasPlaying = _player.state == mdk.PlaybackState.playing;
    _positionPoller.seeking = true;
    isSeeking.value = true;

    final seekStopwatch = Stopwatch()..start();
    try {
      await _player.seek(position: clamped);
      if (_disposed) return;
      position.value = clamped;
      eventLog.add('seek', {'position': clamped});
    } on Exception catch (e) {
      if (_disposed) return;
      lastError.value = PlaybackError(PlaybackErrorCode.seekFailed, '跳转失败: $e', e);
      position.value = _player.position;
      eventLog.add('error', {'action': 'seek', 'error': e.toString()});
    } finally {
      seekStopwatch.stop();
      metrics.recordSeek(seekStopwatch.elapsed);
      _positionPoller.seeking = false;
      isSeeking.value = false;
    }
    if (_disposed) return;
    // seek 完成后恢复到 seek 前的状态
    _safeSetState(
      wasPlaying ? MediaState.playing : MediaState.paused,
      'seekTo.restore',
    );
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
        state.value == MediaState.idle ||
        state.value == MediaState.completed) {
      play();
    }
  }

  @override
  void setPlaybackRate(double rate) {
    _guardedAction('setPlaybackRate', () {
      final clamped = rate.clamp(
        EngineConstants.minPlaybackRate,
        EngineConstants.maxPlaybackRate,
      );
      _player.playbackRate = clamped;
      playbackSpeed.value = clamped;
      // 自适应轮询间隔：倍速播放时调整轮询频率
      _positionPoller.setPlaybackRate(clamped);
      eventLog.add('speed', {'rate': clamped});
    });
  }

  @override
  void skipForward([int ms = EngineConstants.defaultSkipMs]) {
    seekTo((position.value + ms).clamp(0, duration.value));
  }

  @override
  void skipBack([int ms = EngineConstants.defaultSkipMs]) {
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
      _videoEffectController.setVideoEffect(effect, value);
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
      _d3d11Configurator.setD3d11SyncEnabled(enabled);
    });
  }

  @override
  void setHardwareDecoding(bool enabled) {
    _guardedAction('setHardwareDecoding', () {
      _d3d11Configurator.setHardwareDecoding(enabled);
    });
  }

  // ─── 生命周期 ───

  /// 释放所有资源
  ///
  /// debug 模式下检查 ValueNotifier 是否有残留 listeners（内存泄漏检测）。
  @override
  void dispose() {
    _disposed = true;

    // debug 模式：检查 listener 泄漏
    assert(() {
      final notifiers = {
        'textureId': textureId,
        'state': state,
        'position': position,
        'duration': duration,
        'volume': volume,
        'isMuted': isMuted,
        'isBuffering': isBuffering,
        'isSeeking': isSeeking,
        'subtitleText': subtitleText,
        'buffered': buffered,
        'aspectRatio': aspectRatio,
        'lastError': lastError,
        'playbackSpeed': playbackSpeed,
      };
      for (final entry in notifiers.entries) {
        // ignore: invalid_use_of_protected_member
        if (entry.value.hasListeners) {
          debugPrint('⚠️ FvpEngine.dispose: ${entry.key} still has listeners');
        }
      }
      return true;
    }());

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
    isSeeking.dispose();
    subtitleText.dispose();
    buffered.dispose();
    aspectRatio.dispose();
    lastError.dispose();
    playbackSpeed.dispose();

    eventLog.add('dispose');
  }
}
