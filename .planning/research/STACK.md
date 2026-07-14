# Technology Stack — 播放内核重构

**Project:** Simple Player Flutter — 播放内核重构强化
**Researched:** 2026-07-14
**Mode:** Ecosystem (stack evaluation for kernel refactor)

## Current Stack Assessment

### What's Working Well (Keep As-Is)

| Component | Version | Status | Rationale |
|-----------|---------|--------|-----------|
| Flutter SDK | ^3.11.5 | KEEP | Stable, Impeller support, desktop mature |
| fvp (MDK/FFmpeg) | 0.37.3 | KEEP | Stable API, hardware decode works, no reason to change |
| ValueNotifier/ValueListenableBuilder | Flutter built-in | KEEP | Project constraint + already well-established pattern |
| shared_preferences | ^2.5.5 | KEEP | Settings persistence works, no complexity needed |
| freezed + json_annotation | ^3.1.0 / ^4.12.0 | KEEP | Data class generation, already integrated |
| logger | ^2.5.0 | KEEP | Structured logging, already used throughout |
| ffi | ^2.1.0 | KEEP | Win32 FFI bridge, stable |

### What Needs Architectural Change (Not New Dependencies)

The kernel refactor is primarily an **architecture** change, not a **dependency** change. The problems identified in PROJECT.md are structural:

| Problem | Current State | Refactor Direction |
|---------|---------------|-------------------|
| EngineState mixin declares fields | `mixin EngineState` has `final ValueNotifier<X> field = ValueNotifier(...)` that FvpEngine `@override`s | Extract to abstract interface + concrete implementation |
| PlaybackController too large | Facade with 3 sub-modules but responsibilities still mixed | Split into focused service classes |
| Error recovery incomplete | Basic try-catch, no retry/backoff | Add error recovery state machine |
| State transition guards incomplete | `MediaStateTransition` extension exists but not all paths use it | Enforce through centralized state manager |
| Track management scattered | TrackManager + SubtitleConfigurator + VideoEffectController as separate helpers | Unify track lifecycle management |

## Recommended Stack Changes

### 1. EngineState Abstraction Refactor

**Current problem:** `EngineState` is a `mixin` that declares `final ValueNotifier<X>` fields. `FvpEngine` uses `with EngineState` then `@override`s every field. This is fragile — forgetting an override compiles but creates duplicate state.

**Recommended approach:** Convert to abstract interface pattern.

```dart
// Abstract contract — no field declarations, only getters + methods
abstract interface class EngineState {
  ValueNotifier<int?> get textureId;
  ValueNotifier<MediaState> get state;
  ValueNotifier<int> get position;
  // ... all other ValueNotifiers as getters

  Future<void> open(String path);
  void play();
  void pause();
  // ... all methods
}

// Concrete implementation — owns the ValueNotifier instances
class FvpEngineState implements EngineState {
  @override
  final ValueNotifier<int?> textureId = ValueNotifier(null);
  // ...
}
```

**Why not just keep the mixin?** Mixin field override is a code smell — it works but the compiler can't enforce completeness. Abstract interface + implements gives compile-time guarantees.

### 2. MediaState Model Enhancement

**Current state:** `MediaState` is a simple enum with 9 values. `MediaStateTransition` extension defines valid transitions. This is good foundation.

**Recommended additions (no new dependencies):**

```dart
// Richer error context — replace flat MediaErrorType
sealed class EngineError {
  const EngineError();
}
final class FileError extends EngineError { ... }
final class CodecError extends EngineError { ... }
final class NetworkError extends EngineError { ... }

// Buffered state with progress — replace simple isBuffering bool
class BufferState {
  final bool isBuffering;
  final double progress; // 0.0 - 1.0
  final Duration? estimatedRemaining;
}
```

**Why:** Current `MediaErrorType` enum + `errorMessage` string is too loose. Sealed class gives exhaustive pattern matching in switch statements.

### 3. PlaybackController Decomposition

**Current state:** `PlaybackController` is a facade with `PlaybackNavigator`, `FileOperations`, `StateMonitor` sub-modules. But the facade itself still handles playlist CRUD, play mode toggling, and lifecycle.

**Recommended decomposition:**

| New Class | Responsibility | Extracted From |
|-----------|---------------|----------------|
| `PlaylistService` | Playlist CRUD, reorder, clear, play mode | PlaybackController lines 119-160 |
| `PlaybackOrchestrator` | Coordinate open → seek → play flow, generation guard | PlaybackNavigator.playIndex |
| `StatePersistence` | Save/restore playlist, settings, breakpoints | StateMonitor |

**No new dependencies needed** — this is pure Dart reorganization.

### 4. PositionPoller Enhancement

**Current state:** Timer-based polling with adaptive intervals (100ms/250ms/500ms). Works well.

**Recommended improvement:** Add position stream for consumers that need continuous updates (progress bar) vs. discrete polling (OSD display).

```dart
// Current: ValueNotifier<int> position (discrete updates)
// Add: Stream<int> positionStream (continuous, for progress bar drag)
```

**No new dependency** — wrap existing ValueNotifier in a stream controller.

### 5. TrackManager Unification

**Current state:** Three separate helpers:
- `TrackManager` — audio/subtitle track selection
- `SubtitleConfigurator` — external subtitles, delay, equalizer
- `VideoEffectController` — video effects, rotation, aspect ratio, deinterlace

**Recommended:** Unify under a single `MediaControl` interface that groups related operations:

```dart
abstract interface class MediaControl {
  // Track selection
  List<AudioTrackInfo> getAudioTracks();
  void switchAudioTrack(int index);
  List<SubtitleTrackInfo> getSubtitleTracks();
  void switchSubtitleTrack(int index);
  void toggleSubtitle();

  // Subtitle config
  void setExternalSubtitle(String path);
  void setSubtitleDelay(int ms);
  void setEqualizer(String preset);

  // Video effects
  void setVideoEffect(VideoEffectType type, double value);
  void rotate(int degrees);
  void setAspectRatio(double ratio);
  void setDeinterlace(bool enable);
}
```

**Why:** UI layer currently needs to know which helper to call. Unified interface simplifies the contract.

## Dependencies NOT to Add

| Dependency | Why Not |
|------------|---------|
| riverpod / bloc / provider | Project constraint: keep ValueNotifier. Also, engine state is imperative (not declarative), state management frameworks add ceremony without benefit for this use case |
| rxdart | ValueNotifier + StreamController covers reactive needs. rxdart's operators (debounce, switchMap) can be implemented with 10-20 lines of Dart |
| get_it / injectable | DI is overkill for this project size. Constructor injection is sufficient |
| equatable | ValueNotifier handles equality internally. Data classes use freezed which has built-in == |
| audio_service / just_audio | fvp/MDK handles all playback. These would conflict |
| video_player | fvp replaces this entirely |

## Version Verification

| Package | Current | Latest Stable | Action |
|---------|---------|---------------|--------|
| fvp | 0.37.3 | 0.37.x (active) | Keep current — stable, no breaking changes expected |
| shared_preferences | 2.5.5 | 2.5.x | Keep current |
| window_manager | 0.5.2 | 0.5.x | Keep current |
| freezed | 3.2.5 | 3.x | Keep current |
| flutter SDK | ^3.11.5 | 3.11.x | Keep current |

**No version bumps needed** for this refactor. The changes are architectural, not dependency-driven.

## Integration Points

### FvpEngine ↔ New Architecture

```
EngineState (abstract interface)
    ↑ implements
FvpEngine (concrete, owns mdk.Player)
    ↑ delegates to
Helper classes (TrackManager, VolumeController, etc.)
    ↑ accessed via
MediaControl (unified interface)
```

### PlaybackController ↔ New Architecture

```
PlaybackOrchestrator (open/play/seek coordination)
    ↓ uses
EngineState (abstract interface)
    ↓ delegates to
PlaylistService (list CRUD)
StatePersistence (save/restore)
```

### Data Flow (Unchanged)

```
mdk.Player callbacks
    → FvpCallbackHandler (thread dispatch)
    → ValueNotifier updates
    → ValueListenableBuilder (UI rebuild)
```

This flow is correct and should NOT change. The refactor is about class boundaries, not data flow.

## Summary

**Stack verdict: NO NEW DEPENDENCIES NEEDED.**

The kernel refactor is purely architectural:
1. Convert `EngineState` from mixin-with-fields to abstract interface
2. Enhance `MediaState` with sealed error types
3. Decompose `PlaybackController` into focused services
4. Unify track/media control under single interface
5. Keep fvp, ValueNotifier, and all existing dependencies at current versions

The existing technology choices (fvp for playback, ValueNotifier for state, Flutter desktop for platform) are sound. The problems are in code organization, not technology selection.

## Sources

- Project source: `lib/kernel/engine/`, `lib/features/player/services/`
- fvp docs: Context7 `/wang-bin/fvp` (105 snippets, High reputation)
- Flutter ValueNotifier: built-in, no external source needed
- Architecture patterns: project CLAUDE.md conventions
