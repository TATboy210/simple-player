/// 内核诊断日志门面 (D5/D6/D7 — Phase 17 具体实现)
///
/// Kernel diagnostics logging facade. Concrete implementation with
/// zero third-party dependencies: LogLevel enum, LogSink interface,
/// three sink implementations (DevToolsSink/DebugPrintSink/NullSink)
/// + CompositeSink, and KernelLoggerImpl with static `I` accessor.
///
/// 层级映射表 (D8, locked) — Phase 17 迁移已完成 (24 个 kernel 文件已迁移),
/// 此表为迁移期工作清单, 保留作历史参考:
/// Level-mapping table (D8) — Phase 17 migration complete (24 kernel files migrated).
/// Retained as historical reference:
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

import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// LogLevel — 6 severity levels, 1:1 with KernelLogger methods (D14)
// ---------------------------------------------------------------------------

/// 日志严重级别枚举 — 6 级, 与 KernelLogger 的 6 个方法一一对应 (D14).
///
/// Log severity levels. Six values matching KernelLogger methods 1:1.
enum LogLevel {
  /// 最低级别 — 细粒度跟踪, 当前无存量调用点.
  ///
  /// Finest-grained tracing. No existing call sites.
  trace,

  /// 调试级别 — 开发期诊断信息.
  ///
  /// Debug-level diagnostics for development.
  debug,

  /// 信息级别 — 正常运行时事件.
  ///
  /// Informational events during normal operation.
  info,

  /// 警告级别 — 可恢复异常或降级.
  ///
  /// Recoverable anomalies or degraded conditions.
  warn,

  /// 错误级别 — 操作失败但进程可继续.
  ///
  /// Operation failure; process may continue.
  error,

  /// 致命级别 — 不可恢复错误, 进程即将终止.
  ///
  /// Unrecoverable error; process is about to terminate.
  fatal,
}

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
  /// [error]/[stackTrace] 可选 — 由 error/fatal 级别透传, 供支持结构化错误的
  /// sink (如 DevToolsSink) 使用。P1 bugfix: 此前接口不接这两个参数, 导致
  /// KernelLoggerImpl.error/fatal 丢弃调用方传入的 error/stackTrace.
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  });
}

enum KernelBuildMode {
  /// 开发构建，同时输出到 debugPrint 与 DevTools。
  debug,

  /// 性能构建，仅输出到 DevTools，避免终端日志干扰采样。
  profile,

  /// 发布构建，不产生诊断输出。
  release,
}

/// 根据构建模式创建默认日志输出策略。
///
/// sink 参数可注入以通过行为验证路由；生产环境使用默认实现。Release 始终
/// 返回 [NullSink]，从而不注册任何实际输出目标。
LogSink createDefaultLogSink(
  KernelBuildMode mode, {
  LogSink debugSink = const DebugPrintSink(),
  LogSink devToolsSink = const DevToolsSink(),
}) => switch (mode) {
  KernelBuildMode.debug => CompositeSink([debugSink, devToolsSink]),
  KernelBuildMode.profile => devToolsSink,
  KernelBuildMode.release => const NullSink(),
};

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
    // group(1) 类型为 String?, 整体匹配时捕获组必非空, `?? ''` 兜底防御
    (m) => m.group(1) ?? '',
  );
}

/// 将日志 context 转为键顺序稳定、始终可编码的 JSON。
///
/// Map 递归按键排序，List 保序，Set 按规范化后的值排序；非有限浮点数与
/// 循环引用使用固定字符串表示，使 Profile 诊断不会因辅助数据异常而中断。
String serializeLogContext(Map<String, Object?> context) {
  final activeContainers = HashSet<Object>.identity();
  final normalized = _normalizeLogValue(context, activeContainers);
  return jsonEncode(normalized);
}

Object? _normalizeLogValue(Object? value, Set<Object> activeContainers) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (value.isNaN) return 'NaN';
    if (value == double.infinity) return 'Infinity';
    if (value == double.negativeInfinity) return '-Infinity';
    return value;
  }
  if (value is DateTime) return value.toUtc().toIso8601String();

  if (value is Map<Object?, Object?>) {
    if (!activeContainers.add(value)) return '<cycle>';
    try {
      final entries = value.entries.toList()
        ..sort(
          (a, b) =>
              (a.key?.toString() ?? '').compareTo(b.key?.toString() ?? ''),
        );
      return <String, Object?>{
        for (final entry in entries)
          (entry.key?.toString() ?? '<null>'): _normalizeLogValue(
            entry.value,
            activeContainers,
          ),
      };
    } finally {
      activeContainers.remove(value);
    }
  }
  if (value is List<Object?>) {
    if (!activeContainers.add(value)) return '<cycle>';
    try {
      return [
        for (final item in value) _normalizeLogValue(item, activeContainers),
      ];
    } finally {
      activeContainers.remove(value);
    }
  }
  if (value is Set<Object?>) {
    if (!activeContainers.add(value)) return '<cycle>';
    try {
      final normalized = [
        for (final item in value) _normalizeLogValue(item, activeContainers),
      ];
      normalized.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
      return normalized;
    } finally {
      activeContainers.remove(value);
    }
  }

  // 未知对象不调用用户可覆写的 toString()；诊断辅助路径不能执行不可控代码。
  return '<object:${value.runtimeType}>';
}

// ---------------------------------------------------------------------------
// DevToolsSink — dart:developer.log with name='Kernel' (D15)
// ---------------------------------------------------------------------------

/// DevTools 输出 — 通过 dart:developer.log 发送结构化日志 (D15).
///
/// context 以稳定 JSON 后缀写入 message，Profile 控制台与 DevTools 都能直接
/// 收集 machine-readable resize 指标；路径仍通过 [redactPath] 脱敏。
final class DevToolsSink implements LogSink {
  /// const 构造 — 无状态, 支持编译时常量 (D15).
  const DevToolsSink();

  /// LogLevel → dart:developer severity 映射 (D15).
  static int _toSeverity(LogLevel level) => switch (level) {
    LogLevel.trace => 300,
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warn => 900,
    LogLevel.error => 1000,
    LogLevel.fatal => 1200,
  };

  @override
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final redacted = redactPath(msg);
    final contextSuffix = context != null && context.isNotEmpty
        ? ' ${serializeLogContext(context)}'
        : '';
    developer.log(
      '$redacted$contextSuffix',
      name: 'Kernel',
      level: _toSeverity(level),
      time: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
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
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final redacted = redactPath(msg);
    final contextStr = context != null && context.isNotEmpty
        ? ' ${serializeLogContext(context)}'
        : '';
    // error/stackTrace 拼入输出 — debugPrint 无结构化错误通道, 仅文本展示。
    final errorStr = error != null ? ' error=$error' : '';
    final stackStr = stackTrace != null ? '\n$stackTrace' : '';
    debugPrint(
      '${level.name.toUpperCase()}: $redacted$contextStr$errorStr$stackStr',
    );
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
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Intentional no-op: release builds produce zero output.
    return;
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
  ///
  /// Constructor. Accepts a list of [LogSink] instances for fan-out.
  CompositeSink(this._sinks);

  final List<LogSink> _sinks;

  @override
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    for (final sink in _sinks) {
      sink.log(
        level,
        msg,
        context: context,
        error: error,
        stackTrace: stackTrace,
      );
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
/// 层级映射表 (D8, locked) — Phase 17 迁移已完成 (24 个 kernel 文件已迁移),
/// 此表为迁移期工作清单, 保留作历史参考:
/// Level-mapping table (D8) — Phase 17 migration complete (24 kernel files migrated).
/// Retained as historical reference:
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

  /// 最低优先级追踪日志 (trace-level, 当前无存量调用点).
  ///
  /// Trace-level log. No existing call sites.
  void trace(String message, {Map<String, Object?>? context});

  /// 调试日志 (debug-level).
  ///
  /// Debug-level log.
  void debug(String message, {Map<String, Object?>? context});

  /// 信息日志 (info-level).
  ///
  /// Info-level log.
  void info(String message, {Map<String, Object?>? context});

  /// 警告日志 (warn-level).
  ///
  /// Warn-level log.
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

  /// trace 快捷方式 (D11).
  ///
  /// Shortcut for [trace].
  void t(String m, {Map<String, Object?>? context}) =>
      trace(m, context: context);

  /// debug 快捷方式 (D11).
  ///
  /// Shortcut for [debug].
  void d(String m, {Map<String, Object?>? context}) =>
      debug(m, context: context);

  /// info 快捷方式 (D11).
  ///
  /// Shortcut for [info].
  void i(String m, {Map<String, Object?>? context}) =>
      info(m, context: context);

  /// warn 快捷方式 (D11).
  ///
  /// Shortcut for [warn].
  void w(String m, {Map<String, Object?>? context}) =>
      warn(m, context: context);

  /// error 快捷方式 (D11).
  ///
  /// Shortcut for [error].
  void e(
    String m, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // ignore: unnecessary_this — `error` param shadows method name, this. required for disambiguation
    this.error(m, context: context, error: error, stackTrace: stackTrace);
  }

  /// fatal 快捷方式 (D11).
  ///
  /// Shortcut for [fatal].
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
// KernelLoggerImpl — concrete KernelLogger with static I accessor (Phase 17)
// ---------------------------------------------------------------------------

/// 具体 KernelLogger 实现 — 静态 I 访问器 + 构建模式门控 sink (Phase 17).
///
/// Concrete [KernelLogger] backed by a [LogSink]. Composition root
/// ([init]) selects sink based on Flutter's compile-time build mode:
/// - debug: `CompositeSink([DebugPrintSink(), DevToolsSink()])`
/// - profile: `DevToolsSink()`，保留低噪声性能诊断
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

  /// 组合根 — 根据 Flutter 构建模式初始化默认 sink.
  ///
  /// Debug 双路输出，Profile 仅写 DevTools，Release 使用 [NullSink]。必须在
  /// kernel 代码访问 [I] 之前调用。
  static void init() {
    // 启动入口和播放器服务都可能调用初始化；复用实例可避免替换已被组件持有的 logger。
    if (_instance != null) return;

    final mode = kDebugMode
        ? KernelBuildMode.debug
        : kProfileMode
        ? KernelBuildMode.profile
        : KernelBuildMode.release;
    _instance = KernelLoggerImpl(createDefaultLogSink(mode));
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
    _sink.log(
      LogLevel.error,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void fatal(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _sink.log(
      LogLevel.fatal,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
