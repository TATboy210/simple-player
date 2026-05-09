# Testing Patterns

**Analysis Date:** 2026-05-09

## Test Framework

**Runner:**
- `flutter_test` (SDK built-in)
- Config: none (default `flutter test` behavior)

**Assertion Library:**
- `flutter_test` built-in matchers (`expect`, `equals`, `isNull`, `isNotNull`, `closeTo`, `throwsA`, etc.)

**Dev Dependencies:**
- `flutter_test: sdk`
- `flutter_lints: ^6.0.0`
- `fake_async: ^1.0.0`

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --coverage         # With coverage
flutter test test/kernel/playlist/playlist_test.dart  # Single file
```

## Test File Organization

**Location:**
- Tests mirror `lib/kernel/` structure under `test/kernel/`
- Helper fakes in `test/helpers/`
- Unit/performance tests in `test/unit/`

**Naming:**
- `{source_file_name}_test.dart` — matches source file name
- Examples: `playlist_test.dart` for `playlist.dart`, `playback_controller_test.dart` for `playback_controller.dart`

**Structure:**
```
test/
├── helpers/
│   ├── fake_engine.dart              # Fake MediaEngine implementation
│   └── fake_platform_service.dart    # Fake PlatformService implementation
├── kernel/
│   ├── engine/
│   │   ├── fvp_callback_handler_test.dart
│   │   ├── position_poller_test.dart
│   │   └── track_manager_test.dart
│   ├── models/
│   │   ├── aspect_ratio_mode_test.dart
│   │   ├── media_info_test.dart
│   │   └── playlist_item_test.dart
│   ├── persistence/
│   │   └── settings_store_test.dart
│   ├── playlist/
│   │   └── playlist_test.dart
│   ├── services/
│   │   ├── external_subtitle_test.dart
│   │   ├── file_operations_test.dart
│   │   ├── path_validator_test.dart
│   │   ├── playback_controller_test.dart
│   │   ├── playback_navigator_test.dart
│   │   ├── state_monitor_test.dart
│   │   └── video_processing_service_test.dart
│   └── utils/
│       └── path_utils_test.dart
└── unit/
    ├── kernel/engine/
    │   └── media_engine_extension_test.dart
    └── perf/
        └── startup_parallel_init_test.dart
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();  // Required for ValueNotifier tests

  late FakeEngine engine;
  late Playlist playlist;
  late PlaybackController controller;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () {},
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('FeatureName', () {
    group('specific behavior', () {
      test('describes expected behavior', () async {
        // Arrange
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/test/video.mp4');

        // Act
        await controller.playIndex(0);

        // Assert
        expect(playlist.currentIndex, 0);
        expect(engine.state.value, MediaState.playing);
      });
    });
  });
}
```

**Patterns:**
- `setUp()` creates fresh instances for each test (isolation)
- `tearDown()` disposes all disposable resources
- `group()` nests by feature → behavior (2 levels typical)
- `TestWidgetsFlutterBinding.ensureInitialized()` at top of main when testing ValueNotifier/Flutter bindings
- Helper functions defined inside `main()` for test-specific setup (e.g., `registerAutoAdvance()`)

## Mocking

**Framework:** Hand-written fakes (no mockito/mocktail)

**Primary Fake: `FakeEngine`** (`test/helpers/fake_engine.dart`)
```dart
class FakeEngine implements MediaEngine {
  // All 13 ValueNotifier fields with defaults matching FvpEngine
  final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(MediaState.idle);
  // ...

  // Call tracking for test introspection
  int openCallCount = 0;
  int playCallCount = 0;
  final List<String> openPaths = [];

  // One-shot failure injection
  String? failNextOpenWith;

  // Test helper methods
  void configureMedia({int durationMs = 60000, ...});
  void simulateError(String message);
  void simulateCompleted();
  void simulateBuffering(bool buffering);
}
```

**Secondary Fake: `FakePlatformService`** (`test/helpers/fake_platform_service.dart`)
```dart
class FakePlatformService implements PlatformService {
  @override
  Future<void> initService() async {}
  @override
  Future<void> dispose() async {}
}
```

**What to Mock:**
- `MediaEngine` — always use `FakeEngine` (never real FFI)
- `PlatformService` — use `FakePlatformService`
- `SharedPreferences` — use `SharedPreferences.setMockInitialValues({})` in setUp
- File system — use real temp directories (`Directory.systemTemp.createTempSync()`)

**What NOT to Mock:**
- `Playlist` — use real instance (pure Dart, no external deps)
- `PathValidator` — use real instance (pure Dart)
- `PathUtils` — use real instance (pure Dart)
- Model classes (`PlaylistItem`, `MediaInfo`, etc.) — always real

**FakeEngine Call Tracking Pattern:**
```dart
// Track calls for assertion
expect(engine.openCallCount, 1);
expect(engine.playCallCount, 1);
expect(engine.openPaths.last, contains('b.mp4'));
expect(engine.seekToCallCount, 1);
expect(engine.lastSeekToMs, 30000);
```

**Failure Injection Pattern:**
```dart
engine.failNextOpenWith = 'decode failed';
await controller.playIndex(0);
expect(errors, isNotEmpty);
```

## SharedPreferences Mocking

**Pattern:**
```dart
setUp(() {
  SharedPreferences.setMockInitialValues({'volume': 0.5});
  SettingsStore.resetPrewarm();  // Clear cached instance
});

tearDown(() {
  SettingsStore.resetPrewarm();
});
```

**Key rule:** Always call `SettingsStore.resetPrewarm()` in setUp/tearDown to avoid test pollution from cached SharedPreferences instances.

## Async Testing

**Pattern: Yield to microtask queue**
```dart
await controller.playIndex(0);
await Future(() {});  // Yield to let backgrounded async complete
expect(engine.state.value, MediaState.playing);
```

**Pattern: Delayed assertions for debounced operations**
```dart
s.brightness.value = 0.5;
await Future<void>.delayed(const Duration(milliseconds: 100));  // Wait for debounce
final prefs = await SharedPreferences.getInstance();
expect(prefs.getDouble('videoBrightness'), closeTo(0.5, 0.01));
```

**Pattern: Concurrent operation testing**
```dart
final f1 = controller.playIndex(0);
final f2 = controller.playIndex(1);
await f1;
await f2;
expect(playlist.currentIndex, 1);  // Last request wins
expect(controller.currentGeneration, 2);
```

## Test Data

**Path conventions in tests:**
- Use Windows-style paths: `'C:/test/video.mp4'`, `'C:/a.mp4'`
- Use forward slashes even on Windows (cross-platform safe)
- Use `.mp4`, `.mkv`, `.mp3` extensions (pass validation)

**Duration values:**
- `engine.configureMedia(durationMs: 60000)` — standard 1-minute media
- `engine.configureMedia(durationMs: 120000)` — 2-minute media

**Temp directory tests:**
```dart
late Directory tempDir;
setUp(() {
  tempDir = Directory.systemTemp.createTempSync('subtitle_test_');
});
tearDown(() {
  try {
    tempDir.deleteSync(recursive: true);
  } on Exception {
    // ignore cleanup failures
  }
});
```

## Coverage

**Requirements:** None enforced in CI (no coverage threshold configured)

**View Coverage:**
```bash
flutter test --coverage
# Generates coverage/lcov.info
```

## Test Types

**Unit Tests:**
- All kernel logic: playlist, playback controller, navigator, state monitor, file operations, path validation, settings persistence, video processing service
- Pure Dart, no Flutter widget testing
- Focus on state transitions, boundary conditions, error handling

**Widget Tests:**
- None currently exist (no `test/widget/` directory)
- UI code not tested at unit level

**Integration/E2E Tests:**
- None currently exist
- `test/unit/perf/startup_parallel_init_test.dart` tests parallel init pattern behavior

## Common Patterns

**Testing state transitions:**
```dart
test('auto-plays next in normal mode', () async {
  engine.configureMedia(durationMs: 60000);
  playlist.add('C:/a.mp4');
  playlist.add('C:/b.mp4');
  playlist.mode = PlayMode.normal;
  registerAutoAdvance();
  await controller.playIndex(0);
  engine.simulateCompleted();
  await Future(() {});
  expect(playlist.currentIndex, 1);
});
```

**Testing validation/rejection:**
```dart
test('rejects empty path and sets validationError', () async {
  final result = await controller.openAndPlay('');
  expect(result, false);
  expect(controller.validationError.value, isNotNull);
  expect(playlist.isEmpty, true);
});
```

**Testing serialization round-trip:**
```dart
test('round-trip', () {
  final original = PlaylistItem(path: '/test/video.mp4');
  final json = original.toJson();
  final restored = PlaylistItem.fromJson(json);
  expect(restored, equals(original));
});
```

**Testing boundary/clamping:**
```dart
test('load clamps width below 1024 to 1024', () async {
  SharedPreferences.setMockInitialValues({'windowWidth': 800.0});
  final settings = await SettingsStore.load();
  expect(settings.windowWidth, 1024.0);
});
```

**Testing error injection:**
```dart
test('reports error via onError callback on failure', () async {
  playlist.add('C:/a.mp4');
  engine.failNextOpenWith = 'decode failed';
  await controller.playIndex(0);
  expect(errors, isNotEmpty);
});
```

**Testing disposed behavior:**
```dart
test('setExternalSubtitle is no-op when disposed', () {
  final testEngine = FakeEngine();
  testEngine.dispose();
  testEngine.setExternalSubtitle('/path/to/sub.srt');
  expect(testEngine.setExternalSubtitleCallCount, 0);
});
```

## Test Naming Convention

Use descriptive behavior-focused names:
```dart
test('adds file to playlist and starts playback', () { ... });
test('rejects invalid path (empty string)', () { ... });
test('generation guard discards stale request', () { ... });
test('reuses existing index if file already in playlist', () { ... });
test('does not seek when positionMs <= 1000', () { ... });
```

Chinese test names are acceptable (matching codebase convention):
```dart
// 正常路径：合法 String
test('accepts valid path', () { ... });
// 边界：path 非 String 类型
test('rejects non-string path', () { ... });
```

## What Is NOT Tested

- **UI widgets** — no widget tests exist
- **Platform-specific code** — `WindowsPlatformService`, `LinuxPlatformService` not tested (FFI-dependent)
- **FvpEngine** — not directly tested (requires mdk.Player FFI); tested indirectly via FakeEngine
- **PositionPoller** — only API surface verified (FFI-dependent)
- **App widget** — not tested
- **Localization** — not tested

---

*Testing analysis: 2026-05-09*
