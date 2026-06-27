// Win32 显示器枚举 — 获取所有连接的显示器几何信息。
//
// 使用 EnumDisplayMonitors + GetMonitorInfoW FFI 调用，
// 返回 Flutter Rect 坐标系下的显示器 bounds 和 workArea。
import 'dart:ffi';
import 'dart:ui';

import 'package:ffi/ffi.dart';

import '../../utils/log.dart';
import '../display_enumerator.dart';

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

const int _monitorinfoPrimary = 1;
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

/// 临时存储枚举到的显示器句柄（仅在 enumerateDisplays 调用期间有效）。
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

      // 创建回调 — 使用 NativeCallable.isolateLocal 包装静态函数
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
  static int _getFlutterHwnd() {
    final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    try {
      return _findWindow(className, nullptr);
    } finally {
      calloc.free(className);
    }
  }
}

/// Win32 适配器 — 将静态 [Win32DisplayEnumerator] 包装为 [DisplayEnumerator] 实例。
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
