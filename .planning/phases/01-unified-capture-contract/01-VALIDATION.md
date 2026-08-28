---
phase: 1
slug: unified-capture-contract
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-28
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart) |
| **Config file** | `pubspec.yaml` (flutter_test SDK dep) |
| **Quick run command** | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task's direct focused command from the verification map.
- **After every plan wave:** Run `flutter test` and `flutter analyze`.
- **Before `/gsd-verify-work`:** `flutter test` must exit 0 and `flutter analyze` must exit 0. If a known headless native media-DLL failure occurs, apply the project-memory stash/re-run comparison to each failure, record its explicit attribution, and escalate for a documented developer exception or prerequisite baseline-repair phase if the full suite remains nonzero; do not silently accept it.
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01 / Task 1 — platform tracer | 01 | 1 | CAP-01, CAP-03 | T-01-01 / T-01-02 | Immutable platform report reaches bounded FIFO, isolated effect, and flush without UI dependency. | unit/TDD | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart` | ❌ W0 | ⬜ pending |
| 01-01 / Task 2 — full reporter contract | 01 | 1 | CAP-01, CAP-03, CAP-04 | T-01-01..04 | All four adapters are non-throwing; null Flutter stack uses the bounded unavailable marker; FIFO, dedupe, reentrancy, and burst containment hold. | unit/TDD | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart && flutter analyze` | ❌ W0 | ⬜ pending |
| 01-02 / Task 1 — hook tracer | 02 | 2 | CAP-01, CAP-02, CAP-03 | T-01-05 / T-01-08 | Framework presentation precedes safe forwarding; dispatcher returns true; callback failures remain contained. | unit/TDD | `flutter test test/diagnostics/global_error_hooks_test.dart` | ❌ W0 | ⬜ pending |
| 01-02 / Task 2 — guarded bootstrap | 02 | 2 | CAP-01, CAP-02, CAP-03 | T-01-05..08 | Same-zone startup uses a reporter-availability-checked static fallback that returns normally if reporter initialization/access or last-resort output fails. | unit/TDD + manual smoke | `flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart && flutter analyze` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/diagnostics/error_report_test.dart` — immutable ErrorReport field/copy tests and Flutter nullable-stack unavailable-marker behavior.
- [ ] `test/diagnostics/error_reporter_test.dart` — four intake adapters, FIFO/dedupe/flush, fault injection, reentrancy, and burst containment.
- [ ] `test/diagnostics/global_error_hooks_test.dart` — framework/dispatcher adapters, same-zone bootstrap helper, reporter initialization/access failure, and contained last-resort fallback tests.
- [ ] Local hand-written diagnostics fakes for clock, media-path provider, ID generator, effects, reporter availability/access, and last-resort output; no new framework install is required.

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 实机 same-zone `runZonedGuarded` 启动接管及反馈链兜底 | CAP-02, CAP-03 | binding/engine registration crosses process-global Flutter runtime boundaries | Run `flutter run -d windows` in debug mode; induce or observe startup/framework diagnostics and confirm normal player/error state remains reachable. Record the observed outcome; automated tests separately prove reporter-unavailable and throwing-last-resort fallback paths return normally. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
