import 'player_proxy.dart';

/// 网络流配置器 — 为 URL 源设置 FFmpeg 网络参数
///
/// 职责:
///   - 通用网络超时、探测大小、分析时长
///   - 协议特定低延迟配置 (RTSP/RTMP/SRT/UDP/TCP/HTTP)
///
/// 仅对 http/https/rtmp/rtsp 等 URL 生效，本地文件不调用。
class NetworkConfigurator {
  // ─── 常量 ───

  // 10秒超时 — 网络波动容忍阈值，太短会误断，太长用户等太久
  static const _networkTimeoutMs = 10000;
  // 1MB 探测 — 足够识别大多数容器格式和码率，减少首帧延迟
  static const _networkProbeSize = 1000000;
  // 5秒分析 — 平衡流识别准确性和启动速度
  static const _networkAnalyzeDurationUs = 5000000;
  // 500KB RTSP 快速探测 — 实时流需要更小探测以降低延迟
  static const _rtspProbeSize = 500000;

  const NetworkConfigurator._();

  /// 为 URL 源配置 FFmpeg 网络参数
  ///
  /// 设置超时、探测大小、分析时长和协议特定参数。
  /// 仅在 [PathValidator.isUrl] 返回 true 时调用。
  static void configure(MdkPlayerLike player, String url) {
    // 通用网络超时
    player.setProperty('timeout', _networkTimeoutMs.toString());

    // FFmpeg 流探测参数 — 减少首帧延迟
    player.setProperty('avformat.probesize', _networkProbeSize.toString());
    player.setProperty(
      'avformat.analyzeduration',
      _networkAnalyzeDurationUs.toString(),
    );

    // 协议特定配置
    if (url.startsWith('rtsp://')) {
      _configureRtsp(player);
    } else if (url.startsWith('rtmp://')) {
      _configureRtmp(player);
    } else if (url.startsWith('srt://')) {
      _configureSrt(player);
    } else if (url.startsWith('udp://') || url.startsWith('tcp://')) {
      _configureUdpTcp(player);
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      _configureHttp(player);
    }
  }

  /// RTSP 低延迟配置
  static void _configureRtsp(MdkPlayerLike player) {
    player.setProperty('avformat.probesize', _rtspProbeSize.toString());
    player.setProperty('avformat.fflags', '+nobuffer');
    player.setProperty('avformat.fpsprobesize', '0');
    player.setProperty('avformat.avioflags', 'direct');
    player.setBufferRange(min: 0, max: 0, drop: true);
  }

  /// RTMP 低延迟配置（同 RTSP，无 avioflags）
  static void _configureRtmp(MdkPlayerLike player) {
    player.setProperty('avformat.fflags', '+nobuffer');
    player.setProperty('avformat.fpsprobesize', '0');
    player.setBufferRange(min: 0, max: 0, drop: true);
  }

  /// SRT 低延迟配置（同 RTMP）
  static void _configureSrt(MdkPlayerLike player) {
    player.setProperty('avformat.fflags', '+nobuffer');
    player.setProperty('avformat.fpsprobesize', '0');
    player.setBufferRange(min: 0, max: 0, drop: true);
  }

  /// UDP/TCP 实时流低延迟（同 SRT）
  static void _configureUdpTcp(MdkPlayerLike player) {
    player.setProperty('avformat.fflags', '+nobuffer');
    player.setProperty('avformat.fpsprobesize', '0');
    player.setBufferRange(min: 0, max: 0, drop: true);
  }

  /// HTTP/HTTPS 启用解复用缓存（加速 seek）
  static void _configureHttp(MdkPlayerLike player) {
    player.setProperty('demux.buffer.ranges', '1');
  }

  /// 动态缓冲策略 — 根据网络延迟自适应调整缓冲大小
  static void configureAdaptive(
    MdkPlayerLike player,
    String url, {
    int latencyMs = 0,
  }) {
    configure(player, url);
    final bufferSize = latencyMs > 500 ? 5000000 : 1000000;
    player.setProperty('buffer', bufferSize.toString());
  }
}
