# Phase 15: 契约固化与基线盘点 - Pattern Map

**Mapped:** 2026-07-17
**Files analyzed:** 11 (3 contract-spec targets group / 7 interface files + 1 impl file to touch, 1 audit script, 1 audit snapshot pair, 7 contract test files, 1 fixtures dir)
**Analogs found:** 9 / 11 categories (2 categories have NO live analog — noted below)

**Important scope note:** Phase 15 does not create new *feature* files in the usual sense. Its "files to create/modify" are: (1) doc-comment edits to existing interface files, (2) a new audit script + snapshot docs, (3) new contract test files + fixtures. Every entry below reflects this.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kernel/engine/media_engine.dart` (doc-comment edit only) | contract-spec (interface) | request-response | itself (live, read for baseline) — sibling `lib/kernel/engine/playback_control.dart` for `///` style | exact (self) |
| `lib/kernel/engine/engine_state_view.dart` (doc-comment edit — group contract) | contract-spec (interface, 13 getters) | request-response (read-only) | itself; group-contract precedent = none in codebase (no existing "group contract" doc pattern) — RESEARCH.md's `RenderBox`-style example is `[ASSUMED]`, not verifiable in this repo | partial (no live precedent for group contracts) |
| `lib/kernel/engine/playback_control.dart` (doc-comment edit) | contract-spec (interface) | request-response | itself — current `///` is already single-line-per-method; closest style precedent for "before" state | exact (self) |
| `lib/kernel/engine/track_control.dart`, `subtitle_config.dart`, `video_effect_control.dart`, `renderer_control.dart`, `volume_control.dart` (doc-comment edits) | contract-spec (interface) | request-response | `lib/kernel/engine/playback_control.dart` (same ISP tier, same current doc style) | exact (role-match, same author/pattern) |
| `lib/kernel/engine/fvp_engine.dart` (thin doc-comment edit only, D4) | contract-spec (impl, "thin" doc) | request-response + stateful | itself, `open()` method lines 236-311 — existing `///` above `_openGeneration` (line 190-193) is the exact precedent for "implementation-specific side-effect note, not contract" | exact |
| `tool/audit/inventory.sh` (or `.dart`) — new | utility (audit script) | batch / static-analysis | **No analog exists.** `tool/` only contains `tool/dart_skills_lint/`, `tool/dart_hooks/` (external vendored tooling, not project-authored audit scripts). Closest structural precedent is the ripgrep commands already run ad hoc in RESEARCH.md §"复现本次审计所用的确切命令" | no analog — build from RESEARCH.md spec |
| `.planning/phases/15-.../15-BASELINE-AUDIT.json` / `.md` — new | audit-report | batch output | `.planning/codebase/TESTING.md` / `CONCERNS.md` (markdown table conventions) for the `.md` half; no `.json` analog exists in `.planning/` | partial (md style only) |
| `test/contracts/engine_state_view_contract.dart` (+ 6 sibling files) — new | contract-test | request-response (behavioral assertions against interface) | `test/kernel/engine/engine_state_machine_test.dart` (group/setUp/tearDown structure, AAA, state-transition assertions) + `test/helpers/fake_engine.dart` (for the *shape* of an ISP-interface-typed engine, not for reuse per D13) | strong role-match |
| `test/engine/fvp_engine_contract_test.dart` — new (mounts contract groups against real `FvpEngine`) | contract-test (mount point) | request-response | `test/kernel/engine/fvp_engine_open_test.dart` (real-`FvpEngine`-under-test pattern, generation guard assertions) | exact |
| `test/fixtures/*.mp4|.txt|.avi` — new (D17 real bad-file fixtures) | test fixture (file-I/O) | file-I/O | **No analog exists.** `test/fixtures/` does not exist; no other fixture-file directory found in `test/` (golden tests use generated goldens, not curated media fixtures) | no analog — build from RESEARCH.md D17 spec |
| `lib/kernel/engine/media_state.dart` / `lib/kernel/engine/engine_state_machine.dart` (read-only reference, not modified) | contract-spec source-of-truth | — | itself — used as the D7 "states:" cross-check source, not edited in Phase 15 | exact (reference only) |

## Pattern Assignments

### `lib/kernel/engine/media_engine.dart`, `engine_state_view.dart`, `playback_control.dart`, `track_control.dart`, `subtitle_config.dart`, `video_effect_control.dart`, `renderer_control.dart`, `volume_control.dart` (contract-spec, doc-comment edits)

**Analog:** the files themselves (live) — current doc style is the baseline to extend, not replace.

**Current single-line-per-getter style to preserve and extend** (`lib/kernel/engine/engine_state_view.dart:16-38`):
```dart
/// 纹理 ID — 用于 Texture 渲染，null 表示尚未就绪
ValueNotifier<int?> get textureId;

/// 主播放状态 — 正交 6 值枚举（idle/opening/playing/paused/completed/error）
ValueNotifier<MediaState> get state;
```
Per D3, this one-liner stays; a new class-level group contract block goes above `abstract class EngineStateView` (not per-getter). RESEARCH.md gives the target shape (verified against Context7 dartdoc conventions — `///` plain text, no dartdoc-native tag support):

```dart
/// 播放器只读状态视图 — UI 层监听用
///
/// requires: 无（所有 getter 幂等、无参数、永不 throw）
/// ensures: 返回值反映最近一次内部状态更新；disposed 后返回安全默认值（见 D9）
/// modifies: 无（本接口所有成员均为纯读取，不产生副作用）
abstract class EngineStateView {
  /// 纹理 ID — 用于 Texture 渲染，null 表示尚未就绪
  ValueNotifier<int?> get textureId;
  // ... each getter keeps ONE line, points back to the group contract implicitly
}
```

**Current method-level style to extend with D2 tags** (`lib/kernel/engine/playback_control.dart:9-19`):
```dart
/// 打开媒体文件
Future<void> open(String path);

/// 开始播放
void play();
```
Target shape per D2/D7 (tag order fixed: `requires → ensures → states → modifies → throws`, omit absent tags, no empty tag lines):
```dart
/// 打开媒体文件
///
/// requires: state ∈ {idle, opening, paused, completed, error}
/// ensures: state == playing on success
/// states: transitions to {opening, playing, error}
/// modifies: [state], [position], [duration], [lastError]
/// throws: FileError (path 不存在), CodecError (解码器初始化失败)
Future<void> open(String path);
```

**Cross-check source for `states:` values** — `lib/kernel/engine/engine_state_machine.dart:66-92` (`_canTransitionTo` switch expression) is the machine-enforced transition table; each `states:` tag written into the interface MUST be checked against this switch by hand (D7 — deliberate duplication, not DRY violation). Do not invent transition sets; derive them from this switch.

**Bilingual/双语 doc-comment structure precedent** — every existing `///` block in this codebase (e.g. `engine_state_machine.dart:5-16`, `media_engine.dart:9-22`) uses Chinese prose only, not the "中文 + English contract block" structure D1/CONTEXT.md's DOC-01 describes. **Gap:** no LIVE file currently demonstrates the bilingual structure — RESEARCH.md's proposed format (Chinese intent line + blank + tag block) should be treated as the template to introduce, not a pattern already present in the repo. Flag this explicitly in the plan so the executor doesn't go hunting for a bilingual precedent that doesn't exist yet.

---

### `lib/kernel/engine/fvp_engine.dart` (contract-spec, impl "thin" doc per D4)

**Analog:** itself — `lib/kernel/engine/fvp_engine.dart:190-194` is the exact existing precedent for "implementation-specific side-effect note, no contract restated":
```dart
/// open() 递增计数器 — 快速切歌时丢弃过期的异步结果
///
/// 每次 open() 递增，async 操作完成后检查 generation 是否仍匹配。
/// 不匹配说明用户已发起新 open()，旧结果应被丢弃。
int _openGeneration = 0;
```
This is already the D4-compliant style: describes *implementation mechanism* (generation counter, mdk timing), never restates `requires:`/`ensures:`. When touching `fvp_engine.dart` for Phase 15, add similar notes only where `open()`/`dispose()`/etc. have implementation-specific behavior worth flagging (e.g. the software-decode retry fallback at lines 278-289, or the `_guardedAction` try/catch/log/eventLog wrapper at lines 222-232) — do not add `requires:/ensures:` tags here; those live only on the interface.

**Error-handling / logging pattern already established** (`fvp_engine.dart:222-232`, `_guardedAction`):
```dart
void _guardedAction(String name, void Function() action) {
  if (_disposed) return;
  try {
    action();
  } on Exception catch (e) {
    log.e('FvpEngine.$name error: $e');
    lastError.value = PlaybackError(PlaybackErrorCode.playFailed, '$name 失败: $e', e);
    eventLog.add('error', {'action': name, 'error': e.toString()});
  }
}
```
Reference this when contract-testing `throws:` behavior — the observable effect of most FvpEngine "errors" is `lastError.value` being set to a `PlayerError` subtype and `state` transitioning to `error`, NOT a thrown Dart exception. Contract tests should assert on `lastError.value` / `state.value`, not `expect(() => ..., throwsA(...))`, for most methods — this matches D19 "行为断言" (behavioral assertion) design.

---

### `tool/audit/inventory.sh` (or `.dart`) — new, no analog

**No analog found.** `tool/` currently only contains vendored external skill/lint tooling (`tool/dart_skills_lint/`, `tool/dart_hooks/`), not project-authored scripts. Build directly from the RESEARCH.md spec — do not search further for a shell-script analog in this repo.

**Exact commands to embed** (verified live by RESEARCH.md 2026-07-17, `[VERIFIED]`):
```bash
# package:logger 风格调用点统计（按调用点数）
rg -o "\b(log|logEngine|logBridge|logServices|logUi)\.(t|d|i|w|e|f|v)\(" --type dart lib/ | wc -l

# 按文件数统计
rg -l "\b(log|logEngine|logBridge|logServices|logUi)\.(t|d|i|w|e|f|v)\(" --type dart lib/ | wc -l

# MemoryMonitor 生产调用点（需过滤 memory_monitor.dart 自身的 doc-comment 误报）
rg -n "MemoryMonitor\.(start|snapshot)\(" --type dart lib/

# openGeneration 全部引用（scan全部 lib/，不要硬编码文件路径 — Pitfall 2）
rg -n "openGeneration|_openGeneration" --type dart lib/
```

**Structural requirement (D23):** separate the "compute counts" logic from "print/exit" logic so Phase 17 can later add `--enforce` without rewriting the counting code. Design as: pure function(s) returning counts → formatter(s) producing `.json`/`.md` → (future) threshold-comparison function that Phase 17 bolts on.

**Filter requirement (discovered live):** `memory_monitor.dart` itself contains 2 self-referential doc-comment mentions of `MemoryMonitor.start(...)`/`.snapshot()` (see `lib/kernel/utils/memory_monitor.dart:61,63` inside the class doc example) that a naive regex will double-count as "call sites." The script must exclude `lib/kernel/utils/memory_monitor.dart` from its own `MemoryMonitor.(start|snapshot)` grep target, or otherwise filter lines inside `///` blocks.

---

### `.planning/phases/15-.../15-BASELINE-AUDIT.md` — new

**Analog:** `.planning/codebase/TESTING.md` for markdown table conventions (header + `**bold labels**` + fenced code blocks for commands):
```markdown
## Test Framework

**Runner:**
- Flutter Test (built-in)
- Config: `pubspec.yaml` (dev_dependencies)

**Run Commands:**
```bash
flutter test                    # Run all tests
```
```
Reuse this "bold label + bullet list + fenced command block" convention for `15-BASELINE-AUDIT.md`. Do NOT hardcode counts in prose sentences (Pitfall 1) — every count must come from the script's actual output, referenced as a table generated by the script run, e.g. render the JSON's `breakdown` map as a markdown table rather than typing numbers by hand.

**`.json` half has no analog in `.planning/`** — build directly from RESEARCH.md's proposed schema:
```json
{
  "generated_at": "2026-07-17T00:00:00+08:00",
  "script_version": "1.0.0",
  "targets": {
    "package_logger_usage": { "total_call_sites": 84, "total_files": 28, "breakdown": {...} },
    "memory_monitor_calls": { "total_call_sites": 2, "locations": [...] },
    "open_generation_references": { "total_files": 2, "locations": [...] }
  }
}
```

---

### `test/contracts/*_contract.dart` (7 files: EngineStateView/PlaybackControl/TrackControl/SubtitleConfig/VideoEffectControl/RendererControl/VolumeControl) — new

**Analog:** `test/kernel/engine/engine_state_machine_test.dart` for group/setUp/tearDown/AAA structure (lines 1-22, 38-137):
```dart
void main() {
  group('EngineStateMachine', () {
    late EngineStateMachine machine;

    setUp(() {
      machine = EngineStateMachine(...);
    });

    tearDown(() {
      machine.dispose();
    });

    group('transitionTo — legal transitions', () {
      test('idle → opening returns true', () {
        expect(machine.transitionTo(MediaState.opening, 'test'), true);
        expect(machine.state.value, MediaState.opening);
      });
    });
  });
}
```
This nested-group-per-transition-category pattern is exactly the shape D14/D19 want, but retargeted: instead of `group('transitionTo — legal transitions')` against `EngineStateMachine` directly, each contract file wraps its assertions in a **parameterized top-level function** taking `MediaEngine Function() createEngine` (per RESEARCH.md, D13) so `test/engine/fvp_engine_contract_test.dart` can mount it against real `FvpEngine`, and Phase 21 can later mount the same function against `NewFvpEngine`. Do NOT instantiate `FvpEngine()` or `FakeEngine()` directly inside `test/contracts/*.dart` — instantiate only through the injected factory.

**Note on `FakeEngine` (`test/helpers/fake_engine.dart`)** — read it for the *shape* of an ISP-composed engine (all 7 interfaces implemented on one class, delegating to `EngineStateMachine` for `state`/`isSeeking`/`isBuffering`), but D13 explicitly forbids using it as the contract-test subject. `FakeEngine` remains for widget tests only.

**Group contract → test group correspondence (D14):** the 7 groups must exactly match `media_engine.dart`'s `implements` clause (`EngineStateView, PlaybackControl, TrackControl, SubtitleConfig, VideoEffectControl, RendererControl, VolumeControl` — `media_engine.dart:24-31`), which is **7 interfaces, not the 6 named in D14's decision text** (`VolumeControl` was omitted from the D14 enumeration — RESEARCH.md Pitfall 4/Open Question 2). Per RESEARCH.md's recommendation, add `volume_control_contract.dart` as an explicit 7th group; do not silently drop `VolumeControl` coverage.

---

### `test/engine/fvp_engine_contract_test.dart` — new (mount point against real FvpEngine)

**Analog:** `test/kernel/engine/fvp_engine_open_test.dart` — read this file for the existing pattern of testing real `FvpEngine` behavior (generation-guard assertions, async `open()` sequencing) rather than `FakeEngine`. Use it as the closest precedent for "how do existing tests already instantiate/dispose a real FvpEngine in this codebase" since Phase 15's contract tests will do the same, just organized by ISP group instead of by feature.

**Mount-point shape** (from RESEARCH.md, to be validated against the actual sibling file's imports/setup):
```dart
void main() {
  runEngineStateViewContractTests(() => FvpEngine());
  runPlaybackControlContractTests(() => FvpEngine());
  runVolumeControlContractTests(() => FvpEngine());
  // ... one line per ISP group, D14 (7 groups)
}
```

---

### `test/fixtures/*` (D17 real bad-file fixtures) — new, no analog

**No analog found** — `test/fixtures/` does not exist; confirmed via glob (`test/fixtures/**` → no results). No other curated-binary-fixture directory exists under `test/` (golden tests generate/compare PNGs via `matchesGoldenFile`, a different mechanism). Build from scratch per RESEARCH.md's minimal set:
```
test/fixtures/
├── README.md                    # explains each fixture's purpose + how to regenerate
├── corrupted_header.mp4
├── empty_file.mp4
├── not_a_video.txt
└── unsupported_codec.avi
```
Usage pattern (RESEARCH.md):
```dart
test('open() with corrupted file transitions to error state', () async {
  final engine = FvpEngine();
  await engine.open('test/fixtures/corrupted_header.mp4');
  expect(engine.state.value, MediaState.error);
  expect(engine.lastError.value, isA<CodecError>());
  engine.dispose();
});
```

## Shared Patterns

### ValueNotifier disposal in tests
**Source:** `test/kernel/engine/engine_state_machine_test.dart:20-22` (`tearDown(() => machine.dispose())`) and `test/helpers/fake_engine.dart:347-361` (`dispose()` method disposing every owned `ValueNotifier`).
**Apply to:** every contract test file — each `test()` or the group's `tearDown` must call `engine.dispose()` to avoid `ValueNotifier` leak warnings across the 7 contract groups × N tests.

### Behavioral (state/value) assertions over thrown-exception assertions
**Source:** `lib/kernel/engine/fvp_engine.dart:290-296` (`open()` error path sets `_stateMachine.transitionTo(MediaState.error, 'open')` + `lastError.value = error`, never throws to the caller) and `_guardedAction` (`fvp_engine.dart:222-232`).
**Apply to:** all contract tests asserting `throws:` tags — assert `engine.state.value == MediaState.error` and `engine.lastError.value is SomeErrorType`, not `expect(fn, throwsA(...))`, except where a method genuinely throws synchronously (verify per-method against the real impl before choosing assertion style).

### Group-then-transition-category test nesting
**Source:** `test/kernel/engine/engine_state_machine_test.dart` full structure (`group('EngineStateMachine') > group('transitionTo — legal transitions') > test('idle → opening returns true')`).
**Apply to:** all 7 `test/contracts/*_contract.dart` files — nest `group(interfaceName) > group(methodOrCategory) > test(specific behavior)`.

### `///` doc-comment style — Chinese-first, dash-separated intent line
**Source:** every existing interface file, e.g. `lib/kernel/engine/playback_control.dart:1-7`, `lib/kernel/engine/engine_state_view.dart:7-14`.
**Apply to:** all contract-spec doc edits — keep the existing single Chinese intent line per member; ADD the `requires:/ensures:/states:/modifies:/throws:` block as new lines below it, do not replace the existing line.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `tool/audit/inventory.sh` (or `.dart`) | utility (audit script) | batch | No project-authored script exists in `tool/`; only vendored external skill tooling present. Build from RESEARCH.md's verified `rg` commands and D21/D23 structural requirements. |
| `test/fixtures/*` (corrupted/empty/unsupported media files) | test fixture | file-I/O | `test/fixtures/` does not exist; no curated binary-fixture precedent anywhere under `test/`. Build the minimal set RESEARCH.md proposes; fixture generation method (how to actually produce a truncated mp4 header, etc.) is an implementation detail for the executor, not covered by any existing repo pattern. |
| Bilingual (中文+English contract block) `///` structure | contract-spec | — | No LIVE file currently uses this structure — every existing `///` comment in `lib/kernel/engine/` is Chinese-only prose. Treat RESEARCH.md's proposed format as the template to introduce, not an existing pattern to copy. |
| `15-BASELINE-AUDIT.json` schema | audit-report | batch output | No `.json` snapshot analog exists anywhere under `.planning/`. Use RESEARCH.md's proposed schema verbatim as starting point. |

## Metadata

**Analog search scope:** `lib/kernel/engine/*.dart` (all 29 files), `lib/kernel/utils/memory_monitor.dart`, `lib/kernel/utils/log.dart`, `lib/kernel/services/playback_navigator.dart`, `test/kernel/engine/*.dart`, `test/helpers/fake_engine.dart`, `.planning/codebase/*.md`, `tool/**`, `test/fixtures/**` (confirmed absent)
**Files scanned:** ~40 (11 live kernel/engine files read or grepped, 3 test files read, 2 planning docs read, tool/ and test/fixtures/ globbed for absence confirmation)
**Pattern extraction date:** 2026-07-17

## PATTERN MAPPING COMPLETE
