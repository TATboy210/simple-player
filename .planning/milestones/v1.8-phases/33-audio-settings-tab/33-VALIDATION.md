---
N: 33
phase-slug: audio-settings-tab
date: 2026-07-30
---

# Phase 33 Validation Matrix

## Runtime smoke check

Before combined audio-chain implementation, run the target-Windows fvp smoke check with playable local media:

```bash
D:/flutter/bin/flutter test test/ui/dialogs/settings/audio_filter_runtime_smoke_test.dart --concurrency=1
```

The check submits `pan`, `adelay`, and `dynaudnorm` individually via the existing `setEqualizer(String)` route. A filter that raises an `Exception` is recorded unavailable; later composition excludes that segment and logs a `debugPrint` warning while its deferred UI control and raw persisted value remain available.

## Requirement-to-test map

| Requirement | Behavior | Test file | Automated command |
|-------------|----------|-----------|-------------------|
| AUDIO-01 | Five EQ presets compose exact deterministic filter strings. | `test/kernel/audio/audio_filter_compositor_test.dart` | `D:/flutter/bin/flutter test test/kernel/audio/audio_filter_compositor_test.dart --concurrency=1` |
| AUDIO-02 | Balance bounds and full-left/center/full-right values compose exact `pan` segments. | `test/kernel/audio/audio_filter_compositor_test.dart` | `D:/flutter/bin/flutter test test/kernel/audio/audio_filter_compositor_test.dart --concurrency=1` |
| AUDIO-03 | Audio Delay is bounded to 0..10000ms, zero omits delay, and positive values compose direct per-channel `adelay` values. | `test/kernel/audio/audio_filter_compositor_test.dart` | `D:/flutter/bin/flutter test test/kernel/audio/audio_filter_compositor_test.dart --concurrency=1` |
| AUDIO-04 | Normalization off omits its segment and on appends the exact `dynaudnorm` segment. | `test/kernel/audio/audio_filter_compositor_test.dart` | `D:/flutter/bin/flutter test test/kernel/audio/audio_filter_compositor_test.dart --concurrency=1` |
| AUDIO-05 | Apply and OK route one complete chain through the existing equalizer commit seam. | `test/ui/dialogs/settings/audio_tab_test.dart` | `D:/flutter/bin/flutter test test/ui/dialogs/settings/audio_tab_test.dart --concurrency=1` |
| AUDIO-06 | Preset, sliders, and toggle stage values only; Cancel makes no engine call. | `test/ui/dialogs/settings/audio_tab_test.dart` | `D:/flutter/bin/flutter test test/ui/dialogs/settings/audio_tab_test.dart --concurrency=1` |
| AUDIO-07 | Raw EQ, balance, delay, and normalization values persist and reload with validation. | `test/kernel/persistence/settings_store_audio_test.dart` | `D:/flutter/bin/flutter test test/kernel/persistence/settings_store_audio_test.dart --concurrency=1` |

## Phase gates

```bash
D:/flutter/bin/flutter test test/kernel/audio/audio_filter_compositor_test.dart test/kernel/persistence/settings_store_audio_test.dart test/ui/dialogs/settings/audio_tab_test.dart test/ui/dialogs/settings_tab_content_test.dart test/ui/dialogs/settings_overlay_shell_test.dart --concurrency=1
D:/flutter/bin/flutter test --coverage
genhtml coverage/lcov.info --output-directory coverage/html
D:/flutter/bin/flutter analyze
```

Acceptance requires the smoke check to have target-Windows evidence, all listed automated tests to pass, `coverage/lcov.info` and `coverage/html/index.html` to exist after report generation, and `flutter analyze` to exit 0 with no warnings or errors.
