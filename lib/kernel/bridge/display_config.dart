import 'package:flutter/foundation.dart';

import '../utils/log.dart';

/// Refresh-rate-aware D3D11 sync mode policy.
///
/// Returns the optimal d3d11.sync.cpu value based on display refresh rate:
///   - 120Hz+ → '0' (async, lower latency)
///   - <120Hz → '1' (sync, safe default)
///
/// Currently uses a safe 60Hz default. Can be upgraded to detect actual
/// refresh rate via `display_size` package or platform channel later.
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

  /// Detect refresh rate. Defaults to 60Hz (safe fallback).
  static int _detectRefreshRate() {
    logBridge.d('[DisplayConfig] using default 60Hz refresh rate');
    return 60;
  }
}
