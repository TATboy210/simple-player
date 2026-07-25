# Phase 16: 兼容适配层骨架 + DiagnosticsBundle - Pattern Map

**Mapped:** 2026-07-18
**Files analyzed:** 9 new files (6 production + 3 test) — matches D11 (5 diagnostics files, but D19/CONTEXT collapses adapter to 1 combined file vs RESEARCH's 3-file split; both file-count layouts are pattern-compatible, see note under File Classification) + D19 (adapter, actually 3 files per RESEARCH's `kernel_mode.dart`/`delegation_policy.dart`/`kernel_adapter.dart` split) + wave-0 test gaps from RESEARCH Validation Architecture
**Analogs found:** 9 / 9 (100% — this phase is pure internal-pattern reuse, no external library needed)

**Note on file count discrepancy:** CONTEXT D19 says "adapter 文件组织 = 单文件 `lib/kernel/adapter/kernel_adapter.dart`"（KernelAdapter+DelegationPolicy+KernelMode 三类型同文件）, but RESEARCH's Recommended Project Structure shows 3 separate adapter files. **CONTEXT D19 is the locked decision — planner must follow single-file adapter.** RESEARCH's 3-file layout is informative only, not authoritative. This file maps patterns assuming CONTEXT D19 (1 adapter file) + CONTEXT D11 (5 diagnostics files) = 6 production files total, matching D27's "6 files" budget claim.

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|-----------------|----------------|
| `lib/kernel/adapter/kernel_adapter.dart` (KernelAdapter class) | service/facade (engine wrapper) | request-response (delegating dispatch) | `lib/kernel/engine/fvp_engine.dart` (`FvpEngine implements MediaEngine, SubtitleConfig`) | exact (same interface, delegating not owning) |
| `lib/kernel/adapter/kernel_adapter.dart` (DelegationPolicy struct) | config/value-struct | CRUD (static config read) | `lib/kernel/engine/volume_control.dart` style abstract-interface-with-final-fields pattern + Dart const-constructor convention | role-match |
| `lib/kernel/adapter/kernel_adapter.dart` (KernelMode enum) | config/enum | — | plain Dart enum, no direct analog needed (trivial) | n/a — no analog required |
| `lib/kernel/diagnostics/kernel_logger.dart` (KernelLogger abstract + NullKernelLogger) | utility/facade (logging) | event-driven (fire-and-forget calls) | `lib/kernel/utils/log.dart` (5 `Logger` instances + `PrefixPrinter`) | role-match (abstracts over existing loggers) |
| `lib/kernel/diagnostics/memory_monitor_slot.dart` (MemoryMonitorSlot abstract + NullMemoryMonitorSlot) | utility (diagnostics slot) | event-driven / snapshot polling | `lib/kernel/utils/memory_monitor.dart` (`MemoryMonitor` static singleton, 193 lines) | role-match (minimal abstraction over static singleton's public API) |
| `lib/kernel/diagnostics/metrics_slot.dart` (MetricsSlot abstract + NullMetricsSlot) | utility (diagnostics slot) | CRUD (record/reset counters) | `lib/kernel/engine/engine_metrics.dart` (`EngineMetrics`, 91 lines) | role-match |
| `lib/kernel/diagnostics/event_log_slot.dart` (EventLogSlot abstract + NullEventLogSlot) | utility (diagnostics slot) | event-driven (ring-buffer append) | `lib/kernel/engine/engine_event_log.dart` (`EngineEventLog`, 103 lines) | role-match |
| `lib/kernel/diagnostics/diagnostics_bundle.dart` (DiagnosticsBundle carrier) | model/carrier (DI container) | CRUD (construct/dispose) | `lib/kernel/player_services.dart` (`PlayerServices` — DI container pattern, `init()`/`dispose()` lifecycle) | role-match (miniature version of same DI-container idiom) |
| `lib/kernel/player_services.dart` (MODIFIED: line 87 assembly point) | composition root | CRUD (construction wiring) | itself — existing `init()` method, minimal-diff edit | exact |
| `test/adapter/kernel_adapter_contract_test.dart` | test (contract reuse mount point) | request-response | `test/engine/fvp_engine_contract_test.dart` (69 lines, fully read) | exact |
| `test/adapter/kernel_adapter_identity_test.dart` | test (identity/`same()`) | — | new pattern, no direct existing analog file, but uses `EngineStateView` field enumeration from `lib/kernel/engine/engine_state_view.dart` as the source-of-truth field list | partial (interface-derived, not test-file-derived) |
| `test/adapter/kernel_adapter_open_generation_test.dart` | test (unit, counter behavior) | CRUD (increment-and-check) | pattern derived from `fvp_engine.dart` lines 194/259/267/311/320 (the counter this test's adapter-side counterpart must NOT duplicate) | role-match (behavioral analog, not file analog) |
| `test/diagnostics/diagnostics_bundle_test.dart` | test (unit, construction/dispose) | CRUD | no direct existing analog (no prior "bundle" test) — follow `flutter_test` conventions used across `test/` | no analog (new pattern) |
| `test/diagnostics/kernel_logger_test.dart` | test (unit, signature acceptance) | — | no direct existing analog (no prior KernelLogger) | no analog (new pattern) |

## Pattern Assignments

### `lib/kernel/adapter/kernel_adapter.dart` (KernelAdapter — service/facade, request-response)

**Analog:** `lib/kernel/engine/fvp_engine.dart` (636 lines) + `lib/kernel/engine/media_engine.dart` (32 lines, composite interface)

**Interface surface to implement** (`media_engine.dart:24-32`):
```dart
abstract class MediaEngine
    implements
        EngineStateView,
        PlaybackControl,
        TrackControl,
        SubtitleConfig,
        VideoEffectControl,
        RendererControl,
        VolumeControl {}
```
`KernelAdapter implements MediaEngine` must implement every member across all 7 sub-interfaces. There is no partial-implementation shortcut — Dart requires every abstract member concretely overridden.

**Class-level doc-comment pattern** (mirror `fvp_engine.dart:25-41` structure — architecture summary + helper composition list):
```dart
/// fvp/MDK 引擎实现
///
/// 封装 fvp/MDK 播放器，暴露 Flutter 友好的 ValueNotifier 接口。
/// 由 6 个 helper 组合而成: ...
class FvpEngine implements MediaEngine, SubtitleConfig {
```
`KernelAdapter` should follow the same doc-comment shape, but describing the Strangler Fig seam role and listing the P20 migration-point checklist (D21/D23 — exactly 3 items: openGeneration counter migration, bundle activation, policy flip) at the class level, not per-method.

**Per-capability dispatch pattern** (from RESEARCH Architecture Patterns, Pattern 1 — this is THE core pattern for this file):
```dart
// ValueNotifier getter — identity-preserving dispatch (ADAPT-03 critical: never rewrap)
@override
ValueNotifier<double> get volume =>
    _policy.volume == KernelMode.legacy ? _legacy.volume : _migrated.volume;

// Method call — behavior-preserving dispatch (ADAPT-01)
@override
Future<void> play() =>
    _policy.playback == KernelMode.legacy ? _legacy.play() : _migrated.play();
```
Apply this exact ternary-dispatch shape to every one of the ~44 members across the 7 sub-interfaces (13 `EngineStateView` notifiers + 1 `mediaInfo` + `dispose()`, 12 `PlaybackControl` methods, 3 `TrackControl`, 8 `SubtitleConfig`, 4 `VideoEffectControl`, 2 `RendererControl`, 4 `VolumeControl` — note the 4 `VolumeControl` members are shared with `PlaybackControl`/`EngineStateView`, see Pitfall below).

**Critical shared-member pitfall (route via `policy.volume` exactly once):**
`PlaybackControl.setVolume/setMute` (`playback_control.dart:68-81`) and `EngineStateView.volume/isMuted` (`engine_state_view.dart:33-37`) are **identical signatures** to `VolumeControl.setVolume/setMute/volume/isMuted` (`volume_control.dart:7-36`). Implement these 4 members exactly once in `KernelAdapter`, dispatched via `_policy.volume` — do NOT create separate branches keyed on `_policy.playback` or `_policy.stateView` for these members (Dart's interface composition means one override satisfies all parent-interface declarations simultaneously; a second competing branch is unreachable dead code).

**openGeneration — new adapter-local counter, NOT read from `FvpEngine`:**
```dart
// Source pattern (structural analog only — DO NOT reference _openGeneration
// from fvp_engine.dart, it is private and D20 forbids touching that file):
// fvp_engine.dart:194,259,267,311,320
int _openGeneration = 0;                                          // adapter's OWN field
// inside adapter's open():
final gen = ++_openGeneration;
await _dispatchOpen(path);   // forwards to legacy.open(path) or migrated.open(path)
if (gen != _openGeneration) return; // superseded by a newer open() call
```
D22 grep-gate requires `grep -r '_openGeneration' lib/kernel/adapter/'` to show exactly the adapter's own field (not a reference into `fvp_engine.dart`).

**Constructor signature** (CONTEXT D12, RESEARCH Code Examples):
```dart
KernelAdapter({
  required MediaEngine legacy,
  required MediaEngine migrated,
  required DelegationPolicy policy,
  DiagnosticsBundle bundle = const DiagnosticsBundle.noop(),
})
```

---

### `lib/kernel/adapter/kernel_adapter.dart` (DelegationPolicy + KernelMode)

**Analog:** Dart const-constructor struct convention; closest existing shape is the family of small immutable value classes in `lib/kernel/models/` (e.g. `playlist_item.dart`) — final fields + `const` constructor.

**Struct pattern** (verbatim from RESEARCH Architecture Patterns, Pattern 1 — copy directly):
```dart
final class DelegationPolicy {
  const DelegationPolicy({
    required this.stateView,
    required this.playback,
    required this.track,
    required this.subtitle,
    required this.videoEffect,
    required this.renderer,
    required this.volume,
  });

  /// All 7 capabilities routed to the same [KernelMode] — Phase 16 uses
  /// `DelegationPolicy.all(KernelMode.legacy)` exclusively (D14).
  const DelegationPolicy.all(KernelMode mode)
      : stateView = mode,
        playback = mode,
        track = mode,
        subtitle = mode,
        videoEffect = mode,
        renderer = mode,
        volume = mode;

  final KernelMode stateView;
  final KernelMode playback;
  final KernelMode track;
  final KernelMode subtitle;
  final KernelMode videoEffect;
  final KernelMode renderer;
  final KernelMode volume;
}

enum KernelMode { legacy, migrated }
```
All 7 fields are `final` — CONTEXT D15 requires this for the #6/#8 structural-safety argument (immutability forces adapter recreation on cutover rather than unsafe in-place flips).

---

### `lib/kernel/diagnostics/kernel_logger.dart` (KernelLogger — utility/facade, event-driven)

**Analog:** `lib/kernel/utils/log.dart` (293 lines, fully read) — specifically the 5 `Logger` instances (`log`, `logEngine`, `logBridge`, `logServices`, `logUi`) and their `.e/.w/.i/.d` call convention which `KernelLogger` must be able to statically express.

**Level-mapping table (D8, locked):**
| Existing call prefix | KernelLogger method |
|---|---|
| `log*.t(...)` (0 live sites) | `trace(...)` |
| `log*.d(...)` (17 live sites) | `debug(...)` |
| `log*.i(...)` (12 live sites) | `info(...)` |
| `log*.w(...)` (7 live sites) | `warn(...)` |
| `log*.e(...)` (48 live sites) | `error(...)` |
| `log*.f(...)` (0 live sites) | `fatal(...)` |

**Signature pattern** (verbatim from RESEARCH Code Examples — this is the D6-resolved signature, copy directly):
```dart
abstract class KernelLogger {
  void trace(String message);
  void debug(String message);
  void info(String message);
  void warn(String message);
  // Both optional named params required: 3 of 84 live call sites in lib/
  // pass error:/stackTrace: today (2 both-named + 2 stackTrace-only across
  // 2 files — see RESEARCH Pitfall 1 census).
  void error(String message, {Object? error, StackTrace? stackTrace});
  void fatal(String message, {Object? error, StackTrace? stackTrace});
}

final class NullKernelLogger implements KernelLogger {
  const NullKernelLogger();
  @override
  void trace(String message) {}
  @override
  void debug(String message) {}
  @override
  void info(String message) {}
  @override
  void warn(String message) {}
  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}
  @override
  void fatal(String message, {Object? error, StackTrace? stackTrace}) {}
}
```
**Do not** port `log.dart`'s `PrefixPrinter`, `JsonPrinter`, file-rotation (`_RotatingFileOutput`), or `initLog()` machinery into this abstract contract — D7 explicitly caps scope at method signatures only; sink/formatting/rotation implementation is Phase 17's job, hidden behind this interface.

---

### `lib/kernel/diagnostics/memory_monitor_slot.dart` (MemoryMonitorSlot — utility, event-driven/snapshot)

**Analog:** `lib/kernel/utils/memory_monitor.dart` (193 lines, fully read) — static singleton with `start()`/`stop()`/`snapshot()`/`exportJson()`/`snapshotNotifier`.

**Minimal method set derivation** (per D9/D10 — extract PUBLIC API shape, but do NOT copy the static-singleton pattern into the abstract contract):
```dart
// public surface to extract signatures FROM (source: memory_monitor.dart:97-134):
static void start({Duration interval, void Function(MemorySnapshot)? onTick});
static void stop();
static MemorySnapshot? snapshot();
static String exportJson();
final ValueNotifier<MemorySnapshot?> snapshotNotifier;
```
Translate to an instance-method abstract contract (no `static`, per D10 — statics are an implementation detail of the concrete singleton, not part of the contract):
```dart
abstract class MemoryMonitorSlot {
  void start({Duration? interval});
  void stop();
  Object? snapshot(); // return type intentionally loose to avoid coupling
                       // to MemorySnapshot's concrete shape — D9/D11 caution
  void dispose();
}

final class NullMemoryMonitorSlot implements MemoryMonitorSlot {
  const NullMemoryMonitorSlot();
  @override
  void start({Duration? interval}) {}
  @override
  void stop() {}
  @override
  Object? snapshot() => null;
  @override
  void dispose() {}
}
```
**Naming collision guard (D9):** class name `MemoryMonitorSlot` must not collide with existing `MemoryMonitor` (`memory_monitor.dart:69`) — the `Slot` suffix already satisfies this; do not import or reference `MemorySnapshot`/`MetricSample` concrete types from `memory_monitor.dart` in the abstract contract per D10 (keeps P19 free to change the concrete shape without breaking the interface).

---

### `lib/kernel/diagnostics/metrics_slot.dart` (MetricsSlot — utility, CRUD counters)

**Analog:** `lib/kernel/engine/engine_metrics.dart` (91 lines, fully read) — plain class with public mutable counters + `record*()` methods + `toJson()`.

**Public API to derive minimal method set from** (`engine_metrics.dart:44-79`):
```dart
void recordOpen({required bool success});
void recordSeek(Duration elapsed);
void recordFrameDrop([int count = 1]);
void recordDecodeError();
void recordBufferUnderrun();
void reset();
Map<String, Object> toJson();
```
Abstract contract should expose the `record*` verbs (the actual "capability" other phases need) without porting the internal counter fields (`framesDropped`, `_totalSeekTime`, etc. stay implementation-private in the real `EngineMetrics`, not on the abstract slot per D10). `NullMetricsSlot` no-ops every `record*` method and returns an empty/default `toJson()`.

---

### `lib/kernel/diagnostics/event_log_slot.dart` (EventLogSlot — utility, event-driven ring buffer)

**Analog:** `lib/kernel/engine/engine_event_log.dart` (103 lines, fully read) — ring buffer with `add()`/`entries`/`clear()`/`toJson()`.

**Public API to derive minimal method set from** (`engine_event_log.dart:66-102`):
```dart
void add(String type, [Map<String, Object?>? data]);
List<EngineEvent> get entries;      // concrete EngineEvent type — do NOT
                                      // reuse this concrete class in the
                                      // abstract slot per D10; loosen to
                                      // Map<String, Object?> or similar
void clear();
List<Map<String, Object?>> toJson();
```
`NullEventLogSlot.add()` no-ops; `entries`/`toJson()` return empty collections; `clear()` no-ops.

---

### `lib/kernel/diagnostics/diagnostics_bundle.dart` (DiagnosticsBundle — model/carrier, CRUD)

**Analog:** `lib/kernel/player_services.dart` (111 lines, fully read) — DI container idiom: hold service instances as `final`/`late final` fields, provide lifecycle methods (`init()`) and cascading `dispose()` in reverse-of-construction order.

**PlayerServices dispose-cascade pattern to mirror** (`player_services.dart:99-109`):
```dart
/// 释放顺序与 init() 相反 ..., 确保被依赖的服务后释放。每个 dispose() 都是幂等的。
void dispose() {
  playlistGeneration.dispose();
  windowService.dispose();
  videoProcessing.dispose();
  controller.dispose();
  engine.dispose();
}
```

**DiagnosticsBundle carrier pattern** (verbatim from RESEARCH Code Examples — copy directly, D1/D4):
```dart
final class DiagnosticsBundle {
  const DiagnosticsBundle({
    required this.logger,
    required this.memoryMonitor,
    required this.metrics,
    required this.eventLog,
  });

  const DiagnosticsBundle.noop()
      : logger = const NullKernelLogger(),
        memoryMonitor = const NullMemoryMonitorSlot(),
        metrics = const NullMetricsSlot(),
        eventLog = const NullEventLogSlot();

  final KernelLogger logger;
  final MemoryMonitorSlot memoryMonitor;
  final MetricsSlot metrics;
  final EventLogSlot eventLog;

  /// Cascading dispose — noop slots no-op; future real slots may hold
  /// timers/streams that need cleanup (mirrors MemoryMonitor.stop()).
  void dispose() {
    memoryMonitor.dispose();
    metrics.dispose();
    eventLog.dispose();
  }
}
```

---

### `lib/kernel/player_services.dart` (MODIFIED — assembly point, line 87)

**Analog:** itself — this is a minimal-diff edit, not a new-file pattern.

**Current code** (`player_services.dart:86-97`):
```dart
Future<void> init() async {
  engine = FvpEngine();
  playlist = Playlist();
  controller = PlaybackController(
    engine: engine,
    playlist: playlist,
    onNeedRebuild: () => playlistGeneration.value++,
  );
  final settings = await SettingsStore.load();
  await controller.init(settings: settings);
  videoProcessing = VideoProcessingService(engine, initialSettings: settings);
}
```

**Target shape** (per D12/D13/D14, RESEARCH Open Question 2 recommendation — pass same instance to both `legacy`/`migrated`):
```dart
Future<void> init() async {
  final fvp = FvpEngine();
  engine = KernelAdapter(
    legacy: fvp,
    migrated: fvp, // Phase 16: same instance — NewFvpEngine doesn't exist yet (D19)
    policy: const DelegationPolicy.all(KernelMode.legacy),
    // bundle defaults to DiagnosticsBundle.noop() per constructor default
  );
  playlist = Playlist();
  controller = PlaybackController(
    engine: engine,
    playlist: playlist,
    onNeedRebuild: () => playlistGeneration.value++,
  );
  final settings = await SettingsStore.load();
  await controller.init(settings: settings);
  videoProcessing = VideoProcessingService(engine, initialSettings: settings);
}
```
The `late final MediaEngine engine` field type (`player_services.dart:55`) is unchanged — `KernelAdapter implements MediaEngine` satisfies the existing interface-typed field with zero downstream diff (confirmed 0 `as FvpEngine` casts, 0 convenience-getter usages in live code per RESEARCH Cast Audit).

---

### `test/adapter/kernel_adapter_contract_test.dart` (test, contract reuse mount point)

**Analog:** `test/engine/fvp_engine_contract_test.dart` (69 lines, fully read) + `test/contracts/contract_test_runner.dart` (22 lines, fully read)

**Mount-point pattern to copy verbatim, changing only the factory** (`fvp_engine_contract_test.dart:58-69`):
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFvpTextureChannelMock();

  runEngineStateViewContractTests(() => FvpEngine());
  runPlaybackControlContractTests(() => FvpEngine());
  runTrackControlContractTests(() => FvpEngine());
  runSubtitleConfigContractTests(() => FvpEngine());
  runVideoEffectControlContractTests(() => FvpEngine());
  runRendererControlContractTests(() => FvpEngine());
  runVolumeControlContractTests(() => FvpEngine());
}
```
Phase 16's new file changes ONLY the factory (per contract_test_runner.dart's own doc comment: "This indirection is what makes the contract suite reusable ... by swapping only the factory"):
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFvpTextureChannelMock(); // same texture-channel mock helper —
                                     // copy the whole _installFvpTextureChannelMock
                                     // function + _fvpChannel/_nextFakeTextureId
                                     // (lines 36-56 of fvp_engine_contract_test.dart)
                                     // since KernelAdapter also wraps a real FvpEngine

  KernelAdapter _makeAdapter() {
    final fvp = FvpEngine();
    return KernelAdapter(
      legacy: fvp,
      migrated: fvp,
      policy: const DelegationPolicy.all(KernelMode.legacy),
    );
  }

  runEngineStateViewContractTests(_makeAdapter);
  runPlaybackControlContractTests(_makeAdapter);
  runTrackControlContractTests(_makeAdapter);
  runSubtitleConfigContractTests(_makeAdapter);
  runVideoEffectControlContractTests(_makeAdapter);
  runRendererControlContractTests(_makeAdapter);
  runVolumeControlContractTests(_makeAdapter);
}
```
The texture-channel-mock workaround (lines 12-56 of the analog) is copied as-is because `KernelAdapter` forwards to a real `FvpEngine` under the hood, hitting the same headless-test native-texture gap.

---

### `test/adapter/kernel_adapter_identity_test.dart` (test, `same()` identity — D25)

**Analog:** field enumeration from `lib/kernel/engine/engine_state_view.dart:20-65` (13 ValueNotifier fields, fully read) — no existing *test file* analog, this is a new pattern, but the field list to iterate is authoritative and exact.

**Full field list requiring a `same()` assertion each** (from `engine_state_view.dart`):
```dart
ValueNotifier<int?> get textureId;
ValueNotifier<MediaState> get state;
ValueNotifier<int> get position;
ValueNotifier<int> get duration;
ValueNotifier<double> get volume;
ValueNotifier<bool> get isMuted;
ValueNotifier<bool> get isBuffering;
ValueNotifier<bool> get isSeeking;
ValueNotifier<String> get subtitleText;
ValueNotifier<int> get buffered;
ValueNotifier<double> get aspectRatio;
ValueNotifier<PlayerError?> get lastError;
ValueNotifier<double> get playbackSpeed;
// mediaInfo (MediaInfo, not ValueNotifier) — NO same() test needed
// dispose() (method) — NO same() test needed
```
Test-body pattern (`package:test`'s `same()` matcher — reference-identity, ships in `package:matcher` transitively via `flutter_test`):
```dart
test('KernelAdapter forwards EngineStateView notifiers by identity', () {
  final legacy = FvpEngine();
  final adapter = KernelAdapter(
    legacy: legacy,
    migrated: legacy,
    policy: const DelegationPolicy.all(KernelMode.legacy),
  );

  expect(adapter.textureId, same(legacy.textureId));
  expect(adapter.state, same(legacy.state));
  expect(adapter.position, same(legacy.position));
  expect(adapter.duration, same(legacy.duration));
  expect(adapter.volume, same(legacy.volume));
  expect(adapter.isMuted, same(legacy.isMuted));
  expect(adapter.isBuffering, same(legacy.isBuffering));
  expect(adapter.isSeeking, same(legacy.isSeeking));
  expect(adapter.subtitleText, same(legacy.subtitleText));
  expect(adapter.buffered, same(legacy.buffered));
  expect(adapter.aspectRatio, same(legacy.aspectRatio));
  expect(adapter.lastError, same(legacy.lastError));
  expect(adapter.playbackSpeed, same(legacy.playbackSpeed));
});
```
This is the test that directly catches Blocking Constraint #6 violations (re-wrapping a notifier) — critical, not optional.

---

### `test/adapter/kernel_adapter_open_generation_test.dart` (test, unit — ADAPT-04)

**Analog:** behavioral pattern only, from `fvp_engine.dart:194,259,267,311,320` (structural reference — the adapter's counter is a NEW field, never reads `FvpEngine._openGeneration` which is file-private).

Test should assert: (1) adapter's own counter increments once per `open()` call; (2) a superseded `open()` call's post-await work is a no-op (mirrors the existing `gen != _openGeneration` guard shape at `fvp_engine.dart:267/311`, but testing the adapter's own field via observable side effects, since the counter itself is private); (3) `grep -r '_openGeneration' lib/kernel/adapter/'` static gate (D22) is a separate shell-level check, not a Dart test — see Shared Patterns below.

---

## Shared Patterns

### ValueNotifier Identity Forwarding (Blocking Constraint #6)
**Source:** `lib/kernel/engine/engine_state_view.dart` (interface) + RESEARCH Anti-Patterns section
**Apply to:** `KernelAdapter`'s every `EngineStateView`/`VolumeControl` getter
```dart
// CORRECT — returns the same object
ValueNotifier<double> get volume =>
    _policy.volume == KernelMode.legacy ? _legacy.volume : _migrated.volume;

// WRONG — never do this (breaks ValueListenableBuilder subscriptions silently)
ValueNotifier<double> get volume => ValueNotifier(_legacy.volume.value);
```

### Const Noop Factory Pattern (D1/D4, D9)
**Source:** `lib/kernel/diagnostics/*.dart` (all 4 slots) + `DiagnosticsBundle`
**Apply to:** every abstract slot interface + its Null implementation
```dart
abstract class XxxSlot { /* methods */ }
final class NullXxxSlot implements XxxSlot {
  const NullXxxSlot();
  @override
  void someMethod() {} // no-op body
}
```

### Contract Test Reuse via Factory Swap (Phase 15 D13/D14, verified working)
**Source:** `test/contracts/contract_test_runner.dart:9-12` (doc comment states the exact intent)
**Apply to:** `test/adapter/kernel_adapter_contract_test.dart`
```dart
runEngineStateViewContractTests(() => KernelAdapter(/* ... */));
// repeat for all 7 run*ContractTests — only the factory changes, never the test body
```

### Static Grep/Size Gates (LOG-01 precedent, D22/D27)
**Source:** project convention referenced in RESEARCH ("CI grep 闸门内核永不 import package:logger 同模式")
**Apply to:** CI script / `tool/audit/` shell script
```bash
# D22 — no second openGeneration data source in adapter
grep -r '_openGeneration' lib/kernel/adapter/   # expect: adapter's own field only

# D27 — size budget vs FvpEngine's 636-line baseline
wc -l lib/kernel/adapter/*.dart lib/kernel/diagnostics/*.dart | tail -1   # expect: < 636
```

### DI Container Cascading Dispose (mirrors `PlayerServices`)
**Source:** `lib/kernel/player_services.dart:99-109`
**Apply to:** `DiagnosticsBundle.dispose()`, and `KernelAdapter.dispose()` forwarding to `bundle.dispose()` per D10 ("`bundle.dispose()` 由 `KernelAdapter.dispose()` 级联触发")
```dart
void dispose() {
  memoryMonitor.dispose();
  metrics.dispose();
  eventLog.dispose();
}
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/diagnostics/diagnostics_bundle_test.dart` | test (unit) | CRUD | No prior "bundle carrier" test exists in the codebase — follow generic `flutter_test`/`package:test` unit-test conventions (`group`/`test`/`expect`) used project-wide; no specific file to copy structure from beyond standard AAA pattern |
| `test/diagnostics/kernel_logger_test.dart` | test (unit) | — | No prior `KernelLogger` — test purely validates the 3 named-arg call shapes from the D6 census compile/execute without error; standard `flutter_test` conventions apply, no existing analog file needed |

## Metadata

**Analog search scope:** `lib/kernel/engine/*.dart` (all 8 sub-interface + FvpEngine files), `lib/kernel/utils/*.dart` (log.dart, memory_monitor.dart), `lib/kernel/player_services.dart`, `test/contracts/*.dart`, `test/engine/fvp_engine_contract_test.dart`
**Files scanned:** 13 (media_engine.dart, engine_state_view.dart, playback_control.dart, volume_control.dart, fvp_engine.dart [partial + grep], memory_monitor.dart, engine_metrics.dart, engine_event_log.dart, log.dart, player_services.dart, contract_test_runner.dart, fvp_engine_contract_test.dart, CONTEXT.md/RESEARCH.md)
**Pattern extraction date:** 2026-07-18
