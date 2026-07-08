---
phase: 1
slug: settings-panel-glass-redesign
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-08
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | `pubspec.yaml` dev_dependencies |
| **Quick run command** | `flutter test test/widget/dialogs/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widget/dialogs/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | COMP-03 | widget | `flutter test test/widget/shared/section_header_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | COMP-01, STYLE-01/02/03, COMP-04 | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | STYLE-04, TRIG-03 | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 2 | COMP-01/02/03, STYLE-01/02/03 | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 2 | COMP-01/02/03, STYLE-01/02/03 | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | INTX-03 | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 2 | COMP-01/02/03 | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ W0 | ⬜ pending |
| 01-04-01 | 04 | 3 | COMP-03 | analysis | `flutter analyze` | ✅ | ⬜ pending |
| 01-04-02 | 04 | 3 | TRIG-01/02, INTX-01/02/04 | visual | Manual visual verification | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widget/dialogs/settings_panel_test.dart` — covers TRIG-01/02/03, COMP-01/02/04, STYLE-01-04, INTX-01-04
- [ ] `test/widget/shared/section_header_test.dart` — verify SectionHeader extraction works
- [ ] `test/widget/shared/settings_card_test.dart` — verify SettingRow/SettingSwitchRow still work after refactor

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Glass effect renders correctly in panel | COMP-01, STYLE-01 | BackdropFilter requires real rendering context | Open settings panel, verify glass blur visible |
| Sidebar nav hover matches control bar | STYLE-04 | Visual comparison | Hover sidebar items, compare with control bar buttons |
| OK/Cancel/Apply delayed apply works | INTX-01/02 | State persistence across dialog close | Change locale, cancel, verify revert |
| Panel drag works | INTX-04 | Gesture interaction | Drag panel by title bar |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
