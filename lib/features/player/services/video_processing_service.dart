import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../kernel/engine/media_engine.dart';
import '../../../kernel/models/aspect_ratio_mode.dart';
import '../../../kernel/models/video_effect_type.dart';
import '../../../kernel/persistence/settings_store.dart';
import '../models/video_processing_state.dart';

/// 视频处理服务 — 单个 ValueNotifier 持有完整不可变状态
///
/// UI 通过 `ValueListenableBuilder<VideoProcessingState>` 监听。
/// 每个属性一个 `update*` 方法，内部 `copyWith` 生成新状态。
/// 50ms 防抖自动持久化到 SettingsStore。
class VideoProcessingService {
  VideoProcessingService(this._engine, {AppSettings? initialSettings}) {
    state = ValueNotifier<VideoProcessingState>(
      _fromSettings(initialSettings),
    );
    state.addListener(_syncEngine);
    state.addListener(_schedulePersist);
  }

  final MediaEngine _engine;
  bool _disposed = false;
  Timer? _persistDebounce;

  /// 完整视频处理状态（UI 绑定入口）
  late final ValueNotifier<VideoProcessingState> state;

  // ── 更新方法 — copyWith 生成新状态 ──

  void updateBrightness(double v) =>
      state.value = state.value.copyWith(brightness: v);

  void updateContrast(double v) =>
      state.value = state.value.copyWith(contrast: v);

  void updateSaturation(double v) =>
      state.value = state.value.copyWith(saturation: v);

  void updateHue(double v) => state.value = state.value.copyWith(hue: v);

  void updateDeinterlace(bool v) =>
      state.value = state.value.copyWith(deinterlaceEnabled: v);

  void updateRotation(int v) =>
      state.value = state.value.copyWith(rotation: v);

  void updateAspectRatio(AspectRatioMode v) =>
      state.value = state.value.copyWith(aspectRatioMode: v);

  /// 重置所有视频处理状态到默认值
  void resetAll() => state.value = VideoProcessingState.defaults;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _persistDebounce?.cancel();
    state.removeListener(_syncEngine);
    state.removeListener(_schedulePersist);
    state.dispose();
  }

  // ── 内部 ──

  /// 状态变化 → 委托给 MediaEngine
  void _syncEngine() {
    final s = state.value;
    _engine.setVideoEffect(VideoEffectType.brightness, s.brightness);
    _engine.setVideoEffect(VideoEffectType.contrast, s.contrast);
    _engine.setVideoEffect(VideoEffectType.saturation, s.saturation);
    _engine.setVideoEffect(VideoEffectType.hue, s.hue);
    _engine.setDeinterlace(s.deinterlaceEnabled);
    _engine.rotate(s.rotation);
    _engine.setAspectRatio(s.aspectRatioMode.mdkValue);
  }

  /// 50ms 防抖持久化
  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 50), _persistAll);
  }

  void _persistAll() {
    if (_disposed) return;
    final s = state.value;
    SettingsStore.saveVideoBrightness(s.brightness);
    SettingsStore.saveVideoContrast(s.contrast);
    SettingsStore.saveVideoSaturation(s.saturation);
    SettingsStore.saveVideoHue(s.hue);
    SettingsStore.saveVideoRotation(s.rotation);
    SettingsStore.saveVideoAspectRatioIndex(s.aspectRatioMode.index);
    SettingsStore.saveVideoDeinterlace(s.deinterlaceEnabled);
  }

  /// 从持久化设置恢复状态
  static VideoProcessingState _fromSettings(AppSettings? s) {
    if (s == null) return VideoProcessingState.defaults;
    return VideoProcessingState(
      brightness: s.videoBrightness,
      contrast: s.videoContrast,
      saturation: s.videoSaturation,
      hue: s.videoHue,
      deinterlaceEnabled: s.videoDeinterlace,
      rotation: s.videoRotation,
      aspectRatioMode: AspectRatioMode.values[s.videoAspectRatioIndex.clamp(
        0,
        AspectRatioMode.values.length - 1,
      )],
    );
  }
}
