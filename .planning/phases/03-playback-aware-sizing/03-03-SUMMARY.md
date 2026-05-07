---
phase: 03-playback-aware-sizing
plan: 03
status: complete
completed: 2026-05-07
---

# Plan 03-03 Summary: Aspect ratio cycle button + tests

## What Changed

Added aspect ratio cycle button to title bar and comprehensive test coverage for AspectRatioService.

## Files Modified

| File | Change |
|------|--------|
| `lib/kernel/window/aspect_ratio_service.dart` | Added `ratioNotifier` (ValueNotifier<double>) for UI binding, fires on set and rollback |
| `lib/kernel/ui/window/custom_title_bar.dart` | Added aspect ratio cycle button to TitleBarControls (hidden when ratio==0, shows icon+label) |
| `test/widget/window/custom_title_bar_test.dart` | 4 widget tests: hidden/visible/tooltip/wiring |
| `test/kernel/window/aspect_ratio_service_test.dart` | 14 unit tests: cycleRatio (5), currentLabel (5), ratioNotifier (2), existing (2) |

## Test Results

- 328 total tests passed (full suite)
- 4 new widget tests for aspect ratio button
- 12 new unit tests for cycleRatio, currentLabel, ratioNotifier
