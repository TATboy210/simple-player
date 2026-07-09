import 'fullscreen_error.dart';
import 'fullscreen_snapshot.dart';

/// 全屏生命周期事件 — 业务层通过 `Stream<FullscreenEvent>` 监听。
///
/// 设计约束:
/// - 与 _WindowListener 解耦，Adapter 内部转换原生事件
/// - 每个事件携带 timestamp 用于调试和排序
/// - forcedChange 携带差异信息用于诊断
sealed class FullscreenEvent {
  /// 子类构造函数传入 timestamp ?? DateTime.now()。
  FullscreenEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();

  /// 事件发生时间。
  final DateTime timestamp;

  /// 请求进入全屏。
  factory FullscreenEvent.enterRequested({
    required FullscreenMode targetMode,
    DateTime? timestamp,
  }) = EnterRequested;

  /// 已成功进入全屏。
  factory FullscreenEvent.entered({
    required FullscreenMode finalMode,
    DateTime? timestamp,
  }) = Entered;

  /// 请求退出全屏。
  factory FullscreenEvent.leaveRequested({
    DateTime? timestamp,
  }) = LeaveRequested;

  /// 已成功退出全屏。
  factory FullscreenEvent.left({
    DateTime? timestamp,
  }) = Left;

  /// OS 外部强制变更（系统快捷键、窗口管理器）。
  factory FullscreenEvent.forcedChange({
    required FullscreenMode previousMode,
    required FullscreenMode actualMode,
    DateTime? timestamp,
  }) = ForcedChange;

  /// 状态校正 — 回读与预期不一致时发出。
  factory FullscreenEvent.syncCorrected({
    required FullscreenMode expected,
    required FullscreenMode actual,
    DateTime? timestamp,
  }) = SyncCorrected;

  /// 操作出错。
  factory FullscreenEvent.error({
    required FullscreenError error,
    DateTime? timestamp,
  }) = FullscreenErrorEvent;
}

/// 请求进入全屏。
final class EnterRequested extends FullscreenEvent {
  EnterRequested({required this.targetMode, super.timestamp});
  final FullscreenMode targetMode;
}

/// 已成功进入全屏。
final class Entered extends FullscreenEvent {
  Entered({required this.finalMode, super.timestamp});
  final FullscreenMode finalMode;
}

/// 请求退出全屏。
final class LeaveRequested extends FullscreenEvent {
  LeaveRequested({super.timestamp});
}

/// 已成功退出全屏。
final class Left extends FullscreenEvent {
  Left({super.timestamp});
}

/// OS 外部强制变更。
final class ForcedChange extends FullscreenEvent {
  ForcedChange({
    required this.previousMode,
    required this.actualMode,
    super.timestamp,
  });
  final FullscreenMode previousMode;
  final FullscreenMode actualMode;
}

/// 状态校正。
final class SyncCorrected extends FullscreenEvent {
  SyncCorrected({
    required this.expected,
    required this.actual,
    super.timestamp,
  });
  final FullscreenMode expected;
  final FullscreenMode actual;
}

/// 操作出错 — 命名避免与 FullscreenError 冲突。
final class FullscreenErrorEvent extends FullscreenEvent {
  FullscreenErrorEvent({required this.error, super.timestamp});
  final FullscreenError error;
}
