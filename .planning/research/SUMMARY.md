# Project Research Summary

**Project:** Simple Player Flutter - Glass Morphism Color Coordination
**Domain:** Desktop media player control bar visual design
**Researched:** 2026-07-02
**Confidence:** HIGH

## Executive Summary

Simple Player Flutter control bar uses static dark overlay (controlBarBg 45% opacity). Clashes with AuroraBackground in idle state. Solution: add idle-state token variants to Tokens.*, let ControlBar select via isIdle boolean.

## Key Findings

### Recommended Stack
- ImageFilter.compose: blur + color in single GPU pass
- ColorFilter.mode + BlendMode.softLight: hardware tinting
- Tokens.* idle variants: compile-time constants
- Zero new dependencies

### Must Have
- Gradient transition zone above control bar
- Empty state background adaptation
- Border color coordination

### Architecture
1. Tokens.* - 6 idle-variant constants
2. GlassContainer - optional backgroundColor param
3. ControlBar - _buildDecoration(isIdle) method
4. EdgeGlow - glowIntensity param

### Critical Pitfalls
1. Reducing bgGlass alpha does NOT improve blending
2. Measure contrast against composite, not overlay
3. BackdropFilter GPU readback during resize
4. Stacked BackdropFilters compound cost
5. Border invisible after alpha reduction

## Roadmap

### Phase 1: Token Foundation and Gradient Transition
### Phase 2: Adaptive Control Bar
### Phase 3: Polish and Edge Glow Tuning

**Overall confidence:** HIGH
*Research completed: 2026-07-02*
