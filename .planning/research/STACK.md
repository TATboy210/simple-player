# Technology Stack — Settings Panel Refactoring

**Project:** Simple Player Flutter
**Researched:** 2026-07-12
**Scope:** Desktop settings panel patterns, glassmorphism, form state, persistence

## Recommended Stack

### Settings Panel Layout

| Technology | Purpose | Why |
|------------|---------|-----|
| `Row` + `SizedBox` + `Expanded` | Sidebar-content master-detail | Flutter's canonical desktop layout pattern; already proven in your codebase |
| `AnimatedSwitcher` | Tab content transitions | Already in use; lightweight, no external dependency |
| `ListView` | Scrollable tab content | Each tab uses ListView for overflow handling; standard Flutter approach |

**Recommendation: Keep sidebar navigation.** Your current 72px icon-label sidebar is the correct pattern for desktop settings. Flutter's official adaptive layout tutorial confirms `Row([SizedBox(sidebar), VerticalDivider, Expanded(content)])` as the standard desktop master-detail pattern.

**Sidebar width consideration:** 72px is compact. For 7 tabs with icon+label, 80-100px improves readability without wasting space. Your `SettingsNavItem` at 64px content width is tight for localized labels (e.g., "视频处理" in Chinese).

### Glassmorphism UI Components

| Component | Version | Purpose | Status |
|-----------|---------|---------|--------|
| `BackdropFilter` + `ImageFilter.blur()` | Flutter built-in | Frosted glass blur effect | Already implemented in `GlassContainer` |
| `RepaintBoundary` | Flutter built-in | Isolate glass repaints | Already used in `GlassContainer` |
| `ClipRRect` | Flutter built-in | Rounded glass edges | Already used |

**Your `GlassContainer` is already well-optimized.** Key performance patterns already in place:
- Cached `ImageFilter` instances (`GlassTier` enum with static final filters)
- `RepaintBoundary` wrapping
- Blur skip when `opacity < 0.01`
- Blur skip during window resize
- Three-tier blur hierarchy (thin/normal/thick)

**Impeller note:** Flutter 3.19+ optimized gaussian blur to scale down before applying. Desktop Impeller is maturing. Your current approach is forward-compatible — no changes needed.

### Form State Management (No Provider/Riverpod)

| Pattern | When to Use | Your Current Usage |
|---------|-------------|-------------------|
| `ValueNotifier<T>` + `ValueListenableBuilder` | Single-value reactive state | Correct — used throughout |
| `ChangeNotifier` | Multi-field coordinated state | Not currently used; could unify tab state |
| Deferred apply (pending values) | Settings that cause rebuilds (locale, theme) | Already implemented in SettingsPanel |
| Immediate apply | Settings that don't cause rebuilds (video, audio, perf) | Already implemented per-tab |

**Recommendation: Hybrid deferred/immediate pattern.** Your current approach is correct:
- Locale and theme: deferred (pending values, commit on OK/Apply)
- Video/audio/performance: immediate (ValueNotifier override, auto-persist)
- Shortcuts: deferred (restore on cancel)

**For complex tabs with multiple coordinated fields**, consider a `ChangeNotifier` subclass per tab:

```dart
/// Example: if VideoTab gains more coordinated fields
class VideoSettingsDraft extends ChangeNotifier {
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;

  double get brightness => _brightness;
  set brightness(double v) { _brightness = v; notifyListeners(); }

  // ... other fields

  /// Snapshot for cancel restoration
  VideoSettingsDraft copy() => VideoSettingsDraft()
    .._brightness = _brightness
    .._contrast = _contrast
    .._saturation = _saturation;
}
```

**However**, your current per-field `ValueNotifier` approach is simpler and sufficient for 7 tabs with 1-5 controls each. Only refactor to `ChangeNotifier` if a tab exceeds ~8 coordinated fields.

### Settings Persistence

| Technology | Purpose | Why |
|------------|---------|-----|
| `shared_preferences` ^2.5.5 | Key-value persistence | Already in use; platform-native (Registry on Windows, NSUserDefaults on macOS) |
| `SettingsStore` | Persistence facade | Already well-designed: prewarm, try-catch, validation |
| `SettingsValidator` | Input sanitization | Already extracted; pure functions, no I/O |
| `AppSettings` | Immutable data model | Already implemented with `copyWith` sentinel pattern |

**Keep `shared_preferences`.** For a desktop media player with ~25 settings keys, `shared_preferences` is the right choice. Alternatives like Hive or Isar add complexity without proportional benefit for simple key-value settings.

**Your `SettingsStore` patterns are exemplary:**
- `prewarm()` avoids repeated `getInstance()` platform I/O
- `_saveImpl()` generic helper eliminates boilerplate
- `SettingsValidator` pure functions for boundary enforcement
- Sequential writes (not `Future.wait`) for data consistency
- Try-catch with fallback defaults in every `load` method

### Supporting Libraries

| Library | Version | Purpose | Recommendation |
|---------|---------|---------|----------------|
| `shared_preferences` | ^2.5.5 | Settings persistence | Keep — already integrated |
| `window_manager` | ^0.5.2 | Window control | Keep — already integrated |
| `animations` | any | Material motion | Already in pubspec; consider for tab transitions |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Layout | Sidebar + Expanded | `NavigationRail` | NavigationRail adds Material 3 chrome you don't need; your custom `_Sidebar` is lighter and matches your dark theme |
| Layout | Sidebar + Expanded | TabBar (top tabs) | Desktop convention is sidebar for settings (VS Code, macOS System Settings, Windows Settings) |
| Layout | Sidebar + Expanded | Stepper | Stepper implies sequential flow; settings are independent sections |
| State | ValueNotifier | Riverpod/Provider | Overkill for 7 tabs with 1-5 controls; adds dependency + learning curve |
| State | ValueNotifier | Bloc | Same — unnecessary ceremony for this scale |
| Persistence | SharedPreferences | Hive | Hive adds TypeAdapter complexity; you only store primitives |
| Persistence | SharedPreferences | Isar | Full database for key-value is overkill |
| Glassmorphism | Custom GlassContainer | glass_kit / frosted_glass | Your implementation is more optimized (cached filters, tier system, resize skip) than generic packages |

## Key Patterns from Codebase Analysis

### Pattern 1: Deferred Apply (Already Implemented)

Settings that trigger `MaterialApp` rebuilds (locale, theme) must be deferred:

```dart
// In SettingsPanel
late String _pendingLocale;    // draft
late String _originalLocale;   // for cancel

void _commitChanges() {
  if (_pendingLocale != _originalLocale) {
    LocaleService.I.setLocale(_pendingLocale);
  }
}

void _cancel() {
  if (_pendingLocale != _originalLocale) {
    LocaleService.I.setLocale(_originalLocale);
  }
  Navigator.of(context).pop();
}
```

### Pattern 2: Bridging ValueNotifier (Already Implemented)

For settings that persist immediately via engine API, use a `ValueNotifier` subclass that overrides the setter:

```dart
// From PerformanceTab
class _D3d11SyncNotifier extends ValueNotifier<bool> {
  final EngineState _engine;

  _D3d11SyncNotifier(this._engine, {required bool initialValue})
    : super(initialValue);

  @override
  set value(bool newValue) {
    SettingsStore.saveD3d11SyncEnabled(newValue);  // persist
    _engine.setD3d11SyncEnabled(newValue);          // apply to engine
    super.value = newValue;                          // notify UI
  }
}
```

### Pattern 3: GlassContainer Composition (Already Implemented)

Every tab follows the same structure:

```dart
ListView(
  padding: EdgeInsets.zero,
  children: [
    GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: Tokens.spLg, vertical: Tokens.spMd),
      margin: EdgeInsets.only(bottom: Tokens.spMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: '...', icon: Icons.xxx),
          SettingRow(...),
          SettingSwitchRow(...),
        ],
      ),
    ),
  ],
)
```

### Pattern 4: Drag Debounce in Sliders (Already Implemented)

VideoTab's `_VideoSlider` uses local `_dragValue` + `Timer` debounce to decouple drag UI from engine updates:

```dart
onChanged: (v) {
  setState(() { _dragging = true; _dragValue = v; });
  _debounce?.cancel();
  _debounce = Timer(Duration(milliseconds: 50), () => widget.onChanged(v));
},
onChangeEnd: (_) => setState(() => _dragging = false),
```

## Gaps Identified in Current Implementation

### 1. Sidebar Width (Minor)

72px sidebar with 64px content is tight for some localized labels. Consider 80-100px.

### 2. Tab Key Stability (Minor)

`ValueKey(index)` on each tab widget is correct for `AnimatedSwitcher`. Already implemented.

### 3. Missing Scrollbar in Tab Content

Long tabs (ShortcutsTab with 15 rows, VideoTab with 4 sliders + 3 sections) may need explicit `Scrollbar` widget wrapping the `ListView`.

### 4. No Unsaved Changes Guard

If user modifies shortcuts or video settings, then clicks the backdrop to close, changes are lost without confirmation. Consider a "unsaved changes" check before allowing backdrop dismiss.

### 5. Tab Content Height Inconsistency

Some tabs (AboutTab) are short and could look sparse in a 480px dialog. Consider `shrinkWrap: true` or `mainAxisSize: MainAxisSize.min` for short tabs.

## Sources

- Flutter official adaptive layout tutorial: Row + SizedBox + Expanded sidebar pattern
- Flutter 3.19 release notes: Impeller gaussian blur optimization
- Flutter API reference: BackdropFilter, RepaintBoundary, ImageFilter
- Existing codebase: SettingsPanel, GlassContainer, SettingsStore, SettingsValidator, all tab files
