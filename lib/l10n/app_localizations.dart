import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application title shown in title bar and taskbar
  ///
  /// In en, this message translates to:
  /// **'Simple Player'**
  String get appTitle;

  /// Brand name displayed on empty state screen with wide letter spacing
  ///
  /// In en, this message translates to:
  /// **'S I M P L E   P L A Y E R'**
  String get brandName;

  /// Subtitle text below brand name on empty state
  ///
  /// In en, this message translates to:
  /// **'Immersive Audiovisual Experience'**
  String get emptyStateSubtitle;

  /// Button label to open a file
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get openFile;

  /// Tooltip for open file button showing keyboard shortcut
  ///
  /// In en, this message translates to:
  /// **'Open File (O)'**
  String get openFileTooltip;

  /// Hint shown while dragging a file over the window
  ///
  /// In en, this message translates to:
  /// **'Drop video here to play'**
  String get dragHint;

  /// Play mode: play tracks in order and loop
  ///
  /// In en, this message translates to:
  /// **'Sequential'**
  String get playModeLoopAll;

  /// Play mode: loop current track
  ///
  /// In en, this message translates to:
  /// **'Loop Single'**
  String get playModeLoopSingle;

  /// Play mode: random order
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playModeShuffle;

  /// Keyboard shortcut description for Space key
  ///
  /// In en, this message translates to:
  /// **'Play / Pause'**
  String get shortcutPlayPause;

  /// Keyboard shortcut description for arrow keys
  ///
  /// In en, this message translates to:
  /// **'Seek -/+ 5 seconds'**
  String get shortcutSeek;

  /// Keyboard shortcut description for up/down arrows
  ///
  /// In en, this message translates to:
  /// **'Volume +/- 5%'**
  String get shortcutVolume;

  /// Keyboard shortcut description for F key
  ///
  /// In en, this message translates to:
  /// **'Toggle Fullscreen'**
  String get shortcutFullscreen;

  /// Keyboard shortcut description for ESC key
  ///
  /// In en, this message translates to:
  /// **'Exit Fullscreen'**
  String get shortcutExitFullscreen;

  /// Keyboard shortcut description for M key
  ///
  /// In en, this message translates to:
  /// **'Toggle Mute'**
  String get shortcutMute;

  /// Keyboard shortcut description for N key
  ///
  /// In en, this message translates to:
  /// **'Next Track'**
  String get shortcutNext;

  /// Keyboard shortcut description for P key
  ///
  /// In en, this message translates to:
  /// **'Previous Track'**
  String get shortcutPrevious;

  /// Keyboard shortcut description for O key
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get shortcutOpenFile;

  /// Keyboard shortcut description for S key
  ///
  /// In en, this message translates to:
  /// **'Toggle Subtitle'**
  String get shortcutSubtitle;

  /// Keyboard shortcut description for bracket keys
  ///
  /// In en, this message translates to:
  /// **'Subtitle Delay +/- 500ms'**
  String get shortcutSubtitleDelay;

  /// Keyboard shortcut description for F1 key
  ///
  /// In en, this message translates to:
  /// **'Show Help'**
  String get shortcutHelp;

  /// Keyboard shortcut description for the media play/pause key
  ///
  /// In en, this message translates to:
  /// **'Play/Pause'**
  String get shortcutMediaKeys;

  /// Settings dialog title and tooltip
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// General settings tab label
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalTab;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Theme setting label
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Shortcuts settings tab label
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get shortcutsTab;

  /// About tab label
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTab;

  /// Equalizer tab label in settings
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// Audio track tab label in settings
  ///
  /// In en, this message translates to:
  /// **'Audio Track'**
  String get audioTrack;

  /// Video processing tab label in settings
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoTab;

  /// Shown when no audio tracks are found
  ///
  /// In en, this message translates to:
  /// **'No audio tracks available'**
  String get noAudioTracks;

  /// Shown when video processing service is not available
  ///
  /// In en, this message translates to:
  /// **'Video processing unavailable'**
  String get videoProcessingUnavailable;

  /// Audio track label with index
  ///
  /// In en, this message translates to:
  /// **'Track {index}'**
  String audioTrackN(int index);

  /// Equalizer preset: disabled
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get eqOff;

  /// Equalizer preset: bass boost
  ///
  /// In en, this message translates to:
  /// **'Bass Boost'**
  String get eqBassBoost;

  /// Equalizer preset: vocal boost
  ///
  /// In en, this message translates to:
  /// **'Vocal Boost'**
  String get eqVocalBoost;

  /// Equalizer preset: rock
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get eqRock;

  /// Equalizer preset: classical
  ///
  /// In en, this message translates to:
  /// **'Classical'**
  String get eqClassical;

  /// Section header for color correction controls
  ///
  /// In en, this message translates to:
  /// **'Color Correction'**
  String get colorCorrection;

  /// Slider label for brightness adjustment
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// Slider label for contrast adjustment
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// Slider label for saturation adjustment
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// Slider label for hue adjustment
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// Section header for rotation controls
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get rotation;

  /// Section header for aspect ratio selector
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio'**
  String get aspectRatio;

  /// Section header for deinterlace toggle
  ///
  /// In en, this message translates to:
  /// **'Deinterlace'**
  String get deinterlace;

  /// Button to reset all video processing settings
  ///
  /// In en, this message translates to:
  /// **'Reset All'**
  String get resetAll;

  /// Toggle label for deinterlace
  ///
  /// In en, this message translates to:
  /// **'Enable Deinterlace'**
  String get enableDeinterlace;

  /// Hint that deinterlace only works with software decoder
  ///
  /// In en, this message translates to:
  /// **'Software decoder only'**
  String get softwareDecoderOnly;

  /// Tab label for video processing settings
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoProcessing;

  /// Title of keyboard shortcuts help dialog
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortcutsHelpTitle;

  /// Close button text in dialogs
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Tooltip for previous track button
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousTrack;

  /// Tooltip for next track button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextTrack;

  /// Tooltip for playlist toggle button
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// Tooltip for fullscreen button
  ///
  /// In en, this message translates to:
  /// **'Fullscreen (F)'**
  String get fullscreen;

  /// Tooltip for exit fullscreen button
  ///
  /// In en, this message translates to:
  /// **'Exit Fullscreen (F)'**
  String get exitFullscreen;

  /// Tooltip for subtitle import button
  ///
  /// In en, this message translates to:
  /// **'Open Subtitle'**
  String get openSubtitle;

  /// Tooltip for play button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Tooltip for pause button
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Tooltip for stop button
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Tooltip for rewind 10 seconds button
  ///
  /// In en, this message translates to:
  /// **'Rewind 10s'**
  String get rewind10;

  /// Tooltip for forward 30 seconds button
  ///
  /// In en, this message translates to:
  /// **'Forward 30s'**
  String get forward30;

  /// Tooltip for pin window button
  ///
  /// In en, this message translates to:
  /// **'Pin on Top'**
  String get pin;

  /// Tooltip for unpin window button
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// Tooltip for minimize button
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// Tooltip for maximize button
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// Tooltip for restore down button
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// Shown when playlist has no items
  ///
  /// In en, this message translates to:
  /// **'Playlist is empty'**
  String get playlistEmpty;

  /// Shown when playback history is empty
  ///
  /// In en, this message translates to:
  /// **'No playback history'**
  String get noHistory;

  /// Tab label for playlist
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlistTab;

  /// Tab label for playback history
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// Tooltip for clear playlist button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Context menu item to play selected item
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playAction;

  /// Context menu item to copy file path
  ///
  /// In en, this message translates to:
  /// **'Copy Path'**
  String get copyPath;

  /// Context menu item and dialog title for file properties
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// Context menu item to remove from playlist
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Snackbar message after copying path
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get pathCopied;

  /// Subtitle showing breakpoint time in playlist item
  ///
  /// In en, this message translates to:
  /// **'Breakpoint {time}'**
  String breakpointAt(String time);

  /// Tooltip showing last played position
  ///
  /// In en, this message translates to:
  /// **'Last played to {time}'**
  String lastPlayedAt(String time);

  /// Relative time: less than 1 minute ago
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Relative time: N minutes ago
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minutesAgo(int minutes);

  /// Relative time: N hours ago
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String hoursAgo(int hours);

  /// Relative time: N days ago
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(int days);

  /// Title of media info properties dialog
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get propertiesDialog;

  /// Section header for file info
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileSection;

  /// Label for file path row
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get filePath;

  /// Label for file name row
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// Section header for video info
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoSection;

  /// Label for video resolution
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// Label for video/audio codec
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get codec;

  /// Label for pixel aspect ratio
  ///
  /// In en, this message translates to:
  /// **'Pixel Aspect Ratio'**
  String get pixelAspectRatio;

  /// Label for display aspect ratio
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio'**
  String get aspectRatioLabel;

  /// Section header for duration info
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationSection;

  /// Label for total duration row
  ///
  /// In en, this message translates to:
  /// **'Total Duration'**
  String get totalDuration;

  /// Section header for audio info
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioSection;

  /// Label for number of tracks
  ///
  /// In en, this message translates to:
  /// **'Track Count'**
  String get trackCount;

  /// Label for individual track with index
  ///
  /// In en, this message translates to:
  /// **'Track {index}'**
  String trackN(int index);

  /// Section header for subtitle info
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get subtitleSection;

  /// Snackbar message after copying value
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// Tooltip hint for copyable rows
  ///
  /// In en, this message translates to:
  /// **'Double-click to copy'**
  String get doubleClickToCopy;

  /// Fallback text when track info is unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Error banner action: reopen file
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// Error banner action: select a different file
  ///
  /// In en, this message translates to:
  /// **'Select Other File'**
  String get selectOtherFile;

  /// Error banner action: retry operation
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Tooltip for unmute button
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// Tooltip for mute button and OSD message
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// Semantics label for volume slider
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// OSD message showing volume percentage
  ///
  /// In en, this message translates to:
  /// **'Volume {percent}%'**
  String volumePercent(String percent);

  /// Aspect ratio mode: keep original
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get aspectRatioOriginal;

  /// Aspect ratio mode: stretch to fill
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get aspectRatioStretch;

  /// Aspect ratio mode: crop to fill
  ///
  /// In en, this message translates to:
  /// **'Crop Fill'**
  String get aspectRatioCropFill;

  /// Aspect ratio mode: no constraint
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get aspectRatioFree;

  /// Semantics label for playback progress bar
  ///
  /// In en, this message translates to:
  /// **'Playback Progress'**
  String get progressBar;

  /// Tooltip for speed decrease button
  ///
  /// In en, this message translates to:
  /// **'Decrease Speed'**
  String get speedDecrease;

  /// Tooltip for speed label showing reset hint
  ///
  /// In en, this message translates to:
  /// **'Speed (double-click to reset)'**
  String get speedReset;

  /// Tooltip for speed increase button
  ///
  /// In en, this message translates to:
  /// **'Increase Speed'**
  String get speedIncrease;

  /// Tab label for folder scan view in floating playlist
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folderTab;

  /// Context menu item to resume from breakpoint
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeAction;

  /// Context menu item to open containing folder
  ///
  /// In en, this message translates to:
  /// **'Open File Location'**
  String get openFileLocation;

  /// Context menu item to clear all playback history
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// Context menu item to scan folder for other videos
  ///
  /// In en, this message translates to:
  /// **'Scan Folder'**
  String get scanFolder;

  /// Shown when folder scan finds no video files
  ///
  /// In en, this message translates to:
  /// **'No videos in folder'**
  String get noVideosInFolder;

  /// Theme preset: midnight blue
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get themeMidnight;

  /// Theme preset: ocean cyan
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get themeOcean;

  /// Theme preset: forest green
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get themeForest;

  /// Label for app version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Label for technology stack
  ///
  /// In en, this message translates to:
  /// **'Tech Stack'**
  String get techStack;

  /// Button to show open source licenses
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// Copyright/technology description
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter + media_kit (libmpv)'**
  String get copyright;

  /// Button to reset all keyboard shortcuts to defaults
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetShortcuts;

  /// Hint shown when waiting for user to press a key for binding
  ///
  /// In en, this message translates to:
  /// **'Press a key...'**
  String get pressKeyToBind;

  /// Warning when a key is already assigned to another action
  ///
  /// In en, this message translates to:
  /// **'Key already bound'**
  String get shortcutConflict;

  /// Quick menu label for current theme section
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get currentTheme;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Apply button - save without closing
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Error message when deferred player module fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load player module'**
  String get playerLoadError;

  /// Error title when player fails to initialize
  ///
  /// In en, this message translates to:
  /// **'Player initialization failed'**
  String get playerInitFailed;

  /// Performance settings tab label
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performanceTab;

  /// Section header for D3D11 rendering settings
  ///
  /// In en, this message translates to:
  /// **'D3D11 Rendering'**
  String get d3d11Rendering;

  /// Toggle label for D3D11 CPU/GPU synchronization
  ///
  /// In en, this message translates to:
  /// **'D3D11 CPU Sync'**
  String get d3d11Sync;

  /// Description for D3D11 sync toggle
  ///
  /// In en, this message translates to:
  /// **'Synchronize CPU and GPU per frame. Disable for lower latency, may cause tearing.'**
  String get d3d11SyncDesc;

  /// Section header for decoder settings
  ///
  /// In en, this message translates to:
  /// **'Decoder'**
  String get decoderSettings;

  /// Toggle label for hardware decoding
  ///
  /// In en, this message translates to:
  /// **'Hardware Decoding'**
  String get hardwareDecoding;

  /// Description for hardware decoding toggle
  ///
  /// In en, this message translates to:
  /// **'Use GPU for video decoding. Disable if experiencing artifacts.'**
  String get hardwareDecodingDesc;

  /// Hint that performance changes require reopening file
  ///
  /// In en, this message translates to:
  /// **'Changes take effect on next file open.'**
  String get performanceHint;

  /// Button to reset current tab settings to defaults
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get resetToDefaults;

  /// Confirmation dialog title for resetting tab settings
  ///
  /// In en, this message translates to:
  /// **'Reset {tabName} Settings?'**
  String resetConfirmTitle(String tabName);

  /// Confirmation dialog message listing settings to reset
  ///
  /// In en, this message translates to:
  /// **'The following settings will be restored to defaults:'**
  String get resetConfirmMessage;

  /// Confirm button in reset dialog
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get confirmReset;

  /// Button to export settings to JSON file
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportSettings;

  /// Button to import settings from JSON file
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importSettings;

  /// Title of import confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Import Settings?'**
  String get importConfirmTitle;

  /// Message in import confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'The following settings will be overwritten:'**
  String get importConfirmMessage;

  /// Categories that will be overwritten on import
  ///
  /// In en, this message translates to:
  /// **'Playback, Video, Subtitle, Window, Shortcuts, Theme, Language'**
  String get importConfirmCategories;

  /// OSD message after successful import
  ///
  /// In en, this message translates to:
  /// **'Settings imported'**
  String get importSuccess;

  /// Error message when import fails
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importError(String error);

  /// Generic error message when export fails
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportError;

  /// OSD message after successful export
  ///
  /// In en, this message translates to:
  /// **'Settings exported'**
  String get exportSuccess;

  /// Error when imported file contains invalid JSON
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON: {error}'**
  String importParseError(String error);

  /// Error when imported file cannot be read from disk
  ///
  /// In en, this message translates to:
  /// **'Cannot read file: {error}'**
  String importFileReadError(String error);

  /// Accessibility status while media is opening
  ///
  /// In en, this message translates to:
  /// **'Opening media'**
  String get openingMedia;

  /// Accessibility status while media data is buffering
  ///
  /// In en, this message translates to:
  /// **'Buffering media'**
  String get bufferingMedia;

  /// Error message when file path is empty
  ///
  /// In en, this message translates to:
  /// **'File path is empty'**
  String get errorFilePathEmpty;

  /// Error message when file does not exist
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get errorFileNotFound;

  /// Error message for path traversal attempt (security — no details)
  ///
  /// In en, this message translates to:
  /// **'Invalid file path'**
  String get errorFilepathTraversal;

  /// Error message for unsupported media format
  ///
  /// In en, this message translates to:
  /// **'Unsupported media format'**
  String get errorCodecUnsupportedFormat;

  /// Error message when media decoding fails
  ///
  /// In en, this message translates to:
  /// **'Failed to decode media'**
  String get errorCodecDecodeFailed;

  /// Error message when codec is not supported
  ///
  /// In en, this message translates to:
  /// **'Codec not supported'**
  String get errorCodecCodecUnsupported;

  /// Error message when playback fails
  ///
  /// In en, this message translates to:
  /// **'Playback failed'**
  String get errorPlaybackPlayFailed;

  /// Error message when seeking fails
  ///
  /// In en, this message translates to:
  /// **'Seek failed'**
  String get errorPlaybackSeekFailed;

  /// Error message when video texture creation fails
  ///
  /// In en, this message translates to:
  /// **'Video rendering failed'**
  String get errorPlaybackTextureFailed;

  /// Error message when opening media times out
  ///
  /// In en, this message translates to:
  /// **'Open timed out'**
  String get errorPlaybackOpenTimeout;

  /// Error message for network timeout
  ///
  /// In en, this message translates to:
  /// **'Network timeout'**
  String get errorNetworkTimeout;

  /// Error message when network connection is lost
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get errorNetworkConnectionLost;

  /// Error message for unknown/unclassified errors
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get errorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
