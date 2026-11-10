import 'dart:async';

import 'package:flutter/foundation.dart';

/// resize 会话防抖（契约 3）— 500ms 静默即会话结束。
///
/// 检测源为引擎指标（WindowMetricsObserver → noteGeometryChanged），
/// 频率远低于原生事件洪泛且不占窗口线程。防抖语义与旧事件源时代一致：
/// * [isResizing] 仅在会话边沿翻转（会话内重复信号不再 notify）；
/// * [sessionId] 仅在会话开始递增（消费方以 id 变化判定新会话）；
/// * generation 防过期 timer 结算新会话。
class ResizeSession {
  ResizeSession({
    required this.isResizing,
    required this.sessionId,
    required this.onSettled,
    this.debounce = const Duration(milliseconds: 500),
  });

  /// 会话中标志（单一数据源，边沿通知）。
  final ValueNotifier<bool> isResizing;

  /// 会话递增标识（会话开始 +1）。
  final ValueNotifier<int> sessionId;

  /// 会话结算回调（带 generation，过期结算由实现内部拦截）。
  final void Function() onSettled;

  /// 防抖窗口 — 最后一个几何信号后静默这么久才算会话结束。
  final Duration debounce;

  Timer? _timer;
  int _generation = 0;

  /// 当前会话代数 — 结算回调只认最新一代。
  int get generation => _generation;

  /// 几何变化信号：开启或续期会话。
  void noteChanged() {
    _timer?.cancel();
    final generation = ++_generation;
    if (!isResizing.value) sessionId.value++;
    isResizing.value = true;
    _timer = Timer(debounce, () {
      if (generation != _generation) return;
      isResizing.value = false;
      onSettled();
    });
  }

  /// 取消进行中的会话计时（关窗/释放路径）；不触发结算。
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
