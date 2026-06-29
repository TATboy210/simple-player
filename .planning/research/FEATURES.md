# Features Research: PlayerEngine Refactoring

## Table Stakes (must preserve)

These features are production-critical and must survive the refactoring unchanged. Any regression is a ship-blocker.

### 1. Playback Controls (10 methods, 5 ValueNotifiers)

| Method | Purpose | UI Consumers |
|--------|---------|--------------|
| `open(path)` | Load local file or URL, state -> loading -> idle/error | PlayerScreen, PlaybackController |
| `play()` | Start playback, state -> playing | CenterControls, KeyboardHandler |
| `pause()` | Pause playback, state -> paused | CenterControls, KeyboardHandler |
| `stop()` | Stop + reset position to 0 | CenterControls, PlaybackController |
| `seekTo(ms)` | Jump to position (clamp 0..duration) | ProgressBar, PlayerScreen, KeyboardHandler |
| `togglePlayPause()` | Toggle play/pause | CenterControls, KeyboardHandler, ControlsOverlay |
| `skipForward(ms)` / `skipBack(ms)` | Relative seek (default 10s) | CenterControls, KeyboardHandler |
| `setRange(from, to)` | AB loop | KeyboardHandler |
| `setVolume(0.0-1.0)` | Volume control, auto-mute at 0 | VolumeControls, PlayerScreen, KeyboardHandler |
| `setMute(bool)` | Mute toggle | VolumeControls, PlayerScreen, KeyboardHandler |

**ValueNotifiers consumed by UI:**
- `state` (MediaState) -- 8 widgets (PlayerScreen, ControlsOverlay, CenterControls, ErrorBanner, ...)
- `position` (int ms) -- 3 widgets (ProgressBar, TimeRangeDisplay, PlayerScreen)
- `duration` (int ms) -- 3 widgets (ProgressBar, TimeRangeDisplay, PlayerScreen)
- `volume` (double) -- 2 widgets (VolumeControls, PlayerScreen)
- `isMuted` (bool) -- 2 widgets (VolumeControls, PlayerScreen)

### 2. Track Management (5 methods, 1 getter)

| Method | Purpose | UI Consumers |
|--------|---------|--------------|
| `getAudioTracks()` | List available audio tracks | AudioTab |
| `switchAudioTrack(index)` | Select audio track | AudioTab |
| `activeAudioTracks` | Current active track indices | AudioTab |
| `getSubtitleTracks()` | List available subtitle tracks | (unused currently, but interface-critical) |
| `switchSubtitleTrack(index)` | Select subtitle (-1 = off) | KeyboardHandler |
| `toggleSubtitle()` | Toggle subtitle on/off | PlayerScreen, KeyboardHandler |
| `setExternalSubtitle(path)` | Load .srt/.ass/.ssa/.vtt | SubtitleService (auto-detect), PlayerScreen |
| `setSubtitleDelay(ms)` | Delay subtitle (positive = delay, negative = advance) | PlayerScreen, KeyboardHandler |

**Data models (immutable, value equality):**
- `AudioTrackInfo` -- index, language, codec, channels
- `SubtitleTrackInfo` -- index, language, title

### 3. Video Effects (6 methods)

| Method | Purpose | UI Consumers |
|--------|---------|--------------|
| `setVideoEffect(type, value)` | Brightness/contrast/hue/saturation [-1.0, 1.0] | VideoProcessingService (diff-based sync) |
| `rotate(degree)` | 0/90/180/270 rotation | VideoProcessingService |
| `setAspectRatio(ratio)` | Aspect ratio override | VideoProcessingService |
| `setDeinterlace(bool)` | Yadif deinterlace (SW only) | VideoProcessingService |
| `setEqualizer(afFilter)` | FFmpeg audio filter string | EqualizerTab |
| `playbackSpeed` / `setPlaybackRate(0.25-4.0)` | Speed control | SpeedButton, KeyboardHandler |

**Data model:**
- `VideoEffectType` enum -- brightness, contrast, hue, saturation

### 4. Media Info & Metadata

| Property/Method | Purpose | UI Consumers |
|-----------------|---------|--------------|
| `mediaInfo` (MediaInfo) | Parsed metadata after open | MediaInfoDialog |
| `textureId` (ValueNotifier<int?>) | D3D11 texture for Texture widget | PlayerScreen, VideoSurface |
| `aspectRatio` (ValueNotifier<double>) | PAR-corrected width/height | VideoSurface |
| `subtitleText` (ValueNotifier<String>) | Current subtitle text | (OSD overlay) |
| `buffered` (ValueNotifier<int>) | Buffered amount in ms | ProgressBar |
| `errorMessage` (ValueNotifier<String?>) | Error description | ErrorBanner |
| `errorType` (MediaErrorType) | Error category for action buttons | ErrorBanner |
| `subtitleDelay` (int getter) | Current subtitle delay | PlayerScreen |

**Data models (immutable, value equality):**
- `MediaInfo` -- duration, VideoCodecInfo?, AudioTrackInfo[], SubtitleTrackInfo[]
- `VideoCodecInfo` -- width, height, par, codec
- `MediaState` enum -- idle, loading, playing, paused, stopped, completed, error, seeking, buffering
- `MediaErrorType` enum -- file, codec, playback, network, unknown

### 5. Platform Integration (D3D11)

| Method | Purpose | UI Consumers |
|--------|---------|--------------|
| `setD3d11SyncEnabled(bool)` | CPU/GPU sync toggle (async=low latency, sync=no tearing) | PerformanceTab |
| `setHardwareDecoding(bool)` | HW decode (D3D11/NVDEC) vs SW (FFmpeg) | PerformanceTab |

### 6. Engine Lifecycle

| Method | Purpose |
|--------|---------|
| `dispose()` | Release all resources, mark disposed |
| `EnginePrewarm.prewarm()` | Pre-init FFmpeg codecs + D3D11 context at startup |

**Guard patterns that must survive:**
- `_disposed` check on every method (guard clause pattern)
- `_guardedAction` wrapper: disposed check + try-catch + log + error state
- `MediaOpener` sealed result: `OpenSuccess` / `OpenError` (not exceptions)
- Parameter clamping at entry (defensive programming)

### 7. State Management Contract (ValueNotifier Pattern)

The UI layer has a strict contract with the engine:

- **Engine is sole producer** -- UI never writes to engine ValueNotifiers directly
- **UI is consumer + command invoker** -- read state via ValueListenableBuilder, call methods for mutations
- **12 ValueNotifiers exposed** -- textureId, state, position, duration, volume, isMuted, isBuffering, subtitleText, buffered, aspectRatio, errorMessage, playbackSpeed
- **3 plain getters** -- errorType, mediaInfo, subtitleDelay
- **MergedListenable** pattern for multi-notifier widgets (ProgressBar, TimeRangeDisplay)
- **Dual-listener pattern** in ControlsOverlay -- manual addListener for imperative side effects + ValueListenableBuilder for UI
- **ValueNotifier bridge** in PerformanceTab -- custom subclass wrapping engine command + persistence

### 8. Adaptive Position Polling

`PositionPoller` 3-tier strategy must survive (CPU efficiency):
- **Fast**: 100ms for 1s after seek (responsive scrubbing)
- **Normal**: 250ms during active playback
- **Silent**: 500ms after 3s idle (save CPU)
- Buffered polling only for URL sources (skip FFI for local files)
- Pauses during active seeks (prevent stale position overwrites)

### 9. Network Stream Support

`NetworkConfigurator` protocol-specific handling:
- **RTSP**: 500KB probe, nobuffer, low-latency drop
- **RTMP/SRT/UDP/TCP**: nobuffer, direct
- **HTTP**: demux buffer for seek acceleration
- **Defaults**: 10s timeout, 1MB probe, 5s analyze duration

### 10. MockEngine for Testing

`MockEngine` provides:
- Configurable `openDelay` and `autoPlay`
- Simulated position timer (250ms ticks, respects playbackSpeed)
- State transition recording + event history
- `exportDebugData()` / `exportDebugJson()` for test diagnostics
- Full interface compliance (all 12 ValueNotifiers + 30 methods)

---

## Differentiators (architecture improvements)

These are improvements the refactoring enables -- not new features, but better architecture that unlocks future work.

### D1. Engine Decomposition (547 lines -> focused modules)

FvpEngine currently bundles 5 helper classes but still has 547 lines of orchestration. Refactoring can extract:
- Open flow (already `MediaOpener`)
- Callback mapping (already `FvpCallbackHandler`)
- But: play/pause/seek/volume/range logic still inline

**Benefit**: Each concern testable independently, engine becomes thin coordinator.

### D2. Interface Segregation

The current `PlayerEngine` is a 30-method flat interface. Widgets consume subsets:
- ProgressBar only needs: position, duration, buffered, seekTo
- VolumeControls only needs: volume, isMuted, setVolume, setMute
- SpeedButton only needs: playbackSpeed, setPlaybackRate

**Benefit**: Narrower interfaces reduce coupling, enable focused mocks for widget tests.

### D3. State Machine Formalization

`MediaState` has 9 states but transitions are implicit (scattered across FvpEngine methods). A formal state machine would:
- Define valid transitions explicitly
- Prevent illegal state combinations (e.g., buffering + completed)
- Make MockEngine state behavior verifiable

**Benefit**: Fewer state-related bugs, easier to reason about edge cases.

### D4. Error Recovery Strategy

Currently errors set `errorMessage.value` and `state.value = MediaState.error`, but there is no recovery path. The refactoring can add:
- Automatic retry for network errors
- Codec fallback (HW -> SW)
- User-initiated retry without full re-open

**Benefit**: Better user experience for transient failures.

### D5. Platform Abstraction

D3D11 configurator is Windows-only. The refactoring should:
- Keep platform-specific code behind the same interface
- Enable macOS/Linux engine implementations
- Make `setD3d11SyncEnabled` / `setHardwareDecoding` platform-aware

**Benefit**: Cross-platform engine swaps without UI changes.

### D6. Hot-Reload Engine Swap

`PlayerServices` already supports `engineOverride` for mock injection. The refactoring can:
- Enable runtime engine switching (e.g., fvp -> VLC for specific codecs)
- Preserve playback position across engine swaps
- Support A/B testing of engine implementations

**Benefit**: Flexibility for codec compatibility and performance comparison.

---

## Anti-Features (things to NOT do)

Changes that would break existing functionality or violate established contracts.

### A1. DO NOT break the ValueNotifier contract

The UI layer has 57 files importing PlayerEngine. Every widget assumes:
- ValueNotifiers are the sole state source
- Methods are synchronous void commands (except open/seekTo which are Future)
- Values update on the main thread (SchedulerBinding.addPostFrameCallback)

**Wrong**: Replacing ValueNotifiers with Streams, ChangeNotifier, or Bloc would break all 57 consumers.

### A2. DO NOT change method signatures

`open(String path)` returns `Future<void>`, not `Future<OpenResult>`. The UI catches errors via `errorMessage` + `state`, not return values.

**Wrong**: Changing `open()` to return a result type would break all callers that expect `Future<void>`.

### A3. DO NOT add required constructor parameters to PlayerEngine

FvpEngine uses lazy initialization (`_playerInstance ??= _createPlayer()`). Adding required params to the constructor would break `MockEngine` and any test that creates engines without a real mdk.Player.

**Wrong**: `PlayerEngine({required this.mdkPlayer})` -- forces all implementations to have a player at construction time.

### A4. DO NOT remove the _disposed guard pattern

Every method checks `_disposed` before executing. Removing this causes use-after-dispose crashes when UI widgets outlive the engine (e.g., during hot reload or navigation).

**Wrong**: Removing `_disposed` checks because "Flutter should handle lifecycle."

### A5. DO NOT change the position poller timing contract

UI widgets (ProgressBar, TimeRangeDisplay) assume position updates arrive at ~100ms-500ms intervals. Changing to event-driven (only on actual position change) would break:
- Seekbar smooth animation
- Time display update frequency
- Auto-hide timer correlation with position

### A6. DO NOT make open() synchronous

`open()` is async because it calls `mdk.Player.prepare()` (10s timeout) and creates D3D11 texture (5s timeout). Making it synchronous would block the UI thread.

### A7. DO NOT remove MockEngine

MockEngine is the test backbone. It must:
- Implement the full PlayerEngine interface
- Support configurable delays (openDelay)
- Record state transitions for assertion
- Export debug data for test diagnostics

### A8. DO NOT hardcode platform-specific paths in the interface

`setD3d11SyncEnabled` and `setHardwareDecoding` are in the abstract interface but only work on Windows. The refactoring should keep them in the interface (for UI binding) but allow no-op implementations on other platforms.

---

## Dependencies Between Features

### Core Dependency Graph

```
open(path)
  ├── NetworkConfigurator (URL sources only)
  ├── MediaOpener (path validation, prepare, metadata parse)
  ├── D3D11 texture creation
  ├── duration, aspectRatio, mediaInfo populated
  └── state: loading -> idle | error

play() / pause() / togglePlayPause()
  ├── PositionPoller (start/stop)
  ├── state update
  └── FvpCallbackHandler (onStateChanged listener)

seekTo(ms)
  ├── PositionPoller (pause during seek, resume after)
  ├── state: -> seeking (transient)
  └── position update (after mdk callback)

setVolume / setMute
  └── VolumeController (clamp, auto-mute/unmute logic)

setVideoEffect / rotate / setAspectRatio / setDeinterlace
  └── VideoEffectController (mdk.VideoEffect mapping)

getAudioTracks / switchAudioTrack / getSubtitleTracks / switchSubtitleTrack
  └── TrackManager (holds MediaInfo reference from last open)

setExternalSubtitle / setSubtitleDelay / setEqualizer
  └── SubtitleConfigurator (mdk property setters)

setD3d11SyncEnabled / setHardwareDecoding
  └── D3D11Configurator (Windows-only, mdk property setters)
```

### UI Consumption Map

```
PlayerScreen ──── textureId, state, position, duration, volume, isMuted,
                  subtitleDelay, seekTo, togglePlayPause, setVolume,
                  setMute, toggleSubtitle, setSubtitleDelay, setExternalSubtitle

ControlsOverlay ── state (manual addListener + ValueListenableBuilder)

ControlBar ──────── (delegates to children, no direct access)

ProgressBar ─────── position, duration, buffered, seekTo

VolumeControls ──── isMuted, volume, setVolume, setMute

SpeedButton ─────── playbackSpeed, setPlaybackRate

TimeRangeDisplay ── position, duration

ErrorBanner ─────── state, errorMessage, errorType

CenterControls ──── state, togglePlayPause, skipBack, skipForward

VideoSurface ────── textureId, aspectRatio

AudioTab ────────── getAudioTracks, activeAudioTracks, switchAudioTrack

EqualizerTab ────── setEqualizer

PerformanceTab ──── setD3d11SyncEnabled, setHardwareDecoding

MediaInfoDialog ─── mediaInfo (one-shot read)

SubtitleService ─── setExternalSubtitle (auto-detect)

VideoProcessing ─── setVideoEffect, rotate, setAspectRatio, setDeinterlace
                    (diff-based sync, only dispatches changed values)

PlaybackController stop (on playlist removal/clear)
```

### Critical Ordering Constraints

1. `open()` must complete before any playback method is valid
2. `MediaInfo` is only populated after `open()` succeeds
3. Track methods require `MediaInfo` to be populated
4. `seekTo()` requires `duration > 0`
5. Position polling must stop before engine `dispose()`
6. `FvpCallbackHandler.init()` must run before any mdk state changes are observed
7. D3D11 config must be set after player creation but before first `open()`

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Abstract methods (PlayerEngine) | 30 |
| ValueNotifier state fields | 12 |
| Plain getters | 3 |
| Data models (immutable) | 7 (MediaInfo, VideoCodecInfo, AudioTrackInfo, SubtitleTrackInfo, MediaState, MediaErrorType, VideoEffectType) |
| Helper classes in FvpEngine | 5 (PositionPoller, TrackManager, VideoEffectController, MediaOpener, FvpCallbackHandler) |
| Configurator classes | 4 (NetworkConfigurator, SubtitleConfigurator, D3D11Configurator, VolumeController) |
| UI files consuming PlayerEngine | ~21 |
| Total files importing PlayerEngine | 57 |
| Engine line count (FvpEngine) | 547 |
| MockEngine line count | ~430 |
