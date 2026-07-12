# Architecture Patterns — Settings/Fullscreen Decoupling

**Domain:** Flutter desktop media player
**Researched:** 2026-07-12
**Scope:** Decoupling settings_panel (403 lines) from fullscreen code; decomposing settings_store (450 lines)

## Current State Assessment

### Coupling Points

```
settings_panel.dart
  └─ imports SettingsStore directly (static calls)
  └─ imports EngineState (for volume/speed/mute)
  └─ imports VideoProcessingService
  └─ imports LocaleService, ThemeService

settings_store.dart (450 lines)
  └─ 25+ static saveXXX() methods — one per field
  └─ load() returns monolithic AppSettings (26 fields)
  └─ Static singleton (_instance) with prewarm pattern
  └─ SettingsValidator (separate file) does all clamping

window_service.dart
  └─ imports SettingsStore directly for load/saveIsAlwaysOnTop
  └─ imports FullscreenDriver (injected)
  └─ owns fullscreen state (_isFullscreen ValueNotifier)

app_settings.dart (231 lines)
  └─ Single immutable class with 26 fields
  └─ copyWith with sentinel pattern for nullable fields
  └─ No domain grouping — mixes playback, window, subtitle, video
```

### Key Problem

`AppSettings` is a god-object: 26 fields spanning 5 unrelated domains (playback, window, subtitle, video, engine). `SettingsStore` mirrors this with 25+ static save methods. Any change to one domain touches the shared container. Settings panel reads/writes through the monolithic store, creating implicit coupling between unrelated settings.

Fullscreen is coupled to settings via `SettingsStore.saveIsFullscreen()` and `settings.isFullscreen` — WindowService loads settings at init, then maintains its own `_isFullscreen` notifier. Two sources of truth for fullscreen state.

## Recommended Architecture

### Decomposed Settings Model

Split `AppSettings` into domain-specific immutable config objects:

```
AppSettings (thin aggregate, kept for serialization)
├── PlaybackConfig     (volume, isMuted, playMode, playbackSpeed)
├── WindowConfig       (width, height, x, y, isMaximized, isAlwaysOnTop)
├── SubtitleConfig     (fontSize, colorIndex, bottomOffset)
├── VideoConfig        (brightness, contrast, saturation, hue, rotation, aspectRatio, deinterlace)
└── EngineConfig       (d3d11Sync, hardwareDecoding)
```

Each config is a standalone `const` class with its own `copyWith`. `AppSettings` becomes a composition of these, with a convenience `copyWith` that delegates.

**Data flow after decomposition:**

```
User changes volume in settings_panel
  → calls settingsStore.saveVolume(0.8)
  → SettingsStore persists to SharedPreferences
  → PlaybackController listens via ValueNotifier (already exists)
  → Engine applies change

User toggles fullscreen in settings_panel
  → NOT through settings_store at all
  → WindowService.enterFullscreen() called directly
  → WindowService updates _isFullscreen ValueNotifier
  → WindowService persists via WindowPersistence (separate concern)
  → SettingsPanel rebuilds via ValueListenableBuilder
```

### Settings Store Decomposition

Split `SettingsStore` (450 lines) into focused stores:

```
SettingsStore (orchestrator, ~80 lines)
  └── load() → aggregates from sub-stores
  └── saveAll(AppSettings) → delegates to sub-stores
  └── prewarm() / resetPrewarm()

PlaybackSettingsStore (~60 lines)
  └── load() → PlaybackConfig
  └── save(PlaybackConfig)

WindowSettingsStore (~80 lines)
  └── load() → WindowConfig
  └── save(WindowConfig)
  └── saveGeometry() — atomic multi-field write

SubtitleSettingsStore (~50 lines)
  └── load() → SubtitleConfig
  └── save(SubtitleConfig)

VideoSettingsStore (~80 lines)
  └── load() → VideoConfig
  └── save(VideoConfig)
```

Each store owns its SharedPreferences keys. The top-level `SettingsStore` composes them for backward compatibility.

### Fullscreen Decoupling

Fullscreen state must NOT live in settings_store. Current flow:

```
BROKEN: settings.isFullscreen → WindowService reads at init → maintains own _isFullscreen
         SettingsStore.saveIsFullscreen() → called from who-knows-where
         Two sources of truth.
```

Correct flow:

```
FIXED: WindowService owns fullscreen state entirely.
       WindowPersistence persists window mode (fullscreen/windowed).
       SettingsStore does NOT have saveIsFullscreen().
       SettingsPanel reads WindowService.isFullscreen via ValueListenableBuilder.
```

Fullscreen enters WindowService's domain (it already manages the driver). Persistence moves to `WindowPersistence` (already exists at `lib/kernel/bridge/window_persistence.dart`). `isFullscreen` is removed from `AppSettings`.

### Dependency Injection Without Packages

The codebase already uses constructor injection well (FullscreenDriver into WindowService). Extend this pattern:

```dart
// Current (good — keep this)
class WindowService {
  WindowService({
    DisplayEnumerator? displayEnumerator,
    FullscreenDriver? fullscreenDriver,
  });
}

// Settings panel — inject stores instead of static calls
class SettingsPanel extends StatefulWidget {
  final PlaybackSettingsStore playbackStore;
  final WindowSettingsStore windowStore;
  final SubtitleSettingsStore subtitleStore;
  final VideoSettingsStore videoStore;
  final EngineState engine;
  // ...
}

// Wiring point (main.dart or app.dart)
final playbackStore = PlaybackSettingsStore(prefs);
final windowStore = WindowSettingsStore(prefs);
// ... pass down through constructors
```

No InheritedWidget needed — the widget tree is shallow enough that constructor injection works. The existing `ValueNotifier + ValueListenableBuilder` pattern already serves as the reactive layer.

### Settings Panel Decomposition

Split 403-line panel into tab-specific widgets (already partially done — tabs exist in `settings/` subdirectory). The remaining work:

```
settings_panel.dart (403 → ~120 lines)
  └── Sidebar navigation + OK/Cancel/Apply logic
  └── Delegates to tab widgets (already exist)
  └── Holds pending locale/theme state (deferred apply)

settings/general_tab.dart (~100 lines)
  └── Reads PlaybackConfig + locale/theme
  └── Writes via PlaybackSettingsStore

settings/video_tab.dart (~80 lines)
  └── Reads VideoConfig
  └── Writes via VideoSettingsStore

settings/equalizer_tab.dart (~60 lines)
  └── Reads VideoConfig (brightness/contrast/saturation)
  └── Writes via VideoSettingsStore
```

The key change: tabs receive specific store instances, not the monolithic SettingsStore.

### Fullscreen Driver Layer (Already Clean)

The existing driver hierarchy is well-designed — no changes needed:

```
FullscreenDriver (abstract)
├── DesktopFullscreenDriver    (window_manager fallback)
├── WindowsFullscreenDriver    (Win32 FFI, fast path)
├── MacosFullscreenDriver      (fullscreen_window + delegate)
└── LinuxFullscreenDriver      (fullscreen_window + signals)

DesktopFullscreenDriverFactory
  └── Platform detection + compile-time flag
  └── HWND validation + graceful fallback
```

Strategy pattern is already in use. The factory handles platform selection. Keep as-is.

## Patterns to Follow

### Pattern 1: Domain-Specific Config Objects

**What:** Split monolithic settings into per-domain immutable classes.
**When:** When a data class exceeds ~10 fields from unrelated domains.
**Why:** Reduces copyWith churn, makes dependencies explicit, enables independent testing.

```dart
/// Playback-related settings — volume, mute, play mode, speed.
@immutable
class PlaybackConfig {
  final double volume;
  final bool isMuted;
  final int playMode;
  final double playbackSpeed;

  const PlaybackConfig({
    required this.volume,
    required this.isMuted,
    required this.playMode,
    required this.playbackSpeed,
  });

  PlaybackConfig copyWith({
    double? volume,
    bool? isMuted,
    int? playMode,
    double? playbackSpeed,
  }) => PlaybackConfig(
    volume: volume ?? this.volume,
    isMuted: isMuted ?? this.isMuted,
    playMode: playMode ?? this.playMode,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
  );
}
```

### Pattern 2: Store Composition

**What:** Top-level store delegates to domain stores; domain stores own their keys.
**When:** Persistence layer exceeds ~300 lines or handles unrelated domains.

```dart
class SettingsStore {
  final PlaybackSettingsStore _playback;
  final WindowSettingsStore _window;
  // ...

  Future<AppSettings> load() async {
    final playback = await _playback.load();
    final window = await _window.load();
    // ...
    return AppSettings(playback: playback, window: window, ...);
  }
}
```

### Pattern 3: Single Owner for State

**What:** One service owns each piece of state; others read via ValueNotifier.
**When:** Two classes both write to the same logical state.
**Why:** Prevents split-brain bugs.

```dart
// GOOD: WindowService is the sole owner of fullscreen state
class WindowService {
  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  // Only WindowService writes to this
}

// Settings panel reads, never writes fullscreen
class SettingsTab extends StatelessWidget {
  Widget build(context) => ValueListenableBuilder(
    valueListenable: windowService.isFullscreen,
    builder: (ctx, isFs, _) => Text(isFs ? 'Fullscreen' : 'Windowed'),
  );
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Static Singleton Store

**What:** `SettingsStore._instance` with static methods.
**Why bad:** Prevents testing with different configs, hides dependencies, makes refactoring harder.
**Instead:** Constructor-injected instances. Keep `prewarm()` for production wiring, but tests always use `SettingsStore.create(prefs)`.

### Anti-Pattern 2: Settings Saving Window State

**What:** `SettingsStore.saveIsFullscreen()` mixing window management state into user preferences.
**Why bad:** Fullscreen is a transient window state, not a user preference. App crash during fullscreen means the persisted value is stale.
**Instead:** WindowService persists its own state via WindowPersistence. Settings store handles only user preferences.

### Anti-Pattern 3: God AppSettings Object

**What:** Single class with 26 fields from 5 unrelated domains.
**Why bad:** Every change touches the class. copyWith has 26 parameters. Equality check compares all fields even when only one domain changed.
**Instead:** Compose from domain configs. AppSettings becomes a thin aggregate.

## Suggested Build Order

```
Phase A: Extract domain configs (no behavior change)
  1. Create PlaybackConfig, WindowConfig, SubtitleConfig, VideoConfig, EngineConfig
  2. AppSettings becomes composition of these (backward-compatible)
  3. All existing code still works — AppSettings API unchanged

Phase B: Split SettingsStore (no behavior change)
  1. Create PlaybackSettingsStore, WindowSettingsStore, etc.
  2. SettingsStore delegates to sub-stores
  3. Static API unchanged — existing callers unaffected

Phase C: Remove fullscreen from settings (behavioral change)
  1. Remove isFullscreen from AppSettings
  2. Remove SettingsStore.saveIsFullscreen()
  3. WindowPersistence handles fullscreen persistence
  4. Update WindowService.init() to use WindowPersistence
  5. Update settings_panel to read from WindowService.isFullscreen

Phase D: Inject stores into settings panel
  1. SettingsPanel receives store instances via constructor
  2. Each tab receives its specific store
  3. Remove direct SettingsStore static calls from UI code

Phase E: Clean up SettingsStore singleton
  1. Keep prewarm() for production
  2. All tests use constructor injection
  3. Static convenience methods become instance methods
```

**Phase ordering rationale:**
- A before B: configs must exist before stores can produce them
- B before C: store decomposition isolates the fullscreen removal blast radius
- C before D: decouple fullscreen first, then inject stores (simpler change)
- D before E: injection enables removing statics

**Estimated effort per phase:**
- A: ~2 hours (mostly mechanical extraction)
- B: ~3 hours (store split + key ownership)
- C: ~2 hours (fullscreen migration + test updates)
- D: ~2 hours (constructor injection wiring)
- E: ~1 hour (cleanup)

## Sources

- Codebase analysis of `lib/kernel/persistence/settings_store.dart` (450 lines)
- Codebase analysis of `lib/kernel/models/app_settings.dart` (231 lines)
- Codebase analysis of `lib/kernel/bridge/window_service.dart`
- Codebase analysis of `lib/kernel/bridge/fullscreen_driver.dart` and platform drivers
- Codebase analysis of `lib/ui/dialogs/settings_panel.dart` (403 lines)
