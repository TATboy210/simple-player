# Phase 2: Widget Unification - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Unify the glass component library (GlassContainer/GlassButton/GlassIconButton) into a consistent API with single barrel file export, optimize ValueNotifier rebuild patterns across all UI components, and apply glass performance optimizations. No new capabilities — only consolidation and optimization of existing widgets.

</domain>

<decisions>
## Implementation Decisions

### Glass Component API
- **D-01:** Merge GlassIconButton into GlassButton — unified component with `icon` (label) and `iconOnly` constructors
- **D-02:** Full migration + delete GlassIconButton file — all ~20 call sites updated in one pass, no deprecation shim
- **D-03:** Create `glass_widgets.dart` barrel file — exports GlassContainer, GlassButton, GlassChip, GlassTier
- **D-04:** GlassChip stays independent — selector semantics differ from button action semantics
- **D-05:** GlassContainer API unchanged — 6 optional parameters (child required), flexible and sufficient

### Interaction Pattern
- **D-06:** All modes use InkWell (no scale animation) — aligns with user feedback: "按钮不要动画效果，保留 InkWell hover/press 反馈即可"
- **D-07:** No hover/press animation mixin needed — InkWell handles hover/press state internally

### ControlsOverlay State
- **D-08:** ControlBar parameter list unchanged — 16+ params are stable callback references, no extra rebuild cost
- **D-09:** No immutable state object or Record wrapping — premature abstraction for stable props

### ValueNotifier Rebuild Audit
- **D-10:** Audit scope: all `ui/` directory (not just player/)
- **D-11:** Audit all 4 dimensions: child caching, notifier merging, rebuild baseline, unnecessary listeners
- **D-12:** 30% rebuild reduction target validated via qualitative judgment + code analysis estimation (not DevTools profiling)

### Glass Performance
- **D-13:** Conditional BackdropFilter skip — skip blur when opacity=0 or widget not visible
- **D-14:** Degradation mode — no-blur fallback for low-end hardware (settings toggle or auto-detect)
- **D-15:** GlassTier layer evaluation — assess if 3 tiers (thin/normal/thick) can be reduced to 2

### Glass Testing
- **D-16:** Core widget tests for merged GlassButton — cover both icon-only and label modes (render + tap behavior)
- **D-17:** No golden tests in Phase 2 — deferred to Phase 4

### Claude's Discretion
- GlassButton internal implementation details (how to merge InkWell patterns)
- Barrel file exact export list ordering
- Which ValueListenableBuilder instances need child caching (audit-driven)
- GlassTier evaluation outcome (data-driven decision)
- Degradation mode trigger mechanism (setting vs auto-detect)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Patterns
- `.planning/codebase/ARCHITECTURE.md` — 3-layer architecture, state management patterns, ValueNotifier usage
- `.planning/codebase/CONVENTIONS.md` — Glass component patterns, widget caching, error handling
- `.planning/codebase/STRUCTURE.md` — 94 Dart files, directory tree, file locations

### Prior Phase Context
- `.planning/phases/01-window-management/01-CONTEXT.md` — Phase 1 decisions (ValueNotifier preserved, Tokens.* usage)

### Existing Glass Components (source of truth for merge)
- `lib/ui/shared/glass_container.dart` — GlassContainer + GlassTier enum + GlassButton + GlassButton.iconOnly
- `lib/ui/shared/glass_icon_button.dart` — GlassIconButton (TO BE MERGED then DELETED)
- `lib/ui/shared/glass_chip.dart` — GlassChip (stays independent)

### Key Call Sites (migration targets)
- `lib/ui/player/control_bar.dart` — primary GlassIconButton user
- `lib/ui/player/volume_controls.dart` — volume buttons
- `lib/ui/player/speed_button.dart` — speed selector
- `lib/ui/playlist/playlist_panel.dart` — playlist controls
- `lib/ui/dialogs/settings_dialog.dart` — settings buttons

### ValueNotifier Audit Targets
- `lib/ui/player/controls_overlay.dart` — AutoHideController + ValueListenableBuilder
- `lib/ui/player/control_bar.dart` — engine state listeners
- `lib/ui/player/progress_bar.dart` — position/duration listeners
- `lib/ui/player/volume_controls.dart` — volume/mute listeners
- `lib/ui/playlist/playlist_panel.dart` — playlist state

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GlassContainer` — ClipRRect + BackdropFilter + RepaintBoundary, 3-tier blur, ready to use as-is
- `GlassTier` enum — thin/normal/thick with sigma values, already in tokens
- `Tokens.*` — all visual constants (colors, spacing, radius, animation) already defined
- `ValueListenableBuilder2` — dual-notifier builder utility, exists in shared/

### Established Patterns
- ValueNotifier + ValueListenableBuilder — no Provider/Riverpod/Bloc
- `_guardedAction` error handling — on Exception catch + debugPrint
- Widget caching pattern — `ControlBar? _cachedBar;` style field caching
- RepaintBoundary wrapping — for expensive widgets (glass, video)

### Integration Points
- `glass_widgets.dart` barrel file → all `lib/ui/` imports change from individual files to barrel
- GlassIconButton call sites (~20) → GlassButton.iconOnly or GlassButton with label
- ValueListenableBuilder instances → add `child` parameter for static subtrees

</code_context>

<specifics>
## Specific Ideas

- User feedback: "按钮不要动画效果，保留 InkWell hover/press 反馈即可" — no scale animations on any button
- Glass performance: 3 optimization directions selected (conditional skip, degradation mode, tier evaluation)
- Barrel file: glass-only scope, no mixing with other shared components

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 2-Widget Unification*
*Context gathered: 2026-05-28*
