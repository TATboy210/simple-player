# Technology Stack

**Project:** Simple Player Flutter - Glass Morphism Color Coordination
**Researched:** 2026-07-02
**Confidence:** HIGH

## Problem Analysis

The control bar uses a hardcoded dark overlay (`Tokens.controlBarBg = 0x72080A10`) that clashes with the background in two states:

1. **Empty state (no video):** Background is `Tokens.bgBase` (#0C0F18) - very dark, almost black. The 45% dark overlay creates a disconnected, floating panel effect.

2. **With video:** Background is the video frame itself. The static overlay works but doesn't adapt to bright/dark video content.

## Recommended Stack

### Core Flutter APIs (No Dependencies)

| API | Version | Purpose | Why |
|-----|---------|---------|-----|
| `ImageFilter.compose` | Flutter 3.13+ | Chain blur + color filter | Single BackdropFilter pass: blur AND tint simultaneously |
| `ColorFilter.mode` | Flutter SDK | Apply color tinting | Modulate glass overlay color based on state |
| `BlendMode.overlay` | Flutter SDK | Natural color blending | Subtle tinting that preserves background contrast |
| `BlendMode.softLight` | Flutter SDK | Gentle color influence | Less harsh than overlay for dark backgrounds |
| `Color.withValues(alpha:)` | Flutter 3.27+ | Dynamic opacity | Adjust glass transparency for idle vs playing |

### Design Token Extensions

| Token | Value | Purpose | Integration Point |
|-------|-------|---------|-------------------|
| `controlBarBgIdle` | `Color(0x4D0C0F18)` | Empty state: 30% of bgBase | `control_bar.dart` -> `_decoration` |
| `controlBarBgPlaying` | `Color(0x72080A10)` | Video state: current 45% | `control_bar.dart` -> `_decoration` |
| `controlBarTintIdle` | `Color(0x1A0C0F18)` | Subtle dark tint for idle | `ImageFilter.compose` -> `ColorFilter.mode` |
| `controlBarTintPlaying` | `Colors.transparent` | No tint during playback | `ImageFilter.compose` -> `ColorFilter.mode` |
| `controlBarBlurIdle` | `12.0` | Lighter blur for empty state | `GlassContainer` -> `GlassTier` |
| `controlBarBlurPlaying` | `18.0` | Current blur for video | `GlassContainer` -> `GlassTier` |

### Why This Stack

**Flutter-only approach (no packages):**

1. **`ImageFilter.compose`** exists since Flutter 3.13 (stable 2+ years). It chains `ImageFilter.blur()` + `ImageFilter.colorFilter()` in a single GPU pass. No performance penalty vs current implementation.

2. **State-aware tokens** avoid runtime color extraction complexity. The player already knows `engine.state` (idle/playing/paused). Use this to select the right token set at build time.

3. **`BlendMode.overlay` / `BlendMode.softLight`** are hardware-accelerated in Skia/Impeller. They produce natural tinting that adapts to the underlying content without manual color calculation.

### What NOT to Add

| Anti-Package | Why Not |
|--------------|---------|
| `palette_generator` | Extracts colors from images - overkill for 2 states (idle/playing) |
| `flutter_color_extractor` | Runtime video frame sampling is expensive and unnecessary |
| `dynamic_color` | Material You integration - wrong domain for media player |
| Custom `Shader` / `FragmentShader` | Impeller migration pending; avoid fragment shaders until then |
| `ColorFiltered` widget | Only affects child, not backdrop - wrong widget for glass effect |

## Implementation Pattern

### State-Aware Glass Filter

```dart
// In control_bar.dart - replace static _blurFilter
ImageFilter _buildGlassFilter(MediaState state) {
  final isIdle = state == MediaState.idle;
  final sigma = isIdle ? Tokens.controlBarBlurIdle : Tokens.controlBarBlurPlaying;
  
  return ImageFilter.compose(
    inner: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    outer: ColorFilter.mode(
      isIdle ? Tokens.controlBarTintIdle : Tokens.controlBarTintPlaying,
      BlendMode.softLight,
    ),
  );
}
```

### State-Aware Decoration

```dart
// In control_bar.dart - replace static _decoration
BoxDecoration _buildDecoration(MediaState state) {
  final isIdle = state == MediaState.idle;
  final bgColor = isIdle ? Tokens.controlBarBgIdle : Tokens.controlBarBgPlaying;
  
  return BoxDecoration(
    color: bgColor,
    borderRadius: _borderRadius,
    border: Border.all(color: Tokens.glassBorder, width: 1),
    boxShadow: [ /* existing shadows */ ],
  );
}
```

### GlassContainer Extension (Optional)

For reuse across playlist panel and other glass surfaces:

```dart
// In glass_container.dart
class GlassContainer extends StatelessWidget {
  // Add optional tint parameter
  final Color? tint;
  final BlendMode tintBlendMode;
  
  // Default: no tint (backward compatible)
  const GlassContainer({
    // ... existing params
    this.tint,
    this.tintBlendMode = BlendMode.softLight,
  });
}
```

## Integration Points

### Files to Modify

| File | Change | Risk |
|------|--------|------|
| `lib/ui/theme/tokens.dart` | Add 6 new tokens | LOW - additive only |
| `lib/ui/player/control_bar.dart` | State-aware `_buildGlassFilter()` + `_buildDecoration()` | MEDIUM - core visual change |
| `lib/ui/shared/glass_container.dart` | Optional `tint` parameter | LOW - backward compatible |

### Files NOT to Modify

| File | Reason |
|------|--------|
| `glass_widgets.dart` | Just barrel export, no logic |
| `edge_glow.dart` | Decorative glow, unrelated to glass tinting |
| `controls_overlay.dart` | Container only, passes through to ControlBar |
| `video_surface.dart` | Texture rendering, no glass involvement |

## Performance Considerations

| Concern | Impact | Mitigation |
|---------|--------|------------|
| `ImageFilter.compose` GPU cost | Negligible - single pass | Existing `opacity < 0.01` skip (D-13) still works |
| State change frequency | Low - idle/playing transitions are rare | No debouncing needed |
| Token lookup | Compile-time constant | Zero runtime cost |

## Migration Path

1. **Phase 1:** Add new tokens to `tokens.dart` (backward compatible)
2. **Phase 2:** Update `control_bar.dart` to use state-aware filter/decoration
3. **Phase 3 (optional):** Extend `GlassContainer` with tint parameter for playlist panel

## Sources

- Flutter API: `ImageFilter.compose` - https://api.flutter.dev/flutter/dart-ui/ImageFilter/compose.html
- Flutter API: `ColorFilter.mode` - https://api.flutter.dev/flutter/dart-ui/ColorFilter/mode.html
- Flutter API: `BlendMode` - https://api.flutter.dev/flutter/dart-ui/BlendMode.html
- Existing codebase: `lib/ui/theme/tokens.dart`, `lib/ui/player/control_bar.dart`, `lib/ui/shared/glass_container.dart`
