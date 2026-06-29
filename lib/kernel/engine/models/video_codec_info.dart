/// 视频编解码信息
class VideoCodecInfo {
  final int width;
  final int height;
  final double par; // pixel aspect ratio
  final String codec;

  const VideoCodecInfo({
    this.width = 0,
    this.height = 0,
    this.par = 1.0,
    this.codec = '',
  });

  /// 含 PAR 修正的宽高比
  double get aspectRatio =>
      (width > 0 && height > 0) ? (width * par) / height : 16 / 9;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoCodecInfo &&
          width == other.width &&
          height == other.height &&
          par == other.par &&
          codec == other.codec;

  @override
  int get hashCode => Object.hash(width, height, par, codec);
}
