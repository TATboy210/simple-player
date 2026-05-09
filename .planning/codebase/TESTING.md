# Testing Patterns

**Analysis Date:** 2026-05-09

## Test Framework

**Runner:**
- `flutter_test` (built-in Flutter test runner)
- Config: `pubspec.yaml` dev_dependencies

**Assertion Library:**
- `flutter_test` built-in matchers (`expect`, `isNotNull`, `isTrue`, `equals`, etc.)

**Mocking Library:**
- Hand-written fakes (no mockito/mocktail)

**Async Testing:**
- `fake_async: ^1.0.0` available but not heavily used
- `Future<void>.value()` for minimal async yield in tests
- `Future<void>.delayed()` for debounce testing

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --coverage         # With coverage
dart test test/kernel/          # Run specific directory
```

## Test File Organization

**Location:**
- Tests mirror source structure under `test/`
- Co-located pattern: `test/kernel/services/playback_controller_test.dart` tests `lib/kernel/services/playback_controller.dart`

**Naming:**
- `{module_name}_test.dart` pattern
- Test files match source file names exactly

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
    ├── kernel/
    │   └── engine/
    │       └── media_engine_extension_test.dart
    └── perf/
        └── startup_parallel_init_test.dart
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('ComponentName', () {
    group('methodOrFeature', () {
      test('specific behavior description', () async {
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
- `TestWidgetsFlutterBinding.ensureInitialized()` at top of main when ValueNotifiers used
- `setUp()` creates fresh instances per test
- `tearDown()` disposes all resources (engine, controller, ValueNotifiers)
- `group()` for component-level and method-level organization
- Nested `group()` for feature subdivisions

## Mocking

**Approach:** Hand-written fakes implementing abstract interfaces

**FakeEngine (`test/helpers/fake_engine.dart`):**
- Implements `MediaEngine` interface
- Provides controllable behavior: `configureMedia()`, `simulateError()`, `simulateCompleted()`, `simulateBuffering()`
- Call tracking: `openCallCount`, `playCallCount`, `pauseCallCount`, `stopCallCount`, `seekToCallCount`, `openPaths`
- State capture: `lastSeekToMs`, `lastExternalSubtitlePath`, `lastVideoEffectType`, `lastVideoEffectValue`, `lastRotateDegree`, `lastAspectRatioValue`, `lastDeinterlaceValue`
- Error simulation: `failNextOpenWith` (one-shot)
- Disposal guard: checks `_disposed` before operations

**FakePlatformService (`test/helpers/fake_platform_service.dart`):**
- Minimal implementation: `initService()` and `dispose()` are no-ops

**What to Mock:**
- `MediaEngine` — always use `FakeEngine` (never the real `FvpEngine` which requires FFI/native)
- `PlatformService` — use `FakePlatformService`
- `SharedPreferences` — use `SharedPreferences.setMockInitialValues({})`

**What NOT to Mock:**
- `Playlist` — use real instance (pure Dart, no platform deps)
- `PlaylistItem` — use real instance
- `PathValidator` — use real implementation
- `SettingsStore` — use real with mocked SharedPreferences

## Fixtures and Factories

**Test Data:**
```dart
// Common test paths
const testPath = 'C:/test/video.mp4';
const testPathA = 'C:/a.mp4';
const testPathB = 'C:/b.mp4';
const testPathC = 'C:/c.mp4';

// Engine configuration
engine.configureMedia(durationMs: 60000);

// Playlist setup
playlist.add('C:/a.mp4');
playlist.add('C:/b.mp4');
playlist.add('C:/c.mp4');
```

**Helper Methods:**
```dart
// Register auto-advance listener (bypasses init() which needs SharedPreferences)
void registerAutoAdvance() {
  engine.state.addListener(() {
    final state = engine.state.value;
    if (state != MediaState.completed) return;
    if (playlist.mode == PlayMode.loopSingle) {
      final idx = playlist.currentIndex;
      if (idx >= 0) controller.playIndex(idx).catchError((e) {});
    } else {
      controller.playNext().catchError((e) {});
    }
  });
}
```

**Location:**
- Shared fakes: `test/helpers/`
- Test-specific helpers defined inline in test files

## Coverage

**Requirements:** Not formally enforced, but tests exist for all kernel modules

**View Coverage:**
```bash
flutter test --coverage
# Generates coverage/lcov.info
```

## Test Types

**Unit Tests:**
- All kernel logic: engine, services, models, persistence, playlist, utils
- Pure Dart tests with no Flutter widget dependencies
- Path validation, serialization, state machines, navigation logic

**Widget Tests:**
- Not currently present in test suite
- UI testing would require `FakeEngine` + `FakePlatformService` setup

**Integration Tests:**
- Not currently present
- `test/kernel/services/external_subtitle_test.dart` uses real filesystem (`Directory.systemTemp.createTempSync`) as integration-style test

**Performance Tests:**
- `test/unit/perf/startup_parallel_init_test.dart` verifies `Future.wait` parallelism

## Common Patterns

**Async Testing:**
```dart
// Await async operations
await controller.playIndex(0);

// Yield to let backgrounded async complete
await Future(() {});

// Debounce testing with delay
await Future<void>.delayed(const Duration(milliseconds: 100));
```

**ValueNotifier Testing:**
```dart
// Direct value assertion
expect(engine.state.value, MediaState.playing);
expect(engine.position.value, 0);
expect(controller.currentFileName.value, 'video.mp4');

// Value change verification
engine.position.value = 5000;
engine.state.value = MediaState.paused;
```

**Error Testing:**
```dart
// Validation error checking
final result = await controller.openAndPlay('');
expect(result, false);
expect(controller.validationError.value, isNotNull);
expect(controller.validationError.value, contains('empty'));

// Engine error simulation
engine.failNextOpenWith = 'decode failed';
await controller.playIndex(0);
expect(errors, isNotEmpty);

// Error state simulation
engine.simulateError('test error');
expect(engine.errorMessage.value, 'test error');
```

**Call Tracking:**
```dart
// Verify method was called
expect(engine.openCallCount, 1);
expect(engine.playCallCount, 1);
expect(engine.seekToCallCount, 1);

// Verify call arguments
expect(engine.openPaths.last, contains('b.mp4'));
expect(engine.lastSeekToMs, 30000);
expect(engine.lastExternalSubtitlePath, contains('video.srt'));
expect(engine.lastVideoEffectType, VideoEffectType.brightness);
```

**SharedPreferences Mocking:**
```dart
setUp(() {
  SharedPreferences.setMockInitialValues({});
  SettingsStore.resetPrewarm();
});

test('reads value from SharedPreferences', () async {
  SharedPreferences.setMockInitialValues({'volume': 0.5});
  final settings = await SettingsStore.load();
  expect(settings.volume, closeTo(0.5, 0.01));
});

test('writes value to SharedPreferences', () async {
  await SettingsStore.saveVolume(0.5);
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getDouble('volume'), closeTo(0.5, 0.01));
});
```

**Boundary Testing:**
```dart
test('clamps out-of-range values', () async {
  SharedPreferences.setMockInitialValues({
    'videoBrightness': 5.0,  // above max 1.0
    'videoContrast': -5.0,   // below min -1.0
    'videoRotation': 45,     // not in {0, 90, 180, 270}
  });
  final settings = await SettingsStore.load();
  expect(settings.videoBrightness, 1.0);
  expect(settings.videoContrast, -1.0);
  expect(settings.videoRotation, 0);
});

test('rejects out-of-range index', () async {
  await controller.playIndex(-1);
  await controller.playIndex(99);
  expect(engine.openCallCount, 0);
});
```

**Serialization Round-Trip:**
```dart
test('round-trip', () {
  final original = PlaylistItem(path: '/test/video.mp4');
  final json = original.toJson();
  final restored = PlaylistItem.fromJson(json);
  expect(restored, equals(original));
});

test('fromJson handles empty map', () {
  final restored = Playlist.fromJson({});
  expect(restored.isEmpty, true);
  expect(restored.currentIndex, -1);
  expect(restored.mode, PlayMode.normal);
});
```

**Disposal Testing:**
```dart
test('dispose does not throw', () {
  expect(() => service.dispose(), returnsNormally);
});

test('operations are no-op when disposed', () {
  final testEngine = FakeEngine();
  testEngine.dispose();
  testEngine.setExternalSubtitle('/path/to/sub.srt');
  expect(testEngine.setExternalSubtitleCallCount, 0);
});
```

**Concurrency Guard Testing:**
```dart
test('generation guard: only last request wins', () async {
  final f1 = controller.playIndex(0);
  final f2 = controller.playIndex(1);
  final f3 = controller.playIndex(2);
  await f1;
  await f2;
  await f3;
  expect(playlist.currentIndex, 2);
  expect(controller.currentGeneration, 3);
});
```

**Filesystem Integration:**
```dart
late Directory tempDir;

setUp(() {
  tempDir = Directory.systemTemp.createTempSync('test_prefix_');
});

tearDown(() {
  try {
    tempDir.deleteSync(recursive: true);
  } on Exception {
    // ignore cleanup failures
  }
});

File createFile(String name, [String content = '']) {
  final file = File('${tempDir.path}/$name');
  file.writeAsStringSync(content);
  return file;
}
```

---

*Testing analysis: 2026-05-09*
