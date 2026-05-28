# Testing Patterns

**Analysis Date:** 2026-05-28

## Framework

| Component | Tool |
|-----------|------|
| Runner | `flutter_test` (SDK) |
| Assertions | Built-in `expect`, `matcher` |
| Mocking | Hand-written fakes (no mockito) |
| Persistence | `SharedPreferences.setMockInitialValues({})` |

## Test Organization

```
test/
├── helpers/
│   └── fake_engine.dart              # Shared FakeEngine (354 lines)
├── kernel/
│   ├── engine/                       # 3 files
│   ├── models/                       # 4 files
│   ├── persistence/                  # 2 files
│   ├── playlist/                     # 1 file
│   ├── services/                     # 7 files
│   └── utils/                        # 1 file
├── unit/
│   ├── kernel/engine/                # 1 file
│   └── perf/                         # 1 file
└── widget/
    └── player/                       # 6 files
```

**Total: 27 test files**

## FakeEngine Pattern

**File:** `test/helpers/fake_engine.dart` (354 lines)
**Purpose:** Implements `MediaEngine` without FFI dependency

### Capabilities
```dart
class FakeEngine implements MediaEngine {
  // Call tracking
  int openCallCount = 0;
  int playCallCount = 0;
  final List<String> openPaths = [];

  // Error injection
  String? failNextOpenWith;

  // State simulation
  void configureMedia({int durationMs = 60000, ...}) { ... }
  void simulateError(String message) { ... }
  void simulateCompleted() { ... }
  void simulateBuffering(bool buffering) { ... }
}
```

## Test Structure (AAA)

```dart
group('FeatureName', () {
  group('subFeature', () {
    test('behavior description', () {
      // Arrange (in setUp)
      // Act
      // Assert
    });
  });
});
```

### Setup Pattern
```dart
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
```

## Coverage

| Metric | Value |
|--------|-------|
| Lines covered | 1,161 / 1,822 |
| Coverage % | 63.7% |
| Files covered | 38 / 94 (40%) |
| Target | 80% |
| Enforcement | None (no CI threshold) |

## What Is Tested

| Layer | Component | Status |
|-------|-----------|--------|
| kernel/models | PlaylistItem, MediaInfo, PlayerError | Comprehensive |
| kernel/playlist | Playlist | Comprehensive |
| kernel/utils | PathUtils, PathValidator | Comprehensive |
| kernel/persistence | PlaylistStore, SettingsStore | Comprehensive |
| kernel/engine | FvpCallbackHandler, PositionPoller, TrackManager | Basic |
| features/services | PlaybackController, PlaybackNavigator, FileOperations | Comprehensive |
| features/services | StateMonitor, VideoProcessingService, SubtitleService | Comprehensive |
| ui/player | AutoHideController, VolumeControls, OsdOverlay | Comprehensive |
| ui/player | ControlsOverlay, VideoSurface, ControlBar | Basic |

## What Is NOT Tested

| Component | Risk |
|-----------|------|
| FvpEngine (full) | High — FFI boundary |
| PlayerScreen | Medium — composition |
| PlaylistPanel | Medium — complex UI |
| SettingsPanel | Medium — complex UI |
| KeyboardHandler | Medium — 20+ key bindings |
| CustomTitleBar | Medium — Win32 integration |
| FolderScanner | Medium — file system |
| ThumbnailService | High — Win32 COM |
| StartupCoordinator | Medium — state machine |
| AuroraBackground | Low — visual |
| Localization | Low — generated |

## Common Patterns

### Async Testing
```dart
test('openAndPlay adds file', () async {
  engine.configureMedia(durationMs: 120000);
  final result = await controller.openAndPlay('C:/test/video.mp4');
  await Future(() {});  // yield for backgrounded async
  expect(result, true);
});
```

### Error Testing
```dart
test('rejects invalid path', () async {
  final result = await controller.openAndPlay('');
  expect(result, false);
  expect(controller.validationError.value, isNotNull);
});
```

### State Transition Testing
```dart
test('auto-plays next in loopAll', () async {
  registerAutoAdvance();
  await controller.playIndex(0);
  engine.simulateCompleted();
  await Future(() {});
  expect(playlist.currentIndex, 1);
});
```

## Notes

- No golden tests (visual regression)
- No integration tests (package present, no files)
- No coverage enforcement
- Hand-written fakes only (no mockito)
- `SharedPreferences.setMockInitialValues({})` for persistence isolation
