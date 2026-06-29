import '../bridge/display_config.dart';
import '../utils/log.dart';
import 'player_proxy.dart';

/// Encapsulates D3D11 rendering configuration for a player.
///
/// Controls hardware decoding and CPU-GPU sync settings
/// specific to the Windows D3D11 rendering backend.
class D3D11Configurator {
  D3D11Configurator(this._player);

  final PlayerProxy _player;

  /// Hardware decoder priority chain: D3D11 → NVDEC → FFmpeg fallback.
  /// shader_resource=1 enables GPU colorspace conversion (YUV→RGB),
  /// reducing CPU load.
  static const defaultVideoDecoders = 'D3D11:shader_resource=1,NVDEC,FFmpeg';

  /// FFmpeg soft-decode threads (default=CPU cores 8-16, 2 threads saves
  /// 10-30MB).
  static const _ffmpegDecoderThreads = '2';

  /// Renderer max frame buffer (2 too tight, 3 safer for 1080p).
  static const _maxBufferFrames = '3';

  /// Applies all D3D11 rendering + memory optimization defaults to the player.
  ///
  /// Must be called after player creation but before open().
  /// Sets d3d11.sync.cpu, video.decoders, avcodec.threads,
  /// videoout.buffer_frames, and reader.starts_with_key.
  void applyDefaults() {
    _player.setProperty(
      'd3d11.sync.cpu',
      DisplayConfig.d3d11SyncMode(),
    );
    _player.setProperty('video.decoders', defaultVideoDecoders);
    _player.setProperty('avcodec.threads', _ffmpegDecoderThreads);
    _player.setProperty('videoout.buffer_frames', _maxBufferFrames);
    _player.setProperty('reader.starts_with_key', '1');
    log.d('D3D11Configurator: defaults applied');
  }

  /// Enables/disables D3D11 CPU sync.
  /// - `true`: synchronous (safe default, higher latency)
  /// - `false`: asynchronous (low latency)
  void setSyncEnabled(bool enabled) {
    _player.setProperty('d3d11.sync.cpu', enabled ? '1' : '0');
    log.d('D3D11Configurator: d3d11.sync.cpu = ${enabled ? 1 : 0}');
  }

  /// Switches between hardware and software decoding.
  /// - `true`: hardware decoders (D3D11, NVDEC) with FFmpeg fallback
  /// - `false`: FFmpeg software decoding only
  void setHardwareDecoding(bool enabled) {
    _player.setProperty(
      'video.decoders',
      enabled ? defaultVideoDecoders : 'FFmpeg',
    );
    log.d(
      'D3D11Configurator: video.decoders = ${enabled ? defaultVideoDecoders : "FFmpeg"}',
    );
  }
}
