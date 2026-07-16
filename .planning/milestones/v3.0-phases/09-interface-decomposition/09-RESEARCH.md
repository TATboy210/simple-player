# Phase 9: 接口分解 + 状态模型统一 - Research

**Researched:** 2026-07-14
**Domain:** Dart sealed class / ISP interface decomposition / service migration
**Confidence:** HIGH

## Summary

Phase 9 is a pure refactoring phase with zero new dependencies and zero UI changes. It addresses three architectural problems in the playback kernel:

1. **EngineState "god mixin"** — 12 ValueNotifiers + ~35 methods forced into a single mixin. All 3 capability mixins (TrackControl/VideoEffects/RendererConfig) are empty marker mixins that `on EngineState`, creating circular coupling. FvpEngine (641 lines) uses `with EngineState, TrackControl, VideoEffects, RendererConfig` — 4 mixins for what should be 6 independent interfaces.

2. **Dual error model** — MediaErrorType (5 values) and PlayerErrorCode (11 values) + PlayerError class coexist. PlayerError is dead code (never referenced from production paths). OpenResult uses MediaErrorType. ErrorBanner UI switches on MediaErrorType. This needs unification into a single sealed class hierarchy.

3. **Service layer misplacement** — PlaybackController + 4 sub-modules live in `features/player/services/` but are kernel-level orchestrators with no UI dependency. 14 files import from this path. PlaybackContract interface adds indirection that no longer serves its purpose (sub-modules already receive `this` from PlaybackController).

The refactoring is mechanical but high-surface-area: ~34 files import EngineState, ~14 files import from the services path, and the FakeEngine test double (378 lines) must be rewritten to implement the new interfaces.

**Primary recommendation:** Execute in 2 plans — Plan 01 for interface decomposition + error model + MediaState split (kernel-internal), Plan 02 for service migration + import rewrite + test updates (cross-cutting).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** EngineStateView = abstract class with 12 read-only getters (textureId/state/position/duration/volume/isMuted/isBuffering/subtitleText/buffered/aspectRatio/errorMessage/playbackSpeed). UI layer references engine via EngineStateView only.
- **D-02:** PlaybackControl = abstract class with core operations (open/play/pause/stop/togglePlayPause/seekTo/setVolume/setMute/setPlaybackRate/setRange/skipForward/skipBack).
- **D-03:** 4 capability interfaces as abstract classes: TrackControl (getAudioTracks/switchAudioTrack/activeAudioTracks), SubtitleConfig (getSubtitleTracks/switchSubtitleTrack/toggleSubtitle/setExternalSubtitle/setSubtitleDelay/setEqualizer + subtitleText/subtitleDelay getters), VideoEffectControl (setVideoEffect/rotate/setAspectRatio/setDeinterlace + aspectRatio getter), RendererControl (setD3d11SyncEnabled/setHardwareDecoding).
- **D-04:** Delete EngineState mixin entirely. No @Deprecated transition. FvpEngine uses `implements` instead of `with`.
- **D-05:** All 12 ValueNotifier getters concentrated in EngineStateView. Capability interfaces define only methods (plus necessary state getters like subtitleText/aspectRatio).
- **D-06:** Delete existing 3 empty marker mixins (TrackControl/VideoEffects/RendererConfig), replace with new abstract classes.
- **D-07:** PlayerError = nested-level sealed class. First layer: FileError/CodecError/PlaybackError/NetworkError/UnknownError. Each can contain sub-codes. Supports exhaustive pattern matching.
- **D-08:** OpenResult adapts PlayerError. OpenError(PlayerError error) replaces OpenError(MediaErrorType type, String message).
- **D-09:** EngineStateView exposes `ValueNotifier<PlayerError?> lastError` replacing errorMessage (ValueNotifier<String?>) and errorType getter. Delete old fields.
- **D-10:** Delete MediaErrorType enum and PlayerErrorCode enum, unified into PlayerError sealed class.
- **D-11:** All 5 modules migrate to `kernel/services/`: PlaybackController + PlaybackNavigator + FileOperations + StateMonitor + SubtitleService.
- **D-12:** PlayerServices DI container also migrates to `kernel/`.
- **D-13:** Delete PlaybackContract interface. Sub-modules depend directly on PlaybackController.
- **D-14:** Global import path replacement (features/player/services/ -> kernel/services/). No re-export shims.
- **D-15:** features/player/ retains only UI files (player_feature.dart, deferred_player_feature.dart).
- **D-16:** MediaState splits into orthogonal state: main enum (idle/opening/playing/paused/completed/error, 6 values) + two transient flags ValueNotifier<bool> (isSeeking/isBuffering).
- **D-17:** EngineStateView exposes 3 independent getters: `ValueNotifier<MediaState> state`, `ValueNotifier<bool> isSeeking`, `ValueNotifier<bool> isBuffering`.
- **D-18:** State transition guards (switch expression exhaustive) deferred to Phase 10.
- **D-19:** Delete existing MediaState transition guard extension. Phase 10 replaces with new state machine.

### Claude's Discretion
None — all decisions explicitly user-chosen.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENG-01 | EngineState mixin refactored into ISP interfaces: EngineStateView + PlaybackControl + 4 capability interfaces | Current mixin has 12 ValueNotifiers + 35 methods in one blob. 3 empty marker mixins create false polymorphism. ISP split is mechanical: extract getters to EngineStateView, extract methods to PlaybackControl, promote markers to real abstract classes. |
| ENG-03 | Unified error model: sealed class PlayerError replaces MediaErrorType + PlayerErrorCode | MediaErrorType (5 values) used in OpenResult + ErrorBanner UI. PlayerErrorCode (11 values) + PlayerError class exist but are dead code. Merge into nested sealed class. OpenResult + ErrorBanner + FvpEngine all need updating. |
| SVC-01 | PlaybackController migrated from features/player/services/ to kernel/services/ | 5 service files + PlayerServices DI container move. 14 files import from old path. PlaybackContract deleted. Mechanical import rewrite. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Engine state abstraction (EngineStateView) | Kernel/Engine | — | Defines the read-only contract for all engine consumers |
| Playback commands (PlaybackControl) | Kernel/Engine | — | Defines the control contract; only PlaybackController + UI call these |
| Capability interfaces (TrackControl etc.) | Kernel/Engine | — | Optional engine features; UI uses pattern matching to detect support |
| Error model (PlayerError) | Kernel/Models | Kernel/Engine | Data model lives in models/, engine produces errors |
| MediaState (orthogonal) | Kernel/Models | Kernel/Engine | State enum + transient flags; engine sets, UI reads |
| Service orchestration (PlaybackController) | Kernel/Services | — | Moved from features/ to kernel/ — no UI dependency |
| DI container (PlayerServices) | Kernel/ | Features/Player | Container moves to kernel/, but PlayerFeature still creates it |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Dart 3 sealed class | SDK 3.x | Exhaustive pattern matching for error types | Compiler-enforced completeness, no default branch needed |
| Dart abstract class | SDK 3.x | Interface contracts (ISP) | Supports `implements` without field inheritance |
| ValueNotifier | Flutter SDK | Reactive state exposure | Project standard — no Provider/Riverpod/Bloc |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter analyze | SDK | Static analysis for interface compliance | Verify no missing method implementations |
| flutter test | SDK | Test suite for interface conformance | Verify FakeEngine implements all new interfaces |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| abstract class interfaces | mixin interfaces | mixin allows default implementations; abstract class forces explicit implementation — cleaner ISP |
| nested sealed class PlayerError | flat sealed class with 11 subtypes | Nested allows grouping (all file errors under FileError) — better for UI error categorization |
| ValueNotifier<PlayerError?> | Stream<PlayerError> | Stream is overkill for single-error-at-a-time; ValueNotifier matches project pattern |

**Installation:**
```bash
# No new dependencies — pure Dart refactoring
flutter pub get  # existing deps only
```

## Package Legitimacy Audit

> No external packages installed in this phase. All changes are internal Dart refactoring.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | — | — | — | — | — | No packages to audit |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                    ┌─────────────────────────────────────────────┐
                    │              UI Layer (unchanged)            │
                    │  PlayerScreen / ErrorBanner / SettingsPanel  │
                    │  references: EngineStateView (read-only)     │
                    │             + PlaybackControl (commands)     │
                    │             + capability interfaces (pattern │
                    │               matching for optional features)│
                    └──────────────┬──────────────────────────────┘
                                   │ reads state / calls commands
                    ┌──────────────▼──────────────────────────────┐
                    │          Kernel/Services (migrated)          │
                    │  PlaybackController (facade orchestrator)    │
                    │  ├── PlaybackNavigator (track navigation)    │
                    │  ├── FileOperations (file open/drop)         │
                    │  ├── StateMonitor (settings restore + auto)  │
                    │  └── SubtitleService (subtitle detection)    │
                    │  PlayerServices (DI container)               │
                    └──────────────┬──────────────────────────────┘
                                   │ depends on
                    ┌──────────────▼──────────────────────────────┐
                    │          Kernel/Engine (decomposed)          │
                    │                                             │
                    │  EngineStateView ◄── UI reads (12 getters)  │
                    │  PlaybackControl ◄── commands (12 methods)  │
                    │  TrackControl    ◄── optional: audio tracks  │
                    │  SubtitleConfig  ◄── optional: subtitles     │
                    │  VideoEffectCtrl ◄── optional: effects       │
                    │  RendererControl ◄── optional: D3D11 config  │
                    │                                             │
                    │  FvpEngine implements all 6 interfaces      │
                    └──────────────┬──────────────────────────────┘
                                   │ produces
                    ┌──────────────▼──────────────────────────────┐
                    │          Kernel/Models (unified)             │
                    │  PlayerError (sealed: File/Codec/Playback/   │
                    │               Network/Unknown)               │
                    │  MediaState (enum: 6 values)                 │
                    │  + isSeeking / isBuffering (bool flags)      │
                    │  OpenResult (sealed: Success/Error)          │
                    └─────────────────────────────────────────────┘
```

### Recommended Project Structure

```
lib/kernel/
├── engine/
│   ├── engine_state_view.dart      # NEW: abstract class, 12 read-only getters
│   ├── playback_control.dart       # NEW: abstract class, 12 control methods
│   ├── track_control.dart          # REWRITE: empty mixin → abstract class
│   ├── subtitle_config.dart        # NEW: abstract class (replaces part of EngineState)
│   ├── video_effect_control.dart   # REWRITE: empty mixin → abstract class
│   ├── renderer_control.dart       # REWRITE: empty mixin → abstract class
│   ├── media_state.dart            # REWRITE: 9 values → 6 values (remove seeking/buffering)
│   ├── fvp_engine.dart             # REWRITE: implements 6 interfaces
│   ├── media_error_type.dart       # DELETE
│   ├── media_opener.dart           # UPDATE: OpenResult uses PlayerError
│   └── open_result.dart            # UPDATE: OpenError carries PlayerError
├── models/
│   ├── player_error.dart           # REWRITE: nested sealed class hierarchy
│   └── media_state.dart            # DELETE (duplicate, real one in engine/)
├── services/                       # NEW: migrated from features/player/services/
│   ├── playback_controller.dart    # MOVE from features/
│   ├── playback_navigator.dart     # MOVE from features/
│   ├── file_operations.dart        # MOVE from features/
│   ├── state_monitor.dart          # MOVE from features/
│   ├── subtitle_service.dart       # MOVE from features/
│   ├── video_processing_service.dart # MOVE from features/
│   └── breakpoint_saver.dart       # MOVE from features/
├── player_services.dart            # NEW: moved from features/player/
└── ...existing files...

lib/features/player/
├── player_feature.dart             # STAYS: UI only
├── deferred_player_feature.dart    # STAYS: UI only
└── (all services/ removed)
```

### Pattern 1: ISP Interface Decomposition

**What:** Split a single god mixin into focused abstract classes, each representing one responsibility.

**When to use:** When a mixin has 3+ unrelated groups of methods (state getters, playback commands, track control, video effects, renderer config).

**Example:**
```dart
// Source: D-01/D-02/D-03 from CONTEXT.md

/// Read-only state view — UI layer binds to these ValueNotifiers
abstract class EngineStateView {
  ValueNotifier<int?> get textureId;
  ValueNotifier<MediaState> get state;
  ValueNotifier<int> get position;
  ValueNotifier<int> get duration;
  ValueNotifier<double> get volume;
  ValueNotifier<bool> get isMuted;
  ValueNotifier<bool> get isBuffering;
  ValueNotifier<String> get subtitleText;
  ValueNotifier<int> get buffered;
  ValueNotifier<double> get aspectRatio;
  ValueNotifier<PlayerError?> get lastError;
  ValueNotifier<double> get playbackSpeed;
  MediaInfo get mediaInfo;
  void dispose();
}

/// Playback commands — PlaybackController calls these
abstract class PlaybackControl {
  Future<void> open(String path);
  void play();
  void pause();
  void stop();
  void togglePlayPause();
  Future<void> seekTo(int ms);
  void setVolume(double volume);
  void setMute(bool mute);
  void setPlaybackRate(double rate);
  void setRange({required int from, int to = -1});
  void skipForward([int ms = 10000]);
  void skipBack([int ms = 10000]);
}

/// Optional: audio track switching
abstract class TrackControl {
  List<AudioTrackInfo> getAudioTracks();
  void switchAudioTrack(int trackId);
  List<int> get activeAudioTracks;
}

/// Optional: subtitle configuration
abstract class SubtitleConfig {
  List<SubtitleTrackInfo> getSubtitleTracks();
  void switchSubtitleTrack(int trackId);
  void toggleSubtitle();
  void setExternalSubtitle(String path);
  void setSubtitleDelay(int delay);
  void setEqualizer(String preset);
  ValueNotifier<String> get subtitleText;
  int get subtitleDelay;
}

/// Optional: video effects
abstract class VideoEffectControl {
  void setVideoEffect(VideoEffectType effectType, double value);
  void rotate(int degrees);
  void setAspectRatio(double ratio);
  void setDeinterlace(bool enable);
  ValueNotifier<double> get aspectRatio;
}

/// Optional: renderer configuration
abstract class RendererControl {
  void setD3d11SyncEnabled(bool enabled);
  void setHardwareDecoding(bool enabled);
}

/// FvpEngine implements all — concrete engine provides all capabilities
class FvpEngine implements
    EngineStateView, PlaybackControl, TrackControl,
    SubtitleConfig, VideoEffectControl, RendererControl {
  // ... all @override implementations
}
```

### Pattern 2: Nested Sealed Class Error Hierarchy

**What:** Replace flat enum + separate class with a single nested sealed class that carries both category and sub-code.

**When to use:** When you have two parallel error classification systems (MediaErrorType + PlayerErrorCode) that need merging.

**Example:**
```dart
// Source: D-07 from CONTEXT.md

/// Unified player error — nested sealed class for exhaustive matching
sealed class PlayerError {
  const PlayerError();
  String get message;
  Object? get cause;
}

/// File-related errors (path empty, not found, traversal)
final class FileError extends PlayerError {
  final FileErrorCode code;
  @override final String message;
  @override final Object? cause;
  const FileError(this.code, this.message, [this.cause]);
}

enum FileErrorCode { pathEmpty, fileNotFound, pathTraversal }

/// Codec/format errors (unsupported, decode failed)
final class CodecError extends PlayerError {
  final CodecErrorCode code;
  @override final String message;
  @override final Object? cause;
  const CodecError(this.code, this.message, [this.cause]);
}

enum CodecErrorCode { unsupportedFormat, decodeFailed, codecUnsupported }

/// Playback errors (play failed, seek failed, texture failed)
final class PlaybackError extends PlayerError {
  final PlaybackErrorCode code;
  @override final String message;
  @override final Object? cause;
  const PlaybackError(this.code, this.message, [this.cause]);
}

enum PlaybackErrorCode { playFailed, seekFailed, textureFailed, openTimeout }

/// Network errors (timeout, connection lost)
final class NetworkError extends PlayerError {
  final NetworkErrorCode code;
  @override final String message;
  @override final Object? cause;
  const NetworkError(this.code, this.message, [this.cause]);
}

enum NetworkErrorCode { timeout, connectionLost }

/// Unknown/other errors
final class UnknownError extends PlayerError {
  @override final String message;
  @override final Object? cause;
  const UnknownError(this.message, [this.cause]);
}
```

### Pattern 3: Orthogonal State Model

**What:** Split a combined enum (that conflates primary state with transient flags) into a primary enum + independent boolean notifiers.

**When to use:** When an enum has values that are "orthogonal" to the main state (seeking can happen during playing OR paused; buffering can happen during playing OR loading).

**Example:**
```dart
// Source: D-16/D-17 from CONTEXT.md

/// Primary playback state — mutually exclusive
enum MediaState {
  idle,       // initial, no media loaded
  opening,    // loading/preparing media (renamed from 'loading')
  playing,    // actively playing
  paused,     // user paused
  completed,  // reached end of media
  error,      // unrecoverable error
}

/// Transient flags — orthogonal to primary state
/// Exposed as independent ValueNotifiers on EngineStateView:
///   state: ValueNotifier<MediaState>
///   isSeeking: ValueNotifier<bool>
///   isBuffering: ValueNotifier<bool>
```

### Anti-Patterns to Avoid

- **Keeping deprecated shims:** User explicitly said "一步到位" — delete old code, no @Deprecated transition period. This means all 34+ files importing EngineState must be updated in the same phase.
- **Splitting ValueNotifiers across capability interfaces:** D-05 says all 12 getters stay in EngineStateView. Capability interfaces only define methods + necessary state getters (subtitleText, aspectRatio). Don't scatter notifiers.
- **Flat 11-subtype sealed class:** User chose nested (FileError/CodecError/PlaybackError/NetworkError/UnknownError) with sub-enum codes inside each. Not 11 direct subtypes.
- **Re-export shims for old import paths:** D-14 says global replace, no re-exports. Old paths break at compile time — that's the point.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Interface compliance checking | Manual review of all methods | `flutter analyze` — compiler enforces abstract class contracts | Missing method = compile error, not runtime bug |
| Exhaustive error matching | default branch in switch | Dart 3 sealed class — compiler enforces all cases | New error subtype = compile error everywhere it's switched |
| Import path migration | Manual find-replace | IDE refactor or `dart fix` + manual grep verification | Missed imports = compile errors, but grep catches edge cases |

## Common Pitfalls

### Pitfall 1: Circular Import After Interface Extraction

**What goes wrong:** EngineStateView is defined in `engine_state_view.dart` but needs types like MediaState, PlayerError, MediaInfo from other files. Those files might import back from engine_state_view.dart.

**Why it happens:** Dart doesn't allow circular imports. When splitting a monolithic file, the dependency direction must be strictly one-way.

**How to avoid:** MediaState and PlayerError live in `kernel/models/` or `kernel/engine/` as standalone files. EngineStateView imports them. Nothing imports EngineStateView except consumers (UI, services). FvpEngine implements EngineStateView but lives in the same `engine/` directory — no circular dependency.

**Warning signs:** `flutter analyze` shows "cycle in imports" or "undefined name" errors.

### Pitfall 2: FakeEngine Breaking All Tests

**What goes wrong:** FakeEngine currently uses `with EngineState, TrackControl, VideoEffects, RendererConfig` (mixin composition). After refactoring, it must `implements` 6 abstract classes. All 378 lines need updating.

**Why it happens:** The mixin provided default field implementations. With `implements`, FakeEngine must explicitly declare and implement every field and method.

**How to avoid:** Update FakeEngine in the same plan as the interface changes. Since FakeEngine already has explicit @override for all fields (lines 15-54), the change is: remove `with` keywords, add `implements EngineStateView, PlaybackControl, TrackControl, SubtitleConfig, VideoEffectControl, RendererControl`, add `lastError` ValueNotifier, change `errorMessage` references to `lastError`.

**Warning signs:** `flutter test` fails with "class does not implement abstract member" errors.

### Pitfall 3: MediaState.value Transition Guard Deletion

**What goes wrong:** `_safeSetState()` in FvpEngine calls `current.canTransitionTo(next)` from the extension. Deleting the extension (D-19) breaks FvpEngine.compile.

**Why it happens:** Phase 9 deletes the guard extension, but Phase 10 adds the new state machine. There's a gap.

**How to avoid:** In Phase 9, replace `_safeSetState()` with direct `state.value = next` assignment (no guard check). Phase 10 will add the new EngineStateMachine that replaces the guard. The gap is intentional — Phase 9 only splits the state model, Phase 10 adds the enforcement.

**Warning signs:** Compile errors in fvp_engine.dart referencing `canTransitionTo`.

### Pitfall 4: errorBanner UI Breaking on PlayerError

**What goes wrong:** ErrorBanner switches on `engine.errorType` (MediaErrorType enum). After D-09/D-10, MediaErrorType is deleted and `errorType` getter is removed. ErrorBanner must switch on `engine.lastError.value` (PlayerError sealed class) instead.

**Why it happens:** UI code directly references the error type enum.

**How to avoid:** Update ErrorBanner in the same plan. Change from `switch (engine.errorType)` to `switch (engine.lastError.value)` with pattern matching on sealed subtypes.

**Warning signs:** Compile errors in error_banner.dart.

### Pitfall 5: PlaybackContract Deletion Breaking Sub-Modules

**What goes wrong:** PlaybackNavigator, FileOperations, StateMonitor reference `PlaybackController` directly (not PlaybackContract). But playback_contract.dart is still imported by some files. Deleting it without updating imports causes compile errors.

**Why it happens:** PlaybackContract exists but is already unused by production code (sub-modules receive `this` from PlaybackController constructor). However, test helpers or other files might import it.

**How to avoid:** Grep for `playback_contract` imports before deleting. Update any remaining imports to use PlaybackController directly.

**Warning signs:** "File not found" errors for playback_contract.dart imports.

## Code Examples

Verified patterns from official sources:

### Sealed Class with Exhaustive Matching
```dart
// Source: https://dart.dev/language/class-modifiers#sealed
// Used in: OpenResult (existing), PlayerError (new)

sealed class PlayerError {
  const PlayerError();
  String get message;
}

final class FileError extends PlayerError {
  final FileErrorCode code;
  @override final String message;
  const FileError(this.code, this.message);
}

// Compiler enforces exhaustive matching — no default needed:
String describe(PlayerError error) => switch (error) {
  FileError(:final code, :final message) => 'File: $code — $message',
  CodecError(:final message) => 'Codec: $message',
  PlaybackError(:final message) => 'Playback: $message',
  NetworkError(:final message) => 'Network: $message',
  UnknownError(:final message) => 'Unknown: $message',
};
```

### Abstract Class Interface (ISP)
```dart
// Source: Project convention — WindowBridge pattern (4 states + 7 commands)

/// Read-only state view — UI binds to these
abstract class EngineStateView {
  ValueNotifier<int?> get textureId;
  ValueNotifier<MediaState> get state;
  // ... 12 getters total
  void dispose();
}

/// Control commands — PlaybackController calls these
abstract class PlaybackControl {
  Future<void> open(String path);
  void play();
  // ... 12 methods total
}

/// FvpEngine implements all interfaces
class FvpEngine implements EngineStateView, PlaybackControl, TrackControl,
    SubtitleConfig, VideoEffectControl, RendererControl {
  @override
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);
  // ... all implementations
}
```

### ValueNotifier Pattern for Orthogonal State
```dart
// Source: Project convention — all state via ValueNotifier

// Primary state (mutually exclusive)
final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);

// Transient flags (orthogonal — can be true during any primary state)
final ValueNotifier<bool> isSeeking = ValueNotifier(false);
final ValueNotifier<bool> isBuffering = ValueNotifier(false);

// UI usage:
ValueListenableBuilder<MediaState>(
  valueListenable: engine.state,
  builder: (context, state, _) => ValueListenableBuilder<bool>(
    valueListenable: engine.isSeeking,
    builder: (context, seeking, _) {
      // Can combine state + seeking independently
    },
  ),
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| mixin EngineState (god mixin) | 6 abstract class interfaces | Phase 9 | ISP compliance, each consumer sees only what it needs |
| MediaErrorType + PlayerErrorCode (dual) | PlayerError sealed class (unified) | Phase 9 | Single error type, exhaustive matching |
| MediaState 9 values (conflated) | MediaState 6 values + bool flags | Phase 9 | Orthogonal state, cleaner UI binding |
| features/player/services/ path | kernel/services/ path | Phase 9 | Correct architectural layering |
| PlaybackContract interface | Direct PlaybackController dependency | Phase 9 | Less indirection, simpler code |

**Deprecated/outdated:**
- EngineState mixin: replaced by 6 abstract classes
- MediaErrorType enum: replaced by PlayerError sealed class subtypes
- PlayerErrorCode enum: merged into PlayerError sealed class sub-enum codes
- MediaState.seeking/buffering: replaced by ValueNotifier<bool> isSeeking/isBuffering
- PlaybackContract: deleted, sub-modules depend on PlaybackController directly

## Assumptions Log

> All claims in this research were verified against source code or are derived from locked CONTEXT.md decisions. No external package research was needed (zero new dependencies).

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| (none) | All claims verified from source code or CONTEXT.md decisions | — | — |

## Open Questions (RESOLVED)

1. **SubtitleConfig vs TrackControl overlap** (RESOLVED)
   - What we know: D-03 defines SubtitleConfig with subtitleText/subtitleDelay getters that also appear conceptually in EngineStateView (D-05 says all 12 ValueNotifiers stay in EngineStateView)
   - What's unclear: subtitleText is a ValueNotifier in EngineStateView AND a getter in SubtitleConfig — does SubtitleConfig expose the same ValueNotifier, or a derived read-only view?
   - RESOLVED: SubtitleConfig declares `ValueNotifier<String> get subtitleText` as a getter that returns the same instance from EngineStateView. FvpEngine implements both interfaces with one field. No duplication.

2. **VideoEffectControl aspectRatio getter** (RESOLVED)
   - What we know: D-03 says VideoEffectControl has `aspectRatio getter`, but D-05 says all 12 ValueNotifiers stay in EngineStateView
   - What's unclear: Same question — does VideoEffectControl re-expose the same ValueNotifier?
   - RESOLVED: Same pattern. VideoEffectControl declares `ValueNotifier<double> get aspectRatio` returning the same instance. FvpEngine has one field implementing both interfaces.

3. **VideoProcessingService location** (RESOLVED)
   - What we know: D-11 lists 5 modules to migrate but VideoProcessingService is also in features/player/services/
   - What's unclear: D-15 says features/player/ only retains UI files — does VideoProcessingService also migrate?
   - RESOLVED: Yes, it migrates to kernel/services/ along with the others. It depends on EngineState (kernel layer) and has no UI dependency.

4. **BreakpointSaver location** (RESOLVED)
   - What we know: breakpoint_saver.dart is in features/player/services/ but D-11 doesn't explicitly list it
   - What's unclear: Should it migrate too?
   - RESOLVED: Yes — it depends on EngineState + Playlist, both kernel-layer. Migrate to kernel/services/.

## Environment Availability

> Skip — no external dependencies. This phase is pure Dart refactoring within the existing Flutter project.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml (dev_dependencies) |
| Quick run command | `flutter test test/engine/ test/kernel/` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ENG-01 | FvpEngine implements all 6 interfaces | unit | `flutter test test/engine/mixin_capability_test.dart` | Yes (needs rewrite) |
| ENG-01 | EngineStateView exposes 12 getters | unit | `flutter test test/engine/mixin_capability_test.dart` | Yes (needs rewrite) |
| ENG-03 | PlayerError exhaustive matching | unit | `flutter test test/kernel/models/player_error_test.dart` | Yes (needs rewrite) |
| ENG-03 | OpenResult uses PlayerError | unit | `flutter test test/kernel/engine/media_opener_test.dart` | Yes |
| ENG-03 | ErrorBanner switches on PlayerError | widget | `flutter test test/widget/player/error_banner_test.dart` | Yes |
| SVC-01 | PlaybackController import path updated | unit | `flutter test test/kernel/services/playback_controller_test.dart` | Yes (import path change) |
| SVC-01 | All service tests pass after migration | unit | `flutter test test/kernel/services/` | Yes |

### Sampling Rate

- **Per task commit:** `flutter test test/engine/ test/kernel/models/` (focused)
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/engine/mixin_capability_test.dart` — needs rewrite for new 6-interface pattern
- [ ] `test/kernel/models/player_error_test.dart` — needs rewrite for sealed class hierarchy
- [ ] `test/helpers/fake_engine.dart` — needs rewrite: `with` -> `implements`, add lastError, update errorMessage references

## Security Domain

> No security-sensitive changes in this phase. Error model refactoring does not affect input validation, authentication, or cryptographic operations.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | Error model change does not affect input validation paths |
| V6 Cryptography | no | — |

### Known Threat Patterns for Dart/Flutter

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-----|
| (none applicable) | — | Phase 9 is pure refactoring, no new attack surface |

## Sources

### Primary (HIGH confidence)
- Source code analysis of all 16 canonical ref files listed in CONTEXT.md
- Existing test files (mixin_capability_test.dart, player_error_test.dart, playback_controller_test.dart)
- Dart 3 sealed class specification: https://dart.dev/language/class-modifiers#sealed

### Secondary (MEDIUM confidence)
- Project conventions from CLAUDE.md (ValueNotifier pattern, abstract class interfaces)

### Tertiary (LOW confidence)
- (none — all findings from source code)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, pure Dart refactoring
- Architecture: HIGH — all decisions locked in CONTEXT.md, source code fully analyzed
- Pitfalls: HIGH — derived from actual code analysis (34 import sites, 378-line FakeEngine, guard extension deletion)

**Research date:** 2026-07-14
**Valid until:** 2026-08-14 (stable — no external deps, only internal refactoring)
