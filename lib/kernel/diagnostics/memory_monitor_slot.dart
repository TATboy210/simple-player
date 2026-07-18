/// 内存监控插槽接口 (D9/D10 — 从 MemoryMonitor 公开 API 提炼的最小实例方法契约)
///
/// Minimal instance-method contract traced from [MemoryMonitor]'s public
/// surface (start/stop/snapshot). Deliberately NOT a static singleton and
/// NOT coupled to the concrete `MemorySnapshot` type (D9/D10) — the `Slot`
/// suffix avoids a name collision with the existing `MemoryMonitor` class,
/// and the loose `Object?` return keeps Phase 19 free to change the concrete
/// snapshot shape without breaking this interface.
abstract class MemoryMonitorSlot {
  /// 开始周期性采样 (interval 为 null 时使用实现方默认间隔)
  void start({Duration? interval});

  /// 停止采样
  void stop();

  /// 返回当前快照 — 返回类型故意宽松 (Object?), 不耦合具体 MemorySnapshot 形状 (D10)
  Object? snapshot();

  /// 释放资源 (由 DiagnosticsBundle.dispose() 级联调用)
  void dispose();
}

/// 空实现 MemoryMonitorSlot — Phase 16 默认值, 所有方法空操作。
///
/// Null-object implementation: every method no-ops, [snapshot] returns null.
final class NullMemoryMonitorSlot implements MemoryMonitorSlot {
  const NullMemoryMonitorSlot();

  @override
  void start({Duration? interval}) {}

  @override
  void stop() {}

  @override
  Object? snapshot() => null;

  @override
  void dispose() {}
}
