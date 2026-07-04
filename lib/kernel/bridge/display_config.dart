import 'package:flutter/foundation.dart';

import '../utils/log.dart';

/// Refresh-rate-aware D3D11 sync mode policy.
///
/// Detects the primary display's refresh rate and derives the optimal
/// `d3d11.sync.cpu` value for the D3D11 rendering backend:
///   - 120Hz+ → `'0'` (async mode, lower latency ~8ms)
///   - <120Hz → `'1'` (sync mode, tear-free rendering)
///
/// The policy result feeds into [D3D11Configurator.applyDefaults], which
/// sets the initial sync mode during player creation. Higher refresh rate
/// displays benefit from async mode because the shorter frame interval
/// reduces visible tearing, while sub-120Hz displays need sync mode to
/// maintain smooth playback.
///
/// Call [init] after the window is ready to detect the actual refresh rate.
/// Before [init], defaults to 60Hz (sync mode) as a safe fallback.
class DisplayConfig {
  DisplayConfig._();

  /// 内部实例 — 持有缓存状态，消除 static mutable state
  static final DisplayConfig _instance = DisplayConfig._();

  // 安全降级 — 未检测时假设 60Hz，选择同步模式（最安全）
  int _cachedHz = 60;
  bool _initialized = false;

  /// 检测并缓存主显示器刷新率。
  ///
  /// 应在窗口就绪后调用（确保 PlatformDispatcher 已初始化）。
  /// 未调用时 [getRefreshRate] 返回安全默认值 60Hz。
  static void init() => _instance._initImpl();

  void _initImpl() {
    if (_initialized) return;
    _initialized = true;
    _cachedHz = _detectRefreshRate();
    logBridge.d('[DisplayConfig] refreshRate=$_cachedHz Hz');
  }

  /// Returns primary display refresh rate (60Hz if [init] not called).
  static int getRefreshRate() => _instance._cachedHz;

  /// Returns d3d11.sync.cpu value based on display refresh rate.
  static String d3d11SyncMode() => syncModeForHz(_instance._cachedHz);

  /// Pure policy: returns '0' (async) for 120Hz+, '1' (sync) otherwise.
  // 120Hz+ 高刷新率 — 异步模式延迟优势明显（~8ms），且高刷显示器通常有更好的驱动支持
  @visibleForTesting
  static String syncModeForHz(int hz) => hz >= 120 ? '0' : '1';

  /// 重置状态（仅测试用）。
  @visibleForTesting
  static void reset() {
    _instance._cachedHz = 60;
    _instance._initialized = false;
  }

  /// Detect refresh rate via PlatformDispatcher. Defaults to 60Hz on failure.
  // Flutter 的 PlatformDispatcher 不直接暴露显示器刷新率，
  // 只能通过物理尺寸推断（不可靠），所以安全降级为 60Hz。
  // TODO: 升级到 Win32 FFI (GetDeviceCaps VREFRESH) 或 display_size 包获取真实刷新率。
  static int _detectRefreshRate() {
    try {
      final display = PlatformDispatcher.instance.views.first;
      final _ = display.physicalSize; // 验证 display 可用
      return 60;
    } catch (e, st) {
      logBridge.e('[DisplayConfig._detectRefreshRate] $e\n$st');
      return 60;
    }
  }
}
