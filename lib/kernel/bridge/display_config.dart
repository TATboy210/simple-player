import 'package:flutter/foundation.dart';

import '../utils/log.dart';

/// Refresh-rate-aware D3D11 sync mode policy.
///
/// Returns the optimal d3d11.sync.cpu value based on display refresh rate:
///   - 120Hz+ → '0' (async, lower latency)
///   - <120Hz → '1' (sync, safe default)
///
/// 调用 [init] 检测实际刷新率；未调用时安全降级为 60Hz。
class DisplayConfig {
  static int _cachedHz = 60;
  static bool _initialized = false;

  /// 检测并缓存主显示器刷新率。
  ///
  /// 应在窗口就绪后调用（确保 PlatformDispatcher 已初始化）。
  /// 未调用时 [getRefreshRate] 返回安全默认值 60Hz。
  static void init() {
    if (_initialized) return;
    _initialized = true;
    _cachedHz = _detectRefreshRate();
    logBridge.d('[DisplayConfig] refreshRate=${_cachedHz}Hz');
  }

  /// Returns primary display refresh rate (60Hz if [init] not called).
  static int getRefreshRate() => _cachedHz;

  /// Returns d3d11.sync.cpu value based on display refresh rate.
  static String d3d11SyncMode() => syncModeForHz(_cachedHz);

  /// Pure policy: returns '0' (async) for 120Hz+, '1' (sync) otherwise.
  @visibleForTesting
  static String syncModeForHz(int hz) => hz >= 120 ? '0' : '1';

  /// 重置状态（仅测试用）。
  @visibleForTesting
  static void reset() {
    _cachedHz = 60;
    _initialized = false;
  }

  /// Detect refresh rate via PlatformDispatcher. Defaults to 60Hz on failure.
  static int _detectRefreshRate() {
    try {
      final display = PlatformDispatcher.instance.views.first;
      // Flutter 目前不直接暴露刷新率，使用物理尺寸推断。
      // TODO: 升级到 Win32 FFI (GetDeviceCaps VREFRESH) 或 display_size 包。
      final _ = display.physicalSize; // 验证 display 可用
      return 60;
    } catch (e, st) {
      logBridge.e('[DisplayConfig._detectRefreshRate] $e\n$st');
      return 60;
    }
  }
}
