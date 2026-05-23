# Requirements — Simple Player Flutter Performance Optimization

**Date:** 2026-05-23
**Strategy:** Performance-first ("measure first, fix cheap, refactor clean")

## v1 Requirements

### Rendering Pipeline (PERF)

- [ ] **PERF-01**: Profile title bar frame drops using `flutter run --profile -d windows` + DevTools Timeline to identify root cause (BackdropFilter vs ValueNotifier vs other)
- [ ] **PERF-02**: Apply zero-risk fvp config fixes: `MFT:d3d=11` (eliminate D3D9→D3D11 surface copy), `shader_resource=1` (GPU YUV-to-RGB), `log=warning` (stop debug string formatting)
- [ ] **PERF-03**: Test `d3d11.sync.cpu=0` on target hardware (saves 2-5ms/frame, may cause tearing on Intel iGPU)
- [ ] **PERF-04**: Verify all 6 BackdropFilter usages have ClipRect wrappers; expand resize-aware degradation to playlist_panel.dart and empty_state.dart
- [ ] **PERF-05**: Audit all 35 ValueListenableBuilder instances for `child` parameter usage to cache static subtrees
- [ ] **PERF-06**: Implement MergedListenable for position+duration (halves rebuild count for time display widgets)

### Architecture Cleanup (ARCH)

- [ ] **ARCH-01**: Extract `WindowServiceBase` mixin from WindowService (302 lines) + MacosWindowService (286 lines) + LinuxWindowService (279 lines) — reduce each to 40-60 lines
- [ ] **ARCH-02**: Refactor ThumbnailService from static singleton to instance-based with constructor-injected ThumbnailProvider; replace LRU List+Map with LinkedHashMap O(1)
- [ ] **ARCH-03**: Remove dead code: `lib/models/playlist_item.dart` (26 lines, zero imports)
- [ ] **ARCH-04**: Convert OsdService from static singleton to instance-based (enables testing)

### Testing (TEST)

- [ ] **TEST-01**: Add unit tests for WindowStateService and WindowPersistenceService (already separated, testable)
- [ ] **TEST-02**: Add unit tests for ThumbnailService (after ARCH-02 instance-based refactor)
- [ ] **TEST-03**: Add widget tests for settings panel (SettingsCard 754 lines, deferred-apply pattern)
- [ ] **TEST-04**: Add unit tests for FullscreenController (requires Win32Adapter interface extraction)

## v2 Requirements (Deferred)

- [ ] Triple buffering in fvp C++ layer (requires fvp fork, ~50 lines C++)
- [ ] Fence替代Flush in fvp C++ layer (requires fvp fork, ~15 lines C++)
- [ ] Impeller FragmentShader replacement for BackdropFilter (requires Impeller stable on Windows)
- [ ] Integration tests for critical flows (Flutter desktop integration testing immature)
- [ ] Golden tests for glassmorphism components (GPU-dependent, flaky across machines)
- [ ] PlayerActions record to eliminate callback drilling (15+ VoidCallbacks)
- [ ] SettingsCard split into 3 files (settings_card.dart, setting_row.dart, setting_section.dart)

## Out of Scope

- Cross-platform expansion (macOS/Linux real implementation) — stubs only
- State management migration (Provider/Riverpod/Bloc) — violates ValueNotifier constraint
- Online subtitle search — separate feature
- HLS/ABR streaming — separate project
- Steam/SteamOS distribution — separate project
- HDR/ICC color management, frame interpolation, equalizer UI
- Full macOS/Linux WindowService implementation (3-6 days per platform)

## Traceability

| Requirement | Phase | Research Source |
|-------------|-------|-----------------|
| PERF-01 | Phase 2 | PITFALLS.md #1, SUMMARY.md |
| PERF-02 | Phase 1 | STACK.md, FEATURES.md |
| PERF-03 | Phase 3 | STACK.md, PITFALLS.md #3 |
| PERF-04 | Phase 1/4 | STACK.md, PITFALLS.md #2 |
| PERF-05 | Phase 4 | FEATURES.md, STACK.md |
| PERF-06 | Phase 4 | FEATURES.md |
| ARCH-01 | Phase 5 | ARCHITECTURE.md, CONCERNS.md |
| ARCH-02 | Phase 6 | CONCERNS.md, FEATURES.md |
| ARCH-03 | Phase 1 | CONCERNS.md |
| ARCH-04 | Phase 6 | ARCHITECTURE.md |
| TEST-01 | Phase 6 | ARCHITECTURE.md, CONCERNS.md |
| TEST-02 | Phase 6 | CONCERNS.md |
| TEST-03 | Phase 6 | CONCERNS.md |
| TEST-04 | Phase 6 | ARCHITECTURE.md |

---
*Last updated: 2026-05-23 after research synthesis*
