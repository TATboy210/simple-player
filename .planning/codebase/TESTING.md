# Testing Patterns

**Analysis Date:** 2026-07-12

## Test Framework

**Runner:**
- Flutter Test (built-in)
- Config: `pubspec.yaml` (dev_dependencies)

**Assertion Library:**
- `package:flutter_test/flutter_test.dart` (built-in matchers)

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --watch            # Watch mode
flutter test --coverage         # Coverage report
flutter test test/kernel/bridge/display_config_test.dart  # Single file
```

## Test File Organization

**Location:**
- Tests in `test/` directory, mirroring `lib/` structure
- Helpers in `test/helpers/`
- Golden tests in `test/golden/`

**Naming:**
- All test files end with `_test.dart`
- Descriptive names: `control_bar_test.dart`, `display_config_test.dart`

**Structure:**
```
test/
├── debug/              # Debug/diagnostic tests
├── engine/             # Engine layer tests
├── features/           # Feature-specific tests
├── golden/             # Visual regression tests
├── helpers/            # Test utilities and fakes
│   ├── fake_engine.dart
│   ├── fake_window_service.dart
│   └── integration_helpers.dart
├── integration/        # Flow/integration tests
├── kernel/             # Kernel layer tests
├── perf/               # Performance tests
├── platform/           # Platform-specific tests
├── regression/         # Regression test suites
├── ui/                 # UI component tests
├── unit/               # Unit tests
└── widget/             # Widget tests
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  group('DisplayConfig.syncModeForHz', () {
    setUp(() {
      // Setup before each test
    });

    tearDown(() {
      // Cleanup after each test
    });

    test('60Hz returns sync mode (1)', () {
      expect(DisplayConfig.syncModeForHz(60), '1');
    });

    test('120Hz returns async mode (0)', () {
      expect(DisplayConfig.syncModeForHz(120), '0');
    });
  });

  group('DisplayConfig cold startup', () {
    tearDown(() => DisplayConfig.reset());

    test('getRefreshRate returns 60 before init()', () {
      expect(DisplayConfig.getRefreshRate(), 60);
    });
  });
}
```

**Patterns:**
- `group()` for logical test grouping
- `setUp()` / `tearDown()` for setup/cleanup
- Descriptive test names: `'returns sync mode (1)'`
- AAA pattern: Arrange → Act → Assert

## Mocking

**Framework:** Hand-written fakes (no mockito/mocktail)

**Patterns:**
```dart
/// Mock DisplayEnumerator — 验证抽象接口契约。
///
/// Win32 实现依赖 FFI (user32.dll)，无法在测试环境直接调用。
/// 用 mock 验证接口行为和 DisplayInfo 数据类。
class MockDisplayEnumerator implements DisplayEnumerator {
  MockDisplayEnumerator(this._displays);

  final List<DisplayInfo> _displays;

  @override
  List<DisplayInfo> enumerateDisplays() => List.unmodifiable(_displays);

  @override
  DisplayInfo? getDisplayForWindow(int hwnd) {
    try {
      return _displays.firstWhere((d) => d.isPrimary);
    } on StateError {
      return _displays.isNotEmpty ? _displays.first : null;
    }
  }

  @override
  DisplayInfo? getCurrentDisplay() => getDisplayForWindow(0);
}
```

**What to Mock:**
- Platform-specific APIs (FFI, MethodChannel)
- External dependencies (file system, network)
- Complex services (engine, window manager)

**What NOT to Mock:**
- Pure Dart logic (use real implementations)
- ValueNotifiers (use real instances)
- Simple data classes

## Fixtures and Factories

**Test Data:**
```dart
// FakeEngine — hand-written test double
class FakeEngine with EngineState, TrackControl, VideoEffects, RendererConfig {
  // Call tracking
  int openCallCount = 0;
  int playCallCount = 0;
  final List<String> openPaths = [];

  // Controllable behavior
  String? failNextOpenWith;

  // Test helper methods
  void configureMedia({
    int durationMs = 60000,
    List<AudioTrackInfo>? audioTracks,
    List<SubtitleTrackInfo>? subtitleTracks,
  }) {
    _mediaInfo = MediaInfo(
      duration: durationMs,
      audioTracks: audioTracks ?? const [],
      subtitleTracks: subtitleTracks ?? const [],
    );
  }

  void simulateError(String message) {
    state.value = MediaState.error;
    errorMessage.value = message;
  }
}
```

**Location:** `test/helpers/`

**Available Fakes:**
- `FakeEngine` — implements `EngineState` with call tracking
- `FakeWindowService` — implements `WindowBridge` with call tracking
- `createTestController()` — creates `PlaybackController` wired to `FakeEngine`

## Coverage

**Requirements:** 80% minimum (from CLAUDE.md)

**View Coverage:**
```bash
flutter test --coverage
# Coverage report at coverage/lcov.info
# View with: genhtml coverage/lcov.info -o coverage/html
```

## Test Types

**Unit Tests:**
- Location: `test/unit/`, `test/kernel/`
- Scope: Pure Dart logic, models, utilities
- Pattern: Direct function calls, no Flutter framework
```dart
test('syncModeForHz returns correct value', () {
  expect(DisplayConfig.syncModeForHz(60), '1');
  expect(DisplayConfig.syncModeForHz(120), '0');
});
```

**Widget Tests:**
- Location: `test/widget/`
- Scope: UI components with `testWidgets()`
- Pattern: `pumpWidget()` + `tester.pump()` + finders
```dart
testWidgets('renders without error', (tester) async {
  await tester.pumpWidget(buildSubject());
  await tester.pump();

  expect(find.byType(ControlBar), findsOneWidget);
});
```

**Integration Tests:**
- Location: `test/integration/`
- Scope: Multi-component flows
- Pattern: Use `FakeEngine` + `createTestController()`
```dart
test('open file starts playback', () async {
  await controller.openAndPlay('C:/test.mp4');
  expect(engine.state.value, MediaState.playing);
  expect(engine.openCallCount, 1);
});
```

**Golden Tests:**
- Location: `test/golden/`
- Scope: Visual regression testing
- Pattern: `matchesGoldenFile()` for screenshot comparison

**Regression Tests:**
- Location: `test/regression/`
- Scope: High-risk areas, critical paths
- Pattern: Comprehensive test suites for specific features

## Common Patterns

**Async Testing:**
```dart
test('open() succeeds', () async {
  final engine = FakeEngine();
  await engine.open('test.mp4');
  expect(engine.openCallCount, 1);
  engine.dispose();
});
```

**Error Testing:**
```dart
test('failNextOpenWith triggers error on next open', () async {
  final engine = FakeEngine();
  engine.failNextOpenWith = 'simulated failure';
  await engine.open('bad.mp4');
  expect(engine.state.value, MediaState.error);
  expect(engine.errorMessage.value, 'simulated failure');
  engine.dispose();
});
```

**Widget Testing with Localization:**
```dart
Widget buildSubject() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 200,
        child: ControlBar(engine: engine),
      ),
    ),
  );
}

testWidgets('renders with localization', (tester) async {
  await tester.pumpWidget(buildSubject());
  await tester.pump();
  expect(find.byType(ControlBar), findsOneWidget);
});
```

**Cleanup Pattern:**
```dart
late FakeEngine engine;

setUp(() {
  engine = FakeEngine();
});

tearDown(() {
  engine.dispose();
});
```

**Call Tracking Pattern:**
```dart
test('play() increments call count', () {
  final engine = FakeEngine();
  engine.play();
  expect(engine.playCallCount, 1);
  engine.dispose();
});

test('seekTo tracks last value', () async {
  final engine = FakeEngine();
  await engine.seekTo(30000);
  expect(engine.seekToCallCount, 1);
  expect(engine.lastSeekToMs, 30000);
  engine.dispose();
});
```

## Test Naming Conventions

**Pattern:** `'describes behavior'` or `'action results in expected outcome'`

**Examples:**
```dart
test('60Hz returns sync mode (1)', () { ... });
test('getRefreshRate returns 60 before init()', () { ... });
test('init() is idempotent', () { ... });
test('reset() clears cached state', () { ... });
test('equality — same values are equal', () { ... });
test('seekTo clamps to duration', () { ... });
test('setVolume to 0 auto-mutes', () { ... });
```

---

*Testing analysis: 2026-07-12*
