# Phase 3: Reset to Defaults - Research

**Researched:** 2026-07-13
**Domain:** Flutter settings reset, ValueNotifier state management, AlertDialog patterns
**Confidence:** HIGH

## Summary

This phase adds per-tab reset buttons to the 5 settings tabs (General, Equalizer, Video, Shortcuts, Performance). The codebase already has two partial reset implementations: VideoTab's `service.resetAll()` (resets VideoProcessingState to defaults) and ShortcutsTab's `_resetAll()` (clears custom bindings). The new work unifies these into a consistent pattern: each tab gets a "恢复默认" button at the bottom, clicking shows a glass-styled confirmation dialog, and confirming resets only that tab's settings.

The default value sources are well-defined: `AppSettings` constructor parameters for most settings, `LocaleService`/`ThemeService` for General tab, `VideoProcessingState.defaults` for Video tab, empty map `{}` for Shortcuts tab (means use hardcoded defaults). No new dependencies needed -- this is pure UI + state wiring.

**Primary recommendation:** Add a `onReset` callback to each tab widget, manage reset logic in `SettingsPanel`, show a unified glass-styled `AlertDialog` confirmation dialog. Use existing `SettingsStore.save*` methods to persist defaults after reset.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Skip About and Audio tabs. About has no settings, Audio is per-file track selection (not persisted). Only add reset to 5 tabs: General, Equalizer, Video, Shortcuts, Performance.
- **D-02:** Reset button at bottom-left of each tab content area, aligned with OK/Cancel/Apply row. TextButton style with "恢复默认" text, low-profile.
- **D-03:** TextButton style, text "恢复默认" or similar, using Tokens.textSecondary color.
- **D-04:** Use AlertDialog + BackdropFilter for glass-styled confirmation dialog.
- **D-05:** Dialog title lists which settings will be reset. Confirm button uses warning color (Tokens.error or Tokens.warning).
- **D-06:** Defaults from AppSettings constructor default parameters (volume=50, speed=1.0, brightness=0, etc.) + LocaleService/ThemeService defaults (locale='zh', themeIndex=0).
- **D-07:** No new defaults.dart constants file. Reuse existing constructor defaults.
- **D-08:** General tab locale/theme reset uses deferred apply -- reset to defaults ('zh'/0) but only apply when dialog closes, consistent with existing OK/Cancel behavior.
- **D-09:** EQ reset to flat curve -- all band gains to zero (preset index 0).
- **D-10:** Shortcuts reset to app default key mappings (SettingsStore hardcoded defaults), not system-level shortcuts.
- **D-11:** After confirming reset, UI refreshes immediately to default values. No extra highlight animation.

### Claude's Discretion
None -- all decisions explicitly chosen by user.

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SUI-02 | 每个 tab 有独立的 Reset to defaults 按钮 — 用户可单独重置某个 tab 的所有设置项为默认值 | 5 tabs identified (General/EQ/Video/Shortcuts/Performance), each with clear default value sources. Existing partial resets in VideoTab and ShortcutsTab provide patterns. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Reset button UI | UI/SettingsPanel | UI/Tab widgets | Button placement in tab content area, callback to panel |
| Confirmation dialog | UI/SettingsPanel | — | Glass-styled AlertDialog, shared across all tabs |
| Default value resolution | Kernel/AppSettings | Kernel/SettingsStore | Constructor defaults are the source of truth |
| State reset + persistence | Kernel/SettingsStore | UI/Tab widgets | Each tab calls appropriate SettingsStore.save* methods |
| Locale/Theme deferred reset | UI/SettingsPanel | Kernel/Services | Panel manages pending values, applies on dialog close |

## Standard Stack

### Core (no new dependencies)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material.dart | SDK | AlertDialog, TextButton | Standard Flutter dialog |
| dart:ui | SDK | BackdropFilter for glass effect | Already used in GlassContainer |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SettingsStore | project | SharedPreferences persistence | Save default values after reset |
| AppSettings | project | Immutable settings container | Constructor defaults as reset target |
| GlassContainer | project | Glass-morphism wrapper | Dialog background styling |
| Tokens | project | Design tokens | Colors, spacing, radius |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AlertDialog + BackdropFilter | showDialog with GlassContainer | AlertDialog provides standard Material dialog structure; BackdropFilter adds glass effect |
| Per-tab reset logic in SettingsPanel | Per-tab reset in each tab widget | Centralized in panel for locale/theme deferred apply consistency |

## Package Legitimacy Audit

No new packages installed in this phase. All dependencies are existing project code or Flutter SDK.

## Architecture Patterns

### System Architecture Diagram

```
User clicks "恢复默认" button in tab
         │
         ▼
SettingsPanel._showResetDialog(tabIndex)
         │
         ▼
AlertDialog + BackdropFilter (glass style)
  ┌─────────────────────────────┐
  │  "重置 [TabName] 设置?"      │
  │  "将重置以下设置项为默认值:    │
  │   - 语言: 中文               │
  │   - 主题: 午夜"              │
  │                             │
  │  [取消]        [确认重置]    │
  └─────────────────────────────┘
         │ (user confirms)
         ▼
SettingsPanel._resetTab(tabIndex)
         │
         ├─ General: _pendingLocale='zh', _pendingThemeIndex=0
         ├─ Equalizer: engine.setEqualizer('') + reset selectedIndex
         ├─ Video: videoProcessing.resetAll()
         ├─ Shortcuts: clear bindings + notify
         └─ Performance: reset notifiers to true/true
         │
         ▼
setState() → UI rebuilds with default values
```

### Recommended Project Structure

No new files needed. Changes are in existing files:
- `lib/ui/dialogs/settings_panel.dart` — Add reset button to bottom bar, dialog logic
- `lib/ui/dialogs/settings/general_tab.dart` — Add onReset callback
- `lib/ui/dialogs/settings/equalizer_tab.dart` — Add onReset callback
- `lib/ui/dialogs/settings/video_tab.dart` — Wire existing resetAll to callback
- `lib/ui/dialogs/settings/shortcuts_tab.dart` — Wire existing _resetAll to callback
- `lib/ui/dialogs/settings/settings_tab_performance.dart` — Add onReset callback
- `lib/l10n/app_zh.arb` — Add reset-related l10n keys
- `lib/l10n/app_en.arb` — Add reset-related l10n keys

### Pattern 1: Tab Reset Callback Pattern

**What:** Each tab accepts an optional `onReset` callback. SettingsPanel provides the callback to trigger reset with confirmation.

**When to use:** When a parent widget needs to intercept and confirm an action before the child executes it.

**Example:**
```dart
// Tab widget accepts onReset callback
class EqualizerTab extends StatefulWidget {
  final EngineState engine;
  final VoidCallback? onReset;  // NEW
  const EqualizerTab({super.key, required this.engine, this.onReset});
  // ...
}

// In tab's build method, wire reset button to callback
child: TextButton(
  onPressed: widget.onReset,
  child: Text(l10n.resetToDefaults),
),

// SettingsPanel provides the callback
EqualizerTab(
  key: const ValueKey(1),
  engine: widget.engine,
  onReset: () => _showResetDialog(1),
),
```

### Pattern 2: Glass-styled Confirmation Dialog

**What:** AlertDialog with BackdropFilter for glass-morphism effect, matching the app's design language.

**When to use:** Any confirmation dialog in the settings panel.

**Example:**
```dart
Future<bool> _showResetConfirmDialog(String title, List<String> items) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => BackdropFilter(
      filter: GlassTier.normal.blurFilter,
      child: AlertDialog(
        backgroundColor: Tokens.bgGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          side: BorderSide(color: Tokens.borderHighlight),
        ),
        title: Text(title, style: TextStyle(color: Tokens.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) => Text(
            '• $item',
            style: TextStyle(color: Tokens.textSecondary),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Tokens.error),
            child: Text(l10n.confirmReset),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
```

### Anti-Patterns to Avoid

- **Reset without confirmation:** Always show confirmation dialog before resetting. Users may accidentally click.
- **Reset that doesn't persist:** After resetting in-memory state, must call SettingsStore.save* to persist.
- **Reset that doesn't refresh UI:** Must call setState() or update ValueNotifier to trigger rebuild.
- **Hardcoded default values:** Use AppSettings constructor defaults, not inline magic numbers.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Confirmation dialog | Custom dialog widget | AlertDialog + BackdropFilter | Standard Material pattern, already used in app |
| Default values | Separate defaults constants file | AppSettings constructor defaults | D-07: Reuse existing constructor defaults |
| Glass effect on dialog | Custom blur implementation | GlassContainer or BackdropFilter + GlassTier | Existing glass infrastructure |

## Common Pitfalls

### Pitfall 1: Locale/Theme Reset Timing
**What goes wrong:** Resetting locale/theme immediately triggers MaterialApp rebuild, which loses the dialog state.
**Why it happens:** LocaleService.setLocale() and ThemeService.setTheme() cause app-wide rebuild.
**How to avoid:** Use the deferred apply pattern already in SettingsPanel -- set _pendingLocale/_pendingThemeIndex, apply on dialog close via _commitChanges().
**Warning signs:** Dialog disappears after reset, or locale/theme doesn't actually change.

### Pitfall 2: EQ Preset Index vs Engine State Mismatch
**What goes wrong:** Resetting EQ preset index to 0 but not calling engine.setEqualizer('').
**Why it happens:** EqualizerTab has internal _selectedIndex state AND engine state. Both must be reset.
**How to avoid:** Reset _selectedIndex to 0 AND call widget.engine.setEqualizer('') in the reset handler.
**Warning signs:** UI shows "关闭" selected but audio still has EQ applied.

### Pitfall 3: PerformanceTab Async Loading Race
**What goes wrong:** Resetting PerformanceTab before _loadSettings() completes.
**Why it happens:** PerformanceTab loads settings asynchronously in initState. If reset is called before loading completes, _d3d11Sync/_hardwareDecoding may not be initialized.
**How to avoid:** Check _loading flag before allowing reset. Disable reset button while loading.
**Warning signs:** Null reference error on _d3d11Sync or _hardwareDecoding.

### Pitfall 4: Shortcuts Reset Doesn't Notify Parent
**What goes wrong:** ShortcutsTab clears _customBindings but doesn't call widget.onShortcutsChanged.
**Why it happens:** The existing _resetAll() does call onShortcutsChanged, but if the new pattern uses a callback, must ensure the callback chain is complete.
**How to avoid:** After clearing bindings, call widget.onShortcutsChanged?.call({}) AND SettingsStore.saveShortcuts({}).
**Warning signs:** Shortcuts appear reset in dialog but revert on next app launch.

## Code Examples

### Per-Tab Reset with Confirmation

```dart
// In SettingsPanel
void _resetTab(int index) {
  switch (index) {
    case 0: _resetGeneral(); break;
    case 1: _resetEqualizer(); break;
    case 3: _resetVideo(); break;
    case 4: _resetShortcuts(); break;
    case 6: _resetPerformance(); break;
  }
}

void _resetGeneral() {
  setState(() {
    _pendingLocale = 'zh';
    _pendingThemeIndex = 0;
  });
}

void _resetEqualizer() {
  // Engine state reset handled by tab's onReset callback
  // Tab internally resets _selectedIndex to 0 and calls engine.setEqualizer('')
}
```

### Tab Widget with Reset Button

```dart
// At the bottom of each tab's build method
Widget _buildResetButton(AppLocalizations l10n) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: Tokens.spMd),
      child: TextButton(
        onPressed: widget.onReset,
        child: Text(
          l10n.resetToDefaults,
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
          ),
        ),
      ),
    ),
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| VideoTab inline reset button | Callback to parent | Phase 2 visual upgrade | Consistent pattern for all tabs |
| ShortcutsTab inline _resetAll | Callback to parent | Phase 2 visual upgrade | Consistent pattern for all tabs |

**Deprecated/outdated:**
- VideoTab's inline InkWell reset button at bottom-right → will be replaced by callback pattern
- ShortcutsTab's inline InkWell reset button at bottom-right → will be replaced by callback pattern

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | AppSettings constructor default for volume is 1.0 (not 50) | Default Values | Volume slider range is 0-100 in UI but 0.0-1.0 in AppSettings. Context says "volume=50" but constructor shows 1.0. Need to verify actual default. |
| A2 | EqualizerTab preset index 0 = flat/disabled (empty string filter) | EQ Reset | Verified in code: _presetValues[0] = '' (disabled). LOW risk. |

## Open Questions (RESOLVED)

1. **Volume default value discrepancy** ✅ RESOLVED
   - What we know: AppSettings constructor has `volume: 1.0` (0.0-1.0 range), but UI slider shows 0-100 range. Context says "volume=50".
   - Resolution: Use AppSettings constructor default (1.0 = 100% volume). The plan uses `_resetTab()` which calls `AppSettings()` constructor defaults directly. Volume slider internally maps 0.0-1.0 to 0-100 display.

2. **Reset button visibility during loading** ✅ RESOLVED
   - What we know: PerformanceTab loads settings asynchronously.
   - Resolution: Plan disables reset button while `_loading == true` in PerformanceTab (Task 1 acceptance criteria).

## Environment Availability

> No external dependencies needed for this phase.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build | ✓ | — | — |
| SharedPreferences | Persistence | ✓ (existing) | — | — |

**Missing dependencies with no fallback:** None
**Missing dependencies with fallback:** None

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — standard Flutter test |
| Quick run command | `flutter test test/widget/settings/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SUI-02 | Reset button appears in 5 tabs | widget | `flutter test test/widget/settings/` | Partial (shortcuts_tab_test.dart, video_tab_test.dart exist) |
| SUI-02 | Confirmation dialog shows on click | widget | `flutter test test/widget/settings/reset_dialog_test.dart` | Wave 0 |
| SUI-02 | Confirm resets tab settings | widget | `flutter test test/widget/settings/reset_dialog_test.dart` | Wave 0 |
| SUI-02 | Cancel does not reset | widget | `flutter test test/widget/settings/reset_dialog_test.dart` | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/widget/settings/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before /gsd-verify-work

### Wave 0 Gaps
- [ ] `test/widget/settings/reset_dialog_test.dart` — covers SUI-02 reset confirmation flow
- [ ] Update `test/widget/settings/general_equalizer_tab_test.dart` — add reset button tests
- [ ] Update `test/widget/settings/video_tab_test.dart` — add reset callback tests
- [ ] Update `test/widget/settings/shortcuts_tab_test.dart` — add reset callback tests
- [ ] Update `test/widget/settings/audio_performance_tab_test.dart` — add reset button tests

## Security Domain

Not applicable — this phase only resets user preferences to defaults. No authentication, authorization, input validation, or cryptographic operations involved. Settings values are bounded by SettingsValidator which already exists.

## Sources

### Primary (HIGH confidence)
- `lib/kernel/models/app_settings.dart` — Constructor defaults, copyWith pattern
- `lib/kernel/persistence/settings_store.dart` — All save/load methods, SharedPreferences keys
- `lib/kernel/persistence/settings_validator.dart` — Validation bounds and defaults
- `lib/ui/dialogs/settings_panel.dart` — Tab structure, OK/Cancel/Apply pattern, deferred apply
- `lib/ui/dialogs/settings/*.dart` — All 7 tab implementations
- `lib/features/player/services/video_processing_service.dart` — Existing resetAll() pattern
- `lib/features/player/models/video_processing_state.dart` — VideoProcessingState.defaults

### Secondary (MEDIUM confidence)
- `lib/l10n/app_zh.arb` + `app_en.arb` — Existing reset-related l10n keys

### Tertiary (LOW confidence)
- Volume default value (1.0 vs 50) — needs verification against slider implementation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — No new dependencies, using existing Flutter/material patterns
- Architecture: HIGH — Clear patterns already exist in codebase (VideoTab.resetAll, ShortcutsTab._resetAll)
- Pitfalls: HIGH — Locale/theme deferred apply pattern already implemented in SettingsPanel

**Research date:** 2026-07-13
**Valid until:** 2026-08-13 (stable — settings reset is a well-understood pattern)
