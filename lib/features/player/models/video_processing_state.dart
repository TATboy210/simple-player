import 'package:flutter/foundation.dart';

import '../../../kernel/models/aspect_ratio_mode.dart';

/// 视频处理状态 — 不可变值对象，单个 ValueNotifier 原子更新
///
/// 替代原来 7 个独立 ValueNotifier，UI 通过一个
/// `ValueListenableBuilder<VideoProcessingState>` 监听全部属性。
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

  /// 默认状态（所有属性归零）
  static const defaults = VideoProcessingState();

  final double brightness;
  final double contrast;
  final double saturation;
  final double hue;
  final bool deinterlaceEnabled;
  final int rotation;
  final AspectRatioMode aspectRatioMode;

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
