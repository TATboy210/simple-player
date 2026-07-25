---
phase: 25
slug: tab-content-framework
status: draft
nyquist_compliant: false
created: "2026-07-23"
---

# Validation Strategy: Phase 25 — Tab Content Framework

## Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Quick run | `flutter test test/ui/dialogs/` |
| Full suite | `flutter test` |

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Command |
|--------|----------|-----------|---------|
| TABS-01 | 7 tab pages render SettingRow skeletons | widget | `flutter test test/ui/dialogs/settings_tab_content_test.dart` |
| TABS-02 | SettingRow supports Switch/Slider/Dropdown | widget | `flutter test test/ui/dialogs/settings_tab_content_test.dart` |
| TABS-03 | OK/Cancel/Apply bar at panel bottom | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` |
| TABS-04 | Deferred apply: pending → commit/cancel | unit | `flutter test test/ui/dialogs/pending_settings_test.dart` |

## Wave 0 Gaps

- `test/ui/dialogs/pending_settings_test.dart` — TABS-04 deferred apply logic
- `test/ui/dialogs/settings_tab_content_test.dart` — TABS-01/02 skeleton rendering
- Extend `test/ui/dialogs/settings_overlay_shell_test.dart` — TABS-03 button bar

## Security Domain

Not applicable — pure UI framework, no auth/input/crypto/API.
