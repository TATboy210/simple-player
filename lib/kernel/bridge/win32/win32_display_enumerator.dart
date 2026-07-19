// Win32 display enumeration via FFI.
//
// Implements DisplayEnumerator using Win32 EnumDisplayMonitors +
// GetMonitorInfoW FFI calls. Coordinates are converted from physical
// pixels to Flutter logical pixels via devicePixelRatio.
//
// Architecture:
// - Win32DisplayEnumerator: static utility class (direct FFI calls)
// - Win32DisplayAdapter: instance wrapper implementing DisplayEnumerator
//   interface for dependency injection into ScreenUtils
import 'dart:ffi';
import 'dart:ui';

import 'package:ffi/ffi.dart';

import '../../diagnostics/kernel_logger.dart';
import '../display_enumerator.dart';

final log = KernelLogger.I;
final logBridge = KernelLogger.I;

// ─── Win32 结构体 ───

final class _RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _MONITORINFO extends Struct {
  @Uint32()
  external int cbSize;
  external _RECT rcMonitor;
  external _RECT rcWork;
  @Uint32()
  external int dwFlags;
}

// ─── Win32 回调类型 ───

typedef _MonitorEnumProcNative = Int32 Function(
    IntPtr hMonitor, IntPtr hdcMonitor, Pointer<_RECT> lprcMonitor, IntPtr dwData);

// ─── Win32 函数签名 ───

typedef _EnumDisplayMonitorsNative = Int32 Function(
    IntPtr hdc, Pointer<NativeType> lprcClip, IntPtr lpfnEnum, IntPtr dwData);
typedef _EnumDisplayMonitorsDart = int Function(
    int hdc, Pointer<NativeType> lprcClip, int lpfnEnum, int dwData);

typedef _GetMonitorInfoWNative = Int32 Function(
    IntPtr hMonitor, Pointer<_MONITORINFO> lpmi);
typedef _GetMonitorInfoWDart = int Function(
    int hMonitor, Pointer<_MONITORINFO> lpmi);

typedef _MonitorFromWindowNative = IntPtr Function(IntPtr hwnd, Uint32 dwFlags);
typedef _MonitorFromWindowDart = int Function(int hwnd, int dwFlags);

typedef _FindWindowNative = IntPtr Function(
    Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
typedef _FindWindowDart = int Function(
    Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);

// ─── Win32 常量 ───

// MONITORINFOF_PRIMARY — dwFlags 标志位，标识主显示器
const int _monitorinfoPrimary = 1;
// MONITOR_DEFAULTTONEAREST — 窗口不在任何显示器上时，返回最近的显示器（多显示器拖拽窗口到边缘场景）
const int _monitorDefaultToNearest = 2;

// ─── DLL 函数查找 ───

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

final _EnumDisplayMonitorsDart _enumDisplayMonitors = _user32
    .lookupFunction<_EnumDisplayMonitorsNative, _EnumDisplayMonitorsDart>(
        'EnumDisplayMonitors');

final _GetMonitorInfoWDart _getMonitorInfoW = _user32
    .lookupFunction<_GetMonitorInfoWNative, _GetMonitorInfoWDart>(
        'GetMonitorInfoW');

final _MonitorFromWindowDart _monitorFromWindow = _user32
    .lookupFunction<_MonitorFromWindowNative, _MonitorFromWindowDart>(
        'MonitorFromWindow');

final _FindWindowDart _findWindow = _user32
    .lookupFunction<_FindWindowNative, _FindWindowDart>('FindWindowW');

// ─── 回调辅助 ───

/// Temporary storage for enumerated monitor handles.
// EnumDisplayMonitors 回调无法返回值，通过全局列表收集句柄，调用后立即清空
final List<int> _collectedMonitors = [];

/// EnumDisplayMonitors 回调 — 收集显示器句柄。
int _monitorEnumCallback(int hMonitor, int hdc, Pointer<_RECT> lprc, int dwData) {
  _collectedMonitors.add(hMonitor);
  return 1; // 继续枚举
}

// ─── 向后兼容别名 ───

/// 向后兼容别名 — 新代码应使用 [DisplayInfo]。
typedef Win32DisplayInfo = DisplayInfo;

/// Win32 显示器枚举器（静态工具类）。
///
/// 注意: 所有方法为 static，不能直接 implements DisplayEnumerator。
/// 使用 [Win32DisplayAdapter] 适配为实例接口。
class Win32DisplayEnumerator {
  Win32DisplayEnumerator._();

  /// 获取所有连接的显示器及其几何信息。
  ///
  /// 返回 Flutter 逻辑像素坐标系下的 [Win32DisplayInfo] 列表。
  /// 失败时返回空列表。
  static List<Win32DisplayInfo> enumerateDisplays() {
    try {
      final dpr = _getDevicePixelRatio();
      _collectedMonitors.clear();

      // isolate-local 回调 — 不跨 isolate 传递，性能最优。
      // EnumDisplayMonitors 回调在同一调用栈执行，无需跨 isolate 通信。
      final callback = NativeCallable<_MonitorEnumProcNative>.isolateLocal(
        _monitorEnumCallback,
        exceptionalReturn: 0,
      );

      _enumDisplayMonitors(0, nullptr, callback.nativeFunction.address, 0);
      callback.close();

      // 从收集的句柄查询详细信息
      final displays = <Win32DisplayInfo>[];
      for (final hMonitor in _collectedMonitors) {
        final info = _queryMonitorInfo(hMonitor, dpr);
        if (info != null) {
          displays.add(info);
        }
      }
      _collectedMonitors.clear();

      return displays;
    } catch (e, st) {
      logBridge.e('[Win32DisplayEnumerator.enumerateDisplays] $e\n$st');
      return [];
    }
  }

  /// 获取包含指定窗口句柄的显示器信息。
  ///
  /// 若窗口不在任何显示器上，返回最近的显示器。
  /// 失败时返回 null。
  static Win32DisplayInfo? getDisplayForWindow(int hwnd) {
    try {
      final monitor = _monitorFromWindow(hwnd, _monitorDefaultToNearest);
      if (monitor == 0) return null;
      return _queryMonitorInfo(monitor, _getDevicePixelRatio());
    } catch (e, st) {
      logBridge.e('[Win32DisplayEnumerator.getDisplayForWindow] $e\n$st');
      return null;
    }
  }

  /// 获取当前 Flutter 窗口所在显示器的信息。
  static Win32DisplayInfo? getCurrentDisplay() {
    try {
      final hwnd = _getFlutterHwnd();
      if (hwnd == 0) return null;
      return getDisplayForWindow(hwnd);
    } catch (e, st) {
      logBridge.e('[Win32DisplayEnumerator.getCurrentDisplay] $e\n$st');
      return null;
    }
  }

  // ─── 内部方法 ───

  /// 查询单个显示器的 MONITORINFO 并转换为 Win32DisplayInfo。
  static Win32DisplayInfo? _queryMonitorInfo(int hMonitor, double dpr) {
    final mi = calloc<_MONITORINFO>();
    try {
      // 必须设置 cbSize — GetMonitorInfoW 用此字段判断结构体版本，不设置会返回 0（失败）
      mi.ref.cbSize = sizeOf<_MONITORINFO>();
      final result = _getMonitorInfoW(hMonitor, mi);
      if (result == 0) return null;

      final rc = mi.ref.rcMonitor;
      final rw = mi.ref.rcWork;
      final isPrimary = (mi.ref.dwFlags & _monitorinfoPrimary) != 0;

      return Win32DisplayInfo(
        bounds: _rectToFlutter(rc, dpr),
        workArea: _rectToFlutter(rw, dpr),
        isPrimary: isPrimary,
      );
    } finally {
      calloc.free(mi);
    }
  }

  /// 将 Win32 RECT 转换为 Flutter 逻辑像素 Rect。
  // Win32 返回物理像素，Flutter 使用逻辑像素 — 除以 devicePixelRatio 转换坐标系
  static Rect _rectToFlutter(_RECT rect, double dpr) {
    return Rect.fromLTRB(
      rect.left / dpr,
      rect.top / dpr,
      rect.right / dpr,
      rect.bottom / dpr,
    );
  }

  /// 获取 devicePixelRatio。
  static double _getDevicePixelRatio() {
    try {
      return PlatformDispatcher.instance.views.first.devicePixelRatio;
    } catch (_) {
      return 1.0;
    }
  }

  /// 查找 Flutter 窗口 HWND。
  // Flutter 窗口类名固定为 FLUTTER_RUNNER_WIN32_WINDOW — 由 Flutter engine 注册
  static int _getFlutterHwnd() {
    final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    try {
      return _findWindow(className, nullptr);
    } finally {
      calloc.free(className);
    }
  }
}

/// Adapter wrapping static [Win32DisplayEnumerator] as [DisplayEnumerator] instance.
///
/// Use this for dependency injection into [ScreenUtils]. The adapter pattern
/// enables testability (mock [DisplayEnumerator] in tests) while keeping
/// the static FFI implementation isolated.
///
/// When to use which:
/// - [Win32DisplayEnumerator]: direct static calls (internal/low-level)
/// - [Win32DisplayAdapter]: DI into [ScreenUtils] (external/high-level)
class Win32DisplayAdapter implements DisplayEnumerator {
  @override
  List<DisplayInfo> enumerateDisplays() =>
      Win32DisplayEnumerator.enumerateDisplays();

  @override
  DisplayInfo? getDisplayForWindow(int hwnd) =>
      Win32DisplayEnumerator.getDisplayForWindow(hwnd);

  @override
  DisplayInfo? getCurrentDisplay() =>
      Win32DisplayEnumerator.getCurrentDisplay();
}
