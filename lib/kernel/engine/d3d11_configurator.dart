import 'package:fvp/mdk.dart' as mdk;

import '../utils/log.dart';

/// Encapsulates D3D11 rendering configuration for mdk.Player.
///
/// Controls hardware decoding and CPU-GPU sync settings
/// specific to the Windows D3D11 rendering backend.
class D3D11Configurator {
  D3D11Configurator(this._player);

  final mdk.Player _player;

  /// Hardware decoder priority chain: D3D11 → NVDEC → FFmpeg fallback.
  static const defaultVideoDecoders = 'D3D11,NVDEC,FFmpeg';

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
