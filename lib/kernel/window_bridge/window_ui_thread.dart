import 'package:flutter/scheduler.dart';

/// 在 UI 线程的安全时机执行 [update]。
///
/// 调度器处于 idle/post-frame 阶段时同步执行，否则推迟到当前帧回调之后，
/// 避免在 build/layout/paint 阶段修改 ValueNotifier 触发框架断言。
/// 调度器不可用（[Exception]）时降级为同步执行，并经 [warn] 记录异常
/// 上下文；[Error] 子类指示编程错误，先保状态一致再继续传播。
void updateOnUIThread(
  VoidCallback update, {
  required void Function(Object error, StackTrace stackTrace) warn,
}) {
  try {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      update();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => update());
    }
  } on Exception catch (error, stackTrace) {
    // 调度器不可用时保留同步更新，并记录异常上下文便于诊断。
    warn(error, stackTrace);
    update();
  } on Error {
    // 清理/测试阶段可能抛出 Error；保持原有兜底行为但继续传播不可恢复错误。
    update();
    rethrow;
  }
}
