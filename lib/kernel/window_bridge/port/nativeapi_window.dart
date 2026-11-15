import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:nativeapi/nativeapi.dart' as na;

import '../platform/window_handle_locator.dart';
import 'native_window.dart';
import 'window_resize_edge.dart';

/// [NativeWindow] 的生产实现 — nativeapi 的 [na.Window]，**纯命令通道**。
///
/// 全项目唯一直接依赖 nativeapi 的文件；其余代码只见 [NativeWindow]。
///
/// 契约 1（CONTRACT.md）：**不注册**任何事件监听 — nativeapi 在窗口线程
/// 按步构建 Moved/Resized 并跨语言投递，是边缘拖拽"内容追边框"的主犯
/// （三平台共有设计，取证 docs/audit/resize-drag-ab-2026-11.md）。
/// 几何变化检测走 WindowMetricsObserver（引擎指标），关门走
/// CloseNotifierBridge（runner 专线），模式落定用现查校准。
class NativeapiWindow implements NativeWindow {
  NativeapiWindow._(this._window);

  /// 绑定当前 runner 窗口。
  ///
  /// 句柄定位 = [WindowHandleLocator] 策略链：runner 导出符号
  /// （SimplerPlayerGetMainWindowHandle，隐藏态可用）优先，平台 fallback
  /// 兜底（Windows=FindWindowExW 枚举；macOS/Linux=WindowManager
  /// getCurrent/getAll — 注意 getCurrent 在隐藏态/非属主线程可能为 null，
  /// 因此仅作符号缺失时的降级）。找不到窗口抛 [StateError]。
  ///
  /// [locateHandle] 为测试 seam（生产为 null → 默认策略链）。
  factory NativeapiWindow.bind({int? Function()? locateHandle}) {
    final locate =
        locateHandle ??
        WindowHandleLocator(
          defaultHandleStrategies(managerFallback: _managerFallbackHandle),
        ).locate;
    final window = _wrap(locate());
    if (window == null) {
      throw StateError('window: Flutter host window not found');
    }
    return NativeapiWindow._(window);
  }

  static na.Window? _wrap(int? handle) {
    if (handle == null || handle == 0) return null;
    return na.Window.createWithNativeWindow(
      ffi.Pointer<ffi.Void>.fromAddress(handle),
    );
  }

  /// nativeapi WindowManager 兜底 — 返回窗口句柄地址（供 locator 统一
  /// 走 int? 协议）。nativeapi 类型不出本文件。
  static int? _managerFallbackHandle() {
    final manager = na.WindowManager.instance;
    final window = manager.getCurrent() ?? manager.getAll().firstOrNull;
    return window?.nativeNumber;
  }

  /// 必须长期持有同一个 [na.Window]：最小尺寸 handler 与其寿命绑定。
  final na.Window _window;

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
  set minimumSize(Size value) {
    // Windows：走 runner 导出符号 + WM_GETMINMAXINFO，不走 nativeapi 的
    // minimumSize setter — 后者注册 WindowMessageDispatcher handler 时对
    // 宿主窗口做 GWLP_WNDPROC 全量替换（libnativeapi/nativeapi#30 根因 4），
    // 拖拽热路径每条消息都付 dispatcher 互斥锁税。WM_GETMINMAXINFO 是
    // DefWindowProc 的既有查询点，零额外开销。符号缺失（旧 runner 产物）
    // 或平台异常时降级回 nativeapi setter，保底约束不丢。
    // macOS/Linux：dispatcher 不参与 resize 热路径（GTK/AppKit 机制不同），
    // 直接走 nativeapi。
    if (Platform.isWindows && _setRunnerMinSize(value)) return;
    _window.minimumSize = value.toNative();
  }

  /// runner 导出符号 `SimplerPlayerSetMinWindowSize`（flutter_window.cpp，
  /// 与 [WindowHandleLocator] 的 runner 符号同款模式）；查不到返回 false。
  ///
  /// 查找顺序与 [CloseNotifierBridge] 一致：process() 失败再试 executable()
  /// （静态链入 exe 的符号在部分平台只对 executable 作用域可见）。
  static bool _setRunnerMinSize(Size value) {
    for (final lib in _lookupLibraries()) {
      try {
        final setMinSize =
            lib.lookupFunction<
              ffi.Void Function(ffi.Int32, ffi.Int32),
              void Function(int, int)
            >('SimplerPlayerSetMinWindowSize');
        setMinSize(value.width.round(), value.height.round());
        return true;
      } on Object {
        // 换下一个作用域；全部失败由调用方降级到 nativeapi setter。
      }
    }
    return false;
  }

  static List<ffi.DynamicLibrary> _lookupLibraries() {
    try {
      return [ffi.DynamicLibrary.process(), ffi.DynamicLibrary.executable()];
    } on Object {
      return [ffi.DynamicLibrary.executable()];
    }
  }

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
  void startResizing(WindowResizeEdge edge) =>
      _window.startResizing(edge.toNative());

  @override
  void performTitleBarDoubleClick() => _window.performTitleBarDoubleClick();

  /// 无监听器可摘、无流可关（契约 1：零订阅）；保留方法满足端口契约。
  @override
  // ignore: no-empty-block
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

extension on WindowResizeEdge {
  na.ResizeEdge toNative() => switch (this) {
    WindowResizeEdge.top => na.ResizeEdge.top,
    WindowResizeEdge.bottom => na.ResizeEdge.bottom,
    WindowResizeEdge.left => na.ResizeEdge.left,
    WindowResizeEdge.right => na.ResizeEdge.right,
    WindowResizeEdge.topLeft => na.ResizeEdge.topLeft,
    WindowResizeEdge.topRight => na.ResizeEdge.topRight,
    WindowResizeEdge.bottomLeft => na.ResizeEdge.bottomLeft,
    WindowResizeEdge.bottomRight => na.ResizeEdge.bottomRight,
  };
}
