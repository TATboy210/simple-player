/// 引擎指标插槽接口 (D9/D10 — 从 EngineMetrics record* 方法提炼的最小契约)
///
/// Exposes the `record*` verbs traced from [EngineMetrics]'s public surface
/// (engine_metrics.dart:44-79) — the actual capability Phase 18 needs —
/// WITHOUT the internal counter fields (framesDropped/_totalSeekTime stay
/// implementation-private in the real class, D10). [toJson] uses a loose
/// value type rather than the concrete `Map<String, Object>`.
abstract class MetricsSlot {
  /// 记录一次打开操作 (成功/失败)
  void recordOpen({required bool success});

  /// 记录一次 seek 操作耗时
  void recordSeek(Duration elapsed);

  /// 记录丢帧事件 (默认计数 1)
  void recordFrameDrop([int count = 1]);

  /// 记录解码错误
  void recordDecodeError();

  /// 记录缓冲区欠载
  void recordBufferUnderrun();

  /// 重置所有计数器
  void reset();

  /// 导出为 JSON — 值类型故意宽松 (Object?), 不耦合具体计数器形状 (D10)
  Map<String, Object?> toJson();

  /// 释放资源 (由 DiagnosticsBundle.dispose() 级联调用)
  void dispose();
}

/// 空实现 MetricsSlot — Phase 16 默认值, 所有 record*/reset 空操作。
///
/// Null-object implementation: every `record*`/`reset` no-ops, [toJson]
/// returns an empty const map.
final class NullMetricsSlot implements MetricsSlot {
  const NullMetricsSlot();

  @override
  void recordOpen({required bool success}) {}

  @override
  void recordSeek(Duration elapsed) {}

  @override
  void recordFrameDrop([int count = 1]) {}

  @override
  void recordDecodeError() {}

  @override
  void recordBufferUnderrun() {}

  @override
  void reset() {}

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  void dispose() {}
}
