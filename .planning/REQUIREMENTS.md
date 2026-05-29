# Requirements — Simple Player Flutter v1.1

**Date:** 2026-05-29
**Strategy:** Quality-first — testing infrastructure, code optimization, architecture cleanup

## v1.1 Requirements

### Window Optimization (OPT)

- [ ] **OPT-01**: Window layer code optimization
  - Refactor window management code structure while preserving all existing behavior
  - Keep MethodChannel contract with C++ runner unchanged
  - Reduce complexity, improve readability, remove dead paths
  - Files: `lib/kernel/bridge/`, `lib/ui/player/custom_title_bar.dart`

### Testing (TEST)

- [ ] **TEST-05**: Integration tests for critical user flows
  - File open → playback → seek → pause → next track
  - Volume control, mute toggle, fullscreen toggle
  - Playlist navigation (next/prev, play modes)
  - Settings panel open/close, locale change
  - Platform: Windows desktop (`flutter test integration_test/`)

- [ ] **TEST-06**: Golden tests for glassmorphism components
  - GlassContainer, GlassButton, GlassChip visual snapshots
  - ControlBar, ProgressBar, VolumeControls layout snapshots
  - Custom golden file comparator for cross-machine consistency
  - Store baseline images in `test/golden/`

### Quality (QUAL)

- [ ] **QUAL-01**: Architecture optimization
  - Use Context7 to verify latest Flutter/fvp best practices
  - Identify and apply applicable patterns (ValueNotifier optimization, widget splitting)
  - Ensure 3-layer architecture boundaries are clean

- [ ] **QUAL-02**: Dead code cleanup
  - Remove unused imports, unreachable code, deprecated patterns
  - Remove any leftover from v1.0 refactoring (window_manager remnants, etc.)
  - Verify no runtime references before deletion

- [ ] **QUAL-03**: Code quality maintenance
  - `flutter analyze` stays at 0 errors
  - Maintain 80%+ test coverage through v1.1 changes
  - Add lint rules for common anti-patterns if beneficial

## v2 Requirements (Deferred)

- PLATFORM-02: macOS/Linux platform stubs
- Impeller FragmentShader for BackdropFilter
- HLS/ABR streaming
- Steam/SteamOS distribution
- Triple buffering in fvp C++ layer

## Out of Scope

- New dependencies — use existing Flutter SDK + test packages only
- New features — v1.1 is quality/stability only
- State management migration — ValueNotifier preserved
- Window behavior changes — optimize code structure, not functionality

## Traceability

| Requirement | Phase | Status | Source |
|-------------|-------|--------|--------|
| OPT-01 | TBD | Pending | User request |
| TEST-05 | TBD | Pending | v1.0 deferred |
| TEST-06 | TBD | Pending | v1.0 deferred |
| QUAL-01 | TBD | Pending | User request |
| QUAL-02 | TBD | Pending | User request |
| QUAL-03 | TBD | Pending | User request |

---
*Last updated: 2026-05-29*
