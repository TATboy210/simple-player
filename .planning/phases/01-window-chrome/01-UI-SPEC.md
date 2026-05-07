---
phase: 1
slug: window-chrome
status: approved
reviewed_at: 2026-05-07
shadcn_initialized: false
preset: not applicable (Flutter project)
created: 2026-05-07
---

# Phase 1 — UI Design Contract: Window Chrome

> Visual and interaction contract for the custom title bar with glass-morphism, window controls, and production quality baseline.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter built-in widgets) |
| Preset | not applicable |
| Component library | Flutter Material 3 (minimal usage) |
| Icon library | Material Icons (built-in `Icons.*`) |
| Font | System default (Roboto on Windows) |
| Design tokens | `Tokens` class in `lib/kernel/ui/theme/tokens.dart` |

---

## Token Additions Required

The current `tokens.dart` is missing several tokens used by the title bar. These must be added before implementation.

| Token | Value | Category | Purpose |
|-------|-------|----------|---------|
| `titleBarHeight` | `36.0` | Layout | Title bar height (WB-01) |
| `titleBarButtonWidth` | `46.0` | Layout | Width of each window control button |
| `glassBlurThin` | `12.0` | Glass | BackdropFilter sigma for title bar |
| `glassBlur` | `16.0` | Glass | BackdropFilter sigma for control bar (Phase 2+) |
| `glassBlurThick` | `24.0` | Glass | BackdropFilter sigma for dialogs (Phase 2+) |
| `durationFast` | `80` | Animation | Press feedback duration (ms) |
| `durationNormal` | `150` | Animation | Hover state duration (ms) |
| `durationDebounce` | `500` | Animation | Resize debounce duration (ms, Phase 2) |
| `iconLg` | `20.0` | Icon | Large icon size |

---

## Spacing Scale

All values from existing `Tokens` (multiples of 4, confirmed):

| Token | Value | Phase 1 Usage |
|-------|-------|---------------|
| `spXs` | 4px | Icon-to-text micro gap |
| `spSm` | 8px | App icon to file name gap |
| `spMd` | 12px | Title bar left/right padding |
| `spLg` | 16px | (not used in Phase 1) |
| `spXl` | 24px | (not used in Phase 1) |

Exceptions: `titleBarButtonWidth` is 46px (not a multiple of 4) -- matches Windows 11 standard control width. Acceptable exception.

---

## Typography

Phase 1 uses only two text styles:

| Role | Token | Size | Weight | Color Token | Usage |
|------|-------|------|--------|-------------|-------|
| Title bar text | `fontCaption` | 12px | w500 (medium) | `textSecondary` | File name + app name |
| Tooltip | `fontOverline` | 10px | w400 (regular) | `textPrimary` | Button tooltips (system default) |

Line height: Flutter default (1.2-1.4 depending on font). No override needed.

---

## Color Contract

### Title Bar Elements

| Element | Color Token | Hex | State |
|---------|-------------|-----|-------|
| Glass background | `bgGlass` | `0x801A1A24` | Default |
| Glass border (top) | `borderHighlight` | `0x33FFFFFF` | Always |
| App icon | `accent` | `0xFF6C5CE7` | Always |
| File name text | `textSecondary` | `0xFF9999AA` | Default |
| Button icon (normal) | `textSecondary` | `0xFF9999AA` | Default |
| Button icon (hover) | `textPrimary` | `0xFFE8E8F0` | Hovered |
| Button icon (active/pinned) | `accent` | `0xFF6C5CE7` | isAlwaysOnTop = true |
| Button bg (hover) | `bgHover` | `0xFF2A2A3A` | Hovered |
| Close button bg (hover) | `danger` | `0xFFFF6B6B` | Close hovered |
| Resize fallback bg | `bgGlass` | `0x801A1A24` | isResizing = true (no blur) |

### Accent Reserved For (Phase 1)

- App icon in title bar
- Pinned state indicator (active pin icon color)
- (Future phases: progress bar, active controls, EQ sliders)

### 60/30/10 Split (Phase 1 scope)

- **60% dominant**: `bgBase` (#0A0A0F) -- window background behind title bar
- **30% secondary**: `bgGlass` (#1A1A24 @ 50% opacity) -- title bar surface
- **10% accent**: `accent` (#6C5CE7) -- app icon, pinned indicator

---

## Title Bar Layout Contract

### Dimensions

```
+--[12px]--[icon 20px]--[8px]--[text]--[SPACER]--[46px][46px][46px][46px]--[0px]--+
|                              36px total height                                    |
+-----------------------------------------------------------------------------------+
```

| Property | Value | Source |
|----------|-------|--------|
| Height | 36px | `Tokens.titleBarHeight` (requirement WB-01) |
| Left padding | 12px | `Tokens.spMd` |
| Icon-to-text gap | 8px | `Tokens.spSm` |
| Button width | 46px | `Tokens.titleBarButtonWidth` |
| Button height | 36px | `Tokens.titleBarHeight` (full height) |
| Icon size (app) | 20px | `Tokens.iconMd` |
| Icon size (buttons) | 16px | `Tokens.iconSm` |

### Glass-Morphism Stack

```
GestureDetector (drag + double-tap)
  +-- ValueListenableBuilder<bool> (isResizing)
       |
       +-- [resizing=true]  --> child (plain bgGlass, no blur)
       +-- [resizing=false] --> ClipRect --> BackdropFilter(blur 12px) --> child
            |
            +-- Container (height: 36, color: bgGlass)
                 +-- Row
                      +-- [12px spacer]
                      +-- [app icon 20px]
                      +-- [8px spacer]
                      +-- [file name text OR "Simple Player"]
                      +-- [Spacer]
                      +-- [TitleBarControls row]
```

### File Name Display (WB-02)

| State | Display |
|-------|---------|
| No file open | `Simple Player` |
| File open, name available | `{filename} — Simple Player` |
| File name is empty string | `Simple Player` |

Source: `ValueListenableBuilder<String>` on `fileName` notifier.

---

## Window Controls Contract (WC-01..WC-05)

### Control Layout (left to right)

| Position | Icon (default) | Icon (active) | Tooltip | Action | State Source |
|----------|---------------|---------------|---------|--------|--------------|
| 1 | `Icons.push_pin` | same (color: accent) | Pin / Unpin | `toggleAlwaysOnTop()` | `isAlwaysOnTop` ValueNotifier |
| 2 | `Icons.minimize` | -- | Minimize | `minimize()` | (none, stateless) |
| 3 | `Icons.crop_square` | `Icons.filter_none` | Maximize / Restore | `toggleMaximize()` | `isMaximized` ValueNotifier |
| 4 | `Icons.close` | -- | Close | `close()` | (none, stateless) |

### Button Interaction States

| State | Background | Icon Color | Cursor |
|-------|-----------|------------|--------|
| Normal | transparent | `textSecondary` (#9999AA) | default |
| Hovered | `bgHover` (#2A2A3A) | `textPrimary` (#E8E8F0) | click |
| Hovered (close) | `danger` (#FF6B6B) | `textPrimary` (#E8E8F0) | click |
| Active (pinned) | transparent | `accent` (#6C5CE7) | default |
| Active + Hovered | `bgHover` (#2A2A3A) | `textPrimary` (#E8E8F0) | click |

### Tooltip Behavior

- `waitDuration`: 400ms delay before showing
- Position: below button (Flutter default)
- Style: system default Material tooltip

---

## Gesture Contract (WB-03, WB-04)

| Gesture | Target | Action |
|---------|--------|--------|
| Pan start (drag) | Title bar area | `PlatformService.I.startDragging()` |
| Double tap | Title bar area | `PlatformService.I.toggleMaximize()` |
| Single tap | Button area | Button's `onPressed` callback |

Implementation: Outer `GestureDetector` with `behavior: HitTestBehavior.translucent` covers entire title bar. Inner `_TitleBarButton` gesture detectors intercept taps on buttons (buttons are on top in z-order).

---

## Resize Degradation Contract

When `PlatformService.I.isResizing.value == true`:

| Layer | Behavior |
|-------|----------|
| BackdropFilter | **Skipped** (not rendered) |
| Background | Plain `bgGlass` color (no blur) |
| Content | Unchanged (icons, text, buttons still visible) |

Purpose: Skip GPU-heavy blur during drag resize to prevent jank (WB-05 prep, full debounce in Phase 2).

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Title (no file) | `Simple Player` |
| Title (with file) | `{filename} — Simple Player` |
| Pin tooltip | `Pin` / `Unpin` (from l10n) |
| Minimize tooltip | `Minimize` (from l10n) |
| Maximize tooltip | `Maximize` / `Restore` (from l10n) |
| Close tooltip | `Close` (from l10n) |

Note: Tooltip strings come from `AppLocalizations` (l10n). Phase 1 must use existing l10n keys. If keys are missing, add to `lib/l10n/` with both `zh` and `en` translations.

---

## Widget Inventory

### New Files to Create

| File | Widget | Type | Purpose |
|------|--------|------|---------|
| `lib/kernel/ui/window/custom_title_bar.dart` | `CustomTitleBar` | StatelessWidget | Title bar container with glass-morphism and gestures |
| `lib/kernel/ui/window/custom_title_bar.dart` | `TitleBarControls` | StatelessWidget | Row of 4 window control buttons |
| `lib/kernel/ui/window/custom_title_bar.dart` | `_TitleBarButton` | StatefulWidget | Individual button with hover state |

### Files to Modify

| File | Change |
|------|--------|
| `lib/kernel/ui/theme/tokens.dart` | Add 9 new tokens (see Token Additions Required) |
| `lib/kernel/services/platform_service.dart` | Ensure `isAlwaysOnTop`, `isMaximized`, `isResizing`, `startDragging()`, `toggleMaximize()`, `toggleAlwaysOnTop()`, `minimize()`, `close()` exist |

### Test Files to Create

| File | Coverage |
|------|----------|
| `test/widget/window/custom_title_bar_test.dart` | Widget tests for CustomTitleBar and TitleBarControls |

---

## State Wiring Contract

### ValueNotifiers Used (from PlatformService)

| Notifier | Type | Used By | Purpose |
|----------|------|---------|---------|
| `isAlwaysOnTop` | `ValueNotifier<bool>` | TitleBarControls (pin button) | Pin icon color toggle |
| `isMaximized` | `ValueNotifier<bool>` | TitleBarControls (maximize button) | Icon toggle (crop_square / filter_none) |
| `isResizing` | `ValueNotifier<bool>` | CustomTitleBar | Skip BackdropFilter during resize |
| `currentFileName` | `ValueNotifier<String>` | CustomTitleBar | Display current file name |

### Disposal Contract (PQ-05)

- `CustomTitleBar` is `StatelessWidget` -- no disposal needed (notifiers owned by PlatformService)
- `_TitleBarButton` is `StatefulWidget` -- only local `_hovered` bool, no disposal needed
- All `ValueNotifier` disposal is the responsibility of `PlatformService` / `WindowManagerService`

---

## FFI Error Handling Contract (PQ-06)

All window control methods must be wrapped in try-catch:

```dart
void minimize() {
  try {
    windowManager.minimize();
  } on Exception catch (e) {
    debugPrint('[WindowManager] minimize failed: $e');
  }
}
```

Pattern: `_guardedAction(name, action)` wrapper (existing codebase pattern).

Applies to: `minimize()`, `toggleMaximize()`, `toggleAlwaysOnTop()`, `close()`, `startDragging()`.

---

## Registry Safety

Not applicable. Flutter project uses no external UI registries. All widgets are built from Flutter SDK primitives.

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| (none) | -- | -- |

---

## Production Quality Checklist (PQ-01..PQ-07)

| Requirement | Verification Method |
|-------------|-------------------|
| PQ-01: flutter analyze zero warnings | Run `flutter analyze` after implementation |
| PQ-03: Unit tests for controls state | Widget tests: pin color, maximize icon toggle |
| PQ-05: Dispose safety | No new ValueNotifiers in title bar widgets; PlatformService disposal covers all |
| PQ-06: FFI error handling | All PlatformService methods wrapped in try-catch |
| PQ-07: No hardcoded values | All sizes/colors from `Tokens.*` constants |

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS (not applicable)

**Approval:** pending
