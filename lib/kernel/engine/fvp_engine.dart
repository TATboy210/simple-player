// ignore_for_file: overridden_fields — intentional: each engine needs independent ValueNotifier instances
import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../diagnostics/diagnostics_bundle.dart';
import 'lifecycle_phase.dart';
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
///   - EngineStateMachine: 独立状态机，管理 state/isSeeking/isBuffering
///   - FvpCallbackHandler: 回调注册、状态映射、主线程调度
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
///   - [playerFactory] 支持依赖注入 — 测试时注入 FakeMdkPlayer 消除 mdk.dll 依赖
/// Tracks uncancellable MDK operations for one queued open transaction.
///
/// The public result may timeout, but the next transaction must not mutate the
/// shared player until every native Future registered here has settled.
final class _NativeOpenDrain {
  Future<void> _tail = Future<void>.value();

  /// Adds a native operation without allowing its failure to poison the queue.
  void track(Future<Object?> work) {
    _tail = _tail.then<void>(
      (_) => work.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      ),
    );
  }

  /// Resolves after all registered native operations have completed.
  Future<void> waitForSettlement() => _tail;
}

class FvpEngine implements MediaEngine, SubtitleConfig {
  /// 工厂构造函数 — 保证所有依赖在构造时注入，消除 late 初始化风险
  ///
  /// [bundle] 诊断能力载体（Phase 20 D2 依赖注入），默认 noop。
  /// [playerFactory] mdk.Player 工厂 — 默认创建真实 mdk.Player（通过 MdkPlayerProxy）；
  ///   测试时注入 FakeMdkPlayer 工厂以消除 mdk.dll FFI 依赖。
  factory FvpEngine({
    DiagnosticsBundle bundle = const DiagnosticsBundle.noop(),
    MdkPlayerLike Function()? playerFactory,
  }) {
    final player = playerFactory?.call() ?? MdkPlayerProxy.create();
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
      player,
      bundle,
    );

    // 注入状态机回调（engine 已创建，可安全引用 engine.play/pause）
    stateMachine.onPlay = engine.play;
    stateMachine.onPause = engine.pause;

    // 初始化依赖引擎状态的 helper
    engine._subtitleConfigurator = SubtitleConfigurator(player, trackManager);
    engine._callbackHandler = FvpCallbackHandler(
      player,
      stateMachine: stateMachine,
      onStopPositionPolling: () => engine._positionPoller.stop(),
      lastErrorNotifier: engine.lastError,
    );
    engine._positionPoller = PositionPoller(
      player,
      position: engine.position,
      buffered: engine.buffered,
      currentPathGetter: () => engine._currentPath,
    );
    engine._volumeController = VolumeController(
      player,
      volume: engine.volume,
      isMuted: engine.isMuted,
    );

    // 注册纹理 ID 监听 — textureId 是 ValueNotifier<int?>，支持 removeListener
    final tid = player.textureId;
    if (tid is ValueNotifier<int?>) {
      tid.addListener(engine._onTextureIdChanged);
    }

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
    this._bundle,
  ) : _d3d11Configurator = D3D11Configurator(proxy);

  // ─── 核心依赖 ───

  final MdkPlayerLike _player;
  final TrackManager _trackManager;
  final MediaOpener _mediaOpener;
  final VideoEffectController _videoEffectController;
  late final SubtitleConfigurator _subtitleConfigurator;
  final D3D11Configurator _d3d11Configurator;
  final EngineStateMachine _stateMachine;

  /// 诊断能力载体 — Phase 20 D2 依赖注入 (logger/metrics/eventLog/memoryMonitor)
  final DiagnosticsBundle _bundle;

  /// 回调处理器 — 在工厂构造函数中创建
  late FvpCallbackHandler _callbackHandler;

  /// 位置轮询器 — 在工厂构造函数中创建
  late PositionPoller _positionPoller;

  /// 音量控制器 — 在工厂构造函数中创建
  late VolumeController _volumeController;

  bool _disposed = false;

  /// 共享 MDK Player 的原生 open 调用尾部。
  ///
  /// 每个请求在入口处保留一个独立的队列位置；前一段 native 调用结束后，
  /// 当前任务会再次检查 generation，避免过期请求触碰共享 Player。
  Future<void> _nativeOpenTail = Future<void>.value();

  // ─── 可观测性 ───

  /// 引擎健康指标 — 计数器在 open/play/seek/error 路径自动更新
  ///
  /// Engine health counters, auto-updated on open/play/seek/error paths.
  final metrics = EngineMetrics();

  /// 引擎事件日志 — 最近 100 条操作记录（环形缓冲，不持久化）
  ///
  /// Ring buffer of the most recent 100 engine events (not persisted).
  final eventLog = EngineEventLog();

  // ─── ValueNotifier 实现 ───

  /// GPU 纹理 ID — 由 fvp 插件注册，null 表示尚未就绪
  ///
  /// GPU texture ID registered by the fvp plugin; `null` until ready.
  @override
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);

  /// 主播放状态 — 委托给 EngineStateMachine 管理
  ///
  /// Primary playback state notifier, delegated to [EngineStateMachine].
  @override
  ValueNotifier<MediaState> get state => _stateMachine.state;

  /// 当前播放位置（毫秒）
  ///
  /// Current playback position in milliseconds.
  @override
  final ValueNotifier<int> position = ValueNotifier<int>(0);

  /// 媒体总时长（毫秒）
  ///
  /// Total media duration in milliseconds.
  @override
  final ValueNotifier<int> duration = ValueNotifier<int>(0);

  /// 音量（0.0–1.0）
  ///
  /// Volume level in the range 0.0 (silent) to 1.0 (max).
  @override
  final ValueNotifier<double> volume = ValueNotifier<double>(
    EngineConstants.defaultVolume,
  );

  /// 是否静音
  ///
  /// Whether audio output is muted.
  @override
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  /// 是否正在缓冲 — 委托给 EngineStateMachine 管理
  ///
  /// Whether the engine is buffering data, delegated to [EngineStateMachine].
  @override
  ValueNotifier<bool> get isBuffering => _stateMachine.isBuffering;

  /// 当前字幕文本
  ///
  /// Current subtitle text for the active frame.
  @override
  final ValueNotifier<String> subtitleText = ValueNotifier<String>('');

  /// 已缓冲的字节数
  ///
  /// Number of bytes currently buffered ahead of playback position.
  @override
  final ValueNotifier<int> buffered = ValueNotifier<int>(0);

  /// 视频宽高比
  ///
  /// Current video aspect ratio (width / height, accounting for PAR).
  @override
  final ValueNotifier<double> aspectRatio = ValueNotifier<double>(16 / 9);

  /// 最近一次错误（null 表示无错误）
  ///
  /// Most recent [PlayerError], or `null` if no error occurred.
  @override
  final ValueNotifier<PlayerError?> lastError = ValueNotifier<PlayerError?>(
    null,
  );

  /// 是否正在 seek — 委托给 EngineStateMachine 管理
  ///
  /// Whether a seek operation is in progress, delegated to [EngineStateMachine].
  @override
  ValueNotifier<bool> get isSeeking => _stateMachine.isSeeking;

  /// 播放速率（1.0 = 正常速度）
  ///
  /// Playback speed multiplier (1.0 = normal speed).
  @override
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(
    EngineConstants.defaultPlaybackRate,
  );

  // ─── 内部状态 ───

  String _currentPath = '';

  /// 当前媒体元数据（编解码器、分辨率、时长等）
  ///
  /// Current media metadata (codec, resolution, duration, etc.).
  @override
  MediaInfo get mediaInfo => _trackManager.mediaInfo;

  // ─── 生命周期 (Phase 20 D6/D7) ───

  /// 引擎生命周期阶段 — 委托给 EngineStateMachine (D6 正交生命周期)
  ///
  /// Engine lifecycle phase notifier, delegated to [EngineStateMachine].
  ValueNotifier<LifecyclePhase> get lifecyclePhase =>
      _stateMachine.lifecyclePhase;

  /// 状态机访问器 — PlaybackNavigator 通过此访问 generation 计数器 (D5 单一真相源)
  ///
  /// State machine accessor; [PlaybackNavigator] reads the generation counter here.
  @override
  EngineStateMachine get stateMachine => _stateMachine;

  /// 从 error 状态恢复到 idle — 委托给 EngineStateMachine (D7)
  ///
  /// Recovers from error state back to idle. Delegates to [EngineStateMachine].
  void recover() {
    if (_disposed) return;
    _stateMachine.recover(lastError: lastError);
  }

  void _onTextureIdChanged() {
    final tid = _player.textureId;
    // textureId 是 ValueNotifier<int?> (MdkPlayerProxy) 或 ValueNotifier<int?> (FakeMdkPlayer)
    if (tid is ValueNotifier<int?>) {
      textureId.value = tid.value;
    }
  }

  // ─── 接口 getter (per D-07) ───

  /// 音频/字幕轨道管理
  ///
  /// Audio/subtitle track selection and switching.
  TrackControl get trackControl => _trackManager;

  /// 字幕配置（外挂字幕、延迟、均衡器）
  ///
  /// Subtitle configuration (external subs, delay, equalizer).
  SubtitleConfig get subtitleConfig => _subtitleConfigurator;

  /// 视频效果控制（色彩、旋转、宽高比、反交错）
  ///
  /// Video effect controls (color, rotation, aspect ratio, deinterlace).
  VideoEffectControl get videoEffectControl => _videoEffectController;

  /// D3D11 渲染管线配置
  ///
  /// D3D11 render pipeline configuration.
  RendererControl get rendererControl => _d3d11Configurator;

  /// 音量/静音控制
  ///
  /// Volume and mute control.
  VolumeControl get volumeControl => _volumeController;

  // ─── 通用守卫 ───

  /// 通用守卫：disposed 检查 + try-catch + log + 事件记录
  void _guardedAction(String name, void Function() action) {
    if (_disposed) return;
    try {
      action();
    } on Exception catch (e, st) {
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '$name 失败: $e',
        e,
        ErrorContext(action: name, module: 'FvpEngine'),
      );
      lastError.value = error;
      _bundle.logger.e(
        'FvpEngine.$name error',
        context: error.context?.toMap(),
        error: e,
        stackTrace: st,
      );
      eventLog.add('error', {'action': name, 'error': e.toString()});
    }
  }

  // ─── 播放控制 ───

  /// 打开媒体文件或 URL，并显式返回本次请求的最终结果。
  ///
  /// 每个请求在入口处获得 generation 并占用 native 队列位置。轮到执行时会
  /// 再次验证 generation，因此被更新请求取代的任务不会触碰共享 MDK Player。
  @override
  Future<OpenResult> open(String path) async {
    if (_disposed) return const OpenSuperseded();

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
      _bundle.logger.e('open() empty path', context: error.context?.toMap());
      metrics.recordOpen(success: false);
      eventLog.add('open', {'path': path, 'error': 'empty path'});
      return OpenError(error);
    }

    final generation = _stateMachine.nextGeneration();
    return _enqueueNativeOpen(trimmed, generation);
  }

  /// 将一次媒体打开管道排到共享 MDK Player 的前一段原生调用之后。
  ///
  /// 每个队列任务的错误都会被独立消费来推进队列，防止单次失败永久阻塞后续请求。
  Future<OpenResult> _enqueueNativeOpen(String path, int generation) {
    final previousOpen = _nativeOpenTail;
    final nativeDrain = _NativeOpenDrain();
    final queuedOpen = previousOpen.then(
      (_) => _openCurrentGeneration(path, generation, nativeDrain),
    );
    // 调用方可在 timeout 后先拿到 OpenError；队列仍须等待原始 MDK Future。
    _nativeOpenTail = queuedOpen
        .then<void>((_) => nativeDrain.waitForSettlement())
        .catchError((Object _) => nativeDrain.waitForSettlement());
    return queuedOpen;
  }

  /// 在独占共享 MDK Player 时执行一次完整的打开流程。
  ///
  /// 本方法绝不递归调用公共 [open]：本地 codec 错误最多在同一队列位置内
  /// 切换一次软件解码后重试，避免当前任务等待排在自身后方的请求。
  Future<OpenResult> _openCurrentGeneration(
    String path,
    int generation,
    _NativeOpenDrain nativeDrain,
  ) async {
    if (!_isCurrentGeneration(generation)) return const OpenSuperseded();

    _beginOpen(path, generation);
    var hasRetriedSoftwareDecode = false;

    try {
      while (_isCurrentGeneration(generation)) {
        final result = await _mediaOpener.open(
          path,
          canContinue: () => _isCurrentGeneration(generation),
          onNativeWorkStarted: nativeDrain.track,
        );
        if (!_isCurrentGeneration(generation)) return const OpenSuperseded();

        _bundle.logger.d(
          'open result: ${result.runtimeType}',
          context: {'file': PathUtils.basename(path)},
        );

        switch (result) {
          case OpenSuccess(:final mediaInfo):
            _publishOpenSuccess(path, generation, mediaInfo);
            return OpenSuccess(mediaInfo);
          case OpenError(:final error):
            if (error is CodecError &&
                !PathValidator.isUrl(path) &&
                !hasRetriedSoftwareDecode) {
              // 仅重试一次，防止持续 codec 错误使调用栈或 native 队列无限增长。
              hasRetriedSoftwareDecode = true;
              _bundle.logger.i(
                'open() codec error — retrying with software decode',
              );
              eventLog.add('fallback', {
                'reason': 'codec error',
                'action': 'switch to software decode',
              });
              _d3d11Configurator.setHardwareDecoding(false);
              continue;
            }
            _publishOpenError(path, generation, error);
            return OpenError(error);
          case OpenSuperseded():
            return const OpenSuperseded();
        }
      }
      return const OpenSuperseded();
    } on Exception catch (error, stackTrace) {
      if (!_isCurrentGeneration(generation)) return const OpenSuperseded();
      final playerError = _publishOpenException(
        path,
        generation,
        error,
        stackTrace,
      );
      return OpenError(playerError);
    } finally {
      if (_isCurrentGeneration(generation)) {
        isBuffering.value = false;
      }
    }
  }

  /// Returns whether this queued task may still publish state or use the player.
  bool _isCurrentGeneration(int generation) =>
      !_disposed && generation == _stateMachine.currentGeneration;

  /// Stops and resets the prior native session before opening new media.
  ///
  /// An idle Dart state can still retain a prepared MDK pipeline, so every
  /// queued request sends `stopped` before assigning a new media source.
  void _beginOpen(String path, int generation) {
    _player.state = MdkPlaybackState.stopped;
    _positionPoller.stop();
    position.value = 0;

    // `opening` can belong to a superseded request. Converge every non-idle
    // public state first so the state machine permits the next opening phase.
    if (state.value != MediaState.idle) {
      _stateMachine.transitionTo(
        MediaState.idle,
        'open.reset',
        generation: generation,
      );
    }
    _stateMachine.transitionTo(
      MediaState.opening,
      'open',
      generation: generation,
    );
    _currentPath = path;
    eventLog.add('open.stopPrevious', {
      'path': PathUtils.basename(path),
      'generation': generation,
    });
  }

  /// Publishes the observable state for a successfully opened current generation.
  void _publishOpenSuccess(String path, int generation, MediaInfo mediaInfo) {
    if (!_isCurrentGeneration(generation)) return;

    duration.value = mediaInfo.duration;
    final video = mediaInfo.video;
    if (video != null && video.width > 0 && video.height > 0) {
      aspectRatio.value = (video.width * video.par) / video.height;
    }
    position.value = 0;
    _stateMachine.transitionTo(MediaState.idle, 'open', generation: generation);
    lastError.value = null;
    metrics.recordOpen(success: true);
    _bundle.logger.i(
      'open() success — ${PathUtils.basename(path)} '
      '${video?.width}x${video?.height} '
      '${mediaInfo.duration}ms',
    );
  }

  /// Publishes a typed opening failure for the still-current generation.
  void _publishOpenError(String path, int generation, PlayerError error) {
    if (!_isCurrentGeneration(generation)) return;

    _stateMachine.transitionTo(
      MediaState.error,
      'open',
      generation: generation,
    );
    error.context ??= ErrorContext(
      action: 'open',
      generation: generation,
      path: path,
      module: 'MediaOpener',
    );
    lastError.value = error;
    metrics.recordOpen(success: false);
    _bundle.logger.e(
      'open() error — ${PathUtils.basename(path)}',
      context: error.context?.toMap(),
    );
  }

  /// Converts unexpected opening exceptions to a user-visible typed error.
  PlayerError _publishOpenException(
    String path,
    int generation,
    Exception exception,
    StackTrace stackTrace,
  ) {
    _stateMachine.transitionTo(
      MediaState.error,
      'open',
      generation: generation,
    );
    final error = PathValidator.isUrl(path)
        ? NetworkError(
            NetworkErrorCode.timeout,
            '无法打开: ${PathUtils.basename(path)}',
            exception,
            ErrorContext(
              action: 'open',
              generation: generation,
              path: path,
              module: 'FvpEngine',
            ),
          )
        : PlaybackError(
            PlaybackErrorCode.playFailed,
            '无法打开: ${PathUtils.basename(path)}',
            exception,
            ErrorContext(
              action: 'open',
              generation: generation,
              path: path,
              module: 'FvpEngine',
            ),
          );
    lastError.value = error;
    _bundle.logger.e(
      'open() error — ${PathUtils.basename(path)}',
      context: error.context?.toMap(),
      error: exception,
      stackTrace: stackTrace,
    );
    metrics.recordOpen(success: false);
    eventLog.add('error', {'action': 'open', 'error': exception.toString()});
    return error;
  }

  /// 开始播放
  ///
  /// Starts playback. No-op if already playing or disposed.
  @override
  void play() {
    if (_disposed) return;
    if (state.value == MediaState.playing) return;
    try {
      _bundle.logger.d(
        'play() — state=${state.value}, '
        'textureId=${textureId.value}, '
        'path=${PathUtils.basename(_currentPath)}',
      );
      _player.state = MdkPlaybackState.playing;
      _stateMachine.transitionTo(MediaState.playing, 'play');
      _positionPoller.startSilent();
      eventLog.add('play', {'path': PathUtils.basename(_currentPath)});
      _bundle.logger.d('play() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e, st) {
      _stateMachine.transitionTo(MediaState.error, 'play');
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '播放失败: $e',
        e,
        ErrorContext(action: 'play', module: 'FvpEngine'),
      );
      lastError.value = error;
      _bundle.logger.e(
        'play() error',
        context: error.context?.toMap(),
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 暂停播放
  ///
  /// Pauses playback. No-op if disposed.
  @override
  void pause() {
    if (_disposed) return;
    try {
      _player.state = MdkPlaybackState.paused;
      _stateMachine.transitionTo(MediaState.paused, 'pause');
      _positionPoller.stop();
      eventLog.add('pause');
      _bundle.logger.d('pause() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e, st) {
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '暂停失败: $e',
        e,
        ErrorContext(action: 'pause', module: 'FvpEngine'),
      );
      lastError.value = error;
      _bundle.logger.e(
        'pause() error',
        context: error.context?.toMap(),
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 停止播放并重置位置
  ///
  /// Stops playback and resets position to 0. No-op if disposed.
  @override
  void stop() {
    if (_disposed) return;
    try {
      _player.state = MdkPlaybackState.stopped;
      _stateMachine.transitionTo(MediaState.idle, 'stop');
      position.value = 0;
      _positionPoller.stop();
      eventLog.add('stop');
      _bundle.logger.d('stop() — ${PathUtils.basename(_currentPath)}');
    } on Exception catch (e, st) {
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '停止失败: $e',
        e,
        ErrorContext(action: 'stop', module: 'FvpEngine'),
      );
      lastError.value = error;
      _bundle.logger.e(
        'stop() error',
        context: error.context?.toMap(),
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 跳转到指定位置
  ///
  /// Seeks to [milliseconds] (clamped to 0..duration).
  /// No-op if idle, duration unknown, or already seeking.
  @override
  Future<void> seekTo(int milliseconds) async {
    if (_disposed) return;
    if (state.value == MediaState.idle || duration.value <= 0) return;
    if (isSeeking.value) return;
    final clamped = milliseconds.clamp(0, duration.value);
    final wasPlaying = _player.state == MdkPlaybackState.playing;
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
      final error = PlaybackError(
        PlaybackErrorCode.seekFailed,
        '跳转失败: $e',
        e,
        ErrorContext(action: 'seek', module: 'FvpEngine'),
      );
      lastError.value = error;
      _bundle.logger.e(
        'seekTo() error',
        context: error.context?.toMap(),
        error: e,
        stackTrace: st,
      );
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

  /// 切换播放/暂停
  ///
  /// Toggles between playing and paused states. No-op if disposed.
  @override
  void togglePlayPause() {
    if (_disposed) return;
    _stateMachine.togglePlayPause();
  }

  /// 设置播放速率
  ///
  /// Sets playback speed to [rate] (clamped to min/max constants).
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

  /// 快进（默认 10 秒）
  ///
  /// Skips forward by [ms] milliseconds (default 10s). Clamped to duration.
  @override
  void skipForward([int ms = EngineConstants.defaultSkipMs]) {
    seekTo((position.value + ms).clamp(0, duration.value));
  }

  /// 快退（默认 10 秒）
  ///
  /// Skips backward by [ms] milliseconds (default 10s). Clamped to 0.
  @override
  void skipBack([int ms = EngineConstants.defaultSkipMs]) {
    seekTo((position.value - ms).clamp(0, duration.value));
  }

  /// 设置播放范围（循环区间）
  ///
  /// Sets the playback range. [from] and [to] are in milliseconds;
  /// `to = -1` means end of media. Values are clamped to [0, duration].
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

  // ─── TrackControl 实现 ───

  /// 获取可用音频轨道列表
  ///
  /// Returns available audio tracks.
  @override
  List<AudioTrackInfo> getAudioTracks() => _trackManager.getAudioTracks();

  /// 切换到指定音频轨道
  ///
  /// Switches to the audio track at [trackIndex]. No-op if disposed.
  @override
  void switchAudioTrack(int trackIndex) {
    if (_disposed) return;
    _trackManager.switchAudioTrack(trackIndex);
  }

  /// 当前激活的音频轨道索引列表
  ///
  /// Indices of currently active audio tracks; empty if disposed.
  @override
  List<int> get activeAudioTracks =>
      _disposed ? [] : _trackManager.activeAudioTracks;

  // ─── SubtitleConfig 实现 ───

  /// 获取可用字幕轨道列表
  ///
  /// Returns available subtitle tracks.
  @override
  List<SubtitleTrackInfo> getSubtitleTracks() =>
      _trackManager.getSubtitleTracks();

  /// 切换到指定字幕轨道
  ///
  /// Switches to the subtitle track at [trackIndex]. No-op if disposed.
  @override
  void switchSubtitleTrack(int trackIndex) {
    if (_disposed) return;
    _trackManager.switchSubtitleTrack(trackIndex);
  }

  /// 切换字幕开/关
  ///
  /// Toggles subtitle display on/off. No-op if disposed.
  @override
  void toggleSubtitle() {
    if (_disposed) return;
    _trackManager.toggleSubtitle();
  }

  /// 当前激活的字幕轨道索引列表
  ///
  /// Indices of currently active subtitle tracks; empty if disposed.
  @override
  List<int> get activeSubtitleTracks =>
      _disposed ? [] : _trackManager.activeSubtitleTracks;

  /// 加载外挂字幕文件
  ///
  /// Loads an external subtitle file from [path].
  @override
  void setExternalSubtitle(String path) {
    _guardedAction('setExternalSubtitle', () {
      // 防御纵深：验证路径安全性，防止路径遍历攻击
      if (PathValidator.isPathTraversal(path)) {
        debugPrint('[FvpEngine] setExternalSubtitle: rejected unsafe path');
        return;
      }
      _subtitleConfigurator.setExternalSubtitle(path);
    });
  }

  /// 设置字幕延迟（毫秒，正=延后，负=提前）
  ///
  /// Sets subtitle delay in ms (positive = delay, negative = advance).
  @override
  void setSubtitleDelay(int milliseconds) {
    _guardedAction('setSubtitleDelay', () {
      _subtitleConfigurator.setSubtitleDelay(milliseconds);
    });
  }

  /// 当前字幕延迟（毫秒）
  ///
  /// Current subtitle delay in milliseconds; 0 if disposed.
  @override
  int get subtitleDelay {
    if (_disposed) return 0;
    return _subtitleConfigurator.getSubtitleDelay();
  }

  /// 设置音频均衡器滤镜
  ///
  /// Applies an audio filter string (MDK `af` syntax).
  @override
  void setEqualizer(String afFilter) {
    _guardedAction('setEqualizer', () {
      _subtitleConfigurator.setEqualizer(afFilter);
    });
  }

  // ─── VideoEffectControl 实现 ───

  /// 设置视频效果参数
  ///
  /// Applies [value] for the given [effect] type (brightness, contrast, etc.).
  @override
  void setVideoEffect(VideoEffectType effect, double value) {
    _guardedAction('setVideoEffect', () {
      _videoEffectController.setVideoEffect(effect, value);
    });
  }

  /// 旋转视频画面（度数）
  ///
  /// Rotates the video by [degree] degrees.
  @override
  void rotate(int degree) {
    _guardedAction('rotate', () {
      _videoEffectController.rotate(degree);
    });
  }

  /// 设置显示宽高比
  ///
  /// Sets the display aspect ratio to [ratio].
  @override
  void setAspectRatio(double ratio) {
    _guardedAction('setAspectRatio', () {
      _videoEffectController.setAspectRatio(ratio);
    });
  }

  /// 开/关反交错
  ///
  /// Enables or disables deinterlacing.
  @override
  void setDeinterlace(bool enable) {
    _guardedAction('setDeinterlace', () {
      _videoEffectController.setDeinterlace(enable);
    });
  }

  // ─── VolumeControl 实现 ───

  /// 设置音量（0.0–1.0）
  ///
  /// Sets volume to [value] (clamped to 0.0–1.0).
  @override
  void setVolume(double value) {
    _guardedAction('setVolume', () {
      _volumeController.setVolume(value);
    });
  }

  /// 设置静音
  ///
  /// Mutes or unmutes audio based on [mute].
  @override
  void setMute(bool mute) {
    _guardedAction('setMute', () {
      _volumeController.setMute(mute);
    });
  }

  // ─── RendererControl 实现 ───

  /// 开/关 D3D11 CPU 同步
  ///
  /// Enables or disables D3D11 CPU sync (sync.cpu parameter).
  @override
  void setD3d11SyncEnabled(bool enabled) {
    _guardedAction('setD3d11SyncEnabled', () {
      _d3d11Configurator.setD3d11SyncEnabled(enabled);
    });
  }

  /// 开/关硬件解码
  ///
  /// Enables or disables hardware-accelerated decoding.
  @override
  void setHardwareDecoding(bool enabled) {
    _guardedAction('setHardwareDecoding', () {
      _d3d11Configurator.setHardwareDecoding(enabled);
    });
  }

  // ─── 生命周期 ───

  /// 释放所有资源
  ///
  /// Disposes all notifiers, helpers, and the underlying player.
  /// Double-dispose safe (no-op on second call).
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // 使尚未开始的队列任务失效；已经进入原生调用的 Future 无法由 Dart 取消。
    _stateMachine.nextGeneration();

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
          _bundle.logger.w(
            'FvpEngine.dispose: ${entry.key} still has listeners',
          );
        }
      }
      return true;
    }());

    _positionPoller.dispose();
    _callbackHandler.dispose();
    // 移除纹理 ID 监听
    final tid = _player.textureId;
    if (tid is ValueNotifier<int?>) {
      tid.removeListener(_onTextureIdChanged);
    }
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
