/// 应用设置数据容器
class AppSettings {
  static const _sentinel = Object();

  final double volume;
  final String lastFile;
  final double windowWidth;
  final double windowHeight;
  final double? windowX;
  final double? windowY;
  final bool isMaximized;
  final int playMode;
  final bool isMuted;
  final bool isAlwaysOnTop;
  final bool isFullscreen;
  final double subtitleFontSize;
  final int subtitleColorIndex;
  final double subtitleBottomOffset;

  // 视频处理
  final double videoBrightness;
  final double videoContrast;
  final double videoSaturation;
  final double videoHue;
  final int videoRotation;
  final int videoAspectRatioIndex;
  final bool videoDeinterlace;

  // 性能设置
  final bool d3d11Sync;
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
