/// 内核诊断日志门面 (D5/D6/D7 — Phase 17 具体实现)
///
/// Kernel diagnostics logging facade. Concrete implementation with
/// zero third-party dependencies: LogLevel enum, LogSink interface,
/// three sink implementations (DevToolsSink/DebugPrintSink/NullSink)
/// + CompositeSink, and KernelLoggerImpl with static `I` accessor.
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
library;

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// LogLevel — 6 severity levels, 1:1 with KernelLogger methods (D14)
// ---------------------------------------------------------------------------

/// 日志严重级别枚举 — 6 级, 与 KernelLogger 的 6 个方法一一对应 (D14).
///
/// Log severity levels. Six values matching KernelLogger methods 1:1.
enum LogLevel { trace, debug, info, warn, error, fatal }

// ---------------------------------------------------------------------------
// LogSink — single-method output interface (D4)
// ---------------------------------------------------------------------------

/// 日志输出接口 — 单方法, 接受 level/msg/context (D4).
///
/// Single-method sink interface. Concrete sinks handle output to
/// DevTools, debugPrint, or nowhere (NullSink).
abstract interface class LogSink {
  /// 输出一条日志到目标 (D4).
  ///
  /// [level] severity, [msg] redacted message, [context] optional structured data.
  void log(LogLevel level, String msg, {Map<String, Object?>? context});
}

// ---------------------------------------------------------------------------
// redactPath — strips directory prefixes from file paths (D17)
// ---------------------------------------------------------------------------

/// 路径脱敏 — 将完整文件路径缩短为文件名:行号 (D17).
///
/// Strips directory prefixes from `.dart:line` paths in log messages.
/// Example: `lib/kernel/engine/fvp_engine.dart:259` → `fvp_engine.dart:259`
/// Public for direct testing; also used internally by DevToolsSink/DebugPrintSink.
String redactPath(String msg) {
  return msg.replaceAllMapped(
    RegExp(r'[\w/\\]+[/\\]([\w]+\.dart:\d+)'),
    (m) => m.group(1)!,
  );
}

// ---------------------------------------------------------------------------
// DevToolsSink — dart:developer.log with name='Kernel' (D15)
// ---------------------------------------------------------------------------

/// DevTools 输出 — 通过 dart:developer.log 发送结构化日志 (D15).
///
/// Logs via `dart:developer.log` with `name: 'Kernel'`. DevTools receives
/// structured entries; context map is not passed (DevTools has its own view).
/// Message paths are redacted via [redactPath] before output.
final class DevToolsSink implements LogSink {
  /// const 构造 — 无状态, 支持编译时常量 (D15).
  const DevToolsSink();
  /// LogLevel → dart:developer severity 映射 (D15).
  static int _toSeverity(LogLevel level) => switch (level) {
    LogLevel.trace => 300,
    LogLevel.debug => 500,
    LogLevel.info  => 800,
    LogLevel.warn  => 900,
    LogLevel.error => 1000,
    LogLevel.fatal => 1200,
  };

  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    developer.log(
      name: 'Kernel',
      level: _toSeverity(level),
      redactPath(msg),
      time: DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// DebugPrintSink — debugPrint with level prefix (D12/D16)
// ---------------------------------------------------------------------------

/// debugPrint 输出 — 带级别前缀和可选 context 后缀 (D12/D16).
///
/// Outputs via `debugPrint` with `LEVEL: message {context}` format.
/// Message paths are redacted via [redactPath] before output.
/// Only active in debug mode (kDebugMode gate at composition root).
final class DebugPrintSink implements LogSink {
  /// const 构造 — 无状态, 支持编译时常量 (D16).
  const DebugPrintSink();
  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    final redacted = redactPath(msg);
    final contextStr = context != null && context.isNotEmpty
        ? ' $context'
        : '';
    debugPrint('${level.name.toUpperCase()}: $redacted$contextStr');
  }
}

// ---------------------------------------------------------------------------
// NullSink — no-op for release builds (D13)
// ---------------------------------------------------------------------------

/// 空输出 — release 构建使用, 所有方法为空操作 (D13).
///
/// No-op sink. Release builds use this via kDebugMode compile-time gate.
/// const constructor enables tree-shaking of all debug log calls.
final class NullSink implements LogSink {
  /// const 构造 — 支持编译时常量 (D13).
  const NullSink();

  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    // Intentional no-op: release builds produce zero output.
  }
}

// ---------------------------------------------------------------------------
// CompositeSink — fan-out to multiple sinks (D12)
// ---------------------------------------------------------------------------

/// 组合输出 — 将日志分发到多个 sink (D12).
///
/// Fans out log calls to all contained sinks. Debug mode uses
/// `CompositeSink([DebugPrintSink(), DevToolsSink()])` for dual output.
final class CompositeSink implements LogSink {
  /// 构造 — 接受一组 sink 实例.
  CompositeSink(this._sinks);

  final List<LogSink> _sinks;

  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    for (final sink in _sinks) {
      sink.log(level, msg, context: context);
    }
  }
}

// ---------------------------------------------------------------------------
// KernelLogger — abstract interface (Phase 16 skeleton, now extended)
// ---------------------------------------------------------------------------

/// 内核诊断日志接口 (D5/D6/D7)
///
/// Kernel diagnostics logging interface. Concrete [KernelLoggerImpl]
/// provides kDebugMode-gated sinks. Shortcut methods (t/d/i/w/e/f)
/// delegate to full methods for ergonomic call sites.
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
  /// const 构造 — 支持子类 const 构造.
  const KernelLogger();

  /// 静态访问器 — 委托给 [KernelLoggerImpl.I] (Phase 17-02 迁移调用点统一入口).
  ///
  /// Forwarding getter so that 24 migrated kernel files can use
  /// `KernelLogger.I` without importing the concrete implementation.
  static KernelLoggerImpl get I => KernelLoggerImpl.I;

  /// 最低优先级追踪日志 (trace-level, 当前无存量调用点)
  void trace(String message, {Map<String, Object?>? context});

  /// 调试日志 (debug-level)
  void debug(String message, {Map<String, Object?>? context});

  /// 信息日志 (info-level)
  void info(String message, {Map<String, Object?>? context});

  /// 警告日志 (warn-level)
  void warn(String message, {Map<String, Object?>? context});

  /// 错误日志 (error-level) — 84 处存量调用点中有 3 处携带 error/stackTrace 命名参数
  /// (2 处两者皆有 + 2 处仅 stackTrace, 跨 2 个文件, 见 RESEARCH Pitfall 1 普查),
  /// 因此两个可选命名参数都必须保留以兼容全部 3 种现存调用形态。
  void error(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  });

  /// 致命错误日志 (fatal-level) — 与 error() 对称 (D6), 当前无存量 `.f()` 调用点
  /// ([ASSUMED] 见 RESEARCH A1, 对称设计可接受)。
  void fatal(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  });

  // ---- Shortcut methods (D11) — delegate to full methods ----

  /// trace 快捷方式 (D11)
  void t(String m, {Map<String, Object?>? context}) =>
      trace(m, context: context);

  /// debug 快捷方式 (D11)
  void d(String m, {Map<String, Object?>? context}) =>
      debug(m, context: context);

  /// info 快捷方式 (D11)
  void i(String m, {Map<String, Object?>? context}) =>
      info(m, context: context);

  /// warn 快捷方式 (D11)
  void w(String m, {Map<String, Object?>? context}) =>
      warn(m, context: context);

  /// error 快捷方式 (D11)
  void e(
    String m, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // ignore: unnecessary_this — `error` param shadows method name, this. required for disambiguation
    this.error(m, context: context, error: error, stackTrace: stackTrace);
  }

  /// fatal 快捷方式 (D11)
  void f(
    String m, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // ignore: unnecessary_this — `fatal` not shadowed but kept for symmetry
    this.fatal(m, context: context, error: error, stackTrace: stackTrace);
  }
}

// ---------------------------------------------------------------------------
// NullKernelLogger — Phase 16 no-op implementation (D2/D3)
// ---------------------------------------------------------------------------

/// 空实现 KernelLogger — Phase 16 默认值, 所有方法体为空 (D2/D3 故意死代码).
///
/// Null-object [KernelLogger] implementation — every method is a no-op.
/// This is the Phase 16 default; Phase 17 supplies a real sink-backed
/// implementation behind this same interface.
final class NullKernelLogger extends KernelLogger {
  const NullKernelLogger();

  @override
  void trace(String message, {Map<String, Object?>? context}) {}

  @override
  void debug(String message, {Map<String, Object?>? context}) {}

  @override
  void info(String message, {Map<String, Object?>? context}) {}

  @override
  void warn(String message, {Map<String, Object?>? context}) {}

  @override
  void error(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  void fatal(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

// ---------------------------------------------------------------------------
// KernelLoggerImpl — concrete KernelLogger with static I accessor (Phase 17)
// ---------------------------------------------------------------------------

/// 具体 KernelLogger 实现 — 静态 I 访问器 + kDebugMode 门控 sink (Phase 17).
///
/// Concrete [KernelLogger] backed by a [LogSink]. Composition root
/// ([init]) selects sink based on [kDebugMode]:
/// - debug: `CompositeSink([DebugPrintSink(), DevToolsSink()])`
/// - release: `NullSink()` (zero output, tree-shakeable)
///
/// Usage:
/// ```dart
/// KernelLoggerImpl.init(); // at app startup, before engine creation
/// KernelLoggerImpl.I.info('engine ready'); // anywhere in kernel
/// ```
final class KernelLoggerImpl extends KernelLogger {
  /// 直接构造 — 接受任意 LogSink (用于测试注入).
  KernelLoggerImpl(this._sink);

  final LogSink _sink;

  /// 静态单例 — 不用 `late final`, 用 nullable + StateError 守卫 (RESEARCH anti-pattern).
  static KernelLoggerImpl? _instance;

  /// 全局访问器 — 调用前必须先调用 [init()].
  ///
  /// Throws [StateError] if [init()] has not been called.
  static KernelLoggerImpl get I {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'KernelLoggerImpl.I accessed before init(). '
        'Call KernelLoggerImpl.init() at app startup.',
      );
    }
    return inst;
  }

  /// 组合根 — 创建 kDebugMode 门控的 sink 并初始化静态实例 (D13).
  ///
  /// Composition root. Must be called once at app startup, before any
  /// kernel code accesses [I]. Creates:
  /// - debug: `CompositeSink([DebugPrintSink(), DevToolsSink()])`
  /// - release: `NullSink()`
  static void init() {
    final LogSink sink = kDebugMode
        ? CompositeSink([const DebugPrintSink(), const DevToolsSink()])
        : const NullSink();
    _instance = KernelLoggerImpl(sink);
  }

  /// 测试辅助 — 重置静态实例, 便于测试间隔离.
  ///
  /// Test helper: resets static instance for test isolation.
  /// Not part of the public API; only for @visibleForTesting use.
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  // ---- Full methods — delegate to _sink ----

  @override
  void trace(String message, {Map<String, Object?>? context}) {
    _sink.log(LogLevel.trace, message, context: context);
  }

  @override
  void debug(String message, {Map<String, Object?>? context}) {
    _sink.log(LogLevel.debug, message, context: context);
  }

  @override
  void info(String message, {Map<String, Object?>? context}) {
    _sink.log(LogLevel.info, message, context: context);
  }

  @override
  void warn(String message, {Map<String, Object?>? context}) {
    _sink.log(LogLevel.warn, message, context: context);
  }

  @override
  void error(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _sink.log(LogLevel.error, message, context: context);
  }

  @override
  void fatal(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _sink.log(LogLevel.fatal, message, context: context);
  }
}
