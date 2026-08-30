---
phase: 02
plan: 01
subsystem: kernel-diagnostics
 tags: [dart, flutter, diagnostics, durable-file-evidence, security]
requires:
  - phase: 01
    provides: immutable ErrorReport, ErrorReporter effect seam, bounded FIFO acceptance
provides:
  - Error/fatal ErrorReporter effect that durably appends UTF-8 diagnostic packs
  - Pure stable formatter with forged-section resistance and terminal raw-stack evidence
  - Injectable serialized writer seam with availability recovery and rate-limited degradation
  - Formatter-facing immutable ErrorLocation contract for later trusted-location enrichment
affects: [02-02, 02-03, 02-04, phase-03-error-card]
actuals:
  tokens: 5861
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - ErrorReporter effect -> pure formatter -> single Future-chain file writer
    - File.writeAsString append + UTF-8 + flush for per-record evidence durability
    - CR/LF escaping for single-line fields while preserving terminal raw stack verbatim
key-files:
  created:
    - lib/kernel/diagnostics/error_location.dart
    - lib/kernel/diagnostics/diagnostic_pack_formatter.dart
    - lib/kernel/diagnostics/error_log_file_sink.dart
    - test/diagnostics/diagnostic_pack_formatter_test.dart
    - test/diagnostics/error_log_file_sink_test.dart
  modified:
    - lib/kernel/diagnostics/error_report.dart
key-decisions:
  - "D-08 uses ErrorReporter effects directly; ErrorLogFileSink does not attach to KernelLogger CompositeSink."
  - "D-06 uses direct dart:io append+UTF-8+flush writes, serialized by a non-poisoning Future chain."
  - "D-04 formats all non-stack fields as escaped one-line values and reserves the final raw-stack segment for verbatim evidence."
patterns-established:
  - "An ErrorLogWriter seam keeps filesystem failures deterministic and proves single-writer ordering without permission-dependent tests."
  - "The first and every 50th consecutive write failure is reported through contained KernelLogger facade output."
requirements-completed: [LOG-01, LOG-02, LOG-03, LOG-05]
coverage:
  - id: durable-reporter-effect
    description: "Accepted error/fatal reports flow through ErrorReporter effects into real temporary UTF-8 append+flush file evidence."
    requirement: LOG-01
    verification:
      - kind: test
        ref: test/diagnostics/error_log_file_sink_test.dart#persists an accepted platform report through the reporter effect
        status: pass
      - kind: test
        ref: test/diagnostics/error_log_file_sink_test.dart#appends UTF-8 records across sink instances in acceptance order
        status: pass
    human_judgment: false
  - id: presentation-independent-severity-filter
    description: "Only error/fatal evidence is queued; presentation flushing and dismissal do not affect persistence."
    requirement: LOG-02
    verification:
      - kind: test
        ref: test/diagnostics/error_log_file_sink_test.dart#writes only error and fatal reports independently of presentation
        status: pass
    human_judgment: false
  - id: resilient-single-writer
    description: "One Future chain preserves serialized writes, contains failures, restores availability, rate-limits degradation, and supports repeatable drain/dispose."
    requirement: LOG-03
    verification:
      - kind: test
        ref: test/diagnostics/error_log_file_sink_test.dart#contains write failures restores availability and rate-limits output
        status: pass
      - kind: test
        ref: test/diagnostics/error_log_file_sink_test.dart#rate-limits fifty consecutive failures and keeps drain reusable
        status: pass
      - kind: test
        ref: test/diagnostics/error_log_file_sink_test.dart#serializes concurrent writes in record order
        status: pass
    human_judgment: false
  - id: stable-safe-diagnostic-pack
    description: "A pure shared formatter has fixed == sections, escapes hostile single-line fields, and retains raw stack characters in the terminal segment."
    requirement: LOG-05
    verification:
      - kind: test
        ref: test/diagnostics/diagnostic_pack_formatter_test.dart#escapes hostile single-line values without creating extra sections
        status: pass
      - kind: test
        ref: test/diagnostics/diagnostic_pack_formatter_test.dart#retains the raw stack character-for-character as terminal evidence
        status: pass
    human_judgment: false
duration: 10m 20s
completed: 2026-08-30
status: complete
---

# Phase 2 Plan 01: Durable Diagnostic Evidence Summary

已交付从已接纳 `ErrorReport` 经 effect、共享安全 formatter 到真实 UTF-8 append+flush 文件的可等待诊断证据链，并锁定单写者失败隔离与恢复契约。

## Performance

- Duration: 10m 20s
- Started: 2026-08-30T13:19:02Z
- Completed: 2026-08-30T13:29:22Z
- Tasks: 2/2
- Files modified: 6

## Accomplishments

- 建立 `ErrorLocation` 不可变 formatter-facing contract，并以确定性 D-05 文本处理尚无可信项目帧的降级状态。
- 交付唯一的纯 `formatDiagnosticPack`：固定 `==` 分段、稳定字段顺序、单行 CR/LF escaping，以及永远置尾且原样保留的 raw stack。
- `ErrorLogFileSink.record` 可直接作为 `ErrorReportEffect` 注入；仅 error/fatal 进入独立 Future 链，每条写入以 append、UTF-8、flush 执行。
- 通过真实临时文件验证 reporter→effect→formatter→filesystem tracer、跨 sink 追加、中文 UTF-8、presentation 独立性及 severity filter。
- 通过注入 `ErrorLogWriter` 验证 max active write 为 1、调用顺序、失败不污染后续节点、`logsAvailable` 恢复、首个/每 50 次限流和可重复 drain/dispose。

## Task Commits

1. `66a1145c` — `test(02-01): add failing durable file sink tests`
2. `177df817` — `feat(02-01): persist accepted diagnostics to file`
3. `bf39712a` — `test(02-01): add formatter and sink failure tests`
4. `4ca8517f` — `feat(02-01): contain diagnostic file write failures`

## Files Created/Modified

- `lib/kernel/diagnostics/error_report.dart` — 添加可选的 immutable `ErrorLocation` 入口并让 `copyWith` 保留它。
- `lib/kernel/diagnostics/error_location.dart` — 定义 primary/secondary project frame 与后续 source-line evidence 的不可变值对象。
- `lib/kernel/diagnostics/diagnostic_pack_formatter.dart` — 生成供文件记录和未来复制共享的安全稳定纯文本诊断包。
- `lib/kernel/diagnostics/error_log_file_sink.dart` — 实现 error/fatal-only durable reporter effect、writer seam、availability 与失败 containment。
- `test/diagnostics/diagnostic_pack_formatter_test.dart` — 覆盖 CR/LF 分段伪造防护和 terminal raw-stack equality。
- `test/diagnostics/error_log_file_sink_test.dart` — 覆盖真实文件 tracer、UTF-8、顺序、并发、失败恢复、限流和 presentation 独立性。

## Decisions Made

- 诊断文件效果只连接现有 `ErrorReporter` effect seam，保持 `KernelLogger` CompositeSink 不变，符合 D-08。
- durability 通过 `dart:io File.writeAsString(mode: FileMode.append, encoding: utf8, flush: true)` 实现，符合 D-02/D-06；不新增包也不使用 logger `FileOutput`。
- 未信任字段统一转义 `\r` 与 `\n`；只有 raw stack 允许多行且始终是文件包最后一个 segment，满足 T-02-01。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 修复失败写入后 availability 未恢复与测试 writer 未触发**
- **Found during:** Task 2
- **Issue:** 初始 Future 链仅更新状态，未提供可注入 writer seam；测试 helper 默认 warning 也错误绕过 error/fatal filter。
- **Fix:** 添加 `ErrorLogWriter` seam、non-poisoning contained failure continuation、成功恢复 `logsAvailable`、命名的第 1/每 50 次失败限流以及默认 error test report。
- **Files modified:** `lib/kernel/diagnostics/error_log_file_sink.dart`, `test/diagnostics/error_log_file_sink_test.dart`
- **Verification:** focused formatter/sink tests、kernel logger audit、focused Flutter analysis all passed.
- **Commit:** `4ca8517f`

**Total deviations:** 1 auto-fixed (Rule 1: 1).
**Impact:** Required LOG-03 failure isolation became observable and fully covered without changing the planned architecture.

## Issues Encountered

- Task 1 RED test initially failed as expected because `ErrorLogFileSink` did not yet exist.
- Task 2 RED test initially failed as expected because the production sink did not yet expose its injectable writer seam.
- `gh search` returned a limited public Dart example and no reusable logging implementation; SDK `dart:io` remained the plan-mandated, repository-researched mechanism.

## User Setup Required

None. Plan 02-04 will resolve and wire the Application Support default path at composition root.

## Next Phase Readiness

- 02-02 can enrich the new `ErrorLocation` contract with trusted project frame extraction and source-line evidence.
- 02-03 can populate full media/failed-open evidence before the shared formatter runs.
- 02-04 can resolve the support-directory path and inject this sink into production startup while retaining its stable availability notifier.

## Verification Results

- PASS — `D:/flutter/bin/flutter test test/diagnostics/diagnostic_pack_formatter_test.dart test/diagnostics/error_log_file_sink_test.dart`
- PASS — `bash tool/audit/kernel_logger_gate.sh`
- PASS — `D:/flutter/bin/flutter analyze lib/kernel/diagnostics/error_report.dart lib/kernel/diagnostics/error_location.dart lib/kernel/diagnostics/diagnostic_pack_formatter.dart lib/kernel/diagnostics/error_log_file_sink.dart test/diagnostics/diagnostic_pack_formatter_test.dart test/diagnostics/error_log_file_sink_test.dart`
- PASS — acceptance checks confirmed direct `ErrorReportEffect` signature, append/UTF-8/flush semantics, fixed raw-stack final segment, no `package:logger` or new kernel `debugPrint`, and source-level failure/availability/drain controls.

*Phase: 02-trusted-location-file-evidence, Completed: 2026-08-30*

## Self-Check: PASSED
