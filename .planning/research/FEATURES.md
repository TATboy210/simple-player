# Feature Landscape: Control Bar Visual Coordination & Glass Morphism Optimization

**Domain:** Desktop media player control bar visual design
**Researched:** 2026-07-02
**Milestone:** v1.3
**Current state:** Glass morphism control bar exists (BackdropFilter + Tokens), but colors clash with background especially in empty state

## Table Stakes

Features users expect from any competent media player control bar. Missing = product feels unfinished.

| Feature | Why Expected | Complexity | Current Status | Notes |
|---------|--------------|------------|----------------|-------|
| **Semi-transparent control bar** | Every modern player does this — solid bars feel dated | Low | Done | `controlBarBg = #72080A10` at 45% opacity via Tokens |
| **Auto-hide on idle** | Standard since VLC 1.0 — controls should not permanently obscure video | Low | Done | `AutoHideController` with 5s windowed / 3s fullscreen delay |
| **Gradient transition zone** | YouTube, Netflix, IINA, VLC all use a bottom gradient to smoothly blend video into controls | Medium | **MISSING** | Current implementation has hard edge between video surface and control bar |
| **Consistent dark palette** | Control bar colors must harmonize with the deep background (`bgBase` = `#0C0F18`) | Low | Partial | `controlBarBg` matches but `glassBorder` (blue tint) may clash with warm content |
| **Empty state visual distinction** | When no video is playing, the control bar should look different (lighter, more融入) | Low | **MISSING** | Current idle state only dims buttons (20% opacity), background unchanged |
| **Backdrop blur** | Glass morphism requires blur to feel premium, not just transparency | Low | Done | `BackdropFilter` with `glassBlurThick` (18 sigma) |

## Differentiators

Features that set the product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Adaptive gradient intensity** | Gradient opacity adjusts based on video brightness (bright video = stronger gradient for readability) | High | YouTube does this via CSS custom properties; requires frame color sampling |
| **Control bar background color tinting** | Subtle blue tint from video color palette applied to control bar border/glow | High | Netflix does this; requires dominant color extraction from video frames |
| **Empty state glassmorphism** | When idle, control bar uses lighter blur + lower opacity to feel "open" and inviting | Low | mpv OSC uses `floatingalpha=105` for floating layout vs `boxalpha=80` for default |
| **Smooth gradient on hover** | Control bar gradient fades in more prominently on mouse movement, fades out when idle | Medium | YouTube/Netflix pattern; enhances focus on controls when needed |
| **Progress bar glow animation** | Subtle pulsing glow on progress bar thumb during playback | Low | Visual polish; mpv `seekbarstyle` options show this is customizable |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Dynamic color extraction from video frames** | Requires constant frame sampling, high GPU/CPU cost, complex algorithm (Median Cut / K-Means), and the result is often distracting | Use fixed dark palette with gradient overlay — proven by YouTube/Netflix/mpv |
| **Per-button background blur** | Each button with its own BackdropFilter = N separate GPU readbacks, massive performance hit on integrated graphics | Keep current approach: single BackdropFilter for entire control bar background |
| **Animated color transitions on control bar** | Color shifting on every frame is visually distracting and wastes GPU cycles on gradient recomputation | Use static colors with opacity transitions only |
| **Multiple theme presets** | Adds UI complexity, testing burden, and maintenance cost for marginal user benefit | Keep single Midnight theme, focus on making it perfect |
| **Control bar position customization** | mpv supports top/bottom/floating, but this adds layout complexity for a feature <1% of users configure | Fixed bottom position with margin, as currently implemented |

## Feature Dependencies

```
Gradient transition zone
  └── requires Tokens update (new gradient tokens)

Empty state background adaptation
  └── requires Tokens update (idle-specific colors)
  └── requires ControlBar modification (isIdle check for background)

Border color coordination
  └── requires Tokens update (neutral border colors)

Adaptive gradient intensity
  └── requires frame color sampling (Phase 2+, not v1.3)

Control bar background tinting
  └── requires dominant color extraction (Phase 2+, not v1.3)

Progress bar glow animation
  └── independent, can be added anytime
```

## Competitor Analysis: Control Bar Design

### mpv (Lua OSC)
- **Background**: `boxalpha=80` (0=opaque, 255=transparent), so ~69% opaque black
- **Colors**: Configurable hex (default white icons on black background)
- **Auto-hide**: `hidetimeout=500ms`, `fadeduration=200ms`
- **Layouts**: box, slimbox, bottombar, topbar, floating (each with different alpha)
- **Key insight**: mpv uses **no blur** — just alpha compositing. The "glass" feel comes from video showing through the alpha.
- **Source**: `https://raw.githubusercontent.com/mpv-player/mpv/master/player/lua/osc.lua`

### IINA (macOS native)
- **Background**: `NSVisualEffectView` with macOS vibrancy material
- **Colors**: Adapts to system appearance (dark/light), window `backgroundColor` = black in dark mode
- **Key insight**: IINA delegates glass morphism to the OS. Flutter must implement it manually (which this project already does via BackdropFilter).
- **Source**: `https://github.com/iina/iina` (PlayerWindowController.swift)

### YouTube / Netflix (Web)
- **Background**: Semi-transparent black gradient (`rgba(0,0,0,0.7)` at bottom to transparent at top)
- **Gradient height**: ~15-20% of player height
- **Auto-hide**: 3-5 seconds idle, smooth fade
- **Key insight**: The gradient is the most important element — it creates a smooth visual transition from video content to control bar.

### VLC (Qt)
- **Background**: Dark translucent overlay, solid dark theme
- **Auto-hide**: Configurable timeout
- **Key insight**: VLC prioritizes function over form — controls are clearly visible but not beautiful.

## Current Implementation Gaps

### Gap 1: No Gradient Transition Zone (HIGH PRIORITY)

**Current behavior**: Hard edge between video surface and control bar. The control bar starts abruptly at `controlBarMarginBottom` (16px from bottom).

**Competitor pattern**: All major players use a bottom gradient that starts ~15-20% above the control bar and fades from transparent to the control bar background color.

**Impact**: Controls feel "pasted on" rather than "emerging from" the video. This is the single biggest visual quality issue.

**Fix**: Add a gradient overlay `Positioned` widget above the control bar in `ControlsOverlay`:
```dart
Positioned(
  left: Tokens.controlBarMarginH,
  right: Tokens.controlBarMarginH,
  bottom: Tokens.controlBarMarginBottom + Tokens.controlBarHeight,
  height: 80, // gradient height
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Tokens.controlBarBg],
      ),
    ),
  ),
)
```

### Gap 2: No Empty State Background Adaptation (MEDIUM PRIORITY)

**Current behavior**: Control bar background (`controlBarBg = #72080A10` at 45% opacity) is identical whether video is playing or not. In empty state, the dark control bar clashes with the lighter Aurora background.

**Competitor pattern**: mpv uses different alpha values for different layouts. When idle, controls should feel lighter/more open.

**Impact**: Visual clash between dark control bar and lighter empty state background.

**Fix**: In `ControlBar`, use `isIdle` to select background variant:
```dart
final bg = isIdle ? Tokens.controlBarBgIdle : Tokens.controlBarBg;
// Where controlBarBgIdle = Color(0x40080A10) // 25% opacity instead of 45%
```

### Gap 3: Border Color Coordination (LOW PRIORITY)

**Current behavior**: Control bar uses `glassBorder = rgba(100,130,255,0.08)` (blue tint) and `controlBarBorderWhite = rgba(255,255,255,0.04)`.

**Issue**: The blue-tinted border may clash with certain video color palettes, especially warm-toned content.

**Competitor pattern**: mpv uses pure white/black borders that adapt to the alpha compositing context.

**Fix**: Add idle-specific border token or use neutral border color that works with both dark video and light empty state.

## MVP Recommendation

Prioritize for v1.3:
1. **Gradient transition zone** — Add a bottom gradient overlay above the control bar. This single change will have the biggest visual impact. Use a `LinearGradient` from `Colors.transparent` to `Tokens.controlBarBg` covering ~80-100px above the control bar.
2. **Empty state background adaptation** — When `MediaState.idle`, reduce control bar background opacity (e.g., from 45% to 25%) and soften border glow. This makes the control bar feel lighter and more融入 the Aurora background.
3. **Border color coordination** — Adjust `glassBorder` and `controlBarBorderWhite` to use neutral tones that work with both dark video and light empty state.

Defer to later phases:
- Adaptive gradient intensity (requires frame color sampling — complex, Phase 2+)
- Control bar background tinting (requires dominant color extraction — Phase 2+)
- Progress bar glow animation (polish, not critical for visual coordination)

## Token Updates Needed

```dart
// New tokens for gradient and idle state
static const controlBarGradientTop = Color(0x00000000); // transparent
static const controlBarGradientHeight = 80.0;
static const controlBarBgIdle = Color(0x40080A10); // 25% opacity for empty state
static const glassBorderIdle = Color(0x0A6482FF); // softer border for idle
```

## Files to Modify

| File | Change | Priority |
|------|--------|----------|
| `lib/ui/theme/tokens.dart` | Add new tokens for gradient, idle state | P0 |
| `lib/ui/player/controls_overlay.dart` | Add gradient overlay Positioned widget | P0 |
| `lib/ui/player/control_bar.dart` | Use isIdle to select background variant | P1 |
| `lib/ui/shared/glass_container.dart` | No changes needed (already supports opacity) | — |

## Sources

- mpv Lua OSC source: `https://raw.githubusercontent.com/mpv-player/mpv/master/player/lua/osc.lua` (boxalpha, hidetimeout, layout options)
- IINA GitHub: `https://github.com/iina/iina` (NSVisualEffectView vibrancy, theme material system)
- YouTube/Netflix control bar patterns: gradient overlay CSS `linear-gradient(transparent, rgba(0,0,0,0.8))`
- Current project: `lib/ui/player/control_bar.dart`, `lib/ui/theme/tokens.dart`, `lib/ui/shared/glass_container.dart`
