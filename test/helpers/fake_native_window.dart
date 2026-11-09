import 'dart:async';
import 'dart:ui';

import 'package:simple_player_flutter/kernel/window_bridge/native_window.dart';

/// [NativeWindow] 测试替身 — 手写 fake，无 FFI 依赖。
///
/// 默认命令（maximize/minimize/unmaximize）立即翻转状态并发出对应事件；
/// [deferSettling] 为 true 时只记录调用，状态与事件由测试用 `complete*`
/// 手动推进，用来覆盖「命令投递后异步落定」的真实时序。
class FakeNativeWindow implements NativeWindow {
  final StreamController<NativeWindowEvent> _events =
      StreamController<NativeWindowEvent>.broadcast(sync: true);

  /// 调用流水（按发生顺序），形如 `show`、`maximize`、`bounds=...`。
  final List<String> calls = <String>[];

  bool deferSettling = false;
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

  void emit(NativeWindowEvent event) => _events.add(event);

  /// 发出关闭请求并返回回调内是否**同步**调用了 cancel。
  bool requestClose({bool cancelable = true}) {
    var cancelled = false;
    emit(
      NativeCloseRequested(() {
        cancelled = true;
        return cancelable;
      }),
    );
    return cancelled;
  }

  // 手动推进（配合 deferSettling）。
  void completeMaximize() {
    maximized = true;
    boundsValue = _workArea;
    emit(const NativeMaximized());
  }

  void completeUnmaximize() {
    maximized = false;
    emit(const NativeRestored());
  }

  void completeMinimize() {
    minimized = true;
    emit(const NativeMinimized());
  }

  @override
  Stream<NativeWindowEvent> get events => _events.stream;

  @override
  void show() => calls.add('show');
  @override
  void hide() => calls.add('hide');
  @override
  void focus() => calls.add('focus');

  @override
  void maximize() {
    calls.add('maximize');
    if (!deferSettling) completeMaximize();
  }

  @override
  void unmaximize() {
    calls.add('unmaximize');
    if (!deferSettling) completeUnmaximize();
  }

  @override
  void minimize() {
    calls.add('minimize');
    if (!deferSettling) completeMinimize();
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
  void performTitleBarDoubleClick() => calls.add('titleBarDoubleClick');

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    unawaited(_events.close());
  }
}
