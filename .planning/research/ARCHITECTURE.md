# Architecture: Glass Morphism Color Coordination

**Domain:** Flutter desktop media player — control bar visual integration
**Researched:** 2026-07-02
**Overall confidence:** HIGH

## Problem Statement

The control bar uses a static `BoxDecoration` (`_decoration`) with hardcoded `Tokens.controlBarBg` (45% opacity dark tint). In empty state, the BackdropFilter blurs the AuroraBackground (bright blue blobs at 5-8% opacity), producing a washed-out glass effect. In playing state, it blurs a dark video frame, producing the intended deep glass. The control bar needs to adapt its tint/opacity/border based on what lies behind it — without breaking the existing `Tokens.*` compile-time constant contract.

## Current Architecture Analysis

### Data Flow (current)

```
PlayerScreen
  └─ ControlsOverlay (ValueListenableBuilder<MediaState>)
       └─ ControlBar (ValueListenableBuilder<MediaState> — internal)
            ├─ _decoration (static final — hardcoded Tokens.controlBarBg)
            ├─ _blurFilter (static final — Tokens.glassBlurThick)
            └─ GlassContainer (hardcoded Tokens.bgGlass)
```

### Key Constraints

1. **Tokens.* is `static const`** — all values are compile-time constants. Cannot be made dynamic.
2. **ControlBar._decoration is `static final`** — computed once at class load, reused across all builds. Changing per-build would create a new BoxDecoration each frame (GC pressure).
3. **GlassContainer hardcodes `Tokens.bgGlass`** — line 74 of glass_container.dart: `color: Tokens.bgGlass`. No parameter to override.
4. **ControlBar already listens to `engine.state`** — it computes `isIdle` internally (line 91). This is the exact boolean needed for adaptive colors.
5. **EdgeGlow wraps ControlBar** — adds 5-layer box-shadow glow. Glow colors are also static tokens.

### What Needs to Change

| Component | Current | Required Change |
|-----------|---------|-----------------|
| `GlassContainer` | Hardcoded `Tokens.bgGlass` | Accept optional `Color? backgroundColor` |
| `ControlBar._decoration` | `static final` (one value) | Compute per-build from `isIdle` |
| `ControlBar._buildBlur` | No color awareness | Pass adapted bg to backdrop content |
| `Tokens.*` | No adaptive variants | Add idle-state token constants |
| `ControlsOverlay` | No idle pass-down | Already passes engine (ControlBar reads it internally) |

## Recommended Architecture

### Pattern: Adaptive Token Constants + Per-Build Decoration Builder

**Core idea:** Add idle-state variant tokens to `Tokens.*` (still compile-time const), then let `ControlBar` select the right token set based on `isIdle` and build `_decoration` as a non-static method.

This avoids:
- Dynamic `Color.lerp()` at runtime (unnecessary GPU interpolation for a binary state)
- New ValueNotifier for color (over-engineering — `isIdle` is already available)
- Changes to `EngineState` or `PlaybackController` (no data model changes)

### Component Changes

#### 1. Tokens.* — Add Idle-State Variants

Add a small cluster of constants for the empty/idle state. These are still `static const`:

```dart
// ── 控制栏 — 空状态 (idle) ──
static const controlBarBgIdle = Color(0x40080A10);    // 25% opacity (vs 45% normal)
static const controlBarBorderIdle = Color(0x0A6482FF); // 4% blue (vs 12% normal)
static const controlBarShadowIdle = Color(0x00000000);  // no blue glow in idle
static const controlBarOuterShadowIdle = Color(0x1A000000); // 10% black (vs 15%)
static const glassBorderIdle = Color(0x0A6482FF);       // 4% blue (vs 8% normal)
static const glowAccentIdle = Color(0x085082FF);        // 3% blue (vs 6% normal)
```

**Rationale:** Idle state needs a more transparent, less saturated glass. The AuroraBackground blobs are the backdrop, so the glass should recede — lower opacity, subtler borders, no blue glow competing with the aurora.

#### 2. GlassContainer — Optional Background Color

```dart
class GlassContainer extends StatelessWidget {
  // ... existing params ...

  /// Override background color. Defaults to Tokens.bgGlass.
  final Color? backgroundColor;

  const GlassContainer({
    // ... existing ...
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Tokens.bgGlass,  // ← was hardcoded
        borderRadius: rRect,
        border: border ?? Border.all(color: Tokens.borderHighlight, width: 1),
      ),
      // ...
    );
  }
}
```

**Impact:** Zero breaking changes. All existing callers pass no `backgroundColor`, so they get the default. Only `ControlBar` and future adaptive consumers pass the override.

#### 3. ControlBar — Decoration Builder

Replace `static final _decoration` with a method:

```dart
class ControlBar extends StatelessWidget {
  // Keep _borderRadius and _blurFilter as static final (blur doesn't change)

  /// Build decoration based on playback state
  static BoxDecoration _buildDecoration(bool isIdle) {
    if (isIdle) {
      return BoxDecoration(
        color: Tokens.controlBarBgIdle,
        borderRadius: _borderRadius,
        border: Border.all(color: Tokens.glassBorderIdle, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Tokens.controlBarBorderWhite, // keep top highlight
            blurRadius: 0,
            spreadRadius: 0,
            offset: Offset(0, -1),
          ),
          // No blue glow layers in idle
          BoxShadow(
            color: Tokens.controlBarOuterShadowIdle,
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      );
    }
    return _decoration; // existing normal-state decoration
  }
```

Then in `build()`, replace:
```dart
// BEFORE (static)
final background = Container(
  height: Tokens.controlBarHeight,
  decoration: _decoration,
);

// AFTER (dynamic per isIdle)
final background = Container(
  height: Tokens.controlBarHeight,
  decoration: _buildDecoration(isIdle),
);
```

**Performance:** `_buildDecoration` is called once per `ValueListenableBuilder<MediaState>` rebuild. Since `MediaState` changes are infrequent (play/pause/stop), this is negligible. No per-frame cost.

#### 4. EdgeGlow — Optional Glow Intensity

The `EdgeGlow` widget wraps ControlBar with 5-layer box-shadow. For idle state, reduce glow intensity:

```dart
class EdgeGlow extends StatelessWidget {
  final double glowIntensity; // 0.0 = no glow, 1.0 = full (default)

  const EdgeGlow({
    // ...
    this.glowIntensity = 1.0,
  });
```

ControlBar passes `glowIntensity: isIdle ? 0.3 : 1.0` to EdgeGlow.

### Data Flow (proposed)

```
PlayerScreen
  └─ ControlsOverlay (ValueListenableBuilder<MediaState>)
       └─ ControlBar (ValueListenableBuilder<MediaState> — internal)
            ├─ isIdle computed (line 91) ← already exists
            ├─ _buildDecoration(isIdle) → selects token set
            ├─ EdgeGlow(glowIntensity: isIdle ? 0.3 : 1.0)
            └─ GlassContainer(backgroundColor: isIdle ? Tokens.controlBarBgIdle : null)
```

**Key insight:** No new ValueNotifiers, no new state management, no new widgets. The existing `isIdle` boolean inside `ControlBar.build()` drives all adaptive behavior.

### Component Boundaries

| Component | Responsibility | Change Type |
|-----------|---------------|-------------|
| `Tokens.*` | Compile-time color constants | Add 6 idle-variant constants |
| `GlassContainer` | Reusable glass morphism wrapper | Add optional `backgroundColor` param |
| `ControlBar` | Bottom control bar with glass background | Replace static `_decoration` with `_buildDecoration(isIdle)` |
| `EdgeGlow` | Decorative glow wrapper | Add optional `glowIntensity` param |
| `ControlsOverlay` | Auto-hide + gesture layer | No changes needed |

## Anti-Patterns to Avoid

### Anti-Pattern 1: Color.lerp() for Binary State
**What:** Using `Color.lerp(Tokens.controlBarBg, Tokens.controlBarBgIdle, t)` with an animation controller.
**Why bad:** The state is binary (idle vs playing), not continuous. Animation interpolation adds complexity and GPU cost for no visual benefit.
**Instead:** Use a simple ternary: `isIdle ? idleDecoration : normalDecoration`.

### Anti-Pattern 2: New ValueNotifier for Color
**What:** Creating a `ValueNotifier<Color>` that emits different colors based on state.
**Why bad:** `isIdle` is already derived from `engine.state` which is already listened to. Adding a parallel notifier creates synchronization risk and unnecessary rebuilds.
**Instead:** Compute color from the existing `isIdle` boolean in the same `ValueListenableBuilder` callback.

### Anti-Pattern 3: Changing Tokens.* to Be Dynamic
**What:** Making `Tokens.controlBarBg` a non-const variable or using `late` initialization.
**Why bad:** Breaks the compile-time constant contract. Prevents `const` propagation. Violates the design system's "all visual values via Tokens.*" rule.
**Instead:** Add new const variants. The existing tokens remain unchanged. Consumers choose which to use.

## Scalability Considerations

| Concern | At Current Scale | Future Extension |
|---------|-----------------|------------------|
| Idle vs playing | Binary state, 2 token sets | Could extend to `loading`, `paused`, `error` states |
| Blur sigma | Static per tier | Could add `GlassTier.idle` with lower sigma |
| Glow layers | Enable/disable entire glow | Could animate glow intensity on play/pause transition |
| Title bar | Separate component | Could also adapt based on state |

## Implementation Order

1. **Tokens.* — Add idle constants** (5 min, no risk)
2. **GlassContainer — Add `backgroundColor` param** (10 min, backward compatible)
3. **ControlBar — Replace `_decoration` with `_buildDecoration(isIdle)`** (15 min, core change)
4. **EdgeGlow — Add `glowIntensity` param** (10 min, backward compatible)
5. **Visual tuning** (30 min, iterative adjustment of idle token values)

Total estimated: ~70 minutes for implementation, plus tuning time.

## Integration Points

### With Existing ValueNotifier Pattern
- No new ValueNotifiers needed
- `ControlBar` already has `ValueListenableBuilder<MediaState>` with `isIdle` computed
- Adaptive decoration computed in the same builder callback
- Zero impact on `AutoHideController`, `ProgressBar`, `VolumeControls`, `SpeedButton`

### With Tokens.* Design System
- New constants follow existing naming convention: `controlBar*Idle`, `glassBorderIdle`
- All new constants are `static const` — no runtime allocation
- Existing callers of `GlassContainer` are unaffected (optional param defaults to `Tokens.bgGlass`)

### With ControlsOverlay
- No changes needed. `ControlsOverlay` passes `engine` to `ControlBar`, which reads `engine.state` internally.
- The `emptyStatePresent` flag in `ControlsOverlay` is about hit-testing, not visual adaptation.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Architecture pattern | HIGH | Binary state -> select from const sets is well-established |
| Token additions | HIGH | Follows existing naming/structure exactly |
| GlassContainer change | HIGH | Optional param, zero breaking changes |
| ControlBar decoration | HIGH | Existing `isIdle` drives selection, no new state |
| Visual tuning values | MEDIUM | Exact alpha/color values need iterative adjustment |

## Sources

- Codebase analysis: `tokens.dart`, `control_bar.dart`, `glass_container.dart`, `controls_overlay.dart`, `edge_glow.dart`, `empty_state.dart`, `aurora_background.dart`, `engine_state.dart`
- Glass morphism design principles: backdrop-filter + tint + border opacity coordination
- Existing project patterns: Tokens.* compile-time constants, ValueNotifier + ValueListenableBuilder, static final decorations
