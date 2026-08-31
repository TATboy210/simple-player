---
status: diagnosed
trigger: "UAT G-03-1: 没有个专门启动调试的按钮，不反馈错误我也不知道 — truth: 存在开发用错误注入入口（调试触发），可按需构造合成错误走真实链路使卡片弹出"
created: 2026-08-31T00:00:00Z
updated: 2026-08-31T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — The error-injection entry was never a Phase 3 requirement (REQUIREMENTS.md maps exactly CARD-01..06 + MIG-01; no injection-deliverable exists), and no existing runtime affordance composes into one; all machinery to build it with zero kernel change already exists and is verified live.
test: enumerated all intake seams (reporter public methods, forTesting/resetForTesting, effects seam, bridge), all trigger surfaces (keyboard_handler, player_keyboard_actions, help dialog), OSD pattern, build mode, and phase planning docs.
expecting: no such seam exposed in production UI/keyboard; planning docs show no injection requirement; test-only seams are @visibleForTesting.
next_action: return ROOT CAUSE FOUND (goal: find_root_cause_only — no fix applied).

reasoning_checkpoint:
  hypothesis: "No on-demand injection entry exists because it was never in Phase 3 scope (design/scope gap, not a code defect) — the chain itself is verified working (14/15 must-haves) and the public intake seam already exists but is unexposed."
  confirming_evidence:
    - "error_reporter.dart:20-38 ErrorReporter interface has four PUBLIC intake methods (reportFlutterSafely/reportPlatformSafely/reportBootstrapSafely/reportPlayerError) on global singleton ErrorReporterImpl.I (line 138) — the injection seam exists but nothing in the UI layer calls it as a deliberate trigger"
    - "03-VERIFICATION.md Requirements Coverage: 'REQUIREMENTS.md maps exactly CARD-01..06 + MIG-01 to Phase 3' — no injection-entry requirement; grep of all phase-3 docs shows 注入/inject only in widget-test fault contexts (CARD-05 tests) and main.dart:25 UAT_FAULT_WINDOW_INIT dart-define"
    - "keyboard_handler.dart:171-178 Ctrl+Shift+D kDebugMode-gated debug shortcut handled inline — the established convention exists but only covers debug-data export, not error injection"
    - "forTesting constructor (error_reporter.dart:85) and resetForTesting (line 161-166) are @visibleForTesting — unusable in production code by design"
  falsification_test: "If a production-reachable trigger existed (UI button/keyboard/always-on entry calling reporter intake), the user could fire a synthetic error — grep found zero such call sites; if the entry HAD been planned, a requirement/plan task would exist — verification doc proves the requirement set is exhaustive and contains none."
  fix_rationale: "Gap closure adds one kDebugMode-gated keyboard shortcut calling the existing public reporter intake — addresses the missing affordance directly (root cause = unplanned scope item), zero kernel change, no media_kit contact."
  blind_spots: "Whether the developer wants the trigger in the F1 help list (l10n impact) and exact key choice are user-preference, not root-cause questions; whether reportPlatformSafely vs reportPlayerError is preferred synthetic payload affects which chain branch is exercised (both are real-chain)."
  candidate_causes:
    - "planning/scope category: injection entry absent from Phase 3 REQUIREMENTS.md (truth authored at UAT, never planned)"
    - "code category: no UI trigger surface exists — seams present but unexposed (fact, not defect)"
  and_gate: "no — the code behaves exactly as specified; the single contributing condition is the missing scope item (the unexposed seam is the consequence, not a second cause)"

## Symptoms

expected: 存在开发用错误注入入口（调试触发），可按需构造合成错误走真实链路使卡片弹出，供日常验证与调试观察
actual: 没有个专门启动调试的按钮，不反馈错误我也不知道 — user cannot trigger the error card on demand during real-machine smoke
errors: None reported
reproduction: UAT Test 1 (VER-04 实机冒烟) — user asked to trigger any error to show the card; no mechanism exists
started: Discovered during UAT (Phase 3 real-machine verification, 2026-08-31)

## Eliminated

- hypothesis: "Reporter intake is test-only — no production-usable injection seam exists in the codebase"
  evidence: "error_reporter.dart:20-38 four public intake methods on ErrorReporterImpl.I (global singleton, error_reporter.dart:138); UI layer already calls ErrorReporterImpl.I.presentation/dismissCurrent/flushPresentation (error_card_host.dart:75,169,203) — public production seam exists, merely unexposed as a trigger"
  timestamp: 2026-08-31
- hypothesis: "An injection entry was planned but dropped during execution"
  evidence: "03-VERIFICATION.md: 'No orphaned requirements: REQUIREMENTS.md maps exactly CARD-01..06 + MIG-01 to Phase 3'; grep of all 03-* docs for 注入/inject hits only widget-test fault contexts; VER-04 manual test text presumes 'accept a real error' as the trigger"
  timestamp: 2026-08-31

## Evidence

- timestamp: 2026-08-31
  checked: "lib/kernel/diagnostics/error_reporter.dart (full read)"
  found: "ErrorReporter abstract interface exposes 4 public intake methods (reportFlutterSafely/reportPlatformSafely/reportBootstrapSafely/reportPlayerError) + flushPresentation/dismissCurrent; ErrorReporterImpl.I global singleton (throws StateError pre-init; isInitialized probe exists); presentation ValueNotifier<ErrorPresentationState> is the production chain's publish point (_reportSafely → _accept → _publishSafely); reentrancy guard _isReporting (line 257); 10s dedupe window _dedupeWindow (line 50) merges identical reports (identity = 8-field record, line 404-417) — repeated identical synthetic errors merge occurrenceCount instead of new card"
  implication: "The cheapest injection seam is a single call to an existing public method on the global singleton — zero new kernel API, zero new state"
- timestamp: 2026-08-31
  checked: "lib/kernel/diagnostics/error_reporting_dependencies.dart effects seam + main.dart wiring"
  found: "main.dart:43-48 — ErrorReporterImpl.init(effects: [diagnosticLogEffect.record, ErrorCaptureSnapshot.I.record]); effects fan-out (_notifyEffects, error_reporter.dart:495-503) runs on every accepted report"
  implication: "One reporter intake call feeds the FULL real chain simultaneously: FIFO queue → presentation → ErrorCardHost → ErrorCard AND ErrorCaptureSnapshot badge AND error.log file — exactly what '走真实链路' requires"
- timestamp: 2026-08-31
  checked: "lib/ui/player/error_card_host.dart (full read) + app.dart mount"
  found: "Host mounted globally via app.dart:50 builder: buildErrorCardMount → Overlay → ErrorCardHost (app.dart:147); CARD-05 phase guard (_onPresentationChanged) defers only during non-idle scheduler phases — keyboard handlers run in idle phase so a trigger fires synchronously; D-12 post-frame flushPresentation makes isReady=true after first frame, so post-mount reports display immediately"
  implication: "A UI-triggered report after app mount renders the card with no additional wiring; no phase-guard pitfalls from keyboard context"
- timestamp: 2026-08-31
  checked: "lib/ui/player/keyboard_handler.dart (full read)"
  found: "Lines 171-178: kDebugMode-gated Ctrl+Shift+D debug shortcut (export debug data), handled INLINE in KeyboardHandler._handleKeyEvent via direct import of kernel/utils/debug_exporter.dart — established project convention for dev-only triggers; shortcutDefinitions list (lines 15-26) is the F1 help single-source; single Focus node, EditableText passthrough guard"
  implication: "A dev-only injection shortcut fits existing conventions perfectly: same file, same kDebugMode gating, same inline handling pattern (no callback plumbing needed); import of kernel diagnostics from UI is precedented (error_card_host.dart imports ErrorReporterImpl)"
- timestamp: 2026-08-31
  checked: "lib/ui/player/player_keyboard_actions.dart + lib/ui/shared/osd_overlay.dart"
  found: "buildPlayerKeyboardActions wires callbacks; OsdService.I is a static-final singleton with void show(String text, {IconData? icon}); OsdService.I.show used at error_card_host.dart:168 (warning route: 'OsdService.I.show(report.message, icon: Icons.warning_amber_outlined)') and volume/speed controls"
  implication: "OSD confirmation feedback for the trigger is a one-liner following the established pattern; help-list addition would touch shortcutDefinitions + l10n ARB"
- timestamp: 2026-08-31
  checked: "distribute_options.yaml + lib/kernel/models/player_error.dart"
  found: "MSIX build_args: only --dart-define=USE_MOCK_ENGINE=false (no debug defines) → distributed MSIX is release mode, kDebugMode=false; daily driver per UAT is 'flutter run -d windows' (debug mode, kDebugMode=true); PlayerError subtypes cheaply constructible: FileError(this.code, this.message, [this.cause, this.context]) — positionals only"
  implication: "kDebugMode gating matches usage reality: trigger exists in daily debug runs, absent from self-distributed MSIX — mirrors the Ctrl+Shift+D precedent; reportPlayerError(FileError(...)) viable if the player-engine branch (playerErrorCode mapping) should be exercised"
- timestamp: 2026-08-31
  checked: "Phase-3 planning docs (03-VERIFICATION.md Requirements Coverage + grep 注入|inject|调试触发|synthetic across 03-*)"
  found: "Requirements Coverage table is exhaustive: CARD-01..06 + MIG-01 only; VER-04 real-machine smoke belongs to Phase 5 per traceability; all 注入 mentions are widget-test fault injection (CARD-05 build-phase tests, UAT_FAULT_WINDOW_INIT)"
  implication: "G-03-1's truth statement was authored at UAT time — the entry was never a planned deliverable; this is a scope/design gap at plan time, not an implementation defect"

## Resolution

root_cause: "Design/scope gap, not a code defect: Phase 3's requirement set (CARD-01..06 + MIG-01) never included a developer-facing error-injection entry, so none was built — and the only trigger assumed by VER-04's manual test ('accept a real error', e.g. open a corrupt/nonexistent file) has no dedicated affordance. The machinery for one already exists and is production-public: ErrorReporterImpl.I's four public intake methods are the injection seam, one call fans out through the FULL real chain (FIFO → presentation → ErrorCardHost → ErrorCard + snapshot badge + error.log), and the established kDebugMode keyboard-shortcut convention (Ctrl+Shift+D, keyboard_handler.dart:171-178) is the natural trigger UX. The error card chain itself is verified working (14/15 must-haves, 37/37 focused tests)."
fix: "(not applied — goal: find_root_cause_only)"
verification: "(n/a — diagnosis only)"
files_changed: []
