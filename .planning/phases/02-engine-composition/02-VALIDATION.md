---
phase: 2
slug: engine-composition
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-29
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | none (uses default test discovery) |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | COMP-01 | — | N/A | unit | `flutter test test/kernel/engine/volume_controller_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | COMP-02 | — | N/A | unit | `flutter test test/kernel/engine/subtitle_configurator_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | COMP-03 | — | N/A | unit | `flutter test test/kernel/engine/d3d11_configurator_test.dart` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | COMP-04 | — | N/A | integration | `flutter test test/widget/player/` | ✅ existing | ⬜ pending |
| 02-02-02 | 02 | 2 | COMP-05 | — | N/A | verification | `flutter test` (all) | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/kernel/engine/volume_controller_test.dart` — stubs for COMP-01
- [ ] `test/kernel/engine/subtitle_configurator_test.dart` — stubs for COMP-02
- [ ] `test/kernel/engine/d3d11_configurator_test.dart` — stubs for COMP-03

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| D3D11 properties set before open() | PLAT-01 | Timing depends on real mdk.Player lifecycle | Run app, check debugPrint output for D3D11 property set calls before open |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
