/// 内存监控插槽接口 (D9/D10 — 从 MemoryMonitor 公开 API 提炼的最小实例方法契约)
///
/// Minimal instance-method contract traced from [MemoryMonitor]'s public
/// surface (start/stop/snapshot). Deliberately NOT a static singleton and
/// NOT coupled to the concrete `MemorySnapshot` type (D9/D10) — the `Slot`
/// suffix avoids a name collision with the existing `MemoryMonitor` class,
/// and the loose `Object?` return keeps Phase 19 free to change the concrete
/// snapshot shape without breaking this interface.
abstract class MemoryMonitorSlot {
  /// 开始周期性采样 (interval 为 null 时使用实现方默认间隔).
  ///
  /// Starts periodic sampling. Uses implementation default interval when null.
  void start({Duration? interval});

  /// 停止采样.
  ///
  /// Stops sampling.
  void stop();

  /// 返回当前快照 — 返回类型故意宽松 (Object?), 不耦合具体 MemorySnapshot 形状 (D10).
  ///
  /// Returns current snapshot. Deliberately loose return type (D10).
  Object? snapshot();

  /// 释放资源.
  ///
  /// Disposes resources.
  void dispose();
}
