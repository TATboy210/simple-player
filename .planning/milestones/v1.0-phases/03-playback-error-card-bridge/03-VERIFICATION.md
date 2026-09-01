---
phase: 03-playback-error-card-bridge
verified: 2026-08-31T09:55:00Z
status: passed
score: 14/15 must-haves verified
behavior_unverified: 1
overrides_applied: 1
overrides:

  - must_have: "WR-01: close button dismisses the FIFO head, which is not necessarily the report being displayed while cycling"
    reason: "Closed as documented divergence (zero-kernel choice): by-id dismissal requires a kernel dismissById API (Rule 4 red line, unsigned). Divergence documented in ErrorCardHost._onClose doc comment; behavioral boundary locked by test 'close while cycling keeps display and snapshot consistent (WR-01)'; the dismissed head was always displayed on arrival (D-01), so no error is silently dropped."
    accepted_by: "TATboy210 (phase-3 review disposition, commit c878b3e9)"
    accepted_at: "2026-08-31"
behavior_unverified_items:

  - truth: "SC-4/CARD-02 real-machine portion: with the card displayed, title bar / control bar / playlist remain hittable and keyboard shortcuts keep working on a real Windows host window (incl. during media_kit fullscreen route)"
    test: "Run the app on Windows (flutter run -d windows), accept a real error to show the card, then drag the title bar, click control-bar buttons, open the playlist, use Space/arrows/M/F keys, enter/exit fullscreen, and copy with the real system clipboard."
    expected: "Every interaction outside the card rect works; card stays visible above the fullscreen route; no focus steal; copied pack lands on the real clipboard; OSD pills render with readable duration."
    why_human: "Widget tests cannot reproduce host-window hit-testing, the native fullscreen route, the OS clipboard, or OSD观感 — card-level logic is widget-verified but the host-window invariant is not (VER-04, Manual-Only)."
deferred:

  - truth: "VER-04 Windows real-machine smoke (full verification-phase execution)"
    addressed_in: "Phase 5"
    evidence: "REQUIREMENTS.md traceability: 'VER-04 | Phase 5 | Pending'; Phase 5 goal '端到端韧性验证 … Windows 播放器交互期间完整捕获、可回溯且不妨碍使用'."
  - truth: "WR-03: _isFullscreenTransition only cleared by a resizing→false event; a fullscreen transition without a resize event leaves the flag stuck"
    addressed_in: "Deferred (pre-existing, outside phase-3 must-haves)"
    evidence: "03-REVIEW.md WR-03; flag predates the phase (introduced in f146ee0a, path-B stage 1); phase 3 touched player_video_controls.dart only to remove the banner mount. Code unchanged at player_video_controls.dart:584-589."
  - truth: "IN-01: stale seek-distance doc — comment/CLAUDE.md say ±5s, code seeks 10s back / 30s forward"
    addressed_in: "Deferred (doc drift, info-level)"
    evidence: "03-REVIEW.md IN-01; behavior is consistent across center_controls.dart and player_keyboard_actions.dart; doc-only correction."
---

# Phase 3: 播放错误桥与非模态卡片 Verification Report

**Phase Goal:** As a player user, I want to see every error in one unified, expandable non-modal card that never blocks playback controls, so that I can get immediate feedback without a second error display path.
**Verified:** 2026-08-31T09:55:00Z
**Status:** human_needed (1 real-machine item; all automated gates green)
**Re-verification:** No — initial verification
**Mode:** MVP (User Story format validated: `true`)

## User Flow Coverage (MVP mode)

| # | Flow Step | Expected | Evidence in Codebase | Status |
|---|-----------|----------|---------------------|--------|
| 1 | Error occurs (any of 4 sources incl. engine bridge) | Non-modal card appears top-left, never blocks controls | `app.dart:103-114` `buildErrorCardMount` (builder Stack, `Positioned(left,top)` above navigator); test `error_card_host_test.dart` "accepts a report and shows the card at the top-left"; production bridge `player_services.dart:148` | ✓ VERIFIED |
| 2 | Read collapsed card | Summary + severity dot + media path basename | `error_card.dart:198-318`; test "collapsed shows localized message, severity dot and basename" | ✓ VERIFIED |
| 3 | Expand card | file:line → source lines ±2 → full stack → log path → repeat info (D-04 order) | `error_card.dart:354-395`; test "whole-card tap expands five sections in D-04 order" (getTopLeft ordering + rawStackTrace exact match) | ✓ VERIFIED |
| 4 | Copy diagnostic pack | Clipboard text identical to log file format; success/failure OSD; failure isolated | `error_card.dart:145-189` (`formatDiagnosticPack` single source, logPath at copy time, typed catches); 4 copy tests incl. PlatformException injection | ✓ VERIFIED |
| 5 | Close card | Card dismissed, FIFO advances, no auto-hide/focus steal/route/barrier | `error_card_host.dart:195-204` (`_onClose` → `dismissCurrent`); tests "card persists across frames with no auto-hide timer", "close button dismisses current and advances the FIFO", "primary focus unchanged after taps" | ✓ VERIFIED |
| 6 | Interact with rest of UI while card displayed | Taps outside card pass through; route content hittable; focus unchanged | Tests "taps inside the card do not reach widgets below; taps outside pass through", "tap on route content above the navigator still hits while card visible (D-10)", CR-01 test "expanded card is width/height bounded and taps outside pass through" (probe through production mount) — widget level. **Real host window not exercised** → Human Verification item 1 | ✓ VERIFIED (widget) / ⚠️ real-machine |
| 7 | Engine error vs other sources — one path only | Same card for engine errors; legacy banner gone | Equivalence suite `error_banner_equivalence_test.dart` (pre-deletion dual-path proof in 372b10a9, card-path evidence retained); `grep -rn ErrorBanner lib/ test/` → zero matches (re-run this session); `error_banner.dart`/`error_banner_test.dart` deleted | ✓ VERIFIED |
| 8 | New errors while card displayed | Content replaced (no stacking); badge cycles bounded history (≤20) | Tests "newest error replaces the card and badge counts the snapshot", "badge tap cycles older through the snapshot and wraps", "snapshot caps at the bound and evicts the oldest", "new report arrival resets the cycle offset (D-01 replacement)" (CR-02) | ✓ VERIFIED |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | D-10: card mounted at app root (MaterialApp.builder Stack) above Navigator; survives opaque routes; not covered by fullscreen route or dialogs | ✓ VERIFIED | `app.dart:103-114`; tests "stays visible above an opaque fullscreen-style route" (host_test) + route-hit test (card_test) |
| 2 | CARD-05: build-phase reports merged post-frame via SchedulerPhase guard; no markNeedsBuild secondary error | ✓ VERIFIED | `error_card_host.dart:124-135` (idle-only sync, post-frame re-read); tests "build-phase report arrival causes no secondary markNeedsBuild" + "same-frame reports converge to one end-of-frame update" (onBuildScheduled count) |
| 3 | D-12: pre-mount queued reports flushed after first frame (bootstrap/windowInit window) | ✓ VERIFIED | `error_card_host.dart:81-83`; test "presents a pre-mount report after the first flush (D-12)" incl. degraded-home survival |
| 4 | CARD-06/D-08: ValueListenableBuilder subscribes host-owned adapter notifier; no new state library; zero structural kernel change | ✓ VERIFIED | `error_card_host.dart:43-50,206-240`; adapter deviation (A5) documented in doc comment; kernel touch limited to additive 7-line `KernelLoggerImpl.isInitialized` probe (WR-02 fix, 6b3139e2) |
| 5 | SC-2/CARD-03: collapsed shows summary/severity/media path; expanded shows file:line, source lines, full stack, log path | ✓ VERIFIED | `error_card.dart:349-395`; expand test group (7 cases) all green |
| 6 | D-03/D-04: severity semantic tokens (warning/danger/dangerFatal); whole-card tap toggles; chevron flips; zero new visual system | ✓ VERIFIED | `tokens.dart:21-27` + `error_card.dart:89-93,335-346`; test "warning and fatal severities map to dedicated tokens (D-03)" |
| 7 | SC-1/CARD-01: persistent manual close; no auto-hide timer, no route/barrier/autofocus, zero focus steal | ✓ VERIFIED | `error_card.dart:292-311` close button (GestureDetector+Semantics); `error_card_host.dart:223` ExcludeFocus; 3 CARD-01 tests; WR-01 divergence accepted as override (documented + behavior-locked) |
| 8 | CARD-02 (widget level): taps inside card absorbed; taps outside pass through; card does not swallow Navigator hits | ✓ VERIFIED | `app.dart:90-93` intrinsic-size Positioned (no Positioned.fill host, no IgnorePointer); GlassContainer ClipRRect hit-clip; 2 bidirectional hit-test cases + CR-01 bounded passthrough |
| 9 | SC-4 real-machine: title bar/control bar/playlist hittable and keyboard shortcuts usable during card display on Windows host window | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | All widget-level hit-test/focus evidence green; host-window/native-fullscreen/OS-clipboard behavior not reproducible headless — VER-04 Manual-Only (see Human Verification) |
| 10 | D-07: full media path never rendered in visible tree (basename only); full paths only in copy pack | ✓ VERIFIED | `error_card.dart:413-420` defensive basename; test "full media path never rendered in visible tree (T-03-05)" (both states findsNothing) |
| 11 | SC-3/CARD-04: copy pack character-identical to formatDiagnosticPack (LOG-05); two-state OSD feedback; exceptions never escape | ✓ VERIFIED | `error_card.dart:145-189` (typed PlatformException/MissingPluginException catches, isInitialized-guarded logging); 4 copy tests (formatter-identical, logPath at copy time, injection, unmocked channel) |
| 12 | D-02: warning head routes to OsdService + exactly one dismissCurrent; never on card; no rebuild loop | ✓ VERIFIED | `error_card_host.dart:165-170` (`_lastWarningEventId` dedupe); test "warning head routes to OSD and advances exactly once" (presentation-notify count seam). Declared precondition: no capture source produces warnings yet (Phase 4/5 forward-looking, documented in plan + host doc) |
| 13 | D-01/D-11: new error replaces card; badge cycles bounded local snapshot (≤20, eventId identity) via effects seam; cycling never calls dismissCurrent; zero kernel read API | ✓ VERIFIED | `error_capture_snapshot.dart` (maxLength 20, evict-oldest, warning filter) wired at `main.dart:45`; host `_cycleBadge`/`_displayedReport` pure view offset; 5 badge tests + CR-02 reset test; snapshot store is a UI-layer file |
| 14 | SC-5/MIG-01: engine errors bridge into the same card; ErrorBanner removed after pre-deletion dual-path equivalence | ✓ VERIFIED | Bridge wiring `player_services.dart:148-156`; dual-path equivalence proof commit 372b10a9; deletion commit 0805618b; grep gate zero (re-run); equivalence suite retained as card-path integration evidence (production `buildErrorCardMount`) |
| 15 | Plan-04 closeout: full quality gates green (analyze 0 error, tests green, kernel_logger_gate) | ✓ VERIFIED | Re-run this session: `flutter analyze` 0 error/0 warning (59 pre-existing info); 37/37 focused card tests; `bash tool/audit/kernel_logger_gate.sh` GATE 1+2 PASS |

**Score:** 14/15 truths verified (1 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/ui/player/error_card_host.dart` | CARD-05 phase-guard host, adapter notifier, flush/dismiss wiring | ✓ VERIFIED | 253 lines; all six skeleton duties identifiable in source |
| `lib/ui/player/error_card.dart` | Full card: collapse/expand, l10nKey switch, severity colors, copy, badge, close | ✓ VERIFIED | 421 lines; 13-key switch with unknown fallback; IN-02 nested scroll removed |
| `lib/ui/player/error_capture_snapshot.dart` | Bounded snapshot store over existing effects seam | ✓ VERIFIED | 71 lines; maxLength 20; eventId in-place merge; removeById |
| `lib/app.dart` | D-10 mount: builder Stack + Positioned(left,top) + CR-01 ConstrainedBox + local Overlay | ✓ VERIFIED | `buildErrorCardMount` + `_ErrorCardOverlayMount`; maxWidth 420 / maxHeight 0.6×window |
| `lib/ui/theme/tokens.dart` | warning/dangerFatal + card width/height tokens | ✓ VERIFIED | lines 21-27, 260-269; all referenced |
| `lib/l10n/app_en.arb` / `app_zh.arb` (+generated) | 13 Wave-0 errorCard* keys, bilingual | ✓ VERIFIED | 13 keys enumerated in both ARBs; generated files committed |
| `test/widget/player/error_card_host_test.dart` | End-to-end + CARD-05 + D-12 + warning/badge suites | ✓ VERIFIED | 15 testWidgets; harness reuses production `buildErrorCardMount` |
| `test/widget/player/error_card_test.dart` | CARD-01/02/03/04 suites | ✓ VERIFIED | 17 testWidgets |
| `test/widget/player/error_banner_equivalence_test.dart` | MIG-01 evidence (dual-path pre-deletion, card-path retained) | ✓ VERIFIED | Header documents pre-deletion proof (372b10a9); uses real bridge + production mount |
| `(deleted) lib/ui/player/error_banner.dart` | Legacy banner removal | ✓ VERIFIED (deleted) | `git ls-files` empty; grep zero |
| `(deleted) test/widget/player/error_banner_test.dart` | Legacy assertions inherited by equivalence suite | ✓ VERIFIED (deleted) | file absent |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `ErrorReporterImpl.presentation` | `ErrorCardHost._onPresentationChanged` | addListener/removeListener (guarded by isInitialized) | ✓ WIRED | host:74-78, 95-97 |
| `ErrorCardHost.initState` | `flushPresentation()` | first post-frame callback (isReady gate) | ✓ WIRED | host:81-83; D-12 test proves |
| `app.dart MaterialApp.builder` | `ErrorCardHost` | Stack [Positioned.fill(navigator), Positioned(left,top) host] | ✓ WIRED | app.dart:50, 103-114 |
| ErrorCard whole-card GestureDetector | collapse/expand toggle | `onTap: _toggle` + chevron | ✓ WIRED | card:335-336 |
| error_banner 13-key l10nKey switch | ErrorCard `_resolveMessage` | key rebuild `error.{type}.{code}` + fallback | ✓ WIRED | card:104-125; unknown-fallback test |
| ErrorCard close button | `ErrorReporterImpl.dismissCurrent()` | host `onClose → _onClose` | ✓ WIRED | card:300-301 → host:195-204; CAP-04 test |
| ErrorCard copy button | `formatDiagnosticPack(report, logPath)` | single source, logPath at copy time | ✓ WIRED | card:149-152; formatter-identical test |
| `ErrorCardHost._apply` (warning) | `OsdService.I.show` + single dismissCurrent | D-02 routing with eventId dedupe | ✓ WIRED | host:165-170; warning test |
| Badge tap | host local snapshot cycle index | `onBadgeTap: _cycleBadge` (pure view offset) | ✓ WIRED | card:232 → host:177-179; 03-01/02 stub recycled |
| `ErrorCaptureSnapshot.I.record` | `ErrorReporterImpl.init(effects:)` | existing effects seam at composition root | ✓ WIRED | main.dart:45; kernel zero read-API |
| `FakeEngine.lastError` | `PlayerErrorReportBridge → ErrorReporterImpl` | real bridge (production-isomorphic) | ✓ WIRED | equivalence test fixture; production `player_services.dart:148` |
| deletion closeout | grep gate + quality gates | zero residue + analyze/test/logger gates | ✓ WIRED | re-run this session, all pass |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| ErrorCard message | `report.message` | reporter intake (real reports in tests via `reportBootstrapSafely`) | Yes | ✓ FLOWING |
| Severity dot/border | `report.severity` | intake snapshot | Yes | ✓ FLOWING |
| Badge count | `ErrorCaptureSnapshot.reports.value.length` | effects seam (main.dart:45) | Yes | ✓ FLOWING |
| Log path section | `ErrorReporterImpl.diagnosticPath?.value` | Phase 2 FileSink ValueListenable | Yes | ✓ FLOWING |
| Copy pack | `formatDiagnosticPack(report, logPath)` | same formatter as log file (LOG-05) | Yes | ✓ FLOWING |
| Expanded sections | `report.location/.sourceLines/.rawStackTrace` | Phase 2 location/source-line reader | Yes | ✓ FLOWING |

No static fallbacks, hardcoded literals, or hollow props found in the card path.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| All card suites green | `flutter test error_card_host_test.dart error_card_test.dart error_banner_equivalence_test.dart` | 37/37 passed ("All tests passed!") | ✓ PASS |
| Static quality gate | `flutter analyze` | 0 error / 0 warning (59 pre-existing info) | ✓ PASS |
| Kernel log red line | `bash tool/audit/kernel_logger_gate.sh` | GATE 1 PASS, GATE 2 PASS | ✓ PASS |
| Legacy residue gate | `grep -rn ErrorBanner lib/ test/` | zero matches (exit 1) | ✓ PASS |
| Review-fix commits exist | `git log -1 <hash>` × 7 | all 7 present (375240fc/288c8f97/c878b3e9/6b3139e2/f8e0dcf5/fb8a2c2b/f0760cc7) | ✓ PASS |
| Real-machine smoke | (requires Windows host window) | not runnable headless | ? SKIP → Human Verification |

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| `tool/audit/kernel_logger_gate.sh` | `bash tool/audit/kernel_logger_gate.sh` | GATE 1+2 PASS | PASS |

### Review-Fix Regression Locks (03-REVIEW.md findings)

| Finding | Fix Commit | Code Evidence | Regression Test | Status |
| ------- | ---------- | ------------- | ---------------- | ------ |
| CR-01 unconstrained expanded card (1133px on 800px window) | 375240fc | `app.dart` ConstrainedBox(maxWidth 420, maxHeight 0.6×window) + local Overlay (`canSizeOverlay`) | "expanded card is width/height bounded and taps outside pass through" (long-stack repro, width ≤ token, bottom ≤ window, probe passthrough) | ✓ HOLDS |
| CR-02 cycle index not reset on new report | 288c8f97 | `error_card_host.dart:111` `_onSnapshotChanged` resets `_cycleIndex` | "new report arrival resets the cycle offset (D-01 replacement)" | ✓ HOLDS |
| WR-01 close-vs-display divergence | c878b3e9 | `_onClose` doc comment documents divergence (zero-kernel choice) | "close while cycling keeps display and snapshot consistent (WR-01)" | ✓ ACCEPTED (override) |
| WR-02 unguarded `ErrorReporterImpl.I` / `KernelLogger.I` | 6b3139e2 | isInitialized guards at host:74/95/197, card:162/175; additive `KernelLoggerImpl.isInitialized` probe | covered by copy-failure test (injected failure produces OSD, takeException null) | ✓ HOLDS |
| IN-02 dead nested scroll | f0760cc7 | inner SingleChildScrollView removed (card:375-378 comment) | expand tests exercise single outer scroll | ✓ HOLDS |
| IN-03 "0 错误" badge on empty snapshot | f8e0dcf5 | `totalCount: history.isEmpty ? 1 : history.length` (host:230) | host fallback-mount tests | ✓ HOLDS |
| IN-04 wrong constant name in comment | fb8a2c2b | comment now names `ErrorCaptureSnapshot.maxLength` | comment-only | ✓ HOLDS |
| WR-03 `_isFullscreenTransition` stuck flag | — (deferred) | unchanged at player_video_controls.dart:584-589 | — | DEFERRED (pre-existing from f146ee0a) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| CARD-01 | 03-02 | Persistent manual close, no auto-hide/focus steal/route/barrier | ✓ SATISFIED | Truths 7; 3 tests; ExcludeFocus; zero Timer/showDialog in card path |
| CARD-02 | 03-02 | Hit-test strictly bounded to card rect; no blocking of controls (Windows smoke) | ✓ SATISFIED (widget) / ⚠️ real-machine pending | Truths 8-9; bidirectional tests + CR-01 bounded test; VER-04 human item |
| CARD-03 | 03-02/03-03 | Progressive details: collapsed summary/severity/path; expanded file:line/source/stack/log path | ✓ SATISFIED | Truth 5; D-04 order locked by getTopLeft test |
| CARD-04 | 03-03 | One-click copy identical to LOG-05 format; copy failure doesn't affect card | ✓ SATISFIED | Truth 11; 4 copy tests |
| CARD-05 | 03-01 | Build-phase captures merged post-frame; no markNeedsBuild secondary error | ✓ SATISFIED | Truth 2; fault-injection + same-frame tests |
| CARD-06 | 03-01 | Mounted at app/player root Stack; VLB subscribes reporter presentation state; no new state lib | ✓ SATISFIED | Truths 1, 4; app.dart:50 builder; adapter documented |
| MIG-01 | 03-04 | Bridge equivalence proven, then legacy ErrorBanner replaced and removed | ✓ SATISFIED | Truth 14; dual-path proof 372b10a9 → deletion 0805618b → grep zero |

No orphaned requirements: REQUIREMENTS.md maps exactly CARD-01..06 + MIG-01 to Phase 3; all 7 appear across plan frontmatters (01: CARD-05/06; 02: CARD-01/02/03; 03: CARD-04/03; 04: MIG-01). VER-04 belongs to Phase 5 per traceability.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| lib/ui/player/error_card.dart | 131, 418 | `return null` guard clauses (isInitialized probe, empty mediaPath) | ℹ️ Info | Legitimate guards, not stubs — data path populates them otherwise |
| lib/kernel/diagnostics/kernel_logger.dart | 506-512 | Additive `static bool isInitialized` probe (kernel file touched in phase window) | ℹ️ Info | 7-line additive defensive getter for WR-02 fix; same pattern as `ErrorReporterImpl.isInitialized`; non-breaking; noted as deviation from literal "kernel 零改动" claim |
| — | — | TBD/FIXME/XXX/TODO debt markers in phase files | — | Zero found (grep) |
| — | — | Empty-callback stub `onTap: () {}` (registered in 03-01/03-02 Known Stubs) | — | Recycled in 03-03 to `onBadgeTap: _cycleBadge` — verified wired |

## Human Verification Required

### 1. VER-04 Windows real-machine smoke — card-displayed interaction invariant

**Test:** Run the app on Windows (`flutter run -d windows`). Trigger a real error to show the card. With the card visible: (a) drag the title bar, click control-bar buttons, open/interact with the playlist; (b) press Space/←→/M/P/O/S and ESC; (c) enter and exit media_kit fullscreen and confirm the card remains visible above the fullscreen route and exits cleanly; (d) click the copy button and paste into an editor to confirm the real system clipboard received the diagnostic pack; (e) expand the card and confirm the bounded width/scroll feel on a real window.
**Expected:** Every interaction outside the card rect works; keyboard focus stays with KeyboardHandler (shortcuts fire); card survives fullscreen route transitions; clipboard contains the pack identical to the log file; no visual overflow.
**Why human:** Host-window hit-testing, native fullscreen route, OS clipboard, and OSD观感 are not reproducible in headless widget tests. All widget-level equivalents pass (37/37), but the host-window invariant itself is unexercised (VER-04, Manual-Only; full execution lands in Phase 5 per REQUIREMENTS.md traceability).

## Gaps Summary

No gaps. All 15 must-have truths hold at the automated level; the single non-verified truth is the real-machine interaction invariant (SC-4/CARD-02 "Windows 冒烟验证" clause), which the phase itself registered as Manual-Only VER-04 and the roadmap maps to Phase 5. The 03-REVIEW.md findings were all dispositioned: 2 critical (CR-01/CR-02) fixed with regression locks through the production mount path, WR-01 closed as a documented zero-kernel divergence locked by a consistency test (recorded as override), WR-02 fixed with defensive probes, 4 info items fixed or deferred as doc drift. Kernel red lines hold: the only kernel touch is an additive 7-line `isInitialized` probe (WR-02 fix); media_kit untouched; no new packages.

Status is human_needed solely because one behavior-unverified item remains — the Windows real-machine smoke — pending human execution (now or as part of Phase 5 VER-04).

---

_Verified: 2026-08-31T09:55:00Z_
_Verifier: Claude (gsd-verifier)_
