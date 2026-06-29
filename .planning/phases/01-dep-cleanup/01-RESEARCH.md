# Phase 1: 依赖清理 - Technical Research

**Researched:** 2026-06-29
**Domain:** Dart/Flutter dependency management, import path migration
**Confidence:** HIGH

## Summary

Phase 1 is a mechanical migration: remove the external `player_engine` path dependency from `pubspec.yaml` and rewrite all `package:player_engine/player_engine.dart` imports to local relative paths. The operation is well-understood, low-risk, and fully automatable with find-and-replace.

The key discovery is that CONTEXT.md and REQUIREMENTS.md significantly undercount the affected files. The actual count is **56 source files** (34 lib + 22 test), not the claimed 25+20=45 or 37. This must be corrected before planning.

**Primary recommendation:** Execute as a single atomic operation: replace all 56 imports first, then remove the pubspec entry, then verify.

## Current State Analysis

### pubspec.yaml Dependency

```yaml
# Line 14-15 of pubspec.yaml
player_engine:
  path: ../widget_tree_flutter/player_engine
```

This is the sole external path dependency. Removing it makes the project self-contained.

### Local Barrel File

`lib/kernel/engine/player_engine.dart` exports 8 symbols:

| Export | Symbol |
|--------|--------|
| `media_error_type.dart` | `MediaErrorType` enum |
| `media_state.dart` | `MediaState` enum |
| `models/audio_track_info.dart` | `AudioTrackInfo` class |
| `models/media_info.dart` | `MediaInfo` class |
| `models/subtitle_track_info.dart` | `SubtitleTrackInfo` class |
| `models/video_codec_info.dart` | `VideoCodecInfo` class |
| `player_engine_base.dart` | `PlayerEngine` abstract class |
| `video_effect_type.dart` | `VideoEffectType` enum |

### External Barrel Comparison (D-07)

`../widget_tree_flutter/player_engine/lib/player_engine.dart` exports the same 8 symbols from `src/` subdirectories. **Exact match** — no missing symbols, no extra symbols. D-08 (补遗漏) is not needed.

### Import Pattern

All 56 files use the identical import statement:
```dart
import 'package:player_engine/player_engine.dart';
```

No selective imports (`import 'package:player_engine/x.dart'`) exist anywhere. Migration is a single find-and-replace operation.

### Corrected File Counts

| Category | CONTEXT.md Claims | Actual Count | Delta |
|----------|-------------------|--------------|-------|
| lib/ source files | 25 | **34** | +9 |
| test/ files | 20 | **22** | +2 |
| **Total source** | **45** | **56** | **+11** |
| Engine internal (barrel import) | 7 | **7** | 0 |
| Planning/docs references | 19 | **25** (8 files, 25 occurrences) | +6 |

**Correction required:** DEP-02 says "37 files" — actual is 56 source files. REQUIREMENTS.md, CONTEXT.md, and ROADMAP.md all have wrong numbers.

### Engine Internal Files (D-09/D-10)

7 engine internal files currently import the barrel. After migration they switch to direct file imports:

| File | Types Used from Barrel | Direct Import Needed |
|------|----------------------|---------------------|
| `fvp_callback_handler.dart` | `MediaState` | `import 'media_state.dart';` |
| `fvp_engine.dart` | `MediaState`, `MediaErrorType`, `PlayerEngine` (extends) | `import 'media_state.dart'; import 'media_error_type.dart'; import 'player_engine_base.dart';` |
| `media_opener.dart` | `MediaErrorType` | `import 'media_error_type.dart';` |
| `mock_engine.dart` | `MediaState`, `MediaErrorType`, `MediaInfo`, `PlayerEngine` (implements) | `import 'media_state.dart'; import 'media_error_type.dart'; import 'models/media_info.dart'; import 'player_engine_base.dart';` |
| `open_result.dart` | `MediaInfo`, `MediaErrorType` | `import 'models/media_info.dart'; import 'media_error_type.dart';` |
| `track_manager.dart` | `MediaInfo`, `AudioTrackInfo`, `SubtitleTrackInfo` | `import 'models/media_info.dart'; import 'models/audio_track_info.dart'; import 'models/subtitle_track_info.dart';` |
| `video_effect_controller.dart` | `VideoEffectType` | `import 'video_effect_type.dart';` |

### Engine Files NOT Using Barrel (no migration needed)

5 engine files do NOT import the barrel — they only use `fvp/mdk.dart` and local utils:

| File | Imports |
|------|---------|
| `position_poller.dart` | `dart:async`, `flutter/foundation.dart`, `fvp/mdk.dart`, local utils |
| `engine_prewarm.dart` | `flutter/foundation.dart`, `fvp/mdk.dart`, local utils |
| `d3d11_configurator.dart` | `fvp/mdk.dart`, local utils |
| `network_configurator.dart` | `fvp/mdk.dart`, local utils |
| `subtitle_configurator.dart` | `flutter/foundation.dart`, `fvp/mdk.dart`, local utils |
| `volume_controller.dart` | `flutter/foundation.dart`, `fvp/mdk.dart`, local utils |

### Planning/Docs References (D-05)

8 files reference `package:player_engine` and need updating:

| File | Occurrences | What to Update |
|------|-------------|----------------|
| `.planning/PROJECT.md` | 2 | Update architecture description |
| `.planning/REQUIREMENTS.md` | 1 | Fix file count (37 → 56) |
| `.planning/ROADMAP.md` | 1 | Success criteria text |
| `.planning/codebase/CONVENTIONS.md` | 1 | Import example |
| `.planning/research/STACK.md` | 6 | Migration instructions and counts |
| `.planning/research/PITFALLS.md` | 7 | Pitfall examples and table |
| `.planning/research/ARCHITECTURE.md` | 3 | Architecture description |
| `.planning/phases/01-dep-cleanup/01-DISCUSSION-LOG.md` | 4 | Discussion log (read-only, may skip) |

## Architecture Patterns

### Migration Strategy (D-01 through D-12 Validated)

The migration is a two-layer operation:

**Layer 1 — External consumers (49 files):** `lib/` (27 non-engine) + `test/` (22) files that import `package:player_engine/player_engine.dart` get rewritten to relative paths from their location to `lib/kernel/engine/player_engine.dart`.

**Layer 2 — Engine internal (7 files):** Engine files that currently import the barrel switch to direct file imports per the mapping above (D-09).

**Deletion — pubspec.yaml:** Remove the `player_engine` path entry (D-02).

### Relative Path Calculation

From each file's location, compute the relative path to `lib/kernel/engine/player_engine.dart`:

| Source Location | Relative Path |
|----------------|---------------|
| `lib/app.dart` | `kernel/engine/player_engine.dart` |
| `lib/ui/player/*.dart` | `../../kernel/engine/player_engine.dart` |
| `lib/ui/dialogs/*.dart` | `../../kernel/engine/player_engine.dart` |
| `lib/ui/dialogs/settings/*.dart` | `../../../kernel/engine/player_engine.dart` |
| `lib/ui/shared/*.dart` | `../../kernel/engine/player_engine.dart` |
| `lib/features/player/*.dart` | `../../kernel/engine/player_engine.dart` |
| `lib/features/player/services/*.dart` | `../../../kernel/engine/player_engine.dart` |
| `test/helpers/*.dart` | `../../lib/kernel/engine/player_engine.dart` |
| `test/widget/player/*.dart` | `../../../lib/kernel/engine/player_engine.dart` |
| `test/widget/shared/*.dart` | `../../../lib/kernel/engine/player_engine.dart` |
| `test/kernel/**/*.dart` | varies by depth |
| `test/debug/*.dart` | `../../lib/kernel/engine/player_engine.dart` |
| `test/golden/*.dart` | `../../lib/kernel/engine/player_engine.dart` |
| `test/integration/*.dart` | `../../lib/kernel/engine/player_engine.dart` |
| `test/perf/*.dart` | `../../lib/kernel/engine/player_engine.dart` |
| `test/features/**/*.dart` | varies by depth |

### Anti-Patterns to Avoid

- **Don't use `package:simple_player_flutter/kernel/engine/player_engine.dart`** for test/ files — D-01 specifies real relative paths, not package syntax
- **Don't leave any `package:player_engine` reference** — grep must return zero
- **Don't change engine internal files to use barrel** — D-09 requires direct file imports

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Import rewriting | Manual per-file edits | PowerShell/Find + sed replacement | 56 files — manual is error-prone |
| Path calculation | Manual per-file | Script-based relative path computation | Different depth levels, easy to miscalculate |

## Common Pitfalls

### Pitfall 1: Wrong File Count
**What goes wrong:** CONTEXT.md says 45 files, REQUIREMENTS.md says 37 — actual is 56.
**Why it happens:** Different documents were written at different times with different grep commands.
**How to avoid:** Use the verified count of 56 source files. Verify with `grep -rl "package:player_engine" lib/ test/ | wc -l`.
**Warning signs:** Planning tasks that skip files or leave residual imports.

### Pitfall 2: Engine Internal Import Style
**What goes wrong:** Engine files rewritten to relative barrel path instead of direct file imports.
**Why it happens:** Treating all 56 files identically.
**How to avoid:** Apply the engine internal mapping table above. The 7 engine files get direct imports; the other 49 get barrel relative paths.
**Warning signs:** `import '../../kernel/engine/player_engine.dart'` appearing in engine/ directory files.

### Pitfall 3: Stale Documentation Numbers
**What goes wrong:** REQUIREMENTS.md, ROADMAP.md, CONTEXT.md all have wrong file counts.
**Why it happens:** Numbers were estimated before actual grep was run.
**How to avoid:** Update all counts to 56 in D-06. Verify with grep after migration.

### Pitfall 4: Missing pubspec Entry Removal
**What goes wrong:** All imports migrated but pubspec.yaml still has the path entry — creates dead config.
**Why it happens:** Import migration and pubspec cleanup done as separate unlinked steps.
**How to avoid:** Execute in order: migrate imports first (D-11), then remove pubspec entry, then verify.

### Pitfall 5: Circular Import from Engine Files
**What goes wrong:** Engine internal files importing each other create circular dependencies.
**Why it happens:** Direct file imports between engine files can form cycles.
**How to avoid:** Engine internal files currently only import the barrel for types, not for other engine files' logic. The direct import mapping above shows no cycles — each file imports only leaf types (enums, models, abstract class).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled) |
| Config file | none (standard Flutter) |
| Quick run command | `flutter test` |
| Full suite command | `flutter test` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEP-01 | No player_engine in pubspec | grep | `grep -r "player_engine" pubspec.yaml` should return empty | N/A (config check) |
| DEP-02 | Zero package:player_engine imports | grep | `grep -r "package:player_engine" lib/ test/` should return empty | N/A (static check) |
| DEP-03 | Barrel exports 8 symbols | code inspection | Read barrel file, count exports | Already verified |
| DEP-04 | Engine internal imports resolve | build | `flutter analyze` zero errors | Existing |
| All | No regressions | test | `flutter test` all pass | Existing |

### Validation Steps (Post-Migration)

1. `grep -r "package:player_engine" lib/ test/` — must return zero
2. `grep -r "package:player_engine" pubspec.yaml` — must return zero
3. `flutter analyze` — zero errors, zero warnings
4. `flutter test` — all tests pass
5. Manual barrel check: `lib/kernel/engine/player_engine.dart` has exactly 8 export lines

### Wave 0 Gaps
- None — existing test infrastructure covers all phase requirements

## Package Legitimacy Audit

No new packages are installed in this phase. The only dependency change is **removing** an existing path dependency. Audit not applicable.

## Security Domain

Minimal security surface — this phase only changes import paths, no runtime behavior changes.

| ASVS Category | Applies | Notes |
|---------------|---------|-------|
| V5 Input Validation | no | No input handling changes |
| V6 Cryptography | no | No crypto changes |

No new threat patterns introduced. The migration is purely syntactic.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | External barrel exports same 8 symbols as local barrel | Barrel Comparison | LOW — verified by reading both files |
| A2 | All 56 imports are identical `package:player_engine/player_engine.dart` | Import Pattern | LOW — grep confirmed no selective imports |
| A3 | Engine internal files have no circular dependency when using direct imports | Circular Import | LOW — mapping shows each file imports only leaf types |

## Open Questions

1. **File count discrepancy** — CONTEXT.md (45) vs REQUIREMENTS.md (37) vs actual (56)
   - What we know: grep confirms 56 source files
   - What's unclear: Why the discrepancy — likely different grep timings or exclusions
   - Recommendation: Use 56 as authoritative, update all docs

2. **Discussion log files** — `.planning/phases/01-dep-cleanup/01-DISCUSSION-LOG.md` has 4 references
   - What we know: These are historical discussion records
   - What's unclear: Whether updating historical logs is required by D-05
   - Recommendation: Skip DISCUSSION-LOG.md updates — it's an audit trail, not a living doc

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Dart import mechanics are well-understood, no external research needed
- Architecture: HIGH — migration is mechanical find-and-replace, pattern is clear
- Pitfalls: HIGH — all pitfalls derived from actual codebase inspection, not speculation

**Research date:** 2026-06-29
**Valid until:** 2026-07-29 (stable — import paths don't change frequently)

## RESEARCH COMPLETE
