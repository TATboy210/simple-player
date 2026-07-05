/// 模块级概览：视频处理状态 — 不可变值对象与 Diff Patch 模式
///
/// 本文件定义了视频处理的不可变状态模型和差异追踪补丁：
///
/// 1. [VideoProcessingState] — 不可变值对象，包含 7 个视频处理属性
///    - 替代原来 7 个独立 ValueNotifier，通过单个 ValueNotifier 原子更新
///    - UI 通过 `ValueListenableBuilder<VideoProcessingState>` 监听全部属性
///    - 使用 copyWith 模式创建新实例，确保不可变性
///    - 重写 == 和 hashCode 支持相等性比较和 diff 检测
///
/// 2. [VideoProcessingPatch] — 差异追踪补丁，记录两个状态之间哪些字段变化
///    - 用于 VideoProcessingService._syncEngine() 的 diff-based 同步
///    - 只将变化的属性推送给 engine，避免不必要的重复设置
///    - 例如：拖动 brightness 时不会重复设置 contrast/saturation/hue
///
/// 架构位置：VideoProcessingService → **VideoProcessingState** → EngineState
/// 数据流：UI 滑块 → updateBrightness() → copyWith → ValueNotifier → _syncEngine → FvpEngine
library;

import 'package:flutter/foundation.dart';

import '../../../kernel/models/aspect_ratio_mode.dart';

/// 视频处理状态 — 不可变值对象，单个 ValueNotifier 原子更新
///
/// 使用 `@immutable` 注解确保所有字段为 final，通过 copyWith 模式
/// 创建新实例而非修改现有实例。所有 7 个属性都有默认值（0.0/false/0/keepOriginal），
/// 表示"无调整"的初始状态。
///
/// 与 VideoProcessingService 的关系：
/// - VideoProcessingService 持有 `ValueNotifier<VideoProcessingState>`
/// - 每个 update* 方法通过 copyWith 生成新状态并赋值给 ValueNotifier
/// - ValueNotifier 的 listener（_syncEngine）检测变化并同步到 engine
@immutable
class VideoProcessingState {
  const VideoProcessingState({
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.hue = 0.0,
    this.deinterlaceEnabled = false,
    this.rotation = 0,
    this.aspectRatioMode = AspectRatioMode.keepOriginal,
  });

  /// 默认状态（所有属性归零）— 表示"无视频处理调整"
  ///
  /// 使用 static const 确保编译期常量，避免每次 resetAll() 时重新创建。
  /// 零值/baseline 值代表原始视频状态，不应用任何效果。
  static const defaults = VideoProcessingState();

  /// 亮度调整 — 范围 -1.0 到 1.0，0.0 为原始亮度
  final double brightness;

  /// 对比度调整 — 范围 -1.0 到 1.0，0.0 为原始对比度
  final double contrast;

  /// 饱和度调整 — 范围 -1.0 到 1.0，0.0 为原始饱和度
  final double saturation;

  /// 色调调整 — 范围 -1.0 到 1.0，0.0 为原始色调
  final double hue;

  /// 去隔行开关 — true 启用去隔行处理，false 禁用
  ///
  /// 去隔行用于处理隔行扫描的视频源（如 DVD/电视录制），
  /// 将交错的两场合并为完整帧，减少运动画面的梳齿效应。
  final bool deinterlaceEnabled;

  /// 视频旋转角度 — 单位为度（0/90/180/270）
  ///
  /// 使用 int 而非 double，因为 MDK 只支持 90 度倍数的旋转。
  /// 正值为顺时针旋转。
  final int rotation;

  /// 宽高比模式 — 映射到 MDK Player.setAspectRatio() 的浮点值
  ///
  /// 通过 AspectRatioMode 枚举封装 mdk 特殊常量（keepOriginal/stretch/cropFill）
  /// 和标准数学比率（4:3/16:9/21:9），避免在业务层直接使用魔法数字。
  final AspectRatioMode aspectRatioMode;

  /// 创建当前状态的副本，仅更新指定字段
  ///
  /// null 参数表示"保持当前值"，这是 Dart copyWith 模式的标准做法。
  /// 每次调用都会创建新实例，确保不可变性。
  VideoProcessingState copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    bool? deinterlaceEnabled,
    int? rotation,
    AspectRatioMode? aspectRatioMode,
  }) => VideoProcessingState(
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    hue: hue ?? this.hue,
    deinterlaceEnabled: deinterlaceEnabled ?? this.deinterlaceEnabled,
    rotation: rotation ?? this.rotation,
    aspectRatioMode: aspectRatioMode ?? this.aspectRatioMode,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoProcessingState &&
          brightness == other.brightness &&
          contrast == other.contrast &&
          saturation == other.saturation &&
          hue == other.hue &&
          deinterlaceEnabled == other.deinterlaceEnabled &&
          rotation == other.rotation &&
          aspectRatioMode == other.aspectRatioMode;

  /// 哈希码 — 所有 7 个字段参与计算，确保相等性比较的一致性
  ///
  /// Object.hash 是 Dart 推荐的哈希码生成方式，比手动位运算更安全。
  /// 所有字段必须参与，否则两个"逻辑相等"的状态可能产生不同哈希码。
  @override
  int get hashCode => Object.hash(
    brightness,
    contrast,
    saturation,
    hue,
    deinterlaceEnabled,
    rotation,
    aspectRatioMode,
  );
}

/// 视频处理状态差异补丁 — 记录两个状态之间哪些字段发生了变化
///
/// 用于 [VideoProcessingService._syncEngine] 的 diff-based 同步：
/// 比较新旧 [VideoProcessingState]，生成补丁，只将变化的属性推送给 engine。
/// 这避免了不必要的重复设置（例如拖动亮度时不会重复设置对比度/饱和度/色调）。
///
/// 每个 bool 字段为 true 表示对应属性在新旧状态之间发生了变化。
class VideoProcessingPatch {
  const VideoProcessingPatch({
    this.brightness = false,
    this.contrast = false,
    this.saturation = false,
    this.hue = false,
    this.deinterlaceEnabled = false,
    this.rotation = false,
    this.aspectRatioMode = false,
  });

  /// 亮度是否变化
  final bool brightness;

  /// 对比度是否变化
  final bool contrast;

  /// 饱和度是否变化
  final bool saturation;

  /// 色调是否变化
  final bool hue;

  /// 去隔行开关是否变化
  final bool deinterlaceEnabled;

  /// 旋转角度是否变化
  final bool rotation;

  /// 宽高比模式是否变化
  final bool aspectRatioMode;

  /// 是否有任何字段变化 — 快速判断是否需要同步到 engine
  bool get hasAny =>
      brightness ||
      contrast ||
      saturation ||
      hue ||
      deinterlaceEnabled ||
      rotation ||
      aspectRatioMode;

  /// 是否为色彩调整变化 — 亮度/对比度/饱和度/色调中任一变化
  ///
  /// 用于批量处理场景：如果只有色彩调整变化，可以一次性推送
  /// 而非逐个属性推送，减少 engine 调用次数。
  bool get isColorAdjustment => brightness || contrast || saturation || hue;
}
