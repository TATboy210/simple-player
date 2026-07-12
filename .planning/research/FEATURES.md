# Feature Landscape: Settings Panel Refactoring

**Domain:** Desktop media player settings
**Researched:** 2026-07-12
**Current state:** 7 tabs (General, Equalizer, Audio, Video, Shortcuts, About, Performance), sidebar navigation, OK/Cancel/Apply pattern, deferred locale/theme changes

## Table Stakes

Features users expect in any modern desktop settings panel. Missing = feels outdated.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Sidebar navigation** | Already implemented. Standard pattern (VS Code, Slack, Figma) | Done | Keep current pattern |
| **Reset to defaults (per section)** | Users fear breaking things. VLC, macOS, Windows all offer this | Low | Add reset button per tab, not just global |
| **Clear section grouping** | 7 tabs is borderline. Logical grouping reduces cognitive load | Low | Consider merging Related/Audio into fewer tabs |
| **Instant visual feedback** | Changes should feel immediate. Volume slider, theme picker, EQ curve should update live | Medium | Already partially done (theme preview). Extend to EQ |
| **Keyboard navigation** | Tab/arrow/Enter within settings. Desktop users expect this | Low | Flutter handles this by default, verify focus order |
| **Consistent terminology** | Labels must match user mental model, not developer jargon | Low | Audit current labels |
| **Visible save state** | User must know if changes are saved or pending | Low | Current OK/Cancel/Apply is clear. Keep it |

## Differentiators

Features that elevate the experience beyond baseline. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Settings search/filter** | 7 tabs with many options. Search lets users find "subtitle delay" without knowing it's in Audio tab | Medium | Filter sidebar + highlight matching sections. VS Code pattern |
| **Live preview (non-modal)** | See video/audio changes while settings dialog is open | High | Requires settings dialog to not block player. Current modal approach blocks this |
| **Import/export settings** | Power users share configs, backup preferences, transfer between machines | Medium | JSON export of SettingsStore. VLC/PotPlayer support this |
| **Undo last change** | Reduce anxiety about experimenting with EQ, video processing | Medium | Stack of recent changes with Ctrl+Z support |
| **Settings presets** | "Movie night", "Music", "Gaming" presets that batch multiple settings | Medium | Combines volume, EQ, video processing, subtitle settings |
| **Contextual quick settings** | Right-click menu or OSD for in-playback adjustments without opening full settings | Medium | PotPlayer pattern. Avoids opening settings for common tweaks |
| **Keyboard shortcut customization with conflict detection** | Already have shortcuts tab. Conflict detection prevents broken bindings | Low | Detect duplicate key assignments, show warning |
| **Per-file settings override** | Save video processing, audio, subtitle settings per file | High | PotPlayer supports this. Complex persistence layer |

## Anti-Features

Features to explicitly NOT build. Common mistakes that hurt UX.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Tabs within tabs** | Deeply nested navigation is disorienting. Users lose track of where they are | Keep flat tab structure. Use collapsible sections within tabs |
| **Auto-save without indication** | Silent saves make users uncertain. "Did my change apply?" anxiety | Keep explicit OK/Cancel/Apply. Current pattern is correct |
| **Settings that require restart without warning** | User changes something, nothing happens, frustration builds | Show "Requires restart" badge next to affected settings. Current locale change already hints at this |
| **Overwhelming advanced options** | Dumping all options in one flat list. VLC "All settings" mode is a cautionary tale | Progressive disclosure: basic settings visible, advanced behind "Show advanced" toggle |
| **Modal dialog blocking preview** | Can't see the effect of video/audio changes while settings are open | If implementing live preview, use non-modal overlay or split-pane approach |
| **Technical jargon in labels** | "Hardware acceleration" means nothing to most users. "Use GPU for faster playback" is clearer | Audit labels for user-friendly language. Tooltip for technical details |
| **Too many tabs** | More than 5-6 tabs forces users to scan linearly. Current 7 is borderline | Consider consolidating: merge Audio+Equalizer, merge Video+Performance |
| **Settings search without highlighting** | Search that finds results but doesn't show where they are is useless | If adding search, highlight matching settings and auto-scroll to them |

## Feature Dependencies

```
Settings search → requires flat or shallow tab structure (current 7 tabs works)
Live preview → requires non-modal dialog (blocks current modal pattern)
Import/export → requires SettingsStore serialization (already JSON-based)
Settings presets → requires import/export as foundation
Per-file settings → requires preset system + file-level persistence
```

## MVP Recommendation

For the settings panel refactoring, prioritize:

1. **Reset to defaults (per section)** - Low effort, high trust value
2. **Consolidate tabs** - Merge Audio+Equalizer, consider merging Video+Performance. Reduces 7 tabs to 5
3. **Settings search** - Medium effort, significant usability improvement for 7-tab panel
4. **Keyboard shortcut conflict detection** - Low effort, prevents broken bindings

Defer:
- **Live preview**: Requires non-modal dialog redesign. High effort, moderate value
- **Import/export**: Power user feature. Can add later without changing core UX
- **Per-file settings**: Complex persistence. Not needed for panel refactoring
- **Settings presets**: Builds on import/export. Second phase feature

## Sources

- VLC Media Player: Simple/Advanced settings toggle pattern
- mpv: Minimal UI philosophy, config file approach
- PotPlayer: Context menus, per-file settings, tree-based navigation
- macOS System Settings: Search-first, instant apply, single-column scroll
- Windows 11 Settings: Hub-and-spoke, breadcrumbs, categorized sidebar
- VS Code: Settings search, JSON fallback, sidebar navigation
- Material Design 3: Settings guidelines, NavigationRail for desktop
