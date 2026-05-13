---
phase: 04-button-highlight-fix
plan: 01
subsystem: ui/player
tags: [overlay, popup, highlight, overlayportal, flutter]
dependencies:
  requires: []
  provides: [popup-close-notifier]
  affects: [volume-slider, speed-button, control-bar, controls-overlay]
tech_stack:
  added: [OverlayPortal, OverlayPortalController, LayerLink, CompositedTransformTarget, CompositedTransformFollower]
  patterns: [ValueNotifier callback chain, OverlayPortal with LayerLink positioning]
key_files:
  created: []
  modified:
    - lib/ui/player/volume_slider.dart
    - lib/ui/player/speed_button.dart
    - lib/ui/player/control_bar.dart
    - lib/ui/player/controls_overlay.dart
decisions:
  - "Use OverlayPortal instead of manual OverlayEntry — eliminates timing gaps and lifecycle bugs"
  - "Use ValueNotifier<int> generation counter for popup close signal — simplest cross-widget communication"
  - "Button area passthrough via CompositedTransformFollower with opaque GestureDetector — eliminates dead tap bug"
metrics:
  duration: "~10m"
  completed: "2026-05-13"
  tasks: 3
  files: 4
---

# Phase 04 Plan 01: Button Highlight Fix Summary

OverlayPortal migration for VolumeSlider and SpeedButton popups with auto-close callback chain from ControlsOverlay.

## Tasks Completed

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Migrate VolumeSlider to OverlayPortal | 23d9df8 | Replace OverlayEntry with OverlayPortalController + LayerLink, remove _popupOpen/ValueKey hack |
| 2 | Migrate SpeedButton to OverlayPortal | c69bea2 | Same pattern as VolumeSlider, keep ScaleTransition animation |
| 3 | Wire auto-close callback chain | 1fa6307 | ValueNotifier<int> from ControlsOverlay through ControlBar to both buttons |

## What Was Built

### VolumeSlider (volume_slider.dart)
- Replaced `_popupOpen` boolean + `_overlayEntry` with `_popupController.isShowing`
- Removed `ValueKey(_popupOpen)` hack — icon color now driven by controller state
- Popup positioned via `CompositedTransformFollower` with `LayerLink`
- Button area passthrough: `GestureDetector(opaque, onTap: _togglePopup)` excludes button from dismiss background
- `closePopupImmediate()` method for auto-close (stops animation, hides synchronously)
- `popupCloseNotifier` parameter for ControlsOverlay integration

### SpeedButton (speed_button.dart)
- Same OverlayPortal migration pattern as VolumeSlider
- Preserved `ScaleTransition` animation for popup scale effect
- `closePopupImmediate()` method for auto-close
- `popupCloseNotifier` parameter for ControlsOverlay integration

### ControlBar (control_bar.dart)
- Added `popupCloseNotifier` parameter
- Passes notifier to both `VolumeSlider` and `SpeedButton`

### ControlsOverlay (controls_overlay.dart)
- Created `_popupCloseNotifier = ValueNotifier<int>(0)`
- `_hide()` increments notifier BEFORE `_animController.reverse()` — popups close before bar fades
- Passes notifier to `ControlBar` in build method
- Disposes notifier in `dispose()`

## Architecture

```
ControlsOverlay
├── _popupCloseNotifier (ValueNotifier<int>)
├── _hide() → notifier++ → reverse animation
└── FadeTransition
    └── ControlBar (popupCloseNotifier)
        ├── VolumeSlider (popupCloseNotifier → listener → closePopupImmediate)
        │   ├── CompositedTransformTarget (button)
        │   └── OverlayPortal (popup via LayerLink)
        └── SpeedButton (popupCloseNotifier → listener → closePopupImmediate)
            ├── CompositedTransformTarget (button)
            └── OverlayPortal (popup via LayerLink)
```

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `dart analyze lib/` — 0 errors, 0 warnings (6 pre-existing info-level issues in unrelated files)
- `flutter test` — 388 passed, 6 failed (all 6 failures pre-existing: PlaylistStore/WindowManagerService/CustomTitleBar native plugin issues)
- No test failures in modified files

## Known Stubs

None — all popup functionality fully wired.

## Threat Flags

No new security surface. Pure UI state management fix (internal widget plumbing only).
