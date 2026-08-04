import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../kernel/engine/engine_state.dart';
import 'player_units.dart';

/// media_kit [Player] 的可测试端口 — 抽象出 [PlayerControlsState] 所需的
/// stream + 快照 + 纯播放控制。
///
/// 路径B:控制栏直连 `player.stream`,但 [Player] 是 media_kit 具体类,headless
/// 测试环境无法构造(FFI mdk.dll 加载失败,见 memory
/// [[reference_mdk_dll_headless_test_failures]])。本接口用 Dart 标准类型暴露
/// 所需能力,生产用 `MediaKitPlayerPort` 包装真实 [Player],测试用 Fake。
///
/// 纯播放控制(playOrPause/seek/setRate)直写 player(路径B核心);volume/mute
/// 写走 [MediaEngine](保 `_preMuteVolume` 语义),不在此接口。
abstract interface class PlayerPort {
  /// 播放状态流
  Stream<bool> get playing;
  Stream<bool> get buffering;
  Stream<bool> get completed;

  /// 位置流(Duration)
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Duration> get buffer;

  /// 音量(0-100 media_kit 语义)/倍速流
  Stream<double> get volume;
  Stream<double> get rate;

  /// 初始快照(init 时读一次,避免首帧空白)
  bool get isPlayingNow;
  bool get isBufferingNow;
  Duration get positionNow;
  Duration get durationNow;
  double get volumeNow; // 0-100
  double get rateNow;

  /// 纯播放控制 — 直写 player(路径B)
  void playOrPause();
  void seek(Duration position);
  void setRate(double rate);
}

/// 路径B 控制栏的状态容器 — 订阅 [PlayerPort] stream 转写为 [ValueNotifier]。
///
/// 字段用 `ValueNotifier<int>` ms(非 Duration)对齐 ProgressBar seek-hold 的
/// int 差值比较,零改动迁移。volume 用 0-1(项目语义),从 media_kit 0-100 转换。
/// mute/volume 写走 [engine](保 `_preMuteVolume`),不写 [PlayerPort]。
class PlayerControlsState {
  PlayerControlsState(this._port, {required MediaEngine engine})
    : _engine = engine;

  final PlayerPort _port;
  final MediaEngine _engine;

  // ─── 播放状态 ───
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> buffering = ValueNotifier<bool>(false);
  final ValueNotifier<bool> completed = ValueNotifier<bool>(false);

  // ─── 位置(int ms — 对齐 seek-hold int 比较)───
  final ValueNotifier<int> positionMs = ValueNotifier<int>(0);
  final ValueNotifier<int> durationMs = ValueNotifier<int>(0);
  final ValueNotifier<int> bufferedMs = ValueNotifier<int>(0);

  // ─── 音量(0-1)/倍速 ───
  final ValueNotifier<double> volume01 = ValueNotifier<double>(1.0);
  final ValueNotifier<double> rate = ValueNotifier<double>(1.0);

  /// 静音状态 — 直接复用 engine.isMuted(避免双源)
  ValueListenable<bool> get isMuted => _engine.isMuted;

  // ─── stream 订阅 ───
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<double>? _rateSub;

  /// 订阅 [PlayerPort] stream + 初始快照。必须在 widget initState 调用。
  void init() {
    // 初始快照 — 避免首帧空白(订阅前的旧值)
    isPlaying.value = _port.isPlayingNow;
    buffering.value = _port.isBufferingNow;
    positionMs.value = ms(_port.positionNow);
    durationMs.value = ms(_port.durationNow);
    volume01.value = volumeFromMediaKit(_port.volumeNow);
    rate.value = _port.rateNow;

    _playingSub = _port.playing.listen((v) => isPlaying.value = v);
    _bufferingSub = _port.buffering.listen((v) => buffering.value = v);
    _completedSub = _port.completed.listen((v) => completed.value = v);
    _positionSub = _port.position.listen((d) => positionMs.value = ms(d));
    _durationSub = _port.duration.listen((d) => durationMs.value = ms(d));
    _bufferSub = _port.buffer.listen((d) => bufferedMs.value = ms(d));
    _volumeSub = _port.volume.listen(
      (v) => volume01.value = volumeFromMediaKit(v),
    );
    _rateSub = _port.rate.listen((v) => rate.value = v);
  }

  /// 播放/暂停 — 直写 player(路径B,跳过 engine 中间层)
  void playOrPause() => _port.playOrPause();

  /// seek(int ms)— 乐观更新 positionMs 再 player.seek.
  ///
  /// 关键:乐观更新让 ProgressBar seek-hold 立即到达容差触发 _finishSeekHold,
  /// 否则卡 2000ms 超时兜底(见计划"最大障碍")。
  void seek(int milliseconds) {
    final clamped = milliseconds.clamp(0, durationMs.value);
    positionMs.value = clamped;
    _port.seek(fromMs(clamped));
  }

  /// 倍速 — 直写 player
  void setRate(double r) => _port.setRate(r);

  /// 音量(0-1)— 写走 engine(保 _preMuteVolume 语义),不写 player
  void setVolume(double v01) => _engine.setVolume(v01);

  /// 静音切换 — 写走 engine,不写 player
  void toggleMute() => _engine.setMute(!_engine.isMuted.value);

  /// 取消订阅 + dispose 自建 notifiers(不 dispose engine.isMuted — engine 拥有)
  void dispose() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    _volumeSub?.cancel();
    _rateSub?.cancel();
    isPlaying.dispose();
    buffering.dispose();
    completed.dispose();
    positionMs.dispose();
    durationMs.dispose();
    bufferedMs.dispose();
    volume01.dispose();
    rate.dispose();
  }
}
