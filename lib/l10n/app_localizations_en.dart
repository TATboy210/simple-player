// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Simple Player';

  @override
  String get brandName => 'S I M P L E   P L A Y E R';

  @override
  String get emptyStateSubtitle => 'Immersive Audiovisual Experience';

  @override
  String get openFile => 'Open File';

  @override
  String get openFileTooltip => 'Open File (O)';

  @override
  String get dragHintIdle => 'Drag and drop a video onto the window to play';

  @override
  String get dragHint => 'Drop video here to play';

  @override
  String get playModeNormal => 'Sequential';

  @override
  String get playModeLoopAll => 'Loop All';

  @override
  String get playModeLoopSingle => 'Loop Single';

  @override
  String get playModeShuffle => 'Shuffle';

  @override
  String get shortcutPlayPause => 'Play / Pause';

  @override
  String get shortcutSeek => 'Seek -/+ 5 seconds';

  @override
  String get shortcutVolume => 'Volume +/- 5%';

  @override
  String get shortcutFullscreen => 'Toggle Fullscreen';

  @override
  String get shortcutExitFullscreen => 'Exit Fullscreen';

  @override
  String get shortcutMute => 'Toggle Mute';

  @override
  String get shortcutNext => 'Next Track';

  @override
  String get shortcutPrevious => 'Previous Track';

  @override
  String get shortcutOpenFile => 'Open File';

  @override
  String get shortcutSubtitle => 'Toggle Subtitle';

  @override
  String get shortcutSubtitleDelay => 'Subtitle Delay +/- 500ms';

  @override
  String get shortcutHelp => 'Show Help';

  @override
  String get shortcutMediaKeys => 'Play/Pause/Prev/Next';

  @override
  String get settings => 'Settings';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get audioTrack => 'Audio Track';

  @override
  String get videoTab => 'Video';

  @override
  String get noAudioTracks => 'No audio tracks available';

  @override
  String get videoProcessingUnavailable => 'Video processing unavailable';

  @override
  String audioTrackN(int index) {
    return 'Track $index';
  }

  @override
  String get eqOff => 'Off';

  @override
  String get eqBassBoost => 'Bass Boost';

  @override
  String get eqVocalBoost => 'Vocal Boost';

  @override
  String get eqRock => 'Rock';

  @override
  String get eqClassical => 'Classical';

  @override
  String get colorCorrection => 'Color Correction';

  @override
  String get brightness => 'Brightness';

  @override
  String get contrast => 'Contrast';

  @override
  String get saturation => 'Saturation';

  @override
  String get hue => 'Hue';

  @override
  String get rotation => 'Rotation';

  @override
  String get aspectRatio => 'Aspect Ratio';

  @override
  String get deinterlace => 'Deinterlace';

  @override
  String get resetAll => 'Reset All';

  @override
  String get enableDeinterlace => 'Enable Deinterlace';

  @override
  String get softwareDecoderOnly => 'Software decoder only';

  @override
  String get videoProcessing => 'Video';

  @override
  String get shortcutsHelpTitle => 'Keyboard Shortcuts';

  @override
  String get close => 'Close';

  @override
  String get previousTrack => 'Previous';

  @override
  String get nextTrack => 'Next';

  @override
  String get playlist => 'Playlist';

  @override
  String get fullscreen => 'Fullscreen (F)';

  @override
  String get exitFullscreen => 'Exit Fullscreen (F)';

  @override
  String get openSubtitle => 'Open Subtitle';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get rewind10 => 'Rewind 10s';

  @override
  String get forward10 => 'Forward 10s';

  @override
  String get pin => 'Pin on Top';

  @override
  String get unpin => 'Unpin';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restore => 'Restore';

  @override
  String get playlistEmpty => 'Playlist is empty';

  @override
  String get noHistory => 'No playback history';

  @override
  String get playlistTab => 'Playlist';

  @override
  String get historyTab => 'History';

  @override
  String get clear => 'Clear';

  @override
  String get playAction => 'Play';

  @override
  String get copyPath => 'Copy Path';

  @override
  String get properties => 'Properties';

  @override
  String get remove => 'Remove';

  @override
  String get pathCopied => 'Path copied';

  @override
  String breakpointAt(String time) {
    return 'Breakpoint $time';
  }

  @override
  String lastPlayedAt(String time) {
    return 'Last played to $time';
  }

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours hr ago';
  }

  @override
  String daysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get propertiesDialog => 'Properties';

  @override
  String get fileSection => 'File';

  @override
  String get filePath => 'Path';

  @override
  String get fileName => 'File Name';

  @override
  String get videoSection => 'Video';

  @override
  String get resolution => 'Resolution';

  @override
  String get codec => 'Codec';

  @override
  String get pixelAspectRatio => 'Pixel Aspect Ratio';

  @override
  String get aspectRatioLabel => 'Aspect Ratio';

  @override
  String get durationSection => 'Duration';

  @override
  String get totalDuration => 'Total Duration';

  @override
  String get audioSection => 'Audio';

  @override
  String get trackCount => 'Track Count';

  @override
  String trackN(int index) {
    return 'Track $index';
  }

  @override
  String get subtitleSection => 'Subtitle';

  @override
  String get copied => 'Copied';

  @override
  String get doubleClickToCopy => 'Double-click to copy';

  @override
  String get unknown => 'Unknown';

  @override
  String get reopen => 'Reopen';

  @override
  String get selectOtherFile => 'Select Other File';

  @override
  String get retry => 'Retry';

  @override
  String get unmute => 'Unmute';

  @override
  String get mute => 'Mute';

  @override
  String get volume => 'Volume';

  @override
  String volumePercent(String percent) {
    return 'Volume $percent%';
  }

  @override
  String speedLabel(num speed) {
    return '${speed}x Speed';
  }

  @override
  String get aspectRatioOriginal => 'Original';

  @override
  String get aspectRatioStretch => 'Stretch';

  @override
  String get aspectRatioCropFill => 'Crop Fill';

  @override
  String get aspectRatioFree => 'Free';

  @override
  String get progressBar => 'Playback Progress';
}
