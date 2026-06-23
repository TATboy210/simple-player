# UI Widget Layer Redesign Spec

> Date: 2026-05-26 | Approach: Layered Refactoring | Files: 44 → ~18

## Problem Statement

UI Widget Layer has accumulated redundancy: god-widget PlayerScreen (14 params), manual caching patterns (ControlsOverlay 8 fields), redundant abstractions (GlassContainer/GlassButton/GlassIconButton), and excessive saveLayer calls from BackdropFilter over video. Previous optimization (commit d9adab6) was surface-level patching that didn't address architectural issues.

## Design Principles

1. **Desktop-first**: Minimize GPU readback, no BackdropFilter over video layer
2. **Static/dynamic separation**: Video area = zero blur effects; independent floating windows = can use blur
3. **Minimal files**: ~18 files, delete all single-use utilities
4. **ValueListenableBuilder as deep as possible**: Each state source → one deep builder
5. **No manual caching**: Use `const` + `child` parameter pattern instead
6. **Lazy loading**: DeferredPlayerFeature for heavy components

## File Structure (44 → 18)

```
lib/ui/
├── theme/
│   └── tokens.dart                    # KEEP as-is
├── player/
│   ├── player_screen.dart             # REWRITE: PlayerConfig replaces 14 params
│   ├── player_controls.dart           # MERGE: ControlsOverlay + ControlBar + CenterControls
│   ├── progress_bar.dart              # SIMPLIFY: merge TimeRangeDisplay
│   ├── speed_button.dart              # KEEP, simplify
│   ├── volume_controls.dart           # KEEP, simplify
│   ├── keyboard_handler.dart          # KEEP
│   ├── video_surface.dart             # KEEP
│   └── drop_handler.dart              # KEEP
├── shared/
│   ├── glass.dart                     # MERGE: GlassContainer + GlassButton + GlassIconButton
│   ├── empty_state.dart               # SIMPLIFY
│   ├── osd_overlay.dart               # MOVE from widgets/, simplify
│   ├── aurora_background.dart         # KEEP
│   └── context_menu_row.dart          # KEEP
├── playlist/
│   ├── playlist_panel.dart            # MERGE: inline FolderTab + HistoryTab
│   └── thumbnail_tile.dart            # KEEP, simplify
└── dialogs/
    ├── settings_panel.dart            # MERGE: inline all tabs
    └── media_info_dialog.dart         # KEEP
```

## Deleted Files (~26)

- `glass_container.dart`, `glass_icon_button.dart`, `glass_chip.dart` → `glass.dart`
- `controls_overlay.dart`, `center_controls.dart`, `custom_title_bar.dart`, `auto_hide_controller.dart`, `time_range_display.dart`, `error_banner.dart` → `player_controls.dart`
- `folder_tab.dart`, `history_tab.dart` → `playlist_panel.dart`
- `settings_card.dart`, `_settings_nav_item.dart`, `about_tab.dart`, `audio_tab.dart`, `equalizer_tab.dart`, `general_tab.dart`, `shortcuts_tab.dart`, `video_tab.dart` → `settings_panel.dart`
- `merged_listenable.dart`, `resize_aware_builder.dart`, `value_listenable_builder2.dart`, `resize_notifier.dart`, `play_mode_utils.dart`, `progress_splash_screen.dart`, `splash_screen.dart` → deleted or inlined

## Key Architecture Changes

### 1. PlayerScreen: God-widget → Config object

```dart
// BEFORE: 14 constructor parameters
PlayerScreen(engine: e, isFullscreen: f, onPrevious: p, onNext: n, ...)

// AFTER: 2 objects
PlayerScreen(engine: engine, actions: PlayerActions(...))
```

`PlayerActions` groups all callbacks. `isFullscreen` derived from engine state.

### 2. Glass Widget Consolidation

```dart
// glass.dart — 3 widgets in 1 file
class GlassSurface extends StatelessWidget  // semi-transparent container, NO BackdropFilter
class GlassButton extends StatelessWidget    // InkWell + hover/press
class GlassIconButton extends StatelessWidget // 36x36 icon button
```

All use `Color(0x801A1A24)` instead of BackdropFilter. Zero saveLayer.

### 3. Player Controls: No BackdropFilter over video

```dart
// player_controls.dart
Container(
  color: Tokens.bgGlass,  // semi-transparent, NOT BackdropFilter
  child: ...,
)
```

No `ClipRRect`, no `BackdropFilter`, no `saveLayer` over video. The control bar floats over video with pure alpha compositing.

### 4. BackdropFilter Only in Independent Windows

Settings panel and shortcuts help dialog are independent floating windows (not over video). These CAN use BackdropFilter:

```dart
// settings_panel.dart — independent window, OK to blur
ClipRRect(
  borderRadius: ...,
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: ...,
  ),
)
```

### 5. ValueListenableBuilder Deep Placement

```dart
// BEFORE: Builder at parent level, passes state down
ValueListenableBuilder<bool>(
  valueListenable: engine.isMuted,
  builder: (_, muted, _) => Column([
    VolumeButton(muted: muted),  // passes muted as param
    VolumeSlider(...),
  ]),
)

// AFTER: Builder at leaf level, each widget self-contained
Column([
  VolumeButton(engine: engine),  // listens to isMuted internally
  VolumeSlider(engine: engine),  // listens to volume internally
])
```

### 6. Delete Manual Caching Pattern

Remove ControlsOverlay's 8-field `_buildCachedBar()` pattern entirely. Instead:
- Use `const` constructors where possible
- Use `child` parameter in AnimatedBuilder/ValueListenableBuilder
- Trust Flutter's `identical()` optimization

## Rebuild Optimization Strategy

| Pattern | Where | Why |
|---------|-------|-----|
| `const` constructors | All static widgets | Flutter skips rebuild via `identical()` |
| `child` parameter | AnimatedBuilder, ValueListenableBuilder | Cache static subtrees |
| Deep ValueListenableBuilder | Each control button | Minimize rebuild scope |
| No BackdropFilter over video | ControlBar, OSD | Zero saveLayer/GPU readback |
| RepaintBoundary | AuroraBackground, ProgressBar | Isolate custom paint repaints |
| `itemExtent` on ListView | Playlist thumbnails | Skip intrinsic layout |

## Implementation Order

1. `glass.dart` — consolidate glass widgets, remove BackdropFilter
2. `player_controls.dart` — merge controls, no blur over video
3. `player_screen.dart` — PlayerConfig, simplify tree
4. `playlist_panel.dart` — merge tabs
5. `settings_panel.dart` — merge tabs, keep BackdropFilter (independent window)
6. Delete remaining unused files
7. Verify: `flutter analyze` + `flutter run -d windows`

## Success Criteria

- `flutter analyze` — 0 issues
- App launches and plays video
- DevTools: GlassIconButton rebuilds drop from 1476 to <100
- No BackdropFilter over video layer
- Total UI files: ≤20
