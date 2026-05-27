import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../kernel/utils/perf_monitor.dart';

/// 窗口瞬态事件类型
enum WindowEventType { resizeStart, resizeEnd, moveStart, moveEnd }

/// 窗口事件（类型 + 时间戳 + 可选尺寸）
class WindowEvent {
  final WindowEventType type;
  final DateTime timestamp;
  final Size? size;
  WindowEvent(this.type, {this.size}) : timestamp = DateTime.now();

  bool get isStart =>
      type == WindowEventType.resizeStart ||
      type == WindowEventType.moveStart;
  bool get isEnd =>
      type == WindowEventType.resizeEnd || type == WindowEventType.moveEnd;
  bool get isResize =>
      type == WindowEventType.resizeStart ||
      type == WindowEventType.resizeEnd;
  bool get isMove =>
      type == WindowEventType.moveStart || type == WindowEventType.moveEnd;
}

/// 统一窗口生命周期事件总线（singleton）
///
/// 广播 resize/move 等瞬态事件。消费方可按类型过滤。
/// 同时暴露 [isOperating] notifier —— 任何"窗口正在被用户操作"的状态
/// （resize 或 move）为 true，用于统一暂停 BackdropFilter / 动画。
class WindowLifecycleBus {
  WindowLifecycleBus._();
  static final WindowLifecycleBus instance = WindowLifecycleBus._();

  final _controller = StreamController<WindowEvent>.broadcast();

  /// 所有窗口事件流（按需过滤）
  Stream<WindowEvent> get events => _controller.stream;

  /// "窗口正在被用户操作" —— resize 或 move 期间为 true
  /// 这是 ResizeNotifier 的超集，消费方可直接替换
  final ValueNotifier<bool> isOperating = ValueNotifier(false);

  int _resizeCount = 0;
  int _moveCount = 0;

  void dispatch(WindowEvent event) {
    _controller.add(event);
    isOperating.value = event.isStart;

    // PerfMonitor 集成
    final label = event.isResize ? 'window_resize' : 'window_move';
    if (event.isStart) {
      if (event.isResize) _resizeCount++;
      if (event.isMove) _moveCount++;
      PerfMonitor.instance.mark(label);
    } else {
      PerfMonitor.instance.markEnd(label);
    }
  }

  /// 窗口操作统计（供 PerfMonitor.exportStats 使用）
  Map<String, dynamic> get stats => {
        'resizeCount': _resizeCount,
        'moveCount': _moveCount,
      };

  void dispose() {
    _controller.close();
    isOperating.dispose();
  }
}
