<!-- refreshed: 2026-06-26 -->

# Test Infrastructure

## Directory Structure

```
test/
├── features/player/services/     # Feature-layer service tests (1 file)
├── golden/                       # Golden image tests + comparator (3 files)
├── helpers/                      # Test doubles and utilities (3 files)
├── integration/                  # Integration flow tests (3 files)
├── kernel/
│   ├── bridge/                   # Window/display bridge tests (1 file)
│   ├── engine/                   # Engine component tests (4 files)
│   ├── models/                   # Model unit tests (5 files)
│   ├── persistence/              # Store tests (2 files)
│   ├── playlist/                 # Playlist logic tests (1 file)
│   ├── services/                 # Service tests (7 files)
│   ├── startup/                  # Startup coordinator tests (2 files)
│   └── utils/                    # Utility tests (5 files)
├── perf/                         # Performance benchmark tests (1 file)
├── unit/
│   ├── bridge/                   # Bridge unit tests (6 files)
│   ├── kernel/                   # Kernel unit tests (3 files)
│   └── perf/                     # Startup perf tests (1 file)
└── widget/
    ├── player/                   # Player widget tests (9 files)
    └── shared/                   # Shared widget tests (3 files)
```

## Test Counts

- **60 test files**, **~815 test/testWidgets calls**
- **115 source files** in `lib/`
- Test file ratio: ~0.52 test files per source file

## Testing Patterns

### AAA (Arrange-Act-Assert)

All tests follow Arrange-Act-Assert structure:

```dart
testWidgets('renders without error', (tester) async {
  // Arrange
  engine = FakeEngine();
  // Act
  await tester.pumpWidget(buildSubject(eng: engine));
  // Assert
  expect(find.byType(ControlBar), findsOneWidget);
});
```

### Fakes Over Mocks

Hand-written test doubles -- no Mockito dependency:

- `FakeEngine` -- implements `PlayerEngine`, all `ValueNotifier` fields with defaults
- `FakeWindowService` -- implements `WindowBridge`, tracks call counts (`modeCallCount`, `lastModeValue`)
- `integration_helpers.dart` -- shared setup for integration tests

Fakes provide:
- Call tracking via integer counters and stored last-values
- Default `ValueNotifier` state matching real implementations
- `dispose()` for cleanup in `tearDown`

### Test Naming

Descriptive `testWidgets` names describing observed behavior:
```
testWidgets('renders TimeRangeDisplay', ...)
testWidgets('shows secondary controls at width >= 500', ...)
testWidgets('hides secondary controls at width < 500', ...)
testWidgets('hides folder_open button when onOpenFile is null', ...)
```

## Widget Test Patterns

- `MaterialApp` wrapper with `theme: ThemeData.dark()` for consistent styling
- `AppLocalizations` delegates for i18n-dependent widgets
- `MediaQuery` sizing for responsive layout tests
- `pumpWidget` + `pump` for async state updates
- `find.byType`, `find.text`, `find.byIcon` for assertions
- Cleanup in `tearDown`: `engine.dispose()`, timer cancellation
- `buildSubject()` helper function in each test file

## Test Categories

### Unit Tests (kernel/models, kernel/utils, kernel/engine)
- Pure logic, no widget pumping
- Test enum values, serialization, path manipulation, time formatting
- Engine components: position poller, track manager, callback handler

### Widget Tests (widget/player, widget/shared)
- Player UI components: control bar, progress bar, volume controls, speed button
- Shared components: glass container, glass button, glass chip, aurora background
- Responsive layout verification at different widths

### Integration Tests (integration/)
- `controls_flow_test.dart` -- control bar interaction flow
- `playback_flow_test.dart` -- play/pause/seek flow
- `playlist_flow_test.dart` -- playlist navigation flow

### Golden Tests (golden/)
- Visual regression for control layouts and glass widgets
- Custom `golden_comparator.dart` for tolerance handling

### Performance Tests (perf/)
- `control_bar_perf_test.dart` -- control bar build performance
- `startup_parallel_init_test.dart` -- parallel initialization benchmark

## What's Tested

- Models: `AspectRatioMode`, `MediaInfo`, `PlayerError`, `PlaylistItem`, `VideoProcessingState`
- Engine: `PositionPoller`, `TrackManager`, `FvpCallbackHandler`, `EnginePrewarm`
- Services: `PlaybackController`, `PlaybackNavigator`, `StateMonitor`, `ThumbnailService`, `VideoProcessingService`, `FileOperations`, `PathValidator`, `SubtitleService`
- Bridge: `FullscreenController`, `WindowMode`, `WindowPersistence`, `WindowState`, `DisplayConfig`, `PlatformFullscreen` (Win32/macOS/Linux)
- UI: `ControlBar`, `ControlsOverlay`, `ProgressBar`, `VolumeControls`, `SpeedButton`, `VideoSurface`, `ErrorBanner`, `OsdOverlay`, `AutoHideController`
- Startup: `StartupCoordinator`, `StartupState`

## What's Not Tested

- `PlayerScreen` (complex composite -- no dedicated widget test)
- `CustomTitleBar` (Win32 platform dependency)
- `KeyboardHandler` (20+ key bindings -- no unit test)
- `DropHandler` (drag-and-drop platform events)
- `SettingsPanel` / `MediaInfoDialog` (dialog widgets)
- `PlaylistPanel` / `FolderTab` / `HistoryTab` (playlist UI)
- `FolderScanner` (filesystem I/O)
- `DeferredPlayerFeature` (deferred loading)
- `VideoEffectController` (shader operations)

## Test Helpers

| File | Purpose |
|------|---------|
| `helpers/fake_engine.dart` | `FakeEngine` -- pure Dart PlayerEngine implementation |
| `helpers/fake_window_service.dart` | `FakeWindowService` -- WindowBridge with call tracking |
| `helpers/integration_helpers.dart` | Shared integration test setup utilities |
| `golden/golden_comparator.dart` | Golden image comparison with tolerance |

## Running Tests

```bash
flutter test                    # All tests
flutter test test/kernel/       # Kernel tests only
flutter test test/widget/       # Widget tests only
flutter test --update-goldens   # Update golden files
```
