# Stack Research: PlayerEngine Refactoring

> Generated 2026-06-29. Based on codebase analysis of `simple_player_flutter` engine layer.

## Import Migration

### Current State

The external `player_engine` package lives at `D:\widget_tree_flutter\player_engine\` (path dependency in pubspec.yaml). It exports 8 symbols:

| Symbol | Source |
|--------|--------|
| `PlayerEngine` (abstract class) | `player_engine_base.dart` |
| `MediaState` (enum) | `media_state.dart` |
| `MediaErrorType` (enum) | `media_error_type.dart` |
| `VideoEffectType` (enum) | `video_effect_type.dart` |
| `MediaInfo` (data class) | `models/media_info.dart` |
| `AudioTrackInfo` (data class) | `models/audio_track_info.dart` |
| `SubtitleTrackInfo` (data class) | `models/subtitle_track_info.dart` |
| `VideoCodecInfo` (data class) | `models/video_codec_info.dart` |

**60 files** import `package:player_engine/player_engine.dart` (57 Dart source + 3 planning/docs).

Local barrel `lib/kernel/engine/player_engine.dart` already re-exports the same 8 symbols using `package:simple_player_flutter/kernel/engine/...` paths. The local copies exist and are the source of truth.

### Migration Strategy: Mechanical Find-and-Replace

**Single operation:** Replace `import 'package:player_engine/player_engine.dart'` with `import 'package:simple_player_flutter/kernel/engine/player_engine.dart'` in all 57 Dart files.

**Why this works:**
- The local barrel exports the exact same 8 symbols with identical APIs
- No symbol name changes, no type changes
- `dart fix` cannot automate this (it only handles deprecated imports)
- `sed`/PowerShell `-replace` is safe because the import string is unique and literal

**Execution steps:**

```powershell
# 1. Count files to verify
(Get-ChildItem -Recurse -Filter *.dart | Select-String "package:player_engine/player_engine.dart").Count

# 2. Bulk replace (lib/ + test/)
Get-ChildItem -Recurse -Filter *.dart -Path lib,test |
  ForEach-Object {
    (Get-Content $_.FullName -Raw) -replace `
      "import 'package:player_engine/player_engine.dart'", `
      "import 'package:simple_player_flutter/kernel/engine/player_engine.dart'" |
    Set-Content $_.FullName -NoNewline
  }

# 3. Verify zero remaining references
(Get-ChildItem -Recurse -Filter *.dart -Path lib,test |
  Select-String "package:player_engine").Count  # Should be 0

# 4. Remove dependency from pubspec.yaml
# Delete: player_engine:
#         path: ../widget_tree_flutter/player_engine

# 5. Run flutter pub get + flutter analyze
```

**Risk mitigation:**
- Run `flutter analyze` after replacement to catch any import resolution failures
- The local barrel uses `package:simple_player_flutter/...` absolute paths (not relative), so it works from any directory depth
- No circular dependency risk: the barrel only exports leaf types (enums, data classes, abstract class)

### File Breakdown (57 source files)

| Layer | Files | Import target |
|-------|-------|---------------|
| `lib/kernel/engine/` | 7 | fvp_engine, mock_engine, media_opener, track_manager, video_effect_controller, fvp_callback_handler, open_result |
| `lib/features/player/` | 8 | player_feature, deferred_player_feature, player_services, playback_controller, playback_navigator, state_monitor, subtitle_service, video_processing_service |
| `lib/ui/player/` | 11 | player_screen, control_bar, controls_overlay, progress_bar, volume_controls, speed_button, video_surface, center_controls, error_banner, auto_hide_controller, time_range_display |
| `lib/ui/dialogs/` | 4 | settings_panel, media_info_dialog, audio_tab, equalizer_tab, settings_tab_performance |
| `lib/ui/shared/` | 2 | empty_state, aurora_background |
| `lib/` (root) | 1 | app.dart |
| `test/` | 18 | All test files importing the engine types |

## Composition Patterns

### Current Architecture: Already Composed

FvpEngine already delegates to 5 helper components:

```
FvpEngine (orchestrator, ~547 lines)
  ├── FvpCallbackHandler   — mdk callback registration, state mapping
  ├── PositionPoller       — 250ms timer for position updates
  ├── TrackManager         — audio/subtitle track selection
  ├── MediaOpener          — open/prepare/metadata/texture pipeline
  ├── VideoEffectController — brightness/contrast/hue/saturation/rotation
  └── (inline)             — volume, mute, D3D11 config, equalizer, dispose
```

Three additional helpers exist but are **not yet wired into FvpEngine**:

| Helper | Purpose | Status |
|--------|---------|--------|
| `D3D11Configurator` | Hardware decoding + CPU/GPU sync | Extracted, not delegated |
| `SubtitleConfigurator` | External subtitle + delay + equalizer | Extracted, not delegated |
| `VolumeController` | Volume + mute + auto-mute logic | Extracted, not delegated |

### Recommended: Finish Delegation

Wire the 3 remaining helpers into FvpEngine. The pattern is identical to existing helpers:

```dart
// In FvpEngine._createPlayer():
late D3D11Configurator _d3d11Configurator;
late SubtitleConfigurator _subtitleConfigurator;
late VolumeController _volumeController;

mdk.Player _createPlayer() {
  final p = mdk.Player();
  // ... existing helpers ...
  _d3d11Configurator = D3D11Configurator(p);
  _subtitleConfigurator = SubtitleConfigurator(p);
  _volumeController = VolumeController(p, volume: volume, isMuted: isMuted);
  // ...
}
```

Then delegate from FvpEngine methods:

```dart
// Before (inline):
void setVolume(double value) {
  _guardedAction('setVolume', () {
    final clamped = value.clamp(0.0, 1.0);
    _player.volume = clamped;
    volume.value = clamped;
    // ... mute logic ...
  });
}

// After (delegated):
void setVolume(double value) {
  _guardedAction('setVolume', () {
    _volumeController.setVolume(value);
  });
}
```

**Benefits:**
- Each helper is independently testable (already have `video_effect_controller_test.dart`, `track_manager_test.dart`)
- FvpEngine shrinks from ~547 to ~350 lines (orchestrator only)
- D3D11 specifics isolated for future platform-specific extraction

### Composition vs Inheritance

The codebase correctly uses **composition over inheritance**. FvpEngine extends PlayerEngine (abstract interface) but delegates to composed helpers. This is the right pattern:

- `PlayerEngine` = contract for UI layer (12 ValueNotifiers + playback methods)
- `FvpEngine` = concrete implementation that composes fvp-specific helpers
- `MockEngine` = test double implementing the same contract

**Do NOT introduce a "BaseEngine" or mixin hierarchy.** The flat abstract class + concrete composition is simpler and matches IINA's single-engine architecture.

### media_kit Evaluation (Future)

media_kit 1.2.6 uses libmpv (not MDK). Key differences:

| Capability | fvp (MDK) | media_kit (libmpv) |
|------------|-----------|-------------------|
| `setProperty()` | Direct key-value | mpv_set_property (similar) |
| D3D11 sync control | `d3d11.sync.cpu` | Not exposed |
| FFmpeg equalizer | `af` filter string | mpv `af` equivalent exists |
| Video effects | `setVideoEffect()` API | Manual vf filters |
| Hardware decoding | `video.decoders` chain | `hwdec` option |
| Texture rendering | D3D11 via fvp plugin | Similar via mpv render API |

**Verdict:** media_kit can replace fvp at the PlayerEngine interface level, but loses D3D11Configurator and fine-grained hardware decoder control. The composition pattern makes this swap feasible: only FvpEngine and its helpers change, UI layer untouched.

**If pursuing media_kit migration:**
1. Create `MpvEngine implements PlayerEngine` (parallel to FvpEngine)
2. Reuse `PlayerEngine` abstract interface unchanged
3. Create `MpvVideoEffectController`, `MpvTrackManager`, etc. as needed
4. MockEngine stays identical
5. Gate via factory: `PlayerEngine createEngine() => useMpv ? MpvEngine() : FvpEngine()`

## Testing Strategy

### Current Test Architecture

```
test/
  helpers/
    fake_engine.dart          — FakeEngine for widget tests (full implementation)
  kernel/engine/
    video_effect_controller_test.dart
    track_manager_test.dart
    fvp_callback_handler_test.dart
    media_opener_test.dart
  widget/player/
    control_bar_test.dart     — Uses FakeEngine
    controls_overlay_test.dart
    volume_controls_test.dart
    video_surface_test.dart
    auto_hide_controller_test.dart
    error_banner_test.dart
    control_bar_startup_test.dart
  integration/
    playback_flow_test.dart   — End-to-end with FakeEngine
```

### Three Testing Layers

**Layer 1: Helper unit tests** (already exist)

Each helper (VideoEffectController, TrackManager, FvpCallbackHandler, MediaOpener) is tested against a real or mocked `mdk.Player`. These test the composition boundary.

**Recommendation:** Add unit tests for the 3 newly-wired helpers:
- `volume_controller_test.dart` — auto-mute at zero, unmute on raise
- `subtitle_configurator_test.dart` — delay parsing, equalizer passthrough
- `d3d11_configurator_test.dart` — sync mode toggle, decoder chain switch

**Layer 2: MockEngine for widget tests** (already exists)

`MockEngine` implements `PlayerEngine` with simulated playback (position timer, state machine, error injection). Widget tests use this to verify UI behavior without real media.

**Key testing patterns:**

```dart
// Widget test with MockEngine
final engine = MockEngine(openDelay: Duration.zero);
engine.configureMedia(durationMs: 120000);
await tester.pumpWidget(MyApp(engine: engine));

// Verify UI responds to engine state
engine.open('test.mp4');
await tester.pump();
expect(find.text('Loading'), findsOneWidget);

engine.state.value = MediaState.playing;
await tester.pump();
expect(find.byIcon(Icons.pause), findsOneWidget);
```

**Layer 3: FakeEngine for integration tests**

`FakeEngine` (in `test/helpers/`) is a full implementation for integration-level widget tests. It differs from MockEngine in that it's designed for testing complete UI flows rather than isolated widget behavior.

### Testing After Import Migration

The import migration is purely mechanical (string replacement). Test verification:

1. `flutter analyze` — catches any unresolved imports
2. `flutter test` — runs all existing tests, should pass unchanged
3. No new tests needed for the migration itself

### MockEngine Improvements (Optional)

Current MockEngine has full debug instrumentation (event history, state history, JSON export). Consider:

- Add `FakeEngine extends MockEngine` alias for test clarity (or rename)
- Add `configureMedia` with video dimensions for aspect ratio testing
- Add network error simulation (`failNextOpenWith` already exists for file errors)

## Flutter Desktop Specifics

### Win32 / D3D11

The fvp plugin uses D3D11 for GPU-accelerated rendering on Windows. Key integration points:

| Concern | Location | Notes |
|---------|----------|-------|
| D3D11 sync mode | `D3D11Configurator` | `d3d11.sync.cpu` property (0=async, 1=sync) |
| Hardware decoders | `D3D11Configurator` | `video.decoders` chain: D3D11 > NVDEC > FFmpeg |
| Memory optimization | `FvpEngine._applyD3d11Defaults()` | threads=2, buffer_frames=3, starts_with_key=1 |
| Refresh rate | `DisplayConfig` | Used for sync mode selection |
| Texture ID | `mdk.Player.textureId` | Passed to Flutter `Texture` widget |

**D3D11Configurator extraction is important** because:
- D3D11 properties are Windows-specific (no-op on Linux/macOS)
- Future platform branching: `if (Platform.isWindows) D3D11Configurator(p)`
- Isolates GPU-specific error handling

### fvp Plugin Integration

The fvp plugin (`package:fvp`) wraps MDK SDK with Flutter texture rendering:

```
fvp_plugin.cpp (C++)
  ├── D3D11 render context creation
  ├── mdk::Player lifecycle
  ├── TextureRegistrar integration
  └── Property passthrough (setProperty/getProperty)
```

Dart side: `mdk.Player` is the primary API surface. All engine helpers operate on this single object.

**Critical constraint:** fvp creates its own D3D11 device. Do NOT share D3D11 devices with other Flutter plugins (e.g., video_overlay, custom renderers). Each fvp Player instance owns its own GPU context.

### EnginePrewarm

`EnginePrewarm` creates a temporary `mdk.Player` at app startup to trigger FFmpeg codec registration and D3D11 context initialization. This reduces first-open latency from ~800ms to ~200ms.

**Pattern:** Singleton with `@visibleForTesting static void reset()`. Safe to call multiple times (idempotent).

### Network Stream Configuration

`NetworkConfigurator` applies protocol-specific FFmpeg parameters:

| Protocol | Key Settings |
|----------|-------------|
| RTSP | Small probe (500KB), nobuffer, direct IO |
| RTMP | nobuffer, drop frames |
| SRT | nobuffer, drop frames |
| HTTP/HTTPS | Demux buffer ranges for seek acceleration |

This is MDK/FFmpeg-specific. media_kit (libmpv) has different network configuration APIs.

### Platform Abstraction Boundary

The engine layer has a clean platform boundary:

```
PlayerEngine (abstract, platform-agnostic)
  ├── FvpEngine (MDK/FFmpeg, Windows D3D11)
  ├── MockEngine (test, no platform dependency)
  └── [Future: MpvEngine (libmpv, cross-platform)]
```

The abstract interface exposes only Flutter-native types (ValueNotifier, enums, data classes). No `mdk.*` types leak to the UI layer. This is the correct boundary for cross-platform support.

## Recommendations

### Priority 1: Import Migration (Mechanical, Low Risk)

Replace 57 `package:player_engine` imports with `package:simple_player_flutter/kernel/engine/player_engine.dart`. Remove the external path dependency from pubspec.yaml. This eliminates the `../widget_tree_flutter/player_engine` path coupling.

**Effort:** 15 minutes (bulk sed + flutter analyze + flutter test)
**Risk:** Near zero — same symbols, same APIs, local barrel already exists

### Priority 2: Wire Remaining Helpers (Refactor, Low Risk)

Connect `D3D11Configurator`, `SubtitleConfigurator`, and `VolumeController` into FvpEngine. Each is already extracted and tested. The wiring is mechanical delegation.

**Effort:** 30 minutes per helper (wire + add unit tests)
**Risk:** Low — helpers already exist, just not called from FvpEngine

### Priority 3: Keep PlayerEngine Abstract Layer (Architecture Decision)

Do NOT remove the abstract `PlayerEngine` class. It provides:
- MockEngine for widget tests (no real media needed)
- Clean boundary for future engine swap (media_kit, custom libmpv)
- UI layer isolation (widgets never import fvp/mdk directly)

The "remove abstraction" impulse (IINA-style) applies to production architecture, not test architecture. MockEngine proves the abstraction has real test value.

### Priority 4: media_kit as Future Option (Not Now)

media_kit 1.2.6 lacks D3D11 sync control and fine-grained hardware decoder chains. The current fvp composition pattern makes a future swap feasible without touching UI code. Evaluate media_kit when:
- Linux/macOS support becomes primary (libmpv is more portable than MDK)
- D3D11-specific features are no longer needed
- A concrete feature gap in fvp blocks a user-facing requirement

### Anti-Patterns to Avoid

1. **Do NOT create a "BaseEngine" with shared implementation.** FvpEngine and MockEngine have fundamentally different implementations. Shared code would be leaky abstraction.

2. **Do NOT introduce Riverpod/Bloc/Provider for engine state.** ValueNotifier is the correct primitive for this use case (12 state streams, no derived state computation).

3. **Do NOT split PlayerEngine into sub-interfaces** (e.g., `AudioEngine`, `SubtitleEngine`, `VideoEngine`). The flat interface matches how media players actually work — you always need all capabilities together. Sub-interfaces create coordination overhead with no benefit.

4. **Do NOT move helpers out of `kernel/engine/`.** D3D11Configurator, VolumeController, etc. are engine-internal. They should not be visible to the UI layer or feature layer.
