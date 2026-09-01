---
phase: 04-error-feedback-settings
reviewed: 2026-09-01T00:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - lib/app.dart
  - lib/main.dart
  - lib/kernel/diagnostics/error_log_location.dart
  - lib/l10n/app_en.arb
  - lib/l10n/app_zh.arb
  - lib/l10n/app_localizations.dart
  - lib/l10n/app_localizations_en.dart
  - lib/l10n/app_localizations_zh.dart
  - lib/ui/dialogs/settings/diagnostic_log_target.dart
  - lib/ui/dialogs/settings/error_feedback_settings.dart
  - lib/ui/dialogs/settings/general_settings_content.dart
  - lib/ui/dialogs/settings/settings_dialog.dart
  - lib/ui/player/error_card_host.dart
  - test/diagnostics/diagnostic_log_target_test.dart
  - test/diagnostics/error_feedback_settings_store_test.dart
  - test/diagnostics/error_log_location_test.dart
  - test/widget/dialogs/general_settings_content_test.dart
  - test/widget/dialogs/settings_dialog_test.dart
  - test/widget/player/error_card_host_test.dart
findings:
  critical: 0
  warning: 6
  info: 8
  total: 14
status: findings
---

# Phase 4: Code Review Report

**Reviewed:** 2026-09-01
**Depth:** standard
**Files Reviewed:** 19
**Status:** findings (0 critical / 6 warning / 8 info)

## Summary

Reviewed the Phase 4 error-feedback settings slice: portable JSON store, three-tier log
location chain, `DiagnosticLogTarget` retarget coordinator, D-04 dual-channel fallback
notice, SET-01 render gate, and the settings shell / general tab. Cross-file seams were
verified against their definitions (`DelegatingDiagnosticLogEffect`, `ErrorLogFileSink`,
`ErrorPresentationState`, `OsdService`, `WindowBridge.mode`, `Tokens.*`, generated l10n).

**Verified in this review (evidence, not trust):**
- `flutter analyze`: 0 errors, 0 warnings (61 infos, all pre-existing except one new
  const nit in `app.dart:125` — IN-06).
- `flutter test` on the six phase test files: 75/75 pass.
- Kernel red line held: only `error_log_location.dart` changed in `lib/kernel/`; no
  `debugPrint` added there; reporter / single-writer / delegate semantics untouched.
- media_kit untouched; no `MediaKitEngine` construction in tests.
- l10n: ARB keys and the three generated files are consistent (9 new keys, en+zh).
- D-05 gate confirmed render-only: `record`/snapshot never query the toggle; warning
  routing and cycle reset stay outside the gate (locked by tests).

**Key concerns:** the retarget protocol has no in-flight serialization, so two overlapping
`apply` calls can leave the active sink at the stale target while the UI reports the new
one (WR-01) — this silently misroutes diagnostic evidence, which is the core promise of
the milestone. Second, the directory input is seeded with the effective *file* path
(`…\logs\error.log`), so incremental edits from the seed can silently create a nested
`error.log/` directory tree (WR-02). Third, the startup load path bypasses the
`validateConfiguredDirectory` contract that the UI path enforces (WR-03/WR-04).

## Critical Issues

None found.

## Warnings

### WR-01: Concurrent `apply` calls are not serialized — the sink can end up at the stale target while the UI reports the new one

**File:** `lib/ui/dialogs/settings/diagnostic_log_target.dart:109-130,170-173` (with `lib/ui/dialogs/settings/general_settings_content.dart:110-130`)

**Issue:** `apply()` has no in-flight guard. `GeneralSettingsContent._commitPathInput`
fires on every debounce expiry and each invocation runs `validate → save → _swapTo`
concurrently. `_swapTo` is `await dispose(); activateResolved();` and the delegate's
`activate` is a one-shot lock that only `dispose` resets. Two overlapping applies can
interleave as: A.dispose → B.dispose → A.activate(A) → B.activate(B) — B's `activate`
hits the still-locked state and is silently swallowed (warn-and-return inside
`DelegatingDiagnosticLogEffect.activate`), but `activateResolved` still sets
`effectiveLogPath.value = B` and returns `ConfiguredDirectoryValid`. Result: the delegate's
active sink stays at A (the older input), while `effectiveLogPath`, the settings store,
and the settings UI all claim B. Every subsequent diagnostic record lands in the file the
UI says is not active — the exact "named black box" failure this milestone exists to
prevent. The 300 ms debounce does not prevent this: validation involves real
create+probe+flush I/O, which on the documented AV/errno-5-heavy directories can exceed
300 ms. The implementers acknowledged the race in
`test/widget/dialogs/general_settings_content_test.dart:196-198` but mitigated it only in
test waits, not in production code.

**Fix:** serialize the retarget protocol in the coordinator, e.g. chain applies so each
waits for the previous one to settle:

```dart
Future<void> _retargetQueue = Future<void>.value();

Future<ConfiguredDirectoryValidation> apply(String directory) {
  final job = _retargetQueue.then((_) => _applyGuarded(directory));
  _retargetQueue = job; // Future<void> adapter: swallow to keep the chain alive
  return job;
}
```

Additionally, make `activateResolved` truthful under contention by reading back the
delegate's actual post-activate state (`_effect?.logPath.value`) instead of asserting
`file.path` unconditionally.

### WR-02: Directory input is seeded with the effective *file* path — incremental edits build on `…\logs\error.log`

**File:** `lib/ui/dialogs/settings/general_settings_content.dart:90-94`

**Issue:** `initState` seeds `_pathController` with
`DiagnosticLogTarget.I.effectiveLogPath.value ?? ''`, which is the resolved log *file*
(`_logFileIn` produces `<dir><sep>error.log`), not the configured directory. The field's
committed value is stored as `logDirectory` (a directory). Consequences:
1. Reopening settings with a configured directory shows `D:\mylogs\error.log` in a
   directory-typed input, diverging from the stored value `D:\mylogs`.
2. Any incremental edit from the seed (e.g. changing only the drive letter) commits a
   path whose final segment is the existing `error.log` file — or, on a fresh drive,
   `validateConfiguredDirectory` happily `create(recursive: true)`s *directories* named
   `mylogs\error.log`, the probe passes, and the garbage path is saved as the configured
   directory (sink then writes to `E:\mylogs\error.log\error.log`).

**Fix:** seed from the store, not the file path:

```dart
_pathController = TextEditingController(
  text: ErrorFeedbackSettings.I.state.value.logDirectory,
);
```

and keep the full effective file path only in the always-visible `_EffectivePathLine`
(D-04 first channel), which already renders it.

### WR-03: Startup resolve path bypasses the documented configured-directory validation contract

**File:** `lib/kernel/diagnostics/error_log_location.dart:141-156` (with `lib/main.dart:142`)

**Issue:** `validateConfiguredDirectory` enforces trim/absolute/control-char/UNC/length
rules and is documented as "校验即证明 sink 可用" for the configured directory. But the
`resolve` configured tier only checks `configured != null && configured.isNotEmpty` —
no trim, no form validation. `main.dart:142` feeds `state.logDirectory` raw from
settings.json, so a hand-edited file containing `" "` (whitespace), a relative path such
as `logs`, or `//server/share` is accepted by the startup chain: a whitespace value
creates and probes a relative directory under the *process cwd* and wins tier 1, writing
evidence to `./error.log` relative to wherever the process was started. The UI path
rejects exactly these inputs, so load-time and UI-time behavior disagree.

**Fix:** route the configured tier through the single validation implementation:

```dart
if (configured != null && configured.trim().isNotEmpty) {
  final validation = await validateConfiguredDirectory(configured, writable: probe);
  switch (validation) {
    case ConfiguredDirectoryValid(:final directory):
      return ErrorLogLocationResolved(_logFileUnder(directory));
    case ConfiguredDirectoryInvalid(:final error):
      return _resolveDefaultChain(probe, applicationSupportDirectory,
          executableDirectory, configuredFailure: error);
  }
}
```

This also makes the D-04 fallback notice fire for malformed settings values.

### WR-04: UNC rejection (A3) is bypassable with forward-slash form

**File:** `lib/kernel/diagnostics/error_log_location.dart:201-205`

**Issue:** A3 (documented in the enum and doc comment) rejects `\\server\share` because a
dropped network share silently strands diagnostic evidence. The check is
`trimmed.startsWith('\\\\')` only. On Windows, `//server/share` is also an absolute UNC
path (`Directory('//server/share').isAbsolute` is true under the Windows path style), so
typing or storing the forward-slash form passes all form checks and the tier is accepted
whenever the share happens to be reachable — reintroducing the exact failure mode A3
rejected.

**Fix:** normalize separators before the prefix test, or reject both spellings:

```dart
final normalized = trimmed.replaceAll('/', Platform.pathSeparator);
if (normalized.startsWith('\\\\')) { // after normalization this catches //server too
  return const ConfiguredDirectoryInvalid(ConfiguredDirectoryFailure.uncPathUnsupported);
}
```

### WR-05: Unserialized persists share one `.tmp` path — rapid writes can lose the final value

**File:** `lib/ui/dialogs/settings/error_feedback_settings.dart:111-130,162-195`

**Issue:** `setCardEnabled`/`setLogDirectory` both do `_persistFuture = _persist(next)`
with no chaining. Two rapid writes run `_atomicWrite` concurrently against the *same*
`settings.json.tmp`: on Windows the second `writeAsString` can fail with a sharing
violation (write silently lost — memory says B, disk says A), and the third-level
fallback deletes the live target before re-renaming, so a failed fourth level leaves the
previously *valid* settings file deleted. Each individual loss is nominally covered by
D-01 silence, but the destruction of a good file by a concurrent writer is an avoidable
artifact, not a graceful fallback.

**Fix:** chain persists so at most one `_atomicWrite` is in flight:

```dart
_persistFuture = _persistFuture.then((_) => _persist(next));
```

### WR-06: Shipped MSIX target cannot persist settings — exe-side `settings.json` has no fallback tier

**File:** `lib/ui/dialogs/settings/error_feedback_settings.dart:65-70`

**Issue:** Release stores settings beside the executable. The declared distribution target
is MSIX (`pubspec.yaml:76`, `distribute_options.yaml`), whose install directory
(`WindowsApps`) is ACL-protected: every `_persist` fails silently and every `load` finds
nothing, so the SET-01 toggle and SET-02 directory silently reset on each launch of the
packaged app. Unlike the log-location chain (exe root → Application Support), the
settings store has a single tier and no fallback. This is a design-level tension (D-01
"便携哲学" was a deliberate decision) rather than a coding slip, but the shipped-package
behavior contradicts the phase goal of durable preferences.

**Fix:** mirror the log-chain design — probe the exe-side file's directory writability
once (temp-file probe, not `attrib`), and fall back to
`getApplicationSupportDirectory()/settings.json` when it is not writable. At minimum,
document that MSIX installs do not persist settings.

## Info

### IN-01: `_fellBack` prefix compare is case-sensitive on a case-insensitive filesystem

**File:** `lib/ui/dialogs/settings/general_settings_content.dart:278-285`

**Issue:** On Windows, `D:\apps\player` (user-typed) vs the resolved `D:\Apps\Player\logs\error.log`
(exe-derived) fails `startsWith` and shows a spurious "已回退到默认位置" line. Best-effort
heuristic per its own doc, so display-only.

**Fix:** case-fold both sides before comparison (or `equalsIgnoreCase`-style compare on
Windows only).

### IN-02: Directory-picker failure reuses the misleading `notWritable` copy

**File:** `lib/ui/dialogs/settings/general_settings_content.dart:140-150`

**Issue:** A `file_picker` exception renders "无法写入该目录", which blames the (unshown)
directory rather than the picker. The closed set has no picker-failure reason.

**Fix:** add a `ConfiguredDirectoryFailure.pickerUnavailable`-style reason (or an l10n
string) instead of overloading `notWritable`.

### IN-03: One l10n string serves all five validation-failure reasons

**File:** `lib/l10n/app_en.arb:500-503`, `lib/ui/dialogs/settings/general_settings_content.dart:127-128`

**Issue:** `notAbsolute` / `invalidCharacters` / `uncPathUnsupported` / `pathTooLong` /
`notWritable` all render "Cannot write to this directory" — a user entering a relative
path or UNC share gets a message about a directory that was never probed. The single-copy
mapping is documented in the ARB description, so this is an accepted tradeoff; flagging
because the sealed reason enum was built precisely to avoid message collapse.

**Fix:** map at least `notAbsolute` and `uncPathUnsupported` to dedicated strings.

### IN-04: Hardcoded full-width colon in the effective-path line

**File:** `lib/ui/dialogs/settings/general_settings_content.dart:434`

**Issue:** `'${l10n.logEffectivePathLabel}：$path'` hardcodes `：`; English renders
"Effective log location：C:\…".

**Fix:** move the separator into the ARB string (e.g. `"logEffectivePathLabel": "Effective log location: {path}"`).

### IN-05: Minor kernel hygiene — parameter shadowing and redundant catch chain

**File:** `lib/kernel/diagnostics/error_log_location.dart:145,162-168,285-291`

**Issue:** (a) `final configuredDirectory = Directory(configured)` shadows the
`String? configuredDirectory` parameter — legal but confusing in a resolver that also
takes a same-named `Directory` elsewhere. (b) `on FileSystemException` is redundant
before `on IOException` (`FileSystemException extends IOException`) in both `resolve`
and `_prepareTier`.

**Fix:** rename the local (e.g. `configuredDir`), drop the redundant `FileSystemException`
clauses.

### IN-06: Analyzer const nit in the error-card mount

**File:** `lib/app.dart:125`

**Issue:** `flutter analyze` reports `prefer_const_constructors` — the `mode == null`
branch's `Positioned(left: Tokens.controlBarMarginH, top: _errorCardWindowedTop, …)` can
be fully const (both operands are compile-time constants). Only new analyzer info in the
reviewed set.

**Fix:** make the `Positioned` const.

### IN-07: Debug-mode `settings.json` in the repo root is not gitignored

**File:** `lib/ui/dialogs/settings/error_feedback_settings.dart:65-70`, `.gitignore`

**Issue:** Debug runs place `settings.json` beside the project cwd once any toggle is
flipped; `git check-ignore` confirms it is untracked and unignored, so it can be
accidentally committed.

**Fix:** add `/settings.json` to `.gitignore`.

### IN-08: `apply` with an unattached coordinator returns Valid while doing nothing

**File:** `lib/ui/dialogs/settings/diagnostic_log_target.dart:109-130`

**Issue:** For a non-empty valid directory when `attach` never happened, `apply` saves the
store value, `_swapTo` is a no-op, and `activateResolved` early-returns — yet the caller
receives `ConfiguredDirectoryValid`. `_applyDefaultChain` handles the same condition as a
typed `Invalid` (`StateError('DiagnosticLogTarget is not attached')`). Unreachable in
production (attach precedes runApp), but the two branches disagree about the failure
contract.

**Fix:** reuse the `_applyDefaultChain` pattern — return
`ConfiguredDirectoryInvalid(notWritable, error: StateError(...))` when `_effect == null`.

---

_Reviewed: 2026-09-01T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
