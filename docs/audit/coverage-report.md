# Coverage Report

**Date:** 2026-07-20
**Data Source:** `coverage/lcov.info` (generated Jul 20 15:51)
**Note:** Fresh `flutter test --coverage` run failed due to C: drive being full (109MB free). Analysis based on existing coverage data.

---

## Summary

| Metric | Value |
|--------|-------|
| **Overall Coverage** | **63.6%** (3888 / 6113 lines) |
| **Target** | 80% |
| **Gap** | -16.4% (~1006 additional lines needed) |
| **Test Files** | 123 |
| **Source Files** | 156 (excluding l10n/generated) |

---

## Module Coverage

| Module | Coverage | Lines Hit/Total | Status |
|--------|----------|-----------------|--------|
| `lib/features/player` | **100.0%** | 38/38 | EXCELLENT |
| `lib/kernel/playlist` | **100.0%** | 128/128 | EXCELLENT |
| `lib/kernel/models` | **94.8%** | 202/213 | EXCELLENT |
| `lib/ui/player` | **93.8%** | 984/1049 | EXCELLENT |
| `lib/kernel/diagnostics` | **88.8%** | 167/188 | GOOD |
| `lib/kernel/persistence` | **88.7%** | 352/397 | GOOD |
| `lib/ui/shared` | **85.9%** | 555/646 | GOOD |
| `lib/l10n/app_localizations` | **82.4%** | 14/17 | GOOD |
| `lib/kernel/startup` | **76.0%** | 38/50 | ADEQUATE |
| `lib/kernel/scanner` | **72.7%** | 16/22 | ADEQUATE |
| `lib/kernel/services` | **72.5%** | 322/444 | ADEQUATE |
| `lib/kernel/adapter` | **57.1%** | 72/126 | BELOW TARGET |
| `lib/kernel/utils` | **47.2%** | 163/345 | BELOW TARGET |
| `lib/l10n/app_localizations_en` | **44.5%** | 85/191 | BELOW TARGET |
| `lib/kernel/bridge` | **30.0%** | 75/250 | CRITICAL |
| `lib/ui/playlist` | **28.9%** | 128/443 | CRITICAL |
| `lib/kernel/engine` | **23.4%** | 199/850 | CRITICAL |
| `lib/l10n/app_localizations_zh` | **0.0%** | 0/191 | CRITICAL |

---

## Files with ZERO Coverage (14 files, 654 lines)

### Engine Layer (4 files, 225 lines) -- CRITICAL
| File | Lines | Priority |
|------|-------|----------|
| `lib/kernel/engine/media_opener.dart` | 85 | P0 - File open logic |
| `lib/kernel/engine/position_poller.dart` | 60 | P0 - Position update timer |
| `lib/kernel/engine/network_configurator.dart` | 40 | P1 - Network buffer config |
| `lib/kernel/engine/track_manager.dart` | 31 | P0 - Audio/subtitle track selection |
| `lib/kernel/engine/mdk_player_proxy.dart` | 9 | P1 - MDK proxy abstraction |

### Bridge Layer (1 file, 62 lines) -- CRITICAL
| File | Lines | Priority |
|------|-------|----------|
| `lib/kernel/bridge/win32/win32_display_enumerator.dart` | 62 | P0 - Multi-monitor support |

### Playlist UI (2 files, 195 lines) -- CRITICAL
| File | Lines | Priority |
|------|-------|----------|
| `lib/ui/playlist/thumbnail_tile.dart` | 124 | P0 - Thumbnail card widget |
| `lib/ui/playlist/history_tab.dart` | 71 | P0 - History tab widget |

### Other (4 files, 92 lines)
| File | Lines | Priority |
|------|-------|----------|
| `lib/kernel/utils/debug_exporter.dart` | 27 | P2 - Debug tool |
| `lib/ui/shared/setting_slider_row.dart` | 41 | P1 - Settings UI |
| `lib/kernel/services/theme_service.dart` | 16 | P2 - Theme service |
| `lib/ui/shared/context_menu_row.dart` | 7 | P2 - Context menu |
| `lib/ui/theme/tokens.dart` | 1 | P3 - Constants only |

### Localization (1 file, 191 lines) -- LOW PRIORITY
| File | Lines | Priority |
|------|-------|----------|
| `lib/l10n/app_localizations_zh.dart` | 191 | P3 - Generated code |

---

## Files with Very Low Coverage (<20%, 7 files, 703 lines)

| File | Coverage | Lines | Priority |
|------|----------|-------|----------|
| `lib/kernel/engine/fvp_engine.dart` | 0.7% | 2/303 | P0 - Core engine |
| `lib/ui/dialogs/settings/video_tab.dart` | 5.3% | 7/131 | P1 - Video settings |
| `lib/ui/playlist/folder_tab.dart` | 7.0% | 8/115 | P0 - Folder tab |
| `lib/kernel/engine/fvp_callback_handler.dart` | 9.1% | 4/44 | P0 - Engine callbacks |
| `lib/kernel/services/linux_thumbnail_provider.dart` | 9.1% | 1/11 | P2 - Linux stub |
| `lib/kernel/engine/video_effect_controller.dart` | 10.5% | 2/19 | P1 - Video effects |
| `lib/kernel/bridge/window_service.dart` | 19.2% | 23/120 | P0 - Window control |

---

## Key Untested Code Paths

### 1. Engine Core (P0) -- ~570 lines uncovered

**`fvp_engine.dart`** (303 lines, 0.7% covered):
- `open()` - Media file loading
- `play()`/`pause()`/`stop()` - Playback control
- `seek()` - Position seeking
- `setVolume()`/`setMuted()` - Audio control
- `setVideoEffect()` - Color/rotation effects
- Event listener setup and teardown
- Error recovery paths

**`position_poller.dart`** (60 lines, 0%):
- Timer-based position polling
- Position change notification

**`track_manager.dart`** (31 lines, 0%):
- Audio track selection
- Subtitle track management

**`media_opener.dart`** (85 lines, 0%):
- File open with engine integration
- Error handling for invalid files

### 2. Window Bridge (P0) -- ~237 lines uncovered

**`window_service.dart`** (120 lines, 19.2%):
- `setFullscreen()`/`exitFullscreen()`
- `maximize()`/`restore()`
- Window position persistence
- Multi-monitor clamping

**`win32_display_enumerator.dart`** (62 lines, 0%):
- `EnumDisplayMonitors` FFI callback
- Monitor bounds calculation

### 3. Playlist UI (P0) -- ~266 lines uncovered

**`thumbnail_tile.dart`** (124 lines, 0%):
- 16:9 thumbnail rendering
- Play state overlay
- Hover/focus effects

**`history_tab.dart`** (71 lines, 0%):
- Timestamp-sorted history list
- Item selection

**`folder_tab.dart`** (115 lines, 7%):
- Folder-grouped thumbnails
- Expand/collapse

### 4. Services Layer (P1) -- ~122 lines uncovered

**`playback_navigator.dart`** (44 lines, 43.2%):
- Track advancement logic
- Shuffle mode

**`auto_advance_policy.dart`** (26 lines, 34.6%):
- Auto-advance decisions

**`theme_service.dart`** (16 lines, 0%):
- Theme switching

---

## 100% Coverage Files (31 files)

These files have complete test coverage and serve as good examples:

| File | Lines | Domain |
|------|-------|--------|
| `kernel/playlist/playlist.dart` | 128 | Playlist model + play mode logic |
| `kernel/models/app_settings.dart` | 76 | Settings data class |
| `kernel/engine/engine_state_machine.dart` | 56 | State transitions |
| `ui/player/auto_hide_controller.dart` | 70 | Auto-hide timer |
| `ui/player/control_bar.dart` | 62 | Bottom bar |
| `ui/player/speed_button.dart` | 56 | Speed selector |
| `ui/shared/osd_overlay.dart` | 47 | OSD pill |
| `kernel/services/video_processing_service.dart` | 77 | Color correction |
| `kernel/models/playlist_item.dart` | 30 | Playlist item |
| `kernel/engine/volume_controller.dart` | 14 | Volume control |

---

## Recommendations

### P0: Critical Coverage Gaps (target: add ~400 lines)

1. **Engine core tests** - Mock `fvp.Player` to test `FvpEngine` state machine:
   - `open()` → state transitions, error handling
   - `play()`/`pause()`/`stop()` → lifecycle
   - `seek()` → boundary clamping
   - `setVolume()`/`setMuted()` → value validation

2. **Position poller tests** - Mock timer, verify position notifications

3. **Window bridge tests** - Mock MethodChannel, verify fullscreen/maximize flow

4. **Playlist UI widget tests** - `ThumbnailTile`, `HistoryTab`, `FolderTab` with mock data

### P1: Important Gaps (target: add ~200 lines)

5. **Video tab settings tests** - Widget tests for EQ/video settings

6. **PlaybackNavigator tests** - Test track advancement with all play modes

7. **Display enumerator tests** - Mock `EnumDisplayMonitors` for multi-monitor

### P2: Nice-to-Have (target: add ~100 lines)

8. **Localization tests** - Verify zh/en string lookups
9. **Debug exporter tests** - Test export format
10. **Theme service tests** - Test theme switching

---

## Estimated Path to 80%

Current: 63.6% (3888/6113)
Target: 80% (4890 lines)
Gap: +1002 lines to cover

| Priority | Files | Est. Lines | New Coverage |
|----------|-------|------------|--------------|
| P0 (engine core) | 5 | ~400 | +6.5% |
| P0 (playlist UI) | 3 | ~200 | +3.3% |
| P0 (window bridge) | 2 | ~150 | +2.5% |
| P1 (services) | 4 | ~150 | +2.5% |
| P2 (misc) | 5 | ~100 | +1.6% |
| **Total** | **19** | **~1000** | **+16.4%** |

**Projected: 80.0%** with ~19 new test files.

---

## Disk Space Issue

C: drive has only 109MB free. `flutter test --coverage` requires ~300MB temp space for compilation. Before running fresh tests:

```bash
# Clean flutter temp
rm -rf C:/Users/35490/AppData/Local/Temp/flutter_tools.*

# Clean pub cache if needed
flutter pub cache clean
```
