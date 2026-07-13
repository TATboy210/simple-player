---
phase: 1
slug: fullscreen-simplification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-12
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Dart SDK) |
| **Config file** | analysis_options.yaml |
| **Quick run command** | `flutter test test/platform/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/platform/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-T1 | 01-01 | 1 | FULL-01 | — | N/A | unit | `flutter test test/platform/` | ✅ | ⬜ pending |
| 01-01-T1 | 01-01 | 1 | FULL-02 | — | N/A | manual | Check .planning/research/ | ✅ | ⬜ pending |
| 01-02-T1 | 01-02 | 2 | FULL-03 | — | N/A | unit | `flutter test test/platform/` | ✅ | ⬜ pending |
| 01-02-T2 | 01-02 | 2 | FULL-03 | — | N/A | unit | `flutter test test/platform/` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/window_service_init_test.dart` — covers inlined platform detection (D-02)
- [ ] `test/fullscreen_result_test.dart` — covers sealed class exhaustive matching (D-11)
- [ ] Verify deletion: no test files import `desktop_fullscreen_driver.dart` or `desktop_fullscreen_driver_factory.dart`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| flutter_fullscreen evaluation doc exists | FULL-02 | Documentation artifact | Check .planning/research/flutter-fullscreen-evaluation.md exists |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
