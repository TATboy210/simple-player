# Codebase Structure

**Analysis Date:** 2026-05-09

## Directory Layout

```
simple_player_flutter/
├── lib/
│   ├── main.dart                          # Entry point (fvp init, window setup)
│   ├── app.dart                           # MaterialApp shell (engine + service init)
│   ├── kernel/
│   │   ├── engine/                        # Media playback engine layer
│   │   │   ├── media_engine.dart          # Abstract interface (13 ValueNotifiers)
│   │   │   ├── fvp_engine.dart            # fvp/MDK implementation
│   │   │   ├── fvp_callback_handler.dart  # mdk callback → ValueNotifier mapping
│   │   │   ├── position_poller.dart       # 250ms position polling timer
│   │   │   └── track_manager.dart         # Audio/subtitle track management
│   │   ├── models/                        # Data types and enums
│   │   │   ├── media_state.dart           # 9-state playback enum
│   │   │   ├── media_info.dart            # MediaInfo, AudioTrackInfo, SubtitleTrackInfo, VideoCodecInfo
│   │   │   ├── playlist_item.dart         # PlaylistItem data class (path + history metadata)
│   │   │   ├── play_mode.dart             # PlayMode enum (normal/loopAll/loopSingle/shuffle)
│   │   │   ├── aspect_ratio_mode.dart     # AspectRatioMode enum (6 modes with mdk values)
│   │   │   └── video_effect_type.dart     # VideoEffectType enum (brightness/contrast/hue/saturation)
│   │   ├── persistence/                   # Storage layer
│   │   │   ├── settings_store.dart        # SharedPreferences persistence (AppSettings)
│   │   │   └── playlist_store.dart        # JSON file persistence (debounced + atomic)
│   │   ├── platform/                      # Platform-specific services
│   │   │   ├── platform_service.dart      # Abstract interface (factory singleton)
│   │   │   ├── windows_platform_service.dart
│   │   │   └── linux_platform_service.dart
│   │   ├── playlist/                      # Playlist model
│   │   │   └── playlist.dart              # Ordered list + 4 play modes (CQS navigation)
│   │   ├── services/                      # Business logic layer
│   │   │   ├── playback_controller.dart   # Orchestrator (3 mixins composed)
│   │   │   ├── file_operations.dart       # File open/batch add mixin
│   │   │   ├── playback_navigator.dart    # Index jump/prev/next mixin
│   │   │   ├── state_monitor.dart         # Auto-advance/breakpoint save mixin
│   │   │   ├── video_processing_service.dart  # Reactive video effects (7 ValueNotifiers)
│   │   │   └── platform_service.dart      # Abstract platform interface (factory singleton)
│   │   ├── ui/
│   │   │   └── theme/
│   │   │       ├── tokens.dart            # Design tokens (compile-time const)
│   │   │       └── app_theme.dart         # ThemeData bridge from Tokens
│   │   └── utils/                         # Pure utility functions
│   │       ├── log.dart                   # Global Logger instance
│   │       ├── path_validator.dart        # Security: extension whitelist + path traversal
│   │       ├── path_utils.dart            # basename() / dirname() extraction
│   │       ├── time_utils.dart            # formatMs() — milliseconds to HH:MM:SS
│   │       └── motion_utils.dart          # Reduced-motion accessibility adapter
│   └── l10n/                              # Localization
│       ├── app_en.arb                     # English strings
│       ├── app_zh.arb                     # Chinese strings
│       ├── app_localizations.dart         # Generated localizations base
│       ├── app_localizations_en.dart      # Generated English
│       └── app_localizations_zh.dart      # Generated Chinese
├── test/
│   ├── helpers/                           # Test doubles
│   │   ├── fake_engine.dart               # Fake MediaEngine for unit tests
│   │   └── fake_platform_service.dart     # Fake PlatformService for unit tests
│   ├── kernel/                            # Mirror of lib/kernel/ structure
│   │   ├── engine/
│   │   │   ├── fvp_callback_handler_test.dart
│   │   │   ├── position_poller_test.dart
│   │   │   └── track_manager_test.dart
│   │   ├── models/
│   │   │   ├── aspect_ratio_mode_test.dart
│   │   │   ├── media_info_test.dart
│   │   │   └── playlist_item_test.dart
│   │   ├── persistence/
│   │   │   └── settings_store_test.dart
│   │   ├── playlist/
│   │   │   └── playlist_test.dart
│   │   ├── services/
│   │   │   ├── external_subtitle_test.dart
│   │   │   ├── file_operations_test.dart
│   │   │   ├── path_validator_test.dart
│   │   │   ├── playback_controller_test.dart
│   │   │   ├── playback_navigator_test.dart
│   │   │   ├── state_monitor_test.dart
│   │   │   └── video_processing_service_test.dart
│   │   └── utils/
│   │       └── path_utils_test.dart
│   └── unit/
│       ├── kernel/engine/
│       │   └── media_engine_extension_test.dart
│       └── perf/
│           └── startup_parallel_init_test.dart
├── pubspec.yaml                           # Dependencies and config
├── CLAUDE.md                              # Project instructions for Claude
├── .metadata                              # Flutter metadata
└── devtools_options.yaml                  # DevTools config
```

## Directory Purposes

**`lib/kernel/`:**
- Purpose: All application logic (no UI widgets). This is the "kernel" — engine, services, models, persistence, platform, utils.
- Contains: Business logic, engine abstraction, data models, persistence, platform services, utilities
- Key files: `media_engine.dart` (abstract interface), `playback_controller.dart` (orchestrator), `playlist.dart` (state machine)

**`lib/kernel/engine/`:**
- Purpose: Media playback engine abstraction and fvp/MDK implementation
- Contains: Abstract `MediaEngine` interface, `FvpEngine` concrete implementation, 3 helper classes
- Key files: `media_engine.dart` (interface contract), `fvp_engine.dart` (555 lines, largest file)

**`lib/kernel/models/`:**
- Purpose: Pure data types — no behavior, no Flutter dependency (except enums)
- Contains: Enums (`MediaState`, `PlayMode`, `AspectRatioMode`, `VideoEffectType`) and data classes (`MediaInfo`, `PlaylistItem`)
- Key files: `media_state.dart` (9-state enum), `playlist_item.dart` (immutable data class with copyWith)

**`lib/kernel/persistence/`:**
- Purpose: Storage layer — settings (SharedPreferences) and playlist (JSON files)
- Contains: `SettingsStore` (static methods, 25+ keys), `PlaylistStore` (debounced JSON + atomic write)
- Key files: `settings_store.dart` (314 lines), `playlist_store.dart` (172 lines)

**`lib/kernel/platform/`:**
- Purpose: Platform-specific behavior abstraction
- Contains: Abstract `PlatformService` interface + Windows/Linux no-op implementations
- Key files: `platform_service.dart` (factory singleton pattern)

**`lib/kernel/playlist/`:**
- Purpose: Playlist data model with play mode navigation
- Contains: `Playlist` class — ordered list, 4 play modes, CQS navigation, JSON serialization
- Key files: `playlist.dart` (315 lines)

**`lib/kernel/services/`:**
- Purpose: Business logic — playback orchestration, video processing
- Contains: `PlaybackController` (3-mixin orchestrator), `VideoProcessingService` (7 reactive notifiers)
- Key files: `playback_controller.dart` (49 lines), `file_operations.dart`, `playback_navigator.dart`, `state_monitor.dart`

**`lib/kernel/ui/theme/`:**
- Purpose: Design system constants and ThemeData
- Contains: `Tokens` (compile-time const), `AppTheme` (ThemeData bridge)
- Key files: `tokens.dart` (53 lines), `app_theme.dart` (26 lines)

**`lib/kernel/utils/`:**
- Purpose: Pure utility functions — no side effects, no Flutter dependency (except MotionUtils)
- Contains: `PathValidator` (security), `PathUtils` (basename/dirname), `TimeUtils` (formatMs), `MotionUtils` (accessibility), `log` (logger)
- Key files: `path_validator.dart` (security-critical), `log.dart` (global logger)

**`lib/l10n/`:**
- Purpose: Internationalization strings
- Contains: ARB source files + generated Dart localization classes
- Key files: `app_en.arb`, `app_zh.arb` (source), `app_localizations.dart` (generated base)

**`test/helpers/`:**
- Purpose: Test doubles for dependency injection
- Contains: `FakeEngine` (implements `MediaEngine`), `FakePlatformService` (implements `PlatformService`)
- Key files: `fake_engine.dart`, `fake_platform_service.dart`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App bootstrap — fvp.registerWith(), SharedPreferences prewarm, PlatformService init, runApp
- `lib/app.dart`: App shell — creates FvpEngine + Playlist + PlaybackController, parallel init, MaterialApp

**Configuration:**
- `pubspec.yaml`: Dependencies, SDK constraints, Flutter config
- `CLAUDE.md`: Project instructions for Claude (architecture overview, conventions, keyboard shortcuts)

**Core Logic:**
- `lib/kernel/engine/media_engine.dart`: Abstract engine interface (13 ValueNotifiers + 20+ methods)
- `lib/kernel/engine/fvp_engine.dart`: fvp/MDK engine implementation (555 lines)
- `lib/kernel/services/playback_controller.dart`: Business orchestrator (3 mixins)
- `lib/kernel/playlist/playlist.dart`: Playlist state machine (315 lines)
- `lib/kernel/persistence/settings_store.dart`: Settings persistence (314 lines)

**Testing:**
- `test/helpers/fake_engine.dart`: Fake MediaEngine for unit tests
- `test/kernel/services/`: Service-level tests (7 files)
- `test/kernel/playlist/playlist_test.dart`: Playlist model tests

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart files (Dart convention)
- No prefixes/suffixes for layers (no `_service`, `_model` suffixes — context from directory)
- Test files: `{name}_test.dart` in mirror directory structure under `test/`

**Directories:**
- `kernel/` — core application logic (no UI)
- Subdirectories by domain: `engine/`, `models/`, `persistence/`, `platform/`, `playlist/`, `services/`, `ui/`, `utils/`

**Classes:**
- `PascalCase` for classes, enums, typedefs
- Abstract interfaces: plain name (`MediaEngine`, `PlatformService`)
- Implementations: descriptive name (`FvpEngine`, `WindowsPlatformService`)
- Mixins: noun phrase (`FileOperations`, `PlaybackNavigator`, `StateMonitor`)
- Data classes: noun (`PlaylistItem`, `MediaInfo`, `AppSettings`)
- Enums: singular noun (`MediaState`, `PlayMode`, `AspectRatioMode`)

**Methods/Variables:**
- `camelCase` for all methods and variables
- Private: `_` prefix (Dart convention)
- Boolean getters: `is`/`has` prefix (`isBuffering`, `hasVideo`, `isEmpty`)
- ValueNotifiers: noun matching the state (`position`, `duration`, `volume`)

## Where to Add New Code

**New Playback Feature (e.g., new play mode):**
- Enum: `lib/kernel/models/play_mode.dart` (add value)
- Navigation logic: `lib/kernel/playlist/playlist.dart` (add case in `peekNext()`/`peekPrevious()`)
- Controller integration: `lib/kernel/services/state_monitor.dart` (update `_onStateChanged()`)
- Tests: `test/kernel/playlist/playlist_test.dart`

**New Engine Capability (e.g., new video effect):**
- Enum: `lib/kernel/models/video_effect_type.dart` (add value)
- Abstract method: `lib/kernel/engine/media_engine.dart` (add to interface)
- Implementation: `lib/kernel/engine/fvp_engine.dart` (implement in `_guardedAction`)
- Service: `lib/kernel/services/video_processing_service.dart` (add ValueNotifier + listener)
- Tests: `test/kernel/services/video_processing_service_test.dart`

**New Persistence Setting:**
- Data class: `lib/kernel/persistence/settings_store.dart` (add field to `AppSettings`, add key constant)
- Save/Load: Add `saveXxx()` static method and update `load()`/`saveAll()`
- Tests: `test/kernel/persistence/settings_store_test.dart`

**New Platform Support:**
- Implementation: `lib/kernel/platform/{platform}_platform_service.dart`
- Register: `lib/main.dart` (add Platform.isX check)
- No UI changes needed (PlatformService abstraction handles it)

**New Utility Function:**
- Pure utility: `lib/kernel/utils/{name}_utils.dart`
- Tests: `test/kernel/utils/{name}_utils_test.dart`

**New Model/Enum:**
- File: `lib/kernel/models/{name}.dart`
- Tests: `test/kernel/models/{name}_test.dart`

**New Test Helper:**
- Fake/stub: `test/helpers/fake_{name}.dart`

## Special Directories

**`lib/l10n/`:**
- Purpose: Localization ARB files and generated Dart classes
- Generated: Yes (`app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart` are generated from ARB files)
- Committed: Yes (generated files are committed)

**`test/helpers/`:**
- Purpose: Shared test doubles (FakeEngine, FakePlatformService)
- Generated: No (hand-written fakes)
- Committed: Yes

**`.planning/`:**
- Purpose: Project planning documents (architecture, codebase analysis, phases)
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-05-09*
