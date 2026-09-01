---
phase: 01-unified-capture-contract
plan: 04
subsystem: diagnostics
tags: [flutter, dart, diagnostics, redaction, error-reporting, deduplication]
requires:
  - phase: 01-03
    provides: Production PlayerError bridge and bounded diagnostic FIFO
provides:
  - Delimiter-aware local-path redaction across report queue, effects, and presentation
  - Null-metadata fallback that preserves exactly-once PlayerError forwarding
  - Immutable PlayerError discriminator and semantic FIFO deduplication
affects: [phase-01-verification, diagnostics, future-file-logging, error-card]
actuals:
  tokens: 5690
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns:
    - Linear delimiter-aware diagnostic path scanner
    - Immutable sealed-error discriminator snapshot
    - Fixed-order semantic dedupe fingerprint
key-files:
  created: []
  modified:
    - lib/kernel/diagnostics/diagnostic_redactor.dart
    - lib/kernel/diagnostics/error_report.dart
    - lib/kernel/diagnostics/error_reporter.dart
    - lib/kernel/diagnostics/player_error_report_bridge.dart
    - test/diagnostics/error_report_test.dart
    - test/diagnostics/error_reporter_test.dart
    - test/diagnostics/player_error_report_bridge_test.dart
key-decisions:
  - "Redact embedded local paths with a delimiter-aware scanner rather than whitespace-terminated regexes."
  - "Include severity, structured PlayerError code, and sanitized media path in queue-local dedupe identity."
patterns-established:
  - "Optional bridge metadata failures degrade to null snapshots while required player evidence is forwarded once."
requirements-completed: [CAP-01, CAP-02, CAP-03, CAP-04]
coverage:
  - id: D1
    description: "Whitespace-bearing Windows and POSIX local paths are reduced to basename-only evidence before all reporter fan-out."
    requirement: CAP-01
    verification:
      - kind: unit
        ref: "test/diagnostics/error_reporter_test.dart#ErrorReporterImpl diagnostic redaction"
        status: pass
    human_judgment: false
  - id: D2
    description: "A throwing PlayerError bridge media-path provider forwards the original error exactly once with null metadata."
    requirement: CAP-01
    verification:
      - kind: unit
        ref: "test/diagnostics/player_error_report_bridge_test.dart#forwards once with null metadata when the path provider throws"
        status: pass
    human_judgment: false
  - id: D3
    description: "Semantic dedupe separates severity, PlayerError code, and sanitized media target while merging fully equal reports."
    requirement: CAP-04
    verification:
      - kind: unit
        ref: "test/diagnostics/error_reporter_test.dart#keeps same-message player reports distinct by semantic evidence"
        status: pass
      - kind: unit
        ref: "test/diagnostics/error_reporter_test.dart#merges fully equivalent player reports inside the dedupe window"
        status: pass
    human_judgment: false
duration: 29min
completed: 2026-08-28
status: complete
---

# Phase 01 Plan 04: Residual Capture-Contract Gap Closure Summary

**Local diagnostic paths now retain only safe basenames through every report observation, while FIFO deduplication preserves distinct player severity, typed code, and media-target evidence.**

## Performance

- **Duration:** 29 minutes
- **Started:** 2026-08-28T14:30:00Z
- **Completed:** 2026-08-28T14:59:10Z
- **Tasks:** 2/2
- **Files modified:** 7

## Accomplishments

- Replaced whitespace-terminated local-path regexes with a documented delimiter-aware scanner that handles quoted and unquoted Windows/POSIX paths containing spaces, parentheses, and brackets without rewriting package frames or HTTP-family URLs.
- Contained optional media-path lookup separately in `PlayerErrorReportBridge`, so metadata failures retain exactly-once forwarding with a null path snapshot.
- Added immutable `ErrorReport.playerErrorCode` values from an exhaustive sealed `PlayerError` switch, and added severity, code, and sanitized path to the fixed-order dedupe fingerprint.
- Added regressions for end-to-end redaction fan-out, provider failure, discriminator mappings, semantic separation, equivalent merging, and immutable replacement preservation.

## Task Commits

1. **Task 1: Trace whitespace-bearing local paths safely through every reporter observation** - `f7c093b` (feat)
2. **Task 2: Preserve severity, structured player code, and media target in dedupe identity** - `bcc8a32` (feat)

**Plan metadata:** pending

## Files Created/Modified

- `lib/kernel/diagnostics/diagnostic_redactor.dart` - Scans embedded local path tokens using diagnostic delimiters and retains only safe basenames.
- `lib/kernel/diagnostics/player_error_report_bridge.dart` - Separates optional media metadata containment from required reporter forwarding.
- `lib/kernel/diagnostics/error_report.dart` - Adds immutable structured PlayerError code snapshots to report identity.
- `lib/kernel/diagnostics/error_reporter.dart` - Projects all player subtypes to stable codes and fingerprints semantic evidence.
- `test/diagnostics/error_report_test.dart` - Verifies `copyWith` preserves structured identity.
- `test/diagnostics/error_reporter_test.dart` - Covers whitespace-path fan-out, code mapping, and semantic dedupe behavior.
- `test/diagnostics/player_error_report_bridge_test.dart` - Covers null-path forwarding after provider failure.

## Verification

- `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/player_error_report_bridge_test.dart test/diagnostics/global_error_hooks_test.dart` - passed (34 tests).
- `flutter analyze` - passed with no issues.
- `flutter test` - passed (1,259 tests).
- Static diff review confirmed no changes to media_kit, global-hook startup, PlayerError enum registries, file logging, or card UI.

## Decisions Made

- Use delimiter parsing rather than whitespace termination because valid local filenames can contain spaces and balanced punctuation.
- Treat severity, stable player discriminator, and sanitized media target as immutable semantic identity fields for short-window dedupe.
- Treat bridge media context as optional metadata: it may fail independently, but it must never suppress required PlayerError evidence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved non-file URI diagnostic text during path scanning**
- **Found during:** Task 1 (Trace whitespace-bearing local paths safely through every reporter observation)
- **Issue:** Early scanner implementation could recognize URI-internal fragments as local Windows/POSIX paths.
- **Fix:** Added URI-scheme and drive-designator guards before local-token scanning.
- **Files modified:** `lib/kernel/diagnostics/diagnostic_redactor.dart`, `test/diagnostics/error_reporter_test.dart`
- **Verification:** Focused redaction tests prove byte-for-byte preservation of `package:`, `http`, `https`, and `rtsp` evidence.
- **Committed in:** `f7c093b`

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug).
**Impact on plan:** Required security behavior is strengthened; no scope expansion or architecture change.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 01 residual CAP-01 and CAP-04 code gaps are closed with passing focused and full-suite automation. CAP-02 remains subject to the already-recorded real Windows global-hook smoke because process-global runtime callbacks cannot be fully exercised by injected seams.

## Self-Check: PASSED

- Required diagnostic and test artifacts exist in the committed task changes.
- Task commits `f7c093b` and `bcc8a32` exist on the worktree branch.

---
*Phase: 01-unified-capture-contract*
*Completed: 2026-08-28*
