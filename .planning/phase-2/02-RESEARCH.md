# Phase 2 Research: 设置面板视觉升级

**Researched:** 2026-07-13
**Confidence:** HIGH

## Current State Analysis

### Settings Panel Structure
- `settings_panel.dart` (403 lines) — main dialog with sidebar navigation, draggable, OK/Cancel/Apply
- `_settings_nav_item.dart` — sidebar nav item (icon + label, selected highlight)
- 7 tab files: general_tab, equalizer_tab, audio_tab, video_tab, shortcuts_tab, about_tab, performance_tab
- `settings_card.dart` (154 lines) — reusable card widget

### Current Visual Issues
1. **Sidebar width**: 72px — too narrow for CJK labels (research recommends 80-100px)
2. **Nav item width**: 64px — text truncation risk
3. **Border radius**: Uses `radiusLarge` (12.0) for panel, `radiusSm` (8.0) for buttons/nav items
4. **Tab transition**: `AnimatedSwitcher` with `durationFast` (80ms) — functional but no slide/offset animation
5. **Bottom buttons**: Plain `InkWell` + `Container` — no hover elevation, no press scale
6. **No section animations**: Content appears instantly, no staggered reveal
7. **SettingsNavItem**: Simple `InkWell` with bg highlight — no hover gradient, no selection animation

### Design Tokens Available
- Radii: `radiusSm` (8), `radiusMd` (14), `radiusLg` (22), `radiusXl` (32)
- Spacing: `spXs` (4), `spSm` (8), `spMd` (12), `spLg` (16), `spXl` (24)
- Durations: `durationFast` (80ms), `durationNormal` (150ms), `durationFade` (400ms), `durationSlide` (300ms)
- Glass: `glassBlur` (11.5), `glassBlurThick` (24.0)
- Hover: `bgHover` (0xFF283045)
- Glow tokens: extensive set for border highlights

### GlassContainer Pattern
- 3-tier blur system (thin/normal/thick)
- BackdropFilter + borderHighlight + boxShadow
- Already optimized with cached filters

### Control Bar Reference (target style)
- `controlBarRadius` = 22px
- `controlBarBorder` = 146482FF (8% blue glow)
- Uses hover scale (1.02) and press scale (0.98)
- Smooth fade-in/fade-out animations

## Recommendations

### SUI-01 Tasks
1. **Sidebar upgrade**: 72px -> 88px, nav items with hover gradient + selection indicator animation
2. **Panel radius**: `radiusLarge` (12) -> `radiusLg` (22) to match control bar
3. **Tab transitions**: AnimatedSwitcher with SlideTransition (left-right offset) instead of plain fade
4. **Bottom buttons**: Add hover elevation, press scale, accent glow on primary button
5. **Section stagger**: Optional — animate content sections with 50ms stagger on tab switch
6. **Nav item polish**: Hover background gradient, selected accent bar animation (width tween)

### Token Additions Needed
- Settings sidebar width token
- Settings panel radius token (may reuse `radiusLg`)
- Tab transition offset token

## Pitfalls
1. **Don't over-animate**: Keep transitions subtle (80-150ms), match control bar feel
2. **GlassContainer reuse**: Don't create new glass effects — use existing GlassContainer
3. **Sidebar width change**: May affect overall panel width (currently 600px fixed)
4. **Tab content height**: Staggered animations must not cause layout jumps

---
*Research: 2026-07-13*
