import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:nativeapi/nativeapi.dart' as na;

import '../bridge/win32/runner_window_handle.dart';
import 'native_window.dart';

/// nativeapi 事件 → [NativeWindowEvent]；无应用语义的事件返回 null。
///
/// 抽成纯函数以便不经 FFI 单测映射关系。
@visibleForTesting
NativeWindowEvent? mapWindowEvent(na.WindowEvent event) => switch (event) {
  na.WindowMaximizedEvent() => const NativeMaximized(),
  na.WindowRestoredEvent() => const NativeRestored(),
  na.WindowMinimizedEvent() => const NativeMinimized(),
  na.WindowResizedEvent() => const NativeResized(),
  na.WindowMovedEvent() => const NativeMoved(),
  na.WindowCloseRequestedEvent(:final request) => NativeCloseRequested(
    request.cancel,
  ),
  // focus/blur/全屏等事件无应用语义（全屏由 setMode 同步驱动）。
  _ => null,
};

// nativeapi 自带 Point/Size/Rectangle，与 dart:ui 同名 — 在此做最小转换，
// 窗口几何全部以逻辑像素进出。
extension on Rect {
  na.Rectangle toNative() =>
      na.Rectangle(x: left, y: top, width: width, height: height);
}

extension on na.Rectangle {
  Rect toRect() => Rect.fromLTWH(x, y, width, height);
}

extension on Size {
  na.Size toNative() => na.Size(width: width, height: height);
}

/// [NativeWindow] 的生产实现 — nativeapi 的 [na.Window]。
///
/// 全项目唯一直接依赖 nativeapi 的文件；其余代码只见 [NativeWindow]。
class NativeapiWindow implements NativeWindow {
  NativeapiWindow._(this._window) {
    // 拖拽流畅度改造·阶段一：默认 **不注册** nativeapi 窗口事件监听 —
    // 每步 WM_WINDOWPOSCHANGED 的事件构建+跨语言投递挤占窗口线程，是边缘
    // 拖拽"内容追边框"的主犯（取证见 docs/audit/resize-drag-ab-2026-11.md）。
    // 会话检测改由 WindowMetricsObserver 喂引擎指标，模式靠现查。
    // SIMPLER_PLAYER_WINDOW_EVENTS=1 恢复旧事件流（A/B 回退开关；阶段二
    // 关闭消息桥落地后移除）。不订阅时原生侧仅剩快照 diff，无 Dart 投递。
    if (legacyEventStreamEnabled) {
      _listenerId = _window.addListener(_forward);
    }
  }

  /// 旧事件流回退开关 — 读一次环境常量（阶段二随 close 桥一起删除）。
  static final bool legacyEventStreamEnabled = Platform.environment.containsKey(
    'SIMPLER_PLAYER_WINDOW_EVENTS',
  );

  /// 绑定当前 runner 窗口。
  ///
  /// Windows 上 `WindowManager.getCurrent()` 走 GetActiveWindow()，窗口隐藏
  /// 或 UI isolate 不在窗口线程时为 null（本应用先隐藏态恢复几何再亮窗），
  /// 因此自行按进程定位 HWND 再包装；其他平台走 WindowManager。
  /// 找不到窗口抛 [StateError]。
  factory NativeapiWindow.bind() {
    final window = _locate();
    if (window == null) {
      throw StateError('window: Flutter host window not found');
    }
    return NativeapiWindow._(window);
  }

  static na.Window? _locate() {
    if (!Platform.isWindows) {
      return na.WindowManager.instance.getCurrent() ??
          na.WindowManager.instance.getAll().firstOrNull;
    }
    final hwnd = findRunnerWindowHandle();
    if (hwnd == 0) return null;
    return na.Window.createWithNativeWindow(
      ffi.Pointer<ffi.Void>.fromAddress(hwnd),
    );
  }

  /// 必须长期持有同一个 [na.Window]：最小尺寸 handler 与其寿命绑定。
  final na.Window _window;

  // 监听器仅在 legacyEventStreamEnabled 时注册；null = 未订阅（默认路径）。
  na.ListenerId? _listenerId;

  /// sync 广播 — 保证 [NativeCloseRequested.cancel] 在原生回调内被调用。
  final StreamController<NativeWindowEvent> _events =
      StreamController<NativeWindowEvent>.broadcast(sync: true);

  void _forward(na.WindowEvent event) {
    // removeListener 之后仍可能有在途的原生回调。
    if (_events.isClosed) return;
    final mapped = mapWindowEvent(event);
    if (mapped != null) _events.add(mapped);
  }

  @override
  Stream<NativeWindowEvent> get events => _events.stream;

  @override
  void show() => _window.show();
  @override
  void hide() => _window.hide();
  @override
  void focus() => _window.focus();

  @override
  void maximize() => _window.maximize();
  @override
  void unmaximize() => _window.unmaximize();
  @override
  void minimize() => _window.minimize();
  @override
  bool get isMaximized => _window.isMaximized;
  @override
  bool get isMinimized => _window.isMinimized;

  @override
  bool get isFullScreen => _window.isFullScreen;
  @override
  set isFullScreen(bool value) => _window.isFullScreen = value;

  @override
  bool get isAlwaysOnTop => _window.isAlwaysOnTop;
  @override
  set isAlwaysOnTop(bool value) => _window.isAlwaysOnTop = value;

  @override
  Rect get bounds => _window.bounds.toRect();
  @override
  set bounds(Rect value) => _window.bounds = value.toNative();

  @override
  void setSize(Size size) => _window.setSize(size.toNative(), false);
  @override
  void center() => _window.center();

  @override
  set minimumSize(Size value) => _window.minimumSize = value.toNative();

  @override
  set hasShadow(bool value) => _window.hasShadow = value;

  @override
  void hideTitleBar() => _window.titleBarStyle = na.TitleBarStyle.hidden;

  @override
  List<Rect> get workAreas => na.DisplayManager.instance
      .getAll()
      .map((display) => display.workArea.toRect())
      .toList(growable: false);

  @override
  void startDragging() => _window.startDragging();

  @override
  void performTitleBarDoubleClick() => _window.performTitleBarDoubleClick();

  @override
  void dispose() {
    if (_events.isClosed) return;
    final listenerId = _listenerId;
    if (listenerId != null) _window.removeListener(listenerId);
    unawaited(_events.close());
  }
}
