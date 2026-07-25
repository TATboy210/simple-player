# 21-05 SUMMARY: MediaEngine Migration Order

**Plan:** 21-05 (VERIFY-03)
**Status:** Complete
**Date:** 2026-07-20

## What Was Done

Used codegraph MCP tools to analyze the MediaEngine dependency graph and produced
`docs/migration-order.md` with dependency-driven migration ordering.

### codegraph Analysis Results

| Query | Result |
|-------|--------|
| `codegraph explore "MediaEngine"` | 57 symbols across 6 files; 17 callers of MediaEngine |
| `callers_of FvpEngine.open` | 8 results: PlaybackNavigator (production), 4 test files, FvpEngine self-recursive |
| `callers_of FvpEngine.play` | 5 results: PlaybackNavigator + EngineStateMachine.onPlay (production) |
| `callers_of FvpEngine.pause` | 3 results: EngineStateMachine.onPause (production) |
| `callers_of FvpEngine.seekTo` | 7 results: PlaybackNavigator + ProgressBar + PlayerScreen (production) |
| `callers_of FvpEngine.setVolume` | 7 results: StateMonitor + PlayerScreen + VolumeControls (production) |
| `callers_of FvpEngine.setPlaybackRate` | 4 results: SpeedButton (production) |
| `callers_of FvpEngine.togglePlayPause` | 3 results: PlayerScreen (production) |

### 4-Layer Migration Order (dependency-graph-driven)

1. **Leaf Layer** (21 members, no downstream deps):
   - RendererControl (2) → VideoEffectControl (4) → TrackControl (3) → VolumeControl (4) → SubtitleConfig (8)

2. **Orchestrator Layer** (12 methods, depends on leaf helpers):
   - PlaybackControl non-open (11 methods) → PlaybackControl.open (1 method, highest complexity)

3. **State Management Layer** (14 members, depends on orchestrator):
   - EngineStateView (identity-preserving ValueNotifier forwarding, Blocking #6)

4. **UI Binding Layer** (~7 widgets, depends on state):
   - PlayerScreen → ProgressBar → ControlsOverlay → VolumeControls → SpeedButton → MediaInfoDialog

### Phase 20 D11 Comparison

Phase 20 used **core-first** strategy: open → play → pause → seek → volume → mute → other.
This differs from the dependency-graph-driven **leaf-first** strategy.
Both are valid: core-first builds confidence early (Phase 20), leaf-first minimizes risk per step (Phase 21 regression).

### Risk Assessment

- **CRITICAL:** open() (async + generation + codec fallback), EngineStateView (identity forwarding), seekTo()
- **HIGH:** play()/pause() (state transitions), VolumeControl (shared with PlaybackControl)
- **MEDIUM:** SubtitleConfig (8 members), VideoEffectControl, RendererControl
- **LOW:** TrackControl, setPlaybackRate/setRange/skipForward/skipBack

## Artifacts

- `docs/migration-order.md` (220 lines) — full migration order document
