import 'dart:async';
import 'dart:ui';

import 'package:simple_player_flutter/kernel/window_bridge/native_window_host.dart';

/// [NativeWindowHost] 测试替身 — 取代原 window_frame_kit MethodChannel mock。
///
/// Records every port call by name in [calls] (ordering assertions), serves
/// [size] / [position] for geometry reads, and lets tests fail or defer
/// [getSize] and stall [hide]. [emit] pushes platform events as the
/// production host would.
class FakeNativeWindowHost implements NativeWindowHost {
  /// 端口调用记录（方法名，按调用顺序）。
  final List<String> calls = <String>[];

  /// [getSize] 返回值；null 时 [getSize] 抛异常（模拟宿主不可读）。
  Size? size;

  /// [getPosition] 返回值。
  Offset position = Offset.zero;

  /// [isMaximized] 返回值。
  bool maximized = false;

  /// 置位后 [getSize] 抛异常。
  bool failGetSize = false;

  /// 置位后 [getSize] 挂起，completer 依次进入 [pendingSizes]。
  bool deferGetSize = false;
  final List<Completer<Size>> pendingSizes = <Completer<Size>>[];

  /// 非 null 时 [hide] 返回该 future（模拟卡死）。
  Future<void>? hideResult;

  /// 置位后 [attach] 抛异常（模拟找不到宿主窗口）。
  bool failAttach = false;

  /// 最近一次 attach 传入的最小尺寸。
  Size? minimumSize;

  void Function(NativeWindowEvent event)? _onEvent;

  /// 当前是否已 attach 且未 detach。
  bool get isAttached => _onEvent != null;

  /// 投递平台事件（attach 前调用为 no-op）。
  void emit(NativeWindowEvent event) => _onEvent?.call(event);

  @override
  Future<void> attach({
    required Size minimumSize,
    required void Function(NativeWindowEvent event) onEvent,
  }) async {
    calls.add('attach');
    if (failAttach) throw Exception('host window not found');
    this.minimumSize = minimumSize;
    _onEvent = onEvent;
  }

  @override
  void detach() {
    calls.add('detach');
    _onEvent = null;
  }

  @override
  Future<Size> getSize() {
    calls.add('getSize');
    if (failGetSize) return Future<Size>.error(Exception('getSize failed'));
    if (deferGetSize) {
      final pending = Completer<Size>();
      pendingSizes.add(pending);
      return pending.future;
    }
    final current = size;
    if (current == null) {
      return Future<Size>.error(Exception('size unavailable'));
    }
    return Future<Size>.value(current);
  }

  @override
  Future<Offset> getPosition() async {
    calls.add('getPosition');
    return position;
  }

  @override
  Future<bool> isMaximized() async {
    calls.add('isMaximized');
    return maximized;
  }

  @override
  Future<void> setBounds(Rect bounds) async => calls.add('setBounds');

  @override
  Future<void> setSize(Size size) async => calls.add('setSize');

  @override
  Future<void> center() async => calls.add('center');

  @override
  Future<void> setAlwaysOnTop(bool value) async =>
      calls.add('setAlwaysOnTop:$value');

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> hide() {
    calls.add('hide');
    return hideResult ?? Future<void>.value();
  }

  @override
  Future<void> focus() async => calls.add('focus');

  @override
  Future<void> maximize() async => calls.add('maximize');

  @override
  Future<void> unmaximize() async => calls.add('unmaximize');

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> setFullScreen(bool value) async =>
      calls.add('setFullScreen:$value');

  @override
  Future<void> startDragging() async => calls.add('startDragging');

  @override
  Future<void> destroy() async => calls.add('destroy');
}
