---
phase: 1
slug: window-management
date: 2026-05-28
---

# Phase 1: Validation Strategy

## Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Quick run | `flutter test` |
| Full suite | `flutter test --coverage` |
| Static analysis | `dart analyze --fatal-infos` |

## Requirement → Test Mapping

| Req ID | Behavior | Test Type | Command | Status |
|--------|----------|-----------|---------|--------|
| WIN-01 | WindowService sends correct MethodChannel calls | unit | `flutter test test/window/window_service_test.dart` | Not created |
| WIN-02 | Window centers on startup with defaults | unit | `flutter test test/window/window_service_test.dart` | Not created |
| WIN-03 | Frameless window + CustomTitleBar renders | widget | `flutter test test/widget/window/custom_title_bar_test.dart` | Not created |
| PERF-02 | Error handling uses on Exception catch | static | `dart analyze --fatal-infos` | Existing |
| PLATFORM-01 | C++ handler registered in OnCreate | integration | Manual: `flutter run -d windows` | Manual |

## Sampling Rate

- **Per task commit:** `flutter test test/window/` (window-specific tests)
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green + `dart analyze --fatal-infos` + manual `flutter run -d windows` smoke test

## Wave 0 Test Gaps

- [ ] `test/window/window_service_test.dart` — covers WIN-01, WIN-02 (mock MethodChannel)
- [ ] `test/widget/window/custom_title_bar_test.dart` — covers WIN-03 (widget test)
- [ ] `test/helpers/fake_window_channel.dart` — mock MethodChannel for WindowService tests

## Manual Validation

| Check | Steps | Expected |
|-------|-------|----------|
| Frameless window | `flutter run -d windows` → verify no title bar | Window has no native title bar |
| Resize edges | Drag window edges | 8-direction resize works |
| Title bar drag | Drag top 32px region | Window moves |
| Snap layouts | Win+Left/Right | Window snaps |
| Fullscreen | Press F | Fullscreen, taskbar hidden |
| Always-on-top | Toggle via UI | Window stays on top |
| Rounded corners | Maximize + restore | Corners stay rounded |

## Acceptance Criteria

Phase 1 passes validation when:
1. `flutter test` exits 0
2. `dart analyze --fatal-infos` exits 0
3. Manual smoke test passes (all 7 checks above)
4. No `catch (_)` or `on Object catch` in codebase
