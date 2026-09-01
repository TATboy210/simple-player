---
phase: 03-playback-error-card-bridge
reviewed: 2026-08-31T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - lib/app.dart
  - lib/main.dart
  - lib/kernel/models/player_error.dart
  - lib/l10n/app_en.arb
  - lib/l10n/app_zh.arb
  - lib/l10n/app_localizations.dart
  - lib/l10n/app_localizations_en.dart
  - lib/l10n/app_localizations_zh.dart
  - lib/ui/player/error_capture_snapshot.dart
  - lib/ui/player/error_card.dart
  - lib/ui/player/error_card_host.dart
  - lib/ui/player/player_video_controls.dart
  - lib/ui/theme/tokens.dart
  - test/widget/player/error_banner_equivalence_test.dart
  - test/widget/player/error_card_host_test.dart
  - test/widget/player/error_card_test.dart
findings:
  critical: 2
  warning: 3
  info: 4
  total: 9
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-08-31
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Phase 3 wires the error card presentation chain (ErrorCardHost → ErrorCard, snapshot effect D-11, builder mount D-10, legacy ErrorBanner removal — grep-verified zero `ErrorBanner` matches in `lib/`). Cross-file contracts against `ErrorReporterImpl` / `ErrorReport` / `formatDiagnosticPack` / `OsdService` are consistent; l10n key coverage (13 keys, en+zh+generated) is complete; CARD-01 zero-focus and CARD-04 copy-failure isolation are correctly implemented and tested; the phase-severity model in `player_error.dart` is untouched and sound.

However, two behavioral defects were found, one of which was **empirically reproduced** with a throwaway widget probe (created, run, and deleted; test tree left clean): the expanded error card is laid out **unconstrained in the production mount** (1133 logical px wide on an 800 logical px window), and the badge-cycle index is **not reset when a new error arrives**, contradicting the documented D-01 contract. Both bugs escape the current test suite because all widget harnesses mount the card under bounded `Align`/`Center` constraints, unlike the real `Positioned(left, top)` intrinsic-size mount.

## Critical Issues

### CR-01: Expanded ErrorCard renders unconstrained in the production mount — card wider than the window, scroll/Flexible no-ops, giant hit-rect swallows app clicks

**File:** `lib/app.dart:94-105`, `lib/ui/player/error_card.dart:303-317`, `lib/ui/player/error_card.dart:340-376`, `lib/ui/theme/tokens.dart:262-264`
**Issue:** The mount is `Positioned(left:…, top:…)` with intrinsic sizing. RenderStack lays out a positioned child that lacks opposing anchors (or explicit width/height) with **unbounded** width and height constraints. Consequences in the real app:

1. `error_card.dart:362-364` renders `SelectableText(report.rawStackTrace)` with no width constraint — with infinite width, text never soft-wraps, so the expanded card sizes to the longest stack line (stack is bounded at 16384 chars). Same for `location.primaryFrame.file:line member` (`:346-350`) and the basename `Text` at `:303`.
2. The `Flexible(child: SingleChildScrollView(…))` at `:308-317` is a no-op under unbounded height: with `mainAxisSize: MainAxisSize.min` + `FlexFit.loose` and infinite incoming height, flex children get unbounded space, so nothing scrolls and the expanded card runs off the bottom of the window.
3. Because `ClipRRect` clips hit-testing to the card rect (CARD-02 basis, per the class doc), a card wider than the window **absorbs clicks across the whole window**, breaking every interaction below it while expanded.

**Empirical reproduction** (scratch probe test, since deleted): mounting `buildErrorCardMount` with a realistic expanded report produced `ErrorCard` rect `Rect.fromLTRB(18.0, 12.0, 1151.0, 246.0)` — **1133 logical px wide on an 800×600 logical window**. All existing tests pass because they mount the card inside bounded `Align`/`Scaffold` harnesses.

Supporting evidence of intent: `Tokens.errorCardExpandedMaxWidth = 420.0` (`tokens.dart:262-264`, "Expanded details max width — wider than collapsed for stack readability") is declared but **never referenced anywhere in `lib/`** — the width constraint was planned and never wired.

**Fix:**
```dart
// lib/app.dart — bound the host; keeps intrinsic top-left placement and hit-test passthrough
const Positioned(
  left: Tokens.controlBarMarginH,
  top: Tokens.spMd,
  child: RepaintBoundary(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: Tokens.errorCardExpandedMaxWidth,
        maxHeight: 480, // or a viewport-fraction token; enables the expanded scroll path
      ),
      child: ErrorCardHost(),
    ),
  ),
),
```
Then make the expanded sections wrap inside the bounded width (e.g., wrap section widgets in `SizedBox(width: double.infinity, …)` or apply the same `ConstrainedBox` used for the collapsed message), and add a regression test that expands the card through `buildErrorCardMount` (the production mount path) asserting `tester.getRect(find.byType(ErrorCard)).width <= Tokens.errorCardExpandedMaxWidth`.

### CR-02: Badge-cycle index is not reset when a new report arrives — D-01 "new error replaces card content" is violated while cycling

**File:** `lib/ui/player/error_card_host.dart:54-58` (documented contract), `:96-105` (`_onSnapshotChanged`), `:162-164` (`_cycleBadge`)
**Issue:** The field doc states: "轮览索引：0 = 最新（快照尾）；正数向旧偏移；**新报告到达或手动关闭时重置到 0**". Only `_onClose` (`:176`) resets `_cycleIndex`. `_onSnapshotChanged` merely calls `setState(() {})` — no reset. Trace: snapshot `[A,B,C]`, user taps the badge twice → offset 2 → displays `history[0]` = A. New report D arrives → snapshot `[A,B,C,D]` → offset `2 % 4 = 2` → displays `history[1]` = **B**, not D. The newest error is never shown until the user manually cycles; every further arrival keeps displaying stale entries. This silently defeats the D-01 replacement semantics that the same comment block and `error_card_host_test.dart` ("newest error replaces the card") claim — that test never cycles before the arrival, so it cannot catch this.

**Fix:**
```dart
void _onSnapshotChanged() {
  // 新报告/合并到达时轮览失效 —— 重置到最新，保证 D-01 替换语义。
  if (_cycleIndex != 0) _cycleIndex = 0;
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.idle) {
    setState(() {});
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cycleIndex = 0;
        setState(() {});
      }
    });
  }
}
```
Add a test: cycle to oldest, accept a new report, assert the card shows the new report (not the shifted stale one).

## Warnings

### WR-01: Close button dismisses the FIFO head, which is not necessarily the report being displayed — closing a visible card silently discards a different (unseen) error

**File:** `lib/ui/player/error_card_host.dart:171-178` (`_onClose`), `:213-222` (`_displayedReport`)
**Issue:** The card renders the **snapshot newest** (or cycled entry), while `_onClose` consumes `presentation.value.current` (the reporter **FIFO head = oldest** undismissed report) via `dismissCurrent`. With ≥2 pending errors the user sees report B, clicks close, and report A (possibly never displayed) is consumed; the visible content does not change (only the badge decrements). The comment block documents the FIFO constraint, but the display/dismiss divergence is a real logic inconsistency: the visible close button does not close what is visible. It also widens the blast radius of CR-02 (stale display + head-dismiss compounding).

**Fix:** Either (a) dismiss by the displayed report's identity — add a narrow `dismissById(String eventId)` seam to `ErrorReporter` (kernel change needs phase sign-off) and pass the displayed report's `eventId` down from the host; or (b) keep head-dismissal but display the head (drop the newest-first view) so the closed item is always the shown item. Current behavior should at minimum be documented as a known divergence in the phase docs if deferred.

### WR-02: ErrorCardHost accesses `ErrorReporterImpl.I` unguarded; copy-failure branch can turn into a `StateError` escaping the failure-isolation catch

**File:** `lib/ui/player/error_card_host.dart:70,81,87`, `lib/ui/player/error_card.dart:156`
**Issue:** `initState` (`:70`) and `dispose` (`:87`) call `ErrorReporterImpl.I` directly, which throws `StateError` when the reporter is not initialized. `ErrorCard._resolveLogPath` (`:129-132`) carefully guards with `ErrorReporterImpl.isInitialized`, so the defensive posture is inconsistent across the same feature. Today `main.dart:44-47` initializes the reporter before `runApp`, so production is safe; but the host is a public widget any future test or screen can mount standalone, and dispose-ordering changes would produce a crash at teardown. Similarly, in `_copyDiagnosticPack`'s `on PlatformException` branch, `KernelLogger.I.w(...)` (`:156`) throws `StateError` if the logger was never initialized — converting a *contained* copy failure into an unhandled exception (contradicts T-03-11 "异常绝不外溢到调用方").

**Fix:** Guard host listeners with `ErrorReporterImpl.isInitialized` (no-op / defensive logging when absent), and in the copy catch use `if (KernelLoggerImpl.isInitialized)` or route through a `try` around the log call so the failure path cannot itself throw.

### WR-03: `_isFullscreenTransition` is only cleared by a `resizing → false` event — a fullscreen transition without a resize event leaves the flag stuck

**File:** `lib/ui/player/player_video_controls.dart:555-558` (set), `:578-598` (`_onResizeChanged` clear)
**Issue:** `_syncModeFullscreen` sets `_isFullscreenTransition = true` on every fullscreen enter/exit; the only clear site is the `resizing == false` branch of `_onResizeChanged` (`:589`). If a mode transition completes without a window-resize signal (or the resize event arrives before the mode change, or is swallowed during the inactive window), the flag stays `true` indefinitely, and the **next** real window resize will skip `_animController.reverse()` (`:584-586`) — the control bar fails to fade during that resize. Self-heals only after one full resize cycle.

**Fix:** Clear the flag deterministically at transition end, e.g. schedule a post-frame/short-timer reset when it is set, or clear it at the top of `_onResizeChanged`'s `resizing == true` branch after one skip:
```dart
if (resizing) {
  _isResizing = true;
  if (_isFullscreenTransition) {
    _isFullscreenTransition = false; // consume the one-shot suppression
  } else {
    _animController.reverse();
  }
}
```

## Info

### IN-01: Stale seek-distance doc — comment and CLAUDE.md say ±5s, code seeks 10s back / 30s forward

**File:** `lib/ui/player/player_video_controls.dart:456` (doc comment), `:488-494` (implementation); `lib/ui/theme/tokens.dart:346-347`
**Issue:** `_handleKeyEvent` doc says "←→(seek ±5s)" but uses `Tokens.skipShortMs` (10000 ms) for back and `Tokens.skipLongMs` (30000 ms) for forward — asymmetric, and inconsistent with the project CLAUDE.md shortcut table (Left/Right = ±5s). Behavior is at least consistent across `center_controls.dart` and `player_keyboard_actions.dart`, so this is doc drift, but the asymmetry (10s back vs 30s forward) deserves an explicit decision or correction.
**Fix:** Update the comment/CLAUDE.md to the real values, or align the constants if ±5s symmetric was the intent.

### IN-02: Nested vertical `SingleChildScrollView` around the stack `SelectableText` is dead code

**File:** `lib/ui/player/error_card.dart:362-364`
**Issue:** The stack section wraps `SelectableText` in an inner vertical `SingleChildScrollView` inside the outer expanded `SingleChildScrollView`. Under the outer scrollable the inner receives unbounded height and expands to full content height — it can never scroll. Even once CR-01 bounds the card, nested same-axis scrollables cause gesture conflicts.
**Fix:** Delete the inner wrapper (the outer scroll covers it), or make the inner one horizontal if long-token scrolling was the goal.

### IN-03: Snapshot-empty fallback renders a visible card with a "0 错误" badge

**File:** `lib/ui/player/error_card_host.dart:215-222`, `lib/ui/player/error_card.dart:239`
**Issue:** `_displayedReport` falls back to `state.current` when the snapshot is empty (effect-less mounts), but `totalCount` is still `history.length == 0`, so the card shows a "0 错误" badge while displaying an error. Unreachable in production wiring (main.dart always registers the snapshot effect) but reachable in future tests/mounts.
**Fix:** `totalCount: history.isEmpty ? 1 : history.length`, or hide the badge when the snapshot is empty.

### IN-04: Test comment names a non-existent constant

**File:** `test/widget/player/error_card_host_test.dart:425`
**Issue:** Comment references "命名常量 `_maxSnapshotLength`"; the actual constant is `ErrorCaptureSnapshot.maxLength` (`error_capture_snapshot.dart:26`).
**Fix:** Correct the comment to `ErrorCaptureSnapshot.maxLength`.

## Verified-clean notes (adversarial checks that passed)

- **D-07 redaction (T-03-05):** collapsed and expanded trees render only `mediaPath`/basename; `fullMediaPath`/`failedOpenPath` appear solely in `formatDiagnosticPack` output (developer evidence, clipboard/log only). Tests lock both collapsed and expanded trees (`error_card_test.dart:461-484`).
- **CARD-01:** `ExcludeFocus` + `GestureDetector`-only interactions; no `GlassButton`/`FocusableActionDetector` in the card subtree; asserted in tests.
- **CARD-04:** typed `PlatformException`/`MissingPluginException` catch, l10n resolved before `await`, no `context` use after `await`, OSD feedback on both paths; format via `formatDiagnosticPack` single source (LOG-05), logPath read at copy time.
- **CARD-05 phase guard:** deferred re-read of `presentation.value` at frame end is correct (converges same-frame multi-report to one terminal value); same guard applied to snapshot changes; both tested.
- **Warning routing (D-02):** single-dismiss dedupe via `_lastWarningEventId` is sound (eventIds are unique; dismissed warnings cannot re-merge); snapshot effect filters warnings symmetrically with the host.
- **Snapshot boundedness:** 20-entry cap with oldest-eviction; merge replaced in place by `eventId`; `removeById` no-op on miss — all consistent with the reporter's 5-entry FIFO supersets.
- **l10n:** 13 error-card keys present in en/zh ARB and both generated localizations; `errorCardBadgeLabel`/`errorCardSectionRepeats` placeholder metadata present in the en template; `_resolveMessage`'s 13-key switch is exhaustive over `FileErrorCode`/`CodecErrorCode`/`PlaybackErrorCode`/`NetworkErrorCode` plus `error.unknown` with a safe raw-message fallback.
- **Legacy banner removal:** grep confirms zero `ErrorBanner|error_banner` matches under `lib/`; `player_video_controls.dart:881-882` retains only the routing comment.
- **Kernel red lines:** no kernel files modified by this phase (`error_capture_snapshot.dart` consumes the existing `ErrorReportEffect` seam from `lib/`); no `debugPrint` in kernel; no MediaKitEngine/media_kit `Player` construction in any of the three test files (fakes + real reporter intake only).

---

_Reviewed: 2026-08-31_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
