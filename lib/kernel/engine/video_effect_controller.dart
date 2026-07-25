import 'package:fvp/mdk.dart' as mdk;
import 'player_proxy.dart';
import 'video_effect_control.dart';
import 'video_effect_type.dart';

import '../diagnostics/kernel_logger.dart';

late final _log = KernelLogger.I;

/// Encapsulates video effect operations: brightness, contrast, hue,
/// saturation, rotation, aspect ratio, and deinterlace.
///
/// Implements [VideoEffectControl] interface — extracted from FvpEngine
/// to isolate video processing concerns.
/// Uses [MdkPlayerLike] for all video property manipulation.
class VideoEffectController implements VideoEffectControl {
  VideoEffectController(this._player);

  final MdkPlayerLike _player;

  /// Sets a video effect (brightness, contrast, hue, saturation).
  /// Value is clamped to [-1.0, 1.0].
  @override
  void setVideoEffect(VideoEffectType effect, double value) {
    final clamped = value.clamp(-1.0, 1.0);
    final mdkEffect = switch (effect) {
      VideoEffectType.brightness => mdk.VideoEffect.brightness,
      VideoEffectType.contrast => mdk.VideoEffect.contrast,
      VideoEffectType.hue => mdk.VideoEffect.hue,
      VideoEffectType.saturation => mdk.VideoEffect.saturation,
    };
    // MDK 要求效果值为单元素数组（mpv 历史 API 设计）
    // MdkPlayerProxy 将 Object? 转为 mdk.VideoEffect；FakeMdkPlayer 忽略
    _player.setVideoEffect(mdkEffect, [clamped]);
  }

  /// Valid rotation degrees accepted by mdk.
  static const validRotationDegrees = {0, 90, 180, 270};

  /// Returns true if [degree] is a valid rotation value.
  static bool isValidRotation(int degree) =>
      validRotationDegrees.contains(degree);

  /// Rotates video by [degree] (must be 0, 90, 180, or 270).
  @override
  void rotate(int degree) {
    if (!isValidRotation(degree)) {
      _log.w('VideoEffectController.rotate invalid: $degree, expected 0/90/180/270');
      return;
    }
    _player.rotate(degree);
  }

  /// Sets video aspect ratio (e.g., 16/9 = 1.778).
  ///
  /// 防御：拒绝 0/负数/NaN/Infinity，防止原生层除零或渲染损坏
  @override
  void setAspectRatio(double ratio) {
    if (ratio <= 0 || ratio.isNaN || ratio.isInfinite) {
      _log.w('setAspectRatio: rejected invalid ratio ($ratio)');
      return;
    }
    _player.setAspectRatio(ratio);
  }

  /// Enables/disables yadif deinterlace filter (software decode only).
  @override
  void setDeinterlace(bool enable) {
    _player.setProperty(
      'video.avfilter',
      enable ? 'yadif=mode=send_frame:deint=all' : '',
    );
  }
}
