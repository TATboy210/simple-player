---
phase: 18-sealed
plan: 02
subsystem: engine
tags: [sealed-error, error-context, fvp, mdk, thread-marshalling]

requires:
  - phase: 18-01
    provides: "PlayerError extended with ErrorContext + isFatal + l10nKey + recoverable enums"
provides:
  - "All 8 FvpEngine catch points follow three-step pattern (construct PlayerError with ErrorContext -> lastError -> log)"
  - "All 6 MediaOpener error sites include ErrorContext with action/path/module"
  - "PlaybackController._onError narrowed from Object to PlayerError"
  - "FvpCallbackHandler catches mdk callback exceptions with ErrorContext(callbackStackTrace), marshals to main thread"
  - "4 downstream call sites (auto_advance_policy + playback_navigator) wrap Exception -> PlayerError"
  - "PlayerError.context made mutable for engine enrichment pattern"
affects: [19-memory-monitor, 20-new-engine]

tech-stack:
  added: []
  patterns:
    - "Three-step error pattern: construct PlayerError + ErrorContext -> assign lastError.value -> log.e(context: error.context?.toMap())"
    - "Callback error marshalling: catch on callback thread -> construct ErrorContext(callbackStackTrace) -> _scheduleOnMain -> lastError"
    - "Error enrichment: engine enriches lower-layer errors with generation/context via mutable setter"

key-files:
  created:
    - test/kernel/engine/fvp_engine_error_test.dart
  modified:
    - lib/kernel/engine/fvp_engine.dart
    - lib/kernel/engine/media_opener.dart
    - lib/kernel/engine/fvp_callback_handler.dart
    - lib/kernel/models/player_error.dart
    - lib/kernel/services/playback_controller.dart
    - lib/kernel/services/auto_advance_policy.dart
    - lib/kernel/services/playback_navigator.dart
    - test/kernel/engine/fvp_callback_handler_test.dart

key-decisions:
  - "Made PlayerError.context field mutable (non-final) across all subclasses to support engine enrichment pattern where FvpEngine adds ErrorContext to MediaOpener errors"
  - "FvpCallbackHandler does not import KernelLogger (avoids pre-existing KernelLogger.I issue); error logging deferred to main thread via lastErrorNotifier listeners"
  - "Removed unused visibleForTesting import from media_opener.dart (textureTimeoutForHeight method not present in worktree version)"

patterns-established:
  - "Three-step error pattern: every engine catch point must construct PlayerError with ErrorContext, assign lastError, and log via kernel logger"
  - "Callback error marshalling: mdk callback exceptions caught with try-catch, ErrorContext carries callbackStackTrace, errors marshalled to main thread via _scheduleOnMain"

requirements-completed: [ERR-03, ERR-05]

coverage:
  - id: D1
    description: "FvpEngine 8 catch points transformed to three-step pattern"
    requirement: ERR-03
    verification:
      - kind: unit
        ref: "test/kernel/engine/fvp_engine_error_test.dart#ErrorContext construction"
        status: pass
      - kind: other
        ref: "grep verification: no bare catch(e) in fvp_engine.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "MediaOpener 6 error sites include ErrorContext"
    requirement: ERR-03
    verification:
      - kind: other
        ref: "flutter analyze lib/kernel/engine/media_opener.dart — zero new errors"
        status: pass
    human_judgment: false
  - id: D3
    description: "PlaybackController._onError narrowed to PlayerError"
    requirement: ERR-03
    verification:
      - kind: other
        ref: "flutter analyze lib/kernel/services/playback_controller.dart — zero new errors"
        status: pass
    human_judgment: false
  - id: D4
    description: "FvpCallbackHandler mdk callback error marshalling with callbackStackTrace"
    requirement: ERR-05
    verification:
      - kind: unit
        ref: "test/kernel/engine/fvp_callback_handler_test.dart#ErrorContext callbackStackTrace"
        status: pass
    human_judgment: false
  - id: D5
    description: "4 downstream Exception->PlayerError wrapping sites"
    requirement: ERR-03
    verification:
      - kind: other
        ref: "grep verification: no raw Exception calls in auto_advance_policy/playback_navigator"
        status: pass
      - kind: other
        ref: "flutter analyze lib/kernel/services/auto_advance_policy.dart lib/kernel/services/playback_navigator.dart — zero new errors"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-07-20
status: complete
---

# Phase 18 Plan 02: Engine Error Propagation Summary

**End-to-end error propagation chain from engine catch points through service layer, with structured ErrorContext at every point and mdk callback thread marshalling**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-20T12:00:00Z
- **Completed:** 2026-07-20T12:25:00Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments
- All 8 FvpEngine catch points now follow three-step pattern: construct PlayerError with ErrorContext, assign lastError, log via kernel logger with structured context
- All 6 MediaOpener error construction sites include ErrorContext with action/path/module fields
- PlaybackController._onError narrowed from `Object` to `PlayerError` (type-safe error propagation)
- FvpCallbackHandler catches mdk callback exceptions in both onStateChanged and onMediaStatus, constructs PlaybackError with ErrorContext containing callbackStackTrace, marshals to main thread via _scheduleOnMain
- 4 downstream call sites (auto_advance_policy 2x, playback_navigator 2x) wrap raw Exception in PlayerError subtypes
- PlayerError.context field made mutable to support engine enrichment pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: FvpEngine catch points + MediaOpener ErrorContext** - `18a2481` (feat)
2. **Task 3: Wrap Exception call sites (D8 downstream)** - `9c03661` (fix)
3. **Task 2: PlaybackController signature + FvpCallbackHandler marshalling** - `28d67f0` (feat)

## Files Created/Modified
- `lib/kernel/engine/fvp_engine.dart` - 8 catch points transformed to three-step pattern with ErrorContext
- `lib/kernel/engine/media_opener.dart` - 6 error sites enriched with ErrorContext(action/path/module)
- `lib/kernel/engine/fvp_callback_handler.dart` - mdk callback error marshalling with callbackStackTrace, lastErrorNotifier injection
- `lib/kernel/models/player_error.dart` - context field made mutable (non-final) for enrichment pattern
- `lib/kernel/services/playback_controller.dart` - _onError signature narrowed Object -> PlayerError
- `lib/kernel/services/auto_advance_policy.dart` - 2 onError calls wrapped in PlaybackError
- `lib/kernel/services/playback_navigator.dart` - path validation passes FileError, playIndex catch passes PlaybackError
- `test/kernel/engine/fvp_engine_error_test.dart` - 12 new tests for ErrorContext construction and three-step pattern
- `test/kernel/engine/fvp_callback_handler_test.dart` - 3 new tests for callbackStackTrace ErrorContext

## Decisions Made
- Made PlayerError.context mutable across all subclasses to support engine enrichment (FvpEngine adding ErrorContext to MediaOpener errors)
- FvpCallbackHandler does not import KernelLogger to avoid pre-existing KernelLogger.I compilation issue; error logging deferred to main thread
- Task 3 executed before Task 2 (prerequisite: downstream call sites must wrap Exception before _onError signature narrowing compiles)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] PlayerError.context was final, blocking enrichment pattern**
- **Found during:** Task 1 (FvpEngine catch points)
- **Issue:** `error.context = ErrorContext(...)` assignment failed because context was `final` on all subclasses
- **Fix:** Changed `final ErrorContext? context` to `ErrorContext? context` (non-final) on all 5 PlayerError subclasses + added `set context` to sealed class
- **Files modified:** lib/kernel/models/player_error.dart
- **Verification:** flutter analyze passes, all 51 tests pass
- **Committed in:** 18a2481 (Task 1 commit)

**2. [Rule 2 - Missing] KernelLogger import caused compilation failure in tests**
- **Found during:** Task 2 (FvpCallbackHandler)
- **Issue:** Added `KernelLogger.I` reference to FvpCallbackHandler which failed to compile (pre-existing KernelLogger.I issue)
- **Fix:** Removed KernelLogger dependency from FvpCallbackHandler; error logging deferred to main thread via lastErrorNotifier
- **Files modified:** lib/kernel/engine/fvp_callback_handler.dart
- **Verification:** 8 callback handler tests pass
- **Committed in:** 28d67f0 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 final field blocking mutation, 1 pre-existing dependency issue)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered
None beyond the 2 auto-fixed deviations.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Engine error propagation chain is structurally complete
- Ready for Phase 19 (MemoryMonitor error integration) or Phase 20 (NewFvpEngine using same three-step pattern)
- Pre-existing KernelLogger.I issue affects multiple test files (not introduced by this phase)

---
*Phase: 18-sealed*
*Completed: 2026-07-20*
