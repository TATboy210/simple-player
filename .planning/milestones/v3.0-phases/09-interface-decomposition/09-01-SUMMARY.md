---
phase: 09-interface-decomposition
plan: 01
status: complete
completed: 2026-07-14
files_created:
  - lib/kernel/engine/engine_state_view.dart
  - lib/kernel/engine/playback_control.dart
  - lib/kernel/engine/subtitle_config.dart
  - lib/kernel/engine/video_effect_control.dart
  - lib/kernel/engine/renderer_control.dart
files_rewritten:
  - lib/kernel/engine/track_control.dart
  - lib/kernel/models/player_error.dart
  - lib/kernel/engine/media_state.dart
  - lib/kernel/engine/open_result.dart
  - lib/kernel/engine/engine_state.dart
  - test/helpers/fake_engine.dart
files_deleted:
  - lib/kernel/engine/media_error_type.dart
  - lib/kernel/engine/video_effects.dart
  - lib/kernel/engine/renderer_config.dart
---

# Plan 09-01 Summary: ISP Interface Decomposition + Error Model Unification

## What Changed

### 6 ISP Interface Abstract Classes (New)
- `EngineStateView` — 13 read-only ValueNotifier getters (12 original + isSeeking) + mediaInfo + dispose
- `PlaybackControl` — 12 control methods (open/play/pause/stop/seek/volume/speed/range/skip)
- `TrackControl` — 3 members (getAudioTracks/switchAudioTrack/activeAudioTracks)
- `SubtitleConfig` — 8 members (6 methods + subtitleText + subtitleDelay)
- `VideoEffectControl` — 5 members (4 methods + aspectRatio)
- `RendererControl` — 2 methods (setD3d11SyncEnabled/setHardwareDecoding)

### PlayerError Sealed Class (Rewritten)
- Replaced flat `PlayerErrorCode` enum + `PlayerError` class
- New nested sealed hierarchy: `FileError`/`CodecError`/`PlaybackError`/`NetworkError`/`UnknownError`
- Each subtype carries its own sub-enum code (FileErrorCode, CodecErrorCode, etc.)
- Supports exhaustive pattern matching via Dart 3 sealed classes

### MediaState Enum (Rewritten)
- Reduced from 9 values to 6: idle/opening/playing/paused/completed/error
- Removed: loading→opening, stopped (stop→idle), seeking, buffering
- Deleted `MediaStateTransition` extension (transition guards → Phase 10)
- seeking/buffering now as separate `ValueNotifier<bool>` flags

### OpenResult (Rewritten)
- `OpenError` now wraps `PlayerError` instead of `MediaErrorType`
- Removed `type` and `message` fields from OpenError — callers use `error.message`

### engine_state.dart (Converted)
- Entire mixin body removed
- Now barrel export re-exporting all 6 new interfaces + model types
- Backward compatible — existing imports still work

### FakeEngine (Updated)
- `with EngineState, TrackControl, VideoEffects, RendererConfig` → `implements EngineStateView, PlaybackControl, TrackControl, SubtitleConfig, VideoEffectControl, RendererControl`
- `errorMessage` → `lastError` (ValueNotifier<PlayerError?>)
- `errorType` field removed
- `isSeeking` ValueNotifier added
- `MediaState.loading` → `MediaState.opening`
- `MediaState.stopped` → `MediaState.idle`
- `simulateBuffering()` only sets isBuffering flag (no state change)

### Deleted Files
- `media_error_type.dart` — replaced by PlayerError sealed subtypes
- `video_effects.dart` — old empty mixin, replaced by video_effect_control.dart
- `renderer_config.dart` — old empty mixin, replaced by renderer_control.dart

## Known Breakage (Expected — Plan 02 will fix)
- `fvp_engine.dart` — still uses old mixin pattern + MediaErrorType
- `fvp_callback_handler.dart` — references removed MediaState values
- `media_opener.dart` — imports deleted media_error_type.dart
- Various UI widgets — reference old errorMessage/errorType

## Verification
- `dart analyze` on all 11 plan files: **0 errors, 0 warnings**
- FakeEngine compiles with `implements` all 6 interfaces
- PlayerError sealed class supports exhaustive matching
- MediaState has exactly 6 values
