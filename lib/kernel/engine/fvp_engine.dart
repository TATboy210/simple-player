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
import '../diagnostics/kernel_logger.dart';
import 'track_manager.dart';
import 'video_effect_controller.dart';
import 'volume_controller.dart';
import 'subtitle_configurator.dart';
import 'd3d11_configurator.dart';
import 'mdk_player_proxy.dart';

final log = KernelLogger.I;
final logEngine = KernelLogger.I;

/// fvp/MDK 引擎实现
///
/// 封装 fvp/MDK 播放器，暴露 Flutter 友好的 ValueNotifier 接口。
/// 由 6 个 helper 组合而成:
///   - EngineStateMachine: 独立状态机，管理 state/isSeeking/isBuffering
///   - FvpCallbackHandler: mdk 回调注册、状态映射、主线程调度
///   - PositionPoller: 自适应间隔轮询播放位置
///   - TrackManager: 音频/字幕轨道选择与切换
///   - VolumeController: 音量/静音控制
///   - SubtitleConfigurator: 外挂字幕、字幕延迟、均衡器
///   - D3D11Configurator: D3D11 渲染管线配置
///
/// 架构说明:
///   - 使用工厂构造函数保证所有 helper 在构造时就有值，消除 late 初始化风险
///   - 状态转换通过 EngineStateMachine.transitionTo 守卫
///   - 内置 EngineMetrics 性能计数器和 EngineEventLog 事件日志
///   - Helper 通过接口 getter 暴露（trackControl, volumeControl 等）
class FvpEngine implements MediaEngine, SubtitleConfig {
  /// 工厂构造函数 — 保证所有依赖在构造时注入，消除 late 初始化风险
  factory FvpEngine() {
    final player = mdk.Player();
    final proxy = MdkPlayerProxy(player);
    final trackManager = TrackManager(player);
    final mediaOpener = MediaOpener(player, trackManager);
    final videoEffectController = VideoEffectController(player);

    // 创建状态机 — onPlay/onPause 在 engine 创建后注入（避免循环依赖）
    final stateMachine = EngineStateMachine();

    // 创建引擎实例 — 所有字段在构造时赋值
    final engine = FvpEngine._(
      player,
      trackManager,
      mediaOpener,
      videoEffectController,
      stateMachine,
      proxy,
    );

    // 注入状态机回调（engine 已创建，可安全引用 engine.play/pause）
    stateMachine.onPlay = engine.play;
    stateMachine.onPause = engine.pause;

    // 初始化依赖引擎状态的 helper
    engine._subtitleConfigurator = SubtitleConfigurator(proxy, trackManager);
    engine._callbackHandler = FvpCallbackHandler(
      player,
      stateMachine: stateMachine,
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
  FvpEngine._(
    this._player,
    this._trackManager,
    this._mediaOpener,
    this._videoEffectController,
    this._stateMachine,
    PlayerProxy proxy,
  ) : _d3d11Configurator = D3D11Configurator(proxy);

  // ─── 核心依赖 ───

  final mdk.Player _player;
  final TrackManager _trackManager;
  final MediaOpener _mediaOpener;
  final VideoEffectController _videoEffectController;
  late final SubtitleConfigurator _subtitleConfigurator;
  final D3D11Configurator _d3d11Configurator;
  final EngineStateMachine _stateMachine;

  /// 回调处理器 — 在工厂构造函数中创建
  late FvpCallbackHandler _callbackHandler;

  /// 位置轮询器 — 在工厂构造函数中创建
  late PositionPoller _positionPoller;

  /// 音量控制器 — 在工厂构造函数中创建
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

  /// 主播放状态 — 委托给 EngineStateMachine 管理
  @override
  ValueNotifier<MediaState> get state => _stateMachine.state;

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

  /// 是否正在缓冲 — 委托给 EngineStateMachine 管理
  @override
  ValueNotifier<bool> get isBuffering => _stateMachine.isBuffering;

  @override
  final ValueNotifier<String> subtitleText = ValueNotifier<String>('');

  @override
  final ValueNotifier<int> buffered = ValueNotifier<int>(0);

  @override
  final ValueNotifier<double> aspectRatio = ValueNotifier<double>(16 / 9);

  @override
  final ValueNotifier<PlayerError?> lastError = ValueNotifier<PlayerError?>(null);

  /// 是否正在 seek — 委托给 EngineStateMachine 管理
  @override
  ValueNotifier<bool> get isSeeking => _stateMachine.isSeeking;

  @override
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(
    EngineConstants.defaultPlaybackRate,
  );

  // ─── 内部状态 ───

  String _currentPath = '';

  /// open() 递增计数器 — 快速切歌时丢弃过期的异步结果
  ///
  /// 每次 open() 递增，async 操作完成后检查 generation 是否仍匹配。
  /// 不匹配说明用户已发起新 open()，旧结果应被丢弃。
  int _openGeneration = 0;

  @override
  MediaInfo get mediaInfo => _trackManager.mediaInfo;

  void _onTextureIdChanged() {
    textureId.value = _player.textureId.value;
  }

  // ─── 接口 getter (per D-07) ───

  /// 音轨控制 — 委托给 TrackManager
  TrackControl get trackControl => _trackManager;

  /// 字幕配置 — 委托给 SubtitleConfigurator
  SubtitleConfig get subtitleConfig => _subtitleConfigurator;

  /// 视频效果控制 — 委托给 VideoEffectController
  VideoEffectControl get videoEffectControl => _videoEffectController;

  /// 渲染器配置 — 委托给 D3D11Configurator
  RendererControl get rendererControl => _d3d11Configurator;

  /// 音量控制 — 委托给 VolumeController
  VolumeControl get volumeControl => _volumeController;

  // ─── 通用守卫 ───

  /// 通用守卫：disposed 检查 + try-catch + log + 事件记录
  ///
  /// 实现特有：异常被吸收为 lastError=PlaybackError（无论具体操作语义），
  /// 不重新 throw；state 不受影响 — 供大多数无状态迁移的 setter 方法复用
  /// （D19 行为断言模式的通用实现载体，接口层契约见各方法自身 throws: 标签）。
  void _guardedAction(String name, void Function() action) {
    if (_disposed) return;
    try {
      action();
    } on Exception catch (e, st) {
      // 三步模式：构造 PlayerError + ErrorContext → 赋值 lastError → log.e
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '$name 失败: $e',
        e,
        ErrorContext(action: name, module: 'FvpEngine'),
      );
      lastError.value = error;
      log.e('FvpEngine.$name error', context: error.context?.toMap(), error: e, stackTrace: st);
      eventLog.add('error', {'action': name, 'error': e.toString()});
    }
  }

  // ─── 播放控制 ───

  /// 实现特有：成功后 state→idle（非 playing），调用方须显式 play()；
  /// generation 守卫丢弃过期异步结果；codec 错误自动降级软解重试一次
  /// （见下方 CodecError 分支）；从 playing/paused/completed 源态调用时，
  /// 内部无条件先转 opening，若与 _canTransitionTo 表冲突则静默失败但
  /// 方法主体仍继续（契约层已在 PlaybackControl.open 标注此已知落差）。
  @override
  Future<void> open(String path) async {
    if (_disposed) return;

    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      _stateMachine.transitionTo(MediaState.error, 'open');
      final error = FileError(
        FileErrorCode.pathEmpty,
        '文件路径为空',
        null,
        ErrorContext(action: 'open', path: trimmed, module: 'FvpEngine'),
      );
      lastError.value = error;
      log.e('open() empty path', context: error.context?.toMap());
      metrics.recordOpen(success: false);
      eventLog.add('open', {'path': path, 'error': 'empty path'});
      return;
    }

    // 递增 generation — 后续 await 返回后检查是否仍为最新请求
    final gen = ++_openGeneration;
    _stateMachine.transitionTo(MediaState.opening, 'open');
    _currentPath = trimmed;
    eventLog.add('open', {'path': PathUtils.basename(trimmed)});

    try {
      final result = await _mediaOpener.open(trimmed);
      // generation 不匹配或已 dispose → 用户已切歌，丢弃本次结果
      if (_disposed || gen != _openGeneration) return;

      debugPrint('🔍 open() result: ${result.runtimeType} for ${PathUtils.basename(trimmed)}');

      switch (result) {
        case OpenSuccess(:final mediaInfo):
          duration.value = mediaInfo.duration;
          final video = mediaInfo.video;
          if (video != null && video.width > 0 && video.height > 0) {
            aspectRatio.value = (video.width * video.par) / video.height;
          }
          position.value = 0;
          _stateMachine.transitionTo(MediaState.idle, 'open');
          lastError.value = null;
          metrics.recordOpen(success: true);
          logEngine.i(
            'open() success — ${PathUtils.basename(trimmed)} '
            '${video?.width}x${video?.height} '
            '${mediaInfo.duration}ms',
          );
        case OpenError(:final error):
          // 实现特有：软解降级重试仅一次 —— 递归调用 open() 会再次递增
          // generation，不会无限重试（第二次若仍失败会走下方 else 分支
          // 直接 state→error，不会再次判定 CodecError 分支）；本地文件
          // 专属（网络 URL 排除在外，因网络编解码问题多与硬解无关）。
          if (error is CodecError && !PathValidator.isUrl(trimmed)) {
            logEngine.i('open() codec error — retrying with software decode');
            eventLog.add('fallback', {
              'reason': 'codec error',
              'action': 'switch to software decode',
            });
            _d3d11Configurator.setHardwareDecoding(false);
            // open() 内部递增 generation，无需手动重置
            await open(trimmed);
            return;
          }
          _stateMachine.transitionTo(MediaState.error, 'open');
          // 丰富 ErrorContext — MediaOpener 构造的 error 可能没有 generation/module
          error.context ??= ErrorContext(
            action: 'open',
            generation: gen,
            path: trimmed,
            module: 'MediaOpener',
          );
          lastError.value = error;
          metrics.recordOpen(success: false);
          logEngine.e(
            'open() error — ${PathUtils.basename(trimmed)}',
            context: error.context?.toMap(),
          );
      }
    } on Exception catch (e, st) {
      if (_disposed || gen != _openGeneration) return;
      _stateMachine.transitionTo(MediaState.error, 'open');
      // 三步模式：构造 PlayerError + ErrorContext → 赋值 lastError → log.e
      final error = PathValidator.isUrl(trimmed)
          ? NetworkError(
              NetworkErrorCode.timeout,
              '无法打开: ${PathUtils.basename(path)}',
              e,
              ErrorContext(action: 'open', generation: gen, path: trimmed, module: 'FvpEngine'),
            )
          : PlaybackError(
              PlaybackErrorCode.playFailed,
              '无法打开: ${PathUtils.basename(path)}',
              e,
              ErrorContext(action: 'open', generation: gen, path: trimmed, module: 'FvpEngine'),
            );
      lastError.value = error;
      log.e(
        'open() error — ${PathUtils.basename(trimmed)}',
        context: error.context?.toMap(),
        error: e,
        stackTrace: st,
      );
      metrics.recordOpen(success: false);
      eventLog.add('error', {'action': 'open', 'error': e.toString()});
    } finally {
      // 只有当前 generation 才清理 buffering 状态
      if (gen == _openGeneration) {
        isBuffering.value = false;
      }
    }
  }

  @override
  void play() {
    if (_disposed) return;
    if (state.value == MediaState.playing) return;
    try {
      debugPrint(
        '🔍 play() — state=${state.value}, '
        'textureId=${textureId.value}, '
        'path=${PathUtils.basename(_currentPath)}',
      );
      _player.state = mdk.PlaybackState.playing;
      _stateMachine.transitionTo(MediaState.playing, 'play');
      _positionPoller.startSilent();
      eventLog.add('play', {'path': PathUtils.basename(_currentPath)});
      logEngine.d('play() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e, st) {
      _stateMachine.transitionTo(MediaState.error, 'play');
      // 三步模式：构造 PlayerError + ErrorContext → 赋值 lastError → log.e
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '播放失败: $e',
        e,
        ErrorContext(action: 'play', module: 'FvpEngine'),
      );
      lastError.value = error;
      logEngine.e('play() error', context: error.context?.toMap(), error: e, stackTrace: st);
      debugPrint('❌ play() failed: $e');
    }
  }

  @override
  void pause() {
    if (_disposed) return;
    try {
      _player.state = mdk.PlaybackState.paused;
      _stateMachine.transitionTo(MediaState.paused, 'pause');
      _positionPoller.stop();
      eventLog.add('pause');
      logEngine.d('pause() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e, st) {
      // 三步模式：pause 错误也应上报 UI
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '暂停失败: $e',
        e,
        ErrorContext(action: 'pause', module: 'FvpEngine'),
      );
      lastError.value = error;
      logEngine.e('pause() error', context: error.context?.toMap(), error: e, stackTrace: st);
    }
  }

  @override
  void stop() {
    if (_disposed) return;
    try {
      _player.state = mdk.PlaybackState.stopped;
      _stateMachine.transitionTo(MediaState.idle, 'stop');
      position.value = 0;
      _positionPoller.stop();
      eventLog.add('stop');
      logEngine.d('stop() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e, st) {
      // 三步模式：stop 错误也应上报 UI
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '停止失败: $e',
        e,
        ErrorContext(action: 'stop', module: 'FvpEngine'),
      );
      lastError.value = error;
      logEngine.e('stop() error', context: error.context?.toMap(), error: e, stackTrace: st);
    }
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_disposed) return;
    if (state.value == MediaState.idle || duration.value <= 0) return;
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
    } on Exception catch (e, st) {
      if (_disposed) return;
      // 三步模式：构造 PlayerError + ErrorContext → 赋值 lastError → log.e
      final error = PlaybackError(
        PlaybackErrorCode.seekFailed,
        '跳转失败: $e',
        e,
        ErrorContext(action: 'seek', module: 'FvpEngine'),
      );
      lastError.value = error;
      log.e('seekTo() error', context: error.context?.toMap(), error: e, stackTrace: st);
      position.value = _player.position;
      eventLog.add('error', {'action': 'seek', 'error': e.toString()});
    } finally {
      seekStopwatch.stop();
      metrics.recordSeek(seekStopwatch.elapsed);
      _positionPoller.seeking = false;
      isSeeking.value = false;
    }
    if (_disposed) return;
    _stateMachine.transitionTo(
      wasPlaying ? MediaState.playing : MediaState.paused,
      'seekTo.restore',
    );
  }

  @override
  void togglePlayPause() {
    if (_disposed) return;
    _stateMachine.togglePlayPause();
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

  // ─── TrackControl 实现 (delegated to TrackManager) ───

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

  // ─── SubtitleConfig 实现 (FvpEngine 直接实现，部分委托 TrackManager) ───

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

  @override
  List<int> get activeSubtitleTracks =>
      _disposed ? [] : _trackManager.activeSubtitleTracks;

  @override
  void setExternalSubtitle(String path) {
    _guardedAction('setExternalSubtitle', () {
      _subtitleConfigurator.setExternalSubtitle(path);
    });
  }

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

  @override
  void setEqualizer(String afFilter) {
    _guardedAction('setEqualizer', () {
      _subtitleConfigurator.setEqualizer(afFilter);
    });
  }

  // ─── VideoEffectControl 实现 (FvpEngine 直接实现，委托 VideoEffectController) ───

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

  // ─── VolumeControl 实现 (delegated to VolumeController) ───

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

  // ─── RendererControl 实现 (delegated to D3D11Configurator) ───

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

  /// 实现特有：当前 baseline 用 `_disposed` bool 守卫，尚无 LifecyclePhase
  /// 枚举（Phase 20 补，见 15-CONTEXT.md P20 清单）；double-dispose 由
  /// `_disposed` 幂等吸收（第二次调用仍会重复执行 dispose 全部 ValueNotifier，
  /// 但 `_disposed=true` 已生效，故各 setter/控制方法在此之后均为 no-op）。
  @override
  void dispose() {
    _disposed = true;

    assert(() {
      final notifiers = {
        'textureId': textureId,
        'position': position,
        'duration': duration,
        'volume': volume,
        'isMuted': isMuted,
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
    _stateMachine.dispose();

    textureId.dispose();
    position.dispose();
    duration.dispose();
    volume.dispose();
    isMuted.dispose();
    subtitleText.dispose();
    buffered.dispose();
    aspectRatio.dispose();
    lastError.dispose();
    playbackSpeed.dispose();

    eventLog.add('dispose');
  }
}
