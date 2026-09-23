import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../kernel/engine/engine_state.dart';
import 'media_kit_player_port.dart';
import 'player_units.dart';

/// 控制栏状态容器 — 订阅 [PlayerPort] stream 转写为 [ValueNotifier]。
///
/// 字段用 `ValueNotifier<int>` ms(非 Duration)对齐 ProgressBar seek-hold 的
/// int 差值比较,零改动迁移。
/// 音量/静音均复用 [MediaEngine] 单一数据源 (v0.0.8.1): volume01 →
/// engine.volume(引擎内部完成 mpv 立方增益 ↔ 感知刻度换算,双源线性换算
/// 会使滑条漂移到 mpv 空间), isMuted → engine.isMuted; 写路径同理走 engine。
///
/// v0.0.6 清理: 删除 bufferedMs/completed 两个零消费者通知器及其流订阅
/// (ControlBarViewModel 无 buffered 字段,completed 态由 engine.state 表达)。
class PlayerControlsState {
  PlayerControlsState(this._port, {required this._engine});

  PlayerPort _port;
  MediaEngine _engine;

  // ─── 播放状态 ───
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> buffering = ValueNotifier<bool>(false);

  // ─── 位置(int ms — 对齐 seek-hold int 比较)───
  final ValueNotifier<int> positionMs = ValueNotifier<int>(0);
  final ValueNotifier<int> durationMs = ValueNotifier<int>(0);

  // ─── 倍速 ───
  final ValueNotifier<double> rate = ValueNotifier<double>(1.0);

  /// 音量(0-1 感知刻度) — 直接复用 engine.volume(避免双源换算漂移)
  ValueListenable<double> get volume01 => _engine.volume;

  /// 静音状态 — 直接复用 engine.isMuted(避免双源)
  ValueListenable<bool> get isMuted => _engine.isMuted;

  // ─── stream 订阅 ───
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<double>? _rateSub;

  /// 订阅 [PlayerPort] stream + 初始快照。必须在 widget initState 调用。
  void init() {
    _cancelSubscriptions();
    // 初始快照 — 避免首帧空白(订阅前的旧值)。音量无需快照 — volume01
    // 即 engine.volume notifier, 实例上已持有当前值。
    isPlaying.value = _port.isPlayingNow;
    buffering.value = _port.isBufferingNow;
    positionMs.value = ms(_port.positionNow);
    durationMs.value = ms(_port.durationNow);
    rate.value = _port.rateNow;

    _playingSub = _port.playing.listen((v) => isPlaying.value = v);
    _bufferingSub = _port.buffering.listen((v) => buffering.value = v);
    _positionSub = _port.position.listen((d) => positionMs.value = ms(d));
    _durationSub = _port.duration.listen((d) => durationMs.value = ms(d));
    _rateSub = _port.rate.listen((v) => rate.value = v);
  }

  /// 迁移到新的视频端口和引擎，同时复用现有 notifier 保持下游 identity。
  void updateSources(PlayerPort port, {required MediaEngine engine}) {
    _port = port;
    _engine = engine;
    init();
  }

  void _cancelSubscriptions() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _rateSub?.cancel();
    _playingSub = null;
    _bufferingSub = null;
    _positionSub = null;
    _durationSub = null;
    _rateSub = null;
  }

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

  /// 音量(0-1 感知刻度)— 写走 engine(感知曲线 + 原生静音在引擎层),不写 player
  void setVolume(double v01) => _engine.setVolume(v01);

  /// 静音切换 — 写走 engine(原生 mpv mute 属性),不写 player
  void toggleMute() => _engine.setMute(!_engine.isMuted.value);

  /// 取消订阅 + dispose 自建 notifiers(不 dispose engine.isMuted/volume — engine 拥有)
  void dispose() {
    _cancelSubscriptions();
    isPlaying.dispose();
    buffering.dispose();
    positionMs.dispose();
    durationMs.dispose();
    rate.dispose();
  }
}
