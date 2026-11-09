// ignore_for_file: invalid_use_of_visible_for_testing_member

part of 'mpv_kit_engine.dart';

/// [MpvKitEngine] 的状态底座 — 字段、notifier 与 EngineStateView 转发.
///
/// State base of [MpvKitEngine]: fields, self-owned ValueNotifiers and the
/// identity-preserving `EngineStateView` getters. Behaviour lives in the
/// `_MpvKit*` mixins/extensions of the sibling part files, which are applied
/// on top of this class (so they can reach the private fields below).
///
/// 身份保持转发 (Blocking Constraint #6): UI 的 ValueListenableBuilder 监听
/// 引擎自建 notifier 实例, getter 恒返回同一实例; 它们由 [Player] 的
/// MpvState 流与 mpv 事件写入, 绝不包装.
abstract class _MpvKitState implements MediaEngine {
  _MpvKitState(this._player);

  final Player _player;
  MpvVideoController? _video;

  // ---- 自建 ValueNotifier (均有生产消费者, 见 EngineStateView) ----
  final ValueNotifier<int?> _textureId = ValueNotifier<int?>(null);
  final ValueNotifier<MediaState> _state = ValueNotifier(MediaState.idle);
  final ValueNotifier<int> _position = ValueNotifier<int>(0);
  final ValueNotifier<int> _duration = ValueNotifier<int>(0);
  final ValueNotifier<double> _volume = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(false);
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
  MediaInfo _mediaInfo = const MediaInfo();
  bool _hasMedia = false;

  /// 轨道表变更广播流 (K4-b) — 轨道偏好恢复挂此流首帧再读 mediaInfo.
  // ignore: close_sinks, 由 MpvKitEngine.dispose 关闭 (lint 无法跨 part 追踪).
  final StreamController<void> _trackTableChanged =
      StreamController<void>.broadcast();

  /// WASAPI 首播音量 re-sync 门 (v0.0.8.1).
  final VolumeResyncGate _volumeResync = VolumeResyncGate();

  /// 最近下发给 mpv 的 volume 值 (0~100) — 用于识别 mpv 属性回流的"回声".
  ///
  /// `setVolume` 先写 [_volume] (权威 = 滑条值), mpv 随后把同一数值经
  /// `volume` 属性流回显; 回显经 立方→立方根 往返存在浮点误差, 直接回写会
  /// 让 [_volume] 漂移一个 ulp 并多触发一次防抖落盘. 命中此窗口的回显一律
  /// 忽略, 只有外部来源 (非本引擎下发) 的变化才回写.
  final ListQueue<double> _sentMpvVolumes = ListQueue<double>();

  int _subtitleDelayMs = 0;
  int _audioDelayMs = 0;

  /// 最近写入的 sub-margin-y — 相同值不重复写 (每次写触发 mpv 重画).
  int _subMarginY = MpvKitEngine._baseSubMarginY;

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
  // EngineStateView / QueueControl getters — 身份保持转发
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

  /// 诚实降级的一次性告警 — 同名只记一次, 防刷屏.
  void _unsupported(String name) {
    if (!_warnedUnsupported.add(name)) return;
    if (!KernelLoggerImpl.isInitialized) return;
    KernelLoggerImpl.I.w('$name: mpv_kit 后端未实现, 已 stub');
  }

  /// 把感知刻度音量 [u] (0~1) 下发给 mpv, 并记入回声识别窗口.
  ///
  /// side effect: 写 mpv `volume` 属性; 记录的值供 `_onMpvVolume` 过滤回显.
  void _writeMpvVolume(String action, double u) {
    final mpvValue = MpvPropertyMapper.mapVolumeToMpv(u);
    // 窗口只需覆盖"已发出但回显未到"的在途值; 8 条足够任何滑条拖动速率.
    if (_sentMpvVolumes.length >= MpvKitEngine._echoWindow) {
      _sentMpvVolumes.removeFirst();
    }
    _sentMpvVolumes.add(mpvValue);
    _guard(action, () => _player.setVolume(mpvValue));
  }

  /// mpv `volume` 属性回流 — 过滤自身下发的回声, 仅外部变化回写 [_volume].
  void _onMpvVolume(double mpvValue) {
    final isEcho = _sentMpvVolumes.any(
      (sent) => (sent - mpvValue).abs() < MpvKitEngine._echoTolerance,
    );
    if (isEcho) return;
    _volume.value = MpvPropertyMapper.mapVolumeFromMpv(mpvValue);
  }
}

/// mpv 属性应用与 file-scoped 重放 — 各 facet 共用的属性写入口.
extension _MpvKitProps on _MpvKitState {
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

  /// arm 首播音量 re-sync — 仅 Windows (WASAPI 特性).
  void _armVolumeResync() {
    if (Platform.isWindows) _volumeResync.arm();
  }

  /// mute 是全局属性 — 不入 file-scoped 缓存 (否则新文件被错误重放).
  void _applyMuteProperty(bool mute) =>
      _applyMpvProperty(MpvPropertyMapper.mapMute(mute), fileScoped: false);
}
