# Phase 2: Widget Unification - Pattern Map

**Mapped:** 2026-05-28
**Files analyzed:** 12 (3 new, 8 modified, 1 deleted)
**Analogs found:** 10 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/ui/shared/glass_container.dart` | component | request-response | `lib/ui/shared/glass_icon_button.dart` | exact (InkWell pattern source) |
| `lib/ui/shared/glass_widgets.dart` | barrel | — | `lib/ui/shared/value_listenable_builder2.dart` | structural (simple re-export) |
| `lib/ui/shared/glass_icon_button.dart` | component | request-response | — | DELETED |
| `lib/ui/player/control_bar.dart` | component | request-response | `lib/ui/shared/glass_icon_button.dart` | migration target |
| `lib/ui/player/center_controls.dart` | component | request-response | `lib/ui/shared/glass_icon_button.dart` | migration target |
| `lib/ui/player/volume_controls.dart` | component | request-response | `lib/ui/shared/glass_icon_button.dart` | migration target |
| `lib/ui/player/speed_button.dart` | component | request-response | `lib/ui/shared/glass_chip.dart` | role-match (InkWell segment) |
| `lib/ui/playlist/playlist_panel.dart` | component | request-response | `lib/ui/player/controls_overlay.dart` | role-match (ValueListenableBuilder) |
| `lib/ui/player/controls_overlay.dart` | component | event-driven | — | audit target (already optimized) |
| `lib/ui/player/progress_bar.dart` | component | event-driven | `lib/ui/player/controls_overlay.dart` | audit target |
| `lib/ui/player/player_screen.dart` | component | request-response | — | audit target (child caching) |
| `test/widget/shared/glass_button_test.dart` | test | — | `test/widget/player/control_bar_test.dart` | role-match |

## Pattern Assignments

### `lib/ui/shared/glass_container.dart` (component, request-response) — MAJOR REFACTOR

**Analog:** `lib/ui/shared/glass_icon_button.dart` (InkWell pattern) + current `glass_container.dart` (GlassContainer/GlassTier)

**Current state:** GlassButton (lines 75-203) uses `StatefulWidget` with `_hovered`/`_pressed` ValueNotifiers, `GestureDetector + MouseRegion + AnimatedBuilder` for scale animation. This must be replaced with `Material + InkWell` per D-06/D-07.

**Target API (merged GlassButton):**
```dart
// Add these fields from GlassIconButton:
final void Function(TapUpDetails details)? onSecondaryTapUp;  // NEW
final double iconSize;  // NEW (default: Tokens.iconLg)
final Color? color;     // NEW (default: Tokens.textPrimary)
final Widget? child;    // NEW (alternative to icon)
```

**Imports pattern (glass_container.dart lines 1-5):**
```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
```

**GlassContainer (unchanged, lines 23-67):**
```dart
class GlassContainer extends StatelessWidget {
  // ... 6 optional params, child required
  @override
  Widget build(BuildContext context) {
    final rRect = borderRadius ?? BorderRadius.circular(Tokens.radiusLarge);
    final content = Container(/* ... */);
    return ClipRRect(
      borderRadius: rRect,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: tier.sigma, sigmaY: tier.sigma),
        child: RepaintBoundary(child: content),
      ),
    );
  }
}
```

**Icon-only mode (copy from GlassIconButton lines 32-56 — lightweight, NO BackdropFilter):**
```dart
// SOURCE: lib/ui/shared/glass_icon_button.dart lines 32-56
@override
Widget build(BuildContext context) {
  final content = child ?? Icon(icon!, size: iconSize, color: color);
  return Tooltip(
    message: tooltip ?? '',
    waitDuration: const Duration(milliseconds: 400),
    child: SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        borderRadius: _radius,
        child: InkWell(
          onTap: onPressed,
          onSecondaryTapUp: onSecondaryTapUp,
          hoverColor: Tokens.bgHover,
          highlightColor: Colors.transparent,
          borderRadius: _radius,
          splashFactory: NoSplash.splashFactory,
          child: Center(child: content),
        ),
      ),
    ),
  );
}
```

**Label mode (refactor from current GlassButton lines 134-161 + InkWell from GlassIconButton):**
```dart
// Keep GlassContainer for label mode, but wrap with Material+InkWell instead of GestureDetector+scale
// REMOVE: _hovered, _pressed, _interaction ValueNotifiers (lines 110-112)
// REMOVE: AnimatedBuilder + scale transform (lines 182-198)
// REPLACE WITH: Material + InkWell wrapper around GlassContainer content
```

**Key design constraint (from RESEARCH.md):** The icon-only mode MUST NOT use GlassContainer/BackdropFilter. Current GlassIconButton at 36x36 has no blur. Adding blur to 15+ control bar buttons = performance regression.

**Change summary for glass_container.dart:**
1. Convert `GlassButton` from `StatefulWidget` to `StatelessWidget`
2. Remove `_hovered`, `_pressed`, `_interaction` fields and `dispose()`
3. Add fields from GlassIconButton: `onSecondaryTapUp`, `iconSize`, `color`, `child`
4. Icon-only path: use `Material + InkWell + SizedBox(36x36)` — no GlassContainer
5. Label path: use `Material + InkWell` wrapping `GlassContainer` content — no scale animation
6. Both paths use `InkWell` with `hoverColor: Tokens.bgHover`, `splashFactory: NoSplash.splashFactory`

---

### `lib/ui/shared/glass_widgets.dart` (barrel file) — NEW

**Analog:** None (simple re-export file)

**Pattern:** Standard Dart barrel file — only `export` statements, no logic.
```dart
/// Glass 组件统一导出
///
/// 使用: import '../shared/glass_widgets.dart';
export 'glass_container.dart' show GlassContainer, GlassButton, GlassTier;
export 'glass_chip.dart' show GlassChip;
```

**Note:** GlassChip stays independent per D-04. Do not import `glass_icon_button.dart` (will be deleted).

---

### `lib/ui/player/control_bar.dart` (component, request-response) — MIGRATION

**Analog:** `lib/ui/shared/glass_icon_button.dart` (current import being replaced)

**Current imports (lines 1-13):**
```dart
import '../shared/glass_icon_button.dart';  // line 8 — CHANGE TO glass_widgets.dart
```

**Migration sites (6 GlassIconButton calls):**

| Line | Current | Target |
|------|---------|--------|
| 207-211 | `GlassIconButton(icon: playModeIcon ?? Icons.repeat, ...)` | `GlassButton.iconOnly(icon: playModeIcon ?? Icons.repeat, ...)` |
| 252-256 | `GlassIconButton(icon: Icons.folder_open, ...)` | `GlassButton.iconOnly(icon: Icons.folder_open, ...)` |
| 258-262 | `GlassIconButton(icon: Icons.subtitles, ...)` | `GlassButton.iconOnly(icon: Icons.subtitles, ...)` |
| 264-268 | `GlassIconButton(icon: Icons.queue_music, ...)` | `GlassButton.iconOnly(icon: Icons.queue_music, ...)` |
| 270-277 | `GlassIconButton(icon: Icons.settings, onSecondaryTapUp: ...)` | `GlassButton.iconOnly(icon: Icons.settings, onSecondaryTapUp: ...)` |
| 279-283 | `GlassIconButton(icon: isFullscreen ? ...)` | `GlassButton.iconOnly(icon: isFullscreen ? ...)` |

**Mechanical rename:** `GlassIconButton(` → `GlassButton.iconOnly(` at all 6 sites.

---

### `lib/ui/player/center_controls.dart` (component, request-response) — MIGRATION

**Analog:** `lib/ui/shared/glass_icon_button.dart`

**Current imports (line 7):**
```dart
import '../shared/glass_icon_button.dart';  // CHANGE TO glass_widgets.dart
```

**Migration sites (7 GlassIconButton calls):**

| Line | Current | Target |
|------|---------|--------|
| 30-36 | `GlassIconButton(icon: playing ? Icons.pause : Icons.play_arrow, iconSize: Tokens.iconXl, ...)` | `GlassButton.iconOnly(icon: ..., iconSize: Tokens.iconXl, ...)` |
| 69-74 | `GlassIconButton(icon: Icons.skip_previous, color: dimmed, ...)` | `GlassButton.iconOnly(icon: Icons.skip_previous, color: dimmed, ...)` |
| 76-80 | `GlassIconButton(icon: Icons.replay_10, color: dimmed, ...)` | `GlassButton.iconOnly(icon: Icons.replay_10, color: dimmed, ...)` |
| 91-95 | `GlassIconButton(icon: Icons.forward_30, color: dimmed, ...)` | `GlassButton.iconOnly(icon: Icons.forward_30, color: dimmed, ...)` |
| 98-103 | `GlassIconButton(icon: Icons.skip_next, color: dimmed, ...)` | `GlassButton.iconOnly(icon: Icons.skip_next, color: dimmed, ...)` |
| 105-110 | `GlassIconButton(icon: Icons.stop, color: dimmed, ...)` | `GlassButton.iconOnly(icon: Icons.stop, color: dimmed, ...)` |

**Note:** PlayPauseButton (line 30) uses `iconSize: Tokens.iconXl` and `color: baseColor.withValues(alpha: ...)` — both params must be supported by the merged GlassButton.iconOnly.

---

### `lib/ui/player/volume_controls.dart` (component, request-response) — MIGRATION + AUDIT

**Analog:** `lib/ui/shared/glass_icon_button.dart` (migration) + `lib/ui/player/controls_overlay.dart` (ValueNotifier audit)

**Current imports (line 7):**
```dart
import '../shared/glass_icon_button.dart';  // CHANGE TO glass_widgets.dart
```

**Migration site (1 GlassIconButton call, line 57):**
```dart
// BEFORE:
GlassIconButton(icon: icon, iconSize: Tokens.iconLg, color: muted ? Tokens.accent : Tokens.textPrimary, onPressed: _toggleMute, tooltip: ...)
// AFTER:
GlassButton.iconOnly(icon: icon, iconSize: Tokens.iconLg, color: muted ? Tokens.accent : Tokens.textPrimary, onPressed: _toggleMute, tooltip: ...)
```

**ValueNotifier audit — VolumeSlider (lines 70-112):**
- `ValueListenableBuilder<double>` wrapping Slider (line 94)
- The `Slider` widget depends on `volume` value — cannot cache via `child` parameter
- The `SizedBox(width: 100)` and `Listener` wrapper are static — could cache outer structure
- **Verdict:** Low optimization potential. Slider must rebuild on volume change.

**ValueNotifier audit — VolumeButton (lines 11-67):**
- Uses `ValueListenableBuilder2<bool, double>` (line 45) — already optimized dual-notifier
- Builder produces `GlassIconButton` which depends on both `muted` and `volume` — cannot cache
- **Verdict:** Already optimal.

---

### `lib/ui/player/speed_button.dart` (component, request-response) — AUDIT

**Analog:** `lib/ui/shared/glass_chip.dart` (InkWell segment pattern)

**ValueNotifier audit (lines 64-86):**
- `ValueListenableBuilder<double>` wrapping Row with 3 `_Segment` widgets
- `leftArrow` and `rightArrow` are created outside the builder (lines 42-53) — already cached as local variables
- Only the middle segment (label) depends on `speed` value
- **Current optimization:** Left/right arrows are `StatelessWidget` references, so they don't rebuild
- **Possible improvement:** Could pass leftArrow/rightArrow as `child` to a hypothetical builder, but they're already cheap StatelessWidget refs
- **Verdict:** Already well-optimized. No changes needed.

---

### `lib/ui/playlist/playlist_panel.dart` (component, request-response) — AUDIT

**Analog:** `lib/ui/player/controls_overlay.dart`

**ValueNotifier audit:**
- `_selectedTab` ValueNotifier (line 56) — used with `AnimatedBuilder` (line 185)
- `AnimatedBuilder` rebuilds Column with tab bar + content on tab change
- Tab bar (`_buildTabBar()`) reads `_selectedTab.value` directly — must rebuild on tab change
- Content (`_buildContent()`) depends on tab selection — must rebuild
- **Verdict:** No optimization possible — all children depend on `_selectedTab.value`.

**Note:** PlaylistPanel does NOT use GlassIconButton (confirmed by grep). No migration needed.

---

### `lib/ui/player/controls_overlay.dart` (component, event-driven) — AUDIT

**No analog needed — this is the reference pattern.**

**ValueNotifier audit (lines 136-141):**
```dart
ValueListenableBuilder<bool>(
  valueListenable: _autoHide.visible,
  builder: (_, isVisible, child) =>
      IgnorePointer(ignoring: !isVisible, child: child),
  child: RepaintBoundary(child: Stack(children: [...])), // cached!
)
```
**Verdict:** Already optimal — `child` parameter caches the static Stack subtree.

---

### `lib/ui/player/progress_bar.dart` (component, event-driven) — AUDIT

**Analog:** `lib/ui/player/controls_overlay.dart`

**ValueNotifier audit:**
- `_barListenable = Listenable.merge([position, duration, buffered, _dragNotifier])` (lines 58-63) — already merged
- `AnimatedBuilder` wrapping `_buildBarLayers()` (line 180) — uses `RepaintBoundary`
- `ValueListenableBuilder<_HoverState>` for hover tooltip (lines 151-167)
- Hover tooltip builder returns either `SizedBox.shrink()` or `_buildTooltip()` — cannot cache (depends on hover state)
- **Verdict:** Already well-optimized. Merged listenable, RepaintBoundary, post-frame hover scheduling.

---

### `lib/ui/player/player_screen.dart` (component, request-response) — AUDIT

**Analog:** `lib/ui/player/controls_overlay.dart` (child caching pattern)

**ValueNotifier audit:**
- `ValueListenableBuilder<int?>` for textureId (line 110) — rebuilds entire screen on texture change. `videoContent` is built inside builder but passed as `child` to inner builder (line 190). **Already cached.**
- `ValueListenableBuilder<bool>` for playlistVisible (line 153) — `child: videoContent` caches static subtree. **Already optimized.**
- `ValueListenableBuilder<MediaState>` for empty state (lines 217-225) — `child: Positioned.fill(...)` caches. **Already optimized.**
- **Verdict:** All 3 instances already use `child` caching. No changes needed.

---

### `test/widget/shared/glass_button_test.dart` (test) — NEW

**Analog:** `test/widget/player/control_bar_test.dart`

**Test pattern (from control_bar_test.dart lines 1-53):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
// ... import glass_widgets.dart instead of glass_container.dart

void main() {
  Widget buildSubject({...}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(/* ... */),
      ),
    );
  }

  group('GlassButton', () {
    testWidgets('icon-only mode renders icon', (tester) async { ... });
    testWidgets('label mode renders icon and label', (tester) async { ... });
    testWidgets('icon-only tap fires onPressed', (tester) async { ... });
    testWidgets('label mode tap fires onPressed', (tester) async { ... });
    testWidgets('icon-only with onSecondaryTapUp', (tester) async { ... });
    testWidgets('disabled button does not fire onPressed', (tester) async { ... });
  });
}
```

**Required test cases (from RESEARCH.md):**
- WIDGET-01: GlassButton renders icon-only mode
- WIDGET-01: GlassButton renders label mode
- WIDGET-01: GlassButton icon-only tap fires onPressed
- WIDGET-01: GlassButton label mode tap fires onPressed

---

### `lib/ui/shared/glass_icon_button.dart` — DELETE

**Status:** All 3 importers (`control_bar.dart`, `center_controls.dart`, `volume_controls.dart`) migrated. File deleted after migration.

**Verification command:** `grep -r "glass_icon_button" lib/` returns 0 matches.

---

## Shared Patterns

### InkWell Button Pattern (from GlassIconButton)
**Source:** `lib/ui/shared/glass_icon_button.dart` lines 40-55
**Apply to:** All GlassButton modes (icon-only and label)
```dart
Material(
  color: Colors.transparent,
  borderRadius: _radius,
  child: InkWell(
    onTap: onPressed,
    onSecondaryTapUp: onSecondaryTapUp,
    hoverColor: Tokens.bgHover,
    highlightColor: Colors.transparent,
    borderRadius: _radius,
    splashFactory: NoSplash.splashFactory,
    child: Center(child: content),
  ),
)
```
**Key tokens:** `Tokens.bgHover` for hover state, `NoSplash.splashFactory` for no splash, `Tokens.radiusBtn` for border radius.

### Conditional BackdropFilter Skip (from ControlBar)
**Source:** `lib/ui/player/control_bar.dart` lines 123-135
**Apply to:** GlassContainer (D-13 degradation mode)
```dart
if (opacity != null) {
  return AnimatedBuilder(
    animation: opacity!,
    builder: (_, child) {
      if (opacity!.value < 0.01) return child!; // skip BackdropFilter
      return ClipRRect(
        borderRadius: _borderRadius,
        child: BackdropFilter(filter: _blurFilter, child: child),
      );
    },
    child: blurContent,
  );
}
```

### ValueListenableBuilder Child Caching
**Source:** `lib/ui/player/controls_overlay.dart` lines 136-141
**Apply to:** All ValueListenableBuilder instances where builder output has a static subtree
```dart
ValueListenableBuilder<T>(
  valueListenable: notifier,
  builder: (_, value, child) => /* use value + child */,
  child: /* static subtree — built once, reused on rebuild */,
)
```

### Barrel File Pattern
**Source:** Project convention (simple re-export)
**Apply to:** `glass_widgets.dart`
```dart
export 'glass_container.dart' show GlassContainer, GlassButton, GlassTier;
export 'glass_chip.dart' show GlassChip;
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/ui/shared/glass_widgets.dart` | barrel | — | First barrel file in project; trivial re-export pattern |
| `test/widget/shared/glass_button_test.dart` | test | — | First shared widget test; adapt from control_bar_test.dart |

## Migration Checklist

### Import Changes (3 files)
- [ ] `lib/ui/player/control_bar.dart` line 8: `glass_icon_button.dart` → `glass_widgets.dart`
- [ ] `lib/ui/player/center_controls.dart` line 7: `glass_icon_button.dart` → `glass_widgets.dart`
- [ ] `lib/ui/player/volume_controls.dart` line 7: `glass_icon_button.dart` → `glass_widgets.dart`

### GlassIconButton → GlassButton.iconOnly Renames (14 call sites)
- [ ] `control_bar.dart`: 6 calls (lines 207, 252, 258, 264, 270, 279)
- [ ] `center_controls.dart`: 7 calls (lines 30, 69, 76, 91, 98, 105)
- [ ] `volume_controls.dart`: 1 call (line 57)

### Token Cleanup (post-merge)
- [x] `Tokens.hoverScale` — also used by `settings_card.dart` line 143 — CANNOT remove
- [x] `Tokens.pressScale` — also used by `settings_card.dart` line 143 — CANNOT remove
- [ ] Remove scale animation usage from `glass_container.dart` GlassButton (lines 186-187) — these references go away with the refactor, but the token definitions stay

## Metadata

**Analog search scope:** `lib/ui/shared/`, `lib/ui/player/`, `lib/ui/playlist/`, `lib/ui/dialogs/`, `test/widget/`
**Files scanned:** 15 source files + 5 test files
**Pattern extraction date:** 2026-05-28
