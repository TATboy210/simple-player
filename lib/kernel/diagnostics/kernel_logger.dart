/// 内核诊断日志接口 (D5/D6/D7 — 仅签名, 不含 sink/格式化实现)
///
/// Kernel diagnostics logging interface. This is a signature-only contract —
/// no [LogLevel] enum, no sink abstraction, no redaction API, no formatting
/// machinery (D7). Those concerns belong to Phase 17's concrete implementation
/// hidden behind this interface; do NOT port `log.dart`'s `PrefixPrinter`,
/// `JsonPrinter`, `_RotatingFileOutput`, or `initLog()` here.
///
/// 层级映射表 (D8, locked) — Phase 17 迁移时按此表逐行替换调用点:
/// Level-mapping table (D8) for Phase 17's migration (table lookup, not logic):
///
/// | 现有调用前缀 (existing prefix) | KernelLogger 方法 | 现存调用点数 |
/// |---|---|---|
/// | `log*.t(...)` | [trace] | 0 |
/// | `log*.d(...)` | [debug] | 17 |
/// | `log*.i(...)` | [info]  | 12 |
/// | `log*.w(...)` | [warn]  | 7  |
/// | `log*.e(...)` | [error] | 48 |
/// | `log*.f(...)` | [fatal] | 0  |
abstract class KernelLogger {
  /// 最低优先级追踪日志 (trace-level, 当前无存量调用点)
  void trace(String message);

  /// 调试日志 (debug-level)
  void debug(String message);

  /// 信息日志 (info-level)
  void info(String message);

  /// 警告日志 (warn-level)
  void warn(String message);

  /// 错误日志 (error-level) — 84 处存量调用点中有 3 处携带 error/stackTrace 命名参数
  /// (2 处两者皆有 + 2 处仅 stackTrace, 跨 2 个文件, 见 RESEARCH Pitfall 1 普查),
  /// 因此两个可选命名参数都必须保留以兼容全部 3 种现存调用形态。
  void error(String message, {Object? error, StackTrace? stackTrace});

  /// 致命错误日志 (fatal-level) — 与 error() 对称 (D6), 当前无存量 `.f()` 调用点
  /// ([ASSUMED] 见 RESEARCH A1, 对称设计可接受)。
  void fatal(String message, {Object? error, StackTrace? stackTrace});
}

/// 空实现 KernelLogger — Phase 16 默认值, 所有方法体为空 (D2/D3 故意死代码)。
///
/// Null-object [KernelLogger] implementation — every method is a no-op.
/// This is the Phase 16 default; Phase 17 will supply a real sink-backed
/// implementation behind this same interface.
final class NullKernelLogger implements KernelLogger {
  const NullKernelLogger();

  @override
  void trace(String message) {}

  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void fatal(String message, {Object? error, StackTrace? stackTrace}) {}
}
