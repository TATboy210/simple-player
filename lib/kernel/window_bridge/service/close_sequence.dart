import 'dart:async';

import '../../diagnostics/kernel_logger.dart';

/// hide-first 关窗序列（契约 7）。
///
/// 1) hide — 窗口先视觉消失；2) persist — 排空队列后几何落盘；
/// 3) closing listeners — 应用级退出落盘（播放列表断点等）；
/// 4) dispose + exit(0) — 立即终止进程：窗口已不可见、状态已落盘，硬杀
/// 跳过引擎/libmpv 收尾等待（「窗口已消失但进程滞留」的根源），播放器
/// 无跨进程状态，窗口由 OS 随进程退出销毁。
///
/// 每步 [stepTimeout] 超时兜底（超时不取消底层调用，只是不再等待）；
/// 任何失败不阻断退出；多路触发（✕ 连点 / runner 专线回调）经 [begin]
/// 单飞共享同一次执行。
class CloseSequence {
  CloseSequence({
    required this.hide,
    required this.persist,
    required this.closingListeners,
    required this.disposeService,
    required this.exit,
    this.stepTimeout = const Duration(milliseconds: 800),
  });

  /// 各步骤回调 — 由门面组装（见 window_service.dart）。
  final void Function() hide;
  final Future<void> Function() persist;
  final List<Future<void> Function()> Function() closingListeners;
  final void Function() disposeService;
  final void Function(int code) exit;
  final Duration stepTimeout;

  Future<void>? _operation;

  /// 关窗序列的执行体 — 测试等待关窗完成用。
  Future<void>? get operation => _operation;

  /// 唯一入口 — 重复触发共享同一次执行。
  Future<void> begin() => _operation ??= _run();

  Future<void> _run() async {
    try {
      await _step('hide', () => hide());
      await _step('persist', persist);
      // 快照遍历 — listener 执行中允许注册/注销（移除函数幂等）。
      for (final listener in List.of(closingListeners())) {
        await _step('closing-listener', listener);
      }
    } finally {
      disposeService();
      exit(0);
    }
  }

  /// 执行单个命令，附带超时兜底。[step] 可为同步 void（FFI）或异步 Future。
  Future<void> _step(String label, FutureOr<void> Function() step) async {
    try {
      await Future<void>.value(step()).timeout(stepTimeout);
    } on TimeoutException {
      KernelLogger.I.w(
        '[CloseSequence] "$label" timed out — continuing anyway',
      );
    } on Object catch (error, stackTrace) {
      // 关窗路径刻意容纳一切 — 绝不让清理失败阻断退出。
      KernelLogger.I.e(
        '[CloseSequence] "$label" failed: $error\n$stackTrace',
      );
    }
  }
}
