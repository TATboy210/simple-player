---
phase: 03-playback-error-card-bridge
fixed_at: 2026-08-31T00:00:00Z
review_path: .planning/phases/03-playback-error-card-bridge/03-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 7
skipped: 2
status: partial
---

# Phase 3: Code Review Fix Report

**Fixed at:** 2026-08-31
**Source review:** `.planning/phases/03-playback-error-card-bridge/03-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 9 (2 critical / 3 warning / 4 info)
- Fixed: 7
- Skipped (deferred with rationale): 2 (WR-03, IN-01)

**Verification location:** all gates ran in the **main working tree** (`D:/simple_player_flutter`, master) — no worktree was used (per orchestrator EXECUTION MODE). Fix reconstruction note: the seven per-finding commits were rebuilt from HEAD one finding at a time; the final tree was byte-compared against a snapshot of the fully verified state before the last commit (`diff` = identical on all 6 touched files).

## Fixed Issues

### CR-01: Expanded ErrorCard renders unconstrained in the production mount

**Files modified:** `lib/app.dart`, `lib/ui/theme/tokens.dart`, `lib/ui/player/error_card.dart`, `test/widget/player/error_card_host_test.dart`
**Commit:** `375240fc`
**Applied fix:** production mount rework, not just a harness fix:

1. `buildErrorCardMount` now bounds the host: width ≤ `Tokens.errorCardExpandedMaxWidth` (420), height ≤ window height × `Tokens.errorCardMaxHeightRatio` (0.6, new token) so the expanded `Flexible(SingleChildScrollView)` actually scrolls instead of running off-window. Bounded width makes the long stack/location `SelectableText` soft-wrap (kills the 1133px-on-800px-window defect).
2. **Discovered latent production bug while fixing:** the card mount is a sibling of the Navigator (D-10 root-Stack layer), so the card subtree has **no Overlay ancestor** — any tap on a visible `SelectableText` threw `No Overlay widget found` (`TextSelectionOverlay` debug assert). Empirically probed at pristine HEAD with a throwaway test (created, run, deleted): confirmed pre-existing at HEAD — the old unbounded mount merely kept the stack text off-screen/tap-unreachable, and the bounded card would have exposed it. Fixed with a minimal local `Overlay` in the mount (`_ErrorCardOverlayMount`): the entry uses `OverlayEntry(canSizeOverlay: true)` so the theatre sizes to the card's intrinsic size (finite constraints would tight-fill and break intrinsic sizing/CARD-02 passthrough).
3. `ErrorCard` header message wrapped in `Flexible` so a long message (own 320px cap) cannot overflow the now-bounded Row.
4. New regression test `CR-01 挂载约束（生产 mount 路径）` mounts via `buildErrorCardMount` (production path, unbounded Positioned in a bare Stack) with a 30-line stack: asserts expanded card width ≤ `Tokens.errorCardExpandedMaxWidth`, card bottom ≤ window height, and taps outside the card rect still reach a probe below while expanded.

### CR-02: Badge-cycle index not reset when a new report arrives

**Files modified:** `lib/ui/player/error_card_host.dart`, `test/widget/player/error_card_host_test.dart`
**Commit:** `288c8f97`
**Applied fix:** `_onSnapshotChanged` now zeroes `_cycleIndex` before the phase-guarded rebuild (single reset covers both sync and post-frame branches). New test: 3 reports → cycle to oldest → new report arrives → card shows the NEW report (not the shifted stale entry), badge = 4.

### WR-01: Close button dismisses FIFO head which may differ from the displayed entry

**Files modified:** `lib/ui/player/error_card_host.dart`, `test/widget/player/error_card_host_test.dart`
**Commit:** `c878b3e9`
**Status: fixed — requires human verification** (policy choice, see below)
**Applied fix:** zero-kernel-change path chosen. The reporter API has no id-targeted dismissal (`dismissCurrent` only, `error_reporter.dart:235`); adding `dismissById` is a kernel change under Rule 4 red line without sign-off. Head-dismissal semantics retained and the divergence is now documented in the `_onClose` doc comment, with the invariant that no error is silently discarded: the head was always surfaced as newest on arrival (D-01) and remaining snapshot entries stay cyclable. New test `close while cycling keeps display and snapshot consistent (WR-01)` walks 3 reports through cycle→close→cycle→close→close, asserting every consumed entry was previously displayed, counts track, and the card clears at queue exhaustion.

### WR-02: Unguarded `ErrorReporterImpl.I` / `KernelLogger.I` access

**Files modified:** `lib/kernel/diagnostics/kernel_logger.dart`, `lib/ui/player/error_card.dart`, `lib/ui/player/error_card_host.dart`
**Commit:** `6b3139e2`
**Applied fix:** host `initState`/`dispose` and `_onClose` guard with `ErrorReporterImpl.isInitialized` (same probe `ErrorCard._resolveLogPath` already used); un-initialized mounts degrade to an inert host instead of throwing at teardown. Copy-failure paths (`PlatformException` catch and the `MissingPluginException` assert branch) check `KernelLoggerImpl.isInitialized` before logging. Added a read-only `static bool get isInitialized` to `KernelLoggerImpl` mirroring the existing `ErrorReporterImpl.isInitialized` pattern — 1-line additive probe, no reporter API change (Rule 4 not triggered).

### IN-02: Dead nested SingleChildScrollView around the stack SelectableText

**Files modified:** `lib/ui/player/error_card.dart`
**Commit:** `f0760cc7`
**Applied fix:** inner same-axis `SingleChildScrollView` deleted (outer expanded-area scroll covers it); class doc and section comment updated.

### IN-03: Snapshot-empty fallback renders a "0 错误" badge

**Files modified:** `lib/ui/player/error_card_host.dart`
**Commit:** `f8e0dcf5`
**Applied fix:** `totalCount: history.isEmpty ? 1 : history.length` so the presentation-fallback entry is counted truthfully.

### IN-04: Test comment names a non-existent constant

**Files modified:** `test/widget/player/error_card_host_test.dart`
**Commit:** `fb8a2c2b`
**Applied fix:** comment now references `ErrorCaptureSnapshot.maxLength`.

## Skipped Issues

### WR-03: `_isFullscreenTransition` only cleared by a `resizing → false` event

**File:** `lib/ui/player/player_video_controls.dart:368,557,584-589`
**Reason:** **pre-existing, not introduced by this phase** — deferred per fix instruction ("ONLY fix if this is a regression introduced by this phase's edits"). Evidence: `git log -S "_isFullscreenTransition" -- lib/ui/player/player_video_controls.dart` → introduced in `f146ee0a` ("feat(player): PlayerVideoControls 直连 player.stream", 路径B阶段1, pre-Phase-3); the only Phase-3 commit touching that file is `0805618b` (legacy banner deletion). Candidate one-shot-consume fix is in the review; route it to the state-machine repair round already tracked in project memory (progress-bar issue C-related state machine work).

### IN-01: Stale seek-distance doc (±5s comment vs 10s/30s constants)

**File:** `lib/ui/player/player_video_controls.dart:456`, `lib/ui/theme/tokens.dart:346-347`
**Reason:** deferred — this is cross-file doc drift (`_handleKeyEvent` comment, project CLAUDE.md shortcut table) over behavior that is consistent across `center_controls.dart` / `player_keyboard_actions.dart`; the real question is whether the asymmetric 10s-back/30s-forward is intentional. Needs a user decision (align constants to symmetric ±5s vs update docs) — silently "fixing" either side could contradict an existing UX decision.

## Verification

All gates re-run after the final commit (main working tree):

- `flutter test test/widget/player/` → **316 passed** (includes 4 new regression tests: CR-01 mount constraint, CR-02 cycle reset, WR-01 close/cycle consistency, plus IN-04 comment fix)
- `flutter test test/widget/player/error_banner_equivalence_test.dart` → **6 passed**
- `flutter test` (full suite) → **1313 passed**, 0 failed (mdk.dll baseline did not fire this run)
- `flutter analyze` → **0 errors / 0 warnings**; 59 issues, all pre-existing `prefer_initializing_formals` infos (baseline 59)
- `grep -rq ErrorBanner lib/` → **zero matches**
- Kernel red lines: no `debugPrint` added to `lib/kernel/` (only an additive `isInitialized` getter); no reporter API change; no MediaKitEngine/media_kit `Player` construction in tests; D-07 redaction untouched.

Commits (all `master`, staged files limited to the touched sources; `.mcp.json` / `pubspec.yaml` / `pubspec.lock` / `.planning/state.json` / `.planning/agent-history.json` untouched):

| Finding | Commit |
|---------|--------|
| CR-01 | `375240fc` |
| CR-02 | `288c8f97` |
| WR-01 | `c878b3e9` |
| WR-02 | `6b3139e2` |
| IN-02 | `f0760cc7` |
| IN-03 | `f8e0dcf5` |
| IN-04 | `fb8a2c2b` |

---

_Fixed: 2026-08-31_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
