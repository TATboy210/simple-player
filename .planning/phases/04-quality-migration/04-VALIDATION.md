---
phase: 04
slug: quality-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + integration_test (SDK) |
| **Config file** | analysis_options.yaml |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test --coverage` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test`
- **After every plan wave:** Run `flutter test --coverage`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | STATE-01~03, EVT-01~03, ERR-01~03, CMD-01~03, RST-01~04, ARCH-01~03 | N/A | unit | `flutter test test/regression/high_risk_suite_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | STATE-01~03, EVT-01~03, ERR-01~03, CMD-01~03, RST-01~04, PLAT-01~04, ARCH-01~03 | N/A | unit+integration | `flutter test test/regression/smoke_suite_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 1 | All 22 v1 reqs | N/A | CI | `cat .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 1 | All 22 v1 reqs | N/A | CI | `cat .github/workflows/release.yml` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 2 | ARCH-03 | N/A | unit | `flutter analyze --fatal-infos 2>&1 \| tail -3` | ✅ | ⬜ pending |
| 04-03-02 | 03 | 2 | RST-01~04, PLAT-01~03 | N/A | integration | `flutter test test/integration/fullscreen_e2e_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/regression/high_risk_suite_test.dart` — rapid key-press (10/50x), maximized restore, StateDesync recovery
- [ ] `test/regression/smoke_suite_test.dart` — 8 mandatory scenarios automated subset
- [ ] `test/integration/fullscreen_e2e_test.dart` — fullscreen E2E with real window
- [ ] `.github/workflows/ci.yml` — CI workflow (does not exist yet)
- [ ] `.github/workflows/release.yml` — Release workflow (does not exist yet)
- [ ] `test/regression/regression_matrix.md` — Regression matrix document

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| macOS fullscreen enter/exit smooth | PLAT-02 | Requires real macOS window manager | Open app → play video → press F → verify fullscreen → press F → verify restore |
| Linux GNOME fullscreen state readback | PLAT-03 | Requires real Linux WM (GNOME) | Open app on GNOME → press F → verify state → press F → verify restore |
| Multi-monitor drag + fullscreen restore | RST-03 | Requires physical second monitor | Drag window to second monitor → press F → press ESC → verify position restored |
| Focus + TopMost residual after exit | PLAT-01 | Requires manual observation | Enter fullscreen → exit → verify no TopMost residual, focus returns correctly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
