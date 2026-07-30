import 'event_log_slot.dart';
import 'kernel_logger.dart';
import 'memory_monitor_slot.dart';
import 'metrics_slot.dart';

/// 诊断能力载体 (D1/D4 — Phase 16 骨架, 全部插槽 noop, 尚无消费者)
///
/// Construction-injected carrier that gives future phases a home to attach
/// real diagnostics capabilities. This is deliberate dead code in Phase 16
/// (D2/D3) — no consumer reads the bundle (deliberate dead code).
/// `final class` (not just `class`) supports [dispose] semantics and blocks
/// accidental inheritance (D1).
final class DiagnosticsBundle {
  /// 主构造函数 — 4 个插槽均为必填命名参数, 供真实实现注入
  ///
  /// Main constructor — all 4 slots are required named parameters.
  /// Real implementations are injected at composition root (PlayerServices).
  const DiagnosticsBundle({
    required this.logger,
    required this.memoryMonitor,
    required this.metrics,
    required this.eventLog,
  });

  /// Phase 16 默认值 — 全部插槽为空实现 (D4, 唯一的 const 工厂)。
  ///
  /// The sole const factory; wires all 4 `Null*` slots. This is what
  /// `KernelAdapter`'s constructor (Plan 16-01) uses as its `bundle`
  /// parameter default.
  const DiagnosticsBundle.noop()
      : logger = const NullKernelLogger(),
        memoryMonitor = const NullMemoryMonitorSlot(),
        metrics = const NullMetricsSlot(),
        eventLog = const NullEventLogSlot();

  /// 日志插槽 — 结构化内核日志输出 (trace→fatal 6 级)
  ///
  /// Logging slot — structured kernel log output (6 levels: trace→fatal).
  final KernelLogger logger;

  /// 内存监控插槽 — RSS 采样与阈值告警
  ///
  /// Memory monitoring slot — RSS sampling and threshold alerting.
  final MemoryMonitorSlot memoryMonitor;

  /// 指标插槽 — 播放/seek/帧丢/解码错误计数
  ///
  /// Metrics slot — counters for open/seek/frame-drop/decode-error events.
  final MetricsSlot metrics;

  /// 事件日志插槽 — 时序事件环形缓冲
  ///
  /// Event log slot — time-ordered event ring buffer.
  final EventLogSlot eventLog;

  /// 级联释放 — 镜像 PlayerServices.dispose() 的级联模式 (D10, player_services.dart:99-109)。
  ///
  /// [logger] 在 D7 的能力上限内不包含 dispose, 因此不参与级联。noop 插槽
  /// 空操作, 但未来真实插槽可能持有 timer/stream 等需要清理的资源。
  ///
  /// Cascading dispose mirroring `PlayerServices.dispose()`. [logger] has no
  /// `dispose` in its D7-capped contract, so it is not in the cascade. Noop
  /// slots no-op, but future real slots may hold timers/streams needing
  /// cleanup.
  void dispose() {
    memoryMonitor.dispose();
    metrics.dispose();
    eventLog.dispose();
  }
}
