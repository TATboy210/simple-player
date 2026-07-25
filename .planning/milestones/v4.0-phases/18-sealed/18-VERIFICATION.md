---
phase: 18-sealed
verified: 2026-07-20T14:00:00Z
status: passed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: false
---

# Phase 18: Sealed Error Model Stabilization Verification Report

**Phase Goal:** Stabilize and extend existing sealed PlayerError (not create new), letting errors carry structured context end-to-end (engine construct -> lastError assign -> logger emit -> service enrich -> UI translate), never silently swallow errors, never expose raw sealed objects to UI
**Verified:** 2026-07-20T14:00:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ErrorContext class defined with action/generation/path/timestamp/module/callbackStackTrace fields, plus toMap() serialization; PlayerError sealed class extended with optional ErrorContext? context field; ValueNotifier<PlayerError?> contract preserved (FvpEngine.lastError unchanged) | VERIFIED | `lib/kernel/models/player_error.dart` lines 54-92: ErrorContext with all 6 fields, toMap() serializes non-null fields + always timestamp; lines 26-32: context getter/setter on sealed class; line 179: `final ValueNotifier<PlayerError?> lastError = ValueNotifier<PlayerError?>(null)` in fvp_engine.dart |
| 2 | Every PlayerError subclass exposes bool get isFatal (!code.recoverable) and String get l10nKey (error.{type}.{code}); UnknownError.isFatal returns false | VERIFIED | `player_error.dart` lines 113-116 (FileError), 157-160 (CodecError), 200-203 (PlaybackError), 248-251 (NetworkError), 287-290 (UnknownError). isFatal delegates to !code.recoverable for all subclasses with enums. l10nKey format matches D7: error.{type}.{code} |
| 3 | All 4 per-subclass enums (FileErrorCode/CodecErrorCode/PlaybackErrorCode/NetworkErrorCode) carry recoverable bool marker; error codes are append-only with doc comment freeze (D6) | VERIFIED | `player_error.dart` lines 122-136 (FileErrorCode: pathEmpty=true, fileNotFound=true, pathTraversal=false), 167-180 (CodecErrorCode: all true), 211-227 (PlaybackErrorCode: playFailed=true, seekFailed=true, textureFailed=false, openTimeout=true), 258-268 (NetworkErrorCode: all true). Each enum has `/// 错误码注册表 -- append-only, 现有码永不重命名/删除 (D6)` doc comment |
| 4 | Every FvpEngine catch point follows three-step pattern (construct PlayerError with ErrorContext -> assign lastError.value -> log.e()); MediaOpener error construction includes ErrorContext; PlaybackController._onError narrowed from Object to PlayerError | VERIFIED | `fvp_engine.dart`: 8 catch points verified -- _guardedAction (line 235), open() empty path (263), open() main catch (336), open() OpenError enrichment (323), play() (385), pause() (409), stop() (432), seekTo() (461) -- all follow three-step pattern. `media_opener.dart`: 6 error sites (lines 48-55, 63-70, 73-80, 99-108, 148-159, 165-174) all include ErrorContext. `playback_controller.dart` line 73: `final void Function(PlayerError error)? _onError` (narrowed from Object). 4 downstream sites in auto_advance_policy.dart (lines 62-63, 74-75) and playback_navigator.dart (lines 59, 99-101) wrap Exception in PlayerError subtypes |
| 5 | ErrorBanner uses l10nKey to look up localized message from AppLocalizations, with fallback to raw error.message for unknown l10nKey; action button routing preserved | VERIFIED | `error_banner.dart` lines 125-142: _resolveMessage switch expression maps all 13 l10nKey values to AppLocalizations getters, `_ => error.message` fallback. Line 41: `final displayMessage = _resolveMessage(l10n, error)` used in Text widget (line 83). Lines 46-65: sealed switch for action button routing preserved (FileError->reopen, CodecError->selectOtherFile, textureFailed->selectOtherFile, other->retry). ARB files: 13 keys in app_en.arb (lines 399-423) + app_zh.arb (lines 193-205). Generated AppLocalizations has all 13 getters |
| 6 | Sealed PlayerError internals never exposed as raw object to UI -- only l10nKey + message (fallback) + isFatal consumed | VERIFIED | `error_banner.dart` line 41: displayMessage comes from _resolveMessage (l10nKey lookup), not error.message directly. Lines 44-65: sealed switch only uses type (for action routing), not internal fields. error.message only used as fallback in _resolveMessage default case |
| 7 | mdk callback errors caught in FvpCallbackHandler, wrapped in PlaybackError with ErrorContext containing callbackStackTrace, marshalled to main thread via scheduleMicrotask before assigning _lastErrorNotifier.value | VERIFIED | `fvp_callback_handler.dart` lines 54-57 (onStateChanged) and 87-89 (onMediaStatus): try-catch with `_marshalCallbackError(e, st, action)`. Lines 98-113: _marshalCallbackError constructs PlaybackError with ErrorContext(callbackStackTrace: st), _scheduleOnMain sets _lastErrorNotifier.value. Constructor (lines 34-40): lastErrorNotifier injected. FvpEngine factory (line 77): passes `engine.lastError` to FvpCallbackHandler |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/kernel/models/player_error.dart` | Extended with ErrorContext, isFatal, l10nKey, recoverable enums | VERIFIED | 295 lines, all extensions present |
| `lib/l10n/app_en.arb` | 13 error message keys | VERIFIED | Lines 399-423: all 13 keys present |
| `lib/l10n/app_zh.arb` | 13 error message keys (Chinese) | VERIFIED | Lines 193-205: all 13 keys present |
| `lib/l10n/app_localizations.dart` | Generated with error getters | VERIFIED | 13 getters present (lines 1095-1167) |
| `lib/kernel/engine/fvp_engine.dart` | 8 catch points with three-step pattern | VERIFIED | All 8 catch points verified |
| `lib/kernel/engine/media_opener.dart` | 6 error sites with ErrorContext | VERIFIED | All 6 sites include ErrorContext |
| `lib/kernel/engine/fvp_callback_handler.dart` | mdk callback error marshalling | VERIFIED | _marshalCallbackError + _scheduleOnMain |
| `lib/kernel/services/playback_controller.dart` | _onError signature narrowed to PlayerError | VERIFIED | Line 73: `void Function(PlayerError error)?` |
| `lib/kernel/services/auto_advance_policy.dart` | 2 onError calls wrapped in PlaybackError | VERIFIED | Lines 62-63, 74-75 |
| `lib/kernel/services/playback_navigator.dart` | Exception call sites wrapped in PlayerError | VERIFIED | Line 59: FileError, lines 99-101: PlaybackError |
| `lib/ui/player/error_banner.dart` | l10nKey translation via AppLocalizations | VERIFIED | _resolveMessage switch expression present |
| `test/kernel/models/player_error_test.dart` | Extended tests for ErrorContext/isFatal/l10nKey/recoverable | VERIFIED | 302 lines, groups: ErrorContext (lines 71-132), isFatal (134-179), l10nKey (181-245), backward compat (247-275), recoverable markers (277-301) |
| `test/kernel/engine/fvp_engine_error_test.dart` | Three-step pattern tests | VERIFIED | 187 lines, 11 tests covering ErrorContext construction + isFatal + l10nKey + toMap serialization |
| `test/kernel/engine/fvp_callback_handler_test.dart` | Callback error marshalling tests | VERIFIED | 99 lines, 3 ERR-05 tests (lines 51-97) |
| `test/widget/player/error_banner_test.dart` | l10nKey translation tests | VERIFIED | 268 lines, per-error-type test group (lines 163-266) covering all 13 error codes |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| FvpEngine catch points | ErrorContext | PlayerError construction with ErrorContext param | WIRED | All 8 catch points construct ErrorContext with action/module/path |
| PlayerError.l10nKey | ErrorBanner._resolveMessage | switch expression on error.l10nKey | WIRED | 13 l10nKey values mapped to AppLocalizations getters |
| ErrorContext.toMap() | KernelLogger.e() | `context: error.context?.toMap()` parameter | WIRED | All engine catch points pass toMap() to log.e |
| FvpCallbackHandler | lastErrorNotifier | constructor injection from FvpEngine factory | WIRED | Line 77 of fvp_engine.dart: `lastErrorNotifier: engine.lastError` |
| auto_advance_policy.dart | PlaybackError | Exception wrapping before onError call | WIRED | Lines 62-63, 74-75: PlaybackError(playFailed, ...) |
| playback_navigator.dart | FileError/PlaybackError | Exception wrapping before onError call | WIRED | Line 59: FileError(pathTraversal), lines 99-101: PlaybackError(playFailed) |
| AppLocalizations error getters | ARB error keys | flutter gen-l10n code generation | WIRED | All 13 getters generated in app_localizations.dart |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| No bare `catch (e)` in fvp_engine.dart | `grep "catch (e)" lib/kernel/engine/fvp_engine.dart` | No matches (all use `catch (e, st)`) | PASS |
| No raw Exception calls to onError in services | `grep "_controller.onError?.call(e)" lib/kernel/services/` | No matches (all wrapped in PlayerError) | PASS |
| AppLocalizations has all 13 error getters | `grep "errorFile\|errorCodec\|errorPlayback\|errorNetwork\|errorUnknown" lib/l10n/app_localizations.dart` | 13 matches | PASS |
| No debt markers in modified files | `grep "TBD\|FIXME\|XXX" lib/kernel/ lib/ui/player/error_banner.dart` | No matches | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ERR-01 | 18-01 | Extend sealed PlayerError with ErrorContext + ErrorCode registry; preserve ValueNotifier<PlayerError?> contract | SATISFIED | ErrorContext class (player_error.dart:54-92), context field on sealed class (line 26-32), lastError ValueNotifier unchanged (fvp_engine.dart:179) |
| ERR-02 | 18-01, 18-02 | Recoverable vs fatal split; no silent error swallowing; typed catch only | SATISFIED | isFatal on all subclasses, recoverable markers on all enums, no bare catch(e) in fvp_engine.dart, no Error subtypes caught |
| ERR-03 | 18-02 | Engine catch points construct PlayerError with ErrorContext -> lastError -> logger; _onError takes PlayerError | SATISFIED | 8 catch points in fvp_engine.dart + 6 in media_opener.dart follow three-step pattern; _onError narrowed to PlayerError |
| ERR-04 | 18-01, 18-03 | UI boundary ErrorView translation via l10nKey; sealed PlayerError never exposed raw to UI | SATISFIED | ErrorBanner._resolveMessage uses l10nKey -> AppLocalizations; fallback to error.message; 13 ARB keys (en+zh); sealed internals not exposed |
| ERR-05 | 18-02 | mdk callback thread marshalling with callbackStackTrace | SATISFIED | FvpCallbackHandler._marshalCallbackError constructs ErrorContext(callbackStackTrace), _scheduleOnMain -> _lastErrorNotifier.value |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/kernel/services/playback_navigator.dart` | 93 | `on Exception catch (e)` without stack trace capture | Info | Minor: stack trace not captured for this catch point. Not a blocker -- plan only required stack trace capture in FvpEngine catch points. PlaybackNavigator logs the error message and wraps in PlaybackError correctly. |

### Human Verification Required

No human verification items. All truths are structurally verifiable via code inspection. The behavioral spot-checks confirm no anti-pattern violations in the modified files.

### Gaps Summary

No gaps found. All 5 requirements (ERR-01 through ERR-05) are satisfied. All 14 artifacts exist, are substantive, and are wired correctly. The single Info-severity finding (bare catch in playback_navigator.dart line 93) is outside the plan's explicit scope and does not affect goal achievement.

---

_Verified: 2026-07-20T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
