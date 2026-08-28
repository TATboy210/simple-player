---
phase: 01-unified-capture-contract
plan: 03
subsystem: kernel diagnostics
status: complete
tags: [flutter, dart, diagnostics, redaction, player-error, lifecycle]
requires:
  - phase: 01-01
    provides: immutable ErrorReporter FIFO, presentation, effects, and dedupe contracts
  - phase: 01-02
    provides: initialized ErrorReporter singleton and guarded global capture hooks
provides:
  - one PlayerServices-owned PlayerError bridge for callback and lastError ingress
  - pre-fan-out diagnostic redaction for local paths
  - rollback-safe inclusive ten-second fingerprint deduplication
affects: [phase-02-location-and-file-output, phase-03-error-card, CAP-01, CAP-04]
actuals:
  tokens: 12600
  tasks: 3
  commits: 6
tech-stack:
  added: []
  patterns:
    - identity-scoped dual-ingress correlation at one lifecycle-owned bridge
    - sanitize-before-bounding normalization at the reporter trust boundary
    - native-free PlayerServices lifecycle seam for composition tests
key-files:
  created:
    - lib/kernel/diagnostics/diagnostic_redactor.dart
    - lib/kernel/diagnostics/player_error_report_bridge.dart
    - test/diagnostics/player_error_report_bridge_test.dart
  modified:
    - lib/kernel/diagnostics/error_reporter.dart
    - lib/kernel/player_services.dart
    - test/diagnostics/error_reporter_test.dart
    - test/kernel/player_services_test.dart
key-decisions:
  - "Correlate notifier and controller OpenError exposure by PlayerError object identity, not message text or reporter fingerprints."
  - "Redact media-path, message, and stack snapshots before FIFO acceptance, presentation, or effects."
  - "Treat negative wall-clock elapsed durations as distinct evidence while retaining zero-through-ten-second inclusive merges."
patterns-established:
  - "Player error ingress: PlayerServices owns a single bridge whose listener detaches before controller and engine teardown."
requirements-completed: [CAP-01, CAP-04]
coverage:
  - id: D1
    description: "Player validation, OpenError dual exposure, asynchronous notifier errors, and disposal flow through one bridge."
    requirement: CAP-01
    verification:
      - kind: unit
        ref: "flutter test test/diagnostics/player_error_report_bridge_test.dart test/kernel/player_services_test.dart test/kernel/services/playback_controller_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Windows, UNC, POSIX, and file-URI paths are sanitized in reports, effects, and presentation while useful filenames and locations remain."
    requirement: CAP-01
    verification:
      - kind: unit
        ref: "flutter test test/diagnostics/error_reporter_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Rollback-safe fingerprint dedupe preserves distinct stale evidence and retains inclusive zero-to-ten-second merging."
    requirement: CAP-04
    verification:
      - kind: unit
        ref: "flutter test test/diagnostics/error_reporter_test.dart"
        status: pass
    human_judgment: false
duration: 2h15m
completed: 2026-08-28
---

# Phase 01 Plan 03: Player Error Bridge and Safe Diagnostics Summary

**Shipped one lifecycle-owned player-error bridge plus pre-fan-out local-path redaction and rollback-safe ten-second deduplication for immutable diagnostic reports.**

## Performance

- **Duration:** 2h15m
- **Started:** 2026-08-28T12:46:35Z
- **Completed:** 2026-08-28T14:01:25Z
- **Tasks:** 3/3
- **Files modified:** 7

## Accomplishments

- Connected `PlaybackController.onError` and `MediaEngine.lastError` to the initialized reporter through one `PlayerErrorReportBridge` owned by `PlayerServices`.
- Suppressed only identical dual-exposed `OpenError` objects while retaining validation-only, later asynchronous, and same-message distinct failures.
- Sanitized Windows, UNC, POSIX, and percent-encoded file-URI path material before reports reach the FIFO, effects, or presentation notifier.
- Prevented wall-clock rollback from merging stale diagnostics while retaining D-04's inclusive zero-through-ten-second behavior.
- Added native-free lifecycle composition coverage without altering `media_kit`, global hooks, UI, file output, queue capacity, or FIFO semantics.

## Verification

- `flutter test test/diagnostics/error_reporter_test.dart test/diagnostics/player_error_report_bridge_test.dart test/kernel/player_services_test.dart test/kernel/services/playback_controller_test.dart` — passed (36 tests).
- `flutter analyze` — passed with no issues.
- `flutter test` — passed (1,254 tests).
- Production-source search confirms `reportPlayerError` is called only by `PlayerErrorReportBridge`; the sole production owner is `PlayerServices`.
- No media_kit dependency/source, global-hook, UI-card, or file-output changes were made.

## Task Commits

1. **Task 1: Trace one controller validation failure through the production bridge into a sanitized report** — `c592a2e` (test), `73fba33` (feat)
2. **Task 2: Cover OpenError, asynchronous lastError, duplicate suppression, and listener cleanup** — `daaab77` (feat)
3. **Task 3: Lock all redaction families and reject negative elapsed dedupe windows** — `656dd5a` (fix), `8f6c43a` (fix), `249f265` (fix)

## Files Created/Modified

- `lib/kernel/diagnostics/diagnostic_redactor.dart` — deterministic local path and embedded diagnostic text policy.
- `lib/kernel/diagnostics/error_reporter.dart` — redacts snapshots before acceptance and validates dedupe elapsed bounds.
- `lib/kernel/diagnostics/player_error_report_bridge.dart` — sole player-error bridge with identity correlation and idempotent listener cleanup.
- `lib/kernel/player_services.dart` — bridge composition, teardown order, and native-free test seam.
- `test/diagnostics/error_reporter_test.dart` — table-driven redaction, fan-out, rollback, and boundary regressions.
- `test/diagnostics/player_error_report_bridge_test.dart` — controller, OpenError, async notifier, identity, and dispose coverage.
- `test/kernel/player_services_test.dart` — composition-root bridge ownership and teardown coverage.

## Decisions Made

- Use `MediaEngine.lastError` exclusively as the engine-wrapper listener surface; no direct `MediaKitEngine` coupling or package modification.
- Snapshot the controller path at intake, preferring a path held in `PlayerError.context` when present.
- Keep path redaction local to reporter normalization rather than sinks or future UI consumers, so all observations receive the same immutable sanitized report.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented URL scheme suffixes from being interpreted as Windows drive prefixes**
- **Found during:** Task 3 (Lock all redaction families and reject negative elapsed dedupe windows)
- **Issue:** The initial forward-slash Windows-path matcher redacted `https://` and `rtsp://` URL fragments.
- **Fix:** Required the drive-letter match not to be preceded by another letter, preserving non-file network URLs while retaining Windows forward-slash path redaction.
- **Files modified:** `lib/kernel/diagnostics/diagnostic_redactor.dart`
- **Verification:** Redaction idempotence and network URL preservation test; `flutter analyze` passed.
- **Committed in:** `249f265`

**2. [Rule 1 - Bug] Removed obsolete nullable bounding helper after normalization moved to the redactor**
- **Found during:** Task 3 (Lock all redaction families and reject negative elapsed dedupe windows)
- **Issue:** `flutter analyze` reported the no-longer-used `_boundedNullable` helper.
- **Fix:** Removed the obsolete private helper.
- **Files modified:** `lib/kernel/diagnostics/error_reporter.dart`
- **Verification:** `flutter analyze` passed with no issues.
- **Committed in:** `8f6c43a`

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs). **Impact:** No scope increase; both corrections preserve the specified redaction and quality contracts.

## Issues Encountered

None. `flutter pub get` invoked by Flutter commands regenerated platform plugin registrants; those generated files were restored and excluded from every task commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase complete, ready for next step. Phase 2 can attach file-output effects to already-sanitized immutable reports, and Phase 3 can consume the existing presentation state without adding another player listener.

## Self-Check: PASSED

- Confirmed all seven shipped source and test artifacts exist in the worktree.
- Confirmed task commits `c592a2e`, `73fba33`, `daaab77`, `656dd5a`, `8f6c43a`, and `249f265` exist in git history.

---
*Phase: 01-unified-capture-contract*
*Completed: 2026-08-28*
