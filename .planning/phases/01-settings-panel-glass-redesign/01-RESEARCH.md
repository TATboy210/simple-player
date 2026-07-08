# Phase 1: Settings Panel Glass Redesign - Research

**Researched:** 2026-07-08
**Domain:** Flutter UI refactor — Glassmorphism migration
**Confidence:** HIGH

## Summary

This phase migrates the settings panel from solid-color `SettingsCard` backgrounds with box-shadow to the existing `GlassContainer` glassmorphism pattern used by the control bar. The refactor is purely visual — no new packages, no architectural changes, no state management modifications.

The existing `GlassContainer` component (`lib/ui/shared/glass_container.dart`) is production-ready with 3-tier blur (thin/normal/thick), cached `ImageFilter` instances, resize-aware blur skipping, and opacity-driven fade support. It already uses `Tokens.bgGlass` + `BackdropFilter` + `Tokens.borderHighlight` — exactly matching the control bar's visual language.

The refactor scope is contained: replace `SettingsCard`, `SettingsExpanderCard`, and `SettingsActionCard` with `GlassContainer` + `Column` compositions across all 7 tabs (General, Equalizer, Audio, Video, Shortcuts, About, Performance). The `SettingRow` and `SettingSwitchRow` row components are preserved as-is — they already follow the correct pattern (hover/press feedback, `Tokens.*` styling).

**Primary recommendation:** Replace all `SettingsCard`/`SettingsExpanderCard`/`SettingsActionCard` usage with `GlassContainer` wrapping `_SectionHeader` + `SettingRow` children. Keep `SettingRow` and `SettingSwitchRow` unchanged.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Glass background rendering | UI (GlassContainer) | — | Existing component handles BackdropFilter + ClipRRect |
| Settings panel layout | UI (SettingsPanel) | — | Sidebar + content + bottom bar structure |
| Tab content rendering | UI (7 tab widgets) | — | Each tab owns its section layout |
| Delayed apply (locale/theme) | Service (LocaleService/ThemeService) | UI (SettingsPanel) | Service handles state; UI defers commit to dialog close |
| Drag behavior | UI (SettingsPanel) | — | ValueNotifier<Offset> + GestureDetector on title bar |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material | SDK | UI framework | Project standard |
| GlassContainer | project-local | Glassmorphism wrapper | Already tested, 3-tier blur |
| Tokens.* | project-local | Design tokens | Compile-time constants, single source of truth |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| EdgeGlow | project-local | Border glow effect | Optional — control bar uses it, settings panel may not need it |
| GlassButton | project-local | Glass-styled buttons | For bottom bar buttons (OK/Cancel/Apply) |
| GlassChip | project-local | Glass-styled chips | For language/theme selectors in GeneralTab |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| GlassContainer | Custom BackdropFilter per card | More code, inconsistent blur params |
| Keep SettingsCard + change color | Full replacement | Doesn't remove abstraction layer (COMP-03) |
| New SettingsGlassCard wrapper | Direct GlassContainer | Adds unnecessary indirection |

**Installation:** No new packages required — all components are project-local.

## Package Legitimacy Audit

No external packages are installed in this phase. All components (`GlassContainer`, `GlassButton`, `GlassChip`, `EdgeGlow`) are project-local and already in use by the control bar.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| — | — | — | — | — | — | No packages to audit |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    SettingsPanel                         │
│  ┌──────────┐  ┌──────────────────────────────────────┐ │
│  │ _Sidebar │  │  Tab Content (AnimatedSwitcher)      │ │
│  │          │  │  ┌────────────────────────────────┐  │ │
│  │ NavItem  │  │  │  GlassContainer (replaces Card)│  │ │
│  │ NavItem  │  │  │  ├─ _SectionHeader             │  │ │
│  │ NavItem  │  │  │  ├─ SettingRow                  │  │ │
│  │ NavItem  │  │  │  ├─ SettingRow                  │  │ │
│  │ NavItem  │  │  │  └─ SettingSwitchRow            │  │ │
│  │ NavItem  │  │  └────────────────────────────────┘  │ │
│  │ NavItem  │  │  ┌────────────────────────────────┐  │ │
│  │ NavItem  │  │  │  GlassContainer                │  │ │
│  │          │  │  │  └─ SettingRow                  │  │ │
│  │          │  │  └────────────────────────────────┘  │ │
│  └──────────┘  └──────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐│
│  │  Bottom Bar: [OK] [Cancel] [Apply]                  ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│     GlassContainer      │
│  BackdropFilter(blur)   │
│  + bgGlass + borderHL   │
│  + ClipRRect            │
└─────────────────────────┘
```

### Recommended Project Structure
```
lib/ui/
├── dialogs/
│   ├── settings_panel.dart          # Main panel (modify: glass background)
│   └── settings/
│       ├── _settings_nav_item.dart  # Sidebar nav item (modify: glass hover)
│       ├── general_tab.dart         # Replace SettingsCard → GlassContainer
│       ├── equalizer_tab.dart       # Replace SettingsCard → GlassContainer
│       ├── audio_tab.dart           # Replace SettingsCard → GlassContainer
│       ├── video_tab.dart           # Replace SettingsCard → GlassContainer
│       ├── shortcuts_tab.dart       # Replace SettingsCard → GlassContainer
│       ├── about_tab.dart           # Replace SettingsCard/ActionCard → GlassContainer
│       └── settings_tab_performance.dart  # Replace SettingsCard → GlassContainer
├── shared/
│   ├── glass_container.dart         # KEEP — source of truth for glass effect
│   ├── settings_card.dart           # REMOVE after migration (or deprecate)
│   ├── settings_expander_card.dart  # REMOVE after migration
│   ├── settings_action_card.dart    # REMOVE after migration
│   ├── setting_action_row.dart      # KEEP — row component
│   └── setting_slider_row.dart      # KEEP — row component
```

### Pattern 1: GlassContainer as SettingsCard Replacement

**What:** Replace `SettingsCard` with `GlassContainer` + `Column` containing `_SectionHeader` + children.

**When to use:** Every place that currently uses `SettingsCard`, `SettingsExpanderCard`, or `SettingsActionCard`.

**Example:**
```dart
// BEFORE: SettingsCard with solid background
SettingsCard(
  title: l10n.language,
  icon: Icons.language,
  children: [
    _LanguageSelector(currentLocale: currentLocale, onChanged: onLocaleChanged),
  ],
)

// AFTER: GlassContainer with glassmorphism
GlassContainer(
  padding: const EdgeInsets.symmetric(
    horizontal: Tokens.spLg,
    vertical: Tokens.spMd,
  ),
  margin: const EdgeInsets.only(bottom: Tokens.spMd),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(title: l10n.language, icon: Icons.language),
      _LanguageSelector(currentLocale: currentLocale, onChanged: onLocaleChanged),
    ],
  ),
)
```

### Pattern 2: SettingsExpanderCard Replacement

**What:** `SettingsExpanderCard` has expand/collapse behavior. Replace with `GlassContainer` + `ExpansionTile` or custom `AnimatedCrossFade` inside the glass container.

**When to use:** Currently unused in any tab (verified by grep). Can be removed entirely.

**Note:** Grep shows `SettingsExpanderCard` is defined but not imported by any tab file. It may be dead code — verify before preserving expand functionality.

### Pattern 3: SettingsActionCard Replacement

**What:** `SettingsActionCard` is a clickable card with trailing icon. Replace with `GlassContainer` + `InkWell` wrapping a `SettingRow`.

**When to use:** `AboutTab` uses it for the licenses link.

**Example:**
```dart
// BEFORE
SettingsActionCard(
  title: l10n.licenses,
  icon: Icons.article,
  onTap: () => showLicensePage(context: context, ...),
)

// AFTER
GlassContainer(
  padding: const EdgeInsets.symmetric(
    horizontal: Tokens.spLg,
    vertical: Tokens.spMd,
  ),
  margin: const EdgeInsets.only(bottom: Tokens.spMd),
  child: InkWell(
    onTap: () => showLicensePage(context: context, ...),
    borderRadius: BorderRadius.circular(Tokens.radiusLarge),
    child: SettingRow(
      icon: Icons.article,
      title: l10n.licenses,
      control: const Icon(Icons.chevron_right, size: Tokens.iconMd, color: Tokens.textTertiary),
    ),
  ),
)
```

### Pattern 4: Panel Background Glass

**What:** The settings panel itself uses `Material(elevation: 8, color: Tokens.bgElevated)`. Replace with `GlassContainer` wrapping the entire panel.

**When to use:** The outer panel shell in `SettingsPanel.build()`.

**Key constraint:** `GlassContainer` uses `BackdropFilter` which requires a `ClipRRect` ancestor. The panel already has `clipBehavior: Clip.antiAlias` on the Material widget.

### Pattern 5: Sidebar Nav Item Glass Hover

**What:** `_SettingsNavItem` uses `Tokens.bgHover` for selected state. To match control bar buttons, use the same hover/press pattern as `GlassButton.iconOnly` (but without the scale animation — user preference: no button animations).

**When to use:** `_settings_nav_item.dart` modification.

### Anti-Patterns to Avoid

- **Don't create a new SettingsGlassCard wrapper:** Use `GlassContainer` directly. The goal is to reduce abstraction layers, not add another one.
- **Don't hardcode glass parameters:** Always use `Tokens.bgGlass`, `Tokens.radiusLarge`, `Tokens.borderHighlight` — never inline values.
- **Don't remove _SectionHeader:** It's a useful pattern for section titles inside cards. Keep it as a private widget in `settings_card.dart` or move it to a shared location.
- **Don't add EdgeGlow to settings cards:** The control bar uses EdgeGlow for its gradient border, but settings cards should be simpler — just `GlassContainer` with `borderHighlight`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Glass blur effect | Custom BackdropFilter + ImageFilter | `GlassContainer` | Already handles 3-tier blur, resize skip, opacity fade |
| Glass border | Custom Container + Border | `GlassContainer` (default border) | Uses `Tokens.borderHighlight` automatically |
| Hover/press feedback | Custom MouseRegion + GestureDetector | `SettingRow` (existing) | Already handles hover/press with `Tokens.bgHover` |
| Section header | New widget | `_SectionHeader` (existing in settings_card.dart) | Works well, just needs to be accessible after card removal |

**Key insight:** The `GlassContainer` component is production-ready and already handles all the glassmorphism complexity. The refactor is about wiring, not building new components.

## Common Pitfalls

### Pitfall 1: SettingsExpanderCard Dead Code
**What goes wrong:** Preserving `SettingsExpanderCard` when it's not used by any tab.
**Why it happens:** Assumption that all exported components are used.
**How to avoid:** Grep for `SettingsExpanderCard` imports before preserving. If unused, remove it.
**Warning signs:** Compilation errors after removal indicate usage.

### Pitfall 2: _SectionHeader Accessibility
**What goes wrong:** After removing `SettingsCard`, `_SectionHeader` becomes inaccessible (it's a private widget in `settings_card.dart`).
**Why it happens:** `_SectionHeader` is private to `settings_card.dart`.
**How to avoid:** Either keep `settings_card.dart` with only `_SectionHeader` exported, or move `_SectionHeader` to a shared file.
**Warning signs:** Import errors after removing `settings_card.dart`.

### Pitfall 3: Margin/Padding Consistency
**What goes wrong:** Each tab manually sets `GlassContainer` margin/padding, leading to inconsistencies.
**Why it happens:** No shared constant for card spacing.
**How to avoid:** Define `settingsCardMargin` and `settingsCardPadding` constants, or create a thin helper function.
**Warning signs:** Visual inconsistencies between tabs.

### Pitfall 4: ListView Padding
**What goes wrong:** Tabs use `ListView(padding: EdgeInsets.zero)` which clips to the card edges. After switching to `GlassContainer`, the blur effect may be clipped.
**Why it happens:** `ListView` clips its children by default.
**How to avoid:** Use `clipBehavior: Clip.none` on the ListView, or wrap the ListView in a `Padding` widget.
**Warning signs:** Glass blur effect not visible at card edges.

## Code Examples

### GlassContainer Usage (from control_bar.dart)
```dart
// Source: lib/ui/shared/glass_container.dart
// GlassContainer with default settings — matches control bar style
GlassContainer(
  padding: const EdgeInsets.symmetric(
    horizontal: Tokens.spLg,
    vertical: Tokens.spMd,
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Section header
      Row(
        children: [
          Icon(icon, size: Tokens.iconSm, color: Tokens.textSecondary),
          const SizedBox(width: Tokens.spXs),
          Text(
            title,
            style: const TextStyle(
              color: Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
              fontWeight: Tokens.weightMedium,
            ),
          ),
        ],
      ),
      const SizedBox(height: Tokens.spSm),
      // Content rows
      SettingRow(title: 'Label', control: Switch(...)),
    ],
  ),
)
```

### GlassButton for Bottom Bar (from glass_container.dart)
```dart
// Source: lib/ui/shared/glass_container.dart
// Replace _BottomButton with GlassButton for consistency
GlassButton(
  icon: Icons.check,
  label: l10n.ok,
  isPrimary: true,
  onPressed: _ok,
)
```

### SettingsNavItem Hover Pattern (from _settings_nav_item.dart)
```dart
// Source: lib/ui/dialogs/settings/_settings_nav_item.dart
// Current pattern — uses Tokens.bgHover for selected state
// To match control bar: add InkWell hover feedback (already present)
// No change needed — current pattern is already consistent
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SettingsCard with solid bg + boxShadow | GlassContainer with BackdropFilter | This phase | Visual consistency with control bar |
| _BottomButton custom widget | GlassButton (reuse existing) | This phase | Consistent button styling |
| Material(elevation: 8) panel | GlassContainer panel shell | This phase | Glass effect on entire panel |

**Deprecated/outdated:**
- `SettingsCard.cardDecoration`: Will be removed — `BoxDecoration(color: Tokens.bgPanel, boxShadow: ...)` replaced by `GlassContainer`'s `BackdropFilter` approach.
- `SettingsExpanderCard`: Likely dead code — no tab imports it. Remove.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SettingsExpanderCard is unused by any tab | Pattern 2 | If used, need to preserve expand/collapse in GlassContainer |
| A2 | _SectionHeader can be kept as-is after card removal | Pitfall 2 | May need to extract to shared file |
| A3 | GlassContainer works correctly inside ListView without clipping | Pitfall 4 | May need clipBehavior adjustment |
| A4 | EdgeGlow is not needed on settings cards | Anti-Patterns | If user wants gradient borders, add EdgeGlow |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions

1. **Should _SectionHeader be extracted to a shared file?**
   - What we know: It's private to `settings_card.dart`, used by all tabs via `SettingsCard`.
   - What's unclear: Whether to keep `settings_card.dart` with only `_SectionHeader`, or move it.
   - Recommendation: Keep `settings_card.dart` with `_SectionHeader` exported, remove `SettingsCard` class.

2. **Should the panel background use GlassContainer or keep Material?**
   - What we know: Currently uses `Material(elevation: 8, color: Tokens.bgElevated)`.
   - What's unclear: Whether `GlassContainer` works as a panel shell (it uses `BackdropFilter` which may interact with the overlay).
   - Recommendation: Try `GlassContainer` for the panel shell. If blur doesn't render (overlay context), fall back to `Material` with `bgGlass` color.

3. **Should bottom bar buttons use GlassButton?**
   - What we know: Current `_BottomButton` is a custom widget. `GlassButton` exists and is tested.
   - What's unclear: Whether `GlassButton`'s scale animation conflicts with user preference (no button animations).
   - Recommendation: Use `GlassButton` with `enabled: true` but disable scale animation via a parameter, or keep `_BottomButton` with glass styling.

## Environment Availability

> Skip this section if the phase has no external dependencies (code/config-only changes).

This phase is purely code/config changes with no external dependencies. All components are project-local.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| GlassContainer | All tabs | ✓ | project-local | — |
| GlassButton | Bottom bar | ✓ | project-local | — |
| GlassChip | GeneralTab | ✓ | project-local | — |
| Tokens.* | All visual values | ✓ | project-local | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | `pubspec.yaml` dev_dependencies |
| Quick run command | `flutter test test/widget/dialogs/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRIG-01 | Left-click opens full panel | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ Wave 0 |
| TRIG-02 | Right-click opens quick menu | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ Wave 0 |
| TRIG-03 | Settings button hover feedback | visual | Golden test | ❌ Wave 0 |
| COMP-01 | GlassContainer background | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ Wave 0 |
| COMP-02 | SettingRow preserved | widget | Existing: `test/widget/shared/settings_card_test.dart` | ❌ Wave 0 |
| COMP-03 | SettingsCard removed | analysis | `flutter analyze` | ✓ |
| COMP-04 | Title bar unified | visual | Golden test | ❌ Wave 0 |
| STYLE-01 | bgGlass + BackdropFilter | widget | Widget test checks GlassContainer presence | ❌ Wave 0 |
| STYLE-02 | radiusLarge rounded | visual | Golden test | ❌ Wave 0 |
| STYLE-03 | borderHighlight border | visual | Golden test | ❌ Wave 0 |
| STYLE-04 | Sidebar nav hover matches control bar | visual | Golden test | ❌ Wave 0 |
| INTX-01 | OK/Cancel/Apply works | widget | `flutter test test/widget/dialogs/settings_panel_test.dart` | ❌ Wave 0 |
| INTX-02 | Locale/theme deferred | widget | Widget test with mock LocaleService | ❌ Wave 0 |
| INTX-03 | ESC cancel restores | widget | Widget test with key events | ❌ Wave 0 |
| INTX-04 | Drag works | widget | Widget test with drag gestures | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/widget/dialogs/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/widget/dialogs/settings_panel_test.dart` — covers TRIG-01/02/03, COMP-01/02/04, STYLE-01-04, INTX-01-04
- [ ] `test/widget/shared/settings_card_test.dart` — verify SettingRow/SettingSwitchRow still work after refactor
- [ ] Golden tests for glass visual verification

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

## Security Domain

> Required when `security_enforcement` is enabled (absent = enabled). Omit only if explicitly `false` in config.

This phase is a pure UI visual refactor — no security-sensitive code changes (no auth, no input validation, no crypto, no data handling).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |

### Known Threat Patterns for Flutter UI Refactor

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| None applicable | — | Pure visual refactor, no security surface |

## Sources

### Primary (HIGH confidence)
- `lib/ui/shared/glass_container.dart` — GlassContainer implementation, 161 lines, production-ready
- `lib/ui/shared/settings_card.dart` — Current SettingsCard + SettingRow + SettingSwitchRow, 273 lines
- `lib/ui/dialogs/settings_panel.dart` — Main panel, 405 lines, 7-tab structure
- `lib/ui/theme/tokens.dart` — Design tokens, 249 lines
- `lib/ui/player/control_bar.dart` — Reference for glass styling, 325 lines

### Secondary (MEDIUM confidence)
- `lib/ui/shared/edge_glow.dart` — EdgeGlow variants, 285 lines (may not be needed for settings)
- `lib/ui/shared/glass_widgets.dart` — Export barrel for GlassContainer/GlassButton/GlassChip

### Tertiary (LOW confidence)
- No external documentation needed — all components are project-local

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components are project-local and tested
- Architecture: HIGH — clear refactor path, existing patterns
- Pitfalls: MEDIUM — SettingsExpanderCard dead code assumption needs verification

**Research date:** 2026-07-08
**Valid until:** 2026-08-08 (stable — project-local refactor, no external deps)
