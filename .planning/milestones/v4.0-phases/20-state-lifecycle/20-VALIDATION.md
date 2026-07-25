---
phase: 20
slug: state-lifecycle
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-20
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter test (Dart test + widget test) |
| **Config file** | pubspec.yaml (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test test/` |
| **Full suite command** | `flutter test test/ --coverage` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/`
- **After every plan wave:** Run `flutter test test/ --coverage`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 20-01-01 | 01 | 1 | STATE-03,STATE-04 | unit | `flutter analyze lib/kernel/engine/lifecycle_phase.dart lib/kernel/engine/transition_result.dart` | ⬜ pending |
| 20-01-02 | 01 | 1 | STATE-02,STATE-03,STATE-04 | unit | `flutter test test/kernel/engine/engine_state_machine_test.dart` | ⬜ pending |
| 20-02-01 | 02 | 2 | STATE-01,STATE-02,STATE-04 | unit | `flutter analyze lib/kernel/engine/fvp_engine.dart lib/kernel/services/playback_navigator.dart` | ⬜ pending |
| 20-02-02 | 02 | 2 | STATE-01,STATE-06 | unit | `flutter analyze lib/kernel/adapter/kernel_adapter.dart lib/kernel/player_services.dart` | ⬜ pending |
| 20-03-01 | 03 | 2 | STATE-05 | unit | `flutter test test/kernel/engine/fvp_callback_handler_test.dart` | ⬜ pending |
| 20-03-02 | 03 | 2 | STATE-07 | integration | `flutter test test/kernel/engine/race_condition_test.dart` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Phase 15 contract tests provide the verification baseline for method-level DelegationPolicy flips.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
