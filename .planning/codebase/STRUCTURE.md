# Codebase Structure

**Analysis Date:** 2026-05-09

## Directory Layout

```
simple_player_flutter/
├── lib/
│   ├── main.dart                    # Entry point: fvp init, prefs prewarm, platform init, runApp
│   ├── app.dart                     # App shell: engine/playlist/controller wiring, MaterialApp
│   ├── kernel/                      # All business logic (no UI widgets)
│   │   ├── engine/                  # Media playback engine abstraction + fvp/MDK impl
│   │   │   ├── media_engine.dart    # Abstract interface (13 ValueNotifiers, play/pause/seek API)
│   │   │   ├── fvp_engine.dart      # fvp/MDK implementation
│   │   │   ├── fvp_callback_handler.dart  # mdk callback → ValueNotifier mapping
│   │   │   ├── position_poller.dart # 250ms timer polling position/buffered
│   │   │   └── track_manager.dart   # Audio/subtitle track selection
│   │   ├── models/                  # Pure data classes and enums
│   │   │   ├── media_state.dart     # 9-state enum (idle/loading/playing/paused/stopped/completed/error/seeking/buffering)
│   │   │   ├── media_info.dart      # MediaInfo, AudioTrackInfo, SubtitleTrackInfo, VideoCodecInfo
│   │   │   ├── playlist_item.dart   # Data class (path + timestamp + positionMs + durationMs)
│   │   │   ├── play_mode.dart       # Enum: normal/loopAll/loopSingle/shuffle
│   │   │   ├── video_effect_type.dart  # Enum: brightness/contrast/hue/saturation
│   │   │   └── aspect_ratio_mode.dart  # Enum with mdk values: keepOriginal/stretch/cropFill/4:3/16:9/21:9
│   │   ├── persistence/             # Settings and playlist storage
│   │   │   ├── settings_store.dart  # SharedPreferences (prewarm, sanitize, 25+ keys)
│   │   │   └── playlist_store.dart  # JSON file (300ms debounce, atomic .tmp rename write)
│   │   ├── platform/                # Platform-specific service implementations
│   │   │   ├── windows_platform_service.dart  # No-op (OS provides native window)
│   │   │   └── linux_platform_service.dart    # No-op (GTK native window)
│   │   ├── playlist/                # Playlist state machine
│   │   │   └── playlist.dart        # 4 play modes, CQS navigation, JSON serialization
│   │   ├── services/                # Business orchestration
│   │   │   ├── playback_controller.dart   # Orchestrator: with FileOperations, PlaybackNavigator, StateMonitor
│   │   │   ├── file_operations.dart       # Mixin: openAndPlay, addFiles, validation
│   │   │   ├── playback_navigator.dart    # Mixin: playIndex, playNext, playPrevious, openGeneration guard
│   │   │   ├── state_monitor.dart         # Mixin: auto-advance, breakpoint save, settings restore
│   │   │   ├── platform_service.dart      # Abstract interface + singleton factory
│   │   │   └── video_processing_service.dart  # 7 ValueNotifiers for video effects, engine delegation
│   │   ├── ui/
│   │   │   └── theme/
│   │   │       ├── tokens.dart      # Design tokens (compile-time const: colors, fonts, spacing, glass, animation)
│   │   │       └── app_theme.dart   # ThemeData bridge from Tokens
│   │   └── utils/                   # Shared utilities
│   │       ├── log.dart             # Global Logger instance (PrettyPrinter)
│   │       ├── path_validator.dart  # Path security: extension whitelist, traversal detection
│   │       ├── path_utils.dart      # Cross-platform basename/dirname
│   │       ├── time_utils.dart      # formatMs() HH:MM:SS
│   │       └── motion_utils.dart    # Reduced-motion accessibility adapter
│   ├── l10n/                        # Localization (generated)
│   │   ├── app_localizations.dart
│   │   ├── app_localizations_en.dart
│   │   └── app_localizations_zh.dart
│   ├── models/                      # DEPRECATED — migrated to lib/kernel/models/
│   │   └── playlist_item.dart       # (old location, still on disk)
│   └── utils/                       # DEPRECATED — migrated to lib/kernel/utils/
│       └── time_utils.dart          # (old location, still on disk)
├── test/
│   ├── helpers/                     # Test doubles
│   │   ├── fake_engine.dart         # FakeMediaEngine implementing MediaEngine
│   │   └── fake_platform_service.dart  # FakePlatformService implementing PlatformService
│   ├── kernel/                      # Unit tests mirroring lib/kernel/ structure
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
│   │   ├── utils/
│   │   │   └── path_utils_test.dart
│   │   └── window/
│   │       ├── aspect_ratio_service_test.dart   # (deleted — service removed)
│   │       └── window_manager_service_test.dart # (deleted — service removed)
│   ├── unit/
│   │   ├── kernel/
│   │   │   └── engine/
│   │   │       └── media_engine_extension_test.dart
│   │   └── perf/
│   │       └── startup_parallel_init_test.dart
│   └── widget/
│       └── window/
│           └── custom_title_bar_test.dart       # (deleted — widget removed)
├── windows/                         # Windows platform runner
│   ├── runner/main.cpp
│   └── flutter/
│       ├── generated_plugin_registrant.cc
│       └── generated_plugins.cmake
├── linux/                           # Linux platform runner (new)
├── docs/
│   └── kernel-architecture.md       # Architecture documentation
├── .planning/                       # GSD planning artifacts
│   ├── STATE.md
│   ├── HANDOFF.json
│   └── codebase/                    # This document lives here
├── pubspec.yaml                     # Dependencies and Flutter config
├── pubspec.lock                     # Lockfile (present)
├── analysis_options.yaml            # Dart analyzer config
├── l10n.yaml                        # Localization generation config
├── CLAUDE.md                        # Project instructions for Claude
├── devtools_options.yaml            # Flutter DevTools config
└── .metadata                        # Flutter project metadata
```

## Directory Purposes

**`lib/kernel/`:**
- Purpose: ALL business logic — engine, services, persistence, models, playlist, platform, utils, theme
- Contains: Pure Dart + Flutter foundation classes. No UI widgets.
- Key files: `engine/media_engine.dart` (abstract interface), `services/playback_controller.dart` (orchestrator), `playlist/playlist.dart` (state machine)

**`lib/kernel/engine/`:**
- Purpose: Media playback engine abstraction and fvp/MDK implementation
- Contains: MediaEngine interface, FvpEngine, 3 helper classes (FvpCallbackHandler, PositionPoller, TrackManager)
- Key files: `media_engine.dart` (interface contract), `fvp_engine.dart` (implementation)

**`lib/kernel/services/`:**
- Purpose: Business orchestration and platform abstraction
- Contains: PlaybackController (3-mixin orchestrator), PlatformService (abstract), VideoProcessingService
- Key files: `playback_controller.dart` (composition root), `platform_service.dart` (singleton factory)

**`lib/kernel/persistence/`:**
- Purpose: Settings and playlist data persistence
- Contains: SettingsStore (shared_preferences), PlaylistStore (JSON file)
- Key files: `settings_store.dart` (25+ settings with sanitization), `playlist_store.dart` (debounced atomic write)

**`lib/kernel/models/`:**
- Purpose: Pure data classes and enums — no business logic, no dependencies
- Contains: MediaState, MediaInfo, PlaylistItem, PlayMode, VideoEffectType, AspectRatioMode
- Key files: `playlist_item.dart` (immutable with copyWith), `media_state.dart` (9-state enum)

**`lib/kernel/playlist/`:**
- Purpose: Playlist state machine — ordering, navigation, serialization
- Contains: Playlist class with 4 play modes, CQS peek methods, JSON round-trip
- Key files: `playlist.dart` (single file, ~315 lines)

**`lib/kernel/platform/`:**
- Purpose: Platform-specific service implementations
- Contains: WindowsPlatformService, LinuxPlatformService (both no-op currently)
- Key files: `windows_platform_service.dart`, `linux_platform_service.dart`

**`lib/kernel/ui/theme/`:**
- Purpose: Design system tokens and ThemeData bridge
- Contains: Tokens (compile-time constants), AppTheme (ThemeData builder)
- Key files: `tokens.dart` (colors, fonts, spacing, glass, animation constants)

**`lib/kernel/utils/`:**
- Purpose: Shared utility functions used across kernel
- Contains: Logger, PathValidator, PathUtils, TimeUtils, MotionUtils
- Key files: `path_validator.dart` (security-critical), `log.dart` (global logger)

**`lib/l10n/`:**
- Purpose: Generated localization files
- Contains: AppLocalizations base class + en/zh implementations
- Key files: `app_localizations_en.dart`, `app_localizations_zh.dart`

**`test/helpers/`:**
- Purpose: Test doubles for engine and platform service
- Contains: FakeMediaEngine, FakePlatformService
- Key files: `fake_engine.dart` (implements all 13 ValueNotifiers), `fake_platform_service.dart`

**`test/kernel/`:**
- Purpose: Unit tests mirroring `lib/kernel/` structure exactly
- Contains: Test files for engine helpers, models, persistence, playlist, services, utils
- Key files: Follows same directory layout as `lib/kernel/`

**`lib/models/` and `lib/utils/` (top-level):**
- Purpose: DEPRECATED — old locations before kernel restructure
- Contains: Stale files that should be removed after confirming no imports remain
- Key files: `lib/models/playlist_item.dart`, `lib/utils/time_utils.dart`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App bootstrap — fvp.registerWith(), SettingsStore.prewarm(), PlatformService.init(), runApp()
- `lib/app.dart`: App shell — creates FvpEngine, Playlist, PlaybackController; parallel init via Future.wait

**Configuration:**
- `pubspec.yaml`: Dependencies (fvp, shared_preferences, path_provider, file_picker, window_manager, desktop_drop, logger, etc.)
- `analysis_options.yaml`: Dart analyzer rules
- `l10n.yaml`: Localization generation config
- `CLAUDE.md`: Project instructions, architecture overview, conventions

**Core Logic:**
- `lib/kernel/engine/media_engine.dart`: Abstract interface contract (13 ValueNotifiers, ~176 lines)
- `lib/kernel/engine/fvp_engine.dart`: Concrete fvp/MDK implementation (~555 lines)
- `lib/kernel/services/playback_controller.dart`: 3-mixin orchestrator composition
- `lib/kernel/playlist/playlist.dart`: Playlist state machine (~315 lines)

**Testing:**
- `test/helpers/fake_engine.dart`: FakeMediaEngine — hand-written fake implementing MediaEngine
- `test/helpers/fake_platform_service.dart`: FakePlatformService — minimal fake
- `test/kernel/services/playback_controller_test.dart`: Integration test for full orchestrator
- `test/kernel/playlist/playlist_test.dart`: Comprehensive playlist state machine tests

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart files
- Descriptive names matching class name: `playback_controller.dart` contains `PlaybackController`
- Test files: `{name}_test.dart` in same relative path under `test/`

**Directories:**
- `snake_case` for all directories
- `kernel/` for core business logic
- Feature-based grouping: `engine/`, `services/`, `models/`, `persistence/`, `playlist/`, `platform/`, `utils/`, `ui/theme/`

**Classes:**
- `PascalCase` for classes, abstract classes, mixins, enums
- Mixins use descriptive names: `FileOperations`, `PlaybackNavigator`, `StateMonitor`
- Fakes prefixed with `Fake`: `FakeMediaEngine`, `FakePlatformService`

**Constants:**
- `static const` for compile-time values in `Tokens` class
- Private constants prefixed with `_`: `_prepareTimeoutSeconds`, `_pollIntervalMs`

## Where to Add New Code

**New Playback Feature (e.g., playlist sorting):**
- Logic: `lib/kernel/playlist/playlist.dart` (add method to Playlist class)
- Tests: `test/kernel/playlist/playlist_test.dart`
- Controller integration: `lib/kernel/services/state_monitor.dart` (if UI-facing)

**New Engine Capability (e.g., screenshot capture):**
- Abstract method: `lib/kernel/engine/media_engine.dart`
- Implementation: `lib/kernel/engine/fvp_engine.dart`
- Helper (if complex): `lib/kernel/engine/` (new helper class)
- Fake update: `test/helpers/fake_engine.dart`
- Tests: `test/kernel/engine/`

**New Service (e.g., bookmark service):**
- Service file: `lib/kernel/services/bookmark_service.dart`
- Persistence: `lib/kernel/persistence/bookmark_store.dart`
- Wire in: `lib/app.dart` (create instance) or `lib/kernel/services/playback_controller.dart` (if tightly coupled)
- Tests: `test/kernel/services/bookmark_service_test.dart`

**New Model/Enum:**
- File: `lib/kernel/models/{name}.dart`
- Tests: `test/kernel/models/{name}_test.dart`

**New Utility:**
- File: `lib/kernel/utils/{name}.dart`
- Tests: `test/kernel/utils/{name}_test.dart`

**New Platform Support:**
- Implementation: `lib/kernel/platform/{platform}_platform_service.dart`
- Wire in: `lib/main.dart` (add Platform.isX check)
- Tests: `test/kernel/platform/`

**New Design Token:**
- Add to: `lib/kernel/ui/theme/tokens.dart` (Tokens class)
- Reference via: `Tokens.{name}` throughout UI code

**New UI Widget:**
- Screen: `lib/ui/screens/` (currently missing — see CONCERNS.md)
- Widget: `lib/ui/widgets/`
- Use `ValueListenableBuilder` to bind to kernel ValueNotifiers
- Tests: `test/widget/`

**New Localization String:**
- ARB files: `lib/l10n/` (source .arb files)
- Generated: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart`

## Special Directories

**`lib/kernel/`:**
- Purpose: All business logic, no UI widgets
- Generated: No
- Committed: Yes
- Note: This is the canonical location for all non-UI code

**`lib/l10n/`:**
- Purpose: Generated localization files from ARB sources
- Generated: Yes (by `flutter gen-l10n`)
- Committed: Yes
- Note: Do not edit generated files manually

**`test/helpers/`:**
- Purpose: Hand-written test doubles (fakes, not mocks)
- Generated: No
- Committed: Yes
- Note: Update FakeMediaEngine when MediaEngine interface changes

**`windows/flutter/`:**
- Purpose: Flutter-generated Windows build files
- Generated: Yes (by `flutter build`/`flutter run`)
- Committed: Yes
- Note: Auto-updated when plugins change

**`linux/`:**
- Purpose: Linux platform runner (new addition)
- Generated: Partially
- Committed: Yes

**`.planning/`:**
- Purpose: GSD planning artifacts (state, handoff, codebase maps)
- Generated: By GSD commands
- Committed: Yes

**`lib/models/` and `lib/utils/` (top-level):**
- Purpose: DEPRECATED — stale files from before kernel restructure
- Generated: No
- Committed: Yes
- Note: Should be removed. Canonical locations are `lib/kernel/models/` and `lib/kernel/utils/`

---

*Structure analysis: 2026-05-09*
