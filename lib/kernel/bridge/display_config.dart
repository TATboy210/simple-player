import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../utils/log.dart';
import 'win32_bindings.dart';

/// Refresh-rate-aware D3D11 sync mode policy.
///
/// Detects primary display refresh rate via Win32 EnumDisplaySettings FFI
/// and returns the optimal d3d11.sync.cpu value:
///   - 120Hz+ → '0' (async, lower latency)
///   - <120Hz → '1' (sync, safe default)
///
/// Refresh rate is cached at first call (player creation time).
class DisplayConfig {
  static int? _cachedHz;

  /// Returns primary display refresh rate (cached after first call).
  static int getRefreshRate() => _cachedHz ??= _detectRefreshRate();

  /// Returns d3d11.sync.cpu value based on display refresh rate.
  static String d3d11SyncMode() => syncModeForHz(getRefreshRate());

  /// Pure policy: returns '0' (async) for 120Hz+, '1' (sync) otherwise.
  @visibleForTesting
  static String syncModeForHz(int hz) => hz >= 120 ? '0' : '1';

  /// Clears cached refresh rate (for testing).
  @visibleForTesting
  static void reset() => _cachedHz = null;

  static int _detectRefreshRate() {
    final devMode = calloc<DevMode>();
    try {
      devMode.ref.dmSize = 188;
      final result = win32.enumDisplaySettings(
        nullptr, // primary display
        enumCurrentSettings,
        devMode,
      );
      if (result == 0) {
        log.w('DisplayConfig: EnumDisplaySettings failed, defaulting to 60Hz');
        return 60;
      }
      final hz = devMode.ref.dmDisplayFrequency;
      log.d('DisplayConfig: detected ${hz}Hz refresh rate');
      return hz;
    } on Exception catch (e) {
      log.w('DisplayConfig: refresh rate detection error: $e, defaulting to 60Hz');
      return 60;
    } finally {
      calloc.free(devMode);
    }
  }
}
