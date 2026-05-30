import 'dart:ffi';

// ─── FFI type definitions (no side effects at import time) ───

typedef GetWindowLongPtrNative = IntPtr Function(IntPtr, IntPtr);
typedef GetWindowLongPtrDart = int Function(int, int);
typedef SetWindowLongPtrNative = IntPtr Function(IntPtr, IntPtr, IntPtr);
typedef SetWindowLongPtrDart = int Function(int, int, int);
typedef SetWindowPosNative =
    Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32);
typedef SetWindowPosDart = int Function(int, int, int, int, int, int, int);
typedef MonitorFromWindowNative = IntPtr Function(IntPtr, Uint32);
typedef MonitorFromWindowDart = int Function(int, int);
typedef GetMonitorInfoNative = Int32 Function(IntPtr, Pointer);
typedef GetMonitorInfoDart = int Function(int, Pointer);
typedef GetWindowRectNative = Int32 Function(IntPtr, Pointer<Rect>);
typedef GetWindowRectDart = int Function(int, Pointer<Rect>);
typedef DwmExtendFrameIntoClientAreaNative =
    Int32 Function(IntPtr, Pointer<Margins>);
typedef DwmExtendFrameIntoClientAreaDart =
    int Function(int, Pointer<Margins>);

// ─── Win32 constants ───

const gwlStyle = -16;
const wsCaption = 0x00C00000;
const wsPopup = 0x80000000;
const hwndTop = 0;
const swpNoOwnerZOrder = 0x0200;
const swpFrameChanged = 0x0020;
const monitorDefaultToNearest = 2;

// ─── FFI structs ───

final class Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class MonitorInfo extends Struct {
  @Uint32()
  external int cbSize;
  external Rect rcMonitor;
  external Rect rcWork;
  @Uint32()
  external int dwFlags;
}

final class Margins extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int right;
  @Int32()
  external int top;
  @Int32()
  external int bottom;
}

/// Win32 API bindings — lazy singleton to avoid import-time DLL loading.
///
/// All FFI lookups execute on first access, not at import time.
/// This makes importing WindowService safe in test environments.
class Win32Bindings {
  late final DynamicLibrary _user32;
  late final DynamicLibrary _dwmapi;

  late final GetWindowLongPtrDart getWindowLongPtr;
  late final SetWindowLongPtrDart setWindowLongPtr;
  late final SetWindowPosDart setWindowPos;
  late final MonitorFromWindowDart monitorFromWindow;
  late final GetMonitorInfoDart getMonitorInfo;
  late final GetWindowRectDart getWindowRect;
  late final DwmExtendFrameIntoClientAreaDart dwmExtendFrameIntoClientArea;

  Win32Bindings() {
    _user32 = DynamicLibrary.open('user32.dll');
    _dwmapi = DynamicLibrary.open('dwmapi.dll');

    getWindowLongPtr = _user32
        .lookupFunction<GetWindowLongPtrNative, GetWindowLongPtrDart>(
          'GetWindowLongPtrW',
        );
    setWindowLongPtr = _user32
        .lookupFunction<SetWindowLongPtrNative, SetWindowLongPtrDart>(
          'SetWindowLongPtrW',
        );
    setWindowPos = _user32
        .lookupFunction<SetWindowPosNative, SetWindowPosDart>('SetWindowPos');
    monitorFromWindow = _user32
        .lookupFunction<MonitorFromWindowNative, MonitorFromWindowDart>(
          'MonitorFromWindow',
        );
    getMonitorInfo = _user32
        .lookupFunction<GetMonitorInfoNative, GetMonitorInfoDart>(
          'GetMonitorInfoW',
        );
    getWindowRect = _user32
        .lookupFunction<GetWindowRectNative, GetWindowRectDart>(
          'GetWindowRect',
        );
    dwmExtendFrameIntoClientArea = _dwmapi
        .lookupFunction<
          DwmExtendFrameIntoClientAreaNative,
          DwmExtendFrameIntoClientAreaDart
        >('DwmExtendFrameIntoClientArea');
  }
}

/// Lazy-initialized Win32 bindings. First access triggers DLL loading.
final win32 = Win32Bindings();
