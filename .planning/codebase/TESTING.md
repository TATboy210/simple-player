# Testing Patterns

**Analysis Date:** 2026-07-03

## Test Framework

**Runner:**
- `flutter_test` (SDK)
- No external test runner (no jest/vitest equivalent)

**Assertion Library:**
- Built-in `expect()` with Flutter matchers: `findsOneWidget`, `findsNothing`, `isNull`, `isTrue`, `greaterThanOrEqualTo()`

**Run Commands:**
```bash
flutter test                          # Run all tests
flutter test --watch                  # Watch mode (not natively supported, use IDE)
flutter test --coverage               # Coverage report
flutter test test/kernel/utils/       # Run specific directory
flutter test test/widget/player/      # Run widget tests only
```

## Test File Organization

**Location:** `test/` directory, mirroring `lib/` structure

**Naming:** Source file `lib/kernel/utils/time_utils.dart` -> test `test/kernel/utils/time_utils_test.dart`

**Structure:**
```
test/
├── helpers/                        # Shared test utilities
│   ├── fake_engine.dart            # Hand-written FakeEngine
│   ├── fake_window_service.dart    # Hand-written FakeWindowService
│   └── integration_helpers.dart    # buildTestApp(), createTestController()
├── kernel/                         # Kernel layer tests
│   ├── engine/                     # Engine unit tests
│   ├── models/                     # Model unit tests
│   ├── persistence/                # Storage tests
│   ├── playlist/                   # Playlist logic tests
│   ├── services/                   # Service tests
│   └── utils/                      # Utility tests
├── widget/                         # Widget tests
│   ├── player/                     # Player widget tests
│   └── shared/                     # Shared widget tests
├── unit/                           # Additional unit tests
│   ├── bridge/                     # Bridge layer tests
│   ├── kernel/                     # Kernel sub-tests
│   ├── perf/                       # Performance unit tests
│   └── theme/                      # Theme/contrast tests
├── golden/                         # Golden (visual regression) tests
├── integration/                    # Integration tests
├── perf/                           # Performance profiling tests
├── ui/                             # UI layout tests
├── engine/                         # Engine mixin tests
└── debug/                          # Debug tooling tests
```

## Test Structure

**Suite Organization:**
```dart
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    engine.dispose();
  });

  group('FeatureName', () {
    group('subFeature', () {
      test('does something expected', () {
        // Arrange
        engine.configureMedia(durationMs: 60000);

        // Act
        engine.play();

        // Assert
        expect(engine.state.value, MediaState.playing);
      });
    });
  });
}
```

**Patterns:**
- `setUp()` for creating fakes and configuring initial state
- `tearDown()` for disposing fakes and cleaning up singletons
- `group()` for organizing related tests by feature/behavior
- Test names describe behavior: `'rejects invalid path (empty string)'`

## Fakes Over Mocks

**Philosophy:** Hand-written fakes, not generated mocks. No Mockito.

**Primary Fake:** `FakeEngine` (`test/helpers/fake_engine.dart`)

```dart
class FakeEngine with EngineState, TrackControl, VideoEffects, RendererConfig {
  // ValueNotifier fields with defaults matching FvpEngine
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
  final ValueNotifier<int> position = ValueNotifier(0);
  // ...

  // Call tracking for test introspection
  int openCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  final List<String> openPaths = [];

  // Error injection
  String? failNextOpenWith;

  // Test helper methods
  void configureMedia({int durationMs = 60000, ...}) { ... }
  void simulateError(String message) { ... }
  void simulateCompleted() { ... }
  void simulateBuffering(bool buffering) { ... }
}
```

**Key Fake Features:**
- Implements `EngineState` mixin (same interface as `FvpEngine`)
- No FFI imports, no platform plugins -- runs purely in Dart
- Call tracking: `openCallCount`, `playCallCount`, `openPaths`
- Error injection: `failNextOpenWith` (one-shot)
- State simulation: `simulateError()`, `simulateCompleted()`, `simulateBuffering()`
- `configureMedia()` to pre-configure duration, audio tracks, subtitle tracks

**Other Fakes:**
- `FakeWindowService` (`test/helpers/fake_window_service.dart`) -- window management
- `MockEngine` (`lib/kernel/engine/mock_engine.dart`) -- production debug mock with timer-based position simulation

## Integration Test Helpers

**File:** `test/helpers/integration_helpers.dart`

```dart
Widget buildTestApp({required Widget child}) {
  return MaterialApp(home: Scaffold(body: child));
}

PlaybackController createTestController(FakeEngine engine) {
  final playlist = Playlist();
  return PlaybackController(
    engine: engine,
    playlist: playlist,
    onNeedRebuild: () {},
  );
}
```

## Widget Test Pattern

**Helper Function:** Every widget test file defines a `buildSubject()` or `_wrapWithApp()` helper.

```dart
Widget buildSubject({
  EngineState? eng,
  PlayerActions? actions,
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
          actions: actions ?? const PlayerActions(),
        ),
      ),
    ),
  );
}
```

**Key Rules:**
- Always wrap in `MaterialApp` + `Scaffold`
- Set explicit `SizedBox` dimensions to simulate real layout constraints
- Include `AppLocalizations.localizationsDelegates` when widget uses l10n
- Use `const PlayerActions()` for default no-op callbacks
- `await tester.pump()` after `pumpWidget()` to settle initial build

## Widget Test Assertions

**Rendering:**
```dart
expect(find.byType(ControlBar), findsOneWidget);
expect(find.text('test'), findsOneWidget);
expect(find.byIcon(Icons.repeat), findsOneWidget);
```

**Widget Tree:**
```dart
expect(find.byType(BackdropFilter), findsNothing);  // blur disabled
expect(find.byType(BackdropFilter), findsOneWidget); // blur enabled
expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
```

**State Changes:**
```dart
await tester.pump();
expect(find.text('75%'), findsOneWidget);
OsdService.I.hide();
await tester.pump();
expect(find.byType(SizedBox), findsOneWidget);
```

## Mocking

**Framework:** None -- hand-written fakes only

**What to Mock:**
- `EngineState` -- use `FakeEngine`
- `WindowService` -- use `FakeWindowService`
- `SharedPreferences` -- use `SharedPreferences.setMockInitialValues({})`

**What NOT to Mock:**
- Pure Dart utilities (`PathUtils`, `formatMs`) -- test directly
- Data models (`PlaylistItem`, `AppSettings`) -- test directly
- `Playlist` -- test directly (pure Dart, no I/O)

## Fixtures and Factories

**Test Data:**
```dart
// Inline construction -- no external fixture files
PlaylistItem(path: 'C:/a.mp4', timestamp: 1234567890, positionMs: 30000)

// FakeEngine configuration
engine.configureMedia(durationMs: 60000, audioTracks: [...], subtitleTracks: [...])
```

**Location:** All test data is inline in test files or in `test/helpers/`. No external fixture files.

## Golden Tests

**File:** `test/golden/glass_widgets_golden_test.dart`, `test/golden/control_layouts_golden_test.dart`

**Custom Comparator:** `test/golden/golden_comparator.dart`

```dart
class TolerantGoldenComparator extends LocalFileComparator {
  // 5% per-channel tolerance, 1% max mismatch rate
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.05, this.maxMismatchRate = 0.01});
}

void enableTolerantGoldens({double tolerance = 0.05}) {
  goldenFileComparator = TolerantGoldenComparator(...);
}

Widget wrapForGolden(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(child: SizedBox(width: 800, height: 600, child: child)),
    ),
  );
}
```

**Pattern:**
```dart
setUp(() => enableTolerantGoldens());

testWidgets('thin tier', (tester) async {
  await tester.pumpWidget(wrapForGolden(const GlassContainer(tier: GlassTier.thin, ...)));
  await expectLater(find.byType(GlassContainer), matchesGoldenFile('goldens/glass_container_thin.png'));
});
```

## Performance Tests

**File:** `test/perf/control_bar_perf_test.dart`

**Pattern:** Count widget rebuilds during simulated interactions.

```dart
class _RebuildCounter extends StatefulWidget {
  final Widget child;
  final ValueNotifier<int> count;
  // Increments count on every build()
}

testWidgets('rebuild count during playback', (tester) async {
  final rebuildCount = ValueNotifier<int>(0);
  await tester.pumpWidget(_RebuildCounter(count: rebuildCount, child: _buildControlBar(engine)));
  await tester.pump();

  for (var i = 1; i <= 10; i++) {
    engine.position.value = i * 3000;
    await tester.pump(const Duration(milliseconds: 250));
  }

  expect(rebuildCount.value - initialCount, lessThanOrEqualTo(2));
});
```

**Thresholds:**
- 16.6ms/frame (60fps target)
- Position updates at 250ms intervals should not trigger parent rebuilds
- Mouse movement throttled at 100ms intervals

## Coverage

**Requirements:** 80% minimum target (from global rules)

**View Coverage:**
```bash
flutter test --coverage
# Generates coverage/lcov.info
# Use IDE or lcov tools to view
```

**Gaps (known):**
- FFI-dependent classes (`FvpEngine`, `PositionPoller`, `WindowBridge`) -- tested via API surface compilation only
- Platform-specific code (`FolderScanner`, `PathUtils.openFileLocation`) -- limited by test environment
- `initLog()` -- requires `path_provider` platform plugin

## Test Types

**Unit Tests:**
- Pure Dart logic: `test/kernel/models/`, `test/kernel/utils/`, `test/kernel/playlist/`
- Engine helpers: `test/kernel/engine/` (position_poller, volume_controller, subtitle_configurator, etc.)
- Services: `test/kernel/services/` (playback_controller, path_validator, thumbnail_service, etc.)
- Storage: `test/kernel/persistence/` (settings_store, playlist_store, settings_validator)
- Startup: `test/kernel/startup/` (startup_coordinator, startup_state)

**Widget Tests:**
- Player controls: `test/widget/player/` (control_bar, progress_bar, volume_controls, speed_button, osd_overlay, etc.)
- Shared components: `test/widget/shared/` (glass_container, glass_chip, glass_button, aurora_background, edge_glow)
- Layout: `test/ui/player/responsive_layout_test.dart`

**Integration Tests:**
- Playlist flow: `test/integration/playlist_flow_test.dart` (playNext, playPrevious, loopAll, loopSingle)
- Playback flow: `test/integration/playback_flow_test.dart`
- Controls flow: `test/integration/controls_flow_test.dart`

**Golden Tests:**
- Glass widgets: `test/golden/glass_widgets_golden_test.dart`
- Control layouts: `test/golden/control_layouts_golden_test.dart`

**Performance Tests:**
- Control bar rebuild profiling: `test/perf/control_bar_perf_test.dart`

## Common Patterns

**Async Testing:**
```dart
test('adds file to playlist and starts playback', () async {
  engine.configureMedia(durationMs: 120000);
  final result = await controller.openAndPlay('C:/test/video.mp4');
  await Future(() {});  // yield to let background operations complete
  expect(result, true);
});
```

**Error Testing:**
```dart
test('rejects invalid path (empty string)', () async {
  final result = await controller.openAndPlay('');
  expect(result, false);
  expect(controller.validationError.value, isNotNull);
});
```

**Error Injection:**
```dart
test('handles open failure', () async {
  engine.failNextOpenWith = 'File not found';
  await controller.openAndPlay('C:/test/video.mp4');
  expect(engine.state.value, MediaState.error);
});
```

**Singleton Testing:**
```dart
setUp(() {
  SharedPreferences.setMockInitialValues({});
  SettingsStore.resetPrewarm();
  PlaylistStore.reset();
});

tearDown(() {
  SettingsStore.resetPrewarm();
  PlaylistStore.reset();
});
```

**ValueNotifier Testing:**
```dart
test('visible toggles correctly', () {
  OsdService.I.show('test');
  expect(OsdService.I.visible.value, isTrue);
  OsdService.I.hide();
  expect(OsdService.I.visible.value, isFalse);
});
```

## Binding Initialization

**Non-widget tests** that use platform plugins need:
```dart
TestWidgetsFlutterBinding.ensureInitialized();
```

**File:** Required in `test/kernel/services/playback_controller_test.dart`, `test/kernel/persistence/settings_store_test.dart`

## Test Isolation Rules

- Every `FakeEngine` created in `setUp()` must be `dispose()`d in `tearDown()`
- Singletons (`OsdService.I`, `SettingsStore`, `PlaylistStore`) must be reset after tests that modify them
- `ValueNotifier` instances created in tests should be `dispose()`d
- Use `addTearDown()` for gesture cleanup: `addTearDown(gesture.removePointer)`

---

*Testing analysis: 2026-07-03*
