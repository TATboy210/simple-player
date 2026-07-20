# Phase 21: 测试与迁移验证 + 适配层收拢 - Research

**Researched:** 2026-07-20
**Domain:** 双轨回归验证、适配层闸门、release CI 验证
**Confidence:** HIGH

## Summary

Phase 21 是 v3.0 内核重写的验证收尾阶段。在 Phase 20 完成引擎重构与方法级 DelegationPolicy 翻转后，P21 需要：(1) 验证新引擎行为与旧引擎一致（双轨差异为零），(2) 定义并执行适配层删除闸门清单，(3) 确保 release 构建零 debugPrint 泄漏。

核心复用资产已就位：Phase 15 的 7 组参数化契约测试（`run*ContractTests(MediaEngine Function())`）天然支持对新引擎挂载，仅需替换工厂函数。DelegationPolicy 的 per-method 路由（Phase 20 D9）提供了细粒度翻转控制。Phase 16 的 `phase16_gates.sh` 提供了 gate 脚本模式。

当前代码库状态需要注意：`flutter analyze` 有约 35 个 errors（主要是 `KernelLogger.I` 未定义——应为 `KernelLoggerImpl.I`，以及 `log` 歧义导入），845 测试通过/50 失败。`fvp_engine.dart` 已从 Phase 15 基线 636 行增长到 734 行（Phase 20 增加了 lifecycle、DiagnosticsBundle 注入、TransitionResult 等）。`lib/kernel/` 中仍有 19 处 `debugPrint` 调用（VERIFY-06 需清理）。

**Primary recommendation:** 复用 Phase 15 契约测试 + 新建参数化双轨回归套件，以 RegressionFixture 封装共享逻辑；gate 脚本沿用 phase16_gates.sh 模式；debugPrint 清理作为独立前置任务。

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — 双轨回归方法论 (D1-D5):**
- D1: 参数化测试（一个测试文件，参数化 engine factory）
- D2: 全方法覆盖（所有 MediaEngine 方法）
- D3: fakeAsync 范围 = 全异步场景
- D4: 混合断言（状态值 + 回调触发次数 + 错误状态）
- D5: 测试位置 `test/regression/`

**Area 2 — 测试夹具与报告 (D6-D8):**
- D6: 共享 RegressionFixture 类
- D7: 收集+汇总报告（不 fail-fast）
- D8: 删 adapter 测试，保留契约测试

**Area 3 — 适配层删除闸门 (D9-D12):**
- D9: 4 项硬性检查（100% 调用方迁移、双轨全绿、守卫移入新引擎、回退路径审计）
- D10: kill-switch 保留到 v3.1 里程碑
- D11: 分步删除（先删代码→删测试→清引用，每步独立提交）
- D12: gate 脚本 `tool/audit/phase21_gates.sh`

**Area 4 — Release CI 闸门 (D13-D15):**
- D13: 双重保障（lint rule + grep 构建产物）
- D14: lint rule 范围 `lib/kernel/**`
- D15: grep 脚本检查 `flutter build windows --release` 产物

**Area 5 — 回退策略 (D16-D19):**
- D16: DelegationPolicy 翻回 all-legacy（一行代码改动）
- D17: 触发条件 = 用户可感知的播放故障
- D18: 回退范围 = 引擎+诊断组件
- D19: 回退记录 = 文档+rollback.sh 脚本

### Claude's Discretion

- RegressionFixture 类的具体字段和方法签名（D6）
- 汇总报告的具体格式（D7 DiffReport 结构）
- 分步删除的每步 commit message（D11）
- lint rule 的具体配置方式（D14）
- rollback.sh 脚本的具体实现（D19）

### Deferred Ideas (OUT OF SCOPE)

- 适配层正式删除 — 延后到 v3.1 里程碑（D10 kill-switch 保留一个里程碑）
- 双语注释扫尾 — Phase 22 负责
- Helper 接口适配 — Phase 20 D3 "先跑通再改造"
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VERIFY-01 | 契约测试对 NewFvpEngine 通过 | Phase 15 契约测试已参数化，仅需替换工厂函数 |
| VERIFY-02 | 双轨回归套件 — all-old vs all-new 输出一致 | RegressionFixture + 参数化 group + fakeAsync |
| VERIFY-03 | 迁移顺序由依赖图推导 | codegraph/静态分析推导叶子→编排器→状态管理器→UI 绑定 |
| VERIFY-04 | 适配层删除闸门清单全部满足 | 4 项硬性检查 + gate 脚本 + 独立提交 |
| VERIFY-05 | flutter analyze 严格干净；kernel/ 覆盖率 ≥ 80% | 需先修复 pre-existing analyze errors |
| VERIFY-06 | --release 冒烟测试产出零 debugPrint/debug/info | 19 处 debugPrint 需清理 + lint rule 防新增 |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 双轨回归测试 | test/regression/ | test/contracts/ | 回归测试验证行为一致性，契约测试验证接口合规 |
| 适配层闸门验证 | tool/audit/ | lib/kernel/adapter/ | gate 脚本检查适配层状态，adapter 是被检查对象 |
| DelegationPolicy 翻回 | lib/kernel/player_services.dart | — | 翻回 all-legacy 的唯一改动点 |
| debugPrint 清理 | lib/kernel/** | analysis_options.yaml | 清理现有调用 + lint rule 防新增 |
| Release CI 验证 | tool/audit/ | CI pipeline | grep 构建产物 + lint rule 双重保障 |
| 回退文档 | docs/ | tool/audit/rollback.sh | 文档+脚本记录回退步骤 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_test | SDK bundled | 测试框架 | Flutter 官方测试框架，内置 fakeAsync/ValueNotifier 断言 |
| fvp | 项目已有 | 视频播放引擎 | MDK/FFmpeg 封装，Phase 20 已重构 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| codegraph MCP | 已配置 | 依赖图推导 | VERIFY-03 迁移顺序推导 |
| bash (gate scripts) | — | CI 闸门脚本 | phase21_gates.sh / phase21_release_gate.sh |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 参数化测试 (D1) | 复制测试文件 | D1 复用度高，但需共享 RegressionFixture |
| gate 脚本 (D12) | Dart 程序检查 | 脚本更轻量，CI 友好，与 phase16 模式一致 |
| lint rule (D14) | 仅 grep 检查 | lint rule 即时反馈（IDE 内），grep 是 CI 兜底 |

## Package Legitimacy Audit

> Phase 21 不安装新外部包。所有依赖均为项目已有。

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | — | — | — | — | — | No new packages |

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Phase 21 Verification Flow            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │ Phase 15     │    │ Phase 20     │                   │
│  │ Contract     │    │ FvpEngine    │                   │
│  │ Tests        │    │ (refactored) │                   │
│  │ (7 groups)   │    │              │                   │
│  └──────┬───────┘    └──────┬───────┘                   │
│         │                   │                           │
│         ▼                   ▼                           │
│  ┌──────────────────────────────────┐                   │
│  │ VERIFY-01: Mount contract tests  │                   │
│  │ against FvpEngine (new factory)  │                   │
│  └──────────────┬───────────────────┘                   │
│                 │                                       │
│                 ▼                                       │
│  ┌──────────────────────────────────┐                   │
│  │ VERIFY-02: Dual-track regression │                   │
│  │ RegressionFixture(engineFactory) │                   │
│  │  ├─ group('all-legacy', ...)     │                   │
│  │  └─ group('all-migrated', ...)   │                   │
│  │  → DiffReport (0 differences)    │                   │
│  └──────────────┬───────────────────┘                   │
│                 │                                       │
│                 ▼                                       │
│  ┌──────────────────────────────────┐                   │
│  │ VERIFY-03: Dependency graph      │                   │
│  │ codegraph → migration order      │                   │
│  │ leaf→orchestrator→state→UI       │                   │
│  └──────────────┬───────────────────┘                   │
│                 │                                       │
│                 ▼                                       │
│  ┌──────────────────────────────────┐                   │
│  │ VERIFY-04: Gate checklist        │                   │
│  │  ├─ 100% callers migrated        │                   │
│  │  ├─ Dual-track all green         │                   │
│  │  ├─ Guards in new engine         │                   │
│  │  └─ Rollback path audited        │                   │
│  │  → phase21_gates.sh              │                   │
│  └──────────────┬───────────────────┘                   │
│                 │                                       │
│                 ▼                                       │
│  ┌──────────────────────────────────┐                   │
│  │ VERIFY-05: flutter analyze clean │                   │
│  │ + kernel/ coverage ≥ 80%         │                   │
│  └──────────────┬───────────────────┘                   │
│                 │                                       │
│                 ▼                                       │
│  ┌──────────────────────────────────┐                   │
│  │ VERIFY-06: Release smoke gate    │                   │
│  │  ├─ lint rule (kernel/** no      │                   │
│  │  │  debugPrint)                  │                   │
│  │  └─ grep release binary for      │                   │
│  │     debugPrint/debug/info        │                   │
│  └──────────────────────────────────┘                   │
│                                                         │
│  ┌──────────────────────────────────┐                   │
│  │ Rollback: DelegationPolicy       │                   │
│  │ .all(KernelMode.legacy)          │                   │
│  │ → one-line change                │                   │
│  └──────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
test/
├── regression/
│   ├── dual_track_regression_test.dart    # VERIFY-02: 参数化双轨回归
│   ├── regression_fixture.dart            # D6: 共享夹具
│   ├── diff_report.dart                   # D7: 差异收集+汇总报告
│   ├── high_risk_suite_test.dart          # 已有
│   └── smoke_suite_test.dart              # 已有
├── contracts/                             # 保留（D8）
│   └── ... (7 组契约测试不变)
├── engine/
│   └── fvp_engine_contract_test.dart      # VERIFY-01: 挂载点（工厂替换）
└── adapter/                               # D8: 删除
    ├── kernel_adapter_contract_test.dart  # 删除
    └── kernel_adapter_identity_test.dart  # 删除

tool/audit/
├── phase16_gates.sh                       # 已有
├── phase21_gates.sh                       # D12: 适配层闸门脚本
├── phase21_release_gate.sh                # D15: release 构建产物检查
└── rollback.sh                            # D19: 紧急回退脚本

docs/
└── ROLLBACK.md                            # D19: 回退文档
```

### Pattern 1: 参数化双轨回归测试

**What:** 一个测试文件，通过参数化 engine factory 运行 all-legacy 和 all-migrated 两组测试，断言输出一致。
**When to use:** 验证新旧引擎行为完全一致时。
**Example:**

```dart
// Source: Phase 15 contract test pattern + D1/D6 decisions
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFvpTextureChannelMock();

  // D1: 参数化 engine factory — 一个测试文件，两组断言
  final factories = <String, MediaEngine Function()>{
    'all-legacy': () {
      final fvp = FvpEngine();
      return KernelAdapter(
        legacy: fvp,
        migrated: fvp,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );
    },
    'all-migrated': () {
      final fvp = FvpEngine();
      return KernelAdapter(
        legacy: fvp,
        migrated: fvp,
        policy: DelegationPolicy(
          stateView: KernelMode.migrated,
          playback: KernelMode.migrated,
          track: KernelMode.migrated,
          subtitle: KernelMode.migrated,
          videoEffect: KernelMode.migrated,
          renderer: KernelMode.migrated,
          volume: KernelMode.migrated,
          migratedMethods: {'open', 'play', 'pause', 'seekTo', ...},
        ),
      );
    },
  };

  for (final entry in factories.entries) {
    group('${entry.key} — ', () {
      late RegressionFixture fixture;
      setUp(() => fixture = RegressionFixture(entry.value));
      tearDown(() => fixture.dispose());

      // D2: 全方法覆盖 — D4: 混合断言
      test('open → idle → play → playing', () async { ... });
      test('seek updates position', () async { ... });
      test('volume set updates notifier', () { ... });
      // ... all MediaEngine methods
    });
  }
}
```

### Pattern 2: RegressionFixture 共享夹具

**What:** 封装 engine factory + 断言辅助方法 + 结果收集。
**When to use:** 双轨回归测试中共享测试逻辑。
**Example:**

```dart
// Source: D6 decision
class RegressionFixture {
  RegressionFixture(this._engineFactory);

  final MediaEngine Function() _engineFactory;
  late MediaEngine engine;
  final List<DiffEntry> diffs = [];

  void setUp() {
    engine = _engineFactory();
  }

  void dispose() {
    engine.dispose();
  }

  /// D4: 混合断言 — 状态值 + 回调次数
  void assertState(MediaState expected, {String? context}) {
    if (engine.state.value != expected) {
      diffs.add(DiffEntry(
        method: context ?? 'state',
        expected: expected.toString(),
        actual: engine.state.value.toString(),
      ));
    }
  }

  /// D7: 收集差异，不 fail-fast
  void assertNoDiffs() {
    if (diffs.isNotEmpty) {
      fail('Differences found:\n${diffs.join('\n')}');
    }
  }
}
```

### Pattern 3: Gate 脚本模式

**What:** bash 脚本检查适配层状态和构建产物。
**When to use:** CI 闸门验证。
**Example:**

```bash
#!/usr/bin/env bash
# tool/audit/phase21_gates.sh — 沿用 phase16_gates.sh 模式
set -euo pipefail

# GATE 1: 100% 调用方已迁移（DelegationPolicy 全部 migratedMethods）
gate1_all_migrated() {
  # 检查 PlayerServices 中 DelegationPolicy 是否全 migrated
  ...
}

# GATE 2: 双轨回归全绿
gate2_dual_track_green() {
  # 运行 test/regression/dual_track_regression_test.dart
  flutter test test/regression/dual_track_regression_test.dart
}

# GATE 3: 守卫已移入新引擎
gate3_guards_in_new_engine() {
  # 检查 OpenGenerationTracker 在 FvpEngine 中
  ...
}

# GATE 4: 回退路径已审计
gate4_rollback_audited() {
  # 检查 rollback.sh 和 ROLLBACK.md 存在
  ...
}
```

### Anti-Patterns to Avoid

- **fail-fast 回归报告:** D7 要求收集所有差异后统一报告。不要在第一个差异时就 fail。
- **删除适配层代码与 feature 捆绑:** D11 要求分步独立提交。不要在一个提交里既删适配层又加新功能。
- **仅依赖 lint rule 或仅依赖 grep:** D13 要求双重保障。lint rule 防新增 + grep 验证构建产物。
- **过早删除适配层:** D10 要求保留到 v3.1 里程碑。P21 只定义闸门，不正式删除。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 参数化测试 | 自定义 test runner | Flutter `group()` + `setUp()` 参数化 | 内置支持，与现有契约测试模式一致 |
| fakeAsync | 手动 Timer 控制 | `fakeAsync()` from flutter_test | 内置支持，正确处理 microtask/Timer |
| 依赖图分析 | 手动跟踪 import | codegraph MCP `callers`/`impact` | 已配置，精确的 AST 级分析 |
| 覆盖率报告 | 自定义脚本 | `flutter test --coverage` | 内置支持，生成 lcov 格式 |
| 构建产物检查 | 自定义解析 | grep + shell 脚本 | 简单可靠，与 phase16 模式一致 |

## Common Pitfalls

### Pitfall 1: Pre-existing Analyze Errors Block VERIFY-05

**What goes wrong:** `flutter analyze` 有约 35 个 pre-existing errors（`KernelLogger.I` 未定义 + `log` 歧义导入），VERIFY-05 要求"严格干净"。
**Why it happens:** Phase 17 迁移时 `KernelLogger.I` 应为 `KernelLoggerImpl.I`，部分文件未更新。
**How to avoid:** Phase 21 需先修复这些 errors，或明确将其归类为 pre-existing 并在 PLAN 中作为前置任务。
**Warning signs:** `flutter analyze` 输出 `undefined_getter` 或 `ambiguous_import`。

### Pitfall 2: fvp_engine.dart 行数已超基线

**What goes wrong:** Phase 15 基线 636 行，当前 734 行（Phase 20 增加了 ~100 行）。Phase 16 的 gate2_size_budget 检查 `adapter + diagnostics < fvp_engine.dart`。
**Why it happens:** Phase 20 D2 DiagnosticsBundle 注入 + D4 TransitionResult + D6 LifecyclePhase + D8 double-dispose。
**How to avoid:** Phase 21 的 gate 脚本应使用 live `wc -l`（与 phase16 一致），不硬编码基线值。
**Warning signs:** gate 脚本报告行数超预期。

### Pitfall 3: DelegationPolicy.all() 翻回不等于"全 migrated"

**What goes wrong:** 翻回 `DelegationPolicy.all(KernelMode.legacy)` 会同时翻回 per-capability 字段和 migratedMethods，但 migratedMethods 是独立的 Set。
**Why it happens:** `DelegationPolicy.all()` 构造函数设置所有 7 个字段为同一 mode，但 `migratedMethods` 为空 Set。
**How to avoid:** 翻回时必须确认 migratedMethods 也被清空（或使用 `DelegationPolicy.all()` 构造函数自动处理）。
**Warning signs:** 翻回后某些方法仍走 migrated 路径。

### Pitfall 4: Headless 测试环境 Texture Mock

**What goes wrong:** `flutter test` 在 headless 环境运行时，fvp 的 texture 注册 channel 没有原生实现，会抛 `MissingPluginException`。
**Why it happens:** 无 Windows embedder，`CreateRT`/`ReleaseRT` channel handler 未注册。
**How to avoid:** 双轨回归测试必须包含与 `fvp_engine_contract_test.dart` 相同的 texture channel mock。
**Warning signs:** `open()` 测试失败，错误为 `MissingPluginException`。

### Pitfall 5: debugPrint 在 Release 中不剥离

**What goes wrong:** `debugPrint` 在 release 构建中仍然执行（throttled print），VERIFY-06 要求零 debugPrint。
**Why it happens:** Flutter 的 `debugPrint` 不被 tree-shake 移除，只是在 release 模式下被 `kDebugMode` 门控（但代码仍在二进制中）。
**How to avoid:** 清理 `lib/kernel/` 中所有 19 处 `debugPrint` 调用，替换为 `KernelLogger` 或移除。同时添加 lint rule 防新增。
**Warning signs:** `grep -r 'debugPrint' build/windows/x64/runner/Release/` 有输出。

## Code Examples

### 契约测试挂载点复用

```dart
// Source: test/engine/fvp_engine_contract_test.dart (Phase 15)
// VERIFY-01: 仅需新建挂载点，替换工厂函数
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFvpTextureChannelMock();

  // 原来: runPlaybackControlContractTests(() => FvpEngine());
  // VERIFY-01: 对新引擎挂载（如果 Phase 20 就地修改，则同一实例）
  runEngineStateViewContractTests(() => FvpEngine());
  runPlaybackControlContractTests(() => FvpEngine());
  runTrackControlContractTests(() => FvpEngine());
  runSubtitleConfigContractTests(() => FvpEngine());
  runVideoEffectControlContractTests(() => FvpEngine());
  runRendererControlContractTests(() => FvpEngine());
  runVolumeControlContractTests(() => FvpEngine());
}
```

### Texture Channel Mock（headless 测试必须）

```dart
// Source: test/engine/fvp_engine_contract_test.dart
const _fvpChannel = MethodChannel('fvp');
int _nextFakeTextureId = 1;

void _installFvpTextureChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_fvpChannel, (call) async {
    switch (call.method) {
      case 'CreateRT':
        return _nextFakeTextureId++;
      case 'ReleaseRT':
        return null;
      default:
        return null;
    }
  });
}
```

### Gate 脚本模式（沿用 phase16）

```bash
#!/usr/bin/env bash
# Source: tool/audit/phase16_gates.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 沿用 phase16 设计原则：基线 LIVE 读取，绝不硬编码
# Live-read baseline, never hardcode (phase16 design principle)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DelegationPolicy.all() 整体翻转 | per-method migratedMethods 翻转 | Phase 20 D9 | 细粒度控制，逐方法验证 |
| assert-only 静默忽略非法转换 | TransitionResult + KernelLogger.warn | Phase 20 STATE-03 | 显式记录，不再静默 |
| openGeneration 在引擎外部 | OpenGenerationTracker 嵌入状态机 | Phase 20 STATE-02 | 单一真相源 |
| 静态单例 MemoryMonitor | 实例化 + DiagnosticsBundle 注入 | Phase 19 MEM-04 | 可测试，可关闭 |

**Deprecated/outdated:**
- `DelegationPolicy.all()` 整体翻转：已被 per-method `migratedMethods` 取代，但 `all()` 构造函数保留用于回退
- `bool` 返回值 from `transitionTo`：已被 `TransitionResult` 枚举取代

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Phase 20 已完成所有方法级 DelegationPolicy 翻转（migratedMethods 包含所有 MediaEngine 方法） | 双轨回归 | 如果未全部翻转，all-migrated 测试无法验证完整路径 |
| A2 | fvp_engine.dart 的 Phase 20 修改是就地修改（D1），不存在独立的 new_fvp_engine.dart | 契约测试挂载 | 如果存在新文件，需调整工厂函数指向 |
| A3 | 当前 analyze errors 是 pre-existing（Phase 17 迁移遗留），非 Phase 20 引入 | VERIFY-05 前置 | 如果是 P20 引入，需先修复再验证 |
| A4 | DelegationPolicy.all(KernelMode.legacy) 同时清空 migratedMethods | 回退策略 | 如果不清空，翻回后某些方法仍走 migrated |

## Open Questions

1. **Phase 20 是否已完成所有方法翻转？**
   - What we know: Phase 20 D9 定义了 per-method DelegationPolicy，D11 定义了翻转顺序（open→play→pause→seek→volume→mute→...→其他）
   - What's unclear: Phase 20 的实际执行是否已完成全部翻转，或仅建立了基础设施
   - Recommendation: 在 PLAN 中首先检查 `PlayerServices` 中 `DelegationPolicy` 的 `migratedMethods` 集合内容

2. **Pre-existing analyze errors 归属**
   - What we know: 约 35 个 errors，主要是 `KernelLogger.I` undefined + `log` ambiguous import
   - What's unclear: 这些是否在 Phase 15-20 的某个阶段引入，还是更早的遗留
   - Recommendation: 作为 VERIFY-05 的前置任务修复，不阻塞其他验证工作

3. **fvp_engine.dart 行数增长对 gate 脚本的影响**
   - What we know: 从 636 行增长到 734 行（+15%）
   - What's unclear: Phase 16 的 gate2_size_budget 比较的是 adapter+diagnostics vs fvp_engine.dart，增长后预算是否仍合理
   - Recommendation: gate 脚本使用 live `wc -l`，不硬编码基线

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | 全部 | ✓ | 已安装 | — |
| fvp | 引擎测试 | ✓ | 项目已有 | — |
| bash | gate 脚本 | ✓ | Git Bash | — |
| codegraph MCP | VERIFY-03 依赖图 | ✓ | 已配置 | 手动分析 import 关系 |
| flutter test --coverage | VERIFY-05 覆盖率 | ✓ | SDK 内置 | — |
| flutter build windows --release | VERIFY-06 冒烟 | ✓ | SDK 内置 | — |

**Missing dependencies with no fallback:**
- (none)

**Missing dependencies with fallback:**
- (none)

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK bundled) |
| Config file | analysis_options.yaml |
| Quick run command | `flutter test test/regression/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VERIFY-01 | Contract tests pass on FvpEngine | unit | `flutter test test/engine/fvp_engine_contract_test.dart` | ✅ |
| VERIFY-02 | Dual-track regression zero diff | unit | `flutter test test/regression/dual_track_regression_test.dart` | ❌ Wave 0 |
| VERIFY-03 | Migration order from dependency graph | manual | codegraph analysis + doc | ❌ Wave 0 |
| VERIFY-04 | Gate checklist all pass | script | `bash tool/audit/phase21_gates.sh` | ❌ Wave 0 |
| VERIFY-05 | analyze clean + coverage ≥ 80% | static | `flutter analyze && flutter test --coverage` | ✅/❌ |
| VERIFY-06 | Release smoke zero debugPrint | script | `bash tool/audit/phase21_release_gate.sh` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/regression/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green + gate scripts pass before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/regression/dual_track_regression_test.dart` — covers VERIFY-02
- [ ] `test/regression/regression_fixture.dart` — shared fixture (D6)
- [ ] `test/regression/diff_report.dart` — diff collection (D7)
- [ ] `tool/audit/phase21_gates.sh` — covers VERIFY-04
- [ ] `tool/audit/phase21_release_gate.sh` — covers VERIFY-06
- [ ] `tool/audit/rollback.sh` — covers D19
- [ ] `docs/ROLLBACK.md` — covers D19
- [ ] Pre-existing analyze errors fix — covers VERIFY-05
- [ ] debugPrint cleanup in lib/kernel/ — covers VERIFY-06

## Security Domain

> Phase 21 是验证阶段，不引入新功能。安全面极低。

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | 验证阶段不处理用户输入 |
| V6 Cryptography | no | — |

### Known Threat Patterns for {stack}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-----|
| Gate 脚本被绕过 | Elevation of privilege | CI 强制执行 gate 脚本，非零退出阻断 |
| 回退脚本权限不足 | Denial of service | rollback.sh 需要 git 权限，文档说明前置条件 |

## Sources

### Primary (HIGH confidence)
- `lib/kernel/adapter/kernel_adapter.dart` — 适配层当前实现，DelegationPolicy per-method 路由
- `lib/kernel/player_services.dart` — DelegationPolicy 持有者，翻回目标
- `lib/kernel/engine/fvp_engine.dart` — 引擎实现（734 行，Phase 20 重构后）
- `lib/kernel/engine/engine_state_machine.dart` — 状态机（TransitionResult + OpenGenerationTracker）
- `test/contracts/` — 7 组参数化契约测试
- `test/engine/fvp_engine_contract_test.dart` — 契约测试挂载点
- `tool/audit/phase16_gates.sh` — gate 脚本模式参考
- `.planning/phases/21-verify-migration-adapter-convergence/21-CONTEXT.md` — 19 项用户决策

### Secondary (MEDIUM confidence)
- `flutter analyze` 输出 — pre-existing errors 数量和类型
- `flutter test` 输出 — 845 pass / 50 fail 当前状态

### Tertiary (LOW confidence)
- (none)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 全部使用项目已有工具和 Flutter 内置功能
- Architecture: HIGH — 沿用 Phase 15-20 已验证的模式
- Pitfalls: HIGH — 5 个 pitfall 均基于实际代码分析发现

**Research date:** 2026-07-20
**Valid until:** 2026-08-20 (30 days — 项目内部阶段，无外部依赖变化)
