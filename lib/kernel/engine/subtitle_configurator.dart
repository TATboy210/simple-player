import '../utils/log.dart';
import 'player_proxy.dart';

/// Encapsulates subtitle and audio filter configuration for a player.
///
/// Handles external subtitle loading, subtitle delay, and equalizer filters.
class SubtitleConfigurator {
  SubtitleConfigurator(this._player);

  final PlayerProxy _player;

  /// Loads an external subtitle file at [path].
  ///
  /// MDK auto-detects subtitle format (SRT/ASS/SSA/VTT) from file extension
  /// and content sniffing — no need to specify format explicitly.
  void setExternalSubtitle(String path) {
    _player.setProperty('subtitle.external', path);
  }

  /// Sets subtitle timing offset in [milliseconds].
  ///
  /// Positive values delay subtitles (appear later), negative values advance
  /// them (appear earlier) relative to the audio track.
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

  /// Sets audio equalizer filter via FFmpeg filter chain syntax.
  ///
  /// Format: `af=lavfi=[equalizer=f=1000:width_type=h:width=200:g=-10]`
  /// - `af` is the audio filter property (mpv/MDK convention)
  /// - `lavfi` bridges to FFmpeg's libavfilter
  /// - Filter parameters are comma-separated `key=value` pairs inside brackets
  /// - Multiple filters chain with `;` separator
  void setEqualizer(String afFilter) {
    _player.setProperty('af', afFilter);
  }
}
