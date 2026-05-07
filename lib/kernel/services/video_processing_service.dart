import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/media_engine.dart';
import '../models/aspect_ratio_mode.dart';
import '../models/video_effect_type.dart';
import '../persistence/settings_store.dart';

/// 视频处理服务 — 响应式状态 + 引擎委托
///
/// 持有 7 个 ValueNotifier，监听变化并委托给 MediaEngine。
/// UI 层通过 ValueListenableBuilder 绑定这些 notifier。
/// 可选：传入 AppSettings 从持久化恢复状态，并自动持久化变更。
class VideoProcessingService {
  final MediaEngine _engine;
  bool _disposed = false;
  Timer? _persistDebounce;

  /// 亮度 [-1.0, 1.0]，默认 0.0
  late final ValueNotifier<double> brightness;

  /// 对比度 [-1.0, 1.0]，默认 0.0
  late final ValueNotifier<double> contrast;

  /// 饱和度 [-1.0, 1.0]，默认 0.0
  late final ValueNotifier<double> saturation;

  /// 色调 [-1.0, 1.0]，默认 0.0
  late final ValueNotifier<double> hue;

  /// 去隔行开关，默认 false
  late final ValueNotifier<bool> deinterlaceEnabled;

  /// 旋转角度（0/90/180/270），默认 0
  late final ValueNotifier<int> rotation;

  /// 宽高比模式，默认 keepOriginal
  late final ValueNotifier<AspectRatioMode> aspectRatioMode;

  VideoProcessingService(this._engine, {AppSettings? initialSettings}) {
    final s = initialSettings;
    brightness = ValueNotifier<double>(s?.videoBrightness ?? 0.0);
    contrast = ValueNotifier<double>(s?.videoContrast ?? 0.0);
    saturation = ValueNotifier<double>(s?.videoSaturation ?? 0.0);
    hue = ValueNotifier<double>(s?.videoHue ?? 0.0);
    deinterlaceEnabled = ValueNotifier<bool>(s?.videoDeinterlace ?? false);
    rotation = ValueNotifier<int>(s?.videoRotation ?? 0);
    aspectRatioMode = ValueNotifier<AspectRatioMode>(
      s != null
          ? AspectRatioMode.values[s.videoAspectRatioIndex.clamp(0, AspectRatioMode.values.length - 1)]
          : AspectRatioMode.keepOriginal,
    );

    // 引擎委托
    brightness.addListener(() =>
        _engine.setVideoEffect(VideoEffectType.brightness, brightness.value));
    contrast.addListener(() =>
        _engine.setVideoEffect(VideoEffectType.contrast, contrast.value));
    saturation.addListener(() =>
        _engine.setVideoEffect(VideoEffectType.saturation, saturation.value));
    hue.addListener(() =>
        _engine.setVideoEffect(VideoEffectType.hue, hue.value));
    deinterlaceEnabled.addListener(() =>
        _engine.setDeinterlace(deinterlaceEnabled.value));
    rotation.addListener(() =>
        _engine.rotate(rotation.value));
    aspectRatioMode.addListener(() =>
        _engine.setAspectRatio(aspectRatioMode.value.mdkValue));

    // 持久化监听（50ms 防抖，避免逐像素写磁盘）
    void schedulePersist() {
      _persistDebounce?.cancel();
      _persistDebounce = Timer(const Duration(milliseconds: 50), _persistAll);
    }
    brightness.addListener(schedulePersist);
    contrast.addListener(schedulePersist);
    saturation.addListener(schedulePersist);
    hue.addListener(schedulePersist);
    deinterlaceEnabled.addListener(schedulePersist);
    rotation.addListener(schedulePersist);
    aspectRatioMode.addListener(schedulePersist);
  }

  /// 持久化所有视频处理设置到 SettingsStore
  void _persistAll() {
    if (_disposed) return;
    SettingsStore.saveVideoBrightness(brightness.value);
    SettingsStore.saveVideoContrast(contrast.value);
    SettingsStore.saveVideoSaturation(saturation.value);
    SettingsStore.saveVideoHue(hue.value);
    SettingsStore.saveVideoRotation(rotation.value);
    SettingsStore.saveVideoAspectRatioIndex(aspectRatioMode.value.index);
    SettingsStore.saveVideoDeinterlace(deinterlaceEnabled.value);
  }

  /// 重置所有视频处理状态到默认值
  void resetAll() {
    brightness.value = 0.0;
    contrast.value = 0.0;
    saturation.value = 0.0;
    hue.value = 0.0;
    deinterlaceEnabled.value = false;
    rotation.value = 0;
    aspectRatioMode.value = AspectRatioMode.keepOriginal;
  }

  /// 释放所有 ValueNotifier
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _persistDebounce?.cancel();
    brightness.dispose();
    contrast.dispose();
    saturation.dispose();
    hue.dispose();
    deinterlaceEnabled.dispose();
    rotation.dispose();
    aspectRatioMode.dispose();
  }
}
