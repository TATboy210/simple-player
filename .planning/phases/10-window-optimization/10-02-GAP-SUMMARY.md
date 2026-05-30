---
phase: 10-window-optimization
plan: 02-GAP
status: complete
commit: 7312eeb
completed: 2026-05-30
---

## Summary

Added `onWindowClose` override and `_saveGeometryImmediate` to `WindowService`. Ensures geometry is saved immediately when the window closes, complementing the existing 500ms debounce path.

## What Changed

- `lib/kernel/bridge/window_service.dart`: +27 lines
  - `onWindowClose()` override — calls `_saveGeometryImmediate()` then `windowManager.destroy()`
  - `_saveGeometryImmediate()` — cancels debounce, saves geometry without fullscreen/maximized skip, reports `isMaximized.value`

## Verification

- `dart analyze lib/kernel/bridge/window_service.dart` — no issues
- `onWindowClose` count: 1
- `_saveGeometryImmediate` count: 2 (definition + call)
