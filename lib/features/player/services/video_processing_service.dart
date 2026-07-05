/// Services 层视频处理模块 — 不可变状态 + diff 同步 + 防抖持久化
///
/// 本文件实现 [VideoProcessingService] 管理视频处理状态（亮度/对比度/饱和度/
/// 色调/去隔行/旋转/宽高比），使用 copyWith 模式生成不可变状态。
///
/// 架构位置：PlaybackController → **VideoProcessingService** → EngineState（setVideoEffect）
/// 设计模式：
/// - Immutable State：copyWith 生成新状态，不修改原对象
/// - Diff-based Sync：只将变化的属性推送到引擎，避免冗余调用
/// - Debounced Persistence：50ms 防抖批量保存，平衡响应速度和 I/O 效率
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/models/aspect_ratio_mode.dart';
import '../../../kernel/persistence/settings_store.dart';
import '../models/video_processing_state.dart';

/// 视频处理服务 — 单个 ValueNotifier 持有完整不可变状态
///
/// UI 通过 `ValueListenableBuilder<VideoProcessingState>` 监听 [state]。
/// 每个属性一个 `update*` 方法，内部通过 copyWith 生成新状态对象。
/// 状态变化时自动触发两件事：
/// 1. diff-based 同步到引擎（只推送变化的属性）
/// 2. 50ms 防抖持久化到 SettingsStore
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

  /// 上一次同步到引擎的状态 — 用于 diff 比较
  late VideoProcessingState _previousState;

  /// 完整视频处理状态（UI 绑定入口）
  late final ValueNotifier<VideoProcessingState> state;

  // ── 更新方法 — copyWith 生成新状态 ──
  // 每个方法创建新的 VideoProcessingState 实例，不修改原对象（不可变模式）

  /// 更新亮度值（-1.0 ~ 1.0）
  void updateBrightness(double v) =>
      state.value = state.value.copyWith(brightness: v);

  /// 更新对比度值（0.0 ~ 2.0）
  void updateContrast(double v) =>
      state.value = state.value.copyWith(contrast: v);

  /// 更新饱和度值（0.0 ~ 3.0）
  void updateSaturation(double v) =>
      state.value = state.value.copyWith(saturation: v);

  /// 更新色调值（-180.0 ~ 180.0）
  void updateHue(double v) => state.value = state.value.copyWith(hue: v);

  /// 更新去隔行开关
  void updateDeinterlace(bool v) =>
      state.value = state.value.copyWith(deinterlaceEnabled: v);

  /// 更新旋转角度（0/90/180/270）
  void updateRotation(int v) => state.value = state.value.copyWith(rotation: v);

  /// 更新宽高比模式
  void updateAspectRatio(AspectRatioMode v) =>
      state.value = state.value.copyWith(aspectRatioMode: v);

  /// 重置所有视频处理状态到默认值
  void resetAll() => state.value = VideoProcessingState.defaults;

  /// 释放资源 — 取消防抖定时器，注销监听器，释放 ValueNotifier
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _persistDebounce?.cancel();
    state.removeListener(_syncEngine);
    state.removeListener(_schedulePersist);
    state.dispose();
  }

  // ── 内部方法 ──

  /// 状态变化 → diff-based 委托给 EngineState（只同步变化的属性）
  ///
  /// 通过比较前后状态的差异（_diff），只将变化的属性推送到引擎，
  /// 避免每次状态变化都推送所有 7 个属性（减少冗余引擎调用）。
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

  /// 比较前后状态差异，返回哪些属性发生了变化
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

  /// 50ms 防抖持久化 — 滑块拖动时批量保存，避免频繁 I/O
  ///
  /// 每次状态变化重置定时器，50ms 内无新变化才执行保存。
  /// 这个延迟平衡了用户体验（响应速度）和 I/O 效率（避免每帧写磁盘）。
  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 50), _persistAll);
  }

  /// 批量保存所有视频处理设置到 SettingsStore
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
  ///
  /// [s] 为 null 时返回默认值。AspectRatioMode 使用 index clamp 防止越界
  /// （兼容设置文件中存储的旧版本枚举值）。
  static VideoProcessingState _fromSettings(AppSettings? s) {
    if (s == null) return VideoProcessingState.defaults;
    return VideoProcessingState(
      brightness: s.videoBrightness,
      contrast: s.videoContrast,
      saturation: s.videoSaturation,
      hue: s.videoHue,
      deinterlaceEnabled: s.videoDeinterlace,
      rotation: s.videoRotation,
      // clamp 防止旧版本设置文件中存储的枚举索引越界
      aspectRatioMode:
          AspectRatioMode.values[s.videoAspectRatioIndex.clamp(
            0,
            AspectRatioMode.values.length - 1,
          )],
    );
  }
}
