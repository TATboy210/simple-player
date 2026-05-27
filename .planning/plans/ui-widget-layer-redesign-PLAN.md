# UI Widget Layer Redesign — Implementation Plan

> Based on approved spec: `docs/superpowers/specs/2026-05-26-ui-widget-layer-redesign.md`
> Target: 44 UI files → ~18 files, zero BackdropFilter over video, eliminate manual caching

## Dependency Map (verified)

```
glass_container.dart  ← empty_state.dart (only consumer)
glass_icon_button.dart ← control_bar.dart, center_controls.dart, volume_controls.dart
glass_chip.dart       ← UNUSED (zero imports)
auto_hide_controller.dart ← controls_overlay.dart (only consumer)
center_controls.dart  ← control_bar.dart (only consumer)
error_banner.dart     ← controls_overlay.dart (only consumer)
time_range_display.dart ← control_bar.dart (only consumer)
custom_title_bar.dart ← player_screen.dart (only consumer)
controls_overlay.dart ← player_screen.dart (only consumer)
control_bar.dart      ← controls_overlay.dart (only consumer)
folder_tab.dart       ← playlist_panel.dart (only consumer)
history_tab.dart      ← playlist_panel.dart (only consumer)
play_mode_utils.dart  ← player_screen.dart, player_feature.dart
merged_listenable.dart ← time_range_display.dart (only consumer)
value_listenable_builder2.dart ← volume_controls.dart, error_banner.dart
resize_aware_builder.dart ← aurora_background.dart (only consumer)
splash_screen.dart    ← app.dart
progress_splash_screen.dart ← app.dart
settings_nav_item.dart ← settings_panel.dart (only consumer)
about_tab.dart        ← settings_panel.dart (only consumer)
audio_tab.dart        ← settings_panel.dart (only consumer)
equalizer_tab.dart    ← settings_panel.dart (only consumer)
general_tab.dart      ← settings_panel.dart (only consumer)
shortcuts_tab.dart    ← settings_panel.dart (only consumer)
video_tab.dart        ← settings_panel.dart (only consumer)
settings_card.dart    ← 6 settings tabs (shared utility, keep separate)
thumbnail_tile.dart   ← folder_tab.dart, history_tab.dart (keep separate)
```

---

## Phase 1: glass.dart consolidation

**Create:** `lib/ui/shared/glass.dart`
**Delete:** `glass_container.dart`, `glass_icon_button.dart`, `glass_chip.dart`
**Update imports:** `empty_state.dart`, `control_bar.dart`, `center_controls.dart`, `volume_controls.dart`

### What goes into glass.dart:

1. **`GlassSurface`** (replaces `GlassContainer`)
   - StatelessWidget, `const` constructor
   - NO BackdropFilter — use `Color(0x801A1A24)` (Tokens.bgGlass) as plain container
   - Keep: borderRadius, padding, width, height, border, child
   - Remove: GlassTier enum, respectResizeState, ClipRRect, BackdropFilter, RepaintBoundary
   - Widget tree: `Container(decoration: BoxDecoration(color: Tokens.bgGlass, borderRadius: ..., border: ...), child: child)`

2. **`GlassButton`** (simplified from current)
   - StatelessWidget (was StatefulWidget)
   - NO scale animation (remove AnimatedBuilder, Matrix4)
   - Keep: InkWell hover/press feedback, icon + optional label
   - Use GlassSurface for background
   - Widget tree: `GlassSurface > InkWell > Row(icon, label)`

3. **`GlassIconButton`** (keep as-is, move to glass.dart)
   - Already has no BackdropFilter
   - Keep static `_radius` cache
   - No changes to widget tree

4. **DELETE `GlassChip`** — zero imports, completely unused

### Import changes:

| File | Old import | New import |
|------|-----------|------------|
| `empty_state.dart` | `glass_container.dart` | `glass.dart` |
| `control_bar.dart` | `glass_icon_button.dart` | `glass.dart` |
| `center_controls.dart` | `glass_icon_button.dart` | `glass.dart` |
| `volume_controls.dart` | `glass_icon_button.dart` | `glass.dart` |

### Verification:
- `flutter analyze` — 0 issues
- App launches, control bar renders with semi-transparent background (no blur)

---

## Phase 2: player_controls.dart merge

**Create:** `lib/ui/player/player_controls.dart`
**Delete:** `controls_overlay.dart`, `control_bar.dart`, `center_controls.dart`, `custom_title_bar.dart`, `auto_hide_controller.dart`, `time_range_display.dart`, `error_banner.dart`
**Update imports:** `player_screen.dart`

### What goes into player_controls.dart:

1. **`PlayerControls`** (merged ControlsOverlay + ControlBar)
   - StatefulWidget with SingleTickerProviderStateMixin
   - Absorbs: ControlsOverlay's gesture handling, AutoHideController, mouse region
   - Absorbs: ControlBar's layout (progress bar, left/right button groups)
   - **NO BackdropFilter** — use `Container(color: Tokens.bgGlass)` for control bar background
   - Keep: FadeTransition for show/hide animation
   - Remove: ControlBar's 2 BackdropFilter instances, ClipRRect wrapping
   - Remove: ControlsOverlay's 8-field `_buildCachedBar()` manual caching pattern
   - Use `const` + `child` parameter pattern instead of manual caching

2. **`_AutoHideController`** (private, inlined from auto_hide_controller.dart)
   - Keep: AnimationController, Timer, visible ValueNotifier, mouse/engine state handling
   - Make private (was public, only used by ControlsOverlay)

3. **`_CenterGroup`** (private, inlined from center_controls.dart)
   - PlayPauseButton + skip buttons
   - Deep ValueListenableBuilder: each button listens to its own engine state

4. **`_TimeRange`** (private, inlined from time_range_display.dart)
   - Inline the MergedListenable pattern directly
   - Remove separate `merged_listenable.dart` dependency

5. **`_ErrorBanner`** (private, inlined from error_banner.dart)
   - Keep: ValueListenableBuilder2 pattern for dual state listening
   - Inline ValueListenableBuilder2 logic (compose two ValueNotifiers)

6. **OSD positioning** — keep OsdOverlay import, position inside PlayerControls stack

### Key architecture change:

```dart
// BEFORE: ControlBar uses BackdropFilter
ClipRRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(...),
  ),
)

// AFTER: Pure alpha compositing, zero saveLayer
Container(
  decoration: BoxDecoration(
    color: Tokens.bgGlass,  // 0x801A1A24 — semi-transparent
    borderRadius: BorderRadius.circular(Tokens.controlBarRadius),
    border: Border.all(color: Tokens.controlBarBorder),
  ),
  child: ...,
)
```

### Import changes:

| File | Old import | New import |
|------|-----------|------------|
| `player_screen.dart` | `controls_overlay.dart`, `custom_title_bar.dart` | `player_controls.dart` |

### Verification:
- `flutter analyze` — 0 issues
- App launches, control bar visible with semi-transparent background
- Auto-hide works (mouse move shows, idle hides)
- OSD messages appear above control bar
- Error banner shows on playback error

---

## Phase 3: player_screen.dart rewrite

**Modify:** `lib/ui/player/player_screen.dart`
**Update imports:** `player_controls.dart` (from Phase 2)

### Changes:

1. **Replace 16 constructor params with `PlayerActions` object:**

```dart
class PlayerActions {
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final void Function(BuildContext, TapUpDetails)? onSettingsSecondary;
  final VoidCallback? onOpenFile;
  final VoidCallback? onTogglePlayMode;
  final void Function(List<String>)? onFilesDropped;
  final void Function(bool)? onDragHoverChanged;
  final void Function(String, List<PlaylistItem>)? onFolderScanned;
  final VoidCallback? onClearHistory;
  final void Function(String)? onShowProperties;
  final ValueNotifier<int> playlistGeneration;
  final Widget? emptyState;
  final Map<String, VoidCallback> customBindings;
}
```

2. **PlayerScreen constructor becomes:**
```dart
const PlayerScreen({
  super.key,
  required this.engine,
  required this.controller,
  required this.playlist,
  required this.actions,
})
```

3. **Remove CustomTitleBar reference** — title bar is now part of PlayerControls (or removed per spec)
4. **Simplify widget tree** — fewer nesting levels
5. **Keep:** KeyboardHandler, VideoSurface, DropHandler, PlaylistPanel

### Import changes:

| Old import | New import |
|-----------|------------|
| `controls_overlay.dart` | `player_controls.dart` |
| `custom_title_bar.dart` | (removed — inlined into player_controls.dart or deleted) |
| `play_mode_utils.dart` | (inline playModeIcon/playModeLabel into player_controls.dart) |

### Downstream updates needed:
- `player_feature.dart` — update PlayerScreen constructor call to use PlayerActions
- `app.dart` — update if it references PlayerScreen directly

### Verification:
- `flutter analyze` — 0 issues
- App launches, video plays, all controls functional

---

## Phase 4: playlist_panel.dart merge

**Modify:** `lib/ui/playlist/playlist_panel.dart`
**Delete:** `folder_tab.dart`, `history_tab.dart`
**Keep:** `thumbnail_tile.dart` (305 lines, used by both tabs)

### Changes:

1. **Inline `_FolderTab`** (was `FolderTab`) as private widget
   - Keep: folder grouping logic, horizontal thumbnail layout
   - Keep: `_FolderGroupWidget`, `_FolderPathLabel` as private
   - Add ValueKey to list items: `key: ValueKey(item.path)`

2. **Inline `_HistoryTab`** (was `HistoryTab`) as private widget
   - Keep: timestamp-sorted history, `_HistoryTileWrapper`
   - Add ValueKey to list items: `key: ValueKey(item.path)`

3. **Keep `_TabChip`** as-is

4. **Keep PlaylistPanel** structure — visible animation, BackdropFilter OK (independent floating window)

### Import changes:

| File | Old import | New import |
|------|-----------|------------|
| `player_screen.dart` | `folder_tab.dart`, `history_tab.dart` (via playlist_panel) | no change needed (already imports playlist_panel) |

### Verification:
- `flutter analyze` — 0 issues
- Playlist opens, folder/history tabs switch, thumbnails load

---

## Phase 5: settings_panel.dart merge

**Modify:** `lib/ui/dialogs/settings_panel.dart`
**Delete:** `settings/_settings_nav_item.dart`, `settings/about_tab.dart`, `settings/audio_tab.dart`, `settings/equalizer_tab.dart`, `settings/general_tab.dart`, `settings/shortcuts_tab.dart`, `settings/video_tab.dart`
**Keep:** `settings_card.dart` (745 lines, shared utility used by all tabs)

### Changes:

1. **Inline `_SettingsNavItem`** (was `SettingsNavItem`) — 63 lines
2. **Inline `_AboutTab`** — 75 lines
3. **Inline `_AudioTab`** + `_AudioTrackRow` — 83 lines
4. **Inline `_EqualizerTab`** — 72 lines
5. **Inline `_GeneralTab`** + `_LanguageSelector`, `_LangChip`, `_ThemeSelector`, `_ThemeChip` — 217 lines
6. **Inline `_ShortcutsTab`** + `_ShortcutDef`, `friendlyKeyName()` — 244 lines
7. **Inline `_VideoTab`** + `_VideoSlider`, `_RotationPicker`, `_AspectRatioSelector`, `_BoolNotifier` — 307 lines

**All tabs become private.** Only `SettingsPanel` is public.

8. **Keep BackdropFilter** — settings panel is an independent floating window (not over video), so blur is OK per "动静分离" principle.

### Import changes:
- No external files import individual tabs (only settings_panel.dart does)
- settings_panel.dart removes imports of individual tab files, keeps settings_card.dart import

### Verification:
- `flutter analyze` — 0 issues
- Settings opens, all 6 tabs functional, OK/Cancel/Apply works

---

## Phase 6: Delete unused/redundant files

### Files to delete (after all merges):

| File | Reason |
|------|--------|
| `lib/ui/shared/glass_container.dart` | → merged into glass.dart |
| `lib/ui/shared/glass_icon_button.dart` | → merged into glass.dart |
| `lib/ui/shared/glass_chip.dart` | → unused (zero imports) |
| `lib/ui/shared/merged_listenable.dart` | → inlined into player_controls.dart |
| `lib/ui/shared/value_listenable_builder2.dart` | → inlined into player_controls.dart |
| `lib/ui/shared/resize_aware_builder.dart` | → inlined into aurora_background.dart |
| `lib/ui/shared/play_mode_utils.dart` | → inlined into player_controls.dart |
| `lib/ui/shared/splash_screen.dart` | → inlined into app.dart or kept (low priority) |
| `lib/ui/shared/progress_splash_screen.dart` | → inlined into app.dart or kept (low priority) |
| `lib/ui/player/controls_overlay.dart` | → merged into player_controls.dart |
| `lib/ui/player/control_bar.dart` | → merged into player_controls.dart |
| `lib/ui/player/center_controls.dart` | → merged into player_controls.dart |
| `lib/ui/player/custom_title_bar.dart` | → merged into player_controls.dart or deleted |
| `lib/ui/player/auto_hide_controller.dart` | → inlined into player_controls.dart |
| `lib/ui/player/time_range_display.dart` | → inlined into player_controls.dart |
| `lib/ui/player/error_banner.dart` | → inlined into player_controls.dart |
| `lib/ui/playlist/folder_tab.dart` | → inlined into playlist_panel.dart |
| `lib/ui/playlist/history_tab.dart` | → inlined into playlist_panel.dart |
| `lib/ui/dialogs/settings/_settings_nav_item.dart` | → inlined into settings_panel.dart |
| `lib/ui/dialogs/settings/about_tab.dart` | → inlined into settings_panel.dart |
| `lib/ui/dialogs/settings/audio_tab.dart` | → inlined into settings_panel.dart |
| `lib/ui/dialogs/settings/equalizer_tab.dart` | → inlined into settings_panel.dart |
| `lib/ui/dialogs/settings/general_tab.dart` | → inlined into settings_panel.dart |
| `lib/ui/dialogs/settings/shortcuts_tab.dart` | → inlined into settings_panel.dart |
| `lib/ui/dialogs/settings/video_tab.dart` | → inlined into settings_panel.dart |

**Total: 25 files deleted**

### Files that survive:

| # | File | Lines (est.) | Purpose |
|---|------|-------------|---------|
| 1 | `ui/theme/tokens.dart` | 134 | Design tokens |
| 2 | `ui/shared/glass.dart` | ~200 | GlassSurface + GlassButton + GlassIconButton |
| 3 | `ui/shared/empty_state.dart` | 261 | Idle screen |
| 4 | `ui/shared/osd_overlay.dart` | 149 | OSD messages |
| 5 | `ui/shared/aurora_background.dart` | 363 | Aurora animation |
| 6 | `ui/shared/context_menu_row.dart` | 31 | Context menu |
| 7 | `ui/shared/settings_card.dart` | 745 | Settings UI components |
| 8 | `ui/shared/resize_notifier.dart` | 76 | Resize state singleton |
| 9 | `ui/player/player_screen.dart` | ~250 | Main screen (rewritten) |
| 10 | `ui/player/player_controls.dart` | ~600 | Controls (merged) |
| 11 | `ui/player/progress_bar.dart` | 255 | Seekbar |
| 12 | `ui/player/speed_button.dart` | ~100 | Speed selector |
| 13 | `ui/player/volume_controls.dart` | ~110 | Volume |
| 14 | `ui/player/keyboard_handler.dart` | ~200 | Key bindings |
| 15 | `ui/player/video_surface.dart` | ~80 | Texture renderer |
| 16 | `ui/player/drop_handler.dart` | ~50 | Drag-and-drop |
| 17 | `ui/playlist/playlist_panel.dart` | ~700 | Playlist (merged) |
| 18 | `ui/playlist/thumbnail_tile.dart` | 305 | Thumbnail card |
| 19 | `ui/dialogs/settings_panel.dart` | ~1200 | Settings (merged) |
| 20 | `ui/dialogs/media_info_dialog.dart` | ~100 | File properties |

**Total: ~20 files, ~5,700 lines** (down from ~44 files, ~8,500+ lines)

---

## Phase 7: Verification

1. `D:\flutter\bin\flutter analyze` — 0 issues
2. `D:\flutter\bin\flutter run -d windows` — app launches
3. Manual checks:
   - Video plays, controls show/hide on mouse move
   - Control bar has semi-transparent background (NO blur over video)
   - Settings panel opens with blur (independent window, OK)
   - Playlist opens, folder/history tabs work
   - All keyboard shortcuts work
   - Volume, speed, progress bar functional
   - OSD messages appear
   - Error banner shows on playback error
   - Window resize doesn't cause jank

---

## Risk Mitigation

1. **Phase 1 (glass.dart)** — Lowest risk. GlassContainer → GlassSurface is a simplification. If anything breaks, the only consumer is empty_state.dart.

2. **Phase 2 (player_controls.dart)** — Highest risk. Merging 7 files into 1. Mitigation: build incrementally, verify after each sub-merge.

3. **Phase 3 (player_screen.dart)** — Medium risk. Changing constructor signature affects player_feature.dart. Update both files atomically.

4. **Phase 4-5 (playlist/settings)** — Low risk. Each tab is only imported by one parent file.

5. **Phase 6 (deletes)** — Low risk. All deleted files have verified zero remaining imports after merges.

---

## Commit Strategy

One commit per phase:
1. `refactor: consolidate glass widgets into glass.dart`
2. `refactor: merge player controls into player_controls.dart`
3. `refactor: PlayerScreen with PlayerActions config`
4. `refactor: inline playlist tabs into playlist_panel.dart`
5. `refactor: inline settings tabs into settings_panel.dart`
6. `refactor: delete 25 redundant UI files`
7. `verify: flutter analyze + manual smoke test`
