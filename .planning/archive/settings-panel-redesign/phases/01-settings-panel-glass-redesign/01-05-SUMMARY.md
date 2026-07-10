---
plan: 01-05
phase: 01-settings-panel-glass-redesign
status: complete
completed: "2026-07-09"
---

# Plan 01-05 Summary: Fix Double BackdropFilter Nesting

## What Was Built

Fixed invisible glassmorphism effect caused by double `BackdropFilter` nesting. The outer `GlassContainer` wrapping the entire settings panel was replaced with `ClipRRect + Container(bgElevated)`, leaving only the per-tab `GlassContainer` instances as the single blur layer.

## Tasks Completed

### Task 1: Modify settings_panel.dart
- Removed `import '../shared/glass_container.dart'` (outer layer no longer needs it)
- Replaced outer `GlassContainer` with `ClipRRect + Container(bgElevated, borderHighlight)`
- Title bar: `Tokens.bgGlass` → `Tokens.bgElevated` (opaque dark background)
- Bottom bar: `Tokens.bgGlass` → `Tokens.bgElevated` (opaque dark background)
- Tab inner `GlassContainer` instances preserved (they are the correct single blur layer)

### Task 2: Verification — PENDING HUMAN CHECKPOINT
Requires manual visual verification:
1. `flutter run -d windows`
2. Open settings panel — confirm round corners + highlight border
3. Confirm title bar is opaque dark (not translucent blur)
4. Switch all 7 tabs — confirm each tab's cards have clear glass blur effect
5. Confirm OK/Cancel/Apply buttons work
6. Confirm drag works

## Key Files
- `lib/ui/dialogs/settings_panel.dart` — modified (outer GlassContainer → ClipRRect)

## Verification
- `flutter analyze lib/ui/dialogs/settings_panel.dart` → No issues found
- `flutter test test/widget/settings/` → 28/28 tests passed
- No new warnings introduced

## Root Cause
Plans 01-01/02/03 migrated tabs to `GlassContainer` AND wrapped the outer panel in `GlassContainer` too. Two `BackdropFilter` layers + two `bgGlass` (55% opacity) layers = ~80% effective opacity, killing the glass effect.

## Fix Strategy
- **Outer shell:** `ClipRRect` (clipping only, no blur) + `Container(bgElevated)` (opaque background)
- **Inner tabs:** Keep their `GlassContainer` (single blur layer, visible glass effect)
- **Title bar / Bottom bar:** `bgElevated` (opaque, consistent with panel body)

## Requirements Satisfied
- STYLE-01: GlassContainer pattern ✓
- STYLE-02: Single BackdropFilter layer ✓
- STYLE-03: bgElevated for opaque areas ✓
- STYLE-04: borderHighlight preserved ✓
- COMP-01: Component hierarchy simplified ✓
- COMP-04: No double nesting ✓

## Self-Check: PASSED
- `flutter analyze` clean
- 28/28 settings tab tests passing
- glass_container.dart import removed (no longer needed by outer shell)
