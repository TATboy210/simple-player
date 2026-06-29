# Architecture Research: PlayerEngine Refactoring

## Current Architecture Analysis

### What Exists

**Engine layer** (22 files, 2069 lines total in `lib/kernel/engine/`):

```
PlayerEngine (abstract, 178 lines)
  ├── 12 ValueNotifiers (state exposure)
  ├── 30+ methods (playback control, tracks, effects, D3D11)
  └── 3 plain getters (errorType, mediaInfo, subtitleDelay)

FvpEngine (concrete, 547 lines) extends PlayerEngine
  ├── FvpCallbackHandler (99 lines) — mdk callbacks → ValueNotifier mapping
  ├── PositionPoller (150 lines) — adaptive timer polling
  ├── TrackManager (70 lines) — audio/subtitle track switching
  ├── MediaOpener (184 lines) — open/prepare/metadata/texture
  ├── VideoEffectController (57 lines) — brightness/contrast/hue/saturation/rotate
  ├── VolumeController (35 lines) — volume/mute sync
  ├── SubtitleConfigurator (37 lines) — external subtitle/delay/equalizer
  ├── D3D11Configurator (37 lines) — hardware decode/sync toggle
  ├── NetworkConfigurator (84 lines) — protocol-specific FFmpeg params
  ├── EnginePrewarm (79 lines) — startup FFmpeg+D3D11 init
  └── MockEngine (432 lines) — test double with event recording

Models (6 files):
  ├── MediaInfo, AudioTrackInfo, SubtitleTrackInfo, VideoCodecInfo
  ├── MediaState enum, MediaErrorType enum, VideoEffectType enum
  └── OpenResult sealed class
```

**External dependency**: `player_engine` package at `../widget_tree_flutter/player_engine` — 1:1 copy of abstract interface + models. Path dependency in pubspec.yaml.

**Service layer** (5 files in `lib/features/player/services/`):
- PlaybackController — orchestrator, delegates to PlaybackNavigator + FileOperations + StateMonitor
- PlaybackNavigator — index/next/prev with openGeneration guard
- StateMonitor — auto-advance, breakpoint save, settings restore
- SubtitleService — external subtitle detection
- VideoProcessingService — color correction presets

**UI layer** (18 files access engine):
- All go through PlaybackController or direct `engine.xxx` ValueNotifier reads
- ValueListenableBuilder pattern throughout

### Strengths

1. **Clean abstraction**: PlayerEngine interface enables MockEngine for testing
2. **Composition helpers**: FvpEngine delegates to 9 focused helpers (not a god class)
3. **ValueNotifier pattern**: Flutter-native reactive state, no external state management
4. **Guard clauses**: `_disposed` check + try-catch in every method
5. **Timeline tracing**: `Timeline.startSync/finishSync` for performance profiling
6. **Adaptive polling**: PositionPoller uses 3-tier intervals (100ms/250ms/500ms) to save CPU

### Weaknesses

1. **External path dependency**: `player_engine` package is a 1:1 copy, adds complexity without benefit
2. **Flat interface bloat**: PlayerEngine has 30+ methods mixing playback, tracks, effects, D3D11 config — violates ISP
3. **Helper duplication**: VolumeController/SubtitleConfigurator/D3D11Configurator exist but FvpEngine duplicates their logic inline
4. **Inconsistent delegation**: FvpEngine uses VideoEffectController and TrackManager but NOT VolumeController/SubtitleConfigurator/D3D11Configurator
5. **Mixed import paths**: Some files import `package:player_engine/player_engine.dart` (external), others import `package:simple_player_flutter/kernel/engine/...` (local)
6. **No barrel export**: `player_engine.dart` exports models but not all engine files
7. **MockEngine bloat**: 432 lines, duplicates all 30+ method stubs

## Target Architecture

### Design Principles

1. **Single responsibility per interface**: Split PlayerEngine into focused capability interfaces
2. **Composition over inheritance**: FvpEngine composes helpers, each helper implements one interface
3. **Local-only dependency**: Remove external path dependency, use local barrel export
4. **Minimal UI surface**: UI layer only sees what it needs

### Target Structure

```
lib/kernel/engine/
  ├── player_engine.dart          # Barrel export (all public types)
  ├── player_engine_base.dart     # Core interface: state + playback control only
  │
  ├── fvp_engine.dart             # Concrete implementation (thin coordinator)
  │   ├── fvp_callback_handler.dart   # mdk callbacks → ValueNotifier
  │   ├── position_poller.dart        # Adaptive timer polling
  │   └── media_opener.dart           # Open/prepare/metadata/texture
  │
  ├── capabilities/               # Optional capability interfaces
  │   ├── track_control.dart      # Audio/subtitle track switching
  │   ├── video_effects.dart      # Brightness/contrast/hue/saturation/rotate
  │   ├── subtitle_config.dart    # External subtitle/delay
  │   ├── equalizer_config.dart   # Audio equalizer
  │   └── renderer_config.dart    # D3D11/hardware decode config
  │
  ├── helpers/                    # FvpEngine internal helpers
  │   ├── track_manager.dart
  │   ├── video_effect_controller.dart
  │   ├── subtitle_configurator.dart
  │   ├── volume_controller.dart
  │   ├── d3d11_configurator.dart
  │   └── network_configurator.dart
  │
  ├── models/                     # Data classes (unchanged)
  │   ├── media_info.dart
  │   ├── audio_track_info.dart
  │   ├── subtitle_track_info.dart
  │   ├── video_codec_info.dart
  │   ├── media_state.dart
  │   ├── media_error_type.dart
  │   ├── video_effect_type.dart
  │   └── open_result.dart
  │
  ├── mock_engine.dart            # Test double
  └── engine_prewarm.dart         # Startup optimization
```

### Interface Hierarchy

```dart
/// Core interface — playback state + transport controls
/// 90% of UI code only needs this.
abstract class PlayerEngine {
  // 12 ValueNotifiers (state exposure)
  // 8 core methods: open, play, pause, stop, seekTo, setVolume, setMute, togglePlayPause
  // 3 getters: errorType, mediaInfo, subtitleDelay
  // 1 lifecycle: dispose
}

/// Optional capabilities — UI/settings panels use these via cast
mixin TrackControl on PlayerEngine {
  List<AudioTrackInfo> getAudioTracks();
  void switchAudioTrack(int index);
  List<int> get activeAudioTracks;
  List<SubtitleTrackInfo> getSubtitleTracks();
  void switchSubtitleTrack(int index);
  void toggleSubtitle();
  void setExternalSubtitle(String path);
}

mixin VideoEffects on PlayerEngine {
  void setVideoEffect(VideoEffectType effect, double value);
  void rotate(int degree);
  void setAspectRatio(double ratio);
  void setDeinterlace(bool enable);
  void setPlaybackRate(double rate);
}

mixin RendererConfig on PlayerEngine {
  void setD3d11SyncEnabled(bool enabled);
  void setHardwareDecoding(bool enabled);
}
```

### Why Mixins Over Separate Interfaces

- **Backward compatible**: Existing code casting to PlayerEngine still works
- **Progressive adoption**: UI can check `if (engine is TrackControl)` without breaking
- **Single implementation**: FvpEngine implements all mixins, MockEngine implements only core
- **No wrapper boilerplate**: Unlike separate interfaces, no delegation classes needed

## Component Boundaries

### Layer Dependency Graph

```
UI Layer (18 files)
  ↓ depends on
PlaybackController (orchestrator)
  ↓ depends on
PlayerEngine (abstract interface)
  ↑ implemented by
FvpEngine (concrete)
  ↓ delegates to
  ├── FvpCallbackHandler (mdk → Flutter state)
  ├── PositionPoller (timer → position updates)
  ├── MediaOpener (open/prepare/metadata)
  ├── TrackManager (audio/subtitle tracks)
  ├── VideoEffectController (color/rotation)
  ├── VolumeController (volume/mute)
  ├── SubtitleConfigurator (external subtitle)
  ├── D3D11Configurator (hardware config)
  └── NetworkConfigurator (protocol params)
```

### Who Talks to Whom

| Caller | Calls | Purpose |
|--------|-------|---------|
| UI widgets | `engine.state`, `engine.position`, etc. (ValueListenableBuilder) | Read state |
| UI widgets | `controller.playNext()`, `controller.openAndPlay()` | User actions |
| PlaybackController | `engine.open()`, `engine.play()`, `engine.seekTo()` | Orchestrate playback |
| StateMonitor | `engine.state.addListener()` | Auto-advance, breakpoint save |
| FvpEngine | `_callbackHandler.init()` | Register mdk callbacks |
| FvpEngine | `_positionPoller.start/stop()` | Position tracking |
| FvpEngine | `_trackManager.switchAudioTrack()` | Track switching |
| FvpEngine | `_mediaOpener.open()` | File open flow |
| FvpCallbackHandler | `state.value = mapped` | Push state changes |
| PositionPoller | `position.value = newPos` | Push position updates |
| MediaOpener | `_player.prepare()`, `_player.updateTexture()` | MDK operations |
| TrackManager | `_player.activeAudioTracks = [...]` | MDK track control |

### Boundary Rules

1. **UI → Engine**: Read-only via ValueNotifier. Commands via PlaybackController.
2. **PlaybackController → Engine**: All playback commands. Never touches helpers directly.
3. **FvpEngine → Helpers**: Each helper owns one concern. FvpEngine coordinates.
4. **Helpers → mdk.Player**: Direct FFI calls. No cross-helper dependencies.
5. **Callbacks → ValueNotifier**: FvpCallbackHandler and PositionPoller write to ValueNotifiers. Nobody else writes.

## Data Flow

### Playback State Flow

```
mdk.Player state change
  → FvpCallbackHandler.onStateChanged stream
  → mapMdkState() (pure function)
  → SchedulerBinding.addPostFrameCallback (main thread)
  → state.value = MediaState.xxx
  → ValueListenableBuilder in UI rebuilds
```

### Position Update Flow

```
Timer.periodic (250ms/100ms/500ms adaptive)
  → PositionPoller._poll()
  → _player.position (FFI call)
  → position.value = newPos (only if changed)
  → ValueListenableBuilder in ProgressBar rebuilds
```

### Open File Flow

```
UI: onOpenFile callback
  → PlaybackController.openAndPlay(path)
  → FileOperations.openAndPlay(path)
    → PathValidator.validate(path)
    → engine.open(path)
      → FvpEngine.open(path)
        → MediaOpener.open(path)
          → path validation
          → _player.media = path
          → NetworkConfigurator.configure() or _configureLocalBuffer()
          → _player.prepare() (async, 10s timeout)
          → metadata parsing → MediaInfo
          → _player.updateTexture() (async, 5s timeout)
          → return OpenSuccess/OpenError
        → update ValueNotifiers (duration, aspectRatio, state)
    → engine.play()
    → StateMonitor saves breakpoint
```

### Seek Flow

```
UI: ProgressBar drag end
  → engine.seekTo(ms)
  → FvpEngine.seekTo(ms)
    → _positionPoller.seeking = true (pause polling)
    → state.value = MediaState.seeking
    → _player.seek(position: clamped) (async)
    → position.value = clamped
    → _positionPoller.seeking = false (resume with fast polling)
    → state.value = playing/paused (restore)
```

## Build Order

### Phase 1: Remove External Dependency (Low Risk)

**Goal**: Eliminate `player_engine` path dependency.

**Steps**:
1. Copy all types from `../widget_tree_flutter/player_engine/lib/src/` into `lib/kernel/engine/models/`
2. Create `lib/kernel/engine/player_engine.dart` barrel export
3. Update all `import 'package:player_engine/player_engine.dart'` → `import 'package:simple_player_flutter/kernel/engine/player_engine.dart'`
4. Remove `player_engine` from pubspec.yaml
5. Verify: `flutter analyze` clean

**Risk**: Low. Pure import path change, no logic changes.

**Files affected**: ~37 files (all files importing player_engine).

### Phase 2: Split PlayerEngine Interface (Medium Risk)

**Goal**: Extract capability mixins from flat interface.

**Steps**:
1. Create `lib/kernel/engine/capabilities/track_control.dart` — mixin with track methods
2. Create `lib/kernel/engine/capabilities/video_effects.dart` — mixin with effect methods
3. Create `lib/kernel/engine/capabilities/renderer_config.dart` — mixin with D3D11 methods
4. Move methods from PlayerEngine to appropriate mixins
5. FvpEngine: `class FvpEngine extends PlayerEngine with TrackControl, VideoEffects, RendererConfig`
6. MockEngine: only implement core PlayerEngine (stubs for mixins)
7. Verify: `flutter analyze` clean, all tests pass

**Risk**: Medium. Interface change affects all consumers, but mixins are additive.

**Migration strategy**: Add mixins alongside existing interface first, then remove methods from base.

### Phase 3: Consolidate Helpers (Low Risk)

**Goal**: Use all extracted helpers consistently.

**Steps**:
1. Move VolumeController/SubtitleConfigurator/D3D11Configurator to `helpers/` directory
2. FvpEngine: delegate to these helpers instead of inline logic
3. Move NetworkConfigurator to `helpers/` directory
4. Verify: behavior unchanged, `flutter analyze` clean

**Risk**: Low. Internal refactoring, no API change.

### Phase 4: Slim FvpEngine (Low Risk)

**Goal**: FvpEngine becomes thin coordinator (~200 lines).

**Steps**:
1. Move D3D11 defaults to D3D11Configurator
2. Move open() flow entirely to MediaOpener
3. Move play/pause/stop state management to a PlaybackStateMachine helper
4. FvpEngine retains: constructor, helper wiring, method delegation, dispose

**Risk**: Low. Internal only.

### Phase 5: Clean Up MockEngine (Low Risk)

**Goal**: MockEngine only implements core PlayerEngine.

**Steps**:
1. Remove mixin stubs from MockEngine (track, effects, renderer)
2. Add `configureMedia()` for test setup (already exists)
3. Verify: all widget tests still pass

**Risk**: Low. Test-only change.

## Migration Strategy

### Principle: Zero Downtime

Each phase is independently shippable. No phase depends on a later phase.

### Import Migration (Phase 1)

**Strategy**: Big-bang import replacement.

```bash
# Find all files
grep -r "import.*player_engine" lib/ --include="*.dart" -l

# Replace each
sed -i "s|import 'package:player_engine/player_engine.dart'|import 'package:simple_player_flutter/kernel/engine/player_engine.dart'|g" <file>
```

**Verification**: `flutter analyze` + `flutter test` after each file batch.

### Interface Migration (Phase 2)

**Strategy**: Additive-first, then remove.

1. Add mixins alongside existing methods (duplicate temporarily)
2. Update FvpEngine to use mixins
3. Update MockEngine to use mixins
4. Remove duplicate methods from base PlayerEngine
5. Verify no UI code breaks (UI only uses ValueNotifiers, rarely calls methods directly)

**Fallback**: If mixin approach causes issues, keep flat interface but move methods to extension methods on PlayerEngine.

### Helper Consolidation (Phase 3)

**Strategy**: Move files, update imports within engine directory.

No external API changes. Pure internal reorganization.

### Testing Strategy

- **Phase 1**: Run full test suite after import migration
- **Phase 2**: Add mixin-specific tests, verify MockEngine still works
- **Phase 3**: Behavior tests (no API change)
- **Phase 4**: Behavior tests (no API change)
- **Phase 5**: Widget tests verify UI still works with slimmer MockEngine

## Reference Architectures

### IINA (macOS, Swift)

**Pattern**: `MPVController` wraps mpv, exposes `MPVOption` property bag.

```
MPVController (God class, ~2000 lines)
  → mpv_handle* (C API)
  → property observation via mpv_observe_property
  → DispatchQueue for thread safety
```

**Relevance to our project**:
- IINA uses property observation (like our ValueNotifier pattern)
- IINA's MPVController is too large — we should NOT follow this pattern
- IINA separates `PlayerCore` (orchestration) from `MPVController` (mpv wrapper) — good pattern
- Lesson: Keep FvpEngine as coordinator, not as god class

### VLC (Cross-platform, C)

**Pattern**: `libvlc` API with event callbacks.

```
libvlc_instance_t (global config)
  → libvlc_media_player_t (per-player)
    → event callbacks (vlc events → UI)
    → media options (key-value property bag)
```

**Relevance**:
- VLC separates instance (global) from player (per-media) — we have EnginePrewarm (global) + FvpEngine (per-player)
- VLC uses event-based state propagation — we use ValueNotifier (Flutter equivalent)
- VLC's media options pattern is similar to our `setProperty()` calls
- Lesson: Keep global prewarm separate from per-player engine

### media_kit (Flutter, Dart)

**Pattern**: `Player` class with `Stream`-based state.

```dart
class Player {
  Stream<Duration> get positionStream;
  Stream<PlayerState> get stateStream;
  Stream<Tracks> get tracks;
  // ... 15+ streams
}
```

**Relevance**:
- media_kit uses Streams, we use ValueNotifiers — both are valid for Flutter
- media_kit has a single Player class with all capabilities — similar to our current flat design
- media_kit's `Media` class is similar to our `PlaylistItem`
- Lesson: Our ValueNotifier approach is simpler than Streams for single-subscriber UI binding

### mpv (C library)

**Pattern**: Property-based API with observe/set/get.

```c
mpv_observe_property(ctx, 0, "pause", MPV_FORMAT_FLAG);
mpv_set_property_string(ctx, "pause", "yes");
```

**Relevance**:
- mpv's property observation is the gold standard for media player state
- Our ValueNotifiers are the Flutter equivalent
- mpv separates rendering (VO) from playback (AO) — we separate via helpers
- Lesson: Property-based state (ValueNotifier) is the right pattern for Flutter

### Common Patterns Across All References

| Pattern | IINA | VLC | media_kit | mpv | Ours |
|---------|------|-----|-----------|-----|------|
| State propagation | Property observe | Events | Streams | Property observe | ValueNotifier |
| Thread safety | DispatchQueue | vlc_mutex | Dart isolate | mpv_lock | main thread only |
| Capability split | PlayerCore/MPVController | instance/player | single Player | property namespace | interface mixins |
| Config model | MPVOption dict | media options | constructor params | set_property | method params |

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Interface split strategy | Mixins | Backward compatible, progressive adoption, no wrapper boilerplate |
| Helper location | `helpers/` subdirectory | Clear separation from public API files |
| External dependency | Remove entirely | 1:1 copy adds no value, import path confusion |
| State management | Keep ValueNotifier | Flutter-native, simpler than Streams for UI binding |
| MockEngine scope | Core PlayerEngine only | Don't mock what UI doesn't use |
| Build order | External dep first | Lowest risk, biggest win (eliminates confusion) |
