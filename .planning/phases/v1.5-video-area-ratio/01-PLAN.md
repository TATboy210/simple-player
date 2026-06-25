<!--
  Context:
  - Importers: player_screen.dart is the root widget, imported by app.dart
  - Affected API: PlayerScreen.build() and _buildVideoContent() layout tree
  - Data schemas: None (layout-only change)
  - User verbatim: "视频播放区域除开上标题栏是16比9，包括控制栏在内16比9比例，然后播放16比9视频时视频直接铺满画面即可，然后调整窗口大小，允许有黑边，不能裁切画面，然后优化播放视频时调整窗口会卡顿的问题"
-->

# Phase 1: Layout Restructuring — 16:9 Aspect Ratio Constraint

## Goal

Constrain the video area (excluding title bar) to 16:9 aspect ratio. The control bar is INSIDE the 16:9 area.

## Current Layout

```
Column
├── CustomTitleBar (32px)
└── Expanded ← fills remaining space, NO ratio constraint
    └── ValueListenableBuilder (playlistVisible)
        └── ValueListenableBuilder (playlistMounted)
            └── Stack
                ├── _buildVideoContent → Row → Expanded → DropHandler → Stack
                │   ├── VideoSurface (FittedBox + BoxFit.contain)
                │   ├── EmptyState
                │   └── ControlsOverlay (Positioned bottom, 110px ControlBar)
                └── PlaylistPanel (overlays video)
```

**Problem:** Video area fills the entire remaining space after title bar. No 16:9 constraint.

## Target Layout

```
Column
├── CustomTitleBar (32px)
└── Expanded
    └── ColoredBox(color: Colors.black)
        └── Center
            └── AspectRatio(aspectRatio: 16/9)
                └── Stack (fit: StackFit.expand)
                    ├── DropHandler
                    │   └── Stack (fit: StackFit.expand)
                    │       ├── VideoSurface
                    │       └── EmptyState
                    ├── PlaylistPanel
                    └── ControlsOverlay
```

## Files to Modify

### `lib/ui/player/player_screen.dart`

**`build()` method:** Wrap Expanded child with ColoredBox + Center + AspectRatio(16/9).

**`_buildVideoContent()`:** Remove Row/Expanded wrapper, return DropHandler directly.

**Playlist:** Move inside AspectRatio Stack so it overlays the video area.

### No changes needed
- `video_surface.dart` — already uses FittedBox(contain)
- `controls_overlay.dart` — already Positioned inside Stack
- `control_bar.dart` — fixed height, no layout change

## Acceptance Criteria

- [x] Video area maintains 16:9 ratio at any window size
- [x] Control bar is inside the 16:9 area
- [x] 16:9 video fills perfectly
- [x] Non-16:9 video shows letterboxing (no crop)
- [x] Black background visible behind 16:9 area
- [x] Playlist overlays correctly
- [ ] Fullscreen works (needs runtime verification)
- [x] `flutter analyze` passes (1 pre-existing warning)
- [x] Existing tests pass (673 pass, 5 pre-existing failures)

## Completion Summary

**Changes made:**
1. `player_screen.dart` — Wrapped Expanded child with `ColoredBox(black) + Center + AspectRatio(16/9)`
2. `player_screen.dart` — Simplified `_buildVideoContent()`: removed Row/Expanded wrapper
3. `player_screen.dart` — Moved PlaylistPanel inside AspectRatio Stack
4. `player_screen.dart` — Removed `_fitWindowToVideo()` and `_onAspectRatioChanged()` (no longer needed)
5. `player_screen.dart` — Removed `windowManager` import (unused after cleanup)

**Additional changes (from prior session, unrelated to Phase 1):**
- `window_service.dart` — window optimization changes
- `settings_store.dart` — settings persistence changes
