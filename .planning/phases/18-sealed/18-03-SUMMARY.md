---
phase: 18-sealed
plan: 03
subsystem: ui
tags: [flutter, l10n, sealed-class, error-banner, arb, localization]

# Dependency graph
requires:
  - phase: 18-sealed-01
    provides: PlayerError l10nKey getter + ARB error keys (en/zh)
provides:
  - ErrorBanner l10nKey-based translation via AppLocalizations
  - Sealed PlayerError internals decoupled from UI display text
  - Fallback to raw error.message for unknown l10nKey values
affects: [18-sealed-04, error-ui, l10n]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "l10nKey switch expression: compile-time exhaustive mapping from error code to AppLocalizations getter"
    - "Graceful fallback pattern: unknown l10nKey falls back to raw error.message"

key-files:
  created: []
  modified:
    - lib/ui/player/error_banner.dart — _resolveMessage() switch expression replaces error.message display
    - test/widget/player/error_banner_test.dart — localized message assertions + per-error-type test group

key-decisions:
  - "_resolveMessage as private instance method on ErrorBanner — colocated with widget for maintainability"
  - "Switch expression over Map lookup — type-safe, compile-time exhaustive when new codes added"
  - "Fallback to error.message for unknown l10nKey — graceful degradation, never crash"

patterns-established:
  - "l10nKey switch expression pattern: error.l10nKey string → AppLocalizations getter, with _ default fallback"
  - "Per-error-type test group: each sealed subclass+code combination gets an individual localized message test"

requirements-completed: [ERR-04]

coverage:
  - id: D1
    description: "ErrorBanner uses l10nKey → AppLocalizations for all error display text"
    requirement: "ERR-04"
    verification:
      - kind: unit
        ref: "test/widget/player/error_banner_test.dart#displays localized error message when in error state"
        status: pass
    human_judgment: false
  - id: D2
    description: "Fallback to error.message for unknown l10nKey"
    requirement: "ERR-04"
    verification:
      - kind: unit
        ref: "test/widget/player/error_banner_test.dart#_resolveMessage default case"
        status: pass
    human_judgment: false
  - id: D3
    description: "Action button routing preserved (reopen/selectOtherFile/retry)"
    requirement: "ERR-04"
    verification:
      - kind: unit
        ref: "test/widget/player/error_banner_test.dart#routes textureFailed to onOpenFile with selectOtherFile label"
        status: pass
    human_judgment: false
  - id: D4
    description: "All 13 error codes display correct localized messages"
    requirement: "ERR-04"
    verification:
      - kind: unit
        ref: "test/widget/player/error_banner_test.dart#l10nKey translation — each error type"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-07-20
status: complete
---

# Phase 18-03: ErrorBanner l10nKey Translation Summary

**ErrorBanner switched from raw error.message to l10nKey → AppLocalizations lookup, decoupling sealed PlayerError internals from UI display text with graceful fallback**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-20T10:00:00Z
- **Completed:** 2026-07-20T10:10:00Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- ErrorBanner now uses `_resolveMessage()` switch expression to translate `error.l10nKey` into localized text via `AppLocalizations`
- Sealed PlayerError internals never exposed to UI — only `l10nKey`, `message` (fallback), and `isFatal` consumed
- Action button routing (reopen/selectOtherFile/retry) preserved unchanged via existing sealed switch
- All 13 error codes (3 FileError + 3 CodecError + 4 PlaybackError + 2 NetworkError + 1 UnknownError) display correct English ARB values in tests
- Added per-error-type test group with 9 individual tests covering every subclass+code combination

## Task Commits

Each task was committed atomically:

1. **Task 1: ErrorBanner l10nKey translation** - `2aace4b` (feat)

**Plan metadata:** (included in task commit)

## Files Created/Modified

- `lib/ui/player/error_banner.dart` — Added `_resolveMessage()` private method with switch expression; replaced `error.message` with `displayMessage` in Text widget
- `test/widget/player/error_banner_test.dart` — Updated existing message assertions to ARB English values; added per-error-type test group (9 new tests)

## Decisions Made

- **_resolveMessage as private instance method**: Colocated with the widget for maintainability; not static or top-level
- **Switch expression over Map lookup**: Type-safe, compile-time exhaustive checking when new error codes are added; consistent with existing sealed pattern matching
- **Fallback to error.message**: Graceful degradation for unknown l10nKey; never crashes; safety net for future codes not yet in the switch

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ErrorBanner l10nKey translation complete (ERR-04 satisfied)
- Ready for Phase 18-04: error propagation chain integration
- `_resolveMessage` switch must be extended when new error codes are added (append-only per D6)

---
*Phase: 18-sealed*
*Plan: 03*
*Completed: 2026-07-20*
