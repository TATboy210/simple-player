---
phase: 24
slug: sidebar-navigation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-23
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK bundled) |
| **Config file** | none — default flutter test runner |
| **Quick run command** | `flutter test test/ui/dialogs/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **Per task commit:** `flutter test test/ui/dialogs/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green + `flutter analyze` clean

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File |
|--------|----------|-----------|-------------------|------|
| SIDEBAR-01 | Horizontal tab bar 7 equal-width tabs, bgPanel background | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` | extend |
| SIDEBAR-02 | 7 tabs render icon + label, selected/unselected states | widget | `flutter test test/ui/dialogs/settings_nav_item_test.dart` | new |
| SIDEBAR-03 | Click tab → FadeTransition 200ms, IndexedStack preserves state | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` | extend |
| SIDEBAR-04 | ← → arrow keys + LB/RB gamepad cycle tabs | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` | extend |

---

## Wave 0 Gaps

- [ ] `test/ui/dialogs/settings_nav_item_test.dart` — new file for SIDEBAR-02 (refactored horizontal nav item)
- [ ] Extend `test/ui/dialogs/settings_overlay_shell_test.dart` — tab bar + keyboard + gamepad switching

---

## Notes

- No security requirements for this phase (UI-only tab navigation)
- Gamepad testing: implement optimistically, verify with keyboard first
- `Tokens.bgSurface` does NOT exist — use `Tokens.bgPanel` (research finding A1)
