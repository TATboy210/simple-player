# ADR-005: Design System via Tokens.* Static Constants

## Status

**Adopted** (established during UI refactoring, formalized in design system analysis, maintained through all phases)

## Context

A media player with a glass-morphism visual language needs a consistent design system that:

1. Ensures visual consistency across 20+ UI components (title bar, control bar, progress bar, volume slider, playlist panel, OSD, dialogs, etc.).
2. Enables theme changes (accent color: Midnight/Ocean/Forest) without hunting for hardcoded values.
3. Provides a single source of truth for colors, spacing, typography, animation durations, and component dimensions.
4. Works at compile-time (no runtime theme resolution overhead for a desktop app where theme changes are rare).
5. Supports the glass-morphism pattern (BackdropFilter + translucent backgrounds + border highlights).

### Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **Tokens.* static constants** | Compile-time const, zero runtime cost, IDE autocomplete, single source of truth | Manual updates for theme changes (3 accent options), no runtime theme switching | **CHOSEN** |
| Flutter ThemeData | Built-in, supports Material 3, runtime switching | Limited to Material design tokens, cannot express glass-morphism, no custom blur/opacity/glow values | REJECTED — insufficient for glass-morphism |
| CSS-like design tokens (JSON/YAML + codegen) | Industry standard, tooling support | Adds codegen step, runtime resolution, not idiomatic for Flutter | REJECTED — overkill for a single-theme desktop app |
| freezed/theme classes | Immutable, copyWith for theme variants | Codegen dependency, runtime resolution cost | REJECTED — compile-time const is simpler |

## Decision

Use **`Tokens.*` static compile-time constants** as the single design system, defined in `lib/ui/theme/tokens.dart`.

### Token Categories

| Category | Examples | Count |
|----------|----------|-------|
| **Background colors** | `bgDeep`, `bgBase`, `bgPanel`, `bgElevated`, `bgHover`, `bgGlass` | 6 |
| **Accent/semantic colors** | `accent`, `accentLight`, `accentBlue`, `accentEgg`, `danger` | 5 |
| **Glow/edge effects** | `glowCore`, `glowMid`, `glowEdge`, `glowHighlightWhite`, `glowBorderBlue`, etc. | ~20 |
| **Aurora effects** | `auroraBlue1/2/3`, `noiseOverlay`, `glowPurple` | 5 |
| **Control bar** | `controlBarBg`, `controlBarBorderWhite`, `controlBarBorderIdle`, etc. | ~12 |
| **Text colors** | `textPrimary`, `textSecondary`, `textTertiary`, `textDisabled` | 4 |
| **Typography** | `fontFamily`, `fontTitle`, `fontBody`, `fontCaption`, `fontOverline`, weights | ~10 |
| **Icon sizes** | `iconSm` (16), `iconMd` (18), `iconLg` (20), `iconXl` (28) | 4 |
| **Spacing** | `spXs` (4), `spSm` (8), `spMd` (12), `spLg` (16), `spXl` (24) | 5 |
| **Border radius** | `radiusSm` (8), `radiusMd` (14), `radiusLg` (22), `radiusXl` (32) | 6 |
| **Glass blur** | `glassBlurThin` (8), `glassBlur` (11.5), `glassBlurThick` (24) | 3 |
| **Animation durations** | `durationFast` (80ms), `durationNormal` (150ms), `durationFade` (400ms), `durationSlide` (300ms) | 6 |
| **Component dimensions** | `controlBarHeight` (110), `titleBarHeight` (32), `playlistPanelWidth` (420), etc. | ~20 |
| **Progress bar** | `progressBarRadius`, `progressBarThickness`, `progressPlayed`, etc. | ~15 |
| **OSD** | `osdIconSize`, `osdFadeDurationMs`, `osdDefaultHoldMs` | 3 |
| **Breakpoints** | `compactBreakpoint` (500), `breakpointUltraCompact` (360), `breakpointWide` (1200) | 3 |

### Glass-Morphism Pattern

All glass-morphism components follow this pattern via `GlassContainer`:

```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: Tokens.glassBlur, sigmaY: Tokens.glassBlur),
  child: Container(
    decoration: BoxDecoration(
      color: Tokens.bgGlass,                       // 55% opacity dark background
      border: Border.all(color: Tokens.borderHighlight),  // Subtle white border
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
    ),
  ),
)
```

### Theme Variants

Three accent color themes (Midnight/Ocean/Forest) are handled by `ThemeService` which swaps a small set of accent-related tokens at runtime. The vast majority of tokens are compile-time const and theme-invariant.

### Enforcement Rule

**All visual values must come from `Tokens.*`.** No hardcoded colors, font sizes, spacing, radius values, or animation durations in widget code. This is enforced by code review (not automated lint).

## Consequences

### Positive

- **Visual consistency.** Every component uses the same color palette, spacing scale, and border radius. No "one component uses 12px radius while another uses 14px" drift.
- **Single source of truth.** Changing `Tokens.glassBlur` from 11.5 to 16.0 updates every glass component in the app. No hunting for hardcoded values.
- **Zero runtime cost.** All tokens are `static const` — inlined by the Dart compiler. No runtime map lookups, no theme resolution overhead.
- **IDE autocomplete.** `Tokens.` triggers autocomplete showing all available design values. Developers don't need to memorize hex colors or pixel values.
- **Glass-morphism consistency.** The three-tier blur system (`glassBlurThin`/`glassBlur`/`glassBlurThick`) and glow color palette ensure all glass components look cohesive.
- **Responsive breakpoints.** `compactBreakpoint` (500dp) and `breakpointUltraCompact` (360dp) enable consistent responsive layout across components.

### Negative

- **No automated enforcement.** Hardcoded values are caught only by code review, not by `flutter analyze` or a custom lint rule. A developer could write `color: Color(0xFF0C0F18)` instead of `color: Tokens.bgBase` and it would compile.
- **Manual theme switching.** Changing the accent color requires `ThemeService` to update a subset of tokens. The compile-time const nature means most tokens cannot be swapped at runtime.
- **Large token file.** `tokens.dart` is ~250 lines with 100+ tokens. Finding the right token can require scrolling. Naming conventions help but the file grows.
- **Token proliferation risk.** As new components are added, new tokens are added (e.g., OSD-specific tokens, menu-specific tokens). Without discipline, the token file becomes a dumping ground.

### Mitigations

- Code review checklist includes "all visual values via `Tokens.*`" as a mandatory check.
- Tokens are organized by category (background, accent, glow, control bar, text, typography, etc.) with section comments for navigability.
- `ThemeService` handles the 3 accent color variants with minimal token changes (only accent-related tokens are swappable).
- v3.0 bilingual doc comments (Chinese intent + English contract) improve token discoverability.

## Related Decisions

- [ADR-004: Layered Architecture](004-layered-architecture.md) — Tokens live in the UI layer (`lib/ui/theme/`), consumed by all UI components.
- [ADR-001: ValueNotifier](001-value-notifier-state-management.md) — Theme/accent changes are exposed as `ValueNotifier` for reactive UI updates.

## References

- `lib/ui/theme/tokens.dart` — Complete token definitions (~250 lines, 100+ tokens).
- `lib/ui/shared/glass_container.dart` — Reusable glass-morphism wrapper using `Tokens.bgGlass`, `Tokens.borderHighlight`, `Tokens.glassBlur`.
- `lib/ui/player/control_bar.dart` — Bottom glass bar using `Tokens.controlBar*` tokens.
- `lib/ui/player/custom_title_bar.dart` — Title bar using `Tokens.titleBar*` tokens.
- `lib/ui/player/progress_bar.dart` — Progress bar using `Tokens.progressBar*` tokens.
- `lib/ui/widgets/osd_overlay.dart` — OSD using `Tokens.osd*` tokens.
- `lib/ui/playlist/playlist_panel.dart` — Playlist using `Tokens.playlistPanel*` tokens.
- `lib/ui/playlist/thumbnail_tile.dart` — Thumbnail using `Tokens.thumbnailOverlay`.
- `.planning/codebase/CONVENTIONS.md` — Design System Enforcement section.
- `.planning/codebase/ARCHITECTURE.md` — "Single theme: Midnight (compile-time const). Design tokens in `kernel/ui/theme/tokens.dart`."
- Project memory: `project_design_language_analysis.md` — 7 modules with precise parameters, 8 differences, 8 missing.
- Project memory: `project_controlbar_glass_checkpoint.md` — Glass-morphism baseline: glassBlur=0.10, blue glow border, glow constants.
