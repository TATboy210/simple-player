/// Immutable container for all application settings.
///
/// Persisted via [SettingsStore] and used as the single source of truth for
/// playback, window, subtitle, and video-processing preferences.
///
/// Uses a `_sentinel` pattern for nullable fields in [copyWith] so that
/// `null` can be explicitly passed (e.g. to clear windowX/windowY).
///
// NOTE: `playbackSpeed` is an implicit constructor parameter — it has no
// corresponding `final` field declaration below, relying on the implicit
// this-parameter shorthand. This is intentional but worth noting for
// maintainability.
class AppSettings {
  /// Sentinel object distinguishing "not provided" from explicit `null` in [copyWith].
  static const _sentinel = Object();

  /// Audio volume level. Range: 0.0 (mute) to 100.0 (max).
  final double volume;

  /// Path of the last opened media file. Empty string if none.
  final String lastFile;

  /// Window width in logical pixels.
  final double windowWidth;

  /// Window height in logical pixels.
  final double windowHeight;

  /// Window X position in logical pixels. Null = centered by system.
  final double? windowX;

  /// Window Y position in logical pixels. Null = centered by system.
  final double? windowY;

  /// Whether the window is maximized.
  final bool isMaximized;

  /// Playlist loop mode index. Maps to [PlayMode] enum (0=LoopAll, 1=LoopSingle, 2=Shuffle).
  final int playMode;

  /// Whether audio output is muted.
  final bool isMuted;

  /// Whether the window stays above other windows.
  final bool isAlwaysOnTop;

  /// Whether the window is in fullscreen mode.
  final bool isFullscreen;

  /// Subtitle font size in logical pixels.
  // 17.0: 标准可读字号，1080p 下等效约 17px，参考系统默认字体大小
  final double subtitleFontSize;

  /// Subtitle color preset index. Maps to a predefined color palette.
  final int subtitleColorIndex;

  /// Distance from bottom edge to subtitle text in logical pixels.
  // 80.0: 底部偏移量，刚好避开 64px 高的控制栏 + 16px 间距
  final double subtitleBottomOffset;

  /// Video brightness adjustment. Range: -1.0 to 1.0. 0.0 = no change.
  final double videoBrightness;

  /// Video contrast adjustment. Range: -1.0 to 1.0. 0.0 = no change.
  final double videoContrast;

  /// Video saturation adjustment. Range: -1.0 to 1.0. 0.0 = no change.
  final double videoSaturation;

  /// Video hue adjustment in degrees. Range: -180.0 to 180.0. 0.0 = no change.
  final double videoHue;

  /// Video rotation in degrees. Valid: 0, 90, 180, 270.
  final int videoRotation;

  /// Video aspect ratio mode index. Maps to [AspectRatioMode] enum.
  final int videoAspectRatioIndex;

  /// Whether to enable deinterlacing for interlaced content.
  final bool videoDeinterlace;

  /// 播放速度倍率 — 1.0 为正常速度，MDK 以倍率表示
  final double playbackSpeed;

  /// Whether to enable D3D11 CPU sync. Prevents tearing at the cost of performance.
  final bool d3d11Sync;

  /// Whether to use hardware-accelerated decoding (D3D11/NVDEC).
  final bool hardwareDecoding;

  const AppSettings({
    required this.volume,
    required this.lastFile,
    required this.windowWidth,
    required this.windowHeight,
    this.windowX,
    this.windowY,
    this.isMaximized = false,
    required this.playMode,
    required this.isMuted,
    this.isAlwaysOnTop = false,
    this.isFullscreen = false,
    this.subtitleFontSize = 17.0,
    this.subtitleColorIndex = 0,
    this.subtitleBottomOffset = 80.0,
    this.videoBrightness = 0.0,
    this.videoContrast = 0.0,
    this.videoSaturation = 0.0,
    this.videoHue = 0.0,
    this.videoRotation = 0,
    this.videoAspectRatioIndex = 0,
    this.videoDeinterlace = false,
    // 1.0: 正常播放速度，MDK 以倍率表示
    this.playbackSpeed = 1.0,
    this.d3d11Sync = true,
    this.hardwareDecoding = true,
  });

  AppSettings copyWith({
    double? volume,
    String? lastFile,
    double? windowWidth,
    double? windowHeight,
    Object? windowX = _sentinel,
    Object? windowY = _sentinel,
    bool? isMaximized,
    int? playMode,
    bool? isMuted,
    bool? isAlwaysOnTop,
    bool? isFullscreen,
    double? subtitleFontSize,
    int? subtitleColorIndex,
    double? subtitleBottomOffset,
    double? videoBrightness,
    double? videoContrast,
    double? videoSaturation,
    double? videoHue,
    int? videoRotation,
    int? videoAspectRatioIndex,
    bool? videoDeinterlace,
    double? playbackSpeed,
    bool? d3d11Sync,
    bool? hardwareDecoding,
  }) {
    return AppSettings(
      volume: volume ?? this.volume,
      lastFile: lastFile ?? this.lastFile,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      windowX: windowX == _sentinel ? this.windowX : windowX as double?,
      windowY: windowY == _sentinel ? this.windowY : windowY as double?,
      isMaximized: isMaximized ?? this.isMaximized,
      playMode: playMode ?? this.playMode,
      isMuted: isMuted ?? this.isMuted,
      isAlwaysOnTop: isAlwaysOnTop ?? this.isAlwaysOnTop,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleColorIndex: subtitleColorIndex ?? this.subtitleColorIndex,
      subtitleBottomOffset:
          subtitleBottomOffset ?? this.subtitleBottomOffset,
      videoBrightness: videoBrightness ?? this.videoBrightness,
      videoContrast: videoContrast ?? this.videoContrast,
      videoSaturation: videoSaturation ?? this.videoSaturation,
      videoHue: videoHue ?? this.videoHue,
      videoRotation: videoRotation ?? this.videoRotation,
      videoAspectRatioIndex:
          videoAspectRatioIndex ?? this.videoAspectRatioIndex,
      videoDeinterlace: videoDeinterlace ?? this.videoDeinterlace,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      d3d11Sync: d3d11Sync ?? this.d3d11Sync,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          volume == other.volume &&
          lastFile == other.lastFile &&
          windowWidth == other.windowWidth &&
          windowHeight == other.windowHeight &&
          windowX == other.windowX &&
          windowY == other.windowY &&
          isMaximized == other.isMaximized &&
          playMode == other.playMode &&
          isMuted == other.isMuted &&
          isAlwaysOnTop == other.isAlwaysOnTop &&
          isFullscreen == other.isFullscreen &&
          subtitleFontSize == other.subtitleFontSize &&
          subtitleColorIndex == other.subtitleColorIndex &&
          subtitleBottomOffset == other.subtitleBottomOffset &&
          videoBrightness == other.videoBrightness &&
          videoContrast == other.videoContrast &&
          videoSaturation == other.videoSaturation &&
          videoHue == other.videoHue &&
          videoRotation == other.videoRotation &&
          videoAspectRatioIndex == other.videoAspectRatioIndex &&
          videoDeinterlace == other.videoDeinterlace &&
          playbackSpeed == other.playbackSpeed &&
          d3d11Sync == other.d3d11Sync &&
          hardwareDecoding == other.hardwareDecoding;

  @override
  int get hashCode => Object.hashAll([
    volume,
    lastFile,
    windowWidth,
    windowHeight,
    windowX,
    windowY,
    isMaximized,
    playMode,
    isMuted,
    isAlwaysOnTop,
    isFullscreen,
    subtitleFontSize,
    subtitleColorIndex,
    subtitleBottomOffset,
    videoBrightness,
    videoContrast,
    videoSaturation,
    videoHue,
    videoRotation,
    videoAspectRatioIndex,
    videoDeinterlace,
    playbackSpeed,
    d3d11Sync,
    hardwareDecoding,
  ]);
}
