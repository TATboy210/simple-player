# Codebase Structure

**Analysis Date:** 2026-08-21

## Directory Layout

```
simple_player_flutter/
├── lib/                          # Application source (Dart)
│   ├── main.dart                 # Composition root — MediaKit/windowManager/KernelLogger init, runApp
│   ├── app.dart                  # MaterialApp shell — theme, localization, splash→player home
│   ├── features/                 # Feature modules (View layer of MVVM)
│   │   └── player/               # Player feature module (deferred-loaded)
│   ├── kernel/                   # Core logic — no UI, no Flutter widget imports (except ValueNotifier)
│   │   ├── engine/               # Media engine abstraction + media_kit implementation
│   │   ├── window_Bridge/        # Window management abstraction + coordinators
│   │   ├── services/             # Service layer (orchestration, file ops, thumbnails)
│   │   ├── diagnostics/          # Logging, memory monitoring, resize probes
│   │   ├── persistence/          # SharedPreferences-backed storage
│   │   ├── startup/              # StartupCoordinator + StartupState
│   │   ├── models/               # Domain data classes (PlaylistItem, PlayMode, PlayerError, etc.)
│   │   ├── playlist/             # Legacy playlist model (retained, not wired in v1.8)
│   │   ├── scanner/              # Folder scanner (legacy, not wired in v1.8)
│   │   ├── utils/                # Time/path utilities, debug probes
│   │   └── player_services.dart  # DI container (PlayerServices)
│   ├── ui/                       # Widget tree (Flutter UI)
│   │   ├── player/               # Player screen + control bar + keyboard + OSD
│   │   ├── playlist/             # Playlist panel (legacy, not wired in v1.8)
│   │   ├── window/               # Custom window title bar
│   │   ├── shared/               # Reusable glass widgets, empty state, splash
│   │   ├── dialogs/              # Media info dialog (+ settings overlay legacy)
│   │   ├── theme/                # Design tokens (Tokens.* const)
│   │   └── widgets/              # Misc widgets (OSD overlay)
│   └── l10n/                     # Localization (ARB + generated AppLocalizations)
├── test/                         # Test suites (unit/widget/integration/golden/regression)
│   ├── unit/                     # Pure unit tests (no Flutter bindings)
│   ├── widget/                   # Widget tests (flutter_test)
│   ├── integration/              # Integration tests (cross-component flows)
│   ├── golden/                   # Golden image tests
│   ├── kernel/                   # Kernel-layer tests (engine, services, security, startup)
│   ├── features/                 # Feature-layer tests
│   ├── diagnostics/              # Logger/memory tests
│   ├── engine/                   # Engine mixin/capability tests
│   ├── ui/                       # UI widget tests
│   ├── debug/                    # Debug tooling tests
│   ├── regression/               # Regression suites (smoke, high-risk)
│   └── helpers/                  # Test doubles (fake_engine, fake_window_service, etc.)
├── windows/                      # Windows native runner (CMakeLists, flutter_window, win32_window)
├── assets/                       # Fonts (Noto Sans SC)
├── .planning/                    # GSD planning documents + debug notes
├── pubspec.yaml                  # Flutter/Dart dependencies
├── analysis_options.yaml         # Strict analyzer config (strict-casts, strict-inference, strict-raw-types)
└── CLAUDE.md                     # Project instructions for Claude
```

## Directory Purposes

**`lib/features/`:**
- Purpose: Feature modules grouped by domain — MVVM View layer
- Contains: StatefulWidget views + coordinators + per-feature models
- Key files: `lib/features/player/player_feature.dart`, `lib/features/player/deferred_player_feature.dart`, `lib/features/player/file_picker_coordinator.dart`

**`lib/kernel/engine/`:**
- Purpose: Media playback abstraction (ISP-decomposed) + concrete media_kit implementation
- Contains: 7 ISP interfaces, `MediaEngine` composite, `MediaKitEngine` impl, `EngineStateMachine`, `OpenResult` sealed class, `MediaInfo` models
- Key files: `lib/kernel/engine/media_engine.dart`, `lib/kernel/engine/media_kit_engine.dart`, `lib/kernel/engine/engine_state_machine.dart`, `lib/kernel/engine/engine_state.dart` (barrel export)

**`lib/kernel/window_Bridge/`:**
- Purpose: Native window management abstraction (fullscreen/maximize/resize/persistence) decoupled from window_manager package
- Contains: `WindowBridge` interface, `WindowService` impl, `WindowServiceState` mutable container, 3 sub-coordinators
- Key files: `lib/kernel/window_Bridge/window_manager_service.dart`, `lib/kernel/window_Bridge/window_service_state.dart`, `lib/kernel/window_Bridge/window_bridge.dart`, `lib/kernel/window_Bridge/window_constants.dart`

**`lib/kernel/services/`:**
- Purpose: Service layer — orchestration facade, file ops, thumbnails, subtitle, track prefs, validation
- Contains: `PlaybackController` (facade), `PlaybackStateManager`, `SubtitleService`, `TrackPreferenceService`, `ThumbnailService`, `PathValidator`, `InputModeDetector`
- Key files: `lib/kernel/services/playback_controller.dart`, `lib/kernel/services/playback_state_manager.dart`

**`lib/kernel/diagnostics/`:**
- Purpose: Cross-cutting diagnostics — logging, memory monitoring, resize frame metrics
- Contains: `KernelLogger` facade + sinks (DevTools/DebugPrint/Null/Composite), `MemoryMonitor`, `ResizeFrameMetrics`, `VideoTextureResizeProbe`, `Clock`, `RssProvider`
- Key files: `lib/kernel/diagnostics/kernel_logger.dart`, `lib/kernel/diagnostics/video_texture_resize_probe.dart`

**`lib/kernel/persistence/`:**
- Purpose: SharedPreferences-backed state persistence (window geometry)
- Contains: `WindowPersistence`, `PersistedWindowState`, legacy `PlaylistStore`
- Key files: `lib/kernel/persistence/window_persistence.dart`

**`lib/kernel/startup/`:**
- Purpose: Startup phase tracking + progress reporting to UI splash
- Contains: `StartupCoordinator`, `StartupState` (ValueNotifier), `StartupPhase` enum
- Key files: `lib/kernel/startup/startup_coordinator.dart`, `lib/kernel/startup/startup_state.dart`

**`lib/kernel/models/`:**
- Purpose: Domain data classes — pure Dart, no Flutter dependency
- Contains: `PlaylistItem`, `PlayMode`, `PlayerError` (sealed), `MediaInfo`-adjacent types, `AspectRatioMode`, `TrackPreferences`, `ValidationError`
- Key files: `lib/kernel/models/player_error.dart`, `lib/kernel/models/playlist_item.dart`

**`lib/ui/player/`:**
- Purpose: Player screen widget tree — video surface, control bar, keyboard handler, OSD, drop handler
- Contains: `PlayerScreen`, `PlayerVideoControls` (path B control layer), `ControlBar` + layout/actions/view-model, `KeyboardHandler`, `PlayerActions`, `PlayerKeyboardActions`, `ProgressBar`, `VolumeControls`, `SpeedButton`, `DropHandler`, `VideoSurface`, `AutoHideController`, `ErrorBanner`, `MediaKitPlayerPort`/`VideoControlsPort`
- Key files: `lib/ui/player/player_screen.dart`, `lib/ui/player/player_video_controls.dart`, `lib/ui/player/control_bar.dart`, `lib/ui/player/control_bar_layout.dart`, `lib/ui/player/player_actions.dart`

**`lib/ui/shared/`:**
- Purpose: Reusable widgets across features — glass-morphism, empty state, splash, section headers
- Contains: `GlassContainer`, `EmptyState`, `ProgressSplashScreen`, `OsdOverlay`, `EdgeGlow`, `AuroraBackground`, `ControlBarDecoration`, `AppDialog`, `AppTooltip`, `MergedListenable`, `ValueListenableBuilder2`, `AnimatedSectionList`, `SpinControl`, `GlassChip`, `GlassWidgets`
- Key files: `lib/ui/shared/glass_container.dart`, `lib/ui/shared/empty_state.dart`, `lib/ui/shared/progress_splash_screen.dart`

**`lib/ui/theme/`:**
- Purpose: Design system tokens — single compile-time const theme
- Contains: `Tokens` class with static constants for colors, spacing, radius, durations, control bar dimensions
- Key files: `lib/ui/theme/tokens.dart`

**`lib/l10n/`:**
- Purpose: Localization — ARB templates + generated Dart bindings
- Contains: `app_en.arb`, `app_zh.arb` (source), `app_localizations.dart` + `_en.dart` + `_zh.dart` (generated)
- Key files: `lib/l10n/app_zh.arb` (default locale source)

**`test/helpers/`:**
- Purpose: Test doubles — hand-written fakes (not mocks) for complex dependencies
- Contains: `FakeEngine`, `FakePlayerControls`, `FakeVideoControls`, `FakeWindowService`, `IntegrationHelpers`
- Key files: `test/helpers/fake_engine.dart`, `test/helpers/fake_window_service.dart`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Dart `main()` — composition root, platform init, runApp
- `lib/app.dart`: `App` widget — MaterialApp shell, theme, splash→home
- `lib/features/player/deferred_player_feature.dart`: Deferred module loader
- `windows/runner/main.cpp`: Native Windows entry (C++)

**Configuration:**
- `pubspec.yaml`: Flutter/Dart dependencies, fonts, MSIX config
- `analysis_options.yaml`: Strict analyzer (strict-casts, strict-inference, strict-raw-types)
- `windows/CMakeLists.txt`: Windows native build config

**Core Logic:**
- `lib/kernel/player_services.dart`: DI container (`PlayerServices`)
- `lib/kernel/services/playback_controller.dart`: Playback facade
- `lib/kernel/engine/media_kit_engine.dart`: Sole engine impl
- `lib/kernel/engine/engine_state_machine.dart`: State + generation guard
- `lib/kernel/window_Bridge/window_manager_service.dart`: Window service
- `lib/kernel/window_Bridge/window_service_state.dart`: Window sub-coordinators

**UI Composition:**
- `lib/ui/player/player_screen.dart`: Main screen
- `lib/ui/player/player_video_controls.dart`: Path B control layer
- `lib/ui/player/player_actions.dart`: Stable callback bundle
- `lib/ui/window/custom_title_bar.dart`: Frameless title bar

**Testing:**
- `test/kernel/player_services_test.dart`: DI container tests
- `test/kernel/engine/media_kit_engine_test.dart`: Engine tests
- `test/kernel/engine/engine_state_machine_test.dart`: State machine tests
- `test/kernel/services/playback_controller_test.dart`: Facade tests
- `test/helpers/fake_engine.dart`: Test double for MediaEngine

## Naming Conventions

**Files:**
- `snake_case.dart` (Dart convention) — e.g., `playback_controller.dart`, `media_kit_engine.dart`, `window_manager_service.dart`
- Interface files: bare concept name — `media_engine.dart`, `window_bridge.dart`, `playback_control.dart`
- Implementation files: concrete name — `media_kit_engine.dart`, `window_manager_service.dart`
- Test files: mirror source path under `test/` + `_test.dart` suffix — e.g., `test/kernel/services/playback_controller_test.dart`
- Barrel files: aggregate concept — `engine_state.dart` re-exports all ISP interfaces

**Directories:**
- `snake_case` — `window_Bridge` is the sole exception (capital B, legacy naming retained during v1.8 refactor)
- Feature/domain grouping: `kernel/engine/`, `kernel/services/`, `ui/player/` (not by type like `models/` or `widgets/` at top level)

**Classes/Types:**
- `PascalCase` — `PlayerServices`, `MediaKitEngine`, `PlaybackController`, `WindowService`
- Interfaces: `MediaEngine`, `WindowBridge`, `PlaybackControl`, `EngineStateView` (no `I` prefix)
- Sealed result types: `OpenResult` with subtypes `OpenSuccess`/`OpenError`/`OpenSuperseded`
- ViewModels: `ControlBarViewModel`, `PlayerControlsState`
- Coordinators: `WindowModeCoordinator`, `WindowResizeCoordinator`, `WindowPersistenceCoordinator`

**Private members:** `_` prefix — `_player`, `_stateMachine`, `_controller`, `_disposed`

## Where to Add New Code

**New Feature (with UI):**
- Primary code: `lib/features/<feature>/` (new directory) or `lib/ui/<feature>/` (widget-only)
- Feature entry: StatefulWidget in `lib/features/<feature>/<feature>_feature.dart`
- Wire into `lib/app.dart` `_buildPlayerHome` or a new route
- Tests: `test/features/<feature>/` + `test/widget/<feature>/`

**New Engine Control Facet (ISP):**
- Interface: new file in `lib/kernel/engine/<facet>_control.dart` (e.g., `audio_filter_control.dart`)
- Add to `MediaEngine implements` list in `lib/kernel/engine/media_engine.dart`
- Implement in `MediaKitEngine` (`lib/kernel/engine/media_kit_engine.dart`)
- Export via barrel `lib/kernel/engine/engine_state.dart`
- Test: `test/kernel/engine/`

**New Service (orchestration):**
- Implementation: `lib/kernel/services/<service_name>.dart`
- Construct in `PlayerServices._initOnce()` (`lib/kernel/player_services.dart:118`) — add field, init step, dispose in reverse order
- Inject into `PlaybackController` or `PlayerFeature` as needed
- Test: `test/kernel/services/<service_name>_test.dart`

**New Window Coordinator:**
- Implementation: add coordinator class in `lib/kernel/window_Bridge/window_service_state.dart` (co-located with existing coordinators)
- Wire in `WindowService` (`lib/kernel/window_Bridge/window_manager_service.dart`)
- Test: `test/kernel/bridge/` or `test/unit/bridge/`

**New UI Widget (player controls):**
- Implementation: `lib/ui/player/<widget_name>.dart`
- Compose in `PlayerVideoControls._buildControlBar()` or `_buildControls` builder
- Use `Tokens.*` for all visual values — no hardcoded colors/spacing
- Test: `test/widget/player/<widget_name>_test.dart`

**New Reusable Widget:**
- Implementation: `lib/ui/shared/<widget_name>.dart`
- Test: `test/widget/shared/<widget_name>_test.dart`

**New Test Double:**
- Fake: `test/helpers/fake_<name>.dart` (implement interface, hand-written)
- Follow `FakeEngine` / `FakeWindowService` patterns (constructor-injectable, no native deps)

**New Localization Key:**
- Add to `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`
- Run `flutter gen-l10n` (or `flutter pub get` with `generate: true`)
- Access via `AppLocalizations.of(context).<key>`

**New Design Token:**
- Add static const to `Tokens` class in `lib/ui/theme/tokens.dart`
- Document purpose in doc comment
- Never inline literal values in widgets

## Special Directories

**`windows/`:**
- Purpose: Windows native runner (CMake build, win32 window, flutter_window)
- Generated: Partially (runner scaffolded by Flutter, `CMakeLists.txt` hand-modified for WM_NCHITTEST)
- Committed: Yes

**`.planning/`:**
- Purpose: GSD planning documents, phase plans, debug notes
- Generated: No (authored by GSD commands + humans)
- Committed: Mixed (codebase maps committed; debug notes `.planning/debug/` untracked)

**`assets/fonts/`:**
- Purpose: Noto Sans SC font family (Regular/Medium/SemiBold)
- Generated: No
- Committed: Yes

**`test/golden/`:**
- Purpose: Golden image reference files for visual regression
- Generated: Yes (via `flutter test --update-goldens`)
- Committed: Yes

**`lib/l10n/` (generated files):**
- Purpose: `app_localizations*.dart` are generated from ARB
- Generated: Yes (by `flutter gen-l10n`)
- Committed: Yes

---

*Structure analysis: 2026-08-21*
