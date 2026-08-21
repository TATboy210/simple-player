# Testing Patterns

**Analysis Date:** 2026-08-21

## Test Framework

**Runner:**
- `flutter_test` (SDK) / `dart:test` — built-in test runner
- Config: `analysis_options.yaml` (lint rules), `pubspec.yaml` (dev deps)
- No `dart_test.yaml` custom configuration

**Assertion Library:**
- `package:flutter_test/flutter_test.dart` — `expect`, `matchers`, `testWidgets`
- `package:test/test.dart` not directly imported (flutter_test re-exports)

**Run Commands:**
```bash
flutter test                                    # Run all tests
flutter test test/kernel/services/              # Run tests in a directory
flutter test --coverage                         # Coverage to coverage/lcov.info
flutter test test/widget/player/progress_bar_test.dart  # Single file
flutter test integration_test/simple_test.dart  # Integration test
```

**Static analysis (pre-test gate):**
```bash
flutter analyze                                 # Must pass with 0 errors before tests
```

## Test File Organization

**Location:**
- Mirror source tree under `test/`: `lib/kernel/services/path_validator.dart` → `test/kernel/services/path_validator_test.dart`
- Fakes/helpers in `test/helpers/`
- Fixtures (binary files) in `test/fixtures/`
- Golden reference images in `test/golden/goldens/`

**Naming:**
- Source file + `_test.dart` suffix: `playback_controller.dart` → `playback_controller_test.dart`
- Test groups use Chinese AND English descriptions: `group('基础播放控制门面', ...)`, `group('initial state', ...)`

**Structure:**
```
test/
├── debug/                      # Ad-hoc debugging tests
│   └── button_hit_test.dart
├── diagnostics/                # KernelLogger, memory monitor tests
│   ├── kernel_logger_test.dart
│   ├── kernel_logger_impl_test.dart
│   └── memory_monitor_test.dart
├── engine/                     # Engine mixin/capability tests
│   └── mixin_capability_test.dart
├── features/player/            # Feature-level tests
│   └── file_picker_coordinator_test.dart
├── fixtures/                   # Binary test data (real media files)
│   ├── README.md               # Provenance + SHA-256 checksums
│   ├── tiny_valid.mp4          # Real H.264 video (open→play gate)
│   ├── corrupted_header.mp4    # Corrupted MP4 container
│   ├── empty_file.mp4         # Zero-length file
│   ├── not_a_video.txt         # Wrong format
│   └── unsupported_codec.avi   # Corrupted AVI
├── golden/                     # Golden image regression tests
│   ├── golden_comparator.dart  # TolerantGoldenComparator (5% pixel tolerance)
│   ├── control_layouts_golden_test.dart
│   └── glass_widgets_golden_test.dart
├── helpers/                    # Shared test doubles
│   ├── fake_engine.dart         # Hand-written FakeEngine (no FFI)
│   ├── fake_window_service.dart # FakeWindowService
│   ├── fake_player_controls.dart
│   ├── fake_video_controls.dart
│   └── integration_helpers.dart # buildTestApp(), createTestController()
├── integration/                # Cross-module integration tests
│   ├── controls_flow_test.dart
│   └── playback_flow_test.dart
├── kernel/                     # Kernel unit tests (mirror lib/kernel/)
│   ├── bridge/
│   ├── diagnostics/
│   ├── engine/
│   │   ├── engine_state_machine_test.dart
│   │   ├── media_kit_engine_test.dart
│   │   └── race_condition_test.dart
│   ├── models/
│   ├── persistence/
│   ├── scanner/
│   ├── security/               # Fuzz + security tests
│   │   ├── fuzz_input_test.dart
│   │   ├── resource_exhaustion_test.dart
│   │   └── state_machine_security_test.dart
│   ├── services/
│   ├── startup/
│   ├── utils/
│   └── player_services_test.dart
├── regression/                 # Regression suite
│   ├── diff_report.dart
│   ├── diff_report_test.dart
│   ├── high_risk_suite_test.dart
│   └── smoke_suite_test.dart
├── ui/                         # UI-level tests
│   ├── player/responsive_layout_test.dart
│   └── shared/
├── unit/                       # Additional unit tests
│   ├── bridge/
│   ├── kernel/
│   ├── theme/contrast_test.dart
│   ├── widget/
│   └── widgets/
├── widget/                     # Widget tests (flutter_test)
│   ├── player/                 # Player widget tests
│   │   ├── control_bar_test.dart
│   │   ├── keyboard_handler_test.dart
│   │   ├── progress_bar_test.dart
│   │   └── ...
│   └── shared/                 # Shared widget tests
│       ├── glass_container_test.dart
│       └── ...
└── widgets/
```

**Integration tests:**
```
integration_test/
└── simple_test.dart            # App launch smoke test
```

## Test Structure

**Suite Organization:**
```dart
// From test/kernel/services/playback_controller_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine engine;
  late PlaybackController controller;
  late List<PlayerError> errors;

  setUp(() {
    engine = FakeEngine();
    errors = <PlayerError>[];
    controller = PlaybackController(engine: engine, onError: errors.add);
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('PlaybackController', () {
    group('基础播放控制门面', () {
      test('togglePlayPause delegates to the media engine', () {
        controller.togglePlayPause();
        expect(engine.togglePlayPauseCallCount, 1);
      });
    });
  });
}
```

**Patterns:**
- **Setup:** `setUpAll` for one-time initialization (KernelLogger), `setUp` for per-test state (engine, controller)
- **Teardown:** `tearDown` disposes all `ValueNotifier`-owning objects (prevents listener leaks)
- **Assertion:** `expect(actual, matcher)` with type-safe matchers — `equals`, `isA<Type>()`, `hasLength(n)`, `findsOneWidget`, `findsWidgets`
- **Grouping:** Nested `group()` by class name, then by functional area (Chinese + English labels)
- **Test names:** Behavior-focused, declarative — `'rejects an invalid path before calling the engine'`, `'renders with zero duration without error'`

## Mocking

**Framework:** Hand-written Fakes (no mockito/mocktail)

**Rationale:** Per CLAUDE.md — "Fakes over mocks for complex dependencies (hand-written test doubles)". The codebase uses zero mock-generation packages; all test doubles are hand-written classes implementing real interfaces.

**Patterns:**
```dart
// From test/helpers/fake_engine.dart
class FakeEngine implements MediaEngine, SubtitleConfig {
  bool _disposed = false;

  // ValueNotifiers — independent instances per test
  @override
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);
  @override
  ValueNotifier<MediaState> get state => stateMachine.state;

  // Call tracking fields for assertions
  int openCallCount = 0;
  int playCallCount = 0;
  final List<String> openPaths = [];

  // Controllable failure injection
  String? failNextOpenWith;
  bool seekToShouldThrow = false;

  // Deterministic async gates
  Completer<void>? openGate;

  @override
  Future<OpenResult> open(String path) async {
    if (_disposed) return const OpenSuperseded();
    openCallCount++;
    openPaths.add(path);
    // ... generation guard, failure injection, success path
  }

  // Test helper methods
  void configureMedia({int durationMs = 60000, ...}) { ... }
  void simulateError(String message) { ... }
}
```

**Recording subclasses** for service-level fakes:
```dart
// From test/kernel/services/playback_controller_test.dart
class _RecordingSubtitleService extends SubtitleService {
  _RecordingSubtitleService(super.engine);
  final List<String> detectedPaths = <String>[];

  @override
  Future<void> detectAndLoad(String mediaPath) async {
    detectedPaths.add(mediaPath);
  }
}
```

**What to Mock:**
- `MediaEngine` → `FakeEngine` (`test/helpers/fake_engine.dart`) — avoids `mdk.dll`/libmpv FFI dependency in headless tests
- `WindowBridge` → `FakeWindowService` (`test/helpers/fake_window_service.dart`) — avoids `window_manager` platform plugin
- Service subclasses for recording interactions: `_RecordingSubtitleService`, `_RecordingTrackPreferenceService`
- Platform channels: inject callback parameters instead of real `FilePicker` (see `PlayerScreen.pickSubtitlePath`)

**What NOT to Mock:**
- `EngineStateMachine` — used directly in tests (matches `MediaKitEngine` behavior)
- Real `Playlist`, `PathValidator`, `PathUtils` — pure Dart, no I/O, safe to use directly
- `KernelLoggerImpl` — initialized with real `NullSink` (release-mode sink, zero output)

## Fixtures and Factories

**Test Data:**
- Binary fixtures in `test/fixtures/` — real media files with documented provenance and SHA-256 checksums (`test/fixtures/README.md`)
- `tiny_valid.mp4` (788KB, H.264) — powers the "open to play handoff" gate
- `corrupted_header.mp4`, `empty_file.mp4`, `not_a_video.txt`, `unsupported_codec.avi` — error-path fixtures
- Programmatic test data via `FakeEngine.configureMedia(durationMs: ..., audioTracks: ...)` — no binary dependency

**Location:**
- Binary fixtures: `test/fixtures/`
- Fake helpers: `test/helpers/`
- Golden reference images: `test/golden/goldens/` (auto-created on first run via `TolerantGoldenComparator`)

## Coverage

**Requirements:** 80% minimum (per global testing rules; project does not enforce via CI threshold currently)

**View Coverage:**
```bash
flutter test --coverage
# Generates coverage/lcov.info — view with lcov viewer or genhtml
```

**Known gaps:** `lib/kernel/engine/media_kit_engine.dart` concrete implementation requires native libmpv — not covered by headless `flutter test` (needs `flutter run -d windows` to populate DLLs, documented in `test/fixtures/README.md`)

## Test Types

**Unit Tests:**
- Location: `test/kernel/`, `test/unit/`, `test/diagnostics/`
- Scope: Pure logic — state machines, validators, path utils, models, persistence, playlist logic
- Approach: Direct instantiation, no Flutter binding unless required
- Pattern: `KernelLoggerImpl.init()` in `setUpAll`, `FakeEngine` for engine-dependent tests

**Widget Tests:**
- Location: `test/widget/`, `test/ui/`
- Scope: Single widget behavior — rendering, interaction, keyboard, drag, tap
- Approach: `tester.pumpWidget(buildSubject())`, `tester.tap()`, `tester.sendKeyDownEvent()`
- Binding: `TestWidgetsFlutterBinding.ensureInitialized()` at top of `main()`
- Localization: Wrap in `MaterialApp` with `localizationsDelegates: AppLocalizations.localizationsDelegates`

**Integration Tests:**
- Location: `test/integration/` (cross-module), `integration_test/` (device-level)
- Scope: Multi-component flows — `controls_flow_test.dart`, `playback_flow_test.dart`
- Device-level: `integration_test/simple_test.dart` — launches full `App` with `FakeWindowService`, asserts theme and type

**Golden Tests:**
- Location: `test/golden/`
- Framework: `flutter_test` `matchesGoldenFile` with custom `TolerantGoldenComparator` (`test/golden/golden_comparator.dart`)
- Tolerance: 5% per-channel, 1% max mismatch rate — handles cross-machine rendering differences
- Helper: `enableTolerantGoldens()` in `setUp()`, `wrapForGolden()` for consistent dark background
- Update: `flutter test --update-goldens`

**Security/Fuzz Tests:**
- Location: `test/kernel/security/`
- `fuzz_input_test.dart` — path traversal, null byte, UNC, control chars, extreme lengths
- `resource_exhaustion_test.dart` — resource limits
- `state_machine_security_test.dart` — state machine invariant attacks

**Regression Tests:**
- Location: `test/regression/`
- `smoke_suite_test.dart` — 8 mandatory scenarios (FS-REG-001 ~ FS-REG-008), some pending media_kit integration rewrite
- `high_risk_suite_test.dart`, `diff_report_test.dart`

## Common Patterns

**Async Testing:**
```dart
// From test/kernel/services/playback_controller_test.dart
test('opens one file, starts playback, and publishes its identity', () async {
  engine.configureMedia(durationMs: 120000);
  final result = await controller.openAndPlay('C:/test/video.mp4');
  expect(result, true);
  expect(engine.openPaths, <String>['C:/test/video.mp4']);
});
```

**Deterministic Async Gates (race condition testing):**
```dart
// FakeEngine supports Completer-based gates
engine.openGate = Completer<void>();
// ... trigger operation
// ... assert intermediate state
engine.openGate!.complete();  // release the gate
// ... assert final state
```

**Error Testing:**
```dart
// Failure injection via FakeEngine
engine.failNextOpenWith = 'codec error';
final result = await controller.openAndPlay('bad.mp4');
expect(result, false);
expect(controller.validationError.value, isNotNull);
expect(errors, hasLength(1));

// Exception injection
engine.seekToShouldThrow = true;
// ... assert graceful handling
```

**Widget Interaction Testing:**
```dart
// From test/widget/player/progress_bar_test.dart
testWidgets('tap triggers seekTo', (tester) async {
  engine.duration.value = 10000;
  await tester.pumpWidget(buildSubject());
  final bar = find.byType(ProgressBar);
  await tester.tapAt(tester.getRect(bar).center);
  await tester.pump();
  expect(engine.seekToCallCount, greaterThanOrEqualTo(1));
});

// Keyboard testing (test/widget/player/keyboard_handler_test.dart)
testWidgets('space key triggers play/pause', (tester) async {
  await tester.pumpWidget(_buildSubject(tracker));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
  expect(tracker.playPause, 1);
});
```

**Callback Tracking:**
```dart
// From test/widget/player/keyboard_handler_test.dart
class _CallbackTracker {
  int playPause = 0;
  int seekBackward = 0;
  // ... one field per callback
}
// Inject as lambdas: onPlayPause: () => t.playPause++
```

**KernelLogger Test Setup:**
```dart
// Standard pattern across kernel tests
setUpAll(() {
  KernelLoggerImpl.resetForTesting();
  KernelLoggerImpl.init();
});
// init() with no args in test → uses release NullSink (zero output)
// resetForTesting() ensures isolation between test files
```

**Headless FFI Limitation (mdk.dll):**
- `MediaKitEngine` depends on native libmpv (`mdk.dll`) — NOT loadable in headless `flutter test` (error code 126)
- All tests use `FakeEngine` to bypass this; tests that need real engine require DLL provisioning (documented in `test/fixtures/README.md`)
- `@visibleForTesting` static methods on `MediaKitEngine` (e.g., `mediaUriFromPath`) test pure logic without FFI

---

*Testing analysis: 2026-08-21*
