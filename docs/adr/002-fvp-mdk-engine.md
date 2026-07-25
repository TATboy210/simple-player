# ADR-002: fvp (MDK/FFmpeg) as Playback Engine

## Status

**Adopted** (project inception, validated through v2.1, confirmed for v3.0 kernel rewrite)

## Context

A desktop media player requires a playback engine capable of:

1. Decoding and rendering video files in common formats (MP4, MKV, AVI, WebM, etc.) with hardware acceleration.
2. Providing audio/subtitle track management (select, switch, delay adjustment).
3. Supporting network streaming protocols (RTSP, RTMP, SRT, UDP, TCP) for future extensibility.
4. Exposing a Dart-friendly API without requiring manual FFI binding for every codec operation.
5. Running on Windows (primary), macOS, and Linux.

### Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **fvp (MDK/FFmpeg)** | Flutter-native plugin, D3D11 hardware decoding on Windows, NVDEC GPU acceleration, cross-platform, texture rendering, active maintenance by wang-bin | Closed-source MDK core, limited Flutter-specific docs, version pinning required | **CHOSEN** |
| `video_player` (official) | Official Flutter team package, wide adoption | Not designed for desktop (focused on mobile), limited format support, no hardware decoding on desktop, no subtitle track API | REJECTED — desktop support insufficient |
| `media_kit` | Modern Dart API, good desktop support, libmpv-based | Depends on libmpv (external runtime), larger binary, different rendering model (not D3D11 texture) | REJECTED — external runtime dependency + rendering model mismatch |
| Custom FFmpeg FFI | Full control, no third-party dep | Massive engineering effort, codec binding maintenance, rendering pipeline, multi-platform native builds | REJECTED — unreasonable effort for a media player |
| mpv/libmpv FFI | Battle-tested, extensive codec support | Requires native mpv binary distribution, FFI binding maintenance, no Flutter texture integration | REJECTED — distribution + rendering friction |

## Decision

Use **fvp ^0.37.2** (MDK/FFmpeg wrapper) as the playback engine, integrated via `package:fvp/mdk.dart`.

Key design rules:

- `FvpEngine` implements the `MediaEngine` composite interface (7 ISP interfaces: `EngineStateView`, `PlaybackControl`, `TrackControl`, `SubtitleConfig`, `VideoEffectControl`, `RendererControl`, `VolumeControl`).
- `mdk.Player` is the underlying native player instance, created in a factory constructor with D3D11 parameters.
- `PositionPoller` (Timer-based, 200ms interval) polls `mdk.Player.position` and updates `ValueNotifier<int> position`.
- `FvpCallbackHandler` marshals mdk native callbacks (state changes, media info, errors) to the main Dart isolate.
- `EnginePrewarm.prewarm()` fire-and-forget at startup: registers FFmpeg codecs, initializes D3D11 context.
- Version pinned to `^0.37.2` in `pubspec.yaml` with committed `pubspec.lock` to prevent accidental breaking upgrades.

### D3D11 Configuration

- `d3d11.sync.cpu` mode derived from display refresh rate (via `DisplayConfig`): sync mode `'1'` for 60Hz (safe default), async mode `'0'` for 144Hz+ (reduces latency ~8ms/frame).
- Hardware decoding: D3D11 on Windows, NVDEC on NVIDIA GPUs.
- Texture rendering: fvp provides a `textureId` that Flutter renders via `Texture` widget.

## Consequences

### Positive

- **Flutter-native integration.** fvp is a Flutter plugin that registers textures with the Flutter engine. No manual compositor or rendering pipeline needed — `Texture(textureId: engine.textureId.value)` is the entire rendering surface.
- **Hardware acceleration out of the box.** D3D11 decoding on Windows, NVDEC on NVIDIA — no manual GPU configuration.
- **Comprehensive format support.** FFmpeg backend handles virtually all media formats, codecs, and containers without per-format binding code.
- **Cross-platform.** Same `mdk.Player` API works on Windows, macOS, and Linux. Platform-specific rendering (D3D11, Metal, OpenGL) handled internally.
- **Network streaming.** RTSP/RTMP/SRT/UDP/TCP protocols supported natively via `NetworkConfigurator`, with adaptive buffering tuning.
- **Track management.** Audio/subtitle track enumeration, selection, and subtitle delay adjustment are all first-class API features.

### Negative

- **Closed-source core.** MDK is not open-source; bugs in the core engine require upstream fixes. The Flutter plugin (`fvp`) is open-source and forkable.
- **Version pinning required.** Breaking changes in fvp could require rewriting `FvpEngine` and all helpers. The `pubspec.lock` + `^0.37.2` pin mitigates accidental upgrades.
- **Callback threading model.** mdk fires callbacks on a native thread, requiring explicit marshalling to the Dart main isolate. This adds complexity to error handling (sealed errors crossing thread boundaries — see Pitfall 7 in `.planning/research/PITFALLS.md`).
- **No ABR (Adaptive Bitrate).** fvp/MDK does not provide built-in HLS/DASH ABR. This is deferred to a future milestone (see HLS ABR Plan in project memory).

### Mitigations

- `FvpCallbackHandler` + `SchedulerBinding.instance.addPostFrameCallback` marshal all callbacks to the main isolate.
- v3.0 kernel rewrite introduces a `KernelAdapter` (compatible-replacement seam) that decouples the UI from the specific engine implementation, enabling future engine swaps without UI changes.
- `EngineMetrics` and `EngineEventLog` provide runtime observability into engine health.
- `DisplayConfig` caches refresh rate and derives optimal D3D11 sync mode, with safe 60Hz fallback.

## Related Decisions

- [ADR-001: ValueNotifier State Management](001-value-notifier-state-management.md) — Engine state maps directly to ValueNotifier assignments.
- [ADR-003: Win32 FFI Window Management](003-win32-ffi-window.md) — Window management is separate from engine; both use native code but via different pathways.
- [ADR-004: Layered Architecture](004-layered-architecture.md) — Engine lives in the Kernel layer, consumed by Features and UI layers.

## References

- `lib/kernel/engine/fvp_engine.dart` — Concrete fvp engine implementation (~628 lines, 6 helper composition).
- `lib/kernel/engine/media_engine.dart` — Abstract 7-ISP composite interface.
- `lib/kernel/engine/position_poller.dart` — Timer-based position polling.
- `lib/kernel/engine/track_manager.dart` — Audio/subtitle track management.
- `lib/kernel/engine/engine_prewarm.dart` — Startup prewarm (codec registration, D3D11 init).
- `lib/kernel/engine/network_configurator.dart` — Protocol-specific streaming tuning.
- `pubspec.yaml` — `fvp: ^0.37.2` dependency declaration.
- `.planning/codebase/CONCERNS.md` — "fvp: ^0.37.2 — Core rendering dependency; version-pinned."
- `.planning/codebase/STACK.md` — fvp capabilities: D3D11 hardware decoding, NVDEC, network streaming.
- `.planning/PROJECT.md` — Key Decisions: "保持 fvp 引擎 — MDK/FFmpeg 能力足够，更换成本高".
