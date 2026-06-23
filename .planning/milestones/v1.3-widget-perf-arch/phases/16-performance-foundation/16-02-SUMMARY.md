# Plan 16-02 Summary: BackdropFilter Resize Degradation + Paint Cache

**Status:** ✅ COMPLETE
**Date:** 2026-06-22
**Requirements:** PERF-06, PERF-07

## What Changed

### PERF-06: BackdropFilter Resize Degradation

**isResizing signal chain:**
- `WindowBridge` — added `ValueNotifier<bool> get isResizing` interface
- `WindowService` — `isResizing` set synchronously on first resize frame, debounced to false after 200ms
- `FakeWindowService` — test double with `isResizing` ValueNotifier

**3 BackdropFilter sites updated:**
- `GlassContainer` — AnimatedBuilder listens to `resizing`, skips BackdropFilter when true
- `ControlBar` — AnimatedBuilder listens to `resizing`, skips blur when true
- `PlaylistPanel` — AnimatedBuilder listens to `resizing`, shows solid bgGlass when true

**Signal wiring:**
- `PlayerScreen` → `ControlsOverlay(resizing: windowService.isResizing)`
- `PlayerScreen` → `PlaylistPanel(resizing: windowService.isResizing)`
- `ControlsOverlay` → `ControlBar(resizing: widget.resizing)`

### PERF-07: Static Paint Cache

- `_AuroraPainter._bgPaint` — `static final` replacing per-frame `Paint()..color = Tokens.bgBase`
- `_AuroraPainter._compositePaint` — `static final` replacing per-frame `Paint()`

## Files Modified (9)

| File | Change |
|------|--------|
| `lib/kernel/bridge/window_bridge.dart` | +`isResizing` getter |
| `lib/kernel/bridge/window_service.dart` | +isResizing, +_resizeEndTimer, +onWindowResize logic, +dispose |
| `lib/ui/shared/glass_container.dart` | +resizing param, +AnimatedBuilder resize gate |
| `lib/ui/player/control_bar.dart` | +resizing param, +AnimatedBuilder resize gate, +foundation import |
| `lib/ui/playlist/playlist_panel.dart` | +resizing param, +AnimatedBuilder resize gate, +foundation import |
| `lib/ui/player/controls_overlay.dart` | +resizing pass-through, +foundation import |
| `lib/ui/player/player_screen.dart` | wiring isResizing to ControlsOverlay + PlaylistPanel |
| `lib/ui/shared/aurora_background.dart` | +2 static final Paint, replaced 4 per-frame Paint() |
| `test/helpers/fake_window_service.dart` | +isResizing ValueNotifier + dispose |

## Tests Added (3)

- `resizing=true skips BackdropFilter` — GlassContainer with resizing=true → no BackdropFilter
- `resizing=false renders BackdropFilter` — GlassContainer with resizing=false → BackdropFilter present
- `resizing transition rebuilds correctly` — false→true→false transitions verified

## Bug Found & Fixed

Original implementation passed `_buildBlurContent(rRect, content)` as AnimatedBuilder's `child`, which already contained BackdropFilter. When `resizing=true`, the builder wrapped it in ClipRRect but BackdropFilter was still rendered. Fixed: `child` is raw `content`, builder calls `_buildBlurContent` only when `resizing=false`.

## Verification

- `flutter analyze` — 0 errors
- `flutter test` — 651 tests passed, 0 failures
- `grep "Paint()" aurora_background.dart` — no per-frame allocations remain

---
*Completed: 2026-06-22*
