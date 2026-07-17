# Phase 16: DiagnosticsBundle - Research

**Researched:** 2026-07-17
**Domain:** Internal architecture seam — Strangler Fig adapter (`KernelAdapter implements MediaEngine`) + diagnostics carrier skeleton (`DiagnosticsBundle`), pure Dart, zero new third-party dependencies.
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — DiagnosticsBundle 形状 (D1-D11)**
- D1: `DiagnosticsBundle` 是一个 `final class`（不是 sealed/abstract），持有 4 个 final 槽位字段。
- D2: 4 槽位类型为新抽象接口：`KernelLogger`、`MemoryMonitorSlot`、`MetricsSlot`、`EventLogSlot` — 命名避免与既有具体类 `MemoryMonitor`/`EngineMetrics`/`EngineEventLog`冲突。
- D3: 本阶段所有槽位实现均为 noop（不接入真实 Phase 17/18/19 能力），仅建立契约形状与注入点。
- D4: `DiagnosticsBundle.noop()` 是唯一的 const 工厂构造函数，供 Phase 16 默认使用。
- D5: `KernelLogger` 抽象类含 6 个方法：`trace/debug/info/warn/error/fatal`，与既有 `log*.t/d/i/w/e/f` 调用前缀对应。
- D6: `error()`/`fatal()` 签名是否需要 `{Object? error, StackTrace? stackTrace}` 扩展 —由日志调用点普查决定（本研究的核心任务之一，见下方 D6 Log Call-Site Census）。
- D7: KernelLogger 契约本阶段止步于方法签名 — 不新增 LogLevel enum、不新增 sink 接口。
- D8: 契约到既有 `log.e/w/i/d/t/f` 前缀的级别映射表由本阶段确定并文档化，供 Phase 17 实现时对齐。
- D9: `MemoryMonitorSlot`/`MetricsSlot`/`EventLogSlot` 的最小方法集合从既有具体类（`MemoryMonitor`/`EngineMetrics`/`EngineEventLog`）的公开 API 中提炼，但类型/类名不可与现有具体类冲突。
- D10: 槽位契约不携带既有具体类的实现细节（如 `MemoryMonitor` 的 static 单例模式不进入抽象契约）。
- D11: 槽位契约止步于本阶段最小可用集合 — 不预先设计 Phase 17/18/19 尚未确定的能力。

**Area 2 — 适配层构造签名 + DelegationPolicy (D12-D19)**
- D12: `KernelAdapter` 构造函数接受 `legacy`（旧 FvpEngine 实例）与 `migrated`（新引擎实例，Phase 16 阶段可与 legacy 相同或为占位）两个 `MediaEngine` 参数，以及一个 `DelegationPolicy` 与一个 `DiagnosticsBundle`（默认 `.noop()`）。
- D13: `KernelAdapter implements MediaEngine`（复合 7 接口），不新增自有公开成员。
- D14: `DelegationPolicy` 是一个结构体，含 7 个 `KernelMode` 字段（对应 MediaEngine 的 7 个子接口各一个），Phase 16 阶段全部为 `KernelMode.legacy`（`DelegationPolicy.all(KernelMode.legacy)`）。
- D15: `KernelMode` 是唯一仲裁者枚举：`{ legacy, migrated }`。
- D16: 旧引擎（all-legacy 适配器）作为回滚路径需在 Phase 20 切换后保持存活（不 dispose），直到 Phase 21 折叠阶段才释放。
- D17: 适配层除 `KernelMode` 引用 + 统一 `openGeneration` 计数器外不持有其它可变状态。
- D18: 适配层的 `openGeneration` 计数器由适配层统一持有（唯一数据源），不与 legacy 引擎内部的 `_openGeneration` 双写。
- D19: Phase 16 阶段的 `migrated` 引擎参数允许传入与 `legacy` 相同的实例（因为 NewFvpEngine 尚不存在，Phase 20 才引入）。

**Area 3 — openGeneration Phase 16 立场 (D20-D23)**
- D20: Phase 16 不迁移/不重写 FvpEngine 内部现有的 `_openGeneration` 逻辑 — 保持 FvpEngine 原样不变。
- D21: 适配层新增自己的 `openGeneration` 计数器，与 FvpEngine 内部计数器并存（Phase 16 阶段两者独立，因为 legacy 路径 100% 转发到 FvpEngine，FvpEngine 内部计数器仍然生效于其自身异步保护）。
- D22: 静态 grep 门禁验证：适配层代码中不出现第二个 `_openGeneration` 数据源引用（即 `grep -r '_openGeneration' lib/kernel/adapter/` 必须为 0 命中）— 确保没有意外的双数据源。
- D23: ADAPT-04 的“无双数据源”约束在 Phase 16 阶段的精确含义是：适配层自身只有一个 generation 计数器；FvpEngine 内部计数器不算作“适配层的第二数据源”，因为它是被完全转发路径包裹的实现细节，不被适配层直接读取或写入。

**Area 4 — 验证/尺寸预算/red-team 时机 (D24-D27)**
- D24: 测试组织为三层结构：(1) 复用 Phase 15 的 7 个 contract test 文件对 `KernelAdapter` 挂载一次（验证适配层满足全部 ISP 契约）；(2) 新增适配层专属单元测试（DelegationPolicy 路由正确性、DiagnosticsBundle 注入、openGeneration 计数器行为）；(3) 新增 `same()` 身份测试验证 ValueNotifier 转发不重新包装。
- D25: 对 `EngineStateView` 的每一个 ValueNotifier 字段编写 `same()`（引用相等而非值相等）断言测试，验证 `KernelAdapter.X` 与 legacy 引擎的 `X` 是同一对象实例。
- D26: red-team 验证仅在 PLAN 阶段进行一次（不在 VERIFY 阶段重复整轮 red-team），VERIFY 阶段改为对照 PLAN 阶段产出的检查表做比对。
- D27: 尺寸预算门禁：适配层 + diagnostics（合计 6 个文件）用 `wc -l`（含注释和空行）计总行数，必须 < 636 行（当前 `fvp_engine.dart` 的实测行数）。

### Claude's Discretion
- D6 的 `error()`/`fatal()` 签名具体扩展形式（本研究已给出普查结论，建议方案见下）。
- DiagnosticsBundle 4 槽位抽象接口的确切方法命名与最小方法集合（在不与既有具体类冲突、不引入未确定能力的前提下）。
- KernelAdapter 内部如何组织 7 个子接口的委派代码（每接口一个 mixin，或单文件内按接口分组的方法块）— 只要满足 D27 尺寸预算和 D22/D25 的可验证性即可。
- 契约测试挂载文件的具体路径与命名（遵循 Phase 15 既有 `test/engine/fvp_engine_contract_test.dart` 命名惯例）。

### Deferred Ideas (OUT OF SCOPE)
- Phase 17: 真实 `KernelLogger` 实现接入既有 5 个 `Logger` 实例（`log/logEngine/logBridge/logServices/logUi`），LogLevel enum，日志 sink/重定向 API，敏感信息 redaction。
- Phase 18: 真实错误处理能力接入 `MetricsSlot`/`EventLogSlot`。
- Phase 19: 真实内存监控能力接入 `MemoryMonitorSlot`（当前 `MemoryMonitor` 静态单例的替代）。
- Phase 20: `NewFvpEngine` 的真实实现与 per-capability `KernelMode.migrated` 切换。
- Phase 21: 旧 `FvpEngine`/回滚适配器的最终折叠与释放。
- 任何关于 DiagnosticsBundle 槽位未来能力形状的预先设计（Phase 16 只建立契约骨架）。
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADAPT-01 | `KernelAdapter implements MediaEngine`，100% 路由到旧引擎，零行为变更，全测试套件绿 | Full 7-interface member enumeration (Architecture Patterns); FvpEngine baseline read (636 lines, `open()` generation-guard pattern at lines 259/267/311/320); existing 7-file contract test suite confirmed reusable via `run*ContractTests(() => KernelAdapter(...))` factory swap (Validation Architecture) |
| ADAPT-02 | `DiagnosticsBundle` 载体（`KernelLogger` + `MemoryMonitor` + `EngineMetrics` + `EngineEventLog`），含 `noop` 默认，构造注入 | Public API inspection of `MemoryMonitor` (193 lines), `EngineEventLog` (103 lines), `EngineMetrics` (91 lines) to derive minimal abstract slot interfaces (Don't Hand-Roll, Code Examples); D6 log call-site census resolves `KernelLogger.error/fatal` signature |
| ADAPT-03 | 适配层转发活动引擎的 `ValueNotifier` 实例（不重新包装），`ValueListenableBuilder` 监听器不脱钩 | EngineStateView's 13-notifier enumeration + FvpEngine's 10-owned/3-delegated split (Architecture Patterns); `same()` identity test pattern specified (Validation Architecture, D25) |
| ADAPT-04 | 单一 `KernelMode { legacy, migrated }` 仲裁者 + 由适配层持有的统一 `openGeneration` 计数器，无双数据源 | FvpEngine's existing `_openGeneration` field/guard sites documented (line 194/259/267/311/320); grep-gate design for D22 (Validation Architecture); D20/D21/D23 clarify FvpEngine's internal counter is not a competing "adapter data source" |
| ADAPT-05 | 尺寸预算受控 — 适配层+门面+sealed 错误+tracker 合计 < 旧 `FvpEngine`；适配层除 `KernelMode`+generation 计数器外无状态 | `wc -l` baseline confirmed exactly 636 lines (Standard Stack / Validation Architecture); 6-file budget breakdown proposed (Architecture Patterns) |
</phase_requirements>

## Summary

Phase 16 builds a **branch-by-abstraction seam**, not a new capability. The entire task is internal to this repository: read the existing `MediaEngine` composite interface (7 sub-interfaces, zero members of its own), the single concrete implementation `FvpEngine` (636 lines, confirmed via `wc -l`), and three existing diagnostics classes (`MemoryMonitor`, `EngineMetrics`, `EngineEventLog`), then produce (a) a `KernelAdapter` that implements `MediaEngine` by forwarding every call/notifier to a wrapped `legacy` engine with zero behavioral change, and (b) a `DiagnosticsBundle` carrier with four noop abstract slots that gives Phases 17-20 a construction-injected home to attach real capabilities later.

No new third-party packages are required — this is pure Dart interface/class design using only `package:flutter/foundation.dart` (`ValueNotifier`) which is already a transitive dependency of every file in `lib/kernel/engine/`. The research in this document is therefore almost entirely **live-code verification** (grep counts, `wc -l`, full interface enumeration) rather than external documentation lookup — there is no external ecosystem to research for an internal seam pattern.

The single genuinely open technical question — whether `KernelLogger.error()`/`fatal()` need a `{Object? error, StackTrace? stackTrace}` extension (D6) — is answered definitively by an exhaustive call-site census: **84 total log calls exist in `lib/` today** (48 `.e`, 7 `.w`, 12 `.i`, 17 `.d`, 0 `.t`, 0 `.f`), of which exactly 3 `.e()` calls use named `error:`/`stackTrace:` parameters in 2 distinct shapes. Both optional named parameters are required on `error()` to statically express every live call site without behavior change. `fatal()` has zero live call sites — its signature must be extrapolated by symmetry with `error()`, which is flagged as `[ASSUMED]` in the Assumptions Log.

**Primary recommendation:** Build `KernelAdapter` as a single file with 7 clearly-delimited method blocks (one per `MediaEngine` sub-interface, following the interface declaration order), each block a straight `mode == KernelMode.legacy ? _legacy.x : _migrated.x` per-capability dispatch driven by `DelegationPolicy`. Build the 4 `DiagnosticsBundle` slot interfaces as minimal method-set abstractions (not full ports of the concrete classes' APIs) plus one `NullXxx` noop implementation apiece, and keep the whole 6-file bundle under 550 lines to leave comfortable margin under the 636-line ADAPT-05 ceiling.

## Architectural Responsibility Map

This project has no browser/SSR/CDN tiers (desktop Flutter app over MDK/FFmpeg via `fvp`). The relevant tiers are the project's own layered architecture from `CLAUDE.md`: **Kernel/Engine** (playback engine abstraction + concrete implementation), **Bridge** (native Win32 interop, not touched by this phase), **Service** (orchestration, e.g. `PlaybackController`), **UI** (widgets).

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| MediaEngine routing (KernelAdapter) | Kernel/Engine | — | Sits at the exact same architectural position as `FvpEngine` today — a drop-in `MediaEngine` implementation, constructed in `PlayerServices.init()` and consumed by `PlaybackController`/`VideoProcessingService` via the interface type only |
| DiagnosticsBundle carrier | Kernel/Engine (new `lib/kernel/diagnostics/` subpackage) | — | Companion object injected alongside the adapter at construction time; not a service and not UI — it is engine-adjacent infrastructure |
| ValueNotifier identity forwarding | Kernel/Engine | UI (consumer) | The adapter (Kernel/Engine) must preserve identity; the UI's `ValueListenableBuilder` widgets are the reason identity matters — a UI-tier concern enforced at the Kernel/Engine tier |
| openGeneration arbitration | Kernel/Engine | — | Both the existing FvpEngine-internal counter and the new adapter-level counter live entirely inside the Kernel/Engine tier; Service tier (`PlaybackNavigator`) only reads engine state, never touches generation counters directly |
| DelegationPolicy / KernelMode | Kernel/Engine | Service (composition root: `PlayerServices.init()`) | The policy struct is constructed once at the composition root (Service tier boundary) but consumed entirely inside Kernel/Engine (the adapter) |

## Standard Stack

### Core
No new libraries. This phase is 100% internal Dart code using facilities already present in the project.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `package:flutter/foundation.dart` (SDK-bundled) | Flutter SDK (already pinned by project) | `ValueNotifier<T>`/`ChangeNotifier` — the notifier type every `EngineStateView`/`VolumeControl` member returns | Already the exclusive state-notification primitive project-wide per `CLAUDE.md` ("ValueNotifier + ValueListenableBuilder, no Provider/Riverpod/Bloc") `[VERIFIED: live code — lib/kernel/engine/engine_state_view.dart imports foundation.dart]` |

### Supporting
None — no supporting libraries needed. Dart core (`dart:core`) suffices for `KernelMode` enum, `DelegationPolicy` struct, and all 4 diagnostics slot abstract classes.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled `DelegationPolicy` struct (7 `KernelMode` fields) | A single `Map<Type, KernelMode>` keyed by sub-interface `Type` | Map lookup is stringly/reflectively fragile and loses compile-time exhaustiveness checking; the struct approach (locked by D14) is strictly better for a fixed 7-interface set |
| Per-capability struct fields | A single project-wide `KernelMode` (no per-capability granularity) | Rejected explicitly in `16-DISCUSSION-LOG.md` — blocks Phase 20's incremental per-capability cutover, which is the entire reason this phase exists |

**Installation:** N/A — no new dependencies. `pubspec.yaml` is unchanged by this phase.

**Version verification:** N/A — no packages to verify. Confirmed no `pubspec.yaml` diff is required by grepping for any new `import 'package:'` lines this phase would need: none exist beyond `package:flutter/foundation.dart`, which is already a transitive dependency of `lib/kernel/engine/*.dart` today `[VERIFIED: live code — grep of existing engine interface files]`.

## Package Legitimacy Audit

**N/A — no new packages introduced in this phase.** Phase 16 adds only pure-Dart abstract classes, one concrete adapter class, and one struct/enum pair inside the existing `lib/kernel/` tree. No `pubspec.yaml` changes are required. The Package Legitimacy Gate protocol is not applicable.

**Packages removed due to [SLOP] verdict:** none (N/A)
**Packages flagged as suspicious [SUS]:** none (N/A)

## Architecture Patterns

### System Architecture Diagram

```
PlayerServices.init()                                    [Service/composition root]
        |
        |  constructs:
        |    legacy   = FvpEngine()                       (unchanged, 636 lines)
        |    migrated  = legacy   (Phase 16: same instance — NewFvpEngine doesn't exist yet)
        |    policy   = DelegationPolicy.all(KernelMode.legacy)
        |    bundle   = DiagnosticsBundle.noop()
        v
   KernelAdapter(legacy, migrated, policy, bundle)          [Kernel/Engine — NEW]
        |  implements MediaEngine (7 ISP sub-interfaces, zero own members)
        |
        |  per-capability dispatch (driven by `policy.<capability>`):
        |
        +--> EngineStateView   --> policy.stateView   == legacy ? legacy.X   : migrated.X   (forward notifier, don't rewrap)
        +--> PlaybackControl   --> policy.playback    == legacy ? legacy.Y() : migrated.Y()
        +--> TrackControl      --> policy.track       == legacy ? legacy.Z() : migrated.Z()
        +--> SubtitleConfig    --> policy.subtitle    == legacy ? ...       : ...
        +--> VideoEffectControl-> policy.videoEffect  == legacy ? ...       : ...
        +--> RendererControl   --> policy.renderer    == legacy ? ...       : ...
        +--> VolumeControl     --> policy.volume      == legacy ? ...       : ...
        |
        |  owns: _openGeneration (adapter-local counter, ADAPT-04) — single source of truth
        |         KernelMode fields (via policy) — no other mutable state (D17)
        v
   engine: MediaEngine  ------------------------------------>  consumed identically to today by:
        |                                                         PlaybackController (engine: MediaEngine, interface-typed)
        |                                                         VideoProcessingService (engine, interface-typed)
        |                                                         UI ValueListenableBuilder<T>(valueListenable: engine.position, ...)
        v
   DiagnosticsBundle (bundle field, injected, not routed by policy)
        |
        +--> KernelLogger        (noop in P16; real impl arrives Phase 17)
        +--> MemoryMonitorSlot   (noop in P16; real impl arrives Phase 19)
        +--> MetricsSlot         (noop in P16; real impl arrives Phase 18)
        +--> EventLogSlot        (noop in P16; real impl arrives Phase 18)
```

Primary use-case trace: a UI widget calls `engine.play()` (through `PlaybackController`) → `KernelAdapter.play()` looks up `policy.playback` (== `KernelMode.legacy` in Phase 16) → forwards synchronously to `_legacy.play()` → `FvpEngine.play()` executes unchanged → any resulting `state`/`position` notifier update is observed by the UI's `ValueListenableBuilder` because the notifier object handed out by `KernelAdapter.state` **is** `_legacy.state` (same instance, not a wrapper) — this is the ADAPT-03 identity guarantee.

### Recommended Project Structure
```
lib/kernel/
├── adapter/
│   ├── kernel_adapter.dart        # KernelAdapter implements MediaEngine (~200-250 lines)
│   ├── kernel_mode.dart           # enum KernelMode { legacy, migrated }
│   └── delegation_policy.dart     # final class DelegationPolicy (7 KernelMode fields + .all() factory)
└── diagnostics/
    ├── diagnostics_bundle.dart    # final class DiagnosticsBundle (4 slots + .noop() factory + dispose())
    ├── kernel_logger.dart         # abstract class KernelLogger + NullKernelLogger
    └── diagnostics_slots.dart     # abstract MemoryMonitorSlot/MetricsSlot/EventLogSlot + Null* impls
```
This is 6 files matching the ADAPT-05 file count exactly (`adapter` = 3 files, `diagnostics` = 3 files). Splitting `kernel_mode.dart`/`delegation_policy.dart` into separate small files follows the project's "many small files > few large files" convention (`CLAUDE.md`/coding-style.md), and keeps `kernel_adapter.dart` itself lean (pure dispatch logic, no enum/struct boilerplate mixed in).

### Pattern 1: Per-Capability Delegation via Struct-Driven Dispatch
**What:** Each of the 7 `MediaEngine` sub-interfaces gets its own `KernelMode` field in `DelegationPolicy`. `KernelAdapter` reads the relevant field before every forwarded call/getter.
**When to use:** Any time a single adapter must support independent per-capability migration (this is the entire reason Phase 20 can flip capabilities one at a time instead of atomically swapping the whole engine).
**Example:**
```dart
// Source: derived from lib/kernel/engine/media_engine.dart (7-interface composite)
// and lib/kernel/engine/volume_control.dart (concrete member shapes)
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

```dart
// KernelAdapter dispatch example — ValueNotifier getter (identity-preserving, ADAPT-03)
@override
ValueNotifier<double> get volume =>
    _policy.volume == KernelMode.legacy ? _legacy.volume : _migrated.volume;

// KernelAdapter dispatch example — method call (behavior-preserving, ADAPT-01)
@override
Future<void> play() =>
    _policy.playback == KernelMode.legacy ? _legacy.play() : _migrated.play();
```
**Critical:** the getter form returns the notifier object itself — never `ValueNotifier(x.value)` or any re-wrap. Re-wrapping breaks ADAPT-03 silently (existing `ValueListenableBuilder` subscriptions keep listening to the OLD notifier while the app logic mutates the NEW one).

### Pattern 2: Noop Diagnostics Slot with Const Factory
**What:** Each `DiagnosticsBundle` slot is an abstract class with a minimal method set (derived from, but not identical to, the corresponding concrete class's public API) plus a `Null*` implementation that does nothing.
**When to use:** Whenever a future capability needs a construction-time seam before its real implementation exists.
**Example (KernelLogger — the most detailed slot due to D6's signature requirement):**
```dart
// Source: derived from lib/kernel/utils/log.dart level-prefix convention
// (log.t/d/i/w/e/f) cross-referenced against a live call-site census.
abstract class KernelLogger {
  void trace(String message);
  void debug(String message);
  void info(String message);
  void warn(String message);
  // `error`/`fatal` need both optional named params: exactly 3 of 84 live
  // call sites in lib/ pass `error:`/`stackTrace:` today (see Common
  // Pitfalls -> D6 Log Call-Site Census for full breakdown).
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
**DiagnosticsBundle carrier:**
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

### Anti-Patterns to Avoid
- **Re-wrapping notifiers in the adapter:** `ValueNotifier<double> get volume => ValueNotifier(_legacy.volume.value)` looks correct at a glance (same current value) but breaks `ValueListenableBuilder` subscriptions the instant either side rebuilds — this is Blocking Constraint #6 from ROADMAP.md and the exact failure mode D25's `same()` tests exist to catch.
- **Porting full concrete-class APIs into abstract slots:** e.g. giving `MemoryMonitorSlot` a `static` method or a `snapshotNotifier` field identical to `MemoryMonitor`'s shape. D9/D10 explicitly forbid importing implementation details (static singleton pattern, concrete field names) into the abstract contract — the contract should be the minimal method set Phase 17-19 need, not a mirror of today's class.
- **Building a project-wide `KernelMode` instead of per-capability:** rejected in `16-DISCUSSION-LOG.md` for exactly this phase — collapses Phase 20's incremental cutover capability, which is the entire reason `DelegationPolicy` exists as a 7-field struct rather than a single enum value.
- **Skipping the openGeneration counter because "legacy already has one":** ADAPT-04 requires the *adapter* to own the arbitration source; FvpEngine's internal `_openGeneration` (line 194) remains as an implementation detail of the wrapped legacy engine, not a substitute for the adapter's own counter (D18/D21/D23).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-interface routing table | A generic reflection/`Map<Type, dynamic>`-based dispatcher | Direct field-per-capability struct (`DelegationPolicy`) + explicit `if/switch` per method | Reflection is unavailable in Dart AOT release builds for this pattern's needs, and a 7-field struct is both faster and statically checkable — no framework needed for a fixed, small interface set |
| Contract verification | New bespoke test harness | The 7 existing `test/contracts/*_contract.dart` files + `contract_test_runner.dart` aggregator (Phase 15, D13/D14) | Already designed for exactly this reuse — swap only the `MediaEngine Function()` factory passed to each `run*ContractTests` call; verified present and working against `FvpEngine` today |
| ValueNotifier identity checks | Custom equality/diffing helper | `package:test`'s built-in `same()` matcher (reference-identity matcher, not `equals()`) | `same()` is exactly the semantic D25 needs and ships in `package:matcher` (transitive via `flutter_test`), already used project-wide |

**Key insight:** Every tool needed for this phase already exists in the repository or the Flutter SDK. The temptation to hand-roll is highest around "diagnostics slot interfaces" (it's tempting to just reuse `MemoryMonitor`/`EngineMetrics`/`EngineEventLog` directly as the slot types) — resist this per D9/D10; the abstract contract must be independently named and minimal, decoupled from today's concrete implementations so Phase 17-19 can swap internals freely.

## Common Pitfalls

### Pitfall 1: D6 Log Call-Site Census (the concrete evidence behind the `KernelLogger.error/fatal` signature decision)
**What goes wrong:** Assuming `error(String message)` (single positional arg, matching the *majority* shape) is sufficient, then discovering during Phase 17's real migration that 3 call sites need `error:`/`stackTrace:` and must be silently dropped or badly reshaped.
**Why it happens:** Without an exhaustive census, it's easy to eyeball a few call sites and miss the minority shapes.
**How to avoid:** Use the full census below (obtained via exhaustive grep of every `.e(`/`.w(`/`.i(`/`.d(`/`.t(`/`.f(` call site in `lib/`, excluding `test/`) `[VERIFIED: live grep — this session]`:

| Level | Total call sites | Shape breakdown |
|-------|------------------|------------------|
| `.e(` (error) | 48 | 44 sites: single positional `String message` only. 2 sites: `error:` AND `stackTrace:` named params (`lib/features/player/deferred_player_feature.dart:106-110`, `lib/features/player/player_feature.dart:135`). 2 sites: `stackTrace:` only, no `error:` (`lib/kernel/services/auto_advance_policy.dart:59,69`). |
| `.w(` (warn) | 7 | All single positional message only. |
| `.i(` (info) | 12 | All single positional message only. |
| `.d(` (debug) | 17 | All single positional message only. |
| `.t(` (trace) | 0 | Unused in codebase today. |
| `.f(` (fatal) | 0 | Unused in codebase today. |
| **Total** | **84** | Matches `.planning/phases/15-.../15-BASELINE-AUDIT.json` total exactly (`total_call_sites: 84`) `[VERIFIED: matches independent audit script output]` |

**Conclusion (satisfies D6):** `KernelLogger.error(String message, {Object? error, StackTrace? stackTrace})` — both named params optional/nullable — statically expresses all 3 non-default shapes (2-both-named + 2-stackTrace-only) without forcing any call-site behavior change. `fatal()` should mirror `error()`'s signature by symmetry with D8's level-mapping table, but **this is an extrapolation with zero live evidence** (see Assumptions Log A1).
**Warning signs:** If Phase 17 discovers a 4th shape (e.g. a call site passing only `error:` without `stackTrace:`), the signature already accepts it (both are independently optional) — no further extension needed.

### Pitfall 2: Interface Member Overlap Across MediaEngine's 7 Sub-Interfaces
**What goes wrong:** Attempting to route `setVolume`/`setMute` "twice" (once as `PlaybackControl.setVolume` and once as `VolumeControl.setVolume`) via two separate `DelegationPolicy` fields, or writing duplicate forwarding code for `volume`/`isMuted` under both `EngineStateView` and `VolumeControl`.
**Why it happens:** `MediaEngine`'s 7 sub-interfaces are not fully disjoint. Concretely `[VERIFIED: live code enumeration]`:
- `PlaybackControl.setVolume(double)` / `PlaybackControl.setMute(bool)` (lib/kernel/engine/playback_control.dart) have **identical signatures** to `VolumeControl.setVolume(double)` / `VolumeControl.setMute(bool)` (lib/kernel/engine/volume_control.dart).
- `EngineStateView.volume` / `EngineStateView.isMuted` (both `ValueNotifier`-typed getters) **duplicate** `VolumeControl.volume` / `VolumeControl.isMuted` exactly.
A single Dart method/getter override in `KernelAdapter` satisfies both interface contracts simultaneously — Dart's interface composition means implementing the member once is sufficient regardless of how many parent interfaces declare it.
**How to avoid:** Route `setVolume`/`setMute`/`volume`/`isMuted` under `DelegationPolicy.volume` (the `VolumeControl` field) exactly once; do not create a separate `PlaybackControl`-specific branch for these particular members, and do not create a separate `EngineStateView`-specific branch for `volume`/`isMuted`. The `policy.playback` field governs the OTHER 10 `PlaybackControl` methods (open/play/pause/stop/togglePlayPause/seekTo/setPlaybackRate/setRange/skipForward/skipBack); `policy.stateView` governs the OTHER 11 `EngineStateView` notifiers.
**Warning signs:** If `DelegationPolicy` ever needs `policy.playback != policy.volume` in a way that changes `setVolume`'s actual routing target, this ambiguity becomes a real bug — flag as an Open Question for the planner to make an explicit decision on which field wins (recommend: `volume` field wins for these 4 shared members, since `VolumeControl` is the more specific/dedicated interface).

### Pitfall 3: Dead-Code Bundle Temptation
**What goes wrong:** Building out speculative real functionality inside the "noop" slots because "we already know roughly what Phase 17/18/19 need."
**Why it happens:** Natural momentum once the shape of a slot interface is visible.
**How to avoid:** D11 explicitly caps scope at "minimal usable set for this phase" — resist adding methods not required to make `DiagnosticsBundle.noop()` compile and the adapter forward calls somewhere. Every extra method is: (a) size-budget risk against the 636-line ADAPT-05 ceiling, and (b) speculative design that Phase 17-19's own research/planning may contradict.
**Warning signs:** A slot interface method that has no current caller and no direct mapping to an existing concrete class method (`MemoryMonitor`/`EngineMetrics`/`EngineEventLog`)'s existing public API is very likely premature.

### Pitfall 4: Losing the FvpEngine-Internal openGeneration Guard by Accident
**What goes wrong:** Refactoring `FvpEngine.open()` "for consistency" while building the adapter, inadvertently touching lines 259/267/311/320 (the existing generation-guard checks).
**Why it happens:** The adapter work and the FvpEngine-reading work happen in the same session, increasing the chance of an accidental edit.
**How to avoid:** D20 is explicit — `FvpEngine` is untouched in Phase 16. The adapter's own counter (ADAPT-04) is a *new, separate* field inside `KernelAdapter`, incremented/checked only around the adapter's own `open()` forwarding call, never inside `FvpEngine`. Verify via `git diff --stat lib/kernel/engine/fvp_engine.dart` returning empty after Phase 16 work completes.
**Warning signs:** Any diff touching `lib/kernel/engine/fvp_engine.dart` during this phase is a scope violation.

## Code Examples

### MediaEngine full interface surface (verbatim structure)
```dart
// Source: lib/kernel/engine/media_engine.dart (32 lines, fully read)
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

### FvpEngine's existing openGeneration guard (the pattern the adapter's own counter must NOT duplicate/collide with)
```dart
// Source: lib/kernel/engine/fvp_engine.dart:194,259,267,311,320 (untouched by Phase 16, D20)
int _openGeneration = 0;  // line 194

// inside open():
final gen = ++_openGeneration;                                   // line 259
// ... async work ...
if (_disposed || gen != _openGeneration) return;                  // line 267 (early success-path guard)
// ... catch block ...
if (_disposed || gen != _openGeneration) return;                  // line 311 (error-path guard, same pattern)
// ... finally block ...
if (gen == _openGeneration) { isBuffering.value = false; }        // line 320
```
The adapter's new counter is structurally analogous but lives in a different file/class and guards a different (adapter-level) `open()` call — it does not read or write `_openGeneration` above (that identifier is `private` to `FvpEngine` and inaccessible outside the file regardless).

### EngineStateView full member enumeration (for D25's `same()` test suite — one assertion per notifier)
```dart
// Source: lib/kernel/engine/engine_state_view.dart (65 lines, fully read)
abstract class EngineStateView {
  ValueNotifier<int?> get textureId;
  ValueNotifier<MediaState> get state;
  ValueNotifier<int> get position;
  ValueNotifier<int> get duration;
  ValueNotifier<double> get volume;          // ALSO declared on VolumeControl — see Pitfall 2
  ValueNotifier<bool> get isMuted;           // ALSO declared on VolumeControl — see Pitfall 2
  ValueNotifier<bool> get isBuffering;
  ValueNotifier<bool> get isSeeking;
  ValueNotifier<String> get subtitleText;
  ValueNotifier<int> get buffered;
  ValueNotifier<double> get aspectRatio;
  ValueNotifier<PlayerError?> get lastError;
  ValueNotifier<double> get playbackSpeed;
  MediaInfo get mediaInfo;                   // plain getter, NOT a ValueNotifier — no same() test needed
  void dispose();
}
```
13 `ValueNotifier` fields require a `same()` assertion each (D25). `mediaInfo` is a plain value getter (not a notifier) and `dispose()` is a method — neither needs identity testing.

### Contract test reuse pattern (D24, layer 1) — already built in Phase 15, confirmed working
```dart
// Source: test/engine/fvp_engine_contract_test.dart:58-69 (fully read, currently mounts against FvpEngine)
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
Phase 16's new mount point (e.g. `test/adapter/kernel_adapter_contract_test.dart`) changes ONLY the factory:
```dart
runEngineStateViewContractTests(
  () => KernelAdapter(
    legacy: FvpEngine(),
    migrated: FvpEngine(), // Phase 16: same concrete type, D19
    policy: const DelegationPolicy.all(KernelMode.legacy),
    bundle: const DiagnosticsBundle.noop(),
  ),
);
// ... repeat for the other 6 run*ContractTests functions
```
This is explicitly the reuse seam documented in the contract runner's own doc comment: *"This indirection is what makes the contract suite reusable against a future NewFvpEngine (Phase 21) by swapping only the factory"* `[VERIFIED: test/contracts/contract_test_runner.dart:9-12]` — the same mechanism applies one phase earlier, to `KernelAdapter` itself.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Direct `FvpEngine()` construction in `PlayerServices.init()` (`engine = FvpEngine();`, line 87) | `KernelAdapter(legacy: FvpEngine(), migrated: ..., policy: ..., bundle: ...)` | Phase 16 (this phase) | The single line at `lib/kernel/player_services.dart:87` is the entire integration surface this phase must change in application code — no other file constructs an engine |
| "121 log call sites" (historical estimate cited in `REQUIREMENTS.md`/`ROADMAP.md` for LOG-04) | **84 log call sites / 28 files** (live re-audit, Phase 15 `15-BASELINE-AUDIT.json`, independently re-confirmed via direct grep in this session: 48+7+12+17+0+0 = 84) | Phase 15 baseline audit (2026-07-17) | **The planner must use 84, not 121**, for any LOG-04-adjacent sizing/scoping decisions. The 121 figure predates the current codebase state (likely an early, imprecise estimate from before some consolidation/dedup) and should be treated as stale everywhere it appears in older docs. |

**Deprecated/outdated:**
- The "121 处调用点" figure in `.planning/REQUIREMENTS.md`'s LOG-04 description is outdated; supersede with the live 84-count census documented in Pitfall 1 above.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `KernelLogger.fatal()` should mirror `error()`'s signature (`{Object? error, StackTrace? stackTrace}`) by symmetry with D8's level-mapping table | Code Examples / Pitfall 1 | Zero live call sites exist for `.f(` today, so this is pure extrapolation. If Phase 17 introduces a `fatal()` call with a different shape (e.g. requiring non-nullable `error`), the signature would need a breaking change at that point. Low risk in practice since `fatal()` is unused today and adding an unused method with a slightly wrong signature costs nothing until first real use. |
| A2 | Shared members between interfaces (`setVolume`/`setMute`/`volume`/`isMuted`) should route via the `VolumeControl` `DelegationPolicy` field, not `PlaybackControl`/`EngineStateView` | Pitfall 2 | If the planner instead splits these across two policy fields with potentially different `KernelMode` values, Dart's single-method-satisfies-multiple-interfaces semantics make the "other" field's value silently unobservable (whichever field is checked in the actual method body wins, always) — a latent bug source. Recommend explicit planner decision to route via `VolumeControl` and document that `PlaybackControl.setVolume`/`EngineStateView.volume` are aliases satisfied by the same code path. |
| A3 | `MemoryMonitorSlot`/`MetricsSlot`/`EventLogSlot` minimal method sets (not yet designed in code — left to Claude's Discretion per CONTEXT.md) should closely track but not copy the existing concrete classes' public APIs | Don't Hand-Roll / Architecture Patterns | If Phase 17-19 need methods not anticipated by Phase 16's minimal slot design, the abstract interface will need extension later — acceptable per D11 (scope explicitly capped at "minimal usable set"), but the planner should not treat Phase 16's slot shape as final/frozen. |

**If this table is empty:** N/A — see entries above.

## Open Questions

1. **Should `PlaybackControl`'s 10 non-overlapping methods and `VolumeControl`'s 4 members share one `DelegationPolicy` field, or is the current 7-field 1:1 mapping with sub-interfaces correct as-is?**
   - What we know: D14 locks "7 KernelMode fields (one per MediaEngine sub-interface)" — this is a locked decision, not open for research to relitigate.
   - What's unclear: How `KernelAdapter`'s single implementation of `setVolume`/`setMute`/`volume`/`isMuted` should be *labeled* internally when both `policy.playback`/`policy.stateView` AND `policy.volume` nominally govern them.
   - Recommendation: Route these 4 shared members exclusively through `policy.volume` in the adapter implementation (per Assumption A2); document this explicitly in a code comment at the point of implementation so future readers don't assume `policy.playback` affects `setVolume`'s behavior.

2. **Does `migrated: FvpEngine()` (a second, distinct instance per D19's "allowed" wording) or `migrated` == `legacy` (identical instance) better serve Phase 16's zero-behavior-change goal?**
   - What we know: D19 explicitly permits either; D14/D21 establish that Phase 16 routes 100% to `legacy` regardless.
   - What's unclear: Whether constructing a second `FvpEngine()` instance (even though unused, since `policy` is all-legacy) risks any resource/side-effect duplication (e.g., does `FvpEngine`'s factory constructor allocate native resources eagerly?).
   - Recommendation: Pass `migrated: legacy` (the same instance) in Phase 16 — this avoids any question of duplicate resource allocation and matches "Phase 16: same instance" language already used in this document's diagrams and code examples. The planner should make this the explicit default in the plan's task descriptions to avoid ambiguity.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependencies beyond the Dart/Flutter SDK already required to build the project at all. No new CLI tools, databases, or network services are introduced.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (Dart VM test runner via `flutter test`), `package:test`'s `matcher` library for `same()` |
| Config file | none dedicated — project uses default `flutter test` discovery over `test/` |
| Quick run command | `flutter test test/adapter/` (new adapter-specific unit + identity tests, once created) |
| Full suite command | `flutter test` (entire suite, including the 7 reused contract test files mounted against `KernelAdapter`) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADAPT-01 | `KernelAdapter` satisfies all 7 ISP contracts with zero behavior change vs. `FvpEngine` | contract (integration-style, mounts real `FvpEngine` inside adapter) | `flutter test test/adapter/kernel_adapter_contract_test.dart` | ❌ Wave 0 — new mount point, reuses existing `test/contracts/*.dart` bodies unchanged |
| ADAPT-01 | Full existing suite remains green after `engine = FvpEngine()` -> `engine = KernelAdapter(...)` swap at `player_services.dart:87` | regression (full suite) | `flutter test` | ✅ — existing suite already covers `PlaybackController`/`VideoProcessingService` behavior transitively |
| ADAPT-02 | `DiagnosticsBundle.noop()` constructs without error, all 4 slots callable as no-ops | unit | `flutter test test/diagnostics/diagnostics_bundle_test.dart -x` | ❌ Wave 0 — new file |
| ADAPT-02 | `KernelLogger.error()`/`fatal()` accept both named-param shapes found in the live census (both-named, stackTrace-only, neither) | unit | `flutter test test/diagnostics/kernel_logger_test.dart -x` | ❌ Wave 0 — new file |
| ADAPT-03 | Every `EngineStateView` `ValueNotifier` returned by `KernelAdapter` is `same()` as the wrapped legacy engine's notifier | unit (identity) | `flutter test test/adapter/kernel_adapter_identity_test.dart -x` | ❌ Wave 0 — new file, implements D25 |
| ADAPT-04 | Adapter's own `openGeneration` counter increments once per `open()` call; no `_openGeneration` identifier appears inside `lib/kernel/adapter/` | unit + static grep gate | `flutter test test/adapter/kernel_adapter_open_generation_test.dart -x` then `grep -rL '_openGeneration' lib/kernel/adapter/*.dart \| wc -l` (expect count == total files, i.e. 0 matches) | ❌ Wave 0 — new test file + new grep-gate script/CI step |
| ADAPT-05 | `wc -l` across the 6 new files (`lib/kernel/adapter/*.dart` + `lib/kernel/diagnostics/*.dart`) sums to < 636 | static size gate (no Dart test — shell command) | `wc -l lib/kernel/adapter/*.dart lib/kernel/diagnostics/*.dart \| tail -1` (verify total < 636) | ❌ Wave 0 — new files, gate is a shell one-liner, not a `flutter test` target |

### Sampling Rate
- **Per task commit:** `flutter test test/adapter/ test/diagnostics/` (fast, scoped to new code)
- **Per wave merge:** `flutter test` (full suite, includes the reused 7-file contract suite mounted against `KernelAdapter` plus the pre-existing mount against raw `FvpEngine` — both must stay green since `FvpEngine` itself is untouched per D20)
- **Phase gate:** Full suite green + `wc -l` size gate + `grep` dual-source gate, all three before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/adapter/kernel_adapter_contract_test.dart` — mounts the existing 7 `run*ContractTests` functions against `KernelAdapter(legacy: FvpEngine(), ...)`, covers ADAPT-01
- [ ] `test/adapter/kernel_adapter_identity_test.dart` — 13 `same()` assertions (one per `EngineStateView` notifier field), covers ADAPT-03/D25
- [ ] `test/adapter/kernel_adapter_open_generation_test.dart` — covers ADAPT-04's counter-increment behavior
- [ ] `test/diagnostics/diagnostics_bundle_test.dart` — covers ADAPT-02's noop-construction and cascading-dispose behavior
- [ ] `test/diagnostics/kernel_logger_test.dart` — covers D6's signature acceptance for all 3 live call shapes
- [ ] Static grep-gate script (D22) — no dedicated file exists yet; recommend a `tool/audit/` shell script or a CI step alongside the existing `tool/audit/inventory.sh` pattern (Phase 15 precedent)
- [ ] Static size-gate script (D27) — likewise, a `wc -l` one-liner; can be folded into the same audit script as the grep gate

## Security Domain

`security_enforcement` is absent from `.planning/config.json`'s inspected keys during this research pass, which defaults to **enabled** per the verification protocol. Assessed against this phase's actual surface:

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | This phase has no auth surface — it is an internal engine-routing seam with no user identity concept |
| V3 Session Management | No | No sessions involved |
| V4 Access Control | No | No access-control surface; all code is internal to the process |
| V5 Input Validation | No (narrow) | `KernelAdapter`'s inputs are already-validated types flowing from `PlaybackController`/UI (e.g. `String path` to `open()`) — validation, if any, is the existing `FvpEngine`'s/`PathValidator`'s responsibility, unchanged by this phase. No new external input boundary is introduced. |
| V6 Cryptography | No | No cryptographic operations in this phase |

### Known Threat Patterns for this stack
None identified as applicable — this phase introduces no new external input boundary, no new persistence, no new network surface, and no new cryptographic or authentication code. The only "threat" in scope is a correctness/regression risk (silent notifier-identity breakage per ADAPT-03), which is addressed structurally via the D25 `same()` test suite rather than via a security control.

## Sources

### Primary (HIGH confidence)
- `lib/kernel/engine/media_engine.dart` (32 lines) — MediaEngine 7-interface composite, fully read `[VERIFIED: live code]`
- `lib/kernel/engine/engine_state_view.dart` (65 lines) — 13 ValueNotifier + mediaInfo + dispose enumeration `[VERIFIED: live code]`
- `lib/kernel/engine/playback_control.dart` (113 lines) — 12-method enumeration, overlap with VolumeControl found `[VERIFIED: live code]`
- `lib/kernel/engine/track_control.dart` (29 lines), `subtitle_config.dart` (64 lines), `video_effect_control.dart` (37 lines), `renderer_control.dart` (21 lines), `volume_control.dart` (37 lines) — remaining 5 sub-interfaces fully read `[VERIFIED: live code]`
- `lib/kernel/engine/fvp_engine.dart` (636 lines, `wc -l` confirmed twice in this session) — the ADAPT-05 baseline and openGeneration reference implementation `[VERIFIED: wc -l + full read]`
- `lib/kernel/utils/memory_monitor.dart` (193 lines), `lib/kernel/engine/engine_event_log.dart` (103 lines), `lib/kernel/engine/engine_metrics.dart` (91 lines) — diagnostics slot reference shapes `[VERIFIED: live code]`
- `lib/kernel/player_services.dart` (111 lines) — exact integration point (`engine = FvpEngine();` at line 87) `[VERIFIED: live code]`
- `lib/kernel/services/playback_controller.dart` (lines 1-80 read) — confirms interface-typed `engine` field, no cast `[VERIFIED: live code]`
- `test/contracts/contract_test_runner.dart` (22 lines) + `test/engine/fvp_engine_contract_test.dart` (69 lines) — confirms the 7-file contract reuse mechanism is already built and working `[VERIFIED: live code]`
- `.planning/phases/15-contract-freeze-baseline-audit/15-BASELINE-AUDIT.json` — live re-audited call-site counts (84 total, 28 files) `[VERIFIED: prior phase audit + independently re-confirmed via grep this session]`
- Direct grep census of `.e(`/`.w(`/`.i(`/`.d(`/`.t(`/`.f(` across `lib/` (excluding `test/`) — 84 total matching the baseline audit exactly `[VERIFIED: live grep, this session]`
- Direct grep re-verification of `as FvpEngine` (0 hits) and the 5 convenience-getter usages (0 hits) in `lib/` `[VERIFIED: live grep, this session]`
- `.planning/phases/16-diagnosticsbundle/16-CONTEXT.md` (167 lines) — 27 locked decisions D1-D27 `[CITED: project planning doc, authoritative for scope]`
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/config.json` — phase requirements, success criteria, workflow flags `[CITED: project planning docs]`

### Secondary (MEDIUM confidence)
None — no external/web sources were needed for this phase; the entire research surface is internal to the repository.

### Tertiary (LOW confidence)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new libraries; confirmed zero new `pubspec.yaml` entries needed via direct code inspection.
- Architecture: HIGH — every interface member and every concrete class's public API was read in full, not sampled.
- Pitfalls: HIGH for the log-census and interface-overlap findings (both independently grep-verified); MEDIUM for the `fatal()` signature extrapolation (flagged `[ASSUMED]` in Assumptions Log, A1).

**Research date:** 2026-07-17
**Valid until:** Stable — this research documents the current state of an internal, slow-moving interface (`MediaEngine` and its 7 sub-interfaces have not changed since Phase 14/15). No external ecosystem drift risk. Re-verify only if `lib/kernel/engine/*.dart` or `lib/kernel/utils/log.dart` changes before planning begins.
