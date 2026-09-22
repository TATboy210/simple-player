/// 应用偏好编排服务 — 持久化与引擎/服务之间的唯一读写通道 (v0.0.6).
///
/// App settings orchestration — the single read/write path between
/// persistence and engine/services.
///
/// 职责切分 (每层只做一件事):
/// - [AppSettingsStore] = 纯持久化 (无状态)
/// - [MediaKitEngine] = 只执行, 不依赖存储; file-scoped mpv 属性自带
///   内存缓存 + 新文件装载后重放
/// - 本类 = 编排: 启动回放 → 变更防抖写回 → 断点开关持有
///
/// 架构位置: SettingsPanel (UI) → **AppSettingsService** → MediaEngine /
/// VideoProcessingService / AppSettingsStore
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/player/models/video_processing_state.dart';
import '../diagnostics/kernel_logger.dart';
import '../engine/engine_state.dart';
import '../persistence/settings_store.dart';
import 'video_processing_service.dart';

/// re-export 便于 UI 侧单一 import (视频效果枚举随引擎 API 出现).
export '../engine/video_effect_type.dart' show VideoEffectType;
export '../persistence/settings_store.dart' show AppSettingsData;

/// 引擎音量/静音/倍速变更 → 落盘的防抖窗口 (默认值).
const _defaultEngineWriteDebounce = Duration(milliseconds: 300);

/// 视频状态变更 → 落盘的防抖窗口 (默认值, 拖动滑条高频).
const _defaultVideoWriteDebounce = Duration(milliseconds: 500);

final _log = KernelLogger.I;

/// 应用偏好编排服务.
class AppSettingsService {
  AppSettingsService({
    required this.engine,
    required this.videoProcessing,
    required this.store,
    this.engineWriteDebounce = _defaultEngineWriteDebounce,
    this.videoWriteDebounce = _defaultVideoWriteDebounce,
  });

  final MediaEngine engine;
  final VideoProcessingService videoProcessing;
  final AppSettingsStore store;

  /// 防抖窗口 — 可注入 (测试零窗口即事件循环下一轮落盘).
  final Duration engineWriteDebounce;
  final Duration videoWriteDebounce;

  bool _disposed = false;

  /// 回放中标志 — initialize 应用持久值时屏蔽监听器写回 (回声抑制).
  bool _restoring = false;

  // ─── 防抖定时器与待写值 ───

  Timer? volumeTimer;
  Timer? rateTimer;
  Timer? videoTimer;
  double? pendingVolume;
  bool? pendingMuted;
  double? pendingRate;
  VideoProcessingState? pendingVideo;

  /// 断点续播总开关 — coordinator 记录门控 + 面板显示门控共同消费.
  final ValueNotifier<bool> resumeEnabled = ValueNotifier(true);

  /// 硬解开关 — 设置 UI 消费 (ValueNotifier 体系).
  final ValueNotifier<bool> hardwareDecoding = ValueNotifier(true);

  /// 音频延迟 (毫秒) — 当前生效值 (内存镜像, UI 读取).
  int _audioDelayMs = 0;

  /// 字幕延迟 (毫秒).
  int _subtitleDelayMs = 0;

  int get audioDelayMs => _audioDelayMs;
  int get subtitleDelayMs => _subtitleDelayMs;

  /// 初始化 — 载入持久值 → 回放到引擎/服务 → 挂变更监听.
  ///
  /// 回放顺序: 引擎标量 (音量/静音/倍速) → 视频状态 (loadFrom + 全量
  /// 重放, 引擎 file-scoped 缓存随之建立) → 硬解/双延迟.
  Future<void> initialize() async {
    final data = await store.load();
    if (_disposed) return;

    _restoring = true; // 回放期屏蔽写回监听 (回声抑制)
    try {
      resumeEnabled.value = data.resumeEnabled;
      hardwareDecoding.value = data.hardwareDecoding;
      _audioDelayMs = data.audioDelayMs;
      _subtitleDelayMs = data.subtitleDelayMs;

      engine.setVolume(data.volume);
      if (data.isMuted) engine.setMute(true);
      engine.setPlaybackRate(data.playbackRate);

      videoProcessing.loadFrom(data.video);
      videoProcessing.reapplyAll();

      engine.setHardwareDecoding(data.hardwareDecoding);
      engine.setSubtitleDelay(_subtitleDelayMs);
      engine.setAudioDelay(_audioDelayMs);
    } finally {
      _restoring = false;
    }

    _attachListeners();
    _log.i(
      'AppSettingsService: restored preferences',
      context: {
        'volume': data.volume,
        'rate': data.playbackRate,
        'resumeEnabled': data.resumeEnabled,
      },
    );
  }

  // ============================================================
  // 设置入口 (UI 调用)
  // ============================================================

  /// 设置断点续播开关 — 立即落盘 (低频, 无需防抖).
  void setResumeEnabled(bool v) {
    if (_disposed) return;
    resumeEnabled.value = v;
    unawaited(store.saveResumeEnabled(v));
  }

  /// 设置音频延迟 (毫秒) — 引擎生效 + 落盘.
  void setAudioDelayMs(int ms) {
    if (_disposed) return;
    _audioDelayMs = ms;
    engine.setAudioDelay(ms);
    unawaited(store.saveAudioDelayMs(ms));
  }

  /// 设置字幕延迟 (毫秒) — 引擎生效 + 落盘.
  void setSubtitleDelayMs(int ms) {
    if (_disposed) return;
    _subtitleDelayMs = ms;
    engine.setSubtitleDelay(ms);
    unawaited(store.saveSubtitleDelayMs(ms));
  }

  /// 设置硬解开关 — 引擎生效 + 落盘.
  void setHardwareDecoding(bool v) {
    if (_disposed) return;
    hardwareDecoding.value = v;
    engine.setHardwareDecoding(v);
    unawaited(store.saveHardwareDecoding(v));
  }

  // ============================================================
  // 变更监听 → 防抖写回
  // ============================================================

  /// 引擎/服务 notifier 监听挂载 — 回放完成后调用.
  ///
  /// UI 对引擎标量的任何变更 (音量滑条/倍速菜单/静音键) 经此自动持久化;
  /// 引擎不依赖存储, 持久化关注点完全在本层.
  void _attachListeners() {
    engine.volume.addListener(_onEngineVolume);
    engine.isMuted.addListener(_onEngineMuted);
    engine.playbackSpeed.addListener(_onEngineRate);
    videoProcessing.state.addListener(_onVideoState);
  }

  void _onEngineVolume() {
    if (_restoring || _disposed) return;
    pendingVolume = engine.volume.value;
    pendingMuted = engine.isMuted.value; // 同快照写, 音量/静音一致
    volumeTimer?.cancel();
    volumeTimer = Timer(engineWriteDebounce, () {
      final volume = pendingVolume;
      final muted = pendingMuted;
      if (volume == null) return;
      pendingVolume = null;
      unawaited(store.saveVolume(volume));
      if (muted != null) unawaited(store.saveMuted(muted));
    });
  }

  void _onEngineMuted() => _onEngineVolume(); // 同快照策略

  void _onEngineRate() {
    if (_restoring || _disposed) return;
    pendingRate = engine.playbackSpeed.value;
    rateTimer?.cancel();
    rateTimer = Timer(engineWriteDebounce, () {
      final rate = pendingRate;
      if (rate == null) return;
      pendingRate = null;
      unawaited(store.savePlaybackRate(rate));
    });
  }

  void _onVideoState() {
    if (_restoring || _disposed) return;
    pendingVideo = videoProcessing.state.value;
    videoTimer?.cancel();
    videoTimer = Timer(videoWriteDebounce, () {
      final video = pendingVideo;
      if (video == null) return;
      pendingVideo = null;
      unawaited(store.saveVideo(video));
    });
  }

  // ============================================================
  // 生命周期
  // ============================================================

  /// 释放 — 解监听 + 取消防抖定时器 + flush 未落盘的待写值.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    engine.volume.removeListener(_onEngineVolume);
    engine.isMuted.removeListener(_onEngineMuted);
    engine.playbackSpeed.removeListener(_onEngineRate);
    videoProcessing.state.removeListener(_onVideoState);
    volumeTimer?.cancel();
    rateTimer?.cancel();
    videoTimer?.cancel();
    // flush — 未落盘的防抖待写值立即写入 (窗口关闭时不再有 Timer 回调).
    final volume = pendingVolume;
    if (volume != null) {
      unawaited(store.saveVolume(volume));
      final muted = pendingMuted;
      if (muted != null) unawaited(store.saveMuted(muted));
    }
    final rate = pendingRate;
    if (rate != null) unawaited(store.savePlaybackRate(rate));
    final video = pendingVideo;
    if (video != null) unawaited(store.saveVideo(video));
    resumeEnabled.dispose();
    hardwareDecoding.dispose();
  }
}
