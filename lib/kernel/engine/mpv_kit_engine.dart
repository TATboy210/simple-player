// ignore_for_file: invalid_use_of_visible_for_testing_member

/// mpv_kit (libmpv 0.41 FFI) 后端的 [MediaEngine] 实现 — 唯一后端.
///
/// mpv_kit backend: [Player] property observers (`MpvState`) and mpv events
/// bridged into the project's ValueNotifier contract. Queue operations live
/// in `mpv_kit_engine_queue.dart` (same library).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io' show File, Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mpv_kit_video/mpv_kit_video.dart';

import '../diagnostics/kernel_logger.dart' show KernelLoggerImpl;
import '../diagnostics/runtime_environment_report.dart';
import '../models/play_mode.dart';
import '../models/player_error.dart';
import 'media_engine.dart';
import 'media_state.dart';
import 'models/audio_track_info.dart';
import 'models/media_info.dart';
import 'models/subtitle_track_info.dart';
import 'mpv_kit_errors.dart';
import 'mpv_kit_tracks.dart';
import 'mpv_property_mapper.dart';
import 'open_failure_circuit_breaker.dart';
import 'open_result.dart';
import 'playlist_move_planner.dart';
import 'shuffle_policy.dart';
import 'video_effect_type.dart';
import 'volume_resync_gate.dart';

part 'mpv_kit_engine_queue.dart';

/// mpv_kit 后端的 [MediaEngine] 实现.
///
/// 身份保持转发 (Blocking Constraint #6): UI 的 ValueListenableBuilder 监听
/// 引擎自建 notifier 实例, getter 恒返回同一实例; 它们由 [Player] 的
/// MpvState 流与 mpv 事件写入.
///
/// 与 media_kit 时代的语义差异 (均为直接取 mpv 原生信号, 而非包内推导):
/// - EOF: `end-file` (reason eof) 事件驱动完成态 (keep-open=no 下
///   eof-reached 不会稳定为真).
/// - 装载成功: `file-loaded` 事件 (熔断复位 + file-scoped 属性重放).
/// - 路径直传 mpv, 无 URI 编解码层 (`#`/`%` 文件名天然安全).
class MpvKitEngine implements MediaEngine {
  /// 构造引擎并创建 mpv 核心 (同步; libmpv 由 mpv_kit_libs 打包).
  ///
  /// [playerOptions] 覆盖 [defaultOptions] (测试传 `vo=null`/`ao=null`).
  /// 视频输出须另行 `await attachVideo()` — 渲染上下文创建是异步的.
  MpvKitEngine({Map<String, String> playerOptions = const {}})
    : _player = Player(options: {...defaultOptions, ...playerOptions}) {
    _subscribe();
  }

  /// 全局 mpv 选项 — 在 `mpv_initialize` 前生效.
  ///
  /// 内存治理 (v0.0.9) 沿用 media_kit 时代的覆写值; 字幕两项服务于
  /// "libass 画进纹理 + sub-margin-y 避让控制栏" (见 [setSubtitleBottomInset]).
  static const Map<String, String> defaultOptions = <String, String>{
    // 本地文件无网络抖动可抗, 磁盘 demuxer 缓存只增 IO 与页缓存.
    'cache-on-disk': 'no',
    // 后向缓冲 8MB — 本地回退 seek 直接重读盘, 大后向缓冲白占 RSS.
    'demuxer-max-back-bytes': '8388608',
    // 播完即卸载解码链 (v0.0.9 泄漏治理: 停播后 RSS 回落).
    'keep-open': 'no',
    // 硬解白名单全覆盖 — 不在名单的格式会静默回退软解, 4K60 必卡.
    'hwdec-codecs': 'all',
    'hwdec': 'auto-safe',
    // 注: media_kit 时代的 `demuxer-max-secs=10` 已删 — mpv 0.41 无此选项
    // (旧 setProperty 一直静默失败、从未生效); 前向缓冲由 bytes 上限约束.
    // ASS 普通对白也服从 sub-margin-y (\pos 定位的特效字幕不受影响).
    'sub-ass-force-margins': 'yes',
    'sub-margin-y': '$_baseSubMarginY',
  };

  /// mpv `sub-margin-y` 默认值 (缩放像素, 以 720p 窗口高度为基准).
  static const int _baseSubMarginY = 22;

  /// sub-margin-y 缩放像素的参考窗口高度 (`sub-scale-by-window=yes`).
  static const double _subScaleReferenceHeight = 720;

  final Player _player;
  MpvVideoController? _video;

  /// mpv_kit [Player] — UI 端口 (进度条直连流) 与诊断使用.
  Player get player => _player;

  /// 视频输出控制器; [attachVideo] 完成前为 null.
  MpvVideoController? get videoController => _video;

  /// 创建视频渲染上下文 (Vulkan 零拷贝, 失败回退软件渲染) 并发布 textureId.
  ///
  /// side effect: 向 mpv 注册 render context; 失败抛 PlatformException,
  /// 由 PlayerServices 初始化链统一处理.
  Future<void> attachVideo() async {
    if (_disposed || _video != null) return;
    final video = await MpvVideoController.create(_player);
    if (_disposed) {
      await video.dispose();
      return;
    }
    _video = video;
    _textureId.value = video.textureId;
    _log('mpv_kit 视频输出: backend=${video.backend.name} (${video.reason})');
    // 跨机器排障: release 日志为 NullSink, 渲染路径落盘到 environment.txt.
    RuntimeEnvironmentReport.I
      ..record('render.backend', video.backend.name)
      ..record('render.reason', video.reason);
  }

  // ---- 自建 ValueNotifier ----
  final ValueNotifier<int?> _textureId = ValueNotifier<int?>(null);
  final ValueNotifier<MediaState> _state = ValueNotifier(MediaState.idle);
  final ValueNotifier<bool> _isSeeking = ValueNotifier(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier(false);
  final ValueNotifier<int> _position = ValueNotifier<int>(0);
  final ValueNotifier<int> _duration = ValueNotifier<int>(0);
  final ValueNotifier<double> _volume = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<String> _subtitleText = ValueNotifier<String>('');
  final ValueNotifier<int> _buffered = ValueNotifier<int>(0);
  final ValueNotifier<double> _aspectRatio = ValueNotifier<double>(0.0);
  final ValueNotifier<PlayerError?> _lastError = ValueNotifier<PlayerError?>(
    null,
  );
  final ValueNotifier<double> _playbackSpeed = ValueNotifier<double>(1.0);

  // ---- 队列镜像 (权威在 mpv 原生 playlist) ----
  final ValueNotifier<List<String>> _queuePaths = ValueNotifier<List<String>>(
    const <String>[],
  );
  final ValueNotifier<int> _queueIndex = ValueNotifier<int>(-1);
  final ValueNotifier<int> _queueRevision = ValueNotifier<int>(0);
  final ValueNotifier<PlayMode> _playMode = ValueNotifier<PlayMode>(
    PlayMode.loopAll,
  );

  /// open/stop 请求计数器 — 使旧异步 continuation 过期.
  int _operationGeneration = 0;

  List<MpvTrack> _tracks = const [];
  int? _videoWidth;
  int? _videoHeight;
  MediaInfo _mediaInfo = const MediaInfo();
  bool _hasMedia = false;

  /// 轨道表变更广播流 (K4-b) — 轨道偏好恢复挂此流首帧再读 mediaInfo.
  final StreamController<void> _trackTableChanged =
      StreamController<void>.broadcast();

  /// WASAPI 首播音量 re-sync 门 (v0.0.8.1).
  final VolumeResyncGate _volumeResync = VolumeResyncGate();

  int _subtitleDelayMs = 0;
  int _audioDelayMs = 0;

  /// 最近写入的 sub-margin-y — 相同值不重复写 (每次写触发 mpv 重画).
  int _subMarginY = _baseSubMarginY;

  /// file-scoped mpv 属性缓存 — 新文件装载会重置这些属性, 经
  /// `file-loaded` / 视频参数就绪在新文件上幂等重放.
  final Map<String, String> _fileScopedProps = <String, String>{};

  /// 完成态抢占标志 — EOF 后的 pause 变化不得把 completed 误转 paused.
  bool _completing = false;

  /// shuffle 播放历史栈 (path 键) 与随机源 — 见 shuffle_policy.dart.
  final ListQueue<String> _shuffleHistory = ListQueue<String>();
  final Random _rng = Random();

  final Set<String> _warnedUnsupported = <String>{};
  final OpenFailureCircuitBreaker _openFailureBreaker =
      OpenFailureCircuitBreaker();

  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// 队列编辑抑制期 — 批量编辑期间回流只写镜像不发 revision (N+1 → 1).
  bool _queueEditInProgress = false;

  /// mpv `playlist` / `playlist-playing-pos` 是两个独立属性; 同一批事件内
  /// 先后到达, 微任务合并后单发 revision (单通知点契约).
  bool _queueFlushScheduled = false;

  /// 最近一次有效 (>=0) 的 playlist-playing-pos — 切曲间隙的 -1 不覆盖.
  int _playingPos = -1;

  bool _disposed = false;

  // ============================================================
  // EngineStateView / QueueControl — 身份保持转发
  // ============================================================

  @override
  ValueNotifier<int?> get textureId => _textureId;
  @override
  ValueNotifier<MediaState> get state => _state;
  @override
  ValueNotifier<int> get position => _position;
  @override
  ValueNotifier<int> get duration => _duration;
  @override
  ValueNotifier<double> get volume => _volume;
  @override
  ValueNotifier<bool> get isMuted => _isMuted;
  @override
  ValueNotifier<bool> get isBuffering => _isBuffering;
  @override
  ValueNotifier<bool> get isSeeking => _isSeeking;
  @override
  ValueNotifier<String> get subtitleText => _subtitleText;
  @override
  ValueNotifier<int> get buffered => _buffered;
  @override
  ValueNotifier<double> get aspectRatio => _aspectRatio;
  @override
  ValueNotifier<PlayerError?> get lastError => _lastError;
  @override
  ValueNotifier<double> get playbackSpeed => _playbackSpeed;
  @override
  MediaInfo get mediaInfo => _mediaInfo;
  @override
  Stream<void> get trackTableChanged => _trackTableChanged.stream;
  @override
  bool get hasMedia => _hasMedia;
  @override
  ValueNotifier<List<String>> get queuePaths => _queuePaths;
  @override
  ValueNotifier<int> get queueIndex => _queueIndex;
  @override
  ValueNotifier<int> get queueRevision => _queueRevision;
  @override
  ValueNotifier<PlayMode> get playMode => _playMode;

  // ============================================================
  // PlaybackControl
  // ============================================================

  @override
  Future<OpenResult> open(String path) async {
    if (_disposed) return const OpenSuperseded();
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      _state.value = MediaState.error;
      final error = FileError(
        FileErrorCode.pathEmpty,
        '文件路径为空',
        null,
        ErrorContext(action: 'open', path: trimmed, module: 'MpvKitEngine'),
      );
      _lastError.value = error;
      return OpenError(error);
    }
    final gen = ++_operationGeneration;
    _state.value = MediaState.opening;
    _isBuffering.value = true;
    try {
      // play:false — 起播由 PlaybackController 成功后显式 play() 控制.
      await _player.open(trimmed, play: false);
      if (!_isCurrentGeneration(gen)) return const OpenSuperseded();
      _hasMedia = true;
      _armVolumeResync();
      _state.value = MediaState.idle;
      return OpenSuccess(_mediaInfo);
    } on MpvException catch (error, stackTrace) {
      return _openFailed(gen, 'open', '打开失败', error, stackTrace, trimmed);
    } finally {
      if (_isCurrentGeneration(gen)) _isBuffering.value = false;
    }
  }

  /// open/openPlaylist 共用的失败发布 (stale 请求不得覆盖新会话).
  OpenResult _openFailed(
    int gen,
    String action,
    String label,
    Object error,
    StackTrace stackTrace, [
    String? path,
  ]) {
    if (!_isCurrentGeneration(gen)) return const OpenSuperseded();
    final playerError = UnknownError(
      '$label: $error',
      error,
      ErrorContext(
        action: action,
        generation: gen,
        path: path,
        module: 'MpvKitEngine',
        callbackStackTrace: stackTrace,
      ),
    );
    _lastError.value = playerError;
    _state.value = MediaState.error;
    return OpenError(playerError);
  }

  @override
  void play() {
    if (_disposed || !_hasMedia) return;
    final s = _state.value;
    if (s == MediaState.playing ||
        s == MediaState.opening ||
        s == MediaState.error) {
      return;
    }
    _completing = false;
    _state.value = MediaState.playing;
    // 播完 (keep-open=no) 后 mpv 已 idle — 重新播放须重新起播当前条目.
    if (_player.idle.value && _queuePaths.value.isNotEmpty) {
      final index = _queueIndex.value < 0 ? 0 : _queueIndex.value;
      _command(['playlist-play-index', index]);
    }
    _guard('play', _player.play);
  }

  @override
  void pause() {
    if (_disposed || _state.value != MediaState.playing) return;
    _state.value = MediaState.paused;
    _guard('pause', _player.pause);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    _completing = false;
    try {
      _player.stop();
    } on MpvException catch (error, stackTrace) {
      if (!_isCurrentGeneration(generation)) return;
      _lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        '停止播放失败: $error',
        error,
        ErrorContext(
          action: 'stop',
          generation: generation,
          module: 'MpvKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
      _state.value = MediaState.error;
      return;
    }
    if (!_isCurrentGeneration(generation)) return;
    _clearLoadedMediaState();
    if (_state.value != MediaState.idle) _state.value = MediaState.idle;
  }

  @override
  void togglePlayPause() {
    switch (_state.value) {
      case MediaState.playing:
        pause();
      case MediaState.idle || MediaState.paused || MediaState.completed:
        play();
      case MediaState.opening || MediaState.error:
        break; // not toggleable — no-op
    }
  }

  // ============================================================
  // QueueControl — 实现见 mpv_kit_engine_queue.dart
  // ============================================================

  @override
  Future<OpenResult> openPlaylist(List<String> paths, {int startIndex = 0}) =>
      _disposed
      ? Future.value(const OpenSuperseded())
      : _openPlaylist(paths, startIndex);

  @override
  Future<void> appendToQueue(List<String> paths) async {
    if (_disposed || paths.isEmpty) return;
    await _appendToQueue(paths);
  }

  @override
  Future<void> removeFromQueue(int index) async {
    if (!_disposed) _removeFromQueue(index);
  }

  @override
  Future<void> removeFromQueueBatch(Set<int> indices) async {
    if (!_disposed && indices.isNotEmpty) _removeFromQueueBatch(indices);
  }

  @override
  Future<void> sortQueue(List<String> targetOrder) async {
    if (!_disposed) await _sortQueue(targetOrder);
  }

  @override
  Future<bool> jumpTo(int index) async => !_disposed && _jumpTo(index);

  @override
  bool nextInQueue() => !_disposed && _stepQueue(forward: true);

  @override
  bool previousInQueue() => !_disposed && _stepQueue(forward: false);

  @override
  Future<void> setPlayMode(PlayMode mode) async {
    if (!_disposed) _setPlayMode(mode);
  }

  @override
  Future<void> seekTo(int ms) async {
    if (_disposed) return;
    final dur = _duration.value;
    if (_state.value == MediaState.idle || dur <= 0) return;
    final clamped = ms.clamp(0, dur);
    // 乐观定位: 立即反馈 UI; time-pos 回流纠正.
    _position.value = clamped;
    _isSeeking.value = true;
    try {
      // `absolute` 不带 +keyframes: mpv 默认对绝对 seek 走精确 (hr-seek),
      // 与 media_kit 时代语义一致.
      await _player.mpv.commandAsync([
        'seek',
        '${clamped / 1000}',
        'absolute',
      ]).result;
    } on MpvException catch (error) {
      _lastError.value = PlaybackError(
        PlaybackErrorCode.seekFailed,
        '跳转失败: $error',
        error,
        ErrorContext(action: 'seek', module: 'MpvKitEngine'),
      );
    } finally {
      if (!_disposed) _isSeeking.value = false;
    }
  }

  @override
  void setVolume(double value) {
    if (_disposed) return;
    final clamped = value.clamp(0.0, 1.0);
    _volume.value = clamped;
    // 穿越 0 边界联动静音 (契约: 0 自动静音, 调高取消).
    if (clamped == 0.0) {
      _isMuted.value = true;
      _applyMuteProperty(true);
    } else if (_isMuted.value) {
      _isMuted.value = false;
      _applyMuteProperty(false);
    }
    // 感知曲线: mpv volume 是立方软增益, 传立方根使滑条位置即感知响度.
    _guard(
      'setVolume',
      () => _player.setVolume(MpvPropertyMapper.mapVolumeToMpv(clamped)),
    );
  }

  @override
  void setMute(bool mute) {
    if (_disposed) return;
    _isMuted.value = mute;
    _applyMuteProperty(mute);
  }

  /// mute 是全局属性 — 不入 file-scoped 缓存 (否则新文件被错误重放).
  void _applyMuteProperty(bool mute) =>
      _applyMpvProperty(MpvPropertyMapper.mapMute(mute), fileScoped: false);

  /// arm 首播音量 re-sync — 仅 Windows (WASAPI 特性).
  void _armVolumeResync() {
    if (Platform.isWindows) _volumeResync.arm();
  }

  @override
  void setPlaybackRate(double rate) {
    if (_disposed) return;
    final clamped = rate.clamp(0.25, 4.0);
    _playbackSpeed.value = clamped;
    _guard('setPlaybackRate', () => _player.setSpeed(clamped));
  }

  @override
  void setRange({required int from, int to = -1}) => _unsupported('setRange');

  @override
  void skipForward([int ms = 10000]) => unawaited(seekTo(_position.value + ms));

  @override
  void skipBack([int ms = 10000]) => unawaited(seekTo(_position.value - ms));

  // ============================================================
  // TrackControl / SubtitleConfig
  // ============================================================

  @override
  List<AudioTrackInfo> getAudioTracks() => audioTracksFromMpv(_tracks);

  @override
  void switchAudioTrack(int trackId) {
    if (_disposed) return;
    final id = mpvTrackIdAt(_tracks, MpvTrackType.audio, trackId);
    if (id == null) return;
    _guard(
      'switchAudioTrack',
      () => _player.selectTrack(MpvTrackType.audio, id),
    );
  }

  @override
  List<int> get activeAudioTracks =>
      activeIndexOf(_tracks, MpvTrackType.audio, _player.audioTrack.value);

  @override
  List<SubtitleTrackInfo> getSubtitleTracks() => subtitleTracksFromMpv(_tracks);

  @override
  void switchSubtitleTrack(int trackId) {
    if (_disposed) return;
    // K4-a: -1 = 关闭字幕偏好 (显式 sid=no, 否则下个文件自动回来).
    if (trackId == -1) {
      _guard(
        'switchSubtitleTrack',
        () => _player.selectTrack(MpvTrackType.sub, null),
      );
      return;
    }
    final id = mpvTrackIdAt(_tracks, MpvTrackType.sub, trackId);
    if (id == null) return;
    _guard(
      'switchSubtitleTrack',
      () => _player.selectTrack(MpvTrackType.sub, id),
    );
  }

  @override
  void toggleSubtitle() {
    if (_disposed) return;
    final off = _player.subtitleTrack.value == null;
    _guard(
      'toggleSubtitle',
      () => _player.mpv.setPropertyString('sid', off ? 'auto' : 'no'),
    );
  }

  @override
  void setExternalSubtitle(String path) {
    if (_disposed) return;
    unawaited(
      _player.addSubtitle(path).catchError((Object error) {
        _reportPropertyError('sub-add', path, error);
      }),
    );
  }

  @override
  void setSubtitleDelay(int delay) {
    if (_disposed) return;
    _subtitleDelayMs = delay;
    _applyMpvProperty(MpvPropertyMapper.mapDelay('sub-delay', delay));
  }

  @override
  void setAudioDelay(int delay) {
    if (_disposed) return;
    _audioDelayMs = delay;
    _applyMpvProperty(MpvPropertyMapper.mapDelay('audio-delay', delay));
  }

  @override
  void setEqualizer(String preset) => _unsupported('setEqualizer');

  @override
  int get subtitleDelay => _subtitleDelayMs;

  @override
  int get audioDelay => _audioDelayMs;

  @override
  List<int> get activeSubtitleTracks =>
      activeIndexOf(_tracks, MpvTrackType.sub, _player.subtitleTrack.value);

  /// 控制栏避让: 把字幕底边距抬高 [inset] 逻辑像素.
  ///
  /// 字幕由 libass 画进视频纹理, Flutter 侧无字幕组件可加 padding — 改写
  /// mpv `sub-margin-y` (缩放像素, 以 720p 窗口高度为基准), 换算:
  /// `22 + inset × 720 / surfaceHeight`. [inset] 为 0 即恢复默认边距.
  /// side effect: 值变化时写 mpv 属性 (触发一次字幕重画).
  void setSubtitleBottomInset(double inset, double surfaceHeight) {
    if (_disposed || surfaceHeight <= 0) return;
    final margin =
        _baseSubMarginY +
        (inset.clamp(0, surfaceHeight) *
                _subScaleReferenceHeight /
                surfaceHeight)
            .round();
    if (margin == _subMarginY) return;
    _subMarginY = margin;
    _guard(
      'sub-margin-y',
      () => _player.mpv.setPropertyString('sub-margin-y', '$margin'),
    );
  }

  // ============================================================
  // VideoEffectControl / RendererControl — mpv 属性直通
  // ============================================================

  @override
  void setVideoEffect(VideoEffectType effectType, double value) {
    if (_disposed) return;
    _applyMpvProperty(MpvPropertyMapper.mapVideoEffect(effectType, value));
  }

  @override
  void rotate(int degrees) {
    if (_disposed) return;
    _applyMpvProperty(MpvPropertyMapper.mapRotation(degrees));
  }

  @override
  void setAspectRatio(double ratio) {
    if (_disposed) return;
    final property = MpvPropertyMapper.mapAspectRatio(ratio);
    if (property == null) {
      // stretch/cropFill 单属性不可表达 — 诚实降级, 保持原状不伪造.
      _unsupported('setAspectRatio.$ratio');
      return;
    }
    _applyMpvProperty(property);
  }

  @override
  void setDeinterlace(bool enable) {
    if (_disposed) return;
    _applyMpvProperty(MpvPropertyMapper.mapDeinterlace(enable));
  }

  @override
  void setD3d11SyncEnabled(bool enabled) => _unsupported('setD3d11SyncEnabled');

  @override
  void setHardwareDecoding(bool enabled) {
    if (_disposed) return;
    // hwdec 是全局属性 — 新文件装载不重置, 不入缓存.
    _applyMpvProperty(
      MpvPropertyMapper.mapHardwareDecoding(enabled),
      fileScoped: false,
    );
  }

  /// 应用一条 mpv 属性 — 写 file-scoped 缓存 (可选) + setPropertyString.
  void _applyMpvProperty(MpvProperty property, {bool fileScoped = true}) {
    if (_disposed) return;
    if (fileScoped) _fileScopedProps[property.key] = property.value;
    try {
      _player.mpv.setPropertyString(property.key, property.value);
    } on MpvException catch (error) {
      // 单条属性失败不致命 — 记录即可, 播放不受阻.
      _reportPropertyError(property.key, property.value, error);
    }
  }

  /// 重放全部 file-scoped 属性 — 新文件就绪信号触发, 幂等.
  void _reapplyFileScopedProps() {
    if (_disposed) return;
    for (final entry in _fileScopedProps.entries) {
      try {
        _player.mpv.setPropertyString(entry.key, entry.value);
      } on MpvException catch (error) {
        _log('file-scoped 属性重放失败: ${entry.key}=${entry.value}: $error');
      }
    }
  }

  void _reportPropertyError(String key, String value, Object error) {
    if (_disposed) return;
    _lastError.value = UnknownError(
      'mpv 属性应用失败: $key=$value: $error',
      error,
      ErrorContext(action: 'setProperty', module: 'MpvKitEngine'),
    );
  }

  // ============================================================
  // dispose
  // ============================================================

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_trackTableChanged.close());
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    for (final n in <ChangeNotifier>[
      _textureId,
      _state,
      _isSeeking,
      _isBuffering,
      _position,
      _duration,
      _volume,
      _isMuted,
      _subtitleText,
      _buffered,
      _aspectRatio,
      _lastError,
      _playbackSpeed,
      _queuePaths,
      _queueIndex,
      _queueRevision,
      _playMode,
    ]) {
      n.dispose();
    }
    // Player.dispose 先跑 dispose hook (视频控制器先于 mpv 核心释放).
    unawaited(_player.dispose());
  }

  // ============================================================
  // mpv 状态/事件 → ValueNotifier 桥接
  // ============================================================

  /// 订阅 MpvState 流 (`.stream` 不回放当前值; 构造时核心尚未装载媒体,
  /// 初值即各 notifier 默认值).
  void _listen<T>(Stream<T> stream, void Function(T) onData) {
    _subscriptions.add(
      stream.listen((v) {
        if (!_disposed) onData(v);
      }),
    );
  }

  void _subscribe() {
    final p = _player;
    _listen(p.position.stream, (d) => _position.value = d.inMilliseconds);
    _listen(p.duration.stream, (d) {
      _duration.value = d.inMilliseconds;
      _rebuildMediaInfo();
    });
    // mpv volume 0~100 → 感知刻度 0.0~1.0 (与 setVolume 的立方根互逆).
    _listen(
      p.volume.stream,
      (v) => _volume.value = MpvPropertyMapper.mapVolumeFromMpv(v),
    );
    _listen(p.speed.stream, (r) => _playbackSpeed.value = r);
    _listen(p.buffering.stream, (b) => _isBuffering.value = b);
    _listen(
      p.bufferedPosition.stream,
      (d) => _buffered.value = d.inMilliseconds,
    );
    _listen(p.subtitleText.stream, (t) => _subtitleText.value = t);
    _listen(p.paused.stream, (paused) {
      // 无文件 (idle) 时的 pause 变化与播放态无关.
      if (!p.idle.value) _onPlaying(!paused);
    });
    _listen(p.tracks.stream, (t) {
      _tracks = t;
      _rebuildMediaInfo();
      // K4-b: mediaInfo 已是新表后再通知.
      _trackTableChanged.add(null);
    });
    // 视频链就绪 = file-scoped 属性重放的权威信号.
    _listen(p.videoParams.stream, (vp) {
      _videoWidth = vp?.width;
      _videoHeight = vp?.height;
      _updateAspectRatio();
      _rebuildMediaInfo();
      if (vp != null) _reapplyFileScopedProps();
    });
    _listen(p.playlist.stream, (_) => _scheduleQueueFlush());
    _listen(p.mpv.observeProperty('playlist-playing-pos'), (v) {
      // 切曲间隙的 -1 不覆盖当前条目 (与 media_kit 镜像语义一致).
      if (v is int && v >= 0) _playingPos = v;
      _scheduleQueueFlush();
    });
    // 实际硬解路径 (d3d11va/videotoolbox/vaapi/no) — "no" = CPU 软解, 是
    // 其他机器卡顿的首要嫌疑; 每次变化落盘 environment.txt.
    _listen(p.mpv.observeProperty('hwdec-current'), (v) {
      if (v is String && v.isNotEmpty) {
        RuntimeEnvironmentReport.I.record('decode.hwdec', v);
      }
    });
    _listen(p.mpv.events, _onEvent);
    _listen(p.errors, _onPlaybackError);
    // 4K 排障: info 级才有 "Using hardware decoding" 等解码路径实锤.
    p.setLogLevel('info');
    _listen(p.logs, _onLog);
  }

  void _onEvent(MpvEventData e) {
    switch (e) {
      case StartFileEvent():
        _onPlaying(!_player.paused.value);
      case FileLoadedEvent():
        _openFailureBreaker.reset();
        _reapplyFileScopedProps();
      case EndFileEvent(reason: EndFileReason.eof):
        _onCompleted();
      default:
        break;
    }
  }

  /// 播放/暂停转换. EOF 抢占期 (_completing) 的 paused 不覆盖完成态.
  void _onPlaying(bool playing) {
    if (playing) {
      _completing = false;
      // WASAPI 首播 re-sync: 设备可能首播才就绪, 幂等重写 volume+mute.
      if (_volumeResync.consumeOnPlaying()) {
        _guard(
          'volumeResync',
          () => _player.setVolume(
            MpvPropertyMapper.mapVolumeToMpv(_volume.value),
          ),
        );
        _applyMuteProperty(_isMuted.value);
      }
      if (_state.value != MediaState.playing &&
          _state.value != MediaState.opening) {
        _state.value = MediaState.playing;
      }
    } else {
      if (_completing) return;
      if (_state.value == MediaState.playing) _state.value = MediaState.paused;
    }
  }

  void _onCompleted() {
    _completing = true;
    _state.value = MediaState.completed;
    // shuffle 的 EOF 续播 — 随机覆盖层再定向 (loopAll/loopSingle 走 mpv 原生).
    if (_playMode.value == PlayMode.shuffle) _autoAdvanceShuffle();
  }

  void _onPlaybackError(MpvPlaybackError e) {
    // 按 playlist-entry-id 精确取失败条目 (队列镜像经微任务合并, 同批事件
    // 内尚未更新); 取不到再退回镜像当前项.
    final failedPath =
        _player.playlist.value
            .where((entry) => entry.id == e.playlistEntryId)
            .map((entry) => entry.filename)
            .firstOrNull ??
        _currentQueuePath();
    // 连续失败熔断 — 终止 mpv 自动推进的连锁失败 (实机: 90s 207 条).
    if (_openFailureBreaker.registerFailure()) {
      unawaited(stop());
      _lastError.value = UnknownError(
        '连续 ${_openFailureBreaker.threshold} 个文件打开失败, 已停止播放. '
        '最后失败: ${e.message}',
        e,
        ErrorContext(
          action: 'stream.error.circuit-break',
          module: 'MpvKitEngine',
          path: failedPath,
        ),
      );
      return;
    }
    _lastError.value = playerErrorFromMpv(
      e,
      path: failedPath,
      fileExists: (path) => File(path).existsSync(),
    );
  }

  /// mpv 内部日志: warn/error 全量 + info 级解码路径白名单.
  void _onLog(LogMessageEvent entry) {
    if (entry.level != 'error' && entry.level != 'warn') {
      final text = entry.text;
      final isDiag =
          entry.level == 'info' &&
          (text.contains('ardware decoding') ||
              text.contains('hwdec') ||
              text.contains('VO ') ||
              text.contains('video output'));
      if (!isDiag) return;
    }
    if (!KernelLoggerImpl.isInitialized) return;
    KernelLoggerImpl.I.d(
      'mpv[${entry.level}] ${entry.prefix}: ${entry.text.trimRight()}',
      context: {'failedPath': _currentQueuePath()},
    );
  }

  void _updateAspectRatio() {
    final w = _videoWidth;
    final h = _videoHeight;
    if (w != null && h != null && w > 0 && h > 0) _aspectRatio.value = w / h;
  }

  /// 清空已卸载媒体的派生状态, 防止空置 UI 渲染旧文件信息.
  void _clearLoadedMediaState() {
    _hasMedia = false;
    _position.value = 0;
    _duration.value = 0;
    _buffered.value = 0;
    _aspectRatio.value = 0;
    _subtitleText.value = '';
    _tracks = const [];
    _videoWidth = null;
    _videoHeight = null;
    _mediaInfo = const MediaInfo();
    _isSeeking.value = false;
    _isBuffering.value = false;
  }

  void _rebuildMediaInfo() {
    final codec = tracksOfType(
      _tracks,
      MpvTrackType.video,
    ).where((t) => t.selected).map((t) => t.codec ?? '').firstOrNull;
    _mediaInfo = MediaInfo(
      duration: _duration.value,
      video: videoInfoFromMpv(_player.videoParams.value, codec: codec ?? ''),
      audioTracks: audioTracksFromMpv(_tracks),
      subtitleTracks: subtitleTracksFromMpv(_tracks),
    );
  }

  // ============================================================
  // 内部工具
  // ============================================================

  bool _isCurrentGeneration(int gen) => gen == _operationGeneration;

  /// 同步 mpv 调用的统一守卫 — 失败记 lastError, 不抛向 UI.
  void _guard(String action, void Function() call) {
    if (_disposed) return;
    try {
      call();
    } on MpvException catch (error) {
      _lastError.value = UnknownError(
        'mpv 调用失败 ($action): $error',
        error,
        ErrorContext(action: action, module: 'MpvKitEngine'),
      );
    }
  }

  void _command(List<Object> args) =>
      _guard(args.first.toString(), () => _player.mpv.command(args));

  void _log(String message) {
    if (!KernelLoggerImpl.isInitialized) return;
    KernelLoggerImpl.I.i(message);
  }

  void _unsupported(String name) {
    if (!_warnedUnsupported.add(name)) return;
    if (!KernelLoggerImpl.isInitialized) return;
    KernelLoggerImpl.I.w('$name: mpv_kit 后端未实现, 已 stub');
  }
}
