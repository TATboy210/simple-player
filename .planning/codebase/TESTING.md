# Testing Patterns

**Analysis Date:** 2026-06-23

## Test Framework

**Runner:**
- Flutter Test (built-in)
- Config: `analysis_options.yaml` with strict lints

**Assertion Library:**
- Flutter Test built-in matchers: `expect()`, `findsOneWidget`, `findsNothing`
- Custom matchers: `closeTo()` for floating point, `contains()` for strings

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --watch            # Watch mode
flutter test --coverage         # Coverage (requires lcov)
flutter test test/path/to/file.dart  # Single file
```

## Test File Organization

**Location:**
- Tests mirror lib/ structure
- Separate directories for test types: `test/unit/`, `test/widget/`, `test/integration/`, `test/golden/`, `test/perf/`

**Naming:**
- Pattern: `{feature}_test.dart`
- Examples: `playback_controller_test.dart`, `glass_container_test.dart`

**Structure:**
```
test/
├── features/player/services/    # Feature-specific tests
├── golden/                      # Golden file tests
├── helpers/                     # Test utilities and fakes
│   ├── fake_engine.dart         # Hand-written FakeEngine
│   ├── fake_window_service.dart # Hand-written FakeWindowService
│   └── integration_helpers.dart # Shared test utilities
├── integration/                 # Integration flow tests
├── kernel/                      # Kernel layer tests
│   ├── bridge/
│   ├── engine/
│   ├── models/
│   ├── persistence/
│   ├── playlist/
│   ├── services/
│   ├── startup/
│   └── utils/
├── perf/                        # Performance tests
├── unit/                        # Unit tests
└── widget/                      # Widget tests
    ├── player/
    └── shared/
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late PlaybackController controller;

  setUp(() {
    engine = FakeEngine();
    controller = PlaybackController(
      engine: engine,
      playlist: Playlist(),
      onNeedRebuild: () {},
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('PlaybackController', () {
    group('openAndPlay', () {
      test('adds file to playlist and starts playback', () async {
        // Arrange
        engine.configureMedia(durationMs: 120000);

        // Act
        final result = await controller.openAndPlay('C:/test/video.mp4');

        // Assert
        expect(result, true);
        expect(playlist.length, 1);
        expect(engine.state.value, MediaState.playing);
      });
    });
  });
}
```

**Patterns:**
- `setUp()` for common initialization
- `tearDown()` for cleanup (dispose ValueNotifiers)
- Nested `group()` for logical organization
- Chinese comments for test descriptions (codebase convention)

## Mocking

**Framework:** Hand-written fakes (NO mockito)

**Why Fakes Over Mocks:**
- Full control over behavior
- No code generation required
- Easier to maintain
- Better type safety

**FakeEngine Implementation:**
```dart
class FakeEngine implements PlayerEngine {
  // ValueNotifier fields (matches real engine API)
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
  final ValueNotifier<int> position = ValueNotifier(0);
  final ValueNotifier<int> duration = ValueNotifier(0);

  // Call tracking for test introspection
  int openCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  int stopCallCount = 0;
  final List<String> openPaths = [];

  // Configurable behavior
  String? failNextOpenWith;

  // Helper methods
  void configureMedia({int durationMs = 60000, ...}) { ... }
  void simulateCompleted() { ... }
  void simulateError(String message) { ... }
}
```

**What to Mock:**
- External dependencies (file system, platform channels)
- Engine (FFI layer)
- Window service (Win32 API)
- SharedPreferences (persistence)

**What NOT to Mock:**
- Pure Dart logic (test directly)
- ValueNotifier state (use real instances)
- Business logic (test through public API)

## Fixtures and Factories

**Test Data:**
```dart
// Helper function for common widget wrapping
Widget buildSubject({
  PlayerEngine? eng,
  PlayerActions? actions,
  bool isFullscreen = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ControlBar(
        engine: eng ?? engine,
        actions: actions ?? const PlayerActions(),
        isFullscreen: isFullscreen,
      ),
    ),
  );
}
```

**Shared Helpers:**
- `test/helpers/fake_engine.dart` — FakeEngine for all tests
- `test/helpers/fake_window_service.dart` — FakeWindowService
- `test/helpers/integration_helpers.dart` — `buildTestApp()`, `createTestController()`

## Coverage

**Requirements:** 80% minimum (per project rules)

**View Coverage:**
```bash
flutter test --coverage
# Open coverage/lcov.info in VS Code with Coverage Gutters
```

**Coverage Gaps:**
- FFI layer (cannot test in pure Dart)
- Platform channels (requires integration tests)
- File I/O errors (edge cases)

## Test Types

**Unit Tests:**
- Location: `test/unit/`, `test/kernel/`
- Scope: Individual functions, utilities, models
- Examples: `path_utils_test.dart`, `media_info_test.dart`

**Widget Tests:**
- Location: `test/widget/`
- Scope: UI components, interactions
- Examples: `control_bar_test.dart`, `glass_container_test.dart`
- Pattern: `testWidgets()` with `tester.pumpWidget()`

**Integration Tests:**
- Location: `test/integration/`
- Scope: Multi-component flows
- Examples: `playback_flow_test.dart`, `playlist_flow_test.dart`
- Pattern: FakeEngine + real controllers

**Golden Tests:**
- Location: `test/golden/`
- Scope: Visual regression
- Examples: `glass_widgets_golden_test.dart`, `control_layouts_golden_test.dart`
- Pattern: `matchesGoldenFile()` with tolerance settings

**Performance Tests:**
- Location: `test/perf/`
- Scope: Startup time, rendering performance
- Examples: `startup_parallel_init_test.dart`, `control_bar_perf_test.dart`

## Common Patterns

**Async Testing:**
```dart
test('async operation completes', () async {
  // Arrange
  engine.configureMedia(durationMs: 60000);

  // Act
  await controller.openAndPlay('C:/test.mp4');
  await Future(() {}); // yield to microtask queue

  // Assert
  expect(engine.state.value, MediaState.playing);
});
```

**ValueNotifier Testing:**
```dart
test('state changes trigger listeners', () {
  // Arrange
  final notifier = ValueNotifier<int>(0);
  int lastValue = -1;
  notifier.addListener(() => lastValue = notifier.value);

  // Act
  notifier.value = 42;

  // Assert
  expect(lastValue, 42);
  notifier.dispose();
});
```

**Widget Testing:**
```dart
testWidgets('renders with correct text', (tester) async {
  // Arrange & Act
  await tester.pumpWidget(buildSubject());

  // Assert
  expect(find.text('test'), findsOneWidget);
  expect(find.byType(ControlBar), findsOneWidget);
});
```

**Error Testing:**
```dart
test('handles invalid path gracefully', () async {
  // Arrange
  engine.failNextOpenWith = 'File not found';

  // Act
  final result = await controller.openAndPlay('C:/bad.mp4');

  // Assert
  expect(result, false);
  expect(engine.state.value, MediaState.error);
});
```

**Golden Testing:**
```dart
testWidgets('glass container renders correctly', (tester) async {
  await tester.pumpWidget(
    wrapForGolden(
      const GlassContainer(
        tier: GlassTier.normal,
        blurEnabled: false,
        child: Text('Test'),
      ),
    ),
  );
  await expectLater(
    find.byType(GlassContainer),
    matchesGoldenFile('goldens/glass_container_normal.png'),
  );
});
```

## Test Helpers

**FakeEngine Features:**
- `configureMedia()` — pre-configure duration, tracks
- `simulateCompleted()` — trigger completion state
- `simulateError()` — trigger error state
- `simulateBuffering()` — trigger buffering state
- Call tracking: `openCallCount`, `playCallCount`, `openPaths`

**Widget Test Helpers:**
```dart
Widget buildTestApp({required Widget child}) {
  return MaterialApp(home: Scaffold(body: child));
}

PlaybackController createTestController(FakeEngine engine) {
  return PlaybackController(
    engine: engine,
    playlist: Playlist(),
    onNeedRebuild: () {},
  );
}
```

## Test Count Summary

**Total Test Files:** 57

**By Type:**
- Unit/Kernel: 35 tests
- Widget: 12 tests
- Integration: 3 tests
- Golden: 3 tests
- Performance: 2 tests
- Feature: 1 test
- Helpers: 1 file (not tests)

## Best Practices

**Do:**
- Use `FakeEngine` instead of mocking
- Test edge cases (empty inputs, invalid paths, errors)
- Test async operations with `await Future(() {})`
- Dispose ValueNotifiers in `tearDown()`
- Use descriptive test names in Chinese

**Don't:**
- Use mockito (prefer hand-written fakes)
- Skip tests or remove assertions
- Test private methods directly
- Hardcode file paths (use `C:/test.mp4` pattern)
- Ignore async warnings

## Coverage Gaps

**Not Tested:**
- FFI/native layer (C++ code)
- Platform channel implementations
- Real file I/O operations
- Win32 API calls
- Actual MDK/FFmpeg integration

**Partially Tested:**
- Error recovery paths
- Edge cases in playlist operations
- Concurrency scenarios

**Well Tested:**
- Business logic (PlaybackController, Playlist)
- Data models (PlaylistItem, MediaInfo)
- UI components (GlassContainer, ControlBar)
- State management (ValueNotifier patterns)

---

*Testing analysis: 2026-06-23*
