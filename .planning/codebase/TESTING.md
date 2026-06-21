# Testing Patterns

**Analysis Date:** 2026-06-21

## Framework

| Component | Tool | Version |
|-----------|------|---------|
| Runner | `flutter_test` | SDK |
| Assertions | Built-in `expect`, `matcher` | SDK |
| Mocking | Hand-written fakes | No mockito |
| Persistence | `SharedPreferences.setMockInitialValues({})` | - |
| Golden | `TolerantGoldenComparator` | Custom |

**Config:** No dedicated test config file (uses `flutter_test` defaults)

**Run Commands:**
```bash
flutter test                          # Run all tests
flutter test --coverage               # With coverage
flutter test test/kernel/playlist/    # Single directory
flutter test test/widget/player/      # Widget tests only
flutter test --update-goldens         # Update golden files
```

## Test Organization

```
test/
├── features/
│   └── player/services/
│       └── subtitle_service_test.dart        # SubtitleService unit tests
├── golden/
│   ├── control_layouts_golden_test.dart      # ControlBar/ProgressBar/Volume goldens
│   ├── glass_widgets_golden_test.dart        # GlassContainer/Button goldens
│   └── golden_comparator.dart                # TolerantGoldenComparator helper
├── helpers/
│   ├── fake_engine.dart                      # FakeEngine (implements PlayerEngine)
│   ├── fake_window_service.dart              # FakeWindowService (extends WindowService)
│   └── integration_helpers.dart              # buildTestApp(), createTestController()
├── integration/
│   ├── controls_flow_test.dart               # Controls interaction flow
│   ├── playback_flow_test.dart               # Playback state transitions
│   └── playlist_flow_test.dart               # Playlist operations flow
├── kernel/
│   ├── bridge/
│   │   ├── display_config_test.dart          # DisplayConfig
│   │   └── window_bootstrap_test.dart        # WindowBootstrap
│   ├── engine/
│   │   ├── engine_prewarm_test.dart          # EnginePrewarm
│   │   ├── fvp_callback_handler_test.dart    # FvpCallbackHandler
│   │   ├── position_poller_test.dart         # PositionPoller (API surface only)
│   │   └── track_manager_test.dart           # TrackManager
│   ├── models/
│   │   ├── aspect_ratio_mode_test.dart       # AspectRatioMode
│   │   ├── media_info_test.dart              # MediaInfo
│   │   ├── player_error_test.dart            # PlayerError
│   │   ├── playlist_item_test.dart           # PlaylistItem
│   │   └── video_processing_state_test.dart  # VideoProcessingState
│   ├── persistence/
│   │   ├── playlist_store_test.dart          # PlaylistStore
│   │   └── settings_store_test.dart          # SettingsStore
│   ├── playlist/
│   │   └── playlist_test.dart                # Playlist (comprehensive, 392 lines)
│   ├── services/
│   │   ├── external_subtitle_test.dart       # ExternalSubtitle
│   │   ├── file_operations_test.dart         # FileOperations
│   │   ├── path_validator_test.dart          # PathValidator
│   │   ├── playback_controller_test.dart     # PlaybackController (343 lines)
│   │   ├── playback_navigator_test.dart      # PlaybackNavigator
│   │   ├── state_monitor_test.dart           # StateMonitor
│   │   ├── thumbnail_service_test.dart       # ThumbnailService
│   │   └── video_processing_service_test.dart # VideoProcessingService
│   ├── startup/
│   │   ├── startup_coordinator_test.dart     # StartupCoordinator
│   │   └── startup_state_test.dart           # StartupState
│   └── utils/
│       ├── log_test.dart                     # Logger
│       ├── path_utils_dirname_test.dart      # PathUtils.dirname
│       ├── path_utils_test.dart              # PathUtils
│       ├── perf_monitor_test.dart            # PerfMonitor
│       └── time_utils_test.dart              # formatMs
├── perf/
│   └── control_bar_perf_test.dart            # Rebuild profiling (324 lines)
├── unit/
│   ├── kernel/engine/
│   │   └── media_engine_extension_test.dart  # MediaEngine extension
│   └── perf/
│       └── startup_parallel_init_test.dart   # Startup parallel init
└── widget/
    ├── player/
    │   ├── auto_hide_controller_test.dart    # AutoHideController
    │   ├── control_bar_test.dart             # ControlBar widget
    │   ├── controls_overlay_test.dart        # ControlsOverlay widget
    │   ├── error_banner_test.dart            # ErrorBanner widget
    │   ├── osd_overlay_test.dart             # OsdOverlay widget
    │   ├── progress_bar_test.dart            # ProgressBar widget
    │   ├── speed_button_test.dart            # SpeedButton widget
    │   ├── video_surface_test.dart           # VideoSurface widget
    │   └── volume_controls_test.dart         # VolumeControls widget
    └── shared/
        ├── glass_button_test.dart            # GlassButton widget
        ├── glass_chip_test.dart              # GlassChip widget
        └── glass_container_test.dart         # GlassContainer widget
```

**Total: 50+ test files**

## Test Types

### Unit Tests (`test/kernel/`, `test/unit/`, `test/features/`)
- Pure Dart logic, no Flutter widgets
- Models, utilities, services, persistence
- Fast execution, no rendering

### Widget Tests (`test/widget/`)
- Flutter widget rendering and interaction
- Uses `testWidgets()` + `tester.pumpWidget()`
- Requires `MaterialApp` wrapper with localization delegates

### Golden Tests (`test/golden/`)
- Visual regression testing
- Custom `TolerantGoldenComparator` with per-channel pixel tolerance
- 5% tolerance per channel, 1% max mismatch rate

### Integration Tests (`test/integration/`)
- Multi-component flow tests
- Uses `FakeEngine` + real `PlaybackController` + real `Playlist`
- Tests state transitions across components

### Performance Tests (`test/perf/`)
- Rebuild count profiling
- Uses `_RebuildCounter` wrapper to count widget rebuilds
- Validates child caching and ValueNotifier optimization

## FakeEngine Pattern

**File:** `test/helpers/fake_engine.dart`
**Purpose:** Implements `PlayerEngine` without FFI dependency — runs purely in Dart

### Key Features
```dart
class FakeEngine implements PlayerEngine {
  // ─── ValueNotifier fields (defaults match FvpEngine) ───
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);
  final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(MediaState.idle);
  final ValueNotifier<int> position = ValueNotifier<int>(0);
  // ... 10+ ValueNotifiers

  // ─── Call tracking for test introspection ───
  int openCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  int stopCallCount = 0;
  int seekToCallCount = 0;
  final List<String> openPaths = [];

  // ─── Error injection ───
  String? failNextOpenWith;  // One-shot: next open() simulates error

  // ─── State simulation helpers ───
  void configureMedia({int durationMs = 60000, List<AudioTrackInfo>? audioTracks, ...});
  void simulateError(String message);
  void simulateCompleted();
  void simulateBuffering(bool buffering);

  // ─── Call tracking for video processing ───
  int setVideoEffectCallCount = 0;
  int rotateCallCount = 0;
  int setAspectRatioCallCount = 0;
  int setDeinterlaceCallCount = 0;
  int setD3d11SyncEnabledCallCount = 0;
  int setHardwareDecodingCallCount = 0;
}
```

### Usage Pattern
```dart
setUp(() {
  engine = FakeEngine();
  engine.configureMedia(durationMs: 60000);
});

tearDown(() {
  engine.dispose();
});

test('opens file and starts playback', () async {
  await controller.openAndPlay('C:/test.mp4');
  expect(engine.openCallCount, 1);
  expect(engine.state.value, MediaState.playing);
});
```

## FakeWindowService Pattern

**File:** `test/helpers/fake_window_service.dart`
**Purpose:** Test double for WindowService — no FFI, no window_manager

```dart
class FakeWindowService extends WindowService {
  int fullscreenCallCount = 0;
  bool? lastFullscreenValue;
  int maximizeCallCount = 0;

  @override
  Future<void> init() async { /* No-op */ }

  @override
  Future<void> setFullscreen(bool value) async {
    fullscreenCallCount++;
    lastFullscreenValue = value;
    isFullscreen.value = value;
  }
  // ... all methods are no-op stubs with call tracking
}
```

## Integration Helpers

**File:** `test/helpers/integration_helpers.dart`

```dart
/// Wrap [child] in a minimal MaterialApp for widget tests.
Widget buildTestApp({required Widget child}) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Create a PlaybackController wired to [engine] with a no-op rebuild.
PlaybackController createTestController(FakeEngine engine) {
  final playlist = Playlist();
  return PlaybackController(
    engine: engine,
    playlist: playlist,
    onNeedRebuild: () {},
  );
}

/// Create a FakeWindowService with sensible defaults.
FakeWindowService createFakeWindowService() => FakeWindowService();
```

## Test Structure (AAA Pattern)

### Arrange-Act-Assert with setUp/tearDown
```dart
group('PlaybackController', () {
  late FakeEngine engine;
  late Playlist playlist;
  late PlaybackController controller;
  int rebuildCount = 0;
  List<Object> errors = [];

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    rebuildCount = 0;
    errors = [];
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => rebuildCount++,
      onError: (e) => errors.add(e),
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  test('adds file to playlist and starts playback', () async {
    // Arrange (already done in setUp)
    engine.configureMedia(durationMs: 120000);

    // Act
    final result = await controller.openAndPlay('C:/test/video.mp4');
    await Future(() {});  // yield for backgrounded async

    // Assert
    expect(result, true);
    expect(playlist.length, 1);
    expect(engine.state.value, MediaState.playing);
  });
});
```

### Nested groups for sub-features
```dart
group('Playlist', () {
  group('empty state', () {
    test('length is 0', () => expect(playlist.length, 0));
    test('isEmpty', () => expect(playlist.isEmpty, true));
  });

  group('add', () {
    test('adds item and sets index to 0', () { ... });
  });

  group('removeAt', () {
    setUp(() { /* Add items */ });
    test('removes item before current', () { ... });
  });
});
```

## Test Naming Conventions

**Pattern:** `test('behavior description', () { ... })`

**Good examples:**
```dart
test('adds file to playlist and starts playback', () { ... });
test('rejects invalid path (empty string)', () { ... });
test('ignores out-of-range index', () { ... });
test('generation guard discards stale request', () { ... });
test('auto-plays next in loopAll mode', () { ... });
test('removes current item and plays next', () { ... });
test('returns null for valid path', () { ... });
test('detects path traversal', () { ... });
```

**Widget test pattern:**
```dart
testWidgets('renders without error', (tester) async { ... });
testWidgets('shows secondary controls at width >= 500', (tester) async { ... });
testWidgets('hides secondary controls at width < 500', (tester) async { ... });
testWidgets('shows folder_open button when onOpenFile is provided', (tester) async { ... });
testWidgets('blurEnabled=false skips BackdropFilter', (tester) async { ... });
```

## Mocking Patterns

**No mockito — hand-written fakes only:**

```dart
// FakeEngine — implements PlayerEngine interface
class FakeEngine implements PlayerEngine {
  int openCallCount = 0;
  final List<String> openPaths = [];
  String? failNextOpenWith;

  @override
  Future<void> open(String path) async {
    openCallCount++;
    openPaths.add(path);
    if (failNextOpenWith != null) {
      state.value = MediaState.error;
      errorMessage.value = failNextOpenWith!;
      failNextOpenWith = null;
      return;
    }
    // Normal behavior...
  }
}
```

**What to Fake:**
- `PlayerEngine` → `FakeEngine` (FFI boundary)
- `WindowService` → `FakeWindowService` (Win32 boundary)
- `SharedPreferences` → `SharedPreferences.setMockInitialValues({})`

**What NOT to Fake:**
- `Playlist` — pure Dart, use real implementation
- `PlaybackController` — use real with FakeEngine
- `PathValidator` — pure Dart, use real
- Models (`MediaState`, `PlayMode`, etc.) — use real

## Golden Tests

**File:** `test/golden/golden_comparator.dart`

**Custom comparator with tolerance:**
```dart
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {
    this.tolerance = 0.05,        // 5% per-channel
    this.maxMismatchRate = 0.01,  // 1% max mismatched pixels
  });
}

void enableTolerantGoldens({double tolerance = 0.05}) {
  goldenFileComparator = TolerantGoldenComparator(...);
}
```

**Usage:**
```dart
setUp(() => enableTolerantGoldens());

testWidgets('GlassContainer thin tier', (tester) async {
  await tester.pumpWidget(
    wrapForGolden(GlassContainer(tier: GlassTier.thin, child: const Text('Thin'))),
  );
  await expectLater(
    find.byType(GlassContainer),
    matchesGoldenFile('goldens/glass_container_thin.png'),
  );
});
```

**Update goldens:**
```bash
flutter test --update-goldens
```

## Performance Tests

**File:** `test/perf/control_bar_perf_test.dart`

**Pattern: Rebuild counting:**
```dart
class _RebuildCounter extends StatefulWidget {
  final Widget child;
  final ValueNotifier<int> count;

  @override
  State<_RebuildCounter> createState() => _RebuildCounterState();
}

class _RebuildCounterState extends State<_RebuildCounter> {
  @override
  Widget build(BuildContext context) {
    widget.count.value++;
    return widget.child;
  }
}
```

**Test pattern:**
```dart
testWidgets('rebuild count during playback', (tester) async {
  final rebuildCount = ValueNotifier<int>(0);
  await tester.pumpWidget(_RebuildCounter(count: rebuildCount, child: ...));
  await tester.pump();
  final initialCount = rebuildCount.value;

  // Simulate 10 position updates at 250ms intervals
  for (var i = 1; i <= 10; i++) {
    engine.position.value = i * 3000;
    await tester.pump(const Duration(milliseconds: 250));
  }

  final totalRebuilds = rebuildCount.value - initialCount;
  expect(totalRebuilds, lessThanOrEqualTo(2),
    reason: 'ControlBar parent rebuilt $totalRebuilds times during '
        '10 position updates (expected <= 2)');
});
```

## Async Testing

**Pattern: Await + yield for backgrounded async:**
```dart
test('openAndPlay starts playback', () async {
  engine.configureMedia(durationMs: 60000);
  final result = await controller.openAndPlay('C:/test.mp4');
  await Future(() {});  // yield for backgrounded async
  expect(result, true);
  expect(engine.state.value, MediaState.playing);
});
```

**Pattern: ValueNotifier state checking:**
```dart
test('volume changes update notifier', () {
  engine.setVolume(0.5);
  expect(engine.volume.value, 0.5);
  expect(engine.isMuted.value, false);
});
```

**Pattern: Auto-advance with simulateCompleted:**
```dart
test('auto-plays next in loopAll mode', () async {
  registerAutoAdvance();
  await controller.playIndex(0);
  engine.simulateCompleted();
  await Future(() {});  // yield for listener callback
  expect(playlist.currentIndex, 1);
});
```

## Error Testing

**Pattern: Error injection via FakeEngine:**
```dart
test('handles open failure', () async {
  engine.failNextOpenWith = 'File not found';
  final result = await controller.openAndPlay('C:/missing.mp4');
  expect(result, false);
  expect(engine.state.value, MediaState.error);
});
```

**Pattern: Validation error checking:**
```dart
test('rejects non-media extension', () async {
  final result = await controller.openAndPlay('C:/test/file.txt');
  expect(result, false);
  expect(controller.validationError.value, contains('不支持'));
});
```

**Pattern: PathValidator security tests:**
```dart
test('detects null byte', () {
  expect(PathValidator.isPathTraversal('/safe\x00/path'), true);
});

test('detects UNC path', () {
  expect(PathValidator.isPathTraversal('\\\\server\\share'), true);
});
```

## Widget Test Patterns

**Pattern: buildSubject helper:**
```dart
Widget buildSubject({
  PlayerEngine? eng,
  bool isFullscreen = false,
  VoidCallback? onOpenFile,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 200,
        child: ControlBar(
          engine: eng ?? engine,
          isFullscreen: isFullscreen,
          onOpenFile: onOpenFile,
        ),
      ),
    ),
  );
}
```

**Pattern: Find by type/icon:**
```dart
testWidgets('renders play mode button', (tester) async {
  await tester.pumpWidget(buildSubject());
  await tester.pump();
  expect(find.byIcon(Icons.repeat), findsOneWidget);
});

testWidgets('shows secondary controls at width >= 500', (tester) async {
  await tester.pumpWidget(buildSubject());
  await tester.pump();
  expect(find.byType(VolumeButton), findsOneWidget);
});
```

**Pattern: Responsive layout testing:**
```dart
testWidgets('hides secondary controls at width < 500', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 200, child: ControlBar(...)),
      ),
    ),
  );
  await tester.pump();
  expect(find.byType(VolumeButton), findsNothing);
});
```

## Coverage

| Metric | Value |
|--------|-------|
| Test files | 50+ |
| Test types | Unit, Widget, Golden, Integration, Performance |
| Target | 80% |
| Enforcement | None (no CI threshold) |

**View coverage:**
```bash
flutter test --coverage
# Opens lcov.info
```

## Coverage Gaps

**High Risk (not tested):**
| Component | File | Risk |
|-----------|------|------|
| FvpEngine (full) | `lib/kernel/engine/fvp_engine.dart` | FFI boundary |
| PlayerScreen | `lib/ui/player/player_screen.dart` | Complex composition |
| PlaylistPanel | `lib/ui/playlist/playlist_panel.dart` | Complex UI |
| SettingsPanel | `lib/ui/dialogs/settings_panel.dart` | Complex UI |
| KeyboardHandler | `lib/ui/player/keyboard_handler.dart` | 20+ key bindings |
| CustomTitleBar | `lib/ui/player/custom_title_bar.dart` | Win32 integration |
| FolderScanner | `lib/kernel/scanner/folder_scanner.dart` | File system |

**Medium Risk (basic coverage):**
| Component | File | Gap |
|-----------|------|-----|
| PositionPoller | `lib/kernel/engine/position_poller.dart` | API surface only |
| StartupCoordinator | `lib/kernel/startup/startup_coordinator.dart` | State machine |

**Low Risk (acceptable gaps):**
| Component | File | Reason |
|-----------|------|--------|
| AuroraBackground | `lib/ui/shared/aurora_background.dart` | Visual only |
| Localization | `lib/l10n/` | Generated code |

## What Is Tested (Comprehensive)

| Layer | Component | Test File |
|-------|-----------|-----------|
| kernel/models | PlaylistItem, MediaInfo, PlayerError, MediaState | `test/kernel/models/*` |
| kernel/playlist | Playlist (392 lines, all operations) | `test/kernel/playlist/playlist_test.dart` |
| kernel/utils | PathUtils, TimeUtils, PerfMonitor, Log | `test/kernel/utils/*` |
| kernel/persistence | PlaylistStore, SettingsStore | `test/kernel/persistence/*` |
| kernel/services | PathValidator, ThumbnailService | `test/kernel/services/*` |
| kernel/engine | FvpCallbackHandler, TrackManager, EnginePrewarm | `test/kernel/engine/*` |
| kernel/bridge | DisplayConfig, WindowBootstrap | `test/kernel/bridge/*` |
| features/services | PlaybackController (343 lines), PlaybackNavigator, FileOperations | `test/kernel/services/*` |
| features/services | StateMonitor, VideoProcessingService, SubtitleService | `test/kernel/services/*`, `test/features/*` |
| ui/player | AutoHideController, VolumeControls, OsdOverlay, SpeedButton | `test/widget/player/*` |
| ui/player | ControlBar, ControlsOverlay, ProgressBar, ErrorBanner | `test/widget/player/*` |
| ui/shared | GlassContainer, GlassButton, GlassChip | `test/widget/shared/*` |
| golden | ControlBar, ProgressBar, VolumeControls, GlassContainer | `test/golden/*` |
| perf | Rebuild profiling, BackdropFilter optimization | `test/perf/*` |

---

*Testing analysis: 2026-06-21*
