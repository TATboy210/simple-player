/// nativeapi 窗口宿主 — [NativeWindowHost] 的生产实现。
///
/// Production [NativeWindowHost] over `package:nativeapi` 0.5.2 (MIT,
/// libnativeapi). nativeapi is plain Dart FFI over a C++ core that its
/// `cnativeapi` build hook compiles from source (native assets) — no Flutter
/// plugin and no runner code. Two integration facts drive this file:
///
/// 1. **Thread affinity** — nativeapi calls the Win32 API directly on the
///    calling thread and installs its WinEvent hooks there. The Windows
///    runner therefore runs the UI isolate on the platform thread
///    (`UIThreadPolicy::RunOnPlatformThread`, windows/runner/main.cpp);
///    with a separate UI thread no window events would ever be delivered.
/// 2. **Hidden-start lookup** — `WindowManager.getCurrent()` is
///    `GetActiveWindow()` on Windows, null while the runner window is still
///    hidden; Windows resolves the HWND via [findRunnerWindowHandle].
///    macOS (`mainWindow`/first window) and Linux (realized-but-unshown GTK
///    window counts) handle the hidden runner window natively.
///
/// Frame (Windows): `TitleBarStyle.hidden` keeps the native sizing frame
/// (Aero Snap, system resize on all edges; nativeapi answers HTTOP for the
/// top band it gives to the client) and fits a maximized window to the work
/// area. On Windows 10 the compositor frame would leave the accent-coloured
/// top line, so there `hasShadow = false` switches nativeapi to its
/// frameless mode (content covers the window; NCPAINT/NCUAHDRAW* suppressed;
/// all four edges hit-tested at 8px x DPI).
///
/// Close (Windows): nativeapi only treats WM_SYSCOMMAND/SC_CLOSE (✕, Alt+F4,
/// taskbar) as a cancelable close request; a bare WM_CLOSE is "required".
/// The runner re-posts WM_CLOSE as SC_CLOSE (windows/runner/
/// close_bridge_messages.h) so external closes also persist first, and
/// [destroy] marks the window so its own close goes through.
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:nativeapi/nativeapi.dart' as na;

import '../bridge/win32/runner_window_handle.dart';
import '../diagnostics/kernel_logger.dart';
import 'native_window_host.dart';

/// Windows 11 起始内部版本号 — 低于此值的 Windows 10 走无 DWM frame 模式。
const int _windows11Build = 22000;

/// 生产宿主：绑定当前 Flutter runner 窗口。
final class NativeApiWindowHost implements NativeWindowHost {
  na.Window? _window;

  /// Windows runner HWND（其他平台 0）— 关闭放行属性写在其上。
  int _hwnd = 0;
  na.ListenerId? _listenerId;
  void Function(NativeWindowEvent event)? _onEvent;

  /// 自身发起的销毁 — 关闭请求放行, 不再转交服务。
  bool _destroying = false;

  na.Window get _bound {
    final window = _window;
    if (window == null) {
      throw StateError('NativeApiWindowHost used before attach()');
    }
    return window;
  }

  @override
  Future<void> attach({
    required Size minimumSize,
    required void Function(NativeWindowEvent event) onEvent,
  }) async {
    final window = _window ??= _resolveCurrentWindow();
    if (window == null) {
      throw StateError('nativeapi: Flutter host window not found');
    }
    _onEvent = onEvent;
    if (Platform.isWindows) {
      // Win10 去 DWM frame 防主题色顶线 (见库注释); 先于 hidden 设置,
      // 让 nativeapi 只做一次 frame 重算。
      if (_isWindows10()) window.hasShadow = false;
      window.titleBarStyle = na.TitleBarStyle.hidden;
    }
    window.minimumSize = na.Size(
      width: minimumSize.width,
      height: minimumSize.height,
    );
    _listenerId ??= window.addListener(_dispatch);
  }

  na.Window? _resolveCurrentWindow() {
    if (Platform.isWindows) {
      final hwnd = findRunnerWindowHandle();
      if (hwnd == 0) return null;
      _hwnd = hwnd;
      return na.Window.createWithNativeWindow(
        ffi.Pointer<ffi.Void>.fromAddress(hwnd),
      );
    }
    return na.WindowManager.instance.getCurrent() ??
        na.WindowManager.instance.getAll().firstOrNull;
  }

  static bool _isWindows10() {
    // operatingSystemVersion 形如 '"Windows 10 Pro" 10.0 (Build 19045)'。
    final match = RegExp(r'Build (\d+)')
        .firstMatch(Platform.operatingSystemVersion);
    final build = int.tryParse(match?.group(1) ?? '');
    return build != null && build < _windows11Build;
  }

  /// nativeapi 事件 → 端口事件。关闭请求在此同步取消平台默认关闭。
  void _dispatch(na.WindowEvent event) {
    final onEvent = _onEvent;
    final mapped = switch (event) {
      na.WindowMaximizedEvent() => const NativeWindowMaximized(),
      na.WindowRestoredEvent() => const NativeWindowRestored(),
      na.WindowResizedEvent() => const NativeWindowResized(),
      na.WindowFocusedEvent() => const NativeWindowFocused(),
      na.WindowBlurredEvent() => const NativeWindowBlurred(),
      na.WindowCloseRequestedEvent(:final request) => _interceptClose(request),
      _ => null,
    };
    if (mapped != null && onEvent != null) onEvent(mapped);
  }

  NativeWindowEvent? _interceptClose(na.EventRequest request) {
    if (_destroying) return null;
    // 取消默认 DestroyWindow — 服务完成持久化后经 [destroy]/exit 收尾。
    if (!request.cancel()) {
      KernelLogger.I.d(
        '[NativeApiWindowHost] forced close (WM_CLOSE): not cancelable; '
        'runner re-posts SC_CLOSE for the cancelable path',
      );
    }
    return const NativeWindowCloseRequested();
  }

  @override
  void detach() {
    final id = _listenerId;
    if (id != null) _window?.removeListener(id);
    _listenerId = null;
    _onEvent = null;
  }

  @override
  Future<Size> getSize() async {
    final size = _bound.size;
    return Size(size.width, size.height);
  }

  @override
  Future<Offset> getPosition() async {
    final point = _bound.position;
    return Offset(point.x, point.y);
  }

  @override
  Future<bool> isMaximized() async => _bound.isMaximized;

  @override
  Future<void> setBounds(Rect bounds) async {
    _bound.bounds = na.Rectangle(
      x: bounds.left,
      y: bounds.top,
      width: bounds.width,
      height: bounds.height,
    );
  }

  @override
  Future<void> setSize(Size size) async {
    _bound.setSize(na.Size(width: size.width, height: size.height), false);
  }

  @override
  Future<void> center() async => _bound.center();

  @override
  Future<void> setAlwaysOnTop(bool value) async => _bound.isAlwaysOnTop = value;

  @override
  Future<void> show() async => _bound.show();

  @override
  Future<void> hide() async => _bound.hide();

  @override
  Future<void> focus() async => _bound.focus();

  @override
  Future<void> maximize() async => _bound.maximize();

  @override
  Future<void> unmaximize() async => _bound.unmaximize();

  @override
  Future<void> minimize() async => _bound.minimize();

  @override
  Future<void> setFullScreen(bool value) async => _bound.isFullScreen = value;

  @override
  Future<void> startDragging() async => _bound.startDragging();

  @override
  Future<void> destroy() async {
    _destroying = true;
    // runner 把外部 WM_CLOSE 改投 SC_CLOSE 以便拦截; 自身销毁须先放行。
    if (_hwnd != 0) allowRunnerWindowClose(_hwnd);
    _bound.close();
  }
}
