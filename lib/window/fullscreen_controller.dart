import 'dart:ffi' hide Size;

import 'package:ffi/ffi.dart';
import 'package:window_manager/window_manager.dart';

import '../kernel/window/aspect_ratio_service.dart';

/// Win32 FFI fullscreen controller — encapsulates all native fullscreen logic.
///
/// Responsibilities:
/// - WS_CAPTION/WS_THICKFRAME style manipulation
/// - Monitor rect query (covers entire screen including taskbar)
/// - SetWindowPos atomic positioning
/// - Windowed geometry cache for restore
///
/// WindowService owns the mutex + state; this class only does native ops.
class FullscreenController {
  FullscreenController._(this._hwnd);

  final int _hwnd;
  double _savedRatio = 0.0;
  RECT? _windowedRect;

  // ─── Win32 FFI (lazy static) ───

  static const _wsThickFrame = 0x00040000;
  static const _wsCaption = 0x00C00000;
  static const _gwlStyle = -16;
  static const _hwndTop = 0;
  static const _swpFrameChanged = 0x0020;
  static const _swpNoOwnerZOrder = 0x0200;
  static const _monitorDefaultToNearest = 2;

  static DynamicLibrary? _user32Lib;
  static DynamicLibrary get _user32 =>
      _user32Lib ??= DynamicLibrary.open('user32.dll');

  static final _getWindowLongPtrW = _user32.lookupFunction<
      IntPtr Function(IntPtr, Int32),
      int Function(int, int)>('GetWindowLongPtrW');

  static final _setWindowLongPtrW = _user32.lookupFunction<
      IntPtr Function(IntPtr, Int32, IntPtr),
      int Function(int, int, int)>('SetWindowLongPtrW');

  static final _getForegroundWindow = _user32.lookupFunction<
      IntPtr Function(),
      int Function()>('GetForegroundWindow');

  static final _monitorFromWindow = _user32.lookupFunction<
      IntPtr Function(IntPtr, Uint32),
      int Function(int, int)>('MonitorFromWindow');

  static final _getMonitorInfoW = _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Void>),
      int Function(int, Pointer<Void>)>('GetMonitorInfoW');

  static final _setWindowPos = _user32.lookupFunction<
      Int32 Function(
          IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
      int Function(int, int, int, int, int, int, int)>('SetWindowPos');

  // ─── Lifecycle ───

  /// Create controller — caches foreground window HWND.
  static FullscreenController init() {
    return FullscreenController._(_getForegroundWindow());
  }

  /// Restore WS_THICKFRAME after setAsFrameless() strips it.
  /// Static — used during WindowService.init() before controller exists.
  static void restoreThickFrame() {
    final hwnd = _getForegroundWindow();
    if (hwnd == 0) return;
    final style = _getWindowLongPtrW(hwnd, _gwlStyle);
    if ((style & _wsThickFrame) == 0) {
      _setWindowLongPtrW(hwnd, _gwlStyle, style | _wsThickFrame);
    }
  }

  // ─── Public API ───

  bool get isActive => _windowedRect != null;

  /// Enter borderless fullscreen covering the entire monitor (including taskbar).
  Future<void> enter() async {
    // Cache aspect ratio
    _savedRatio = AspectRatioService.I.current;
    if (_savedRatio > 0) await AspectRatioService.I.unlock();

    // Cache windowed geometry via window_manager
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    _windowedRect = RECT()
      ..left = position.dx.toInt()
      ..top = position.dy.toInt()
      ..right = position.dx.toInt() + size.width.toInt()
      ..bottom = position.dy.toInt() + size.height.toInt();

    // Strip border styles and cover entire monitor
    _stripCaptionAndThickFrame();
    final monitorRect = _getMonitorRect(_hwnd);
    _setWindowPosAtomic(monitorRect);
  }

  /// Exit fullscreen — restore windowed geometry and styles.
  Future<void> exit() async {
    // Restore resize border
    _restoreThickFrameFor(_hwnd);

    // Restore windowed geometry atomically
    final rect = _windowedRect;
    if (rect != null) {
      _setWindowPosAtomic(rect);
    }

    await windowManager.setHasShadow(true);

    // Restore aspect ratio
    if (_savedRatio > 0) {
      await AspectRatioService.I.setAspectRatio(_savedRatio);
      _savedRatio = 0.0;
    }

    _windowedRect = null;
  }

  /// Rollback on enter failure — restore aspect ratio if it was unlocked.
  void rollbackEnter() {
    if (_savedRatio > 0) {
      AspectRatioService.I.setAspectRatio(_savedRatio);
      _savedRatio = 0.0;
    }
    _windowedRect = null;
  }

  // ─── Private FFI ───

  void _stripCaptionAndThickFrame() {
    final style = _getWindowLongPtrW(_hwnd, _gwlStyle);
    _setWindowLongPtrW(
        _hwnd, _gwlStyle, style & ~(_wsCaption | _wsThickFrame));
  }

  void _restoreThickFrameFor(int hwnd) {
    final style = _getWindowLongPtrW(hwnd, _gwlStyle);
    _setWindowLongPtrW(hwnd, _gwlStyle, style | _wsThickFrame);
  }

  void _setWindowPosAtomic(RECT rect) {
    _setWindowPos(
      _hwnd,
      _hwndTop,
      rect.left,
      rect.top,
      rect.right - rect.left,
      rect.bottom - rect.top,
      _swpFrameChanged | _swpNoOwnerZOrder,
    );
  }

  /// Get the monitor rect covering the entire screen (including taskbar).
  static RECT _getMonitorRect(int hwnd) {
    final monitor = _monitorFromWindow(hwnd, _monitorDefaultToNearest);
    // MONITORINFO: cbSize(4) + rcMonitor(16) + rcWork(16) + dwFlags(4) = 40
    final mi = calloc.allocate<Uint8>(40);
    mi.cast<Uint32>().value = 40;
    final ok = _getMonitorInfoW(monitor, mi.cast());
    if (ok == 0) {
      calloc.free(mi);
      throw Exception('GetMonitorInfoW failed');
    }
    final base = mi.cast<Int32>();
    final rect = RECT()
      ..left = (base + 1).value
      ..top = (base + 2).value
      ..right = (base + 3).value
      ..bottom = (base + 4).value;
    calloc.free(mi);
    return rect;
  }
}

/// Win32 RECT with mutable int fields.
class RECT {
  int left = 0;
  int top = 0;
  int right = 0;
  int bottom = 0;
}
