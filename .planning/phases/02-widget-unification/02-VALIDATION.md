---
phase: 2
slug: widget-unification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-28
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK bundled) |
| **Config file** | pubspec.yaml (dev_dependencies: flutter_test) |
| **Quick run command** | `flutter test test/widget/player/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widget/shared/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | WIDGET-01 | — | N/A | widget | `flutter test test/widget/shared/glass_button_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | WIDGET-01 | — | N/A | unit | `dart analyze lib/ui/shared/glass_widgets.dart` | ✅ | ⬜ pending |
| 02-01-03 | 01 | 1 | WIDGET-01 | — | N/A | unit | `grep -r "glass_icon_button" lib/` returns 0 | ✅ | ⬜ pending |
| 02-02-01 | 02 | 1 | WIDGET-02 | — | N/A | manual | Code review audit | N/A | ⬜ pending |
| 02-02-02 | 02 | 1 | WIDGET-02 | — | N/A | manual | DevTools (D-12: qualitative) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widget/shared/glass_button_test.dart` — stubs for WIDGET-01 (icon-only + label modes, tap behavior)
- [ ] Verify existing tests still pass after GlassButton refactor (control_bar_test.dart, volume_controls_test.dart, controls_overlay_test.dart)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ValueListenableBuilder child caching audit | WIDGET-02 | Requires code review judgment | Review all ValueListenableBuilder in ui/, verify static subtrees use `child` param |
| ControlBar rebuild count reduction | WIDGET-02 | D-12: qualitative judgment + code analysis | Compare rebuild patterns before/after via code analysis |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
