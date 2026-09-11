// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'media_engine.dart';
import 'media_state.dart';
import 'open_result.dart';
import 'video_effect_type.dart';
import '../models/play_mode.dart';
import '../models/player_error.dart';
import 'models/audio_track_info.dart';
import 'models/media_info.dart';
import 'models/subtitle_track_info.dart';
import 'models/video_codec_info.dart';

/// media_kit (libmpv) 后端的 [MediaEngine] 实现 — 唯一后端.
///
/// 用 `Player.stream.*` 事件流桥接项目既有 ValueNotifier 契约.
/// 事件流驱动 position 替代 [PositionPoller] 的 250ms 轮询, 根治"进度不准".
///
/// 身份保持转发 (Blocking Constraint #6 — UI ValueListenableBuilder 监听
/// 的是引擎自己的 notifier 实例, 不能包装新 notifier 否则 listener detach):
///   - `state` / `isSeeking` / `isBuffering` 由引擎自建 notifier 持有
///     (原 EngineStateMachine 已移除 — 状态容器与 generation 守卫内联于此)
///   - `textureId` 复用 [VideoController.id]
///   - 其余 7 个 (position/duration/volume/isMuted/subtitleText/buffered/
///     aspectRatio/lastError/playbackSpeed) 自建, 由 stream 写入
///
/// 不支持能力 (用户决策放弃, 阶段 4+ 再评估): 视频效果/旋转/反交错/字幕延迟/
/// EQ/AB 循环/D3D11 sync/运行时硬解切换 — 全部 stub + 一次性 debugPrint 告警.
class MediaKitEngine implements MediaEngine {
  /// 构造引擎. 须在 `MediaKit.ensureInitialized()` 之后调用 (libmpv 已加载).
  ///
  /// [configuration] 透传 media_kit [Player] (默认硬解开启).
  /// 单测不应实例化本类 (依赖 native libmpv); 纯逻辑走 [@visibleForTesting]
  /// 静态方法 ([mediaUriFromPath] / [audioTracksFromMediaKit] / ...).
  MediaKitEngine({PlayerConfiguration? configuration})
    : _player = Player(
        configuration: configuration ?? const PlayerConfiguration(),
      ) {
    // VideoController 依赖 _player, 须在 _player 初始化后创建.
    // late final 合法: 构造体立即赋值, 首次使用前必然已初始化.
    _controller = VideoController(_player);
    _subscribeStreams();
  }

  final Player _player;

  // VideoController 在构造体里创建 (依赖 _player), 故 late final.
  late final VideoController _controller;

  // ---- 自建 ValueNotifier (由 Player.stream 写入) ----
  // state/isSeeking/isBuffering 原由 EngineStateMachine 持有 — 状态机移除后
  // 内联为引擎自建 notifier. 实例身份保持: UI 的 ValueListenableBuilder 监听
  // 的是 getter 返回的同一实例, 不能包装否则 listener detach.
  final ValueNotifier<MediaState> _state = ValueNotifier(MediaState.idle);
  final ValueNotifier<bool> _isSeeking = ValueNotifier(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier(false);

  // open/stop 请求计数器 — 每次请求递增, 使旧异步 continuation 过期
  // (stale 回调不得发布状态/错误/清空新媒体派生状态).
  int _operationGeneration = 0;

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

  // ---- 队列状态镜像 (QueueControl) ----
  // 队列权威是 mpv 原生 playlist; 这里只镜像 paths/index/playMode 供服务层与
  // UI 消费. 拆两个 notifier: paths 变更罕见 (装载/追加/移除/shuffle), index
  // 切换频繁 (自动续播) — 避免每次切曲触发全列表重建.
  // 注意: 不镜像 media_kit Playlist 对象本身 (其 == 是 ListEquality O(n)).
  final ValueNotifier<List<String>> _queuePaths = ValueNotifier<List<String>>(
    const <String>[],
  );
  final ValueNotifier<int> _queueIndex = ValueNotifier<int>(-1);
  final ValueNotifier<PlayMode> _playMode = ValueNotifier<PlayMode>(
    PlayMode.loopAll,
  );

  // ---- stream 缓存 (tracks/track 异步到达, 供 getter 查询) ----
  Tracks? _tracks;
  Track? _track;
  int? _videoWidth;
  int? _videoHeight;
  MediaInfo _mediaInfo = const MediaInfo();
  bool _hasMedia = false;

  // 静音前音量快照 — unmute 时恢复. media_kit 无独立 mute API, 借 setVolume(0).
  double _preMuteVolume = 1.0;

  // 完成态抢占标志 — completed 事件先于 playing(false) 到达时,
  // 用它阻止 _onPlaying 把 completed 误转 paused (顺序见 _onPlaying 注释).
  bool _completing = false;

  // 已告警的 stub 方法集合 — 每个 stub 只 debugPrint 一次, 避免刷屏.
  final Set<String> _warnedUnsupported = <String>{};

  // 异构 stream 只保存取消回调，避免用 dynamic 统一不同的 stream 类型。
  final List<Future<void> Function()> _subscriptionCancels =
      <Future<void> Function()>[];
  bool _disposed = false;

  // ============================================================
  // EngineStateView — 身份保持转发
  // ============================================================

  @override
  ValueNotifier<int?> get textureId => _controller.id;

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
  bool get hasMedia => _hasMedia;

  // ============================================================
  // QueueControl — 身份保持转发
  // ============================================================

  @override
  ValueNotifier<List<String>> get queuePaths => _queuePaths;

  @override
  ValueNotifier<int> get queueIndex => _queueIndex;

  @override
  ValueNotifier<PlayMode> get playMode => _playMode;

  /// media_kit [VideoController] — 供 UI 层的 [Video] widget 使用.
  ///
  /// 契约缺口: [MediaEngine] 抽象未暴露 controller (fvp 走 textureId 自建 Texture,
  /// media_kit 走 Video widget), 阶段 2 经 [PlayerServices.mediaKitVideoController]
  /// 透传给 [PlayerScreen]. 契约清洁化留阶段 5.
  VideoController get videoController => _controller;

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
        ErrorContext(action: 'open', path: trimmed, module: 'MediaKitEngine'),
      );
      _lastError.value = error;
      return OpenError(error);
    }

    // generation 守卫: 仅最新 open 可发布状态 (stale continuation 不得
    // 覆盖新会话). 切歌时从 playing 直写 opening 是引擎本地允许的转换.
    final gen = ++_operationGeneration;
    _state.value = MediaState.opening;
    _isBuffering.value = true;

    try {
      // play:false — 由 PlaybackController.open 成功后显式 play() 控制,
      // 避免与 controller 的 play() 调用产生状态竞争.
      await _player.open(Media(mediaUriFromPath(trimmed)), play: false);
      if (!_isCurrentGeneration(gen)) return const OpenSuperseded();

      // 成功: 回 idle (契约: 成功后 state==idle, 调用方随后 play()).
      // duration/tracks 由 stream 异步到达, _mediaInfo 随之重建.
      _hasMedia = true;
      _state.value = MediaState.idle;
      return OpenSuccess(_mediaInfo);
    } on Exception catch (error, stackTrace) {
      if (!_isCurrentGeneration(gen)) return const OpenSuperseded();
      final playerError = UnknownError(
        '打开失败: $error',
        error,
        ErrorContext(
          action: 'open',
          generation: gen,
          path: trimmed,
          module: 'MediaKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
      _lastError.value = playerError;
      _state.value = MediaState.error;
      return OpenError(playerError);
    } finally {
      if (_isCurrentGeneration(gen)) _isBuffering.value = false;
    }
  }

  @override
  void play() {
    if (_disposed) return;
    // 空置态 (无媒体) play 无意义 — state 保持 idle, 防止 UI 把空置页
    // (极光背景) 卸载露出底层无媒体的黑色 Video. idle 同时表示
    // "未加载"与"已 open 未 play", 故以 _hasMedia 而非状态值判定.
    if (!_hasMedia) return;
    final s = _state.value;
    // playing/opening/error 态 play 无意义, 跳过.
    if (s == MediaState.playing ||
        s == MediaState.opening ||
        s == MediaState.error) {
      return;
    }
    _completing = false; // 重新播放, 清完成态.
    _state.value = MediaState.playing;
    unawaited(_player.play());
  }

  @override
  void pause() {
    if (_disposed) return;
    if (_state.value != MediaState.playing) return;
    _state.value = MediaState.paused;
    unawaited(_player.pause());
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;

    // 使等待中的 open 失效；后续新 open/stop 也会使本次异步 stop 过期。
    final generation = ++_operationGeneration;
    _completing = false;
    try {
      await _player.stop();
    } on Exception catch (error, stackTrace) {
      // 新会话已取得生命周期所有权时，旧 stop 不得覆盖其状态或错误信息。
      if (!_isCurrentGeneration(generation)) return;
      // stop 失败时不伪造“媒体已清空”的应用状态，避免用户继续操作残留媒体。
      final playerError = PlaybackError(
        PlaybackErrorCode.playFailed,
        '停止播放失败: $error',
        error,
        ErrorContext(
          action: 'stop',
          generation: generation,
          module: 'MediaKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
      _lastError.value = playerError;
      _state.value = MediaState.error;
      return;
    }

    // 旧 stop 的完成不能清空新 open 已经发布的媒体派生状态。
    if (!_isCurrentGeneration(generation)) return;
    _clearLoadedMediaState();
    if (_state.value != MediaState.idle) {
      _state.value = MediaState.idle;
    }
  }

  /// 切换播放/暂停 — 按当前状态分派到 [play]/[pause].
  ///
  /// State-to-action mapping:
  /// - playing → [pause]
  /// - idle/paused/completed → [play]
  /// - opening/error → no-op (not toggleable)
  /// 命令合法性 (如空置态 play) 由 play/pause 内部 guard 幂等处理.
  @override
  void togglePlayPause() {
    final current = _state.value;
    if (current == MediaState.playing) {
      pause();
    } else if (current == MediaState.idle ||
        current == MediaState.paused ||
        current == MediaState.completed) {
      play();
    }
    // opening/error — no-op
  }

  // ============================================================
  // QueueControl — 队列权威在 mpv 原生 playlist, 这里只做投影 + 乐观镜像
  // ============================================================

  @override
  Future<OpenResult> openPlaylist(
    List<String> paths, {
    int startIndex = 0,
  }) async {
    if (_disposed) return const OpenSuperseded();

    if (paths.isEmpty) {
      final error = FileError(
        FileErrorCode.pathEmpty,
        '队列为空, 无法装载',
        null,
        ErrorContext(
          action: 'openPlaylist',
          module: 'MediaKitEngine',
        ),
      );
      _lastError.value = error;
      return OpenError(error);
    }

    // generation 守卫: 与 open(String) 同模式 — 旧请求的异步 continuation
    // 不得覆盖新会话状态.
    final gen = ++_operationGeneration;
    _state.value = MediaState.opening;
    _isBuffering.value = true;

    try {
      final clampedStart = startIndex.clamp(0, paths.length - 1);
      final medias = <Media>[
        for (final path in paths) Media(mediaUriFromPath(path)),
      ];
      // play:false — 与 open(String) 一致, 由调用方显式 play() 控制起播时机.
      // mpv 侧: 写临时文件 + loadlist 整体装载 (毫秒级), 不逐条 append.
      await _player.open(Playlist(medias, index: clampedStart), play: false);
      if (!_isCurrentGeneration(gen)) return const OpenSuperseded();

      // 乐观镜像: stream.playlist 广播稍后到达, 值相同幂等覆盖.
      _queuePaths.value = List<String>.unmodifiable(paths);
      _queueIndex.value = clampedStart;
      _hasMedia = true;
      _state.value = MediaState.idle;
      return OpenSuccess(_mediaInfo);
    } on Exception catch (error, stackTrace) {
      if (!_isCurrentGeneration(gen)) return const OpenSuperseded();
      final playerError = UnknownError(
        '装载播放队列失败: $error',
        error,
        ErrorContext(
          action: 'openPlaylist',
          generation: gen,
          module: 'MediaKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
      _lastError.value = playerError;
      _state.value = MediaState.error;
      return OpenError(playerError);
    } finally {
      if (_isCurrentGeneration(gen)) _isBuffering.value = false;
    }
  }

  @override
  Future<void> appendToQueue(List<String> paths) async {
    if (_disposed || paths.isEmpty) return;
    try {
      // mpv loadfile append — 原子追加, 不打断当前播放.
      for (final path in paths) {
        await _player.add(Media(mediaUriFromPath(path)));
      }
      // 乐观镜像; index 不变 (追加不动当前播放). 空队列首次追加时保持 -1
      // (mpv playlist-playing-pos 语义: 未播放即 -1), 由 jumpTo/stream 纠正.
      _queuePaths.value = List<String>.unmodifiable([
        ..._queuePaths.value,
        ...paths,
      ]);
    } on Exception catch (error, stackTrace) {
      _lastError.value = UnknownError(
        '追加播放队列失败: $error',
        error,
        ErrorContext(
          action: 'appendToQueue',
          module: 'MediaKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> removeFromQueue(int index) async {
    if (_disposed) return;
    final paths = _queuePaths.value;
    // 越界 no-op — 与接口契约一致.
    if (index < 0 || index >= paths.length) return;
    try {
      await _player.remove(index);
      // 乐观镜像: 移除条目并平移 index. 正在播放条目被删时 mpv 自动跳转,
      // 精确 index 由 stream.playlist 回流纠正 — 这里只保证不越界.
      final remaining = [...paths]..removeAt(index);
      final current = _queueIndex.value;
      var nextIndex = current;
      if (current > index) {
        nextIndex = current - 1;
      } else if (current == index) {
        nextIndex = remaining.isEmpty
            ? -1
            : index.clamp(0, remaining.length - 1);
      }
      _queuePaths.value = List<String>.unmodifiable(remaining);
      _queueIndex.value = nextIndex;
    } on Exception catch (error, stackTrace) {
      _lastError.value = UnknownError(
        '移除队列条目失败: $error',
        error,
        ErrorContext(
          action: 'removeFromQueue',
          module: 'MediaKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<bool> jumpTo(int index) async {
    if (_disposed) return false;
    final count = _queuePaths.value.length;
    // 越界 no-op — mpv jump 不查边界, 防御前置.
    if (index < 0 || index >= count) return false;

    _completing = false; // 跳转即重新进入播放会话, 清完成态.
    _queueIndex.value = index; // 乐观镜像, stream 幂等覆盖.
    try {
      // media_kit jump 内部先 play 再 playlist-pos — 跳转即播放,
      // 符合"点击列表条目直接播放"的 UI 语义.
      await _player.jump(index);
      return true;
    } on Exception catch (error, stackTrace) {
      _lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        '跳转队列条目失败: $error',
        error,
        ErrorContext(
          action: 'jumpTo',
          module: 'MediaKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  @override
  bool nextInQueue() {
    return _stepQueue(forward: true);
  }

  @override
  bool previousInQueue() {
    return _stepQueue(forward: false);
  }

  /// 上一个/下一个的统一步进 — 边界语义按 [playMode] 裁定, 不透传
  /// media_kit next()/previous() 的内部判断 (它们在 loopSingle 末尾会
  /// 意外 no-op, 且先 play() 的副作用不可控). 全部走 [jumpTo].
  bool _stepQueue({required bool forward}) {
    if (_disposed) return false;
    final count = _queuePaths.value.length;
    if (count == 0) return false;

    final current = _queueIndex.value;
    // 未播放 (index == -1): 步进视为"从头/从尾开始播".
    if (current < 0) {
      unawaited(jumpTo(forward ? 0 : count - 1));
      return true;
    }

    final target = forward ? current + 1 : current - 1;
    if (target >= 0 && target < count) {
      unawaited(jumpTo(target));
      return true;
    }

    // 越界: 三种 PlayMode 均为循环语义 — 回绕 (loopSingle 只约束自然播完,
    // 用户主动切曲照常回绕). PlayMode 无 none 值, 此分支恒可达.
    unawaited(jumpTo(forward ? 0 : count - 1));
    return true;
  }

  @override
  Future<void> setPlayMode(PlayMode mode) async {
    if (_disposed) return;
    _playMode.value = mode; // 引擎为模式单一数据源, 先记后映射.
    try {
      switch (mode) {
        case PlayMode.loopAll:
          await _player.setPlaylistMode(PlaylistMode.loop);
          await _player.setShuffle(false);
        case PlayMode.loopSingle:
          // mpv loop-file — 自然播完单文件循环, 队列不动.
          await _player.setPlaylistMode(PlaylistMode.single);
          await _player.setShuffle(false);
        case PlayMode.shuffle:
          // 乱序循环: loop-playlist 保循环 + playlist-shuffle 一次性重排;
          // 重排后的新顺序经 stream.playlist 广播回流镜像.
          await _player.setPlaylistMode(PlaylistMode.loop);
          await _player.setShuffle(true);
      }
    } on Exception catch (error, stackTrace) {
      _lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        '设置播放模式失败: $error',
        error,
        ErrorContext(
          action: 'setPlayMode',
          module: 'MediaKitEngine',
          callbackStackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> seekTo(int ms) async {
    if (_disposed) return;
    final dur = _duration.value;
    if (_state.value == MediaState.idle || dur <= 0) return;

    final clamped = ms.clamp(0, dur);
    // 乐观定位: 立即反馈 UI; stream.position 随后推送真实值纠正.
    // 这是 media_kit 治"进度不准"的核心 — position 跟事件流, 不靠轮询.
    _position.value = clamped;
    _isSeeking.value = true;
    try {
      await _player.seek(Duration(milliseconds: clamped));
    } on Exception catch (error) {
      final pe = PlaybackError(
        PlaybackErrorCode.seekFailed,
        '跳转失败: $error',
        error,
        ErrorContext(action: 'seek', module: 'MediaKitEngine'),
      );
      _lastError.value = pe;
      // position 由 stream 纠正, 不回退本地乐观值.
    } finally {
      _isSeeking.value = false;
    }
  }

  @override
  void setVolume(double value) {
    if (_disposed) return;
    final clamped = value.clamp(0.0, 1.0);
    _volume.value = clamped;
    // 穿越 0 边界联动静音标志 (契约: 0 自动静音, 调高取消).
    if (clamped == 0.0) {
      _isMuted.value = true;
    } else if (_isMuted.value) {
      _isMuted.value = false;
    }
    // media_kit 音量 0~100, 项目 0.0~1.0.
    unawaited(_player.setVolume(clamped * 100));
  }

  @override
  void setMute(bool mute) {
    if (_disposed) return;
    if (mute) {
      if (!_isMuted.value) _preMuteVolume = _volume.value;
      _isMuted.value = true;
      unawaited(_player.setVolume(0));
    } else {
      _isMuted.value = false;
      unawaited(_player.setVolume(_preMuteVolume * 100));
    }
  }

  @override
  void setPlaybackRate(double rate) {
    if (_disposed) return;
    // 契约范围 0.25 ~ 4.0 (minPlaybackRate / maxPlaybackRate).
    final clamped = rate.clamp(0.25, 4.0);
    _playbackSpeed.value = clamped;
    unawaited(_player.setRate(clamped));
  }

  @override
  void setRange({required int from, int to = -1}) => _unsupported('setRange');

  @override
  void skipForward([int ms = 10000]) => unawaited(seekTo(_position.value + ms));

  @override
  void skipBack([int ms = 10000]) => unawaited(seekTo(_position.value - ms));

  // ============================================================
  // TrackControl
  // ============================================================

  @override
  List<AudioTrackInfo> getAudioTracks() => audioTracksFromMediaKit(_tracks);

  @override
  void switchAudioTrack(int trackId) {
    if (_disposed) return;
    final real = _realAudioTracks();
    if (trackId < 0 || trackId >= real.length) return;
    unawaited(_player.setAudioTrack(real[trackId]));
  }

  @override
  List<int> get activeAudioTracks {
    final cur = _track?.audio;
    if (cur == null || cur.id == 'auto' || cur.id == 'no') return const [];
    final idx = _realAudioTracks().indexWhere((t) => t.id == cur.id);
    return idx >= 0 ? <int>[idx] : const <int>[];
  }

  // ============================================================
  // SubtitleConfig
  // ============================================================

  @override
  List<SubtitleTrackInfo> getSubtitleTracks() =>
      subtitleTracksFromMediaKit(_tracks);

  @override
  void switchSubtitleTrack(int trackId) {
    if (_disposed) return;
    final real = _realSubtitleTracks();
    if (trackId < 0 || trackId >= real.length) return;
    unawaited(_player.setSubtitleTrack(real[trackId]));
  }

  @override
  void toggleSubtitle() {
    if (_disposed) return;
    final cur = _track?.subtitle;
    if (cur == null || cur.id == 'no') {
      unawaited(_player.setSubtitleTrack(SubtitleTrack.auto()));
    } else {
      unawaited(_player.setSubtitleTrack(SubtitleTrack.no()));
    }
  }

  @override
  void setExternalSubtitle(String path) {
    if (_disposed) return;
    unawaited(
      _player.setSubtitleTrack(SubtitleTrack.uri(mediaUriFromPath(path))),
    );
  }

  @override
  void setSubtitleDelay(int delay) => _unsupported('setSubtitleDelay');

  @override
  void setEqualizer(String preset) => _unsupported('setEqualizer');

  @override
  int get subtitleDelay => 0;

  @override
  List<int> get activeSubtitleTracks {
    final cur = _track?.subtitle;
    if (cur == null || cur.id == 'auto' || cur.id == 'no') return const [];
    final idx = _realSubtitleTracks().indexWhere((t) => t.id == cur.id);
    return idx >= 0 ? <int>[idx] : const <int>[];
  }

  // ============================================================
  // VideoEffectControl — 全部 stub (media_kit 无直接 API)
  // ============================================================

  @override
  void setVideoEffect(VideoEffectType effectType, double value) =>
      _unsupported('setVideoEffect.${effectType.name}');

  @override
  void rotate(int degrees) => _unsupported('rotate');

  @override
  void setAspectRatio(double ratio) => _unsupported('setAspectRatio');

  @override
  void setDeinterlace(bool enable) => _unsupported('setDeinterlace');

  // ============================================================
  // RendererControl — 全部 stub (硬解经 PlayerConfiguration 配, 运行时切换不支持)
  // ============================================================

  @override
  void setD3d11SyncEnabled(bool enabled) => _unsupported('setD3d11SyncEnabled');

  @override
  void setHardwareDecoding(bool enabled) => _unsupported('setHardwareDecoding');

  // ============================================================
  // dispose
  // ============================================================

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final cancel in _subscriptionCancels) {
      unawaited(_cancelSubscription(cancel));
    }
    _subscriptionCancels.clear();
    _state.dispose();
    _isSeeking.dispose();
    _isBuffering.dispose();
    _position.dispose();
    _duration.dispose();
    _volume.dispose();
    _isMuted.dispose();
    _subtitleText.dispose();
    _buffered.dispose();
    _aspectRatio.dispose();
    _lastError.dispose();
    _playbackSpeed.dispose();
    _queuePaths.dispose();
    _queueIndex.dispose();
    _playMode.dispose();
    // textureId (_controller.id) 由 player 生命周期管理, 不单独 dispose.
    // Player.dispose 是 Future — 用 unawaited 标记 fire-and-forget.
    unawaited(_player.dispose());
  }

  // ============================================================
  // stream → ValueNotifier 桥接
  // ============================================================

  /// 注册带具体类型的订阅，同时让取消回调列表保持同质。
  void _addSubscription<T>(StreamSubscription<T> subscription) {
    _subscriptionCancels.add(subscription.cancel);
  }

  /// 取消订阅并隔离异步清理失败，避免 dispose 产生未处理异常。
  Future<void> _cancelSubscription(Future<void> Function() cancel) async {
    try {
      await cancel();
    } on Exception catch (error, stackTrace) {
      debugPrint('Failed to cancel media stream subscription: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _subscribeStreams() {
    // position — 事件流根治轮询滞后 (换后端的核心收益).
    _addSubscription(
      _player.stream.position.listen((d) {
        _position.value = d.inMilliseconds;
      }),
    );
    _addSubscription(
      _player.stream.duration.listen((d) {
        _duration.value = d.inMilliseconds;
        _rebuildMediaInfo();
      }),
    );
    // media_kit volume 0~100 → 项目 0.0~1.0.
    // 仅同步数值, 不联动 isMuted (静音由 setMute 显式管).
    _addSubscription(
      _player.stream.volume.listen((v) {
        _volume.value = (v / 100).clamp(0.0, 1.0);
      }),
    );
    _addSubscription(
      _player.stream.rate.listen((r) {
        _playbackSpeed.value = r;
      }),
    );
    _addSubscription(
      _player.stream.buffering.listen((b) {
        _isBuffering.value = b;
      }),
    );
    // 队列状态回流 — mpv 侧 playlist-playing-pos 属性观察: 装载/追加/移除/
    // shuffle 重排/自动续播全部经此同步到镜像 (最终一致). 空列表广播
    // (stop 时 Playlist([]) index 默认 0) 归一为 -1 的"无当前条目"语义.
    _addSubscription(
      _player.stream.playlist.listen((pl) {
        _queuePaths.value = List<String>.unmodifiable(<String>[
          for (final m in pl.medias) pathFromMediaUri(m.uri),
        ]);
        _queueIndex.value = pl.medias.isEmpty ? -1 : pl.index;
      }),
    );
    _addSubscription(
      _player.stream.buffer.listen((d) {
        _buffered.value = d.inMilliseconds;
      }),
    );
    _addSubscription(_player.stream.playing.listen(_onPlaying));
    _addSubscription(_player.stream.completed.listen(_onCompleted));
    _addSubscription(
      _player.stream.tracks.listen((t) {
        _tracks = t;
        _rebuildMediaInfo();
      }),
    );
    _addSubscription(
      _player.stream.track.listen((t) {
        _track = t;
      }),
    );
    // 用 width/height 流算 aspectRatio, 避开 VideoParams 字段名版本差异.
    _addSubscription(
      _player.stream.width.listen((w) {
        _videoWidth = w;
        _updateAspectRatio();
      }),
    );
    _addSubscription(
      _player.stream.height.listen((h) {
        _videoHeight = h;
        _updateAspectRatio();
      }),
    );
    _addSubscription(
      _player.stream.subtitle.listen((lines) {
        _subtitleText.value = lines.join('\n');
      }),
    );
    _addSubscription(
      _player.stream.error.listen((msg) {
        _lastError.value = UnknownError(
          msg,
          null,
          ErrorContext(action: 'stream', module: 'MediaKitEngine'),
        );
      }),
    );
  }

  /// playing 事件驱动 playing/paused 转换. 完成引起的 playing(false) 由
  /// [_completing] 标志拦截 (completed 通常先于 playing(false) 到达).
  void _onPlaying(bool playing) {
    if (_disposed) return;
    if (playing) {
      if (_state.value != MediaState.playing) {
        _state.value = MediaState.playing;
      }
    } else {
      // 完成态抢占: completed 已处理, 跳过 paused 转换.
      if (_completing) return;
      if (_state.value == MediaState.playing) {
        _state.value = MediaState.paused;
      }
    }
  }

  void _onCompleted(bool completed) {
    if (_disposed || !completed) return;
    _completing = true;
    // completed 事件驱动转换 (playing→completed 合法路径).
    _state.value = MediaState.completed;
  }

  void _updateAspectRatio() {
    final w = _videoWidth;
    final h = _videoHeight;
    if (w != null && h != null && w > 0 && h > 0) {
      _aspectRatio.value = w / h;
    }
  }

  /// 清空已卸载媒体留下的派生状态，防止空置 UI 渲染旧文件信息。
  void _clearLoadedMediaState() {
    _hasMedia = false;
    _position.value = 0;
    _duration.value = 0;
    _buffered.value = 0;
    _aspectRatio.value = 0;
    _subtitleText.value = '';
    _tracks = null;
    _track = null;
    _videoWidth = null;
    _videoHeight = null;
    _mediaInfo = const MediaInfo();
    _isSeeking.value = false;
    _isBuffering.value = false;
  }

  /// media_kit width/height 事件流 → [VideoCodecInfo].
  ///
  /// 仅当两者都已到达且为正值时才返回视频元数据；否则为 null，避免
  /// 让纯音频/损坏文件被误识别成有效视频流。
  @visibleForTesting
  static VideoCodecInfo? videoInfoFromMediaKit({
    int? width,
    int? height,
    double par = 1.0,
    String codec = '',
  }) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return VideoCodecInfo(width: width, height: height, par: par, codec: codec);
  }

  /// 重建 _mediaInfo — duration/tracks 任一到达后调用, 保持两者同步.
  void _rebuildMediaInfo() {
    _mediaInfo = MediaInfo(
      duration: _duration.value,
      video: videoInfoFromMediaKit(width: _videoWidth, height: _videoHeight),
      audioTracks: audioTracksFromMediaKit(_tracks),
      subtitleTracks: subtitleTracksFromMediaKit(_tracks),
    );
  }

  // ============================================================
  // 内部工具
  // ============================================================

  bool _isCurrentGeneration(int gen) => gen == _operationGeneration;

  /// 过滤掉 media_kit 的 auto/no 占位轨, 只留真实轨道.
  List<AudioTrack> _realAudioTracks() {
    final all = _tracks?.audio ?? const <AudioTrack>[];
    return all.where((t) => t.id != 'auto' && t.id != 'no').toList();
  }

  List<SubtitleTrack> _realSubtitleTracks() {
    final all = _tracks?.subtitle ?? const <SubtitleTrack>[];
    return all.where((t) => t.id != 'auto' && t.id != 'no').toList();
  }

  void _unsupported(String name) {
    if (_warnedUnsupported.add(name)) {
      debugPrint(
        '[MediaKitEngine] $name: media_kit 后端不支持, 已 stub '
        '(阶段 4+ 评估是否经 NativePlayer.handle FFI 补)',
      );
    }
  }

  // ============================================================
  // 纯逻辑 (@visibleForTesting — 单测不依赖 native libmpv)
  // ============================================================

  /// 本地文件路径 → media_kit [Media] URI.
  /// `D:\video.mp4` → `file:///D:/video.mp4`; http/https/rtsp/file URL 原样返回.
  @visibleForTesting
  static String mediaUriFromPath(String path) {
    const schemes = <String>['http://', 'https://', 'rtsp://', 'file://'];
    for (final s in schemes) {
      if (path.startsWith(s)) return path;
    }
    // Windows 反斜杠 → 正斜杠, 加 file:/// 前缀 (空 host + 绝对路径).
    return 'file:///${path.replaceAll('\\', '/')}';
  }

  /// media_kit [Media] URI → 本地文件路径 ([mediaUriFromPath] 的对称反解).
  ///
  /// 用途: `Player.stream.playlist` 回流的 [Media.uri] 转回项目层路径语义,
  /// 供队列镜像与 path→index 映射消费. 非安全边界 — 仅展示/映射用.
  /// `file:///D:/video.mp4` → `D:\video.mp4`; http/rtsp 等 URL 原样返回.
  @visibleForTesting
  static String pathFromMediaUri(String uri) {
    const filePrefix = 'file:///';
    if (!uri.startsWith(filePrefix)) return uri;
    // Windows: 正斜杠还原为反斜杠 (与 mediaUriFromPath 的规范化对称).
    return uri.substring(filePrefix.length).replaceAll('/', r'\');
  }

  /// media_kit [Tracks.audio] → 项目 [AudioTrackInfo] 列表 (过滤 auto/no).
  @visibleForTesting
  static List<AudioTrackInfo> audioTracksFromMediaKit(Tracks? tracks) {
    final real =
        tracks?.audio
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList(growable: false) ??
        const <AudioTrack>[];
    return [
      for (var i = 0; i < real.length; i++)
        AudioTrackInfo(
          index: i,
          language: real[i].language ?? '',
          codec: real[i].codec ?? '',
          channels: real[i].channelscount ?? 0,
        ),
    ];
  }

  /// media_kit [Tracks.subtitle] → 项目 [SubtitleTrackInfo] 列表 (过滤 auto/no).
  @visibleForTesting
  static List<SubtitleTrackInfo> subtitleTracksFromMediaKit(Tracks? tracks) {
    final real =
        tracks?.subtitle
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList(growable: false) ??
        const <SubtitleTrack>[];
    return [
      for (var i = 0; i < real.length; i++)
        SubtitleTrackInfo(
          index: i,
          language: real[i].language ?? '',
          title: real[i].title ?? '',
        ),
    ];
  }
}
