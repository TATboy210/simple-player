# Phase 19: gradient-transition-strip - Research

**Researched:** 2026-07-03
**Domain:** Flutter widget composition, gradient rendering, animation sync
**Confidence:** HIGH

## Summary

This phase adds a gradient transition strip above the control bar that eliminates the hard visual edge between video content and the glass control bar. The strip fades from transparent (top) to the control bar's background color (bottom), creating a smooth visual bridge.

**Primary recommendation:** Insert a new `Positioned` widget in the ControlsOverlay Stack between OsdOverlay and ControlBar, using a simple `Container` with `BoxDecoration(gradient: LinearGradient(...))`. Sync opacity with `_autoHide.opacity` via `FadeTransition`. Use `HitTestBehavior.translucent` to pass pointer events through to the video surface below.

**Key architectural insight:** The gradient strip is a purely visual element with no interactivity, state, or complex animation. It reuses existing tokens (`controlBarBg`, `controlBarBgIdle`, `controlBarMarginH`, `controlBarMarginBottom`, `controlBarHeight`) and the existing `_autoHide.opacity` animation controller. No new state management or animation infrastructure is needed.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Gradient rendering | UI / Widget | — | Pure visual element in the player overlay |
| Opacity animation sync | UI / Widget | — | Uses existing `_autoHide.opacity` from AutoHideController |
| Hit test passthrough | UI / Widget | — | Non-interactive element, pointer events pass through |
| Idle/playing state color | UI / Widget | — | Reads `isIdle` from engine state, selects gradient color |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material.dart | SDK | LinearGradient, Container, Positioned | Standard Flutter widget API |
| tokens.dart | existing | controlBarBg, controlBarBgIdle, controlBarMarginH, controlBarMarginBottom, controlBarHeight, durationNormal | Project design tokens |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| auto_hide_controller.dart | existing | opacity animation | Always — gradient strip must sync with control bar fade |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Positioned in Stack | Custom RenderObject | Overengineered for a simple gradient strip |
| FadeTransition | AnimatedBuilder | FadeTransition is simpler and already used for ControlBar |
| HitTestBehavior.translucent | IgnorePointer | IgnorePointer blocks all events; translucent passes through |

**Installation:** No new packages needed. All dependencies are existing project files.

## Package Legitimacy Audit

> **Required** whenever this phase installs external packages. Run the Package Legitimacy Gate protocol before completing this section.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | — | — | — | — | — | No packages installed |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  ControlsOverlay (Stack)                                     │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Listener (HitTestBehavior.translucent)                  │ │
│  │  ┌───────────────────────────────────────────────────┐  │ │
│  │  │  MouseRegion (opaque: false)                      │  │ │
│  │  │  ┌─────────────────────────────────────────────┐  │  │ │
│  │  │  │  IgnorePointer (ignoring: !isVisible)       │  │  │ │
│  │  │  │  ┌───────────────────────────────────────┐  │  │  │ │
│  │  │  │  │  RepaintBoundary                      │  │  │  │ │
│  │  │  │  │  ┌─────────────────────────────────┐  │  │  │  │ │
│  │  │  │  │  │  Stack                          │  │  │  │  │ │
│  │  │  │  │  │                                 │  │  │  │  │ │
│  │  │  │  │  │  Positioned: OsdOverlay (top)   │  │  │  │  │ │
│  │  │  │  │  │                                 │  │  │  │  │ │
│  │  │  │  │  │  ┌─────────────────────────┐    │  │  │  │  │ │
│  │  │  │  │  │  │ NEW: GradientStrip      │    │  │  │  │  │ │
│  │  │  │  │  │  │ (Positioned, 60px)      │    │  │  │  │  │ │
│  │  │  │  │  │  │ FadeTransition +         │    │  │  │  │  │ │
│  │  │  │  │  │  │ HitTestBehavior          │    │  │  │  │  │ │
│  │  │  │  │  │  │ .translucent             │    │  │  │  │  │ │
│  │  │  │  │  │  └─────────────────────────┘    │  │  │  │  │ │
│  │  │  │  │  │                                 │  │  │  │  │ │
│  │  │  │  │  │  Positioned: ControlBar (bottom)│  │  │  │  │ │
│  │  │  │  │  │                                 │  │  │  │  │ │
│  │  │  │  │  │  Positioned: ErrorBanner        │  │  │  │  │ │
│  │  │  │  │  └─────────────────────────────────┘  │  │  │  │ │
│  │  │  │  └───────────────────────────────────────┘  │  │  │ │
│  │  │  └─────────────────────────────────────────────┘  │  │ │
│  │  └───────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

No new files needed. The gradient strip is implemented inline in `controls_overlay.dart` as a local widget or method.

### Pattern 1: Gradient Transition Strip (inline in ControlsOverlay.build)

**What:** A `Positioned` widget containing a `Container` with `BoxDecoration(gradient: LinearGradient(...))`, wrapped in `FadeTransition` and `GestureDetector` for hit test control.

**When to use:** Always — this is the only pattern needed for this phase.

**Example:**

```dart
// Source: Codebase analysis (controls_overlay.dart, control_bar.dart, tokens.dart)

// New token in tokens.dart:
static const double gradientStripHeight = 60.0;

// In ControlsOverlay.build(), inside the Stack, between OsdOverlay and ControlBar:
Positioned(
  bottom: Tokens.controlBarMarginBottom + Tokens.controlBarHeight,
  left: Tokens.controlBarMarginH,
  right: Tokens.controlBarMarginH,
  height: Tokens.gradientStripHeight,
  child: FadeTransition(
    opacity: _autoHide.opacity,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                isIdle ? Tokens.controlBarBgIdle : Tokens.controlBarBg,
              ],
            ),
          ),
        ),
      ),
    ),
  ),
),
```

### Pattern 2: Opacity Sync with Control Bar

**What:** Use the same `_autoHide.opacity` animation controller that wraps the ControlBar to also wrap the gradient strip.

**When to use:** Always — ensures the gradient strip fades in/out with the control bar.

**Example:**

```dart
// Source: Codebase analysis (auto_hide_controller.dart, controls_overlay.dart)

// The _autoHide.opacity is an Animation<double> that:
// - Fades from 0 to 1 when control bar appears (300ms easeOut)
// - Fades from 1 to 0 when control bar disappears
// - Is already used by ControlBar's FadeTransition

// Gradient strip uses the same animation:
FadeTransition(
  opacity: _autoHide.opacity,
  child: ...
)
```

### Anti-Patterns to Avoid

- **Don't create a separate AnimationController** — reuse `_autoHide.opacity`
- **Don't use IgnorePointer for hit test** — use `HitTestBehavior.translucent` to pass events through
- **Don't hardcode gradient colors** — use existing tokens (`controlBarBg`, `controlBarBgIdle`)
- **Don't forget RepaintBoundary** — isolate repaint region from control bar repaints

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Gradient rendering | Custom Canvas painting | Container + BoxDecoration(gradient) | Simpler, performant, standard Flutter |
| Opacity animation | New AnimationController | Existing `_autoHide.opacity` | Already exists, syncs with control bar |
| Hit test passthrough | Custom RenderBox | HitTestBehavior.translucent | Standard Flutter pattern, well-tested |
| Idle/playing state | New ValueNotifier | Existing `isIdle` parameter | Already passed to ControlBar |

**Key insight:** The gradient strip is a thin visual layer that reuses existing infrastructure. No new abstractions needed.

## Common Pitfalls

### Pitfall 1: Gradient Strip Blocks Clicks

**What goes wrong:** The gradient strip intercepts pointer events, preventing clicks on the video surface or other widgets below.

**Why it happens:** Container with decoration is opaque to hit testing by default.

**How to avoid:** Wrap the gradient strip in `GestureDetector(behavior: HitTestBehavior.translucent)` or `Listener(behavior: HitTestBehavior.translucent)`. This allows pointer events to pass through to widgets below.

**Warning signs:** Clicks on the video area above the control bar don't work when the gradient strip is visible.

### Pitfall 2: Gradient Strip Doesn't Sync with Control Bar Fade

**What goes wrong:** The gradient strip appears/disappears at a different time than the control bar.

**Why it happens:** Using a different animation controller or not using FadeTransition at all.

**How to avoid:** Always wrap the gradient strip in `FadeTransition(opacity: _autoHide.opacity)` — the same animation that wraps the ControlBar.

**Warning signs:** Visual mismatch between gradient strip and control bar opacity.

### Pitfall 3: Gradient Strip Position Drifts on Window Resize

**What goes wrong:** The gradient strip doesn't stay flush with the control bar top edge after window resize.

**Why it happens:** Hardcoded values instead of using tokens.

**How to avoid:** Use `Tokens.controlBarMarginBottom + Tokens.controlBarHeight` for the bottom edge position, and `Tokens.controlBarMarginH` for horizontal margins.

**Warning signs:** Gap or overlap between gradient strip and control bar after resize.

### Pitfall 4: Gradient Strip Causes Unnecessary Repaints

**What goes wrong:** The gradient strip repaints on every frame, even when nothing changes.

**Why it happens:** No RepaintBoundary to isolate the repaint region.

**How to avoid:** Wrap the gradient strip's Container in `RepaintBoundary`.

**Warning signs:** Performance degradation in DevTools timeline when gradient strip is visible.

## Code Examples

Verified patterns from official sources:

### LinearGradient Container Pattern

```dart
// Source: Codebase analysis (control_bar.dart line 195-202)
// Existing gradient pattern in ControlBar's top highlight:
Positioned(
  top: 0,
  left: 0,
  right: 0,
  height: 1,
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          Tokens.glowAccent,
          Colors.transparent,
        ],
      ),
    ),
  ),
),
```

### FadeTransition Pattern

```dart
// Source: Codebase analysis (controls_overlay.dart line 200-209)
// Existing FadeTransition wrapping ControlBar:
FadeTransition(
  opacity: _autoHide.opacity,
  child: ControlBar(
    engine: widget.engine,
    actions: widget.actions,
    isIdle: isIdle,
    title: widget.title,
    opacity: _autoHide.opacity,
    enableBlur: true,
    resizing: widget.resizing,
  ),
),
```

### HitTestBehavior Pattern

```dart
// Source: Codebase analysis (controls_overlay.dart line 171-176)
// Existing HitTestBehavior.translucent in ControlsOverlay:
Listener(
  behavior: HitTestBehavior.translucent,
  onPointerDown: blockBackgroundTap ? null : _onPointerDown,
  onPointerUp: blockBackgroundTap ? null : _onPointerUp,
  child: MouseRegion(
    opaque: false,
    hitTestBehavior: HitTestBehavior.translucent,
    onHover: (_) => _autoHide.onMouseMove(),
    ...
  ),
),
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hard edge between video and control bar | Gradient transition strip | Phase 19 (this phase) | Smooth visual bridge |

**Deprecated/outdated:**
- None — this is a new feature, not a migration

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The UI-SPEC.md is approved and contains the final visual spec | User Constraints | Low — UI-SPEC was created and reviewed in this session |
| A2 | The gradient strip height should be 60px (new token) | Standard Stack | Low — UI-SPEC specifies this value |
| A3 | The gradient strip should use HitTestBehavior.translucent (not IgnorePointer) | Architecture Patterns | Low — UI-SPEC specifies passthrough behavior |
| A4 | No new packages are needed for this phase | Package Legitimacy Audit | None — pure Flutter widget composition |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions (RESOLVED)

1. **Should the gradient strip have a rounded top corner?** — RESOLVED: Leave sharp (no border radius). The gradient fades to transparent, so corners are invisible.

2. **Should the gradient strip extend to the edges of the screen or match ControlBar margins?** — RESOLVED: Match ControlBar margins (24px each side), per UI-SPEC definition.

## Environment Availability

> Skip this section if the phase has no external dependencies (code/config-only changes).

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Widget development | ✓ | 3.x | — |
| tokens.dart | Token values | ✓ | existing | — |
| controls_overlay.dart | Widget tree insertion | ✓ | existing | — |

**Missing dependencies with no fallback:**
- None

**Missing dependencies with fallback:**
- None

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test |
| Config file | test/widget/player/controls_overlay_test.dart |
| Quick run command | `flutter test test/widget/player/controls_overlay_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GRAD-01 | Gradient strip renders above control bar | widget | `flutter test test/widget/player/gradient_strip_test.dart` | ❌ Wave 0 |
| GRAD-02 | Gradient strip has correct height (60px) | widget | `flutter test test/widget/player/gradient_strip_test.dart` | ❌ Wave 0 |
| GRAD-03 | Gradient strip fades with control bar | widget | `flutter test test/widget/player/gradient_strip_test.dart` | ❌ Wave 0 |
| GRAD-04 | Gradient bottom color changes idle/playing | widget | `flutter test test/widget/player/gradient_strip_test.dart` | ❌ Wave 0 |
| GRAD-05 | Gradient strip is non-interactive (hit test passthrough) | widget | `flutter test test/widget/player/gradient_strip_test.dart` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/widget/player/gradient_strip_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/widget/player/gradient_strip_test.dart` — covers GRAD-01 to GRAD-05
- [ ] No shared fixtures needed — reuse `test/helpers/fake_engine.dart`

## Security Domain

> Required when `security_enforcement` is enabled (absent = enabled). Omit only if explicitly `false` in config.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A — desktop media player, no auth |
| V3 Session Management | no | N/A — no sessions |
| V4 Access Control | no | N/A — no access control |
| V5 Input Validation | no | N/A — no user input in gradient strip |
| V6 Cryptography | no | N/A — no cryptography |

### Known Threat Patterns for Flutter Desktop

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| None applicable | — | — |

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `controls_overlay.dart` — widget tree, Positioned layout, _autoHide.opacity
- Codebase analysis: `control_bar.dart` — AnimatedContainer, EdgeGlow, RepaintBoundary patterns
- Codebase analysis: `tokens.dart` — token values, naming conventions
- Codebase analysis: `auto_hide_controller.dart` — opacity animation, show/hide logic

### Secondary (MEDIUM confidence)
- UI-SPEC.md — gradient strip specification (created in this session)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — all dependencies are existing project files, no new packages
- Architecture: HIGH — clear insertion point in ControlsOverlay.build(), simple widget composition
- Pitfalls: HIGH — well-understood Flutter patterns (hit test, animation sync, repaint isolation)

**Research date:** 2026-07-03
**Valid until:** 2026-08-03 (30 days — stable Flutter API, no fast-moving dependencies)
