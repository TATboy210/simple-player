import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/models/aspect_ratio_mode.dart';
import '../../../kernel/persistence/settings_store.dart';
import '../models/video_processing_state.dart';

/// 视频处理服务 — 单个 ValueNotifier 持有完整不可变状态
///
/// UI 通过 `ValueListenableBuilder<VideoProcessingState>` 监听。
/// 每个属性一个 `update*` 方法，内部 `copyWith` 生成新状态。
/// 50ms 防抖自动持久化到 SettingsStore。
class VideoProcessingService {
  VideoProcessingService(this._engine, {AppSettings? initialSettings}) {
    final initial = _fromSettings(initialSettings);
    state = ValueNotifier<VideoProcessingState>(initial);
    _previousState = initial;
    state.addListener(_syncEngine);
    state.addListener(_schedulePersist);
  }

  final EngineState _engine;
  bool _disposed = false;
  Timer? _persistDebounce;
  late VideoProcessingState _previousState;

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

  void updateRotation(int v) => state.value = state.value.copyWith(rotation: v);

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

  /// 状态变化 → diff-based 委托给 EngineState（只同步变化的属性）
  void _syncEngine() {
    final next = state.value;
    final patch = _diff(_previousState, next);
    _previousState = next;
    if (!patch.hasAny) return;

    if (patch.brightness) {
      _engine.setVideoEffect(VideoEffectType.brightness, next.brightness);
    }
    if (patch.contrast) {
      _engine.setVideoEffect(VideoEffectType.contrast, next.contrast);
    }
    if (patch.saturation) {
      _engine.setVideoEffect(VideoEffectType.saturation, next.saturation);
    }
    if (patch.hue) {
      _engine.setVideoEffect(VideoEffectType.hue, next.hue);
    }
    if (patch.deinterlaceEnabled) {
      _engine.setDeinterlace(next.deinterlaceEnabled);
    }
    if (patch.rotation) {
      _engine.rotate(next.rotation);
    }
    if (patch.aspectRatioMode) {
      _engine.setAspectRatio(next.aspectRatioMode.mdkValue);
    }
  }

  static VideoProcessingPatch _diff(
    VideoProcessingState prev,
    VideoProcessingState next,
  ) => VideoProcessingPatch(
    brightness: prev.brightness != next.brightness,
    contrast: prev.contrast != next.contrast,
    saturation: prev.saturation != next.saturation,
    hue: prev.hue != next.hue,
    deinterlaceEnabled: prev.deinterlaceEnabled != next.deinterlaceEnabled,
    rotation: prev.rotation != next.rotation,
    aspectRatioMode: prev.aspectRatioMode != next.aspectRatioMode,
  );

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
      aspectRatioMode:
          AspectRatioMode.values[s.videoAspectRatioIndex.clamp(
            0,
            AspectRatioMode.values.length - 1,
          )],
    );
  }
}
