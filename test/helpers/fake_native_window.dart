import 'dart:ui';

import 'package:simple_player_flutter/kernel/window_bridge/port/native_window.dart';
import 'package:simple_player_flutter/kernel/window_bridge/port/window_resize_edge.dart';

/// [NativeWindow] 测试替身 — 手写 fake，无 FFI 依赖。
///
/// 纯命令通道（契约 1：端口无事件流）— 命令默认立即翻转同步状态；
/// 「异步落定」时序由测试手动改状态（[completeMaximize] 等）+
/// `noteGeometryChanged()` 模拟（生产 = 引擎指标边沿现查校准）。
class FakeNativeWindow implements NativeWindow {
  /// 调用流水（按发生顺序），形如 `show`、`maximize`、`bounds=...`。
  final List<String> calls = <String>[];

  bool maximized = false;
  bool minimized = false;
  bool fullScreen = false;
  bool alwaysOnTop = false;
  Rect boundsValue = const Rect.fromLTWH(100, 100, 1280, 720);
  List<Rect> workAreasValue = const <Rect>[Rect.fromLTWH(0, 0, 1920, 1040)];
  Object? workAreasError;

  /// 非空时 hideTitleBar 抛出 — 模拟绑定成功后 init 中途失败。
  Object? hideTitleBarError;
  bool? shadowValue;
  Size? minimumSizeValue;

  /// 工作区尺寸 — 模拟最大化时 bounds 贴合工作区。
  Rect get _workArea => workAreasValue.first;

  // 状态推进语法糖（无事件）— 模拟原生侧异步到达目标状态。
  void completeMaximize() {
    maximized = true;
    boundsValue = _workArea;
  }

  void completeUnmaximize() {
    maximized = false;
  }

  void completeMinimize() {
    minimized = true;
  }

  @override
  void show() => calls.add('show');
  @override
  void hide() => calls.add('hide');
  @override
  void focus() => calls.add('focus');

  @override
  void maximize() {
    calls.add('maximize');
    completeMaximize();
  }

  @override
  void unmaximize() {
    calls.add('unmaximize');
    completeUnmaximize();
  }

  @override
  void minimize() {
    calls.add('minimize');
    completeMinimize();
  }

  @override
  bool get isMaximized => maximized;
  @override
  bool get isMinimized => minimized;

  @override
  bool get isFullScreen => fullScreen;
  @override
  set isFullScreen(bool value) {
    calls.add('fullScreen=$value');
    fullScreen = value;
  }

  @override
  bool get isAlwaysOnTop => alwaysOnTop;
  @override
  set isAlwaysOnTop(bool value) {
    calls.add('alwaysOnTop=$value');
    alwaysOnTop = value;
  }

  /// bounds getter 被读取的次数 — 断言热路径同步 FFI 读取被节流。
  int boundsReads = 0;

  @override
  Rect get bounds {
    boundsReads++;
    return boundsValue;
  }

  @override
  set bounds(Rect value) {
    calls.add('bounds=$value');
    boundsValue = value;
  }

  @override
  void setSize(Size size) {
    calls.add('setSize=$size');
    boundsValue = boundsValue.topLeft & size;
  }

  @override
  void center() {
    calls.add('center');
    final area = _workArea;
    boundsValue = Rect.fromLTWH(
      area.left + (area.width - boundsValue.width) / 2,
      area.top + (area.height - boundsValue.height) / 2,
      boundsValue.width,
      boundsValue.height,
    );
  }

  @override
  set minimumSize(Size value) {
    calls.add('minimumSize=$value');
    minimumSizeValue = value;
  }

  @override
  set hasShadow(bool value) {
    calls.add('hasShadow=$value');
    shadowValue = value;
  }

  @override
  void hideTitleBar() {
    final error = hideTitleBarError;
    if (error != null) throw error;
    calls.add('hideTitleBar');
  }

  @override
  List<Rect> get workAreas {
    final error = workAreasError;
    if (error != null) throw error;
    return workAreasValue;
  }

  @override
  void startDragging() => calls.add('startDragging');

  @override
  void startResizing(WindowResizeEdge edge) =>
      calls.add('startResizing=$edge');

  @override
  void performTitleBarDoubleClick() => calls.add('titleBarDoubleClick');

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}
