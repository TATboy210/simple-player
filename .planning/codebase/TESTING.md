# Testing Patterns

**Analysis Date:** 2026-05-07

## Test Framework

**Runner:**
- `flutter_test` (built-in with Flutter SDK)
- Config: `pubspec.yaml` dev_dependencies: `flutter_test: sdk: flutter`

**Assertion Library:**
- Built-in `expect()` from `flutter_test` / `test` package
- Matchers: `equals`, `isNull`, `isNotNull`, `isTrue`, `isFalse`, `isEmpty`, `isNotEmpty`, `contains`, `closeTo`, `throwsA`, `isA<Type>()`, `greaterThan`, `greaterThanOrEqualTo`, `anyOf`, `same`

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --coverage         # Run with coverage report
flutter test test/kernel/playlist/playlist_test.dart  # Run single file
```

## Test File Organization

**Location:**
- Co-located with source: `lib/kernel/playlist/playlist.dart` -> `test/kernel/playlist/playlist_test.dart`
- Additional test directories:
  - `test/helpers/` -- Shared fakes and test utilities
  - `test/unit/` -- Additional unit tests (platform service, perf)
  - `test/unit/kernel/engine/` -- Engine extension tests

**Naming:**
- Source file: `playlist.dart` -> Test file: `playlist_test.dart`
- Helpers: `fake_engine.dart` (no `_test` suffix)

**Directory Structure:**
```
test/
├── helpers/
│   └── fake_engine.dart              # Hand-written FakeEngine for MediaEngine
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
│   ├── utils/
│   │   └── path_utils_test.dart
│   └── window/
│       ├── aspect_ratio_service_test.dart
│       └── window_manager_service_test.dart
└── unit/
    ├── kernel/engine/
    │   └── media_engine_extension_test.dart
    ├── perf/
    │   └── startup_parallel_init_test.dart
    └── platform_service_test.dart
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  group('ClassName', () {
    late ClassName instance;

    setUp(() {
      instance = ClassName();
    });

    tearDown(() {
      instance.dispose();
    });

    group('feature area', () {
      test('describes expected behavior', () {
        // Arrange
        // Act
        // Assert
      });
    });
  });
}
```

**Patterns:**
- `setUp()` for creating instances and resetting state
- `tearDown()` for disposing resources (ValueNotifiers, engines, controllers)
- Nested `group()` by class name, then by feature/behavior area
- `TestWidgetsFlutterBinding.ensureInitialized()` at top of `main()` when testing code that uses Flutter bindings (SchedulerBinding, platform channels)
- Chinese test descriptions are acceptable: `test('rejects non-string path', () { ... })`

**Test Naming:**
- Descriptive behavior-focused names in English or Chinese
- Format: `test('action/behavior when condition', () { ... })`
- Examples:
  - `test('rejects empty path and sets validationError', () async { ... })`
  - `test('maps stopped to MediaState.stopped', () { ... })`
  - `test('fromJson clamps out-of-range mode', () { ... })`

## Mocking / Faking

**Framework:** Hand-written fakes (no mockito/mocktail)

**Primary Fake:** `FakeEngine` at `test/helpers/fake_engine.dart`
- Implements `MediaEngine` interface completely
- No FFI imports, no platform plugins -- runs purely in Dart
- Call tracking: `openCallCount`, `playCallCount`, `pauseCallCount`, `stopCallCount`, `openPaths`
- Configurable failure: `failNextOpenWith` (one-shot error injection)
- Pre-configuration: `configureMedia(durationMs:, audioTracks:, subtitleTracks:)`
- Simulation helpers: `simulateError()`, `simulateCompleted()`, `simulateBuffering()`
- Trackable state for new methods: `seekToCallCount`, `lastSeekToMs`, `setExternalSubtitleCallCount`, `lastExternalSubtitlePath`, `setVideoEffectCallCount`, `lastVideoEffectType`, `rotateCallCount`, etc.

**Secondary Fake:** `FakePlatformService` at `test/unit/platform_service_test.dart`
- Implements `PlatformService` interface
- Call counters for all window methods: `minimizeCalls`, `toggleMaximizeCalls`, etc.

**What to Fake:**
- All external dependencies with FFI/platform channels (mdk.Player, window_manager, SharedPreferences)
- Abstract interfaces: `MediaEngine`, `PlatformService`
- I/O operations: file system access for subtitle detection tests uses real temp directories

**What NOT to Fake:**
- Pure data classes (`Playlist`, `PlaylistItem`, `MediaInfo`, `AppSettings`)
- Pure utility functions (`PathUtils`, `PathValidator`, `formatMs`)
- Enum mappings (`FvpCallbackHandler.mapMdkState`)

**SharedPreferences Mocking:**
```dart
setUp(() {
  SharedPreferences.setMockInitialValues({'key': value});
});
```
- Use `SharedPreferences.setMockInitialValues()` for persistence tests
- Call `SettingsStore.resetPrewarm()` in setUp/tearDown to clear cached instance
- Call `PlaylistStore.reset()` in tearDown to clear static debounce state

**MethodChannel Mocking:**
```dart
setUp(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.simple_player/aspect_ratio'),
    (MethodCall methodCall) async {
      calls.add(methodCall);
      return null;
    },
  );
});
```
- Used for testing `AspectRatioService` native calls
- Verify method name and arguments sent to platform

## Async Testing

**Pattern -- yield to let async complete:**
```dart
test('adds file to playlist and starts playback', () async {
  engine.configureMedia(durationMs: 120000);
  final result = await controller.openAndPlay('C:/test/video.mp4');
  await Future(() {});  // Yield to let backgrounded playIndex complete
  expect(result, true);
  expect(engine.state.value, MediaState.playing);
});
```

**Pattern -- debounce testing with delayed wait:**
```dart
test('brightness change persists to SharedPreferences', () async {
  service.brightness.value = 0.5;
  await Future<void>.delayed(const Duration(milliseconds: 100));  // Wait for 50ms debounce
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getDouble('videoBrightness'), closeTo(0.5, 0.01));
});
```

**Pattern -- widget tester pump for timers:**
```dart
testWidgets('isResizing resets after debounce', (WidgetTester tester) async {
  wm.onWindowResize();
  wm.onWindowResized();
  await tester.pump(const Duration(milliseconds: 600));
  expect(wm.isResizing.value, isFalse);
});
```

## Fixtures and Factories

**Test Data:**
- Inline test data in each test file (no shared fixtures directory)
- Paths use Windows-style strings: `'C:/test/video.mp4'`, `'C:/a.mp4'`
- Playlist creation helper in setUp:
```dart
setUp(() {
  playlist = Playlist();
  playlist.add('C:/a.mp4');
  playlist.add('C:/b.mp4');
  playlist.add('C:/c.mp4');
});
```

**Auto-advance helper (reused across test files):**
```dart
void registerAutoAdvance() {
  engine.state.addListener(() {
    final state = engine.state.value;
    if (state != MediaState.completed) return;
    if (playlist.mode == PlayMode.loopSingle) {
      controller.playIndex(playlist.currentIndex).catchError((e) {});
    } else {
      controller.playNext().catchError((e) {});
    }
  });
}
```

**Temp directory for file I/O tests:**
```dart
setUp(() {
  tempDir = Directory.systemTemp.createTempSync('subtitle_test_');
});
tearDown(() {
  tempDir.deleteSync(recursive: true);
});
```

## Coverage

**Requirements:** Not explicitly enforced in config, but CLAUDE.md states 80% minimum target.

**View Coverage:**
```bash
flutter test --coverage           # Generates coverage/lcov.info
```

## Test Types

**Unit Tests:**
- All kernel logic: Playlist, PlaylistItem, PathValidator, PathUtils, SettingsStore, formatMs
- All services via FakeEngine: PlaybackController, FileOperations, PlaybackNavigator, StateMonitor, VideoProcessingService
- Engine helpers: FvpCallbackHandler (static mapMdkState), TrackManager (data classes)
- Model classes: MediaInfo, VideoCodecInfo, AspectRatioMode, AppSettings
- Window services: WindowManagerService (via WindowListener callbacks), AspectRatioService (via MethodChannel mock)
- Platform service: PlatformService singleton lifecycle via FakePlatformService
- Persistence: SettingsStore with SharedPreferences mocks

**Widget Tests:**
- WindowManagerService resize debouncing uses `testWidgets` with `tester.pump()`
- No dedicated widget tests for UI components in this directory (UI widgets may be tested elsewhere)

**Integration/E2E Tests:**
- Not present in this test directory
- `external_subtitle_test.dart` is a hybrid: uses real filesystem (temp directory) with FakeEngine

## Common Patterns

**ValueNotifier assertion:**
```dart
test('mode ValueNotifier notifies listeners on change', () {
  final values = <WindowMode>[];
  wm.mode.addListener(() => values.add(wm.mode.value));
  wm.mode.value = WindowMode.fullscreen;
  wm.mode.value = WindowMode.windowed;
  expect(values, [WindowMode.fullscreen, WindowMode.windowed]);
});
```

**Error injection:**
```dart
test('restores old index on engine.open failure', () async {
  playlist.add('C:/a.mp4');
  playlist.add('C:/b.mp4');
  await controller.playIndex(0);
  final oldIndex = playlist.currentIndex;
  engine.failNextOpenWith = 'open failed';
  await controller.playIndex(1);
  expect(playlist.currentIndex, oldIndex);
});
```

**Serialization round-trip:**
```dart
test('round-trip', () {
  final original = PlaylistItem(path: '/test/video.mp4');
  final json = original.toJson();
  final restored = PlaylistItem.fromJson(json);
  expect(restored, equals(original));
});
```

**Defensive boundary testing:**
```dart
test('rejects non-string path', () {
  expect(
    () => PlaylistItem.fromJson({'path': 123}),
    throwsA(isA<FormatException>()),
  );
});
```

**PlatformException rollback testing:**
```dart
test('setAspectRatio rolls back on platform exception', () async {
  await service.setAspectRatio(1.5);
  expect(service.current, 1.5);
  // Override with error handler
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.simple_player/aspect_ratio'),
    (MethodCall methodCall) async {
      throw PlatformException(code: 'ERROR', message: 'test error');
    },
  );
  await service.setAspectRatio(2.0);
  expect(service.current, 1.5);  // Rolled back
});
```

---

*Testing analysis: 2026-05-07*
