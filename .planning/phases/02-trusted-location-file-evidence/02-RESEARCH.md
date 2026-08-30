# Phase 2: 可信定位与文件证据 - Research

**Researched:** 2026-08-30
**Domain:** Dart/Flutter stack-trace frame extraction, source-line reading, durable UTF-8 file append (desktop Windows), diagnostic-pack formatting
**Confidence:** HIGH (core library semantics verified from installed package sources + live probes in this repo)

## Summary

Phase 2 extends the Phase-1 diagnostics pipeline (`ErrorReport` → `ErrorReporterImpl` effects) with (a) location enrichment — first `package:simple_player_flutter` frame + ≤2 secondary frames, ±2 source lines in debug/profile — and (b) an error/fatal-only file sink writing a segmented plain-text diagnostic pack to `getApplicationSupportDirectory()/logs/error.log`.

Two verified findings materially shape the plan:

1. **logger 2.7.0 `FileOutput` cannot satisfy D-02 (即时写/掉电不丢) as-is.** Reading the installed source (`logger-2.7.0/lib/src/outputs/file_output.dart`): `init()` opens one long-lived `IOSink` via `file.openWrite(mode: FileMode.writeOnlyAppend, encoding: utf8)`; `output()` only does `_sink?.writeAll(event.lines, '\n')` with **no flush**; flush happens solely in `destroy()`. The `IOSink _sink` field is private, so a subclass cannot flush per record either. Per-record durability requires either direct `dart:io` writes (`writeAsString(mode: FileMode.append, flush: true)`) or an accepted data-loss window.
2. **The existing structural gate blocks importing `package:logger` into the kernel.** `tool/audit/kernel_logger_gate.sh` GATE 1 fails on any `import.*package:logger` under `lib/kernel/` — its sole exception `lib/kernel/utils/log.dart` no longer exists (dir contains only debug_exporter/debug_probe/path_utils/time_utils). A `FileSink` in `lib/kernel/diagnostics/` that imports `package:logger` **fails the audit gate**. The 30-line append logic is trivially reimplemented in `dart:io`, which also resolves finding 1.

Net recommendation: **drop the logger-package dependency for this phase; implement a project-owned `FileSink` (LogSink impl or reporter effect) on `dart:io` with a chained-Future single-writer queue and `flush: true` per record.** This satisfies D-02 exactly, passes GATE 1 unchanged, removes a dead dependency path, and is more Unix (软件杠杆 inverted: the "mature lib" here is `dart:io` itself). Because PROJECT.md records "FileOutput 方案" as a locked decision, this needs explicit user confirmation before planning locks it in (see Assumptions A1 / Open Questions Q1).

**Primary recommendation:** New `lib/kernel/diagnostics/` files — `error_location.dart` (frame extraction + source-line reader, sealed `ErrorLocation`), `diagnostic_pack_formatter.dart` (pure function, LOG-05), `error_log_file_sink.dart` (dart:io single-writer sink, LOG-01/03) wired as an `ErrorReportEffect` in the composition root; extend `ErrorReport` with optional `ErrorLocation? location`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** debug/profile 下随报告展示定位行 ±2 行（共 5 行）；前提 = 源码根信任校验通过（containment check）且源码可读；release / 越界 / 不可读时优雅降级为仅定位文本，不报错不闪退
- **D-02:** 即时写——每条 error/fatal 报告立即 UTF-8 追加落盘；洪流场景由上游有界 FIFO + 时间窗去重控制（Phase 1 已建），FileSink 不再叠加批量缓冲；掉电不丢已写记录
- **D-03:** 默认落点 = `getApplicationSupportDirectory()/logs/error.log`（path_provider，不用 exe 目录/进程 cwd）；单文件 UTF-8 追加，跨会话累积（轮转已 Out of Scope）；用户可配置路径留待 Phase 4 接入
- **D-04:** 分段式纯文本——`==` 段标题 + 字段行（report ID / 来源 / 时序 / 媒体快照 / 定位 / 可选源码行 / 重复信息 / raw stack / 日志路径），人类直接可读可复制；卡片复制与文件记录使用同一 formatter 输出
- **D-05:** 定位字段 = 首个 `package:simple_player_flutter` 帧（文件:行:成员）+ 后续最多 2 个项目帧；raw stack 全文始终保留在诊断包尾部；提取失败时降级为「无项目帧，完整栈见 raw stack」定位文本，不产生新错误

### Claude's Discretion
- 源码根路径的界定方式（编译时断言 vs 运行时探测，researcher 定）
- StackFrame.fromStackTrace 解析失败的具体兜底形态
- FileSink 挂入 CompositeSink 的组装细节与写失败限流节流参数
- 诊断包各段的确切标题文案与字段顺序

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOC-01 | StackFrame.fromStackTrace 提取首个项目帧，raw stack 全程保留 | Verified StackFrame API shape (fields, parsing pitfalls, pre-filter requirement) — see Architecture Patterns 1–2 |
| LOC-02 | 可信源码根 containment check；debug/profile 读源码行，release 降级 | `Isolate.resolvePackageUri` unusable in Flutter (probed: throws UnsupportedError) → self-anchored root capture design; kReleaseMode gate |
| LOC-03 | 媒体路径快照 + failed-open 尝试路径 | Phase 1 intake already snapshots `mediaPath ?? context?.path` (error_reporter.dart:174) and `PlaybackController.currentPath` notifier exists (playback_controller.dart:76); remaining work = contract surfacing in pack |
| LOG-01 | error/fatal-only FileSink，UTF-8 单文件追加 | Verified FileOutput semantics; GATE 1 conflict; dart:io alternative |
| LOG-02 | 仅错误上盘；落盘独立于卡片可见性 | Wire as reporter effect / severity filter before presentation coupling |
| LOG-03 | 单写者串行队列、失败非致命、限流降级 | Chained-Future queue pattern; degradation channel constraints (release gate greps debugPrint) |
| LOG-04 | path_provider 默认位置，配置路径写入前校验 | Verified path_provider_windows naming + null/MAX_PATH cases |
| LOG-05 | 稳定诊断包格式，卡片复制与文件同格式 | Pure formatter module; redactor reuse points identified |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Frame extraction (LOC-01) | Kernel (`lib/kernel/diagnostics/`) | — | Pure Dart string/stack logic, no UI, no platform |
| Source-line reading (LOC-02) | Kernel | dart:io (file read) | Needs `kDebugMode` gating + filesystem; containment policy is kernel-owned |
| Media snapshot (LOC-03) | Kernel (reporter intake) | — | Already owned by `ErrorReporterImpl._createReport` via `CurrentMediaPathProvider` |
| File append (LOG-01/02/03) | Kernel (diagnostics) | dart:io | Single-writer durability logic; UI-independent |
| Default log location (LOG-04) | Composition root (`main.dart`) | path_provider plugin | Async plugin call at startup; kernel receives resolved path (kernel must not await plugin at static-init time) |
| Diagnostic pack format (LOG-05) | Kernel (pure formatter) | Phase 3 UI (copy) | Formatter is a pure function consumed by both file sink and future card |
| Degraded "日志不可用" status | Kernel | Phase 3 card (display) | Status ValueNotifier on sink; card display is Phase 3 |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/foundation `StackFrame` | Flutter 3.47.0 (SDK) | Frame parsing from stored raw stack string | Already imported everywhere; no new dep; verified field shape from SDK source [VERIFIED: D:/flutter/packages/flutter/lib/src/foundation/stack_frame.dart:22-278] |
| dart:io File | SDK | Append + flush + mkdir | The only dependency-free way to meet D-02 per-record flush [VERIFIED: logger source shows FileOutput cannot] |
| path_provider | 2.1.6 (already in pubspec:22) | `getApplicationSupportDirectory()` | Locked by D-03; Windows impl verified below |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| logger | ^2.7.0 (already in pubspec:27, currently unused) | — | **Not recommended for this phase** (see Summary); consider removing from pubspec in a later cleanup phase |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| dart:io direct append | logger 2.7.0 `FileOutput` | FileOutput verified to not flush per record and is banned by GATE 1 inside `lib/kernel/`; only viable if gate amended AND durability requirement weakened [VERIFIED: pub cache source] |
| Self-anchored source root | `Isolate.resolvePackageUri` | Throws `Unsupported operation: Isolate.resolvePackageUriSync` in Flutter (probed live) — unusable [VERIFIED: probe in this repo] |

**Installation:** None. All dependencies already present and version-locked in `pubspec.lock`. No new packages → no slopsquat surface.

## Package Legitimacy Audit

**No new external packages are installed by this phase.** Existing deps verified from local pub cache:

| Package | Registry | Version | Source | Verdict | Disposition |
|---------|----------|---------|--------|---------|-------------|
| logger | pub.dev | 2.7.0 (in cache, `^2.7.0` pubspec:27) | github.com/EronildoB/logger-janth | OK (already locked; NOT used this phase) | Not installed |
| path_provider / path_provider_windows | pub.dev | 2.1.6 / 2.3.0 (in cache) | flutter/packages (first-party) | OK | Approved (existing) |
| stack_trace | not needed | — | — | — | Avoided: `StackFrame` (foundation) covers parsing; adding `package:stack_trace` would trip the documented `fromStackTraceLine` assert on chain-formatted traces [VERIFIED: stack_frame.dart:196-201] |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
Error sources (Phase 1, unchanged)
  FlutterError.onError / PlatformDispatcher / runZonedGuarded / PlayerError bridge
        │
        ▼
ErrorReporterImpl._reportSafely          [kernel/diagnostics/error_reporter.dart]
  ├─ _createReport: redact + bound + snapshot mediaPath        (existing)
  ├─ _accept: FIFO(5) + 10s window dedupe                      (existing)
  │      ▼
  │  ErrorReport (immutable; + NEW optional location fields)
  │      ▼
  └─ _notifyEffects ──► Effects list (injectable, each isolated)  ← NEW WIRING
                          │
                          ├─► FileSinkEffect (error/fatal only)      [NEW]
                          │     ├─ DiagnosticPackFormatter.format()   [NEW, pure]
                          │     │    ├─ ErrorLocationExtraction       [NEW, pure]
                          │     │    │    └─ SourceLineReader (debug/profile only,
                          │     │    │         containment check, ±2 lines)
                          │     │    └─ DiagnosticRedactor reuse (existing)
                          │     └─ SingleWriterFileWriter (dart:io)
                          │          chained Future → writeAsString(append, flush:true)
                          │          on failure: rate-limited degraded output
                          │          + "logs unavailable" status notifier
                          ▼
                    logs/error.log (UTF-8, append, cross-session)
```

Entry point: every accepted error/fatal report. Decision points: severity filter (error/fatal only), build-mode gate (LOC-02), containment check, write-success/failure branch. External dependency: filesystem only.

### Recommended Project Structure
```
lib/kernel/diagnostics/
├── error_location.dart              # NEW: sealed ErrorLocation + frame extractor (LOC-01/05)
├── source_line_reader.dart          # NEW: containment check + ±2 line read (LOC-02)
├── diagnostic_pack_formatter.dart   # NEW: pure ErrorReport → segmented text (LOG-05)
├── error_log_file_sink.dart         # NEW: single-writer append + degraded status (LOG-01/03)
├── error_log_location.dart          # NEW: default path resolution seam (LOG-04)
└── error_report.dart                # MODIFY: add optional location/sourceLines fields
main.dart                            # MODIFY: resolve support dir → construct sink → inject effect
test/diagnostics/                    # mirrors lib (existing 8 test files are the convention)
```

### Pattern 1: Frame extraction with pre-filtered parsing (LOC-01, D-05)
**What:** Parse the *stored* `rawStackTrace` string (not a live stack) into frames, tolerate malformed input.
**When to use:** Enrichment pass after report acceptance.
**Critical verified mechanics:**
- `StackFrame` fields are `packageScheme` / `package` / `packagePath` / `line` / `column` / `className` / `method` / `source` — there is **no `uri` getter** [VERIFIED: stack_frame.dart:255-278].
- `fromStackString` splits on `\n`, maps each line through `fromStackTraceLine`, then `whereType<StackFrame>()` silently drops nulls — but `fromStackTraceLine` for VM frames (`#`-prefixed) uses the regex `^#(\d+) +(.+) \((.+?):?(\d+){0,1}:?(\d+){0,1}\)$` followed by `match = match!` with only an **assert** guarding it [VERIFIED: stack_frame.dart:208-211]. A malformed `#` line therefore *throws* (AssertionError in debug / null-check error in release) rather than being dropped. **Pre-filter each line with the same regex before calling the API, or wrap the whole parse in `on Object`.**
- `<asynchronous suspension>` and `...` lines parse into sentinel frames with `line: -1`, `package: ''` — filter these out when locating project frames [VERIFIED: stack_frame.dart:41-62].
- Project-frame match predicate: `f.package == 'simple_player_flutter'` covers `package:` frames; `file:` frames arrive as `packageScheme: 'file'`, `package: '<unknown>'`, `packagePath: '/D:/simple_player_flutter/...'` (Uri.path form, leading slash, forward slashes) [VERIFIED: live probe in this repo].

```dart
// Pre-filter prevents fromStackTraceLine's match! throw on malformed lines.
final framePattern = RegExp(r'^#(\d+) +(.+) \((.+?):?(\d+){0,1}:?(\d+){0,1}\)$');
List<StackFrame> parseFrames(String rawStack) {
  try {
    final parsable = rawStack
        .split('\n')
        .where((l) => l.startsWith('#') && framePattern.hasMatch(l))
        .join('\n');
    return StackFrame.fromStackString(parsable)
        .where((f) => f.line >= 0) // drop <asynchronous suspension>/elision sentinels
        .toList(growable: false);
  } on Object {
    return const [];
  }
}
```

### Pattern 2: Self-anchored source root + containment (LOC-02, discretion item)
**What:** `Isolate.resolvePackageUri` is unusable in Flutter (probe: `Unsupported operation: Isolate.resolvePackageUriSync`). Resolve source files without it:
- `file:`-scheme frames already carry an absolute path in `packagePath` (`/D:/...` → normalize to `D:/...` by stripping the single leading `/` on Windows drive paths) [VERIFIED: probe].
- For `package:simple_player_flutter/...` frames (expected dominant form under `flutter run` debug — [ASSUMED], see A2), capture the **project root once at sink/locator init**: take `StackTrace.current`, find a `file:` frame whose path ends with `/lib/kernel/diagnostics/`, and define root = path up to and including `/` before `lib/`. Then map `package:simple_player_flutter/<path>` → `<root>/lib/<path>`.
**Containment:** canonicalize (forward slashes, case-insensitive drive compare on Windows), require the resolved file path to start with the captured root, reject any `..` segment, and `File.existsSync()` as the final gate. Any failure → return null → degraded "仅定位文本" (D-01/D-05).
**Release:** gate the whole reader on `kReleaseMode == false` before any filesystem work; in release the pack carries location text only (D-01).

### Pattern 3: Single-writer durable append (LOG-01/03, D-02)
**What:** Serialize writes on a Future chain; each record flushed before the next starts.

```dart
// Single-writer queue: writes are ordered, each fs-flushed (掉电不丢), non-blocking UI isolate.
Future<void> _pending = Future<void>.value();

void enqueue(String pack) {
  _pending = _pending
      .then((_) => _file.writeAsString(pack, mode: FileMode.append,
          encoding: utf8, flush: true))
      .then((_) => _consecutiveFailures = 0)
      .catchError((Object e, StackTrace st) {
        if (++_consecutiveFailures == 1 || _consecutiveFailures % 50 == 0) {
          _degradedOutput(e, st); // rate-limited; build-mode gated, see Pitfall 4
        }
        _logsAvailable.value = false; // "日志不可用" status for Phase 3 card
      });
}

Future<void> dispose() => _pending; // bounded close/drain: await in-flight record
```
Error/fatal filter sits *before* enqueue (LOG-02: debug/info never touch the file, independent of card visibility).

### Pattern 4: Diagnostic pack formatter (LOG-05, D-04)
One pure top-level function `String formatDiagnosticPack(ErrorReport report, {String? logPath})` emitting `==` segment headers exactly per D-04 order. Field values containing newlines (from `message` / raw stack) are confined to their own segments; single-line field values must have embedded `\n`/`\r` escaped so a hostile message cannot forge a segment header. Reuse `DiagnosticRedactor` — note `mediaPath` is **already** basename-redacted at intake (`error_reporter.dart:380-383`), so the formatter must not redact a second time (idempotent in practice but don't double-apply to raw stack, which contains `file:///D:/...` frames that `redactDiagnosticText` would mangle — pass raw stack through verbatim; it is a locked Phase-1 full-preservation field).

### Anti-Patterns to Avoid
- **Parsing the live `StackTrace.current` instead of the stored string** — the report is the frozen evidence; re-parsing stored `rawStackTrace` keeps dedupe/merge identity stable.
- **Buffering in the sink** — D-02 explicitly forbids batch buffering upstream of the file; the Future chain is an ordering device, not a buffer (max 1 record in flight).
- **Awaiting path_provider inside kernel static init** — `KernelLoggerImpl.init()`/`ErrorReporterImpl.init()` are sync; resolve the directory in `main.dart` and inject the path.
- **Calling `StackFrame.fromStackString` on unfiltered input** — throws on malformed `#` lines (see Pattern 1).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stack line parsing | Custom regex-from-scratch frame parser | `StackFrame.fromStackString` (foundation) with pre-filter | Battle-tested regex handles constructor/closure/async variants; verified source in SDK |
| Path redaction | New privacy pass for pack | `DiagnosticRedactor.redactPathValue` / `redactDiagnosticText` | Phase-1 locked policy; fuzz-tested |
| File append durability | Custom buffering/rotation | `dart:io writeAsString(flush: true)` + mkdir | OS-level flush is the durability primitive; rotation is Out of Scope (D-03) |
| Log context serialization | — | `serializeLogContext` (existing) if pack needs structured context | Stable-key, cycle-safe, already tested |

**Key insight:** every "hard" sub-problem here (parsing, redaction, flush) already has a verified primitive in the SDK or Phase-1 code; the phase's actual work is wiring + degradation policy, not algorithms.

## Common Pitfalls

### Pitfall 1: FileOutput append ≠ durable append
**What goes wrong:** Using logger's `FileOutput` and assuming "即时追加" — writes go into an unflushed `IOSink`; process crash or power loss loses everything since last OS-managed buffer drain.
**Why it happens:** `output()` has no flush; only `destroy()` flushes [VERIFIED: file_output.dart:29-46].
**How to avoid:** direct `writeAsString(..., flush: true)` per record.
**Warning signs:** log file missing the last N records after a crash-repro cycle.

### Pitfall 2: Gate conflict on `package:logger`
**What goes wrong:** Importing `package:logger` in `lib/kernel/diagnostics/error_log_file_sink.dart` fails `tool/audit/kernel_logger_gate.sh` GATE 1 (LOG-01 structural gate).
**Why it happens:** Gate predates Phase 2; its only exclusion file `lib/kernel/utils/log.dart` was deleted.
**How to avoid:** dart:io implementation (recommended) or amend the gate with a new exclusion (requires justification).
**Warning signs:** audit script exit 1 on Phase-2 files.

### Pitfall 3: StackFrame parse throw on foreign stack formats
**What goes wrong:** Stack traces that reached the reporter through `FlutterError.demangleStackTrace` gaps (e.g., `package:stack_trace` chain format with `===== asynchronous gap =====`) contain `#` lines the VM regex rejects → `match!` throws inside `fromStackTraceLine` [VERIFIED: stack_frame.dart:196-211].
**How to avoid:** pre-filter per Pattern 1; treat zero parsed frames as the D-05 degraded path, never an error.
**Warning signs:** analyzer-clean tests pass but a real `runZonedGuarded` capture crashes the reporter.

### Pitfall 4: Degraded debugPrint trips the release gate
**What goes wrong:** LOG-03's "限流 debugPrint" fallback, if unconditional, leaks `debugPrint(` strings into the AOT snapshot and fails `tool/audit/phase21_release_gate.sh` (`LEAK_PATTERNS="debugPrint|\.debug\(|KernelLogger\.debug|debugPrint("` [VERIFIED: phase21_release_gate.sh:49]).
**How to avoid:** degraded channel is build-mode gated: debug/profile → rate-limited `DebugPrintSink`-style output (precedent: `DebugPrintSink` already calls `debugPrint` inside `lib/kernel/diagnostics/kernel_logger.dart:274`, and the documented kernel grep gate `grep -rn 'debugPrint(' lib/kernel/` — docs/audit/cicd-configuration-plan.md:152 — demonstrably tolerates that sink); release → `developer.log` (same as `ErrorReporterImpl._defaultLastResortOutput`) or silence.
**Warning signs:** release-gate script fails after Phase 2 lands.

### Pitfall 5: Double redaction / mangling raw stack
**What goes wrong:** Running the formatter output through `redactDiagnosticText` rewrites `file:///D:/simple_player_flutter/...` frames in the raw-stack segment, destroying the "raw stack 全文保留" guarantee (D-05) and the identity used by dedupe tests.
**How to avoid:** redact only at intake (already done in `_createReport`); formatter copies fields verbatim.
**Warning signs:** pack raw-stack segment shows basenames instead of paths.

### Pitfall 6: path_provider returning null / MAX_PATH overflow
**What goes wrong:** `getApplicationSupportPath()` can return null (known-folder failure) or skip directory creation when the composed path exceeds MAX_PATH [VERIFIED: path_provider_windows_real.dart:250-263] → first write crashes.
**How to avoid:** null-check + explicit `Directory(dir).create(recursive: true)` for the `logs/` child at startup; on resolution failure enter "日志不可用" state immediately (that *is* the LOG-03 degraded path, not an exception).
**Warning signs:** crash only on machines with long user profiles.

## Code Examples

### ErrorReport contract extension (minimal, additive)
```dart
// error_report.dart — new optional field keeps all existing tests compiling.
final class ErrorReport {
  const ErrorReport({ ..., this.location });          // NEW
  /// 首个项目帧 + ≤2 次级帧 + 可选源码行；null = 定位降级 (D-05)。
  final ErrorLocation? location;                       // NEW
}

final class ErrorLocation {
  const ErrorLocation({
    required this.primaryFrame,       // 'file:line:member' bounded string
    required this.secondaryFrames,    // ≤2 entries
    this.sourceLines,                 // debug/profile only, 5 lines with numbers
    required this.sourceRootTrusted,  // containment result, for pack display
  });
}
```
Note `copyWith` currently only covers `lastOccurredAt`/`occurrenceCount` (error_report.dart:92-106) — enrichment happens before queue insertion in `_createReport`, so no copyWith extension is strictly needed.

### Default log path (LOG-04)
```dart
// Windows result (verified from path_provider_windows 2.3.0 source):
// %APPDATA%\<CompanyName>\<ProductName>  (fallback: exe basename if no CompanyName;
//  ProductName falls back to exe name; directory auto-created if path ≤ MAX_PATH)
final support = await getApplicationSupportDirectory(); // may return path with dir created
final logsDir = Directory('${support.path}/logs');
await logsDir.create(recursive: true); // idempotent; catch FileSystemException → degraded state
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Isolate.resolvePackageUri` for package→path | Unusable in Flutter (throws); self-anchored root capture | Verified this session | LOC-02 must not rely on it |
| logger `FileOutput` for append logs | `File.writeAsString(flush: true)` per record | Verified this session | Meets D-02; avoids GATE 1 |
| `package:stack_trace` Trace parsing | foundation `StackFrame` | Long-standing | No new dependency; but pre-filter required |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dropping logger-`FileOutput` in favor of dart:io append is acceptable despite PROJECT.md recording "FileOutput 方案" as a locked decision | Summary / LOG-01 | Plan contradicts a recorded decision; needs user confirmation (discuss-phase or checkpoint) |
| A2 | Under `flutter run` debug, project lib frames appear as `package:simple_player_flutter/...` (test-mode probes showed `file:///` for the test file itself; lib frame could not be observed due to inlining) | Pattern 2 / LOC-02 | If frames are `file:` instead, Pattern 2's file-path branch already handles it — design is form-agnostic, low risk |
| A3 | AOT release stack traces lack reliable line numbers, so kReleaseMode short-circuit loses nothing | Pattern 2 | None material — D-01 mandates release degradation regardless |

## Open Questions (RESOLVED)

1. **FileOutput vs dart:io (A1)** — PROJECT.md Key Decisions records the logger-FileOutput plan; research shows it cannot meet D-02 (no per-record flush) and is banned by GATE 1 inside kernel. Recommendation: dart:io + remove logger from pubspec in a later cleanup. Needs user sign-off since it revises a locked decision.
   - **已解决 / RESOLVED（D-06）：** 采用直接 `dart:io` `File.writeAsString(..., mode: FileMode.append, flush: true)` + 单写者 Future 队列；见 [02-CONTEXT.md](./02-CONTEXT.md) D-06。
2. **Media path granularity in the pack (LOC-03)** — Phase-1 policy basename-redacts `mediaPath` at intake (error_reporter.dart:380-383), so the pack's 媒体快照 segment will show a basename, not the full path. Success criterion says "报告冻结发生时的当前媒体路径" — confirm basename-only satisfies it or whether full path is desired for this developer-only tool (redaction would then need a policy carve-out).
   - **已解决 / RESOLVED（D-07）：** 诊断包与复制输出携带完整媒体路径，普通日志维持 basename 脱敏；见 [02-CONTEXT.md](./02-CONTEXT.md) D-07。
3. **FileSink dual attachment** — CONTEXT lists both "error_reporter fan-out 新增 FileSink" and "kernel_logger CompositeSink error/fatal 分流". Recommended primary: reporter effect (it owns the rich ErrorReport); raw `KernelLogger.e/f` passthrough to the same file is optional. Planner should pick one, not both, to keep single-writer trivial.
   - **已解决 / RESOLVED（D-08）：** FileSink 通过 `ErrorReporter` 副作用链挂接，不走 `KernelLogger` `CompositeSink` 分流；见 [02-CONTEXT.md](./02-CONTEXT.md) D-08。

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | everything | ✓ | 3.47.0 stable (D:/flutter) | — |
| path_provider_windows | LOG-04 | ✓ | 2.3.0 (pub cache) | — |
| dart:io | LOG-01/03 | ✓ | SDK | — |
| Windows RoamingAppData known folder | LOG-04 | ✓ (dev machine) | — | "日志不可用" degraded state (designed-in) |

**Missing dependencies with no fallback:** none.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + fake_async 1.3.3 (already used) |
| Config file | none (convention: mirror lib path under test/) |
| Quick run command | `flutter test test/diagnostics/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LOC-01 | First-project-frame extraction from stored raw stack; malformed stacks degrade, never throw | unit (synthetic stack strings: normal/async-gap/malformed/foreign-package/empty) | `flutter test test/diagnostics/error_location_test.dart` | ❌ Wave 0 |
| LOC-02 | ±2 source lines read under containment; traversal (`..`), out-of-root, unreadable, line-out-of-range all degrade; kReleaseMode short-circuit | unit (temp fixture files via `Directory.systemTemp`) | `flutter test test/diagnostics/source_line_reader_test.dart` | ❌ Wave 0 |
| LOC-03 | mediaPath/failed-open path frozen at intake and rendered verbatim in pack | unit | `flutter test test/diagnostics/error_reporter_test.dart` (extend) | ✅ extend |
| LOG-01 | error/fatal-only append; debug/info never written; UTF-8 (Chinese) content; append across sink instances | integration w/ real temp files | `flutter test test/diagnostics/error_log_file_sink_test.dart` | ❌ Wave 0 |
| LOG-02 | Persistence independent of presentation/dismiss (dismiss card → record already on disk) | unit | `flutter test test/diagnostics/error_reporter_test.dart` (extend) | ✅ extend |
| LOG-03 | Write-failure injection (unwritable dir / file-as-directory) → non-fatal, rate-limited degraded output, "日志不可用" status flips; drain completes on dispose | unit (failure-injected writer port) | `flutter test test/diagnostics/error_log_file_sink_test.dart` | ❌ Wave 0 |
| LOG-04 | Default path = supportDir/logs/error.log; null support dir / long path → degraded state; no exe-dir/cwd use | unit (injected path-provider seam) | `flutter test test/diagnostics/error_log_location_test.dart` | ❌ Wave 0 |
| LOG-05 | Pack format: exact `==` segment order per D-04, same output used by file and (future) copy; newline-forging message cannot inject segment headers | unit (golden-style string assertions) | `flutter test test/diagnostics/diagnostic_pack_formatter_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/diagnostics/`
- **Per wave merge:** `flutter test` + `flutter analyze` (0-error red line) + `bash tool/audit/kernel_logger_gate.sh`
- **Phase gate:** full suite green + both audit gates before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/diagnostics/error_location_test.dart`
- [ ] `test/diagnostics/source_line_reader_test.dart`
- [ ] `test/diagnostics/error_log_file_sink_test.dart` (needs an injectable writer-port so failure injection doesn't depend on real FS permissions)
- [ ] `test/diagnostics/diagnostic_pack_formatter_test.dart`
- [ ] `test/diagnostics/error_log_location_test.dart`
- [ ] Injected `ErrorLogWriter`/path-provider ports defined in `error_reporting_dependencies.dart` (existing seams file)

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | Pre-filtered frame regex; log-path containment for Phase-4 config (validate writable + no traversal before first write); newline escaping in pack field values |
| V6 Cryptography | no | — |
| V2/V3/V4 | no | No auth/session/access surfaces in this phase |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Log forging via error message containing `\n== ` | Tampering | Escape CR/LF in single-line field values; raw-stack confined to its terminal segment |
| Path traversal via configurable log path (Phase 4 preview) | Elevation | Containment check against resolved support dir before first write; reuse PathValidator philosophy |
| Sensitive paths in evidence file (media filenames, source paths) | Information Disclosure | Phase-1 `DiagnosticRedactor` policy at intake; pack is copy-verbatim — do not re-redact; document that error.log itself contains redacted basenames |
| Unbounded log growth | DoS (self) | Explicitly Out of Scope (轮转, D-03); note in plan as accepted |

## Sources

### Primary (HIGH confidence)
- Installed source: `logger-2.7.0/lib/src/outputs/file_output.dart` (pub cache) — append/flush semantics
- Installed source: `path_provider_windows-2.3.0/lib/src/path_provider_windows_real.dart:119-263` — support-dir naming, auto-create, MAX_PATH null
- SDK source: `D:/flutter/packages/flutter/lib/src/foundation/stack_frame.dart:22-278` — StackFrame API + parser behavior
- Repo source: `lib/kernel/diagnostics/{error_report,error_reporter,error_reporting_dependencies,diagnostic_redactor,kernel_logger}.dart`, `tool/audit/kernel_logger_gate.sh`, `tool/audit/phase21_release_gate.sh`
- Live probes (this repo, this session): StackFrame output forms in flutter test; `Isolate.resolvePackageUri` UnsupportedError

### Secondary (MEDIUM confidence)
- docs/audit/cicd-configuration-plan.md:152 — documented kernel debugPrint grep gate

### Tertiary (LOW confidence)
- AOT release stack-trace form (A3) — training knowledge, mitigated by design

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every library behavior read from installed sources
- Architecture: HIGH — all integration points read from Phase-1 code this session
- Pitfalls: HIGH — each pitfall traces to verified source or a run probe; A2 is the single [ASSUMED] with a form-agnostic design

**Research date:** 2026-08-30
**Valid until:** 2026-09-29 (stable local stack; no fast-moving deps)
