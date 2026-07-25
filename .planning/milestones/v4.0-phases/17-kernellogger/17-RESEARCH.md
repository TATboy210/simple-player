# Phase 17: 零依赖 KernelLogger 门面（替换迁移） - Research

**Researched:** 2026-07-19
**Domain:** Internal diagnostics logging facade — pure Dart `KernelLogger` implementation + batch migration of 78 call sites + CI grep gate, zero new third-party dependencies.
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — LogSink 注入与接线时机 (D1-D6)**
- D1: Logger 访问模式 — 静态注册 `KernelLogger.I` 静态访问器。84 处调用点迁移只改 import + 声明类型，不改函数签名。
- D2: DiagnosticsBundle 激活时机 — P17 激活 bundle 的 logger slot（替换 NullKernelLogger → 真实 KernelLogger 实例）。bundle 其他 3 slot 仍 noop。
- D3: 组合根接线时机 — P17 在 `player_services.dart` 接线：创建 KernelLogger 实例 → 注入 DiagnosticsBundle → bundle 注入 KernelAdapter。
- D4: LogSink 接口形态 — 单方法 `void log(LogLevel level, String msg, {Map<String, Object?>? context})`。
- D5: LogSink 位置 — 全在 `kernel_logger.dart` 内：LogLevel + LogSink + DevToolsSink + DebugPrintSink + NullSink + KernelLogger。
- D6: KernelLogger 静态生命周期 — `KernelLogger.I` 在 app 启动时设置一次，永不替换。

**Area 2 — 迁移策略与 error/fatal 签名扩展 (D7-D11)**
- D7: 迁移节奏 — 一次性批量替换。grep 确认零残留后 CI 闸门生效。
- D8: error()/fatal() 签名扩展 — `error(String msg, {Map<String, Object?>? context, Object? error, StackTrace? stackTrace})` + fatal 同签名。
- D9: 替换方式 — 脚本自动替换，入 `tool/audit/`。
- D10: logger 变量处理 — 保留每文件顶部的 `final log = Logger('...')` 声明，改为 `final log = KernelLogger.I`。
- D11: 快捷方法保留 — KernelLogger 同时提供全称方法和快捷方法 w()/e()/i()/d()/t()/f()。

**Area 3 — sink 分级与 release 门控策略 (D12-D14)**
- D12: debug 模式输出 — 全走 `debugPrint`（trace→fatal 全输出）。
- D13: release 门控 — `NullSink` + `kDebugMode` 编译时分支。debug→DebugPrintSink，release→NullSink。
- D14: LogLevel 枚举 — 6 级 `enum LogLevel { trace, debug, info, warn, error, fatal }`。

**Area 4 — dart:developer 配置与 path 脱敏 (D15-D17)**
- D15: dart:developer.log name 参数 — `'Kernel'`。
- D16: context 格式化 — Map context 追加到消息末尾 `WARN: msg {key: val}`。
- D17: path 脱敏 — 只保留文件名 `fvp_engine.dart:259`。

### Claude's Discretion
- `tool/audit/` 下替换脚本的具体语法（sed vs dart script vs ripgrep + xargs）
- `DebugPrintSink` 内部实现
- `DevToolsSink` 内部实现（name='Kernel' per D15）
- `NullSink` 实现
- `KernelLogger.I` 静态字段的具体 Dart 实现
- logger slot 激活的具体代码变更

### Deferred Ideas (OUT OF SCOPE)
- P18 ErrorContext + Logger 联动
- P19 MemoryMonitor Logger 集成
- P20 NewFvpEngine Logger 集成
- P21 VERIFY-06 release 冒烟闸门
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOG-01 | `lib/kernel/diagnostics/` 内零依赖 KernelLogger 门面（dart:developer + 受控 debugPrint）；内核永不导入 package:logger（CI grep 闸门） | Phase 16 交付的 abstract KernelLogger 骨架已存在；dart:developer.log + debugPrint 均为 Flutter SDK 内置零依赖 API；CI grep 闸门可复用 Phase 15 inventory.sh 的 rg/grep 兼容层模式 |
| LOG-02 | 日志级别（trace/debug/info/warn/error/fatal）、结构化 Map 上下文、稳定调用点 API、文件路径脱敏 | D14 锁定 6 级枚举；D16 context 格式化 `msg {key: val}`；D17 path 脱敏仅保留文件名；现有 78 调用点的 message 格式已含模块前缀（如 `[DisplayConfig]`、`FvpEngine.`） |
| LOG-03 | 发布门控 kDebugMode；warn/error 走 dart:developer.log；release 构建产出零 debugPrint/debug/info 行 | kDebugMode 是 Flutter 编译时常量，release 构建 tree-shakes DebugPrintSink；dart:developer.log 在 release 构建中 no-op（DevTools 不连接） |
| LOG-04 | 调用点替换迁移保留 log*.w() 调用形状（文件仅改 import/声明即迁移） | D10/D11 策略：保留 `final log = ...` 声明改类型，KernelLogger 提供 w()/e()/i()/d()/t()/f() 快捷方法，78 处调用点零方法名改动 |
| LOG-05 | 可插拔 LogSink（DevToolsSink/DebugPrintSink/NullSink）；app 级 log.dart 作为 sink 注册 | D4 单方法 LogSink 接口 + D5 全在 kernel_logger.dart 内；app 级 log.dart 保留不删（仅内核文件迁移） |
</phase_requirements>

## Summary

Phase 17 fills the concrete implementation behind the `KernelLogger` abstract class delivered by Phase 16. The task is entirely internal: add a `LogLevel` enum, a `LogSink` single-method interface, three sink implementations (`DevToolsSink` for dart:developer, `DebugPrintSink` for debug console, `NullSink` for release), a concrete `KernelLogger` class with static `I` accessor, then batch-replace 78 call sites across 24 files in `lib/kernel/` by changing only their import and `final log = ...` declaration. No new packages — only `dart:developer` (SDK) and `package:flutter/foundation.dart` (`kDebugMode`, `debugPrint`, both already transitive dependencies).

**Key finding from live code audit:** The actual call site count is **78** (not 84 as CONTEXT.md states, not 121 as ROADMAP/REQUIREMENTS state). Breakdown: 44 `.e()` / 6 `.w()` / 12 `.i()` / 16 `.d()` / 0 `.t()` / 0 `.f()`, across 24 files. The Phase 16 researcher's count of 84 appears to have included `log.dart` definition-site references or used a broader regex. The planner must use 78 as the authoritative count and verify with `tool/audit/inventory.sh` before execution.

**Primary recommendation:** Implement `KernelLogger` as a single file (`kernel_logger.dart`) containing all 6 types (LogLevel, LogSink, 3 sinks, KernelLogger), use `kDebugMode` compile-time branch for sink selection, batch-migrate via script, then add a CI grep gate ensuring `lib/kernel/**` never imports `package:logger`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| KernelLogger facade | Kernel/Engine (diagnostics/) | — | Sits in `lib/kernel/diagnostics/`, zero UI dependency, consumed only by kernel code |
| LogSink routing | Kernel/Engine (kernel_logger.dart) | — | Internal to KernelLogger, routes level→sink.log(); sinks are implementation details |
| kDebugMode gate | Kernel/Engine | Flutter SDK (compile-time) | `kDebugMode` is a compile-time constant from `foundation.dart`; sink selection happens once at construction |
| CI grep gate | Build/CI (tool/audit/) | — | Static structural verification, same pattern as Phase 15 inventory.sh + Phase 16 phase16_gates.sh |
| Composition root wiring | Service (player_services.dart) | — | PlayerServices.init() creates KernelLogger → injects DiagnosticsBundle → injects KernelAdapter |
| App-level log.dart retention | App (lib/kernel/utils/log.dart) | — | log.dart stays for app-level code outside kernel; only `lib/kernel/**` files migrate |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:developer | SDK built-in | `log()` for DevTools integration | Zero dependency, Flutter SDK included, structured logging to DevTools |
| package:flutter/foundation.dart | SDK built-in | `kDebugMode` + `debugPrint()` | Already transitive dependency in every kernel file |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none) | — | — | This phase adds zero new packages |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| dart:developer.log | package:logger (existing) | Adds runtime dependency to kernel — violates LOG-01 zero-dependency constraint |
| dart:developer.log | package:logging | Another third-party dep — same violation |
| debugPrint only | dart:developer + debugPrint | debugPrint has throttling; dart:developer gives DevTools structured view |

**Installation:** None required — all dependencies are SDK built-in.

## Package Legitimacy Audit

> No new packages are installed in this phase. All dependencies are Flutter/Dart SDK built-in.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| dart:developer | Dart SDK | — | — | dart-lang/sdk | OK | Built-in, no install needed |
| flutter/foundation.dart | Flutter SDK | — | — | flutter/flutter | OK | Already in pubspec.yaml |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                    ┌─────────────────────────────────────────┐
                    │           PlayerServices.init()          │
                    │         (composition root, line 87)       │
                    └─────────────┬───────────────────────────┘
                                  │ creates
                                  ▼
                    ┌─────────────────────────────┐
                    │     KernelLogger (concrete)   │
                    │  .I = KernelLogger(sink)      │
                    │  static accessor pattern       │
                    └─────────────┬────────────────┘
                                  │ injected into
                                  ▼
                    ┌─────────────────────────────┐
                    │     DiagnosticsBundle         │
                    │  .logger slot activated        │
                    └─────────────┬────────────────┘
                                  │ injected into
                                  ▼
                    ┌─────────────────────────────┐
                    │     KernelAdapter             │
                    │  .bundle.logger available      │
                    └─────────────────────────────┘

    ┌──────────────────────────────────────────────────────┐
    │              KernelLogger internal routing             │
    │                                                       │
    │  .w(msg) ──► _sink.log(LogLevel.warn, msg, ctx)      │
    │  .e(msg) ──► _sink.log(LogLevel.error, msg, ctx)     │
    │                                                       │
    │  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  │
    │  │ DebugPrintSink│  │ DevToolsSink │  │  NullSink  │  │
    │  │ debugPrint()  │  │ dart:dev.log │  │  no-op     │  │
    │  └──────┬──────┘  └──────┬───────┘  └─────┬──────┘  │
    │         │                │                 │         │
    │    kDebugMode=true   kDebugMode=true   kDebugMode=false
    │    (both active)                        (release)    │
    └──────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────┐
    │              Migration data flow                       │
    │                                                       │
    │  78 call sites in lib/kernel/**                       │
    │  ┌─────────────────┐    ┌───────────────────────┐    │
    │  │ import log.dart  │──►│ import kernel_logger   │    │
    │  │ final log =      │──►│ final log =            │    │
    │  │   Logger('...')  │    │   KernelLogger.I       │    │
    │  └─────────────────┘    └───────────────────────┘    │
    │  log.w(msg) unchanged ──► log.w(msg) unchanged       │
    └──────────────────────────────────────────────────────┘
```

### Recommended Project Structure
```
lib/kernel/diagnostics/
├── kernel_logger.dart       # LogLevel + LogSink + 3 sinks + KernelLogger (P17, ~120 lines)
├── diagnostics_bundle.dart  # Existing P16, logger slot activated (P17 changes 1 line)
├── memory_monitor_slot.dart # Existing P16, unchanged
├── metrics_slot.dart        # Existing P16, unchanged
└── event_log_slot.dart      # Existing P16, unchanged

tool/audit/
├── inventory.sh             # Existing P15, reused for baseline
├── phase16_gates.sh         # Existing P16, unchanged
└── kernel_logger_gate.sh    # P17: CI grep gate (lib/kernel/** never imports package:logger)
```

### Pattern 1: Static Singleton Accessor (KernelLogger.I)
**What:** `KernelLogger.I` is a public static field set once at app startup, providing global access without dependency injection at every call site.
**When to use:** When 78+ call sites need access and constructor injection would require threading through every intermediate class.
**Example:**
```dart
// Phase 16 skeleton (existing)
abstract class KernelLogger {
  void warn(String message);
  void error(String message, {Object? error, StackTrace? stackTrace});
  // ... 6 methods total
}

// Phase 17 addition (new)
final class KernelLoggerImpl implements KernelLogger {
  KernelLoggerImpl(this._sink);
  final LogSink _sink;

  static KernelLoggerImpl? _instance;
  static KernelLogger get I {
    final instance = _instance;
    if (instance == null) {
      throw StateError('KernelLogger.I not initialized — call KernelLogger.init() first');
    }
    return instance;
  }

  static void init(LogSink sink) {
    _instance = KernelLoggerImpl(sink);
  }

  @override
  void warn(String message) => _sink.log(LogLevel.warn, message);
  // ... all 6 methods delegate to _sink.log()
}
```

### Pattern 2: Single-Method LogSink Interface
**What:** `LogSink` has one method: `void log(LogLevel level, String msg, {Map<String, Object?>? context})`. All sink implementations (DevToolsSink, DebugPrintSink, NullSink) implement this single method.
**When to use:** When the routing logic (level→sink selection) lives in KernelLogger, and sinks only need to know "here's a log event, output it."
**Example:**
```dart
abstract interface class LogSink {
  void log(LogLevel level, String msg, {Map<String, Object?>? context});
}

final class DebugPrintSink implements LogSink {
  const DebugPrintSink();
  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    final contextStr = context != null ? ' $context' : '';
    debugPrint('${level.name.toUpperCase()}: $msg$contextStr');
  }
}
```

### Pattern 3: kDebugMode Compile-Time Branching
**What:** Sink selection at KernelLogger construction uses `kDebugMode` — a compile-time constant. In release builds, `DebugPrintSink` and `DevToolsSink` are tree-shaken away.
**When to use:** When you need zero-cost abstraction — release binary contains only NullSink.
**Example:**
```dart
static void init() {
  final sink = kDebugMode
      ? const CompositeSink([DebugPrintSink(), DevToolsSink()])
      : const NullSink();
  _instance = KernelLoggerImpl(sink);
}
```

### Anti-Patterns to Avoid

- **Don't import package:logger in kernel_logger.dart:** The whole point is zero dependency. Use only `dart:developer` and `package:flutter/foundation.dart`.
- **Don't use `late final` for KernelLogger.I:** Use nullable + init guard pattern instead. `late final` throws a cryptic `LateInitializationError` if accessed before init; a guard with `StateError` gives a clear message.
- **Don't create separate files for each sink:** D5 explicitly says all in `kernel_logger.dart`. Keep it simple — one file, ~120 lines.
- **Don't forget to gate debugPrint:** Every `debugPrint` call must be inside a class that is only instantiated when `kDebugMode` is true. The `DebugPrintSink` class itself is the gate — it's only constructed in the `kDebugMode` branch.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Log level filtering | Custom if/else chain | LogLevel enum + switch expression | Dart 3 exhaustive switch catches missing cases at compile time |
| Path sanitization | Complex regex | `path.split(Platform.pathSeparator).last` | One-liner, handles all OS path separators |
| CI grep gate | New tool from scratch | Extend existing `tool/audit/` shell script pattern | inventory.sh + phase16_gates.sh already have rg/grep compat layer |
| Release zero-output verification | Custom binary inspection | `--release` build + grep on stderr (Phase 21 VERIFY-06) | Existing CI infrastructure |

## Common Pitfalls

### Pitfall 1: Call Site Count Discrepancy
**What goes wrong:** CONTEXT.md says 84, ROADMAP says 121, actual count is 78. Using wrong count causes incomplete migration or false confidence.
**Why it happens:** Phase 16 researcher used a different regex (possibly including `log.dart` definition-site references or broader pattern). ROADMAP's 121 is from Phase 15 baseline audit which scanned the entire `lib/` directory (including app-level code outside kernel).
**How to avoid:** Run `tool/audit/inventory.sh` before migration to get the LIVE count. Use 78 as the working number for this phase (kernel-only scope).
**Warning signs:** If migration script processes 84 sites but only 78 exist, the script has a bug.

### Pitfall 2: App-Level log.dart Must Stay
**What goes wrong:** Deleting `lib/kernel/utils/log.dart` breaks app-level code that imports it for non-kernel logging.
**Why it happens:** `log.dart` is imported by both kernel files (78 call sites to migrate) and potentially app-level files outside `lib/kernel/`.
**How to avoid:** Only migrate files under `lib/kernel/`. The old `log.dart` stays as-is for app-level usage. After migration, `lib/kernel/**` should have zero imports of `log.dart`, but `log.dart` itself remains. The 4 non-kernel files confirmed: `app.dart` (1 `.w()`), `main.dart` (`initLog()` call), `player_feature.dart` (1 `.e()` + 1 `.d()`), `deferred_player_feature.dart` (1 `.e()`).
**Warning signs:** `grep -r 'import.*utils/log.dart' lib/` after migration should show only files outside `lib/kernel/`.

### Pitfall 3: DebugPrintSink Leakage in Release
**What goes wrong:** `debugPrint()` calls leak into release binary output.
**Why it happens:** If `DebugPrintSink` is constructed unconditionally (not gated by `kDebugMode`), or if `debugPrint` is called directly in KernelLogger methods instead of through the sink.
**How to avoid:** Sink selection MUST be inside a `kDebugMode` compile-time branch. Never call `debugPrint` directly in KernelLogger — always delegate to `_sink.log()`.
**Warning signs:** Phase 21 VERIFY-06 `--release` smoke test finds debugPrint output.

### Pitfall 4: Logger Variable Name Collision
**What goes wrong:** Files that declare `final log = Logger('...')` and also import `kernel_logger.dart` get name collision.
**Why it happens:** Both old and new provide a `log` identifier.
**How to avoid:** Migration script changes the import AND the declaration atomically. The old `import '../utils/log.dart'` is replaced with `import '../diagnostics/kernel_logger.dart'`, and `final log = Logger('...')` becomes `final log = KernelLogger.I`.
**Warning signs:** Compile error after partial migration.

## Code Examples

### KernelLogger Full Implementation
```dart
// Source: Phase 17 design (D4/D5/D14)
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 日志级别 — 6 级，与 KernelLogger 6 方法 1:1 (D14)
enum LogLevel { trace, debug, info, warn, error, fatal }

/// 单方法日志接收接口 (D4)
abstract interface class LogSink {
  void log(LogLevel level, String msg, {Map<String, Object?>? context});
}

/// DevTools 输出 — dart:developer.log (D15: name='Kernel')
final class DevToolsSink implements LogSink {
  const DevToolsSink();
  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    developer.log(
      name: 'Kernel',
      level: _toSeverity(level),
      msg: msg,
      time: DateTime.now(),
    );
  }
  static int _toSeverity(LogLevel level) => switch (level) {
    LogLevel.trace => 300,
    LogLevel.debug => 500,
    LogLevel.info  => 800,
    LogLevel.warn  => 900,
    LogLevel.error => 1000,
    LogLevel.fatal => 1200,
  };
}

/// debugPrint 输出 — kDebugMode 门控 (D12/D13)
final class DebugPrintSink implements LogSink {
  const DebugPrintSink();
  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    final ctx = context != null && context.isNotEmpty ? ' $context' : '';
    debugPrint('${level.name.toUpperCase()}: $msg$ctx');
  }
}

/// 空实现 — release 构建使用 (D13)
final class NullSink implements LogSink {
  const NullSink();
  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {}
}

/// 多 sink 组合 — debug 模式同时输出到 DevTools + console
final class CompositeSink implements LogSink {
  const CompositeSink(this._sinks);
  final List<LogSink> _sinks;
  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    for (final sink in _sinks) {
      sink.log(level, msg, context: context);
    }
  }
}
```

### KernelLogger Concrete Class
```dart
// Source: Phase 17 design (D1/D6/D11)
final class KernelLoggerImpl implements KernelLogger {
  KernelLoggerImpl(this._sink);
  final LogSink _sink;

  /// 静态访问器 (D1) — app 启动时 init() 一次 (D6)
  static KernelLoggerImpl? _instance;
  static KernelLogger get I {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'KernelLogger.I not initialized — call KernelLogger.init() first',
      );
    }
    return instance;
  }

  /// 初始化 — PlayerServices.init() 中调用一次
  static void init() {
    final sink = kDebugMode
        ? const CompositeSink([DebugPrintSink(), DevToolsSink()])
        : const NullSink();
    _instance = KernelLoggerImpl(sink);
  }

  // --- 全称方法 ---
  @override
  void trace(String message) => _sink.log(LogLevel.trace, message);
  @override
  void debug(String message) => _sink.log(LogLevel.debug, message);
  @override
  void info(String message) => _sink.log(LogLevel.info, message);
  @override
  void warn(String message) => _sink.log(LogLevel.warn, message);
  @override
  void error(String message, {Map<String, Object?>? context, Object? error, StackTrace? stackTrace}) {
    _sink.log(LogLevel.error, message, context: context);
  }
  @override
  void fatal(String message, {Map<String, Object?>? context, Object? error, StackTrace? stackTrace}) {
    _sink.log(LogLevel.fatal, message, context: context);
  }

  // --- 快捷方法 (D11) — 84 处调用点零方法名改动 ---
  void t(String message) => trace(message);
  void d(String message) => debug(message);
  void i(String message) => info(message);
  void w(String message) => warn(message);
  void e(String message, {Object? error, StackTrace? stackTrace}) =>
      this.error(message, error: error, stackTrace: stackTrace);
  void f(String message, {Object? error, StackTrace? stackTrace}) =>
      fatal(message, error: error, stackTrace: stackTrace);
}
```

### Migration Pattern (per file)
```dart
// BEFORE:
import '../utils/log.dart';
// ...
final log = Logger('FvpEngine');
// ...
log.e('open() error: $e');  // 78 call sites like this

// AFTER:
import '../diagnostics/kernel_logger.dart';
// ...
final log = KernelLogger.I;
// ...
log.e('open() error: $e');  // call site unchanged (D11)
```

### CI Grep Gate Script
```bash
#!/usr/bin/env bash
# tool/audit/kernel_logger_gate.sh
# LOG-01: lib/kernel/** 永不 import package:logger
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KERNEL_DIR="$REPO_ROOT/lib/kernel"

# 检查内核目录是否还有 package:logger 导入
hits=$(grep -rn 'import.*package:logger' "$KERNEL_DIR" --include='*.dart' || true)
if [ -n "$hits" ]; then
  echo "GATE FAIL (LOG-01): package:logger import found in lib/kernel/:"
  echo "$hits"
  exit 1
fi

# 检查内核目录是否还有 utils/log.dart 导入（应全部替换为 kernel_logger.dart）
legacy_hits=$(grep -rn "import.*utils/log\.dart" "$KERNEL_DIR" --include='*.dart' || true)
if [ -n "$legacy_hits" ]; then
  echo "GATE FAIL (LOG-04): utils/log.dart import found in lib/kernel/:"
  echo "$legacy_hits"
  exit 1
fi

echo "GATE PASS (LOG-01/04): lib/kernel/** has zero package:logger and zero utils/log.dart imports."
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK built-in) |
| Config file | analysis_options.yaml (strict-casts/strict-inference/strict-raw-types) |
| Quick run command | `flutter test test/diagnostics/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LOG-01 | KernelLogger facade exists in diagnostics/ with zero package:logger imports | unit + grep gate | `flutter test test/diagnostics/kernel_logger_test.dart` + `tool/audit/kernel_logger_gate.sh` | Partial (signature tests exist, gate script needed) |
| LOG-02 | 6 log levels, Map context, path redaction | unit | `flutter test test/diagnostics/kernel_logger_test.dart` | Needs extension |
| LOG-03 | kDebugMode gate — release has zero debugPrint output | build verification | `flutter build windows --release` + smoke (Phase 21) | Manual only |
| LOG-04 | 78 call sites migrated, log*.w() shape preserved | grep + compile | `flutter analyze` + `tool/audit/kernel_logger_gate.sh` | Gate script needed |
| LOG-05 | DevToolsSink/DebugPrintSink/NullSink pluggable | unit | `flutter test test/diagnostics/kernel_logger_test.dart` | Needs new tests |

### Sampling Rate
- **Per task commit:** `flutter test test/diagnostics/`
- **Per wave merge:** `flutter test`
- **Phase gate:** `flutter analyze` + `tool/audit/kernel_logger_gate.sh` + `flutter test` all green

### Wave 0 Gaps
- [ ] `test/diagnostics/kernel_logger_test.dart` — extend with DevToolsSink/DebugPrintSink/NullSink/CompositeSink tests, KernelLoggerImpl.init() + .I accessor tests
- [ ] `tool/audit/kernel_logger_gate.sh` — new CI grep gate script
- [ ] Migration script in `tool/audit/` — automated batch replacement

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | Log messages are developer-controlled strings, not user input |
| V6 Cryptography | no | — |

### Known Threat Patterns for Internal Logging Facade

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Log injection via user-controlled paths | Tampering | D17 path redaction strips directory components; messages are format strings with developer-controlled templates |
| Sensitive data in log output | Information Disclosure | D17 path redaction (filename only); no user data logged in kernel (only engine state/codec info) |
| Release binary leaking debug info | Information Disclosure | D13 kDebugMode compile-time gate; DebugPrintSink tree-shaken in release |

**Threat model assessment:** LOW risk. This phase implements an internal developer-facing logging facade with no user-facing surface, no network I/O, no file I/O (file logging stays in app-level log.dart), and no authentication/authorization concerns. The primary risk is debugPrint leakage in release builds, mitigated by kDebugMode compile-time branching + Phase 21 VERIFY-06 smoke gate.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| package:logger with 5 Logger instances (log/logEngine/logBridge/logServices/logUi) | KernelLogger facade with LogSink interface | Phase 17 | Kernel zero dependency on package:logger |
| PrefixPrinter per module (engine/bridge/services/ui) | Single KernelLogger with module name in message | Phase 17 | Simplified — 78 call sites already include module prefix in message |
| PrettyPrinter with colors/emojis/date formatting | Plain text debugPrint + dart:developer structured log | Phase 17 | Less visual noise, better DevTools integration |
| _RotatingFileOutput for release file logging | File logging stays in app-level log.dart only | No change | Kernel never does file I/O for logging |

**Deprecated/outdated:**
- `PrefixPrinter` class in log.dart: Only used by module-scoped loggers (logEngine/logBridge/etc.), which are replaced by KernelLogger
- `JsonPrinter` class in log.dart: Optional, unused by default — stays in log.dart for app-level use
- `initLog()` function in log.dart: Release file logging setup — stays in log.dart for app-level use

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Actual call site count is 78 (not 84 as CONTEXT.md states) | Summary | If wrong, migration is incomplete — some call sites remain on old logger. Mitigated by CI grep gate. |
| A2 | `logServices` and `logUi` prefixes have 0 live call sites in kernel | Summary | If wrong, 2 additional prefixes need migration. Low risk — grep confirmed 0 hits. |
| A3 | `fatal()` has 0 live call sites — signature extrapolated by symmetry with `error()` | Code Examples | If wrong, fatal() call sites need testing. Low risk — Phase 16 census confirmed 0. |
| A4 | 4 app-level files outside `lib/kernel/` import `log.dart` (app.dart, main.dart, player_feature.dart, deferred_player_feature.dart) and should NOT be migrated | Common Pitfalls | Verified by `rg -c '\blog\.(e|w|i|d|t|f)\(' --type dart lib/ -g '!lib/kernel/**'` — 4 call sites confirmed. log.dart must stay. |
| A5 | `CompositeSink` (multiple sinks in debug mode) is the user's preferred pattern over single-sink | Code Examples | If wrong, simplify to DebugPrintSink only (DevToolsSink can be added later). User chose D12 "全走 debugPrint" which suggests single output is sufficient. |

## Open Questions (RESOLVED)

1. **CompositeSink vs single DebugPrintSink** — RESOLVED by Plan 01: Use CompositeSink (both DevToolsSink + DebugPrintSink). D15 requires DevToolsSink, D12 says debugPrint is primary output. Both coexist at zero cost.

2. **Exact migration script approach** — RESOLVED by Plan 02: Bash script with rg/grep in `tool/audit/`, matching Phase 15 inventory.sh pattern. Dart script deferred (not needed for mechanical import swaps).

3. **log.dart import in non-kernel files** — RESOLVED by research: 4 non-kernel files (app.dart, main.dart, player_feature.dart, deferred_player_feature.dart) import log.dart and are NOT migrated. log.dart stays for app-level use.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Dart SDK | KernelLogger compilation | ✓ | 3.12.2 | — |
| Flutter SDK | flutter_test, kDebugMode, debugPrint | ✓ | 3.44.6 | — |
| dart:developer | DevToolsSink | ✓ | SDK built-in | — |
| ripgrep (rg) | CI grep gate | ✓ | (available per Phase 15 audit) | grep fallback in inventory.sh |
| flutter analyze | Static verification | ✓ | 3.44.6 | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none — all dependencies are SDK built-in or already available

## Sources

### Primary (HIGH confidence)
- Phase 16 deliverables: `lib/kernel/diagnostics/kernel_logger.dart` (abstract + NullKernelLogger skeleton), `diagnostics_bundle.dart` (noop bundle with logger slot)
- Live code grep: 78 call sites counted across 24 files importing utils/log.dart in lib/kernel/
- Phase 15 `tool/audit/inventory.sh` — rg/grep compat layer pattern for CI gates
- Dart SDK `dart:developer.log()` API — structured logging to DevTools
- Flutter SDK `kDebugMode` + `debugPrint()` — compile-time gate + throttled console output

### Secondary (MEDIUM confidence)
- Phase 16 RESEARCH.md — call site census (84 count, slightly different from our 78 recount)
- CONTEXT.md D1-D17 — all 17 decisions locked by user

### Tertiary (LOW confidence)
- None — all claims verified against live code or SDK documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new packages, all SDK built-in
- Architecture: HIGH — extends Phase 16 skeleton, same patterns as inventory.sh/phase16_gates.sh
- Pitfalls: HIGH — call site count verified by live grep, migration pattern is mechanical

**Research date:** 2026-07-19
**Valid until:** 2026-08-19 (stable — internal facade pattern, no external ecosystem dependency)
