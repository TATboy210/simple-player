---
phase: 07-integration-golden-tests
plan: 01
status: complete
completed_at: "2026-05-30T10:00:00+08:00"
---

# 07-01 Summary: Integration Tests

## What Changed

### FFI Lazy Initialization Refactor
- `lib/kernel/bridge/window_service.dart` — moved all top-level FFI bindings into `_Win32Bindings` class
- Top-level `final _win32 = _Win32Bindings()` uses Dart's built-in lazy initialization (no `late` needed)
- Pure refactor: no behavioral change, all existing 564 tests pass

### New Test Infrastructure
- `test/helpers/fake_window_service.dart` — FakeWindowService extending WindowService, zero FFI, call tracking
- `test/helpers/integration_helpers.dart` — buildTestApp, createTestController, createFakeWindowService

### Integration Tests (18 tests)
- `test/integration/playback_flow_test.dart` — 6 tests: open, seek, pause, toggle, skipForward, skipBack
- `test/integration/controls_flow_test.dart` — 6 tests: volume, clamping, mute, volume-0-muted, fullscreen, speed
- `test/integration/playlist_flow_test.dart` — 6 tests: next, prev, loopAll wrap, loopSingle, mode cycle, addFiles

## Key Decisions

- Tests use `test()` not `testWidgets()` — pure Dart tests, no widget tree needed
- Tests placed in `test/integration/` not `integration_test/` — avoids device build requirement
- PathValidator accepts paths like `C:/test.mp4` (format-only validation, no existence check)

## Verification

- 582 tests passing (564 existing + 18 new)
- `dart analyze` clean on all new/modified files
- FFI refactor verified non-breaking by full test suite
