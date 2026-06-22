import 'package:fvp/mdk.dart' as mdk;

import '../utils/log.dart';

/// Encapsulates subtitle and audio filter configuration for mdk.Player.
///
/// Handles external subtitle loading, subtitle delay, and equalizer filters.
class SubtitleConfigurator {
  SubtitleConfigurator(this._player);

  final mdk.Player _player;

  /// Loads an external subtitle file at [path].
  void setExternalSubtitle(String path) {
    _player.setProperty('subtitle.external', path);
  }

  /// Sets subtitle timing offset in [milliseconds] (positive = delay).
  void setSubtitleDelay(int milliseconds) {
    _player.setProperty('subtitle.delay', milliseconds.toString());
  }

  /// Gets current subtitle delay in milliseconds.
  int getSubtitleDelay() {
    try {
      return int.parse(_player.getProperty('subtitle.delay') ?? '0');
    } on Exception catch (e) {
      log.d('SubtitleConfigurator.getSubtitleDelay parse error: $e');
      return 0;
    }
  }

  /// Sets audio equalizer filter (e.g., 'af=lavfi=[...]').
  void setEqualizer(String afFilter) {
    _player.setProperty('af', afFilter);
  }
}
