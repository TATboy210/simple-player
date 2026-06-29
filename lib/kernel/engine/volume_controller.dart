import 'package:flutter/foundation.dart';

import 'player_proxy.dart';

/// Manages volume and mute state for a player.
///
/// Synchronizes player volume/mute with Flutter ValueNotifiers.
/// Handles auto-mute when volume reaches zero.
class VolumeController {
  VolumeController(this._player, {required this.volume, required this.isMuted});

  final PlayerProxy _player;
  final ValueNotifier<double> volume;
  final ValueNotifier<bool> isMuted;

  /// Sets volume [value] (clamped to 0.0–1.0).
  /// Auto-mutes at zero, auto-unmutes when raised from zero.
  void setVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    _player.volume = clamped;
    volume.value = clamped;
    if (clamped == 0 && !isMuted.value) {
      _player.mute = true;
      isMuted.value = true;
    } else if (clamped > 0 && isMuted.value) {
      _player.mute = false;
      isMuted.value = false;
    }
  }

  /// Sets mute state directly.
  void setMute(bool mute) {
    _player.mute = mute;
    isMuted.value = mute;
  }
}
