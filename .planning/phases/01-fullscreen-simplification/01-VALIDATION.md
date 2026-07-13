---
phase: 01
slug: fullscreen-simplification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-13
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | none — uses flutter test defaults |
| **Quick run command** | `flutter test test/unit/kernel/bridge/window_service_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** `flutter analyze lib/` (must show no errors from deleted files)
- **After every wave:** `flutter analyze` (full static analysis)
- **Phase gate:** `flutter analyze` passes with no errors related to deleted files

---

## Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| ARCH-REM-01 | fullscreen_driver.dart + fullscreen_capability.dart deleted | grep | `grep -r "fullscreen_driver\|fullscreen_capability" lib/` returns 0 |
| ARCH-REM-02 | platform/ drivers deleted | file check | `ls lib/kernel/bridge/platform/` returns empty or dir deleted |
| ARCH-REM-03 | win32_fullscreen_ffi.dart deleted | file check | `test -f lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` returns false |
| ARCH-REM-04 | Old test files deleted | file check | `ls test/platform/` returns empty or dir deleted |

---

## Wave 0 Gaps

- None — this is a deletion phase, no new test infrastructure needed

---

*Phase: 01-fullscreen-simplification*
*Created: 2026-07-13*
