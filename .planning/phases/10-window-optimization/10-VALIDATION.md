---
phase: 10
slug: window-optimization
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | none — standard flutter test |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test --coverage` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** `flutter test test/kernel/bridge/ test/kernel/persistence/`
- **After every plan wave:** `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | WIN-04a | T-10-01 | N/A | unit | `flutter test test/kernel/bridge/window_bootstrap_test.dart` | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 1 | WIN-04b | T-10-02 | N/A | unit | `flutter test test/kernel/bridge/window_bootstrap_test.dart` | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | WIN-04d | T-10-04 | N/A | unit | `flutter test test/kernel/bridge/window_service_test.dart` | ❌ W0 | ⬜ pending |
| 10-03-01 | 03 | 2 | WIN-04a | T-10-05 | N/A | unit | `flutter test test/kernel/bridge/window_service_test.dart` | ❌ W0 | ⬜ pending |
| 10-03-02 | 03 | 2 | WIN-04c | T-10-06 | N/A | manual | Visual inspection on Windows | Manual only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/kernel/bridge/window_service_test.dart` — covers WIN-04a (startup geometry restore)
- [ ] `test/kernel/bridge/window_bootstrap_test.dart` — covers WIN-04b (multi-monitor bounds check)
- [ ] `test/helpers/fake_screen_retriever.dart` — mock for screen_retriever in tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fullscreen enter/exit no visual glitch | WIN-04c | Visual rendering requires Windows desktop | Enter fullscreen (F key), verify smooth animation, exit fullscreen, verify restore animation |
| Multi-monitor window move | WIN-04b | Requires physical multi-monitor setup | Move window to second monitor, close, reopen — verify position on correct monitor |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
