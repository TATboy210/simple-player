import 'package:fvp/mdk.dart' as mdk;
import 'video_effect_type.dart';

import '../utils/log.dart';

/// Encapsulates video effect operations: brightness, contrast, hue,
/// saturation, rotation, aspect ratio, and deinterlace.
///
/// Extracted from FvpEngine to isolate video processing concerns.
/// Uses mdk.Player directly for all video property manipulation.
class VideoEffectController {
  VideoEffectController(this._player);

  final mdk.Player _player;

  /// Sets a video effect (brightness, contrast, hue, saturation).
  /// Value is clamped to [-1.0, 1.0].
  void setVideoEffect(VideoEffectType effect, double value) {
    final clamped = value.clamp(-1.0, 1.0);
    final mdkEffect = switch (effect) {
      VideoEffectType.brightness => mdk.VideoEffect.brightness,
      VideoEffectType.contrast => mdk.VideoEffect.contrast,
      VideoEffectType.hue => mdk.VideoEffect.hue,
      VideoEffectType.saturation => mdk.VideoEffect.saturation,
    };
    // MDK 要求效果值为单元素数组（mpv 历史 API 设计）
    _player.setVideoEffect(mdkEffect, [clamped]);
  }

  /// Valid rotation degrees accepted by mdk.
  /// MDK only supports 0/90/180/270 — these correspond to hardware rotation
  /// steps (no arbitrary angle support).
  static const validRotationDegrees = {0, 90, 180, 270};

  /// Returns true if [degree] is a valid mdk rotation value.
  static bool isValidRotation(int degree) =>
      validRotationDegrees.contains(degree);

  /// Rotates video by [degree] (must be 0, 90, 180, or 270).
  void rotate(int degree) {
    if (!isValidRotation(degree)) {
      log.w('VideoEffectController.rotate invalid: $degree, expected 0/90/180/270');
      return;
    }
    _player.rotate(degree);
  }

  /// Sets video aspect ratio (e.g., 16/9 = 1.778).
  void setAspectRatio(double ratio) {
    _player.setAspectRatio(ratio);
  }

  /// Enables/disables yadif deinterlace filter (software decode only).
  ///
  /// `yadif` = Yet Another DeInterlacing Filter (FFmpeg).
  /// - `mode=send_frame`: outputs one frame per input (vs `send_field` for half)
  /// - `deint=all`: deinterlaces both fields (vs `interlaced` for interlaced-only)
  void setDeinterlace(bool enable) {
    _player.setProperty(
      'video.avfilter',
      enable ? 'yadif=mode=send_frame:deint=all' : '',
    );
  }
}
