# Phase 2: Widget Unification - Research

**Researched:** 2026-05-28
**Domain:** Flutter glass component library + ValueNotifier rebuild optimization
**Confidence:** HIGH

## Summary

Phase 2 unifies the glass component library (GlassContainer, GlassButton, GlassIconButton, GlassChip) into a consistent API with a single barrel file export, and optimizes ValueNotifier rebuild patterns across the UI layer.

The core challenge is merging GlassIconButton (lightweight 36x36 Material + InkWell, no blur) with GlassButton (GlassContainer-based with BackdropFilter blur). These two widgets have fundamentally different rendering models. The merge must preserve GlassIconButton's lightweight inline-button behavior for the ~15 control bar call sites while consolidating the API.

The ValueNotifier optimization is largely a verification pass -- the codebase already uses `child` caching, `MergedListenable`, and `ValueListenableBuilder2` correctly in most places. The main targets for optimization are VolumeSlider and SpeedButton's inner segments.

**Primary recommendation:** Merge GlassIconButton into GlassButton by adding a lightweight `GlassButton.iconOnly` mode that uses Material + InkWell (no GlassContainer/BackdropFilter), matching GlassIconButton's current rendering. Then refactor GlassButton's label mode to use InkWell per D-06. Create barrel file, migrate all 15 call sites, audit ValueListenableBuilder instances.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Merge GlassIconButton into GlassButton -- unified component with `icon` (label) and `iconOnly` constructors
- **D-02:** Full migration + delete GlassIconButton file -- all ~20 call sites updated in one pass, no deprecation shim
- **D-03:** Create `glass_widgets.dart` barrel file -- exports GlassContainer, GlassButton, GlassChip, GlassTier
- **D-04:** GlassChip stays independent -- selector semantics differ from button action semantics
- **D-05:** GlassContainer API unchanged -- 6 optional parameters (child required), flexible and sufficient
- **D-06:** All modes use InkWell (no scale animation) -- aligns with user feedback: "按钮不要动画效果，保留 InkWell hover/press 反馈即可"
- **D-07:** No hover/press animation mixin needed -- InkWell handles hover/press state internally
- **D-08:** ControlBar parameter list unchanged -- 16+ params are stable callback references, no extra rebuild cost
- **D-09:** No immutable state object or Record wrapping -- premature abstraction for stable props
- **D-10:** Audit scope: all `ui/` directory (not just player/)
- **D-11:** Audit all 4 dimensions: child caching, notifier merging, rebuild baseline, unnecessary listeners
- **D-12:** 30% rebuild reduction target validated via qualitative judgment + code analysis estimation (not DevTools profiling)
- **D-13:** Conditional BackdropFilter skip -- skip blur when opacity=0 or widget not visible
- **D-14:** Degradation mode -- no-blur fallback for low-end hardware (settings toggle or auto-detect)
- **D-15:** GlassTier layer evaluation -- assess if 3 tiers (thin/normal/thick) can be reduced to 2
- **D-16:** Core widget tests for merged GlassButton -- cover both icon-only and label modes (render + tap behavior)
- **D-17:** No golden tests in Phase 2 -- deferred to Phase 4

### Claude's Discretion
- GlassButton internal implementation details (how to merge InkWell patterns)
- Barrel file exact export list ordering
- Which ValueListenableBuilder instances need child caching (audit-driven)
- GlassTier evaluation outcome (data-driven decision)
- Degradation mode trigger mechanism (setting vs auto-detect)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WIDGET-01 | Unify glass component library -- single barrel file, consistent GlassTier, merge GlassButton/GlassIconButton, shared animation patterns | GlassIconButton has 15 call sites in 3 files. GlassButton already has icon/iconOnly constructors. Merge strategy: refactor GlassButton internals to use InkWell (D-06), keep icon-only mode lightweight (no BackdropFilter). Create glass_widgets.dart barrel. |
| WIDGET-02 | Optimize ValueNotifier rebuilds -- audit child caching, merge related notifiers, cache static subtrees, 30%+ rebuild reduction | 25+ ValueListenableBuilder instances found. Most already use child caching. MergedListenable exists. Key targets: VolumeSlider, SpeedButton segments, ProgressBar hover. ControlsOverlay architecture is already clean (no 8-field cache). |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Glass component rendering | UI Widget | Theme/Tokens | GlassContainer/GlassButton are pure UI widgets consuming Tokens.* constants |
| ValueNotifier rebuild optimization | UI Widget | Engine | Widgets consume engine ValueNotifiers; optimization is widget-layer concern |
| BackdropFilter performance | UI Widget | — | Conditional skip and degradation mode are widget-layer rendering decisions |
| Barrel file export | UI Shared | — | glass_widgets.dart is a shared UI module export |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material | SDK | Material + InkWell + BackdropFilter | Already in use, no new dependencies needed |
| flutter/foundation | SDK | ValueNotifier, ValueListenableBuilder, Listenable.merge | Already in use for state management |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:ui | SDK | ImageFilter.blur for BackdropFilter | Already used in GlassContainer and ControlBar |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual barrel file | auto_barrel or build_runner | Overkill for 4 exports; manual is simpler |
| AnimatedContainer for hover | InkWell hoverColor | D-06/D-07: InkWell only, no animation |

**Installation:**
```bash
# No new packages needed -- all using Flutter SDK
```

**Version verification:** No external packages required. All components use Flutter SDK built-in widgets and dart:ui.

## Package Legitimacy Audit

No external packages are installed in this phase. All components use Flutter SDK built-in widgets (Material, InkWell, BackdropFilter, ValueNotifier). Skip audit.

## Architecture Patterns

### System Architecture Diagram

```
User Interaction (tap/hover)
        |
        v
GlassButton (icon / iconOnly mode)
        |
        +-- iconOnly mode: Material + InkWell (lightweight, no blur)
        |       |
        |       +-- 36x36 or 48x48 (Tokens.iconButtonSizeLarge)
        |
        +-- label mode: GlassContainer + InkWell
                |
                +-- BackdropFilter (GlassTier.sigma)
                +-- ClipRRect + RepaintBoundary
                        |
                        v
                  Tokens.* (colors, spacing, radius)
```

### Recommended Project Structure
```
lib/ui/shared/
├── glass_widgets.dart          # NEW: barrel file (GlassContainer, GlassButton, GlassChip, GlassTier)
├── glass_container.dart        # GlassContainer + GlassTier enum (unchanged)
├── glass_chip.dart             # GlassChip (unchanged, independent)
├── glass_icon_button.dart      # DELETED after migration
├── value_listenable_builder2.dart  # Existing dual-notifier builder
├── merged_listenable.dart      # Existing position+duration merger
└── ...
```

### Pattern 1: GlassButton Dual-Mode Architecture

**What:** GlassButton supports two rendering modes via named constructors -- `GlassButton(icon, label)` for labeled buttons with GlassContainer blur, and `GlassButton.iconOnly(icon)` for lightweight inline buttons with Material + InkWell only.

**When to use:** All glass button needs in the UI. Use `icon` constructor for primary actions (open file, settings), `iconOnly` for inline control bar buttons.

**Critical design insight:** The current GlassIconButton has NO BackdropFilter (it's just Material + InkWell at 36x36). The current GlassButton wraps GlassContainer which HAS BackdropFilter. The merged icon-only mode must preserve the lightweight rendering -- adding BackdropFilter to every 36x36 control bar button would be a performance regression.

**Example (target API):**
```dart
// Lightweight icon-only (replaces GlassIconButton) -- no BackdropFilter
GlassButton.iconOnly(
  icon: Icons.play_arrow,
  onPressed: () => engine.togglePlayPause(),
  tooltip: 'Play',
)

// Labeled button with glass blur (existing GlassButton)
GlassButton(
  icon: Icons.folder_open,
  label: 'Open File',
  onPressed: () => openFile(),
)

// Current GlassIconButton call site migration:
// BEFORE: GlassIconButton(icon: Icons.pause, onPressed: togglePlayPause)
// AFTER:  GlassButton.iconOnly(icon: Icons.pause, onPressed: togglePlayPause)
```

### Pattern 2: InkWell-Only Interaction (D-06/D-07)

**What:** Replace GlassButton's current GestureDetector + MouseRegion + AnimatedBuilder + scale animation with Material + InkWell. InkWell provides hover and press feedback natively without custom animation code.

**When to use:** All button modes (icon-only and labeled).

**Why:** User feedback explicitly states "no animation effects, keep InkWell hover/press feedback only." The current implementation uses `Tokens.hoverScale=1.02` and `Tokens.pressScale=0.98` scale transforms -- these must be removed.

**Example (current vs target):**
```dart
// CURRENT (glass_container.dart GlassButton._GlassButtonState):
GestureDetector(
  onTapDown: (_) => _pressed.value = true,
  child: MouseRegion(
    onEnter: (_) => _hovered.value = true,
    child: AnimatedBuilder(
      animation: _interaction, // Listenable.merge([_hovered, _pressed])
      builder: (context, child) {
        final scale = _pressed.value ? Tokens.pressScale : (_hovered.value ? Tokens.hoverScale : 1.0);
        return AnimatedContainer(
          transform: Matrix4.diagonal3Values(scale, scale, 1),
          child: child,
        );
      },
      child: content,
    ),
  ),
)

// TARGET (InkWell-based, no animation):
Material(
  color: Colors.transparent,
  borderRadius: _radius,
  child: InkWell(
    onTap: onPressed,
    hoverColor: Tokens.bgHover,
    highlightColor: Colors.transparent,
    borderRadius: _radius,
    splashFactory: NoSplash.splashFactory,
    child: content,
  ),
)
```

### Pattern 3: Conditional BackdropFilter Skip (D-13)

**What:** Skip BackdropFilter GPU readback when the widget is invisible (opacity < 0.01) or blur is disabled.

**When to use:** ControlBar already implements this pattern (control_bar.dart lines 123-135). Apply same pattern to GlassContainer.

**Example (existing pattern in ControlBar):**
```dart
// Source: lib/ui/player/control_bar.dart lines 123-135
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

### Anti-Patterns to Avoid

- **Scale animation on buttons:** D-06 explicitly forbids scale transforms. Use InkWell hover/press only.
- **Adding BackdropFilter to icon-only buttons:** GlassIconButton currently has no blur. Adding it would be a performance regression for 15+ control bar buttons.
- **Premature state object abstraction (D-09):** ControlsOverlay's 16+ callback parameters are stable references. Wrapping them in an immutable state object adds complexity without reducing rebuilds.
- **Deprecation shim for GlassIconButton (D-02):** Full migration in one pass. No backward-compat layer.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Merging 2 ValueNotifiers | Custom Listenable wrapper | `MergedListenable` (already exists) | Already used in TimeRangeDisplay, handles dispose correctly |
| Dual-notifier ValueListenableBuilder | Nested ValueListenableBuilder | `ValueListenableBuilder2` (already exists) | Already used in VolumeButton and ErrorBanner |
| Barrel file generation | build_runner / codegen | Manual barrel file | 4 exports, trivial to maintain |
| Hover/press interaction | GestureDetector + MouseRegion + AnimatedBuilder + ValueNotifier<bool> | Material + InkWell | D-06/D-07: InkWell handles all interaction states internally |

**Key insight:** The codebase already has the reusable utilities (MergedListenable, ValueListenableBuilder2). The main work is consolidating GlassButton/GlassIconButton and cleaning up the interaction pattern.

## Common Pitfalls

### Pitfall 1: GlassIconButton/GlassButton Rendering Model Mismatch
**What goes wrong:** Treating the merge as a simple API rename. GlassIconButton (36x36 Material, no blur) and GlassButton (GlassContainer with BackdropFilter) have fundamentally different rendering.
**Why it happens:** Both are "glass buttons" so they look like they should merge trivially.
**How to avoid:** The merged GlassButton.iconOnly must use the lightweight Material + InkWell pattern (no GlassContainer/BackdropFilter). Only the labeled mode uses GlassContainer.
**Warning signs:** If icon-only buttons suddenly get BackdropFilter blur, performance will degrade.

### Pitfall 2: Removing Scale Animation Breaks Visual Feedback
**What goes wrong:** Removing AnimatedBuilder + scale transform leaves buttons with no visual feedback.
**Why it happens:** The old code used scale (1.02/0.98) for hover/press. Removing it without replacing with InkWell feedback creates dead buttons.
**How to replace:** InkWell's `hoverColor: Tokens.bgHover` and `highlightColor: Colors.transparent` with `splashFactory: NoSplash.splashFactory` provide subtle feedback without scale animation. This matches the existing GlassIconButton pattern.
**Warning signs:** Buttons feel unresponsive or have no hover state.

### Pitfall 3: Barrel File Import Cycles
**What goes wrong:** glass_widgets.dart imports glass_container.dart which imports tokens.dart, creating circular dependencies if other shared files import glass_widgets.dart.
**Why it happens:** Barrel files re-export, which can create implicit cycles.
**How to avoid:** glass_widgets.dart only re-exports (no logic). Ensure no exported file imports glass_widgets.dart.
**Warning signs:** `dart analyze` reports import cycle errors.

### Pitfall 4: ValueListenableBuilder Audit -- False Positives
**What goes wrong:** Adding `child` caching to builders that actually need to rebuild on every value change.
**Why it happens:** Mechanical audit without checking if the builder's output depends on the value.
**How to avoid:** Only cache `child` when the subtree is truly static (doesn't use the notifier value). Example: VolumeSlider's Slider widget depends on volume -- cannot cache. But the surrounding SizedBox(100) could be cached.
**Warning signs:** Stale UI after value changes.

### Pitfall 5: GlassTier Reduction Breaking Visual Hierarchy
**What goes wrong:** Merging thin (8 sigma) and normal (10 sigma) into a single tier makes title bar and control bar look identical.
**Why it happens:** The 2 sigma difference seems negligible in code but may be visible on high-DPI displays.
**How to avoid:** Test on actual display before committing to reduction. If merging, use 10 sigma (the higher value) to avoid losing blur intensity.
**Warning signs:** Title bar and control bar blur levels look identical.

## Code Examples

### Current GlassIconButton API (to be replaced)
```dart
// Source: lib/ui/shared/glass_icon_button.dart
class GlassIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final double iconSize;
  final Color? color;
  final VoidCallback? onPressed;
  final void Function(TapUpDetails details)? onSecondaryTapUp;
  final String? tooltip;

  const GlassIconButton({
    this.icon, this.child, this.iconSize = Tokens.iconLg,
    this.color = Tokens.textPrimary, this.onPressed,
    this.onSecondaryTapUp, this.tooltip,
  }) : assert(icon != null || child != null);
}
```

### Current GlassButton API (to be refactored)
```dart
// Source: lib/ui/shared/glass_container.dart lines 69-203
class GlassButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool isPrimary;
  final bool enabled;
  final VoidCallback onPressed;

  const GlassButton({required this.icon, this.label, this.tooltip,
    this.isPrimary = false, this.enabled = true, required this.onPressed});

  const GlassButton.iconOnly({required this.icon, this.tooltip,
    this.isPrimary = false, this.enabled = true, required this.onPressed})
    : label = null;
}
```

### Target GlassButton API (after merge)
```dart
// Merged GlassButton -- icon-only mode is lightweight (no BackdropFilter)
class GlassButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool isPrimary;
  final bool enabled;
  final VoidCallback? onPressed;
  final void Function(TapUpDetails details)? onSecondaryTapUp; // from GlassIconButton
  final double iconSize; // from GlassIconButton (default: Tokens.iconLg)
  final Color? color; // from GlassIconButton (default: Tokens.textPrimary)

  const GlassButton({required this.icon, this.label, this.tooltip,
    this.isPrimary = false, this.enabled = true, required this.onPressed,
    this.onSecondaryTapUp, this.iconSize = Tokens.iconLg, this.color});

  const GlassButton.iconOnly({required this.icon, this.tooltip,
    this.isPrimary = false, this.enabled = true, required this.onPressed,
    this.onSecondaryTapUp, this.iconSize = Tokens.iconLg, this.color})
    : label = null;
}
```

### Migration Example (control_bar.dart)
```dart
// BEFORE (6 GlassIconButton calls):
GlassIconButton(icon: Icons.folder_open, onPressed: onOpenFile, tooltip: l10n.openFileTooltip)
GlassIconButton(icon: Icons.subtitles, onPressed: onOpenSubtitle, tooltip: l10n.openSubtitle)
GlassIconButton(icon: Icons.queue_music, onPressed: onTogglePlaylist, tooltip: l10n.playlist)
GlassIconButton(icon: Icons.settings, onPressed: onSettings, onSecondaryTapUp: ..., tooltip: l10n.settings)
GlassIconButton(icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, onPressed: onToggleFullscreen, tooltip: ...)

// AFTER (same calls, new widget name + import):
GlassButton.iconOnly(icon: Icons.folder_open, onPressed: onOpenFile, tooltip: l10n.openFileTooltip)
GlassButton.iconOnly(icon: Icons.subtitles, onPressed: onOpenSubtitle, tooltip: l10n.openSubtitle)
GlassButton.iconOnly(icon: Icons.queue_music, onPressed: onTogglePlaylist, tooltip: l10n.playlist)
GlassButton.iconOnly(icon: Icons.settings, onPressed: onSettings, onSecondaryTapUp: ..., tooltip: l10n.settings)
GlassButton.iconOnly(icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, onPressed: onToggleFullscreen, tooltip: ...)

// Import change:
// BEFORE: import '../shared/glass_icon_button.dart';
// AFTER:  import '../shared/glass_widgets.dart';
```

### ValueListenableBuilder Child Caching Pattern
```dart
// Source: lib/ui/player/controls_overlay.dart lines 136-141
// GOOD -- child is static (IgnorePointer doesn't depend on isVisible)
ValueListenableBuilder<bool>(
  valueListenable: _autoHide.visible,
  builder: (_, isVisible, child) =>
      IgnorePointer(ignoring: !isVisible, child: child),
  child: RepaintBoundary(child: Stack(children: [...])), // cached!
)

// GOOD -- PlayerScreen caches videoContent (lines 153-191)
ValueListenableBuilder<bool>(
  valueListenable: _playlistVisible,
  builder: (context, playlistVisible, videoContent) => Stack(children: [
    videoContent!, // cached static subtree
    ...
  ]),
  child: videoContent,
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GlassIconButton as separate widget | GlassButton.iconOnly constructor | Phase 2 | Single unified API, ~15 call sites migrated |
| GestureDetector + MouseRegion + scale animation | Material + InkWell | Phase 2 (D-06) | Simpler code, no animation, InkWell hover/press feedback |
| Individual file imports | glass_widgets.dart barrel file | Phase 2 (D-03) | Single import for all glass components |

**Deprecated/outdated:**
- `GlassIconButton` class: replaced by `GlassButton.iconOnly` constructor
- Scale animation (`Tokens.hoverScale`/`Tokens.pressScale`): no longer used in buttons (InkWell only)
- `_hovered`/`_pressed` ValueNotifiers in GlassButton: removed (InkWell handles internally)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GlassChip has no external importers (only used internally in playlist_panel.dart's _TabChip) | Migration scope | If imported elsewhere, those sites need barrel file migration too |
| A2 | `Tokens.hoverScale` and `Tokens.pressScale` are only used by GlassButton | Cleanup scope | If other widgets use them, they remain needed |
| A3 | 30% rebuild reduction is achievable via child caching + removing unnecessary ValueListenableBuilder wrappers | Success criteria | Actual reduction depends on runtime profiling; D-12 accepts qualitative estimation |

## Open Questions

1. **GlassButton icon-only rendering: Material or GlassContainer?**
   - What we know: Current GlassIconButton uses Material (no blur). Current GlassButton uses GlassContainer (with blur).
   - What's unclear: Should the merged icon-only mode add BackdropFilter blur or stay lightweight?
   - Recommendation: Stay lightweight (Material + InkWell). The 15 control bar call sites currently have no blur. Adding blur would be a visual change and performance cost. If the user wants glass blur on icon buttons, that's a separate decision.

2. **GlassTier reduction (D-15): merge thin+normal?**
   - What we know: thin=8 sigma (title bar drag hint), normal=10 sigma (GlassContainer default), thick=24 sigma (playlist panel). The thin/normal gap is 2 sigma.
   - What's unclear: Whether 2 sigma is visually noticeable on the target 4K display.
   - Recommendation: Keep 3 tiers for now. The cost of maintaining one extra enum value is negligible. If testing shows thin/normal are indistinguishable, merge to 2 tiers.

3. **Degradation mode trigger (D-14): settings toggle vs auto-detect?**
   - What we know: Low-end hardware may struggle with BackdropFilter. A no-blur fallback is needed.
   - What's unclear: Whether to use a manual settings toggle or automatic detection.
   - Recommendation: Manual toggle in SettingsStore. Auto-detection is unreliable across platforms. Add a `blurEnabled` bool to SettingsStore, check it in GlassContainer.build().

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All widgets | Yes | D:\flutter\bin\flutter | — |
| dart format | Code formatting | Yes | SDK bundled | — |
| flutter test | Widget tests | Yes | SDK bundled | — |
| flutter analyze | Static analysis | Yes | SDK bundled | — |

**Missing dependencies with no fallback:**
- None -- all dependencies are Flutter SDK built-in.

**Missing dependencies with fallback:**
- None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK bundled) |
| Config file | pubspec.yaml (dev_dependencies: flutter_test) |
| Quick run command | `flutter test test/widget/player/` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WIDGET-01 | GlassButton renders icon-only mode | widget | `flutter test test/widget/shared/glass_button_test.dart` | Wave 0 |
| WIDGET-01 | GlassButton renders label mode | widget | `flutter test test/widget/shared/glass_button_test.dart` | Wave 0 |
| WIDGET-01 | GlassButton icon-only tap fires onPressed | widget | `flutter test test/widget/shared/glass_button_test.dart` | Wave 0 |
| WIDGET-01 | GlassButton label mode tap fires onPressed | widget | `flutter test test/widget/shared/glass_button_test.dart` | Wave 0 |
| WIDGET-01 | glass_widgets.dart exports all 4 types | unit | `dart analyze lib/ui/shared/glass_widgets.dart` | Yes (analyze) |
| WIDGET-01 | All GlassIconButton imports replaced | unit | `grep -r "glass_icon_button" lib/` returns 0 | Yes (grep) |
| WIDGET-02 | ValueListenableBuilder instances have child where static | manual | Code review audit | N/A |
| WIDGET-02 | ControlBar rebuild count reduced | manual | DevTools (D-12: qualitative) | N/A |

### Sampling Rate
- **Per task commit:** `flutter test test/widget/shared/` (glass button tests)
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green + `flutter analyze` clean before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/widget/shared/glass_button_test.dart` -- covers WIDGET-01 (icon-only + label modes, tap behavior)
- [ ] Verify existing tests still pass after GlassButton refactor (control_bar_test.dart, volume_controls_test.dart, controls_overlay_test.dart)

## Security Domain

This phase involves no security-sensitive changes. All modifications are UI widget consolidation and rebuild optimization. No authentication, input validation, cryptography, or data handling changes.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | No | — |
| V6 Cryptography | No | — |

## Sources

### Primary (HIGH confidence)
- `lib/ui/shared/glass_container.dart` -- GlassContainer + GlassTier + GlassButton implementation (direct codebase read)
- `lib/ui/shared/glass_icon_button.dart` -- GlassIconButton implementation (direct codebase read)
- `lib/ui/shared/glass_chip.dart` -- GlassChip implementation (direct codebase read)
- `lib/ui/player/control_bar.dart` -- Primary GlassIconButton consumer (direct codebase read)
- `lib/ui/player/center_controls.dart` -- 7 GlassIconButton calls (direct codebase read)
- `lib/ui/player/volume_controls.dart` -- VolumeButton + VolumeSlider (direct codebase read)
- `lib/ui/player/controls_overlay.dart` -- AutoHideController + ValueListenableBuilder usage (direct codebase read)
- `lib/ui/player/progress_bar.dart` -- MergedListenable usage + ValueListenableBuilder (direct codebase read)
- `lib/ui/shared/merged_listenable.dart` -- Existing merger utility (direct codebase read)
- `lib/ui/shared/value_listenable_builder2.dart` -- Existing dual-notifier builder (direct codebase read)
- `lib/ui/theme/tokens.dart` -- Design tokens including glassBlur values (direct codebase read)
- `.planning/phases/02-widget-unification/02-CONTEXT.md` -- User decisions (direct file read)

### Secondary (MEDIUM confidence)
- Flutter SDK InkWell documentation -- confirmed via training knowledge + codebase pattern match

### Tertiary (LOW confidence)
- GlassTier thin/normal visual indistinguishability -- needs actual display testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all Flutter SDK built-in
- Architecture: HIGH -- patterns verified by reading all relevant source files
- Pitfalls: HIGH -- derived from actual code analysis of GlassButton vs GlassIconButton rendering models

**Research date:** 2026-05-28
**Valid until:** 2026-06-28 (stable -- Flutter SDK widgets don't change frequently)
