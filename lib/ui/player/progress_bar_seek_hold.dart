part of 'progress_bar.dart';

/// seek-hold 控制器 (修 C 事件驱动 v2) — dragEnd 后监听 position 到达
/// 目标容差内才清 drag, 遮住旧 stream 回拨防回跳.
///
/// Event-driven replacement for the old fixed 300ms timer: holds the drag
/// fraction until the engine position reaches the seek target (within
/// [Tokens.progressSeekArriveToleranceMs]), with a timeout fallback so a failed
/// seek can never pin the bar at the drag position forever. 记住所监听的
/// 源, 因此源替换时 [cancel] 总能从旧源摘除回调 (无需调用方传旧 source).
class _SeekHold {
  /// [isMounted] 守卫宿主是否存活; [onDone] 在 hold 正常完成/超时后调用
  /// (宿主在其中清 drag 并刷新 tooltip).
  _SeekHold({required this.isMounted, required this.onDone});

  /// 宿主 State 是否仍挂载.
  final bool Function() isMounted;

  /// hold 完成回调 — 宿主清 drag + 刷新 tooltip.
  final VoidCallback onDone;

  VoidCallback? _listener;
  ValueListenable<int>? _source;
  int? _targetMs;
  Timer? _timer;

  /// 是否有未完成的 hold.
  bool get isActive => _listener != null;

  /// 当前 hold 的目标位置 (ms); 无 hold 时为 null.
  int? get targetMs => _targetMs;

  /// 开始 hold — 监听 [position] 到达 [targetMs] 容差内才触发 [onDone].
  ///
  /// Side effect: 取消先前 hold, 注册 position 监听 + 超时 timer.
  void begin(ValueListenable<int> position, int targetMs) {
    cancel();
    _targetMs = targetMs;
    _source = position;
    // 局部函数声明 (非闭包变量赋值, 避免 prefer_function_declarations_over_variables);
    // 复用函数名消除 addListener/call 的 `!`; 内 target local 捕获消除 `!`.
    void listener() {
      if (!isMounted()) return;
      final target = _targetMs;
      if (target == null) return;
      if ((position.value - target).abs() <=
          Tokens.progressSeekArriveToleranceMs) {
        _finish();
      }
    }

    _listener = listener;
    // 先建超时 timer, 再 addListener + 立即检查 — 若立即检查触发 _finish,
    // cancel 会 cancel 此 timer; 顺序反了 (timer 在 call 之后建) 会留下无人
    // 取消的 pending timer, 触发 flutter_test 的 !timersPending 断言.
    _timer = Timer(
      const Duration(milliseconds: Tokens.progressSeekHoldTimeoutMs),
      _finish,
    );
    // 误报 — listener 存入 _listener 字段, cancel (含 dispose 路径)
    // 统一移除.
    // ignore: always-remove-listener
    position.addListener(listener);
    // 立即检查一次: FakeEngine/同步 seek 可能已让 position 到达目标,
    // addListener 只对未来变化触发, 不立即检查会卡到超时 (测试/同步路径).
    listener.call();
  }

  /// 清理监听 + 超时 timer, 不触发 [onDone].
  /// 用于新 drag 开始 (覆盖前) / dispose / 源替换时取消未完成 hold.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    final listener = _listener;
    if (listener != null) {
      // 用 begin 时记录的源摘除 — 源替换后 widget.position 已指向新 port.
      _source?.removeListener(listener);
      _listener = null;
    }
    _source = null;
    _targetMs = null;
  }

  /// hold 正常完成 (position 到达或超时兜底) — 清监听后通知宿主.
  void _finish() {
    if (!isMounted()) return;
    cancel();
    onDone();
  }
}
