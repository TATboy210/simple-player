---
phase: 18-sealed
plan: 01
subsystem: models
tags: [sealed-class, error-handling, l10n, dart-3, error-context]

# Dependency graph
requires: []
provides:
  - ErrorContext class with toMap() serialization
  - PlayerError extended with isFatal/l10nKey/context (backward compatible)
  - Recoverable markers on all 4 per-subclass enums
  - 13 error l10n keys (en + zh) for ErrorBanner translation
affects: [18-02, 18-03, 18-04, 18-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ErrorContext.toMap() for KernelLogger structured context"
    - "isFatal delegates to !code.recoverable (single source of truth)"
    - "l10nKey format: error.{type}.{code} for UI translation"
    - "Append-only error code registry with doc comment freeze (D6)"

key-files:
  created: []
  modified:
    - lib/kernel/models/player_error.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_zh.arb
    - lib/l10n/app_localizations.dart
    - lib/l10n/app_localizations_en.dart
    - lib/l10n/app_localizations_zh.dart
    - lib/kernel/engine/fvp_engine.dart
    - test/kernel/models/player_error_test.dart
    - test/integration/error_propagation_test.dart
    - test/widget/player/error_banner_test.dart

key-decisions:
  - "ErrorContext as plain class (not sealed/abstract) — simple data carrier"
  - "Optional ErrorContext? context on sealed PlayerError — backward compatible"
  - "Constructors non-const (DateTime.now() non-const per D3)"
  - "isFatal = !code.recoverable — single source of truth in enum markers"
  - "l10nKey format error.{type}.{code} — switch expression friendly for ErrorBanner"

patterns-established:
  - "ErrorContext: structured error context with toMap() for logger integration"
  - "recoverable enum marker: per-subclass enum values carry recoverable bool"
  - "l10nKey accessor: PlayerError subclass → ARB key for UI translation"

requirements-completed: [ERR-01, ERR-02, ERR-04]

coverage:
  - id: D1
    description: "ErrorContext class with action/generation/path/timestamp/module/callbackStackTrace"
    requirement: ERR-01
    verification:
      - kind: unit
        ref: "test/kernel/models/player_error_test.dart#ErrorContext"
        status: pass
    human_judgment: false
  - id: D4
    description: "isFatal abstract getter on PlayerError, delegates to !code.recoverable"
    requirement: ERR-02
    verification:
      - kind: unit
        ref: "test/kernel/models/player_error_test.dart#isFatal"
        status: pass
    human_judgment: false
  - id: D5
    description: "recoverable marker on all 4 per-subclass enums (File/Codec/Playback/Network)"
    requirement: ERR-02
    verification:
      - kind: unit
        ref: "test/kernel/models/player_error_test.dart#recoverable markers on enums"
        status: pass
    human_judgment: false
  - id: D7
    description: "l10nKey accessor for UI translation (error.{type}.{code} format)"
    requirement: ERR-04
    verification:
      - kind: unit
        ref: "test/kernel/models/player_error_test.dart#l10nKey"
        status: pass
    human_judgment: false
  - id: ERR04-ARB
    description: "13 error l10n keys in app_en.arb and app_zh.arb"
    requirement: ERR-04
    verification:
      - kind: unit
        ref: "flutter gen-l10n && grep -c errorFile/errorCodec/errorPlayback/errorNetwork/errorUnknown"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-20
status: complete
---

# Phase 18-01: Sealed Error Model Extensions Summary

**Extended sealed PlayerError with ErrorContext, isFatal/l10nKey accessors, recoverable enum markers, and 13 error l10n keys for UI translation**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-20T00:00:00Z
- **Completed:** 2026-07-20T00:08:00Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- ErrorContext class with 6 optional fields + toMap() serialization for KernelLogger
- PlayerError extended with optional context field, abstract isFatal/l10nKey getters
- All 4 per-subclass enums (File/Codec/Playback/Network) carry recoverable bool markers
- 13 error l10n keys added to both English and Chinese ARB files
- AppLocalizations regenerated with error message getters
- All existing const error construction sites updated to non-const
- 31 unit tests passing covering ErrorContext, isFatal, l10nKey, recoverable markers, backward compatibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend PlayerError model — ErrorContext + isFatal + l10nKey + recoverable enums** - `8ff6c32` (feat)
2. **Task 2: Add error l10n keys to ARB files** - `53f442d` (feat)

## Files Created/Modified
- `lib/kernel/models/player_error.dart` - Extended sealed PlayerError with ErrorContext, isFatal, l10nKey, recoverable enums
- `lib/l10n/app_en.arb` - Added 13 error message keys (English)
- `lib/l10n/app_zh.arb` - Added 13 error message keys (Chinese)
- `lib/l10n/app_localizations.dart` - Regenerated with error getters
- `lib/l10n/app_localizations_en.dart` - Regenerated
- `lib/l10n/app_localizations_zh.dart` - Regenerated
- `lib/kernel/engine/fvp_engine.dart` - Removed const from FileError construction
- `test/kernel/models/player_error_test.dart` - Extended with 24 new test cases
- `test/integration/error_propagation_test.dart` - Removed const from error constructions
- `test/widget/player/error_banner_test.dart` - Removed const from error constructions

## Decisions Made
- ErrorContext is a plain Dart class (not sealed/abstract) — simple data carrier for structured diagnostics
- Optional ErrorContext? context field on sealed PlayerError preserves backward compatibility
- All subclass constructors changed from const to non-const (ErrorContext contains DateTime.now() per D3)
- isFatal delegates to !code.recoverable — single source of truth in enum markers
- l10nKey uses format error.{type}.{code} — switch expression friendly for ErrorBanner

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ErrorContext + isFatal + l10nKey model foundation ready for 18-02 (engine catch point injection)
- ARB keys ready for 18-04 (ErrorBanner l10nKey translation)
- Recoverable markers ready for 18-03 (PropagationController error classification)

---
*Phase: 18-sealed*
*Completed: 2026-07-20*
