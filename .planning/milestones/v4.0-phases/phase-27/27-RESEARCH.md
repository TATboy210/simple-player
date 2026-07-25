# Phase 27 Research: Responsive Scaling & Polish

## Current State

### Panel Sizing (settings_overlay_shell.dart)
- Width: `MediaQuery.sizeOf(context).width * 0.5`, clamped to 80%
- Height: `MediaQuery.sizeOf(context).height * 0.5`, clamped to 80%
- No breakpoint-based adaptation (fixed 50% ratio)

### Existing Breakpoints (tokens.dart)
- `compactBreakpoint = 500`
- `breakpointUltraCompact = 360`
- `breakpointWide = 1200`

### Animation System
- Open/close: `AnimatedOpacity` + `AnimatedScale`, 200ms, AppleCurves
- Tab transitions: `TweenAnimationBuilder` 200ms opacity fade
- Micro-interactions: `AnimatedContainer` 80ms hover

### Test Coverage
- ~83 widget tests across 8 test files
- No responsive breakpoint tests
- No animation timing verification
- No integration tests for settings→persistence flow

## Responsive Design Approach

### Breakpoint Strategy
| Breakpoint | Panel Size | Sidebar | Label |
|-----------|-----------|---------|-------|
| ≥1200px (wide) | 600×480 | 200px | Full |
| 800-1199px (medium) | 500×400 | 180px | Standard |
| <800px (compact) | 400×320 | 160px | Compact |

### Implementation Pattern
Use `MediaQuery.sizeOf(context)` with a `_SettingsPanelLayout` helper class that computes dimensions based on window width. Sidebar width scales proportionally.

## Animation Polish

### Current Gaps
- No explicit 60fps verification mechanism
- Tab content uses implicit `TweenAnimationBuilder` controller
- No resize-responsive animation adaptation

### Target
- Maintain existing AppleCurves (already polished)
- Ensure 60fps via `RepaintBoundary` (already in GlassContainer)
- Add smooth panel size transition when window resizes across breakpoints

## Integration Test Strategy

### Key Paths
1. Open panel → verify mask + panel visible
2. Close panel → verify cleanup
3. Switch tab → verify content change
4. Change setting → Apply → verify persistence
5. Cancel → verify original value restored

### Pattern
Use `testWidgets` with `FakePlaybackController` (established pattern). No `mdk.dll` dependency.

## Risks
- Phase 26 dependency (gamepad nav) not yet started — responsive scaling can proceed independently
- Old tab files still in tree — cleanup outside scope
