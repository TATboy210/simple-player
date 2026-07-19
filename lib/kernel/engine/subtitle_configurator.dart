import '../diagnostics/kernel_logger.dart';
import 'models/subtitle_track_info.dart';
import 'player_proxy.dart';
import 'subtitle_config.dart';
import 'subtitle_track_source.dart';

final log = KernelLogger.I;

/// Encapsulates subtitle and audio filter configuration for a player.
///
/// Implements [SubtitleConfig] interface — handles external subtitle loading,
/// subtitle delay, equalizer filters, and delegates track management to
/// [SubtitleTrackSource].
class SubtitleConfigurator implements SubtitleConfig {
  SubtitleConfigurator(this._player, this._trackSource);

  final PlayerProxy _player;
  final SubtitleTrackSource _trackSource;

  // ─── SubtitleConfig: 轨道管理 (delegated to TrackManager) ───

  @override
  List<SubtitleTrackInfo> getSubtitleTracks() =>
      _trackSource.getSubtitleTracks();

  @override
  void switchSubtitleTrack(int trackId) =>
      _trackSource.switchSubtitleTrack(trackId);

  @override
  void toggleSubtitle() => _trackSource.toggleSubtitle();

  @override
  List<int> get activeSubtitleTracks => _trackSource.activeSubtitleTracks;

  // ─── SubtitleConfig: 配置方法 ───

  /// Loads an external subtitle file at [path].
  ///
  /// MDK auto-detects subtitle format (SRT/ASS/SSA/VTT) from file extension
  /// and content sniffing — no need to specify format explicitly.
  @override
  void setExternalSubtitle(String path) {
    _player.setProperty('subtitle.external', path);
  }

  /// Sets subtitle timing offset in [delay] milliseconds.
  ///
  /// Positive values delay subtitles (appear later), negative values advance
  /// them (appear earlier) relative to the audio track.
  @override
  void setSubtitleDelay(int delay) {
    _player.setProperty('subtitle.delay', delay.toString());
  }

  /// Gets current subtitle delay in milliseconds.
  @override
  int get subtitleDelay => getSubtitleDelay();

  /// Gets current subtitle delay in milliseconds.
  /// Internal helper used by [subtitleDelay] getter.
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
  @override
  void setEqualizer(String afFilter) {
    _player.setProperty('af', afFilter);
  }
}
