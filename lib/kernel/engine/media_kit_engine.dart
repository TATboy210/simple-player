// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'engine_state_machine.dart';
import 'media_engine.dart';
import 'media_state.dart';
import 'open_result.dart';
import 'video_effect_type.dart';
import '../models/player_error.dart';
import 'models/audio_track_info.dart';
import 'models/media_info.dart';
import 'models/subtitle_track_info.dart';

/// media_kit (libmpv) 后端的 [MediaEngine] 实现 — 唯一后端.
///
/// 用 `Player.stream.*` 事件流桥接项目既有 ValueNotifier 契约.
/// 事件流驱动 position 替代 [PositionPoller] 的 250ms 轮询, 根治"进度不准".
///
/// 身份保持转发 (Blocking Constraint #6 — UI ValueListenableBuilder 监听
/// 的是引擎自己的 notifier 实例, 不能包装新 notifier 否则 listener detach):
///   - `state` / `isSeeking` / `isBuffering` 复用 [EngineStateMachine] 的 notifier
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
      ),
      _stateMachine = EngineStateMachine() {
    // VideoController 依赖 _player, 须在 _player 初始化后创建.
    // late final 合法: 构造体立即赋值, 首次使用前必然已初始化.
    _controller = VideoController(_player);
    // 注入 toggle 回调 — 构造后赋值以打破 stateMachine ↔ engine 循环依赖
    // (见 EngineStateMachine doc 的循环依赖说明).
    _stateMachine.onPlay = play;
    _stateMachine.onPause = pause;
    _subscribeStreams();
  }

  final Player _player;
  final EngineStateMachine _stateMachine;

  // VideoController 在构造体里创建 (依赖 _player), 故 late final.
  late final VideoController _controller;

  // ---- 自建 ValueNotifier (由 Player.stream 写入) ----
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

  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];
  bool _disposed = false;

  // ============================================================
  // EngineStateView — 身份保持转发
  // ============================================================

  @override
  ValueNotifier<int?> get textureId => _controller.id;

  @override
  ValueNotifier<MediaState> get state => _stateMachine.state;

  @override
  ValueNotifier<int> get position => _position;

  @override
  ValueNotifier<int> get duration => _duration;

  @override
  ValueNotifier<double> get volume => _volume;

  @override
  ValueNotifier<bool> get isMuted => _isMuted;

  @override
  ValueNotifier<bool> get isBuffering => _stateMachine.isBuffering;

  @override
  ValueNotifier<bool> get isSeeking => _stateMachine.isSeeking;

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

  @override
  EngineStateMachine get stateMachine => _stateMachine;

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
      _stateMachine.transitionTo(MediaState.error, 'open');
      final error = FileError(
        FileErrorCode.pathEmpty,
        '文件路径为空',
        null,
        ErrorContext(action: 'open', path: trimmed, module: 'MediaKitEngine'),
      );
      _lastError.value = error;
      return OpenError(error);
    }

    // generation 守卫: 仅最新 open 可发布状态.
    // 切歌时若从 playing 直转 opening 会被状态矩阵拒, 依赖后续 stream 修正
    // (切歌不频繁, 单次 warn 可接受).
    final gen = _stateMachine.nextGeneration();
    _stateMachine.transitionTo(MediaState.opening, 'open', generation: gen);
    _stateMachine.isBuffering.value = true;

    try {
      // play:false — 由 PlaybackController.open 成功后显式 play() 控制,
      // 避免与 controller 的 play() 调用产生状态竞争.
      await _player.open(Media(mediaUriFromPath(trimmed)), play: false);
      if (!_isCurrentGeneration(gen)) return const OpenSuperseded();

      // 成功: 回 idle (契约: 成功后 state==idle, 调用方随后 play()).
      // duration/tracks 由 stream 异步到达, _mediaInfo 随之重建.
      _hasMedia = true;
      _stateMachine.transitionTo(MediaState.idle, 'open', generation: gen);
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
      _stateMachine.transitionTo(MediaState.error, 'open', generation: gen);
      return OpenError(playerError);
    } finally {
      if (_isCurrentGeneration(gen)) _stateMachine.isBuffering.value = false;
    }
  }

  @override
  void play() {
    if (_disposed) return;
    final s = _stateMachine.state.value;
    // playing/opening/error 态 play 无意义且会触发 illegal 转换, 跳过.
    if (s == MediaState.playing ||
        s == MediaState.opening ||
        s == MediaState.error) {
      return;
    }
    _completing = false; // 重新播放, 清完成态.
    _stateMachine.transitionTo(MediaState.playing, 'play');
    unawaited(_player.play());
  }

  @override
  void pause() {
    if (_disposed) return;
    if (_stateMachine.state.value != MediaState.playing) return;
    _stateMachine.transitionTo(MediaState.paused, 'pause');
    unawaited(_player.pause());
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;

    // 使等待中的 open 失效；后续新 open/stop 也会使本次异步 stop 过期。
    final generation = _stateMachine.nextGeneration();
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
      _stateMachine.transitionTo(
        MediaState.error,
        'stop',
        generation: generation,
      );
      return;
    }

    // 旧 stop 的完成不能清空新 open 已经发布的媒体派生状态。
    if (!_isCurrentGeneration(generation)) return;
    _clearLoadedMediaState();
    if (_stateMachine.state.value != MediaState.idle) {
      _stateMachine.transitionTo(
        MediaState.idle,
        'stop',
        generation: generation,
      );
    }
  }

  @override
  void togglePlayPause() => _stateMachine.togglePlayPause();

  @override
  Future<void> seekTo(int ms) async {
    if (_disposed) return;
    final dur = _duration.value;
    if (_stateMachine.state.value == MediaState.idle || dur <= 0) return;

    final clamped = ms.clamp(0, dur);
    // 乐观定位: 立即反馈 UI; stream.position 随后推送真实值纠正.
    // 这是 media_kit 治"进度不准"的核心 — position 跟事件流, 不靠轮询.
    _position.value = clamped;
    _stateMachine.isSeeking.value = true;
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
      _stateMachine.isSeeking.value = false;
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
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _stateMachine.dispose();
    _position.dispose();
    _duration.dispose();
    _volume.dispose();
    _isMuted.dispose();
    _subtitleText.dispose();
    _buffered.dispose();
    _aspectRatio.dispose();
    _lastError.dispose();
    _playbackSpeed.dispose();
    // textureId (_controller.id) 由 player 生命周期管理, 不单独 dispose.
    // Player.dispose 是 Future — 用 unawaited 标记 fire-and-forget.
    unawaited(_player.dispose());
  }

  // ============================================================
  // stream → ValueNotifier 桥接
  // ============================================================

  void _subscribeStreams() {
    // position — 事件流根治轮询滞后 (换后端的核心收益).
    _subs.add(
      _player.stream.position.listen((d) {
        _position.value = d.inMilliseconds;
      }),
    );
    _subs.add(
      _player.stream.duration.listen((d) {
        _duration.value = d.inMilliseconds;
        _rebuildMediaInfo();
      }),
    );
    // media_kit volume 0~100 → 项目 0.0~1.0.
    // 仅同步数值, 不联动 isMuted (静音由 setMute 显式管).
    _subs.add(
      _player.stream.volume.listen((v) {
        _volume.value = (v / 100).clamp(0.0, 1.0);
      }),
    );
    _subs.add(
      _player.stream.rate.listen((r) {
        _playbackSpeed.value = r;
      }),
    );
    _subs.add(
      _player.stream.buffering.listen((b) {
        _stateMachine.isBuffering.value = b;
      }),
    );
    _subs.add(
      _player.stream.buffer.listen((d) {
        _buffered.value = d.inMilliseconds;
      }),
    );
    _subs.add(_player.stream.playing.listen(_onPlaying));
    _subs.add(_player.stream.completed.listen(_onCompleted));
    _subs.add(
      _player.stream.tracks.listen((t) {
        _tracks = t;
        _rebuildMediaInfo();
      }),
    );
    _subs.add(
      _player.stream.track.listen((t) {
        _track = t;
      }),
    );
    // 用 width/height 流算 aspectRatio, 避开 VideoParams 字段名版本差异.
    _subs.add(
      _player.stream.width.listen((w) {
        _videoWidth = w;
        _updateAspectRatio();
      }),
    );
    _subs.add(
      _player.stream.height.listen((h) {
        _videoHeight = h;
        _updateAspectRatio();
      }),
    );
    _subs.add(
      _player.stream.subtitle.listen((lines) {
        _subtitleText.value = lines.join('\n');
      }),
    );
    _subs.add(
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
      if (_stateMachine.state.value != MediaState.playing) {
        _stateMachine.transitionTo(MediaState.playing, 'stream.playing');
      }
    } else {
      // 完成态抢占: completed 已处理, 跳过 paused 转换.
      if (_completing) return;
      if (_stateMachine.state.value == MediaState.playing) {
        _stateMachine.transitionTo(MediaState.paused, 'stream.playing');
      }
    }
  }

  void _onCompleted(bool completed) {
    if (_disposed || !completed) return;
    _completing = true;
    // playing→completed 合法; 若 playing(false) 已先把 state 转 paused,
    // 此处 paused→completed 会 illegal (矩阵未收录) — 已知边界, 阶段 5 覆盖.
    _stateMachine.transitionTo(MediaState.completed, 'stream.completed');
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
    _stateMachine.isSeeking.value = false;
    _stateMachine.isBuffering.value = false;
  }

  /// 重建 _mediaInfo — duration/tracks 任一到达后调用, 保持两者同步.
  void _rebuildMediaInfo() {
    _mediaInfo = MediaInfo(
      duration: _duration.value,
      audioTracks: audioTracksFromMediaKit(_tracks),
      subtitleTracks: subtitleTracksFromMediaKit(_tracks),
    );
  }

  // ============================================================
  // 内部工具
  // ============================================================

  bool _isCurrentGeneration(int gen) => gen == _stateMachine.currentGeneration;

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
