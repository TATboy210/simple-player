# Testing Patterns

**Analysis Date:** 2026-05-23

## Test Framework

**Runner:**
- `flutter_test` (from Flutter SDK)
- Config: `pubspec.yaml` dev_dependencies

**Assertion Library:**
- Built-in `expect` with matchers (`isTrue`, `isNull`, `contains`, `closeTo`, etc.)

**Run Commands:**
```bash
flutter test                    # Run all tests
flutter test --coverage         # Run with coverage
flutter test test/kernel/       # Run specific directory
flutter test test/kernel/services/path_validator_test.dart  # Run single file
```

## Test File Organization

**Location:**
- Tests mirror source structure: `lib/kernel/services/foo.dart` → `test/kernel/services/foo_test.dart`
- Helpers in `test/helpers/` (e.g., `fake_engine.dart`)
- Widget tests in `test/widget/` (e.g., `test/widget/player/`)
- Window tests in `test/window/` (e.g., `test/window/window_service_test.dart`)

**Naming:**
- `{source_file_name}_test.dart`
- Same directory structure as `lib/` but under `test/`

**Structure:**
```
test/
├── helpers/
│   └── fake_engine.dart              # Shared FakeEngine implementation
├── kernel/
│   ├── bridge/
│   │   └── window_bridge_test.dart
│   ├── engine/
│   │   ├── fvp_callback_handler_test.dart
│   │   ├── position_poller_test.dart
│   │   └── track_manager_test.dart
│   ├── models/
│   │   ├── aspect_ratio_mode_test.dart
│   │   ├── media_info_test.dart
│   │   ├── player_error_test.dart
│   │   └── playlist_item_test.dart
│   ├── persistence/
│   │   ├── playlist_store_test.dart
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
│       └── aspect_ratio_service_test.dart
├── unit/
│   ├── kernel/engine/
│   │   └── media_engine_extension_test.dart
│   └── perf/
│       └── startup_parallel_init_test.dart
├── widget/
│   ├── player/
│   │   ├── auto_hide_controller_test.dart
│   │   ├── control_bar_test.dart
│   │   ├── controls_overlay_test.dart
│   │   ├── osd_overlay_test.dart
│   │   ├── video_surface_test.dart
│   │   └── volume_controls_test.dart
│   └── window/
│       └── custom_title_bar_test.dart
└── window/
    ├── geometry_store_test.dart
    ├── window_service_test.dart
    └── window_shell_test.dart
```

## Test Structure

**Suite Organization:**
```dart
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();  // Required for platform plugins

  late FakeEngine engine;
  late Playlist playlist;
  late PlaybackController controller;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => rebuildCount++,
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('FeatureName', () {
    group('methodName', () {
      test('does something when condition', () async {
        // Arrange
        engine.configureMedia(durationMs: 60000);
        
        // Act
        final result = await controller.openAndPlay('C:/test/video.mp4');
        
        // Assert
        expect(result, true);
        expect(playlist.length, 1);
      });
    });
  });
}
```

**Patterns:**
- `setUp()` creates fresh instances for each test
- `tearDown()` disposes all ValueNotifiers and services
- `late` variables for test-scoped instances
- `group()` for logical grouping by feature/method
- `TestWidgetsFlutterBinding.ensureInitialized()` when using platform plugins

## Mocking

**Framework:** Hand-written fakes (NO Mockito)

**Why no Mockito:**
- ValueNotifier-based state doesn't need mock verification
- Fakes provide controllable behavior + call tracking
- Simpler, no code generation required

**Primary Fake: `FakeEngine`** (`test/helpers/fake_engine.dart`)

```dart
class FakeEngine implements MediaEngine {
  // ValueNotifier fields with defaults
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);
  final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
  // ... all 10+ ValueNotifiers

  // Call tracking for test introspection
  int openCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  int stopCallCount = 0;
  final List<String> openPaths = [];
  int seekToCallCount = 0;
  int? lastSeekToMs;
  int setVideoEffectCallCount = 0;
  VideoEffectType? lastVideoEffectType;
  double? lastVideoEffectValue;

  // Controllable behavior
  String? failNextOpenWith;  // One-shot error simulation

  // Test helpers
  void configureMedia({int durationMs = 60000, ...}) { ... }
  void simulateError(String message) { ... }
  void simulateCompleted() { ... }
  void simulateBuffering(bool buffering) { ... }
}
```

**What to Mock/Fake:**
- `MediaEngine` → `FakeEngine` (always)
- `WindowService` → mock or test instance
- `SharedPreferences` → `SharedPreferences.setMockInitialValues({})`
- Platform channels → `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`

**What NOT to Mock:**
- `Playlist` — use real instance (pure Dart, no side effects)
- `PathValidator` — use real implementation (static methods, no state)
- Model classes (`PlaylistItem`, `MediaInfo`, `PlayerError`) — always real
- `VideoProcessingService` — use real with FakeEngine

## Fixtures and Factories

**Test Data:**
```dart
// Engine configuration
engine.configureMedia(durationMs: 120000);  // 2 minutes
engine.configureMedia(
  durationMs: 60000,
  audioTracks: [AudioTrackInfo(index: 0, language: 'en', codec: 'aac', channels: 2)],
  subtitleTracks: [SubtitleTrackInfo(index: 0, language: 'zh', title: 'Chinese')],
);

// Playlist setup
playlist.add('C:/a.mp4');
playlist.add('C:/b.mp4');
playlist.add('C:/c.mp4');
playlist.mode = PlayMode.loopAll;

// PathValidator test data
PathValidator.isAllowedMedia('/video.mp4');  // true
PathValidator.isPathTraversal('/../../../etc/passwd');  // true
PathValidator.validate('/video.mp4');  // null (valid)
```

**Location:**
- Shared fakes: `test/helpers/fake_engine.dart`
- Inline fakes: defined at bottom of test file

## Coverage

**Requirements:** 80%+ line coverage for business logic (per CLAUDE.md)

**View Coverage:**
```bash
flutter test --coverage           # Generates coverage/lcov.info
# Use lcov or similar tool to generate HTML report
```

## Test Types

**Unit Tests:**
- Models: `PlaylistItem`, `PlayerError`, `MediaInfo`, `AspectRatioMode`
- Services: `PathValidator`, `PlaybackController`, `VideoProcessingService`
- Utils: `PathUtils`, `TimeUtils`
- All kernel/ code except engine FFI layer

**Widget Tests:**
- Player UI: `ControlsOverlay`, `ControlBar`, `VolumeControls`, `SpeedButton`
- Shared: `GlassContainer`, `OsdOverlay`
- Window: `CustomTitleBar`
- Use `FakeEngine` + `MaterialApp` wrapper

**No E2E Tests:**
- Not applicable (desktop app, no integration_test framework used)

## Widget Test Patterns

**Build Helper:**
```dart
Widget buildSubject({
  MediaEngine? eng,
  bool isFullscreen = false,
  VoidCallback? onToggleFullscreen,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ControlsOverlay(
        engine: eng ?? engine,
        isFullscreen: isFullscreen,
        onToggleFullscreen: onToggleFullscreen,
      ),
    ),
  );
}
```

**Common Assertions:**
```dart
// Widget existence
expect(find.byType(ControlsOverlay), findsOneWidget);
expect(find.byIcon(Icons.volume_off), findsOneWidget);

// State verification
expect(engine.state.value, MediaState.playing);
expect(engine.openCallCount, 1);
expect(engine.lastVideoEffectType, VideoEffectType.brightness);

// Value changes
engine.volume.value = 0.7;
await tester.pump();
final slider = tester.widget<Slider>(find.byType(Slider));
expect(slider.value, 0.7);
```

**Gesture Testing:**
```dart
// Tap
await tester.tap(find.byType(GestureDetector).first);
await tester.pump();

// Double tap (with timing)
final center = tester.getCenter(find.byType(ControlsOverlay));
await tester.tapAt(center);
await tester.pump(const Duration(milliseconds: 50));
await tester.tapAt(center);
await tester.pump(const Duration(milliseconds: 300));

// Drag
final gesture = await tester.startGesture(Offset(startX, center.dy));
await gesture.moveBy(Offset(endX - startX, 0));
await gesture.up();
await tester.pump();

// Mouse hover (desktop)
final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
await gesture.addPointer(location: tester.getCenter(find.byType(ControlsOverlay)));
addTearDown(gesture.removePointer);
await gesture.moveTo(tester.getCenter(find.byType(ControlsOverlay)));
await tester.pump();
```

## Common Patterns

**Async Testing:**
```dart
// Wait for async operations
await Future(() {});  // Yield to microtask queue
await Future<void>.delayed(const Duration(milliseconds: 100));  // Wait for debounce

// SharedPreferences mock
SharedPreferences.setMockInitialValues({});
final prefs = await SharedPreferences.getInstance();
expect(prefs.getDouble('videoBrightness'), closeTo(0.5, 0.01));
```

**Platform Channel Mocking:**
```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
```

**Ticker Provider for Animation Tests:**
```dart
class _TestTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

// Usage
late _TestTickerProvider vsync;
setUp(() {
  vsync = _TestTickerProvider();
});
```

**Lifecycle Management:**
```dart
// Use addTearDown for inline-created resources
final s = VideoProcessingService(engine, initialSettings: settings);
addTearDown(s.dispose);

// Or use late + tearDown
late FakeEngine engine;
setUp(() { engine = FakeEngine(); });
tearDown(() { engine.dispose(); });
```

**Error Simulation:**
```dart
// One-shot error
engine.failNextOpenWith = 'File not found';
await controller.openAndPlay('C:/missing.mp4');
expect(engine.state.value, MediaState.error);

// Direct error state
engine.simulateError('Network timeout');
expect(engine.errorMessage.value, 'Network timeout');

// Completion simulation
engine.simulateCompleted();
```

---

*Testing analysis: 2026-05-23*
