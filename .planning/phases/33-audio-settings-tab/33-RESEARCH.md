# Phase 33: Audio Settings Tab — Research

**Researched:** 2026-07-30
**Domain:** FFmpeg audio filter chains via MDK `af` property, deferred-apply settings pattern
**Confidence:** MEDIUM (af property route proven; individual filter availability in fvp's bundled FFmpeg needs runtime verification)

## Summary

Phase 33 fills the Audio settings tab (currently an EQ-only skeleton at tab index 0) with four real audio features — EQ presets, balance, sync, and normalization — all composed into a single MDK `af` filter string and applied through the existing `MediaEngine.setEqualizer(String afFilter)` entry point.

**Key discovery:** The existing codebase already has a proven route for audio filters. `SubtitleConfigurator.setEqualizer(String afFilter)` calls `_player.setProperty('af', afFilter)`, and the old `EqualizerTab` successfully uses `bass=g=N` and `treble=g=N` filter strings. The filter chain is comma-separated: `bass=g=5,treble=g=3,pan=stereo|c0=0.9*c0+0.1*c1|c1=0.1*c0+0.9*c1`. This same mechanism handles all four Phase 33 features.

**Primary recommendation:** Compose all four audio features into a single private `_buildAfString(PendingSettingsState) → String` function. EQ presets use `bass`/`treble`/`equalizer` filters (proven working). Balance uses `pan=stereo|c0=...|c1=...` (FFmpeg standard, but verify in fvp's build). Sync uses `adelay=ms|ms`. Normalization uses `dynaudnorm` (FFmpeg standard). All features flow through the existing deferred-apply `PendingSettingsState` mechanism — slider drag only mutates pending state; `engine.setEqualizer()` fires on OK/Apply; Cancel discards pending with zero engine-state management.

## User Constraints (from ROADMAP.md Phase 33)

### Locked Decisions (PRODUCT decisions固化)
- Pure deferred-apply (AUDIO-06): slider drag updates `PendingSettingsState` ONLY; `engine.setEqualizer()` called on OK/Apply; Cancel discards pending (no engine-state snapshot management)
- Reuse existing `setEqualizer` af entry; `AudioConfig` ISP deferred to v4.6+
- Scope boundary: audio tab only — video/subtitle/playback tabs remain SettingRow placeholders
- Zero kernel interface expansion (reuse `setEqualizer` af entry)
- Zero new dependencies
- `SettingsStore` (SharedPreferences) persists EQ preset / balance / sync / normalization on OK/Apply commit

### Claude's Discretion
- Filter string composition strategy (`_buildAfString` implementation)
- Specific FFmpeg filter choices within the `af` property route
- UI layout of the audio tab within the existing GlassContainer / SettingRow pattern

### Deferred Ideas (OUT OF SCOPE)
- AUDIO-F01: `AudioConfig` ISP interface (deferred to v4.6+)
- AUDIO-F02: 10-band graphical EQ (v4.5 presets only)
- AUDIO-F03: Audio device / output module selector
- AUDIO-F04: Default audio language preference wiring
- AUDIO-F05: Real-time EQ preview + controller snapshot restore

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUDIO-01 | EQ presets (`bass`/`treble`/`equalizer` af filters) | Existing `EqualizerTab` already uses `bass=g=N` syntax — proven working via `setProperty('af', ...)` |
| AUDIO-02 | Balance slider (`pan` filter, UI abstracts -1.0..+1.0 → filter string) | FFmpeg `pan=stereo|c0=L*c0+R*c1|c1=L*c0+R*c1` — map balance value to L/R coefficients |
| AUDIO-03 | Sync slider (`adelay` filter, direction aligned with subtitle delay UX) | FFmpeg `adelay=ms|ms` — positive = audio delayed (matches subtitle delay UX: positive = later) |
| AUDIO-04 | Normalization toggle (`dynaudnorm` filter, default off) | FFmpeg `dynaudnorm` with sensible defaults (framelen=500, targetpeak=0.95) |
| AUDIO-05 | All features flow through existing `MediaEngine.setEqualizer(String afFilter)` | Verified: `setEqualizer` → `SubtitleConfigurator.setEqualizer` → `_player.setProperty('af', afFilter)` |
| AUDIO-06 | Pure deferred-apply (PendingSettingsState ONLY until OK/Apply) | Existing `PendingSettingsState` mechanism: `register`/`update`/`current`/`commit`/`cancel` |
| AUDIO-07 | `SettingsStore` persists EQ/balance/sync/normalization on OK/Apply | Add new keys + `save*`/`load*` methods following existing pattern (sequential write, validated) |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| EQ presets (filter string generation) | UI Layer (AudioTab) | — | Preset selection is pure UI state; filter string is a UI concern |
| Balance slider (pan filter string) | UI Layer (AudioTab) | — | UI abstracts -1.0..+1.0 → filter string |
| Sync slider (adelay filter string) | UI Layer (AudioTab) | Kernel (adelay is a time concept) | UI captures user intent; kernel understands ms delay |
| Normalization toggle (dynaudnorm) | UI Layer (AudioTab) | — | Toggle is pure UI state |
| af string composition (`_buildAfString`) | UI Layer (AudioTab) | — | Composes UI state into engine-facing string |
| af filter application (`setEqualizer`) | Kernel (SubtitleConfigurator) | — | Existing kernel entry, unchanged |
| Persistence (SettingsStore) | Kernel (persistence/) | — | Existing persistence pattern |

## Standard Stack

### Core (already in project — zero new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FFmpeg `bass` filter | Bundled in fvp 0.37.2 | Low-frequency boost/cut (biquad) | Already proven in existing `EqualizerTab` |
| FFmpeg `treble` filter | Bundled in fvp 0.37.2 | High-frequency boost/cut (biquad) | Already proven in existing `EqualizerTab` |
| FFmpeg `equalizer` filter | Bundled in fvp 0.37.2 | Parametric multi-band EQ | Standard FFmpeg audio filter |
| FFmpeg `pan` filter | Bundled in fvp 0.37.2 | Channel mixing / balance | Standard FFmpeg audio filter |
| FFmpeg `adelay` filter | Bundled in fvp 0.37.2 | Per-channel audio delay | Standard FFmpeg audio filter |
| FFmpeg `dynaudnorm` filter | Bundled in fvp 0.37.2 | Dynamic audio normalization | Standard FFmpeg audio filter |
| `shared_preferences` | ^8.0.0 | Key-value persistence | Existing project dependency |

### No new dependencies
All Phase 33 features use existing `setProperty('af', ...)` route + existing `shared_preferences` for persistence. Zero `pubspec.yaml` changes.

## Architecture Patterns

### Pattern 1: Existing `setEqualizer` Pipeline (verified)

**What:** The current audio filter application route from UI to MDK engine.
**When to use:** Every audio feature in Phase 33.
**Flow:**
```
AudioTab → PendingSettingsState → _buildAfString() → MediaEngine.setEqualizer(afString)
  → FvpEngine.setEqualizer(afFilter) → SubtitleConfigurator.setEqualizer(afFilter)
    → _player.setProperty('af', afFilter) → mdk.Player.setProperty('af', ...)
      → FFmpeg audio filter graph reinitialized
```

**Source:** `subtitle_configurator.dart:79-81`
```dart
void setEqualizer(String afFilter) {
  _player.setProperty('af', afFilter);
}
```

### Pattern 2: Deferred-Apply via PendingSettingsState (existing)

**What:** All user modifications go through `PendingSettingsState.update(key, value)`. OK/Apply calls `commit()` which returns the changes map. Cancel calls `cancel()` which discards pending.
**When to use:** All audio tab interactions.
**Source:** `pending_settings.dart`

```dart
// Register on panel open (controller.open()):
pending.register('eqPresetIndex', currentPresetIndex);
pending.register('balance', currentBalance);
pending.register('syncMs', currentSyncMs);
pending.register('normalization', currentNormalization);

// Slider/preset change (in tab):
pending.update('balance', sliderValue);

// On OK/Apply (button bar):
final changes = controller.commitPending();
// → read audio values from changes, compose af string, apply + persist

// On Cancel (button bar):
controller.cancelPending(); // → discards pending, no engine call
```

### Pattern 3: af String Composition (`_buildAfString`)

**What:** Private function that reads audio settings from `PendingSettingsState` and produces a single comma-separated FFmpeg filter chain.
**When to use:** On every OK/Apply commit.
**Recommended filter order:** EQ first (tonal shaping) → balance (spatial) → delay (temporal) → normalization (dynamics).

```dart
String _buildAfString(PendingSettingsState pending) {
  final filters = <String>[];

  // 1. EQ preset (index → filter string)
  final presetIndex = pending.current('eqPresetIndex') as int? ?? 0;
  final eqFilter = _eqPresetFilter(presetIndex);
  if (eqFilter.isNotEmpty) filters.add(eqFilter);

  // 2. Balance (pan filter)
  final balance = (pending.current('balance') as double? ?? 0.0)
      .clamp(-1.0, 1.0);
  if (balance != 0.0) {
    filters.add(_balanceFilter(balance));
  }

  // 3. Sync delay (adelay filter)
  final syncMs = (pending.current('syncMs') as int? ?? 0);
  if (syncMs != 0) {
    final absMs = syncMs.abs();
    filters.add('adelay=$absMs|$absMs');
  }

  // 4. Normalization (dynaudnorm filter)
  final normEnabled = pending.current('normalization') as bool? ?? false;
  if (normEnabled) {
    filters.add('dynaudnorm=f=500:g=15:p=0.95');
  }

  return filters.join(',');
}
```

### Pattern 4: EQ Preset Table (extend existing)

The existing `EqualizerTab` has 5 presets (off, bass boost, vocal boost, rock, classical). Phase 33 extends this with the same format, referenced by index.

```dart
/// EQ preset → FFmpeg filter string mapping.
/// Gain range: -20dB to +20dB. Index 0 = off (empty string).
static const List<EqPreset> eqPresets = [
  EqPreset('off', ''),
  EqPreset('bass_boost', 'bass=g=10'),
  EqPreset('vocal_boost', 'treble=g=5'),
  EqPreset('rock', 'bass=g=8,treble=g=6'),
  EqPreset('classical', 'bass=g=3,treble=g=4'),
];
```

### Anti-Patterns to Avoid

- **Do NOT call `engine.setEqualizer()` on every slider change.** This is the "live preview" anti-pattern explicitly forbidden by AUDIO-06. Only call on OK/Apply.
- **Do NOT build a new kernel interface for audio.** The existing `setEqualizer(String afFilter)` is the single entry point. Do not create `setBalance()`, `setSync()`, `setNormalization()` — compose everything into the af string.
- **Do NOT store the composed af string in SettingsStore.** Store the raw user values (preset index, balance, sync ms, normalization bool). Recompose the af string at apply time. This keeps persistence human-readable and debuggable.
- **Do NOT use `audio.avfilter` property name.** The existing code uses `'af'` which already works. Changing to `'audio.avfilter'` risks regressions with no benefit.
- **Do NOT modify `SubtitleConfigurator` or `SubtitleConfig`.** The interface and implementation are unchanged — we only call the existing `setEqualizer` method differently.

## MDK/FFmpeg Audio Filter Syntax Reference

### Property Name

The existing code uses `'af'` as the property key (via `setProperty('af', afFilter)`). This works and is proven. MDK also documents `'audio.avfilter'` as the formal property name, but since `'af'` is already functional, Phase 33 must use `'af'` for consistency.

### Filter Chain Syntax

Multiple filters are chained with commas (FFmpeg libavfilter simple filtergraph):
```
filter1=params,filter2=params,filter3=params
```

An empty string `''` disables all filters (audio passthrough).

### Filter Reference

#### `bass` / `treble` (proven working)

```
bass=g=<gain_dB>          # e.g., bass=g=10 (boost 10dB at ~100Hz)
treble=g=<gain_dB>        # e.g., treble=g=5 (boost 5dB at ~10kHz)
```

Additional parameters: `f` (frequency), `w` (width), `t` (type: h/o/q/s/k).

#### `equalizer` (proven working)

```
equalizer=f=<freq>:width_type=<h|o|q|k>:width=<val>:g=<gain_dB>
```

Example: `equalizer=f=1000:width_type=o:width=2:g=-10` (cut 1kHz by 10dB, Q=2).

#### `pan` (balance — needs runtime verification)

```
pan=stereo|c0=<left_mix>|c1=<right_mix>
```

For balance abstraction (UI: -1.0 = full left, 0.0 = center, +1.0 = full right):
```
# balance = -0.3 (slightly left):
pan=stereo|c0=1.0*c0+0.0*c1|c1=0.3*c0+0.7*c1

# General formula (balance b in -1.0..+1.0):
left_gain = max(0, 1.0 - b)
right_gain = max(0, 1.0 + b)
pan=stereo|c0=${left_gain}*c0|c1=${right_gain}*c1
```

**WARNING:** The `pan` filter forces stereo output layout. For stereo sources this is correct. For mono or surround sources, the behavior needs testing. Mitigation: catch exceptions from `setEqualizer` and log a warning.

#### `adelay` (sync — needs runtime verification)

```
adelay=<delay_ms>|<delay_ms>   # e.g., adelay=200|200 (delay both channels by 200ms)
```

Positive value = audio is delayed relative to video (matches subtitle delay UX: positive = later).

**Direction convention:** The subtitle delay uses positive = delay (appear later). AUDIO-03 says "direction aligned with subtitle delay UX". So the sync slider should use: positive slider value → `adelay` with positive ms → audio is delayed.

#### `dynaudnorm` (normalization — needs runtime verification)

```
dynaudnorm=f=<framelen>:g=<gauss>:p=<peak>
```

Recommended defaults: `dynaudnorm=f=500:g=15:p=0.95`
- `f=500`: frame length 500ms (smooth gain changes)
- `g=15`: Gaussian filter window size 15 (smooth temporal response)
- `p=0.95`: target peak 0.95 (slightly below full scale to avoid clipping)

When disabled (toggle off), simply omit `dynaudnorm` from the filter chain.

### Example Composed Filter Strings

```
# All features active: EQ rock + balance 0.3 right + 200ms delay + normalization
bass=g=8,treble=g=6,pan=stereo|c0=0.7*c0|c1=1.0*c1,adelay=200|200,dynaudnorm=f=500:g=15:p=0.95

# Only EQ: bass boost
bass=g=10

# Only balance: center (no filter needed — empty string)
''

# Only sync: 500ms delay
adelay=500|500

# Only normalization
dynaudnorm=f=500:g=15:p=0.95

# All off (passthrough)
''
```

## Existing API Analysis

### MediaEngine.setEqualizer(String afFilter)

**Location:** `fvp_engine.dart:908-911`
```dart
void setEqualizer(String afFilter) {
  _guardedAction('setEqualizer', () {
    _subtitleConfigurator.setEqualizer(afFilter);
  });
}
```

**Interface:** `SubtitleConfig.setEqualizer(String preset)` — defined in `subtitle_config.dart:50`
**Implementation:** `SubtitleConfigurator.setEqualizer(String afFilter)` → `_player.setProperty('af', afFilter)` — in `subtitle_configurator.dart:79-81`

**Format expected:** A raw FFmpeg filter chain string (e.g., `bass=g=10`, `bass=g=8,treble=g=6`). Empty string `''` disables filters.

**Key observation:** The interface is already generic — it accepts any af filter string, not just EQ presets. Phase 33 leverages this generality without any kernel change.

### SettingsStore Persistence

**Location:** `settings_store.dart`

**Pattern for adding new settings:**
1. Add `_key*` constant (e.g., `static const _keyEqPresetIndex = 'eqPresetIndex';`)
2. Add `save*` static method using `_save` helper (sequential write, try-catch)
3. Add `load*` static method with safe default on exception
4. Add validation constants to `SettingsValidator`

**New keys needed for Phase 33:**

| Key | Type | Default | Validator |
|-----|------|---------|-----------|
| `eqPresetIndex` | int | 0 (off) | `clamp(0, 4)` — matches 5 presets |
| `balance` | double | 0.0 | `clamp(-1.0, 1.0)` |
| `syncMs` | int | 0 | `clamp(-10000, 10000)` — ±10s range |
| `normalization` | bool | false | N/A |

### PendingSettingsState

**Location:** `pending_settings.dart`

**API:** `register(key, originalValue)` / `update(key, value)` / `current(key)` / `commit()` / `cancel()`

**Current registrations in `SettingsPanelController.open()`:**
- `'locale'` → `'zh'`
- `'themeIndex'` → `0`

**New registrations needed:**
- `'eqPresetIndex'` → current value from SettingsStore
- `'balance'` → current value from SettingsStore
- `'syncMs'` → current value from SettingsStore
- `'normalization'` → current value from SettingsStore

### Commit Flow (current vs Phase 33)

**Current flow (settings_overlay_shell.dart button bar):**
```dart
// Apply:
_controller.commitPending();  // Returns changes map, but return value unused

// OK:
_controller.commitPending();
_controller.close();

// Cancel:
_controller.cancelPending();
_controller.close();
```

**Phase 33 requirement:** After `commitPending()`, read audio settings from the returned changes map, compose the af string, call `engine.setEqualizer()`, and persist to `SettingsStore`.

**Integration approach:** The commit flow needs to be extended. Two options:

**Option A (recommended):** Inject an `AudioSettingsCommitHandler` callback/interface into `SettingsPanelController`. On commit, the controller calls this handler with the pending audio values. The handler composes the af string, calls `engine.setEqualizer()`, and persists.

```dart
// In settings_panel_controller.dart:
typedef AudioCommitCallback = void Function(Map<String, dynamic> audioChanges);
AudioCommitCallback? _onAudioCommit;
void setAudioCommitCallback(AudioCommitCallback cb) => _onAudioCommit = cb;

// In commitPending():
Map<String, dynamic> commitPending() {
  final changes = pending.commit();
  _onAudioCommit?.call(changes);  // Fire audio commit
  return changes;
}
```

**Option B:** Extend the button bar's `onTap` to read audio-specific keys from the commit result and apply them directly.

Option A is cleaner because it separates the audio commit logic from the UI layer. The callback is registered in the composition root (e.g., `app.dart` or `PlayerServices`).

### Current Tab Structure

Tab index 0 is `EqualizerTab` (old live-apply preset selector). Tab index 1 is `AudioTab` (audio output device, auto-select track, default volume — all dummy values).

**Phase 33 replaces tab 0** with a combined audio settings tab that includes:
- EQ presets (replacing old EqualizerTab)
- Balance slider (new)
- Sync slider (new)
- Normalization toggle (new)

Tab 1 (AudioTab) remains unchanged in Phase 33 (scope boundary).

### SettingSliderRow Widget

**Location:** `setting_slider_row.dart`

The existing `SettingSliderRow` takes a `ValueNotifier<double>` for its value source. For Phase 33's deferred-apply pattern, sliders should NOT use a ValueNotifier that drives engine calls. Instead, use local `StatefulWidget` state that writes to `PendingSettingsState.update()`.

**Recommendation:** Create a `PendingSliderRow` variant (or inline Slider widgets) that read from `pending.current(key)` and write to `pending.update(key, value)` — no ValueNotifier, no live engine call.

## Filter Availability Risk Assessment

| Filter | FFmpeg Upstream | fvp Bundled | Risk | Mitigation |
|--------|----------------|-------------|------|------------|
| `bass` | ✓ (af_biquads.c) | ✓ (proven in existing EQ) | NONE | Already working |
| `treble` | ✓ (af_biquads.c) | ✓ (proven in existing EQ) | NONE | Already working |
| `equalizer` | ✓ (af_biquads.c) | ✓ (proven in existing EQ) | NONE | Already working |
| `pan` | ✓ (af_pan.c) | **MEDIUM** — not yet tested in fvp | Try/catch + log warning. Fallback: use `balance` filter (simpler, same FFmpeg module) |
| `adelay` | ✓ (af_adelay.c) | **MEDIUM** — not yet tested in fvp | Try/catch + log warning. Fallback: disable sync silently |
| `dynaudnorm` | ✓ (af_dynaudnorm.c) | **MEDIUM** — not yet tested in fvp | Try/catch + log warning. Fallback: disable normalization silently |

**Runtime verification plan:** Create a small test that calls `setEqualizer` with each filter type individually and check for exceptions or no-op behavior. Run on the target Windows machine with the fvp 0.37.2 bundle.

**Fallback strategy:** If a filter is unavailable, the composed af string should omit that filter and log a `debugPrint` warning. The UI should still show the controls (user can set values), but the apply function silently skips unavailable filters.

## Common Pitfalls

### Pitfall 1: Calling setEqualizer During Slider Drag

**What goes wrong:** Calling `engine.setEqualizer()` on every `Slider.onChanged` causes audio filter graph reinitialization ~60 times per second during drag, producing audible clicks/pops and CPU spikes.

**Why it happens:** The old `EqualizerTab` calls `engine.setEqualizer()` directly on preset tap (single event), but a slider generates continuous events.

**How to avoid:** Strictly follow AUDIO-06: slider drag ONLY updates `PendingSettingsState`. The engine call happens exactly once on OK/Apply.

**Warning signs:** Audio glitches during slider manipulation, MDK logs showing rapid filter graph rebuilds.

### Pitfall 2: pan Filter Breaking Non-Stereo Sources

**What goes wrong:** The `pan=stereo|...` filter forces stereo output. If the audio source is mono or 5.1 surround, the output may be incorrect (downmixed/upmixed unexpectedly).

**Why it happens:** The `pan` filter's output layout is fixed by the first argument (`stereo`).

**How to avoid:** Wrap `pan` filter application in try/catch. For Phase 33, accept this limitation — most desktop player audio content is stereo. Document the limitation. Future enhancement: detect channel count and adjust the pan expression.

**Warning signs:** Distorted audio when playing mono or surround content with non-zero balance.

### Pitfall 3: SettingsStore Key Collisions with Future Phases

**What goes wrong:** Phase 33 adds `eqPresetIndex`, `balance`, `syncMs`, `normalization` keys. Future phases (v4.6+ AudioConfig ISP) might want the same concepts with different semantics.

**Why it happens:** Incremental development without forward planning.

**How to avoid:** Use a clear naming convention: prefix with `audio_` (e.g., `audioEqPreset`, `audioBalance`, `audioSyncMs`, `audioNormalization`) to namespace these settings under the audio domain.

**Warning signs:** Key name collisions in `SettingsStore.load()` or `exportSettings()`.

### Pitfall 4: af String Order Matters

**What goes wrong:** Different filter orderings produce different audio results. For example, `dynaudnorm,bass` normalizes first then boosts bass (potentially clipping), while `bass,dynaudnorm` boosts bass first then normalizes (safer).

**Why it happens:** FFmpeg filter chains are sequential — each filter processes the output of the previous one.

**How to avoid:** Use a fixed, documented order: **EQ → balance → delay → normalization**. This order makes musical sense: shape tone first, position in stereo field, adjust timing, then normalize dynamics.

**Warning signs:** Clipping/distortion when EQ boost + normalization are both active.

### Pitfall 5: Balance at Zero Should Produce Empty String

**What goes wrong:** If balance is 0.0 but the composition function still generates a `pan` filter, the audio passes through an unnecessary filter (wasted CPU, potential subtle coloration).

**Why it happens:** Not checking for identity values before adding filters.

**How to avoid:** Skip each filter when its value is at the identity/default: EQ preset 0 (off), balance 0.0, sync 0ms, normalization false.

## Code Examples

### EQ Preset Selection (deferred-apply)

```dart
// In AudioTab — EQ preset radio buttons
SettingRow(
  title: 'Bass Boost',
  control: Icon(
    pending.current('eqPresetIndex') == 1
        ? Icons.radio_button_checked
        : Icons.radio_button_unchecked,
    color: pending.current('eqPresetIndex') == 1
        ? Tokens.accent
        : Tokens.textDisabled,
  ),
  onTap: () => pending.update('eqPresetIndex', 1),
),
```

### Balance Slider (deferred-apply)

```dart
// In AudioTab — balance slider
// UI: -1.0 (full left) ←——— 0.0 (center) ———→ +1.0 (full right)
SettingRow(
  title: 'Balance',
  description: 'Left/Right audio balance',
  control: SizedBox(
    width: 160,
    child: Slider(
      value: (pending.current('balance') as double?) ?? 0.0,
      min: -1.0,
      max: 1.0,
      onChanged: (v) => pending.update('balance', v),
      activeColor: Tokens.accent,
      inactiveColor: Tokens.bgHover,
    ),
  ),
),
```

### Sync Slider (deferred-apply)

```dart
// In AudioTab — sync slider
// Direction: positive = audio delayed (aligned with subtitle delay UX)
// Range: -10000ms to +10000ms (±10 seconds)
SettingRow(
  title: 'Audio Sync',
  description: 'Audio delay relative to video',
  control: SizedBox(
    width: 160,
    child: Slider(
      value: ((pending.current('syncMs') as int?) ?? 0).toDouble(),
      min: -10000.0,
      max: 10000.0,
      onChanged: (v) => pending.update('syncMs', v.round()),
      activeColor: Tokens.accent,
      inactiveColor: Tokens.bgHover,
    ),
  ),
),
```

### Normalization Toggle (deferred-apply)

```dart
// In AudioTab — normalization toggle
SettingRow(
  title: 'Volume Normalization',
  description: 'Dynamic range compression (dynaudnorm)',
  control: Switch(
    value: (pending.current('normalization') as bool?) ?? false,
    onChanged: (v) => pending.update('normalization', v),
    activeThumbColor: Tokens.accent,
  ),
),
```

### Balance → pan Filter Mapping

```dart
/// Converts balance value (-1.0..+1.0) to FFmpeg pan filter string.
///
/// balance = -1.0 → full left (right channel silenced)
/// balance =  0.0 → center (no filter, return empty string)
/// balance = +1.0 → full right (left channel silenced)
String _balanceFilter(double balance) {
  if (balance == 0.0) return '';
  final b = balance.clamp(-1.0, 1.0);
  final leftGain = (1.0 - b).clamp(0.0, 1.0);
  final rightGain = (1.0 + b).clamp(0.0, 1.0);
  return 'pan=stereo|c0=${leftGain.toStringAsFixed(2)}*c0|c1=${rightGain.toStringAsFixed(2)}*c1';
}
```

### SettingsStore Persistence (new methods)

```dart
// In settings_store.dart — new keys and methods

static const _keyEqPresetIndex = 'audioEqPreset';
static const _keyBalance = 'audioBalance';
static const _keySyncMs = 'audioSyncMs';
static const _keyNormalization = 'audioNormalization';

// Load (with safe defaults)
static Future<int> loadAudioEqPreset() async { ... }   // default: 0
static Future<double> loadAudioBalance() async { ... } // default: 0.0
static Future<int> loadAudioSyncMs() async { ... }     // default: 0
static Future<bool> loadAudioNormalization() async { ... } // default: false

// Save (sequential write, validated)
static Future<void> saveAudioEqPreset(int index) async { ... }
static Future<void> saveAudioBalance(double value) async { ... }
static Future<void> saveAudioSyncMs(int ms) async { ... }
static Future<void> saveAudioNormalization(bool enabled) async { ... }
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Live-apply EQ (old `EqualizerTab` calls `setEqualizer` on each tap) | Deferred-apply (PendingSettingsState → compose on commit) | Phase 33 | Eliminates audio glitches from rapid filter changes |
| Single EQ preset string | Composed multi-filter af chain | Phase 33 | All audio features share one entry point |
| No audio settings persistence | SharedPreferences persistence for all 4 audio features | Phase 33 | User preferences survive app restart |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `pan` filter is available in fvp 0.37.2's bundled FFmpeg | MDK/FFmpeg Syntax | Balance feature silently fails; fallback to omit filter |
| A2 | `adelay` filter is available in fvp 0.37.2's bundled FFmpeg | MDK/FFmpeg Syntax | Sync feature silently fails; fallback to omit filter |
| A3 | `dynaudnorm` filter is available in fvp 0.37.2's bundled FFmpeg | MDK/FFmpeg Syntax | Normalization feature silently fails; fallback to omit filter |
| A4 | The `'af'` property name accepts multi-filter comma chains (not just single filters) | Existing API Analysis | Only one filter can be active at a time; features would need separate property routes |
| A5 | `pan` filter's pipe (`|`) syntax does not conflict with MDK's property parsing | MDK/FFmpeg Syntax | Pan filter string gets mangled; need to test actual behavior |
| A6 | `SettingsPanelController` can be extended with an audio commit callback without breaking existing tests | Commit Flow | Existing settings tests need updates; additional coordination |

## Open Questions (RESOLVED)

### Q1: Filter availability in fvp's FFmpeg build ✅ RESOLVED
- **What:** Whether `pan`, `adelay`, `dynaudnorm` are compiled into fvp 0.37.2's bundled FFmpeg.
- **Decision:** Wave 0 (Plan 33-01 Task 1) runs individual smoke checks on target Windows before combined-chain use. Each filter whose `setEqualizer` call throws is marked unavailable.
- **Fallback policy:** An unavailable segment is omitted from the composed af chain + emits `debugPrint` warning. However, because AUDIO-02/03/04 require real functional filters, if ANY of pan, adelay, or dynaudnorm is unavailable on target runtime, Phase 33 MUST NOT be declared complete until an equivalent supported route is identified, implemented, and tested. Partial feature omission is not an acceptable final state. This makes filter support a strict delivery gate.
- **Verification:** Runtime smoke test in `test/ui/dialogs/settings/audio_filter_runtime_smoke_test.dart`.

### Q2: Commit flow integration method ✅ RESOLVED
- **What:** How to wire the audio commit handler into the existing button bar without breaking locale/theme logic.
- **Decision:** Adopt Option A — inject a typed `AudioCommitCallback?` into `SettingsPanelController`. `PlayerFeature` registers the callback at the manual composition root (app.dart / PlayerServices). On `commitPending()`, the controller builds an `AudioSettings` snapshot from committed-or-current values and invokes the callback exactly once per Apply/OK.
- **Scope boundary:** Only `settings_panel_controller.dart` and `player_feature.dart` receive new seams; `SubtitleConfigurator`, `MediaEngine`, and `SubtitleConfig` remain untouched.
- **Verification:** Plan 33-01 Task 2 acceptance criteria.

### Q3: Which EqualizerTab is rendered ✅ RESOLVED
- **What:** Two `equalizer_tab.dart` files exist — one at project-root settings dir (old live-apply), one in `tabs/` (Phase 32 skeleton).
- **Decision:** `tab_content.dart` imports from `tabs/equalizer_tab.dart`. Phase 33 replaces THAT file with the combined AudioTab (EQ presets replacing the skeleton). The legacy root-level file is dead code and is not touched.
- **Verification:** Plan 33-01 Task 2 acceptance criteria: "root-level legacy equalizer tab remains untouched."

## Security Domain

No security implications. Audio filters are applied locally to media playback. No user input leaves the application. No authentication, authorization, or data transmission involved.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | None (default) |
| Quick run command | `flutter test test/ui/dialogs/settings/ --concurrency=1` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| AUDIO-01 | EQ presets produce correct filter strings | Unit | `flutter test test/kernel/audio/audio_filter_compositor_test.dart` |
| AUDIO-02 | Balance -1.0..+1.0 maps to correct pan filter | Unit | `flutter test test/kernel/audio/audio_filter_compositor_test.dart` |
| AUDIO-03 | Sync ms maps to correct adelay filter | Unit | `flutter test test/kernel/audio/audio_filter_compositor_test.dart` |
| AUDIO-04 | Normalization toggle adds/omits dynaudnorm | Unit | `flutter test test/kernel/audio/audio_filter_compositor_test.dart` |
| AUDIO-05 | All features route through setEqualizer | Widget | `flutter test test/ui/dialogs/settings/audio_tab_test.dart` |
| AUDIO-06 | Slider drag does NOT call setEqualizer | Widget | `flutter test test/ui/dialogs/settings/audio_tab_test.dart` |
| AUDIO-07 | SettingsStore persists/loads audio values | Unit | `flutter test test/kernel/persistence/settings_store_audio_test.dart` |

### Wave 0 Gaps

- [ ] `test/kernel/audio/audio_filter_compositor_test.dart` — covers AUDIO-01 through AUDIO-04 (pure function tests)
- [ ] `test/ui/dialogs/settings/audio_tab_test.dart` — covers AUDIO-05, AUDIO-06 (widget tests)
- [ ] `test/kernel/persistence/settings_store_audio_test.dart` — covers AUDIO-07

## Environment Availability

Step 2.6: SKIPPED — no external dependencies beyond existing fvp/FFmpeg bundle and shared_preferences. All filters are internal to the bundled FFmpeg library.

## Sources

### Primary (HIGH confidence)
- `subtitle_configurator.dart:79-81` — setEqualizer implementation via `setProperty('af', ...)`
- `equalizer_tab.dart` (old) — Proven `bass=g=N`, `treble=g=N` syntax working
- `fvp_engine.dart:908-911` — setEqualizer delegation to SubtitleConfigurator
- `pending_settings.dart` — PendingSettingsState API (register/update/current/commit/cancel)
- `settings_store.dart` — Persistence pattern (key constants, save/load methods, _saveImpl)
- `settings_overlay_shell.dart:362-403` — Button bar commit flow

### Secondary (MEDIUM confidence)
- [MDK SDK Wiki - Player APIs](https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs) — `audio.avfilter` property documentation
- [MDK SDK Changelog](https://github.com/wang-bin/mdk-sdk/blob/master/Changelog.md) — Confirms `audio.avfilter` support and bug fixes
- [FFmpeg Filters Documentation](https://ffmpeg.org/ffmpeg-filters.html) — pan, adelay, dynaudnorm, bass, treble, equalizer filter syntax
- [FFmpeg AudioChannelManipulation](https://trac.ffmpeg.org/wiki/AudioChannelManipulation) — pan filter examples
- `.planning/research/02-features.md:33` — Feature landscape confirms `af=pan` route for balance
- [FFmpeg dynaudnorm docs](https://ayosec.github.io/ffmpeg-filters-docs/8.0/Filters/Audio/dynaudnorm.html) — dynaudnorm parameters

### Tertiary (LOW confidence)
- Filter availability in fvp's specific FFmpeg build (bass/treble proven; pan/adelay/dynaudnorm unverified)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, all using existing infrastructure
- Architecture: HIGH — follows established patterns (PendingSettingsState, setEqualizer, SettingsStore)
- Filter syntax: MEDIUM — FFmpeg upstream syntax is well-documented, but fvp's bundled build needs runtime verification for pan/adelay/dynaudnorm
- Commit flow integration: MEDIUM — the wiring pattern is clear, but requires extending the controller without breaking existing tests

**Research date:** 2026-07-30
**Valid until:** 2026-08-30 (stable codebase, no version upgrades planned)
