---
phase: 3
slug: reset-to-defaults
created: "2026-07-13"
status: active
---

# Phase 3 Validation Strategy

## Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — standard Flutter test |
| Quick run command | `flutter test test/widget/settings/` |
| Full suite command | `flutter test` |

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SUI-02 | Reset button appears in 5 tabs (General, EQ, Video, Shortcuts, Performance) | widget | `flutter test test/widget/settings/` | Partial |
| SUI-02 | Reset button NOT in About and Audio tabs | widget | `flutter test test/widget/settings/` | New |
| SUI-02 | Confirmation dialog shows on reset click | widget | `flutter test test/widget/settings/reset_dialog_test.dart` | New |
| SUI-02 | Confirm resets only current tab settings | widget | `flutter test test/widget/settings/reset_dialog_test.dart` | New |
| SUI-02 | Cancel does not reset any settings | widget | `flutter test test/widget/settings/reset_dialog_test.dart` | New |
| SUI-02 | General tab reset uses deferred apply (locale/theme) | widget | `flutter test test/widget/settings/reset_dialog_test.dart` | New |
| SUI-02 | EQ reset sets flat curve | widget | `flutter test test/widget/settings/` | New |
| SUI-02 | Shortcuts reset clears to app defaults | widget | `flutter test test/widget/settings/` | New |
| SUI-02 | UI refreshes immediately after reset | widget | `flutter test test/widget/settings/reset_dialog_test.dart` | New |
| SUI-02 | PerformanceTab reset disabled while loading | widget | `flutter test test/widget/settings/` | New |

## Sampling Rate

Standard — all requirements have automated test coverage.

## Verification Commands

```bash
# Static analysis
flutter analyze

# Widget tests for reset functionality
flutter test test/widget/settings/

# Full test suite
flutter test
```
