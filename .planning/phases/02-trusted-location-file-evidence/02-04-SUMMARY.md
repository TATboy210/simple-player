---
phase: 02
plan: 04
subsystem: kernel-diagnostics
tags: [dart, flutter, diagnostics, path-provider, durable-file-evidence, startup]
requires:
  - phase: 02-01
    provides: durable ErrorReporter file-sink writer and shared diagnostic-pack formatter
  - phase: 02-02
    provides: trusted stored-stack location and source evidence contracts
  - phase: 02-03
    provides: effect-ready immutable enriched ErrorReport evidence
provides:
  - Application Support-only default diagnostic location at logs/error.log
  - Hooks-first reporter startup with an identity-stable delegating durable-file effect
  - Stable read-only log availability and resolved-path listenables for Phase 3
  - Contained pending, path-provider, directory, and writer activation degradation
  - Production wiring of accepted error/fatal reports to the existing append-and-flush sink
affects: [phase-03-error-card, phase-04-settings, phase-05-verification]
actuals:
  tokens: 6547
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns:
    - Composition root installs ErrorReporter and GlobalErrorHooks before async platform path resolution
    - Delegating effect retains reporter callback and ValueListenable identity while its concrete sink activates late
    - Typed Application Support path result contains provider/filesystem failures without a fallback path
key-files:
  created:
    - lib/kernel/diagnostics/error_log_location.dart
    - test/diagnostics/error_log_location_test.dart
  modified:
    - lib/main.dart
    - lib/kernel/diagnostics/error_log_file_sink.dart
    - lib/kernel/diagnostics/error_reporter.dart
    - lib/kernel/diagnostics/error_reporting_dependencies.dart
    - test/diagnostics/global_error_hooks_test.dart
key-decisions:
  - "D-03 default location is exclusively getApplicationSupportDirectory()/logs/error.log; no cwd, executable, home, or last-known-good fallback exists."
  - "D-08 production persistence remains an ErrorReporter effect, not a KernelLogger CompositeSink responsibility."
  - "A stable unavailable delegating effect is constructed before hooks; successful activation changes only its internal writer and notifier values."
  - "Pending or failed activation never blocks MediaKit, window initialization, runApp, or the global capture chain."
patterns-established:
  - "DiagnosticLogStatus exposes only read-only availability and nullable-path listenables; future UI code does not acquire writer mutation access."
  - "An activated DiagnosticLogSink forwards availability changes into the same public ValueNotifier rather than replacing listener identity."
requirements-completed: [LOG-01, LOG-02, LOG-03, LOG-04, LOG-05]
coverage:
  - id: application-support-default-location
    description: "The sole default location is an idempotently prepared Application Support/logs/error.log target, with typed containment of provider and filesystem failures."
    requirement: LOG-04
    verification:
      - kind: test
        ref: test/diagnostics/error_log_location_test.dart#creates and resolves support/logs/error.log idempotently
        status: pass
      - kind: test
        ref: test/diagnostics/error_log_location_test.dart#returns unavailable when the support provider throws
        status: pass
      - kind: test
        ref: test/diagnostics/error_log_location_test.dart#returns unavailable when the support path is a file
        status: pass
      - kind: test
        ref: test/diagnostics/error_log_location_test.dart#does not use process or executable fallback locations
        status: pass
    human_judgment: false
  - id: hooks-first-stable-file-effect
    description: "Reporter and global hooks are ready before path-provider I/O; pending or failed activation preserves capture, while successful activation retains effect and status identities and writes new error evidence."
    requirement: LOG-01
    verification:
      - kind: test
        ref: test/diagnostics/global_error_hooks_test.dart#declares hooks-first diagnostic file startup ordering in main source
        status: pass
      - kind: test
        ref: test/diagnostics/global_error_hooks_test.dart#keeps capture available while location resolution is pending
        status: pass
      - kind: test
        ref: test/diagnostics/global_error_hooks_test.dart#activates the same delegate and status listenables after resolution
        status: pass
      - kind: command
        ref: D:/flutter/bin/flutter test test/diagnostics/
        status: pass
    human_judgment: false
  - id: presentation-independent-and-resilient-startup-persistence
    description: "The existing severity-filtered, serialized append-and-flush sink remains independently owned by ErrorReporter and activation failures remain unavailable rather than recursively reporting."
    requirement: LOG-02
    verification:
      - kind: test
        ref: test/diagnostics/error_log_file_sink_test.dart#writes only error and fatal reports independently of presentation
        status: pass
      - kind: test
        ref: test/diagnostics/global_error_hooks_test.dart#keeps capture live when diagnostic file activation never occurs
        status: pass
      - kind: command
        ref: bash tool/audit/kernel_logger_gate.sh
        status: pass
    human_judgment: false
  - id: stable-availability-and-path-contract
    description: "Phase 3 can observe the same read-only availability and nullable-path listenables across unavailable, pending, and active states without retaining a filesystem writer."
    requirement: LOG-03
    verification:
      - kind: test
        ref: test/diagnostics/global_error_hooks_test.dart#activates the same delegate and status listenables after resolution
        status: pass
      - kind: test
        ref: test/diagnostics/global_error_hooks_test.dart#keeps capture available while location resolution is pending
        status: pass
    human_judgment: false
  - id: shared-production-diagnostic-pack
    description: "The late-activated production sink uses the established ErrorReporter effect and existing shared formatter, preserving LOG-05's stable diagnostic-pack output."
    requirement: LOG-05
    verification:
      - kind: test
        ref: test/diagnostics/diagnostic_pack_formatter_test.dart
        status: pass
      - kind: command
        ref: D:/flutter/bin/flutter test test/diagnostics/
        status: pass
    human_judgment: false
duration: 14m 30s
completed: 2026-08-30
status: complete
---

# Phase 2 Plan 04: Hooks-First Durable File Evidence Summary

已将可信诊断文件链路装入真实启动路径：全局 `ErrorReporter` 与四源 hooks 先以稳定 delegate 启动，随后非阻塞解析 Application Support 的 `logs/error.log` 并原位激活 UTF-8 append+flush writer，任何慢、失败或永久 pending 的文件准备均不会留下 capture blind spot。

## Performance

- Duration: 14m 30s
- Started: 2026-08-30T14:21:00Z
- Completed: 2026-08-30T14:35:30Z
- Tasks: 2/2
- Files modified: 7

## Accomplishments

- 新增 `ErrorLogLocation`，仅接受 composition root 注入的 Application Support provider，先递归创建 `logs` 后返回固定 `error.log`；provider、目录和目标结构异常均返回 typed unavailable，不使用 cwd/exe/home fallback。
- 在 `KernelLogger` 后立即创建 `DelegatingDiagnosticLogEffect`，以其 `record` 注入唯一 `ErrorReporterImpl`，再安装 `GlobalErrorHooks`；`path_provider` 与目录 I/O 只在此后由 unawaited activation 执行。
- delegate 从启动起保持同一 effect、availability 与 nullable path listenable identity；pending/unavailable 为安全 no-op，成功只替换内部 writer target 并发布 resolved path。
- `ErrorReporterImpl` 以 read-only `ValueListenable<bool>` / `ValueListenable<String?>` 暴露 log status；Phase 3 不需要持有 sink 或 filesystem object。
- `ErrorLogFileSink` 适配窄 `DiagnosticLogSink` contract，继续使用既有 error/fatal-only、serialized `dart:io` append+UTF-8+flush 与 shared diagnostic pack，未接入 `KernelLogger` CompositeSink。
- 覆盖路径唯一性、目录幂等、Unicode 路径、typed unavailable、hooks-first source ordering、pending capture、late activation durable write、stable identity 和 degraded capture。

## Task Commits

1. `fe5fd2a4` — `feat(02-04): resolve default diagnostic log location`
2. `1486da7f` — `feat(02-04): activate diagnostic file evidence after hooks`

## Files Created/Modified

- `lib/kernel/diagnostics/error_log_location.dart` — Application Support provider seam、固定 `logs/error.log` composition 和 typed resolved/unavailable outcome。
- `test/diagnostics/error_log_location_test.dart` — D-03 default path、mkdir idempotence、Unicode/space preservation、external failures 和 no-fallback matrix。
- `lib/kernel/diagnostics/error_reporting_dependencies.dart` — stable delegate、read-only status 和 concrete writer lifecycle contracts。
- `lib/kernel/diagnostics/error_log_file_sink.dart` — 实现窄 `DiagnosticLogSink`，保留 durable writer semantics。
- `lib/kernel/diagnostics/error_reporter.dart` — collaborator-aware singleton init、stable read-only log state exposure 和 reset-time writer cleanup。
- `lib/main.dart` — guarded startup 的 hooks-first delegate injection 与 contained late activation。
- `test/diagnostics/global_error_hooks_test.dart` — startup ordering、pending/degraded/late activation 与 identity evidence。

## Decisions Made

- D-03 默认位置保持唯一且 fail-closed：只能从 `getApplicationSupportDirectory()/logs/error.log` 获得，异常时停留 unavailable/null，不推测任何本地替代目录。
- D-08 的 persistence ownership 保持在 ErrorReporter effects；KernelLogger 仅记录 contained startup warning，永不承担 ErrorReport durable persistence。
- 不等待 path provider：稳定 delegate 与 hooks 在 first await 前建立，慢 provider 不会延迟 `MediaKit`、window 或 `runApp`。
- public status 是 stable read-only listenable identity；activation 更新内部 writer/notifier values，而不是替换 reporter、effect callback 或 ValueListenable。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 修正 Windows separator 假设导致 D-03 test 错误失败**
- **Found during:** Task 1
- **Issue:** 初始 test 以 POSIX `/logs/error.log` 比较 path；Windows 的 `Directory.path` 正确使用 `\\`，导致实现正确但 test 误报失败。
- **Fix:** 将 assertion 改为 `Platform.pathSeparator` composition，同时继续断言固定 child/filename。
- **Files modified:** `test/diagnostics/error_log_location_test.dart`
- **Verification:** focused location test、focused analyze、kernel logger audit passed。
- **Committed in:** `fe5fd2a4`

**2. [Rule 1 - Bug] 使用 KernelLogger 的实际 warn contract 记录 activation containment**
- **Found during:** Task 2
- **Issue:** 初版 activation warning 按 error-level named parameters 调用 `KernelLogger.warn`；其 contract 只接受 message/context，因此无法编译。
- **Fix:** 在 structured context 中保存 contained error/stack text，保留无递归的 KernelLogger-only degradation path。
- **Files modified:** `lib/main.dart`
- **Verification:** focused hooks tests、diagnostics suite、flutter analyze (0 errors) passed。
- **Committed in:** `1486da7f`

**Total deviations:** 2 auto-fixed (Rule 1: 2).
**Impact:** 两项均为 platform correctness 或 facade API correctness；没有扩大 architecture、trust boundary 或 scope。

## Issues Encountered

- Task 1 RED failed as expected because `error_log_location.dart` and its typed outcomes did not exist.
- Task 2 RED initially exposed the absent startup delegate wiring; after implementation, focused startup tests passed.
- `flutter analyze` completed with 0 errors and 59 repository-existing `prefer_initializing_formals` infos, including nine already present in `error_reporter.dart`; no new analyzer error was introduced.
- Full `flutter test` completed without a new diagnostics failure. The run showed no `Some tests failed`, `[E]`, `Failed to load`, or failure assertion markers; documented mdk.dll/FFI, KernelLogger-init, KeyboardHandler F-key, and visible-window headless baseline failures were not reproduced in this run.

## User Setup Required

None.

## Next Phase Readiness

- Phase 3 can read `ErrorReporterImpl.I.diagnosticLogsAvailable` and `diagnosticLogPath` as stable read-only listenables while rendering ErrorCard state.
- Phase 4 can own configured-path validation and safe writer reactivation without changing the default D-03 resolver or public status identity contract.
- Phase 5 can perform the manual Windows smoke test from `02-VALIDATION.md`: trigger an error after startup and confirm the surfaced Application Support path contains a readable UTF-8 diagnostic pack.

## Verification Results

- PASS — `D:/flutter/bin/flutter test test/diagnostics/error_log_location_test.dart`
- PASS — `D:/flutter/bin/flutter test test/diagnostics/error_log_location_test.dart test/diagnostics/global_error_hooks_test.dart`
- PASS — `D:/flutter/bin/flutter test test/diagnostics/`
- PASS — `D:/flutter/bin/flutter analyze` (0 errors; existing informational style findings only)
- PASS — `D:/flutter/bin/flutter test` (no new or known-headless baseline failures reproduced)
- PASS — `bash tool/audit/kernel_logger_gate.sh`
- PASS — `git diff --check`, `git show --check fe5fd2a4`, and `git show --check 1486da7f`
- PASS — acceptance criteria: Application Support-only default, created logs child, typed unavailable degradation, no fallback path, hooks-first delegate construction, pending/failed activation capture continuity, stable reporter/effect/listenable identity, read-only status/path publishing, no `package:logger` kernel import, and no media_kit file modification.

*Phase: 02-trusted-location-file-evidence, Completed: 2026-08-30*

## Self-Check: PASSED
