---
phase: 06
slug: window-code-optimization
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 06 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | none — standard flutter test |
| **Quick run command** | `flutter test test/widget/player/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widget/player/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | OPT-01 | widget | `flutter test test/widget/player/` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | OPT-01 | widget | `flutter test test/widget/player/keyboard_handler_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widget/player/keyboard_handler_test.dart` — covers ESC fullscreen exit

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fullscreen button visible in control bar | OPT-01 (D-01) | Visual check — button must not be clipped or hidden | Open app, verify fullscreen button visible in bottom-right control bar |
| 16:9 video matches 16:9 window | OPT-01 (D-06) | Visual check — no black bars | Open a 16:9 video, verify it fills the 960x540 window with no letterboxing |
| DragToResizeArea disabled in fullscreen | OPT-01 (D-04) | Behavior check — resize gestures must not work | Enter fullscreen, try dragging window edges — nothing should happen |
| ESC exits fullscreen | OPT-01 (D-02) | Behavior check — ESC must always work | Enter fullscreen, press ESC — window returns to windowed mode |
| Title bar hides in fullscreen | OPT-01 (D-03) | Visual check — title bar must disappear | Enter fullscreen, verify title bar is not visible |
