---
phase: 07
slug: code-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-14
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter analyze + manual verification |
| **Config file** | analysis_options.yaml |
| **Quick run command** | `D:/flutter/bin/flutter analyze` |
| **Full suite command** | `D:/flutter/bin/flutter analyze` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `D:/flutter/bin/flutter analyze`
- **After every plan wave:** Run `D:/flutter/bin/flutter analyze` + manual smoke test
- **Before `/gsd-verify-work`:** `flutter analyze` must pass with zero warnings
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| 07-01-01 | 01 | 1 | CODE-01 | N/A | source | `flutter analyze` — WindowManagerService deleted | ⬜ pending |
| 07-01-02 | 01 | 1 | CODE-01 | N/A | source | `flutter analyze` — PlatformService proxy compiles | ⬜ pending |
| 07-01-03 | 01 | 1 | CODE-02 | N/A | behavior | 'A' key cycles aspect ratio in-app | ⬜ pending |
| 07-01-04 | 01 | 1 | CODE-03 | N/A | source | AspectRatio labels use l10n keys | ⬜ pending |
| 07-01-05 | 01 | 1 | CODE-04 | N/A | source | `flutter analyze` — zero warnings | ⬜ pending |
| 07-01-06 | 01 | 1 | CODE-05 | N/A | source | No manual OverlayEntry remains | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- None — existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CustomTitleBar renders without crash | CODE-01 | Requires running app with window visible | Launch app non-fullscreen, verify title bar renders |
| 'A' key cycles aspect ratio | CODE-02 | Requires keyboard input in running app | Press 'A' multiple times, verify ratio changes |
| AspectRatio tooltip shows localized text | CODE-03 | Requires hover on title bar button | Hover aspect ratio button, verify tooltip language |

---

## Validation Sign-Off

- [ ] All tasks have automated or manual verify
- [ ] Sampling continuity: `flutter analyze` after every commit
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
