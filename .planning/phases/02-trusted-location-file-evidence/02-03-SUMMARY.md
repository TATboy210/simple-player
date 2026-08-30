---
phase: 02
plan: 03
subsystem: kernel-diagnostics
tags: [dart, flutter, diagnostics, trusted-location, file-evidence, privacy]
requires:
  - phase: 02-01
    provides: stable diagnostic pack formatter and immutable ErrorReport location field
  - phase: 02-02
    provides: trusted stored-stack extraction and build-gated source excerpt reader
provides:
  - Frozen basename-safe media path plus separate full current-media and failed-open developer evidence
  - Pre-effect immutable location/source enrichment with contained D-05 fallback
  - Diagnostic packs containing actual location, source lines, full current-media, and failed-open evidence
  - Terminal verbatim raw-stack preservation after enrichment and formatting
affects: [02-04, phase-03-error-card]
actuals:
  tokens: 6256
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns:
    - Intake snapshots full developer paths before ordinary basename redaction
    - Failed-open target and successfully current media remain separate immutable evidence
    - Synchronous contained location-enricher seam completes before queue/effect visibility
    - Formatter reads frozen report evidence only and preserves raw stack as terminal segment
key-files:
  created: []
  modified:
    - lib/kernel/diagnostics/error_report.dart
    - lib/kernel/diagnostics/error_reporter.dart
    - lib/kernel/diagnostics/player_error_report_bridge.dart
    - lib/kernel/diagnostics/diagnostic_pack_formatter.dart
    - test/diagnostics/error_report_test.dart
    - test/diagnostics/error_reporter_test.dart
    - test/diagnostics/diagnostic_pack_formatter_test.dart
key-decisions:
  - "D-07 stores fullMediaPath and failedOpenPath separately; ordinary mediaPath remains basename-safe for presentation and existing effects."
  - "ErrorContext.path is failed-open evidence, while PlayerErrorReportBridge snapshots PlaybackController current media independently."
  - "ErrorReporter enriches stored raw stack synchronously before _accept and _notifyEffects; extractor/reader failure degrades to a null D-05 location."
  - "formatDiagnosticPack renders frozen structured evidence and performs no live controller or filesystem lookup."
patterns-established:
  - "Developer-only evidence fields have explicit diagnostic-pack/copy-only documentation at the ErrorReport boundary."
  - "Dedupe may use a safe-redacted failed-open identity component without exposing full developer paths to ordinary consumers."
requirements-completed: [LOC-01, LOC-02, LOC-03, LOG-05]
coverage:
  - id: frozen-current-and-failed-open-paths
    description: "Reports freeze basename-safe ordinary media paths plus distinct full current-media and failed-open developer paths, preserving both through dedupe copyWith."
    requirement: LOC-03
    verification:
      - kind: test
        ref: test/diagnostics/error_report_test.dart#copyWith replaces occurrence metadata without changing identity data
        status: pass
      - kind: test
        ref: test/diagnostics/error_reporter_test.dart#freezes separate current-media and failed-open paths before redaction
        status: pass
      - kind: test
        ref: test/diagnostics/error_reporter_test.dart#keeps explicit player media path as current snapshot and context as failed open
        status: pass
      - kind: test
        ref: test/diagnostics/player_error_report_bridge_test.dart
        status: pass
    human_judgment: false
  - id:effect-ready-trusted-location
    description: "Effects receive the same already enriched immutable report containing stored-stack primary/secondary project frames and optional source excerpt evidence; enrichment failure degrades safely."
    requirement: LOC-01
    verification:
      - kind: test
        ref: test/diagnostics/error_reporter_test.dart#enriches frozen raw stack and source evidence before effects
        status: pass
      - kind: test
        ref: test/diagnostics/error_reporter_test.dart#contains enricher failure with explicit fallback before sibling effects
        status: pass
      - kind: test
        ref: test/diagnostics/source_line_reader_test.dart
        status: pass
    human_judgment: false
  - id:release-safe-source-degradation
    description: "Trusted source reading remains release no-I/O while reports retain location text and formatter-ready evidence."
    requirement: LOC-02
    verification:
      - kind: test
        ref: test/diagnostics/source_line_reader_test.dart#does no file access in release and degrades without a trusted root
        status: pass
    human_judgment: false
  - id:diagnostic-pack-actual-evidence
    description: "Shared formatter emits frozen current and failed-open full paths, location frames, numbered source lines, and terminal verbatim raw stack."
    requirement: LOG-05
    verification:
      - kind: test
        ref: test/diagnostics/diagnostic_pack_formatter_test.dart#renders location source and full path evidence without live lookups
        status: pass
      - kind: test
        ref: test/diagnostics/diagnostic_pack_formatter_test.dart#retains the raw stack character-for-character as terminal evidence
        status: pass
    human_judgment: false
duration: 12m 53s
completed: 2026-08-30
status: complete
---

# Phase 2 Plan 03: Effect-Ready Trusted Evidence Summary

已交付在 `ErrorReporter` intake 时冻结的 basename-safe 与完整 developer-path 双证据，并在每份 immutable report 进入 queue/effect 前完成可信位置和可选源码行富化；共享 formatter 仅依赖该冻结报告输出完整诊断包。

## Performance

- Duration: 12m 53s
- Started: 2026-08-30T13:55:47Z
- Completed: 2026-08-30T14:08:40Z
- Tasks: 2/2
- Files modified: 7

## Accomplishments

- `ErrorReport` 现明确分离 ordinary `mediaPath`、developer-only `fullMediaPath` 与 `failedOpenPath`，且 `copyWith` 完整保留这些 immutable evidence fields 以及已有 location/first occurrence identity。
- Reporter 在任何 basename redaction 前单次冻结 full current media；PlayerError context path 独立作为 failed-open evidence，避免打开失败的 B 覆盖已播放 A。
- `PlayerErrorReportBridge` 仅将 controller 的成功 current media 送入 ordinary/current snapshot；失败尝试仍由 `ErrorContext.path` 记录，保持语义清晰。
- 新增窄 `ErrorLocationEnricher` seam，默认使用 02-02 的 stored raw-stack extractor 与 trusted `SourceLineReader`；所有 enrichment failure 都在 reporter 内降级为 D-05 null location，effects 仍接收同一份完成的 immutable report。
- 共享 `formatDiagnosticPack` 输出 primary/secondary location、numbered source lines、full current-media 和 failed-open labels，同时继续将 raw stack 原样保留在末尾。

## Task Commits

1. `583e1f9f` — `feat(02-03): freeze developer media path evidence`
2. `719863e5` — `feat(02-03): enrich reports before diagnostic effects`

## Files Created/Modified

- `lib/kernel/diagnostics/error_report.dart` — 为 immutable report 定义并复制 current/failed-open full-path developer evidence。
- `lib/kernel/diagnostics/error_reporter.dart` — 在 intake-time 冻结路径、维护 safe dedupe identity、并于 `_accept`/`_notifyEffects` 前完成 contained location/source enrichment。
- `lib/kernel/diagnostics/player_error_report_bridge.dart` — 将成功 current-media snapshot 与 PlayerError failed-open context 分离。
- `lib/kernel/diagnostics/diagnostic_pack_formatter.dart` — 输出完整路径、可信 location/source evidence，保持 terminal raw stack contract。
- `test/diagnostics/error_report_test.dart` — 覆盖 copyWith 对全部 frozen evidence 的保持。
- `test/diagnostics/error_reporter_test.dart` — 覆盖 current-vs-failed-open、single snapshot、bounded evidence、effect order 和 enrichment degradation。
- `test/diagnostics/diagnostic_pack_formatter_test.dart` — 覆盖真实 full-path/location/source rendering 及 raw-stack terminal preservation。

## Decisions Made

- D-07 的诊断包/复制完整路径只进入 `fullMediaPath` 与 `failedOpenPath`；ordinary `mediaPath` 继续是 basename-safe，presentation/effect 的现有隐私边界不改变。
- failed-open 目标不能伪装成成功 current media：bridge 读取 current media，reporter 独立冻结 `ErrorContext.path`。
- D-05 enrichment 以 stored raw stack 为唯一输入，在 effect fan-out 前完成；失败只减少证据，不中断 intake 或 sibling effects。
- Formatter 只读已冻结 `ErrorReport`，不回查 controller 或 filesystem，因此 pack 能可靠重放报告捕获瞬间的证据。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 保留 failed-open 的安全语义去重区分**
- **Found during:** Task 1
- **Issue:** 将 `ErrorContext.path` 从 ordinary current-media path 中分离后，具有相同 message/code/current media、但不同 failed-open target 的连续 reports 会错误合并。
- **Fix:** 在 dedupe identity 中加入 `failedOpenPath` 的 basename-safe redacted component，完整路径仍不暴露给 ordinary consumers。
- **Files modified:** `lib/kernel/diagnostics/error_reporter.dart`, `test/diagnostics/error_reporter_test.dart`
- **Verification:** focused reporter/bridge tests passed；ordinary `mediaPath` remains basename-safe。
- **Committed in:** `583e1f9f`

**2. [Rule 1 - Bug] 修复 bounded developer path 超出声明上限**
- **Found during:** Task 1
- **Issue:** 原有 `_bounded` 在截断后追加 marker，导致 4096-character full-path limit 实际增长超过上限。
- **Fix:** reserve marker length before substring so every bounded developer path is at or below its declared maximum.
- **Files modified:** `lib/kernel/diagnostics/error_reporter.dart`, `test/diagnostics/error_reporter_test.dart`
- **Verification:** bounded path assertion and focused diagnostics tests passed.
- **Committed in:** `583e1f9f`

**Total deviations:** 2 auto-fixed (Rule 1: 2).
**Impact:** 修复 dedupe correctness 和 bounded-memory guarantee，未扩大计划架构或隐私 surface。

## Issues Encountered

- Task 1 RED tests initially failed as expected because `ErrorReport` had no full current/failed-open evidence fields.
- Task 2 RED tests initially failed as expected because reporter had no location-enricher seam and formatter had not rendered structured evidence.
- Focused `flutter analyze` completed without errors but reported nine pre-existing `prefer_initializing_formals` infos in constructor initializer style; no new analyzer errors were introduced.

## User Setup Required

None.

## Next Phase Readiness

- 02-04 can attach the already effect-ready `ErrorLogFileSink` at startup without revisiting live playback state, source filesystem, or formatting logic.
- Phase 3 ErrorCard/copy features can consume the safe ordinary path for UI and invoke the same formatter for developer evidence.
- The report now guarantees stable full current/failed-open semantics even after playback changes or source/effect processing occurs.

## Verification Results

- PASS — `D:/flutter/bin/flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/player_error_report_bridge_test.dart`
- PASS — `D:/flutter/bin/flutter test test/diagnostics/error_reporter_test.dart test/diagnostics/diagnostic_pack_formatter_test.dart`
- PASS — `D:/flutter/bin/flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/player_error_report_bridge_test.dart test/diagnostics/diagnostic_pack_formatter_test.dart test/diagnostics/source_line_reader_test.dart`
- PASS — `D:/flutter/bin/flutter analyze` over the modified diagnostics/test files (0 errors; existing initializer-style infos only).
- PASS — `bash tool/audit/kernel_logger_gate.sh`
- PASS — `git diff --check` and `git show --check` for `583e1f9f` and `719863e5`.
- PASS — acceptance criteria confirmed final location/source evidence precedes fan-out, failures degrade without losing reports or sibling effects, formatter reads frozen full-path/location/source evidence, and raw stack remains terminal/verbatim.

*Phase: 02-trusted-location-file-evidence, Completed: 2026-08-30*

## Self-Check: PASSED
