---
phase: 04-error-feedback-settings
fixed_at: 2026-08-31T19:45:48Z
review_path: .planning/phases/04-error-feedback-settings/04-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 12
skipped: 2
status: all_fixed
---

# Phase 4: Code Review Fix Report

**Fixed at:** 2026-08-31 19:45 UTC (2026-09-01 local)
**Source review:** `.planning/phases/04-error-feedback-settings/04-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (6 warnings + 5 enumerated cheap infos)
- Fixed: 12 (all 11 in-scope + opportunistic IN-05 inside the WR-03 commit)
- Deferred: 2 (IN-03, IN-08 — out-of-scope infos, rationale below)
- Verification: scoped tests 577/577; full suite 1389/1389 green; `flutter analyze` 0 errors / 0 warnings / 0 infos in touched files; kernel logger gate PASS
- Verification ran in the **main working tree** (`D:/simple_player_flutter`, master) per orchestrator directive — no worktree; numbers are reproducible from this tree at commit `8a9c5539`.

## Fixed Issues

### WR-01: Concurrent `apply` calls not serialized — sink ends at stale target while UI reports the new one

**Files modified:** `lib/ui/dialogs/settings/diagnostic_log_target.dart`, `test/diagnostics/diagnostic_log_target_test.dart`
**Commit:** `42239049`
**Status:** fixed: requires human verification (concurrency logic)

- `apply()` now chains every retarget job on a `_retargetQueue` future: validate → save → dispose → activate runs with at most one in flight, so the interleaving A.dispose → B.dispose → A.activate → B.activate(swallowed) is impossible.
- `activateResolved` reads back `effect.logPath.value` instead of asserting `file.path`, so the UI's authoritative read can never claim an activation the delegate swallowed. The effectiveLogPath doc comment updated accordingly.
- Additional isolation fix found by testing: `_retargetQueue` is session state on the singleton; `resetForTesting` now also resets it to an empty chain (a stale future from a dead test zone otherwise poisons every later apply — the reason three widget tests hung until this was added).
- New test: `overlapping applies serialize; final target is the last request` — two overlapping applies; asserts delegate + effectiveLogPath + store all settle at the second request and the first file is never written.

### WR-02: Directory input seeded with the effective *file* path

**Files modified:** `lib/ui/dialogs/settings/general_settings_content.dart`, `test/widget/dialogs/general_settings_content_test.dart`
**Commit:** `13e323d2`
**Status:** fixed

- `initState` seeds `_pathController` from `ErrorFeedbackSettings.I.state.value.logDirectory` (the configured directory), not `DiagnosticLogTarget.I.effectiveLogPath.value` (the resolved `…\logs\error.log` file). Full effective path stays on the always-visible `_EffectivePathLine` (D-04 first channel).
- New test: `directory input is seeded from the store, not the file path`.

### WR-03: Startup configured tier bypasses the validation contract

**Files modified:** `lib/kernel/diagnostics/error_log_location.dart`, `test/diagnostics/error_log_location_test.dart`
**Commit:** `9e0077d6`
**Status:** fixed: requires human verification (fallback-marker semantics)

- `resolve`'s configured tier now routes through `validateConfiguredDirectory(configured, writable: probe)` — the single validation implementation (trim/absolute/control-char/UNC/length/probe). Hand-edited settings.json values (whitespace, relative, UNC) can no longer reach the filesystem unchecked.
- Form rejections carry `configuredFailure: error ?? reason` so the D-04 fallback notice fires for malformed settings values too (the review snippet's bare `error` would have left form rejections null). `ErrorLogLocationResolved.configuredFailure` doc updated to document the reason-enum case.
- Pure-whitespace values are treated like `''` (silent default chain, no failure marker) — consistent with D-03's empty = reset semantics.
- Whitespace-padded valid directories still win the configured tier via the internal trim.
- Opportunistic IN-05 in the same function: the shadowing local `configuredDirectory` disappeared with the rewrite, and the redundant `on FileSystemException` clauses (subsumed by `on IOException`) were dropped in `resolve` and `_prepareTier`.
- New tests (group `启动配置层校验契约 WR-03`): whitespace-only skips to default chain; relative falls back carrying `notAbsolute`; `//server/share` falls back carrying `uncPathUnsupported`; whitespace-padded valid directory wins via trim.

### WR-04: UNC rejection bypassable with forward-slash form

**Files modified:** `lib/kernel/diagnostics/error_log_location.dart`, `test/diagnostics/error_log_location_test.dart`
**Commit:** `9e0077d6` (coupled to WR-03, same function)
**Status:** fixed

- **Premise correction (verified empirically):** on Dart 3.13/Windows, `Directory('//server/share').isAbsolute` is **false**, so the forward-slash UNC was already rejected today — but as `notAbsolute`, not the A3 UNC reason, contrary to the review's premise. The A3 rejection was not actually bypassable; the *reason* was wrong.
- Fix: the UNC check (`startsWith('\\\\') || startsWith('//')`) now runs **before** the isAbsolute form check, so both spellings get the identical `uncPathUnsupported` reason, toolchain-independently. Doc comments and enum doc updated.
- New test: `forward-slash UNC form is rejected identically (WR-04)`.

### WR-05: Unserialized persists share one `.tmp`

**Files modified:** `lib/ui/dialogs/settings/error_feedback_settings.dart`, `test/diagnostics/error_feedback_settings_store_test.dart`
**Commit:** `c6c95d9b`
**Status:** fixed: requires human verification (concurrency logic)

- Both fixes applied: persists are chained via `_schedulePersist` (at most one `_atomicWrite` in flight, error-swallowing adapter keeps the chain alive) **and** the tmp file name is unique per write (`settings.json.tmp.<pid>-<micros>`), which also protects against out-of-chain multi-process/multi-instance writers.
- The `finally` cleanup deletes only its own tmp; the level-3 `target.delete()` of a valid file can no longer be caused by a concurrent writer of the same store instance.
- Existing tmp-residue assertion strengthened to "no `.tmp*` anywhere in the directory".
- New test: `rapid successive persists serialize; final state is the last write` (three back-to-back writes crossing both setters).

### WR-06: MSIX target cannot persist settings

**Files modified:** `lib/ui/dialogs/settings/error_feedback_settings.dart`, `lib/main.dart`, `test/diagnostics/error_feedback_settings_store_test.dart`
**Commit:** `f2665fad`
**Status:** fixed: requires human verification (tier-selection design)

- Two-tier store mirroring D-02: exe-side (debug: project cwd) `settings.json` primary; when its directory fails a one-time writability probe, Application Support `settings.json` is used and remembered for the session (no per-write probing). Silent-failure D-01 semantics preserved end to end.
- The probe reuses kernel's `validateConfiguredDirectory` (single validation implementation — no second probe logic in UI). `load()` accepts an optional `ApplicationSupportDirectoryProvider`; `main.dart` passes `getApplicationSupportDirectory`. Provider un-injected or both tiers unwritable → layer-1 file object retained, reads/writes fail silently.
- `_resolvedSettingsFile` session cache is cleared by `resetForTesting` (test isolation).
- New tests (group `两层回退 WR-06`): probe-fail primary → AS tier used for both read and write (round-trip proven, primary never created); both tiers unwritable → defaults in memory, no crash, silent persist.

### IN-01: `_fellBack` case-sensitive compare

**Files modified:** `lib/ui/dialogs/settings/general_settings_content.dart`, `test/widget/dialogs/general_settings_content_test.dart`
**Commit:** `8a9c5539`
**Status:** fixed

- Both sides are lower-cased before the prefix compare (Windows case-insensitive filesystem). New test: case-flipped configured directory no longer shows the spurious `已回退到默认位置` line.

### IN-02: Picker failure reuses misleading `notWritable` copy

**Files modified:** `lib/ui/dialogs/settings/general_settings_content.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, generated l10n, test
**Commit:** `8a9c5539`
**Status:** fixed

- New UI-local `_PickerFailureStatus` sealed variant + ARB key `logPathPickerFailureStatus` (en "Could not open the directory picker" / zh "无法打开目录选择器"). Deliberately **not** added to kernel's `ConfiguredDirectoryFailure` closed set — a picker invocation failure is not a directory-validation failure. Generated l10n regenerated via `flutter gen-l10n`. New test: picker throw shows the dedicated copy with zero side effects.

### IN-04: Hardcoded full-width colon in the effective-path line

**Files modified:** ARB (en+zh) + generated l10n, `lib/ui/dialogs/settings/general_settings_content.dart`, test
**Commit:** `8a9c5539`
**Status:** fixed

- `logEffectivePathLabel` became a placeholder string (`"Effective log location: {path}"` / `"当前有效路径：{path}"`); code renders `l10n.logEffectivePathLabel(path)`. zh rendering is byte-identical to before; en gains the ASCII colon.

### IN-05: Kernel hygiene (parameter shadowing, redundant catch chain)

**Files modified:** `lib/kernel/diagnostics/error_log_location.dart`
**Commit:** `9e0077d6`
**Status:** fixed (opportunistic, inside the WR-03 commit — same file/function)

- Shadowing local eliminated by the rewrite; redundant `on FileSystemException` clauses dropped (subsumed by `on IOException`) in `resolve` and `_prepareTier`.

### IN-06: Analyzer const nit in the error-card mount

**Files modified:** `lib/app.dart`
**Commit:** `bfff1abf`
**Status:** fixed

- Windowed-branch `Positioned` is now fully `const` (`Tokens.controlBarMarginH` and top-level `const _errorCardWindowedTop` are compile-time constants).

### IN-07: Debug `settings.json` not gitignored

**Files modified:** `.gitignore`
**Commit:** `d67055a9`
**Status:** fixed

- Added `/settings.json` (with comment) — debug builds write the portable store beside the project cwd.

## Skipped Issues

### IN-03: One l10n string serves all five validation-failure reasons

**File:** `lib/l10n/app_en.arb:500-503`
**Reason:** Deferred — not in the enumerated cheap-info list. Closing it means 4+ new ARB keys × 2 locales plus a per-reason mapping switch; the single-copy mapping is documented in the ARB description as an accepted tradeoff, and the reason wording deserves its own copy-review pass.
**Original issue:** `notAbsolute` / `invalidCharacters` / `uncPathUnsupported` / `pathTooLong` / `notWritable` all render "Cannot write to this directory".

### IN-08: `apply` with an unattached coordinator returns Valid while doing nothing

**File:** `lib/ui/dialogs/settings/diagnostic_log_target.dart:109-130`
**Reason:** Deferred — unreachable in production (attach precedes runApp), and changing the retarget protocol's failure contract immediately after WR-01 stabilized it deserves its own review cycle with a dedicated test.
**Original issue:** unattached `apply` saves the store value but reports `ConfiguredDirectoryValid`.

## Verification

| Gate | Result |
|------|--------|
| `flutter test test/diagnostics/ test/widget/dialogs/ test/widget/player/` | 577/577 pass (incl. 12 new tests) |
| `flutter test` (full suite) | 1389/1389 pass — zero failures, mdk.dll baseline not even triggered |
| `flutter analyze` | 0 errors, 0 warnings; 0 issues in any touched file |
| `bash tool/audit/kernel_logger_gate.sh` | PASS (LOG-01, LOG-04) |

**Verification environment:** main working tree `D:/simple_player_flutter` on `master`, per orchestrator directive (no worktree, no recovery sentinel). All gates reproducible from this tree at `8a9c5539`.

**Commits (all `fix(04): …`, staged files only; `.mcp.json` / `pubspec.yaml` / `pubspec.lock` / `.planning/state.json` / `.planning/agent-history.json` left untouched):**
- `42239049` WR-01 serialize retarget applies and read back delegate path
- `13e323d2` WR-02 seed directory input from store, not effective file path
- `9e0077d6` WR-03 + WR-04 startup tier single validation contract + forward-slash UNC
- `c6c95d9b` WR-05 chain persists and use unique tmp per write
- `f2665fad` WR-06 Application Support fallback tier for settings store
- `bfff1abf` IN-06 const Positioned
- `d67055a9` IN-07 gitignore settings.json
- `8a9c5539` IN-01/02/04 inline copy polish

**Human verification flags (logic-classified fixes):** WR-01 (serialization + read-back), WR-05 (persist chain + unique tmp), WR-06 (tier selection/probe) — tests prove behavior in-process, but real-machine confirmation (esp. an MSIX install writing to Application Support) is worthwhile before calling the milestone done.

---

_Fixed: 2026-08-31T19:45:48Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
