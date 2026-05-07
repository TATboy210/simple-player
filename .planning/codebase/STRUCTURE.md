# Codebase Structure

**Analysis Date:** 2026-05-07

## Directory Layout

```
simple_player_flutter/
├── lib/
│   ├── main.dart                 # Entry point (fvp init, SharedPreferences, PlatformService)
│   ├── app.dart                  # App shell (MaterialApp, engine/service init)
│   ├── kernel/                   # All business logic (no UI)
│   │   ├── engine/               # Media playback abstraction + fvp/MDK implementation
│   │   ├── models/               # Data classes and enums (pure Dart)
│   │   ├── persistence/          # Settings and playlist storage
│   │   ├── platform/             # Platform-specific service implementations
│   │   ├── playlist/             # Playlist state machine
│   │   ├── services/             # Business orchestration + cross-cutting services
│   │   ├── ui/
│   │   │   └── theme/            # Design tokens and ThemeData
│   │   ├── utils/                # Pure utility functions
│   │   └── window/               # Window management + aspect ratio
│   ├── l10n/                     # Internationalization (zh/en)
│   ├── models/                   # [LEGACY] Old PlaylistItem (use kernel/models/ instead)
│   └── utils/                    # [LEGACY] Old time_utils (use kernel/utils/ instead)
├── test/
│   ├── helpers/                  # Test doubles (FakeEngine)
│   ├── kernel/                   # Kernel tests (mirrors lib/kernel/ structure)
│   └── unit/                     # Additional unit tests (perf, platform, engine extensions)
├── windows/                      # Windows platform runner + CMake
├── android/                      # Android platform
├── ios/                          # iOS platform
├── web/                          # Web platform
├── packaging/                    # Packaging scripts (linux)
├── production/                   # Production artifacts (session-logs)
├── pubspec.yaml                  # Package manifest
├── analysis_options.yaml         # Linter config (flutter_lints)
└── l10n.yaml                     # Localization config
```

## Directory Purposes

**`lib/kernel/engine/`:**
- Purpose: Media playback engine abstraction and concrete fvp/MDK implementation
- Contains: `MediaEngine` (abstract), `FvpEngine` (concrete), `FvpCallbackHandler`, `PositionPoller`, `TrackManager`
- Key files: `lib/kernel/engine/media_engine.dart`, `lib/kernel/engine/fvp_engine.dart`

**`lib/kernel/models/`:**
- Purpose: Pure data classes and enums with no external dependencies
- Contains: `MediaState` (9-state enum), `MediaInfo`/`AudioTrackInfo`/`SubtitleTrackInfo`/`VideoCodecInfo`, `PlaylistItem`, `PlayMode` (4 modes), `AspectRatioMode` (6 modes), `VideoEffectType`
- Key files: `lib/kernel/models/media_state.dart`, `lib/kernel/models/playlist_item.dart`

**`lib/kernel/services/`:**
- Purpose: Business orchestration and cross-cutting service interfaces
- Contains: `PlaybackController` (3 mixins: FileOperations, PlaybackNavigator, StateMonitor), `VideoProcessingService`, `PathValidator`, `PlatformService` (abstract)
- Key files: `lib/kernel/services/playback_controller.dart`, `lib/kernel/services/path_validator.dart`

**`lib/kernel/playlist/`:**
- Purpose: Playlist state machine with navigation and serialization
- Contains: `Playlist` class (4 play modes, CQS navigation, JSON round-trip)
- Key files: `lib/kernel/playlist/playlist.dart`

**`lib/kernel/persistence/`:**
- Purpose: Settings and playlist persistence
- Contains: `SettingsStore` (SharedPreferences, 22 settings keys), `PlaylistStore` (JSON file, 300ms debounce, atomic write)
- Key files: `lib/kernel/persistence/settings_store.dart`, `lib/kernel/persistence/playlist_store.dart`

**`lib/kernel/platform/`:**
- Purpose: Platform-specific implementations of abstract service interfaces
- Contains: `WindowsPlatformService` (delegates to WindowManagerService)
- Key files: `lib/kernel/platform/windows_platform_service.dart`

**`lib/kernel/window/`:**
- Purpose: Window management and native aspect ratio control
- Contains: `WindowManagerService` (singleton, 517 lines, frameless/fullscreen/persistence), `AspectRatioService` (MethodChannel)
- Key files: `lib/kernel/window/window_manager_service.dart`

**`lib/kernel/ui/theme/`:**
- Purpose: Design tokens and ThemeData bridge
- Contains: `Tokens` (30 compile-time const values), `AppTheme` (dark theme)
- Key files: `lib/kernel/ui/theme/tokens.dart`, `lib/kernel/ui/theme/app_theme.dart`

**`lib/kernel/utils/`:**
- Purpose: Pure utility functions with no dependencies
- Contains: `PathUtils` (basename/dirname), `time_utils` (formatMs), `MotionUtils` (reduced motion)
- Key files: `lib/kernel/utils/path_utils.dart`

**`lib/l10n/`:**
- Purpose: Generated localization files for zh/en
- Contains: `AppLocalizations`, `AppLocalizationsZh`, `AppLocalizationsEn`
- Key files: `lib/l10n/app_localizations.dart`

**`test/helpers/`:**
- Purpose: Hand-written test doubles (no mockito/codegen)
- Contains: `FakeEngine` implementing `MediaEngine` with call tracking and controllable behavior
- Key files: `test/helpers/fake_engine.dart`

**`test/kernel/`:**
- Purpose: Unit tests mirroring `lib/kernel/` structure
- Contains: Tests for all kernel modules (engine, models, persistence, playlist, services, utils, window)
- Key files: `test/kernel/services/playback_controller_test.dart`, `test/kernel/playlist/playlist_test.dart`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App bootstrap (fvp register, SharedPreferences prewarm, PlatformService init)
- `lib/app.dart`: MaterialApp shell, parallel init of engine/playlist/controller/locale

**Configuration:**
- `pubspec.yaml`: Dependencies (fvp, path_provider, file_picker, window_manager, shared_preferences, desktop_drop)
- `analysis_options.yaml`: Linter config (flutter_lints)
- `l10n.yaml`: Localization generation config

**Core Logic:**
- `lib/kernel/engine/media_engine.dart`: Abstract engine interface (13 ValueNotifiers, 20+ methods)
- `lib/kernel/engine/fvp_engine.dart`: Concrete fvp/MDK implementation (538 lines)
- `lib/kernel/services/playback_controller.dart`: Business orchestrator (3 mixins)
- `lib/kernel/playlist/playlist.dart`: Playlist state machine (310 lines)
- `lib/kernel/persistence/settings_store.dart`: Settings persistence (309 lines, 22 keys)
- `lib/kernel/window/window_manager_service.dart`: Window management (516 lines)

**Testing:**
- `test/helpers/fake_engine.dart`: Hand-written FakeEngine for all kernel tests
- `test/kernel/`: Mirror structure of `lib/kernel/` for unit tests

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart files
- Test files: `{name}_test.dart`
- Service interfaces: `{name}_service.dart`
- Concrete implementations: `{platform}_{name}_service.dart` or `{name}_impl.dart`

**Directories:**
- `snake_case` for all directories
- Feature-based grouping (engine, models, services, persistence, etc.)

**Classes:**
- `PascalCase` for classes, enums, typedefs
- Abstract interfaces: descriptive name without `I` prefix (e.g., `MediaEngine`, not `IMediaEngine`)
- Singletons: `ClassName.I` accessor pattern

**Constants:**
- `SCREAMING_SNAKE_CASE` for top-level const values in `Tokens`
- `_camelCase` for private const keys in `SettingsStore`

## Where to Add New Code

**New Playback Feature:**
- Engine method: Add to `lib/kernel/engine/media_engine.dart` (abstract) + implement in `lib/kernel/engine/fvp_engine.dart`
- Business logic: Add mixin in `lib/kernel/services/`, compose into `PlaybackController`
- Persistence: Add key/method to `lib/kernel/persistence/settings_store.dart`
- Tests: Add to `test/kernel/services/` or `test/kernel/engine/`

**New Model/Enum:**
- Data class: Add to `lib/kernel/models/`
- Enum: Add to `lib/kernel/models/`
- Tests: Add to `test/kernel/models/`

**New Platform Support:**
- Implementation: Create `lib/kernel/platform/{platform}_platform_service.dart` implementing `PlatformService`
- Registration: Call `PlatformService.init(NewPlatformService())` in `lib/main.dart`
- No UI changes needed (UI depends on abstract `PlatformService`)

**New UI Widget:**
- Widget file: Add to `lib/ui/widgets/` (not yet present in kernel)
- Theme: Use `Tokens.*` for all visual values
- State: Use `ValueListenableBuilder` with engine/service ValueNotifiers

**New Utility:**
- Pure function: Add to `lib/kernel/utils/`
- Tests: Add to `test/kernel/utils/`

## Special Directories

**`lib/models/` and `lib/utils/`:**
- Purpose: Legacy duplicates of kernel equivalents
- Generated: No
- Committed: Yes (should be deleted)
- Note: `lib/models/playlist_item.dart` is an older version without `timestamp`/`positionMs`/`durationMs`. `lib/utils/time_utils.dart` is identical to `lib/kernel/utils/time_utils.dart`.

**`test/unit/`:**
- Purpose: Additional tests outside the kernel mirror structure
- Contains: `perf/startup_parallel_init_test.dart`, `platform_service_test.dart`, `kernel/engine/media_engine_extension_test.dart`
- Note: These tests may need relocation to `test/kernel/` for consistency

**`packaging/`:**
- Purpose: Platform packaging scripts
- Contains: `linux/` directory
- Generated: No
- Committed: Yes

**`production/`:**
- Purpose: Production artifacts
- Contains: `session-logs/` directory
- Generated: Yes (runtime)
- Committed: No (should be gitignored)

---

*Structure analysis: 2026-05-07*
