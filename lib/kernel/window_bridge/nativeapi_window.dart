import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:nativeapi/nativeapi.dart' as na;

import '../bridge/win32/runner_window_handle.dart';
import 'native_window.dart';

/// [NativeWindow] 的生产实现 — nativeapi 的 [na.Window]，**命令通道**。
///
/// 全项目唯一直接依赖 nativeapi 的文件；其余代码只见 [NativeWindow]。
///
/// 阶段二改造（取证 docs/audit/resize-drag-ab-2026-11.md）：**不注册**事件
/// 监听 — nativeapi 在窗口线程按步构建 Moved/Resized 并跨语言投递，是边缘
/// 拖拽"内容追边框"的主犯。本适配器的职责收缩为：包装 HWND、下发几何/状态
/// 命令；[events] 返回恒定空的流以满足端口形状（[WindowService] 的 _settle
/// 订阅它即得 onDone，落定语义退化为"命令后查询"，nativeapi 命令为同步
/// marshal，实测等价）。几何变化检测走 WindowMetricsObserver（引擎指标），
/// 关门走 CloseNotifierBridge（runner 专线），事件流整体退订。
class NativeapiWindow implements NativeWindow {
  NativeapiWindow._(this._window);

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

  /// 退订事件流后的空实现（见类注释）。const 空流在 listen 时即 done，
  /// 服务侧 _settle 的 onDone 收尾路径已覆盖。
  @override
  Stream<NativeWindowEvent> get events =>
      const Stream<NativeWindowEvent>.empty();

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

  /// 无监听器可摘、无流可关（事件流已退订）；保留方法满足端口契约。
  @override
  void dispose() {}
}

// nativeapi 自带 Point/Size/Rectangle，与 dart:ui 同名 — 在此做最小转换，
// 窗口几何全部以逻辑像素进出（匿名扩展按接收者类型隐式解析）。
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
