# Phase 6: Settings Completion - Research

**Researched:** 2026-05-14
**Domain:** Flutter settings dialog, video processing persistence, l10n
**Confidence:** HIGH

## Summary

Settings dialog is almost fully implemented. All 3 tabs (equalizer, audio track, video processing) are functional and wired. The settings button in the control bar correctly opens the dialog via `showDialog` in `app.dart:136-142`. Video processing sliders persist via `SettingsStore` with 50ms debounce. The only confirmed bug is a wrong fallback text at `settings_dialog.dart:69` — when `videoProcessing` is null, it shows `l10n.noAudioTracks` ("No audio tracks available") instead of a video-processing-specific message.

This is a small polish phase: fix one l10n bug, verify all 3 tabs work end-to-end. No new features, no architectural changes.

**Primary recommendation:** Fix the one-line l10n fallback bug, add a missing l10n key for "video processing unavailable", verify the full settings flow.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Settings dialog UI | Presentation (Flutter) | -- | Pure widget, no business logic |
| Equalizer presets | Engine (fvp/MDK) | -- | `setEqualizer()` sets FFmpeg `af` filter |
| Audio track selection | Engine (fvp/MDK) | TrackManager | `switchAudioTrack()` delegates to mdk |
| Video processing state | Service | Engine | `VideoProcessingService` holds ValueNotifiers, delegates to engine |
| Video processing persistence | Persistence (shared_preferences) | -- | `SettingsStore` individual save methods |
| L10n strings | L10n layer | -- | `AppLocalizations` + ARB files |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter (SDK) | project constraint | UI framework | Project is a Flutter app |
| shared_preferences | pubspec.lock | Key-value persistence | Already used for all settings |
| fvp | pubspec.lock | MDK/FFmpeg engine | Existing player backend |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_localizations | SDK | L10n infrastructure | Already configured |
| intl | SDK | L10n message formatting | Already used |

**No new dependencies needed.**

## Architecture Patterns

### Settings Dialog Data Flow

```
ControlBar (onSettings callback)
  -> PlayerScreen (passes callback through)
    -> ControlsOverlay (passes callback through)
      -> App.build() showDialog()
        -> SettingsDialog(engine, videoProcessing)
          -> TabBarView
            -> _EqualizerTab: engine.setEqualizer(afFilter)
            -> _AudioTrackTab: engine.switchAudioTrack(i)
            -> VideoProcessingTab(service): ValueNotifiers -> engine
```

### Video Processing Persistence Flow

```
User drags slider
  -> _DebouncedSlider sets ValueNotifier (50ms debounce)
    -> VideoProcessingService listener: engine.setVideoEffect()
    -> VideoProcessingService schedulePersist: SettingsStore.saveVideoXxx()
      -> SharedPreferences (50ms debounce on persist)
```

On app startup:
```
App.initState() -> VideoProcessingService(_engine)
  // NOTE: initialSettings NOT passed in current app.dart:49
  // Service defaults to 0.0/false — persisted values NOT restored on startup
```

### Recommended Project Structure

No changes needed. Files are already well-organized:
```
lib/
├── ui/dialogs/settings_dialog.dart    # SettingsDialog + 2 tabs
├── ui/widgets/video_processing_tab.dart # Video processing tab widget
├── kernel/services/video_processing_service.dart # State + persistence
├── kernel/persistence/settings_store.dart # SharedPreferences persistence
├── l10n/app_localizations*.dart        # L10n strings
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Debounced slider input | Custom Timer logic | Already implemented in `_DebouncedSlider` | 50ms debounce works correctly |
| Settings persistence | Custom JSON/file I/O | `SettingsStore` + `shared_preferences` | Already handles all video processing fields |

## Common Pitfalls

### Pitfall 1: Video Processing Values Not Restored on Startup
**What goes wrong:** `App.initState()` creates `VideoProcessingService(_engine)` without passing `initialSettings` (app.dart:49). The service defaults all values to 0.0/false. Persisted values from previous sessions are ignored.
**Why it happens:** `_init()` loads settings via `SettingsStore.load()` but only uses the result for window geometry, not for video processing restoration.
**How to fix:** Pass `initialSettings` from `SettingsStore.load()` to `VideoProcessingService` constructor.
**Warning signs:** User adjusts sliders, restarts app, sliders reset to zero.

### Pitfall 2: Wrong Fallback Text (CONFIRMED BUG)
**What goes wrong:** `settings_dialog.dart:69` shows `l10n.noAudioTracks` when `videoProcessing` is null. This text says "No audio tracks available" — wrong context for video processing tab.
**Why it happens:** Copy-paste error — the audio track tab uses the same fallback text, and it was reused for video processing.
**How to fix:** Add a new l10n key (e.g., `videoProcessingUnavailable`) and use it at line 71.
**Warning signs:** User sees "No audio tracks available" in the video processing tab.

### Pitfall 3: AppDialog Close Button Hardcoded '关闭'
**What goes wrong:** `app_dialog.dart:52` hardcodes `'关闭'` instead of using l10n. English users see Chinese text.
**Why it happens:** Missing l10n integration in the shared dialog wrapper.
**How to fix:** Use `l10n.close` instead of hardcoded string.
**Warning signs:** English locale shows Chinese close button.

## Code Examples

### Fix: Wrong fallback text (settings_dialog.dart:69-73)

```dart
// BEFORE (bug):
widget.videoProcessing != null
    ? VideoProcessingTab(service: widget.videoProcessing!)
    : Center(
        child: Text(
          l10n.noAudioTracks,  // WRONG: shows audio track message
          style: const TextStyle(color: Tokens.textSecondary),
        ),
      ),

// AFTER (fix):
widget.videoProcessing != null
    ? VideoProcessingTab(service: widget.videoProcessing!)
    : Center(
        child: Text(
          l10n.videoProcessingUnavailable,  // NEW l10n key
          style: const TextStyle(color: Tokens.textSecondary),
        ),
      ),
```

### Fix: Restore video processing from persisted settings (app.dart:49)

```dart
// BEFORE:
_videoProcessing = VideoProcessingService(_engine);

// AFTER (after _init loads settings):
// In _init(), after SettingsStore.load():
final settings = await SettingsStore.load();
_videoProcessing = VideoProcessingService(_engine, initialSettings: settings);
```

Note: This requires restructuring `_init()` to create `_videoProcessing` after settings load, or creating it in `_init()` and using `late final`.

### Fix: AppDialog hardcoded close button (app_dialog.dart:52)

```dart
// BEFORE:
child: const Text(
  '关闭',
  style: TextStyle(color: Tokens.textSecondary),
),

// AFTER:
child: Text(
  AppLocalizations.of(context).close,
  style: const TextStyle(color: Tokens.textSecondary),
),
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No video processing persistence | `SettingsStore` individual save methods with 50ms debounce | Phase 5 | Values persist across sessions |
| No video processing restoration | `VideoProcessingService(initialSettings:)` constructor exists | Phase 5 | But `app.dart` doesn't pass `initialSettings` |

**Gap:** `app.dart:49` creates `VideoProcessingService(_engine)` without `initialSettings` — persisted values are saved but never restored on startup.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Equalizer preset selection is not persisted (acceptable for v1 per requirements) | Equalizer tab | Low — user must re-select preset each session |
| A2 | The `videoProcessing` parameter being null is a valid runtime scenario (not just a code path that's never hit) | Settings dialog | Low — fallback exists but may never trigger in practice |

## Open Questions (RESOLVED)

1. **RESOLVED: Is videoProcessing ever null in practice?** — `App.build()` always passes non-null `_videoProcessing` (app.dart:139). Null path is dead code. Fix the l10n bug anyway for defensive coding.

2. **RESOLVED: Should equalizer preset be persisted?** — Out of scope for v1. Requirement SET-02 says "apply correctly", not "persist". Could be a future enhancement.

## Environment Availability

No external dependencies needed for this phase. All changes are in Dart/Flutter code.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| flutter_test | Widget tests | yes | SDK | -- |
| shared_preferences (mock) | Unit tests | yes | -- | SharedPreferences.setMockInitialValues |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none (default) |
| Quick run command | `flutter test test/kernel/persistence/settings_store_test.dart test/kernel/services/video_processing_service_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SET-01 | Settings button opens dialog | widget | `flutter test` (manual verification needed for showDialog) | partial |
| SET-02 | Equalizer presets apply | unit | Need test for `_EqualizerTab` preset selection | Wave 0 |
| SET-03 | Audio track selection works | unit | Need test for `_AudioTrackTab` track switching | Wave 0 |
| SET-04 | Video processing sliders persist | unit | `flutter test test/kernel/services/video_processing_service_test.dart` | yes |
| SET-05 | Fallback text correct | widget | Need test for SettingsDialog null videoProcessing | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/kernel/persistence/settings_store_test.dart test/kernel/services/video_processing_service_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/ui/dialogs/settings_dialog_test.dart` — covers SET-01, SET-05 (dialog opens, fallback text)
- [ ] `test/ui/widgets/video_processing_tab_test.dart` — covers SET-04 (slider interaction)

## Security Domain

No security concerns for this phase. Settings dialog is local-only UI, no user input sent to external services, no auth/secrets involved.

## Sources

### Primary (HIGH confidence)
- `lib/ui/dialogs/settings_dialog.dart` — direct code inspection
- `lib/ui/widgets/video_processing_tab.dart` — direct code inspection
- `lib/ui/player/control_bar.dart` — direct code inspection
- `lib/kernel/persistence/settings_store.dart` — direct code inspection
- `lib/kernel/services/video_processing_service.dart` — direct code inspection
- `lib/app.dart` — direct code inspection
- `lib/l10n/app_localizations_en.dart` — direct code inspection
- `lib/l10n/app_localizations_zh.dart` — direct code inspection
- `test/kernel/persistence/settings_store_test.dart` — existing test coverage
- `test/kernel/services/video_processing_service_test.dart` — existing test coverage
- `test/helpers/fake_engine.dart` — test infrastructure

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, all existing in project
- Architecture: HIGH — direct code inspection confirms data flow
- Pitfalls: HIGH — bugs confirmed by reading source code

**Research date:** 2026-05-14
**Valid until:** 2026-06-14 (stable — no fast-moving dependencies)
