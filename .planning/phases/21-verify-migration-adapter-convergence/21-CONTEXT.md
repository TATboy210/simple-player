# Phase 21: 测试与迁移验证 + 适配层收拢 - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning

<domain>
## Phase Boundary

在 Phase 20 完成引擎重写与方法级 DelegationPolicy 翻转后，验证新引擎行为与旧引擎一致（双轨差异为零），以显式闸门清单守护适配层收拢（独立提交），release 构建冒烟通过。

**本 phase 不交付**: 新引擎功能（P20 已完成）、双语注释（P22）、适配层删除本身（仅验证+闸门，删除在下一里程碑）。P21 只交付 **双轨回归验证 + 闸门清单定义 + CI gate 脚本 + 回退文档**。
</domain>

<decisions>
## Implementation Decisions

### Area 1: 双轨回归方法论 (D1-D5)

- **D1 — 测试组织方式：参数化测试。** 一个测试文件，参数化传入 engine factory（all-legacy vs all-migrated），跑两遍断言一致。复用度高，共享测试逻辑。
- **D2 — 覆盖范围：全方法覆盖。** 所有 MediaEngine 方法（open/play/pause/seek/volume/mute/track/subtitle/videoEffect）全覆盖。最安全。
- **D3 — fakeAsync 范围：全异步场景。** 所有涉及异步的测试都用 fakeAsync（open、seek、auto-advance、callback marshalling）。最严格。
- **D4 — 断言策略：混合断言。** 状态值（state/position/volume/mute 等 ValueNotifier 最终值）+ 关键回调触发次数 + 错误状态。平衡全面性和复杂度。
- **D5 — 测试位置：`test/regression/`。** 与现有 regression_matrix.md 一致。

### Area 2: 测试夹具与报告 (D6-D8)

- **D6 — 夹具设计：共享 RegressionFixture 类。** 封装 engine factory + 断言辅助方法 + 结果收集。两个测试（all-old vs all-new）共用同一个 fixture。
- **D7 — 失败报告：收集+汇总报告。** 收集所有差异到最后统一报告。不中断测试，但失败时信息量大。报告格式：每个差异项包含 method + expected(old) + actual(new) + context。
- **D8 — adapter 测试处理：删 adapter 测试，保留契约测试。** 删除 `test/adapter/kernel_adapter_contract_test.dart` 和 `kernel_adapter_identity_test.dart`。`test/contracts/` 下的接口级契约测试保留（它们验证接口，不验证适配层）。

### Area 3: 适配层删除闸门 (D9-D12)

- **D9 — 闸门清单：4 项硬性检查。** 100% 调用方已迁移到新引擎（DelegationPolicy 全部 migratedMethods）、双轨回归全绿、守卫（openGeneration/generation tracker）已移入新引擎、回退路径已审计（Policy 翻回 all-legacy 仍可用）。
- **D10 — kill-switch 保留：适配层保留到下一里程碑（v3.1）。** Phase 21 完成后适配层代码仍存在，作为 kill-switch。下一里程碑正式删除。
- **D11 — 删除提交策略：分步删除。** 先删适配层代码，再删测试，再清理引用。多步但每步小。每步独立提交，永不与 feature 捆绑。
- **D12 — 闸门执行方式：gate 脚本。** 在 `tool/audit/` 下新增 `phase21_gates.sh`，自动检查 4 项硬性检查。与 Phase 16 的 `phase16_gates.sh` 同模式。

### Area 4: Release CI 闸门 (D13-D15)

- **D13 — 验证方式：双重保障。** lint rule 防止新增 + grep 脚本验证构建产物。
- **D14 — lint rule 范围：`lib/kernel/**` 目录。** 在 analysis_options.yaml 中为 kernel/ 目录添加禁止 `debugPrint` 的 lint rule。内核代码永远用 KernelLogger 替代。
- **D15 — grep 脚本：检查构建产物。** `flutter build windows --release` 后 grep 产物中的 debugPrint/debug/info 字符串。放在 `tool/audit/phase21_release_gate.sh`。

### Area 5: 回退策略 (D16-D19)

- **D16 — 回退方式：DelegationPolicy 翻回 all-legacy。** `PlayerServices` 中 `DelegationPolicy.all(KernelMode.legacy)` 一行代码改动，立即生效。所有方法走旧引擎。
- **D17 — 触发条件：用户可感知的播放故障。** 无法播放、崩溃、音画不同步等立即触发回退。
- **D18 — 回退范围：引擎+诊断组件。** 回退播放引擎（DelegationPolicy 翻回）+ 诊断组件（KernelLogger/MemoryMonitor 回退到 noop）。不涉及 UI/设置/播放列表。
- **D19 — 回退记录：文档+脚本。** 在项目文档中添加"紧急回退"章节记录翻回步骤 + 写一个 `rollback.sh` 脚本自动翻回 DelegationPolicy。

### Carried Forward from Phase 15/16/17/18/19/20（承袭决策，不再问）

- **Phase 15 D1:** 契约权威在接口 `///` 双语注释
- **Phase 16 D10:** DiagnosticsBundle 所有权 = PlayerServices 构造
- **Phase 16 ADAPT-03:** 适配层转发同一 ValueNotifier 实例（不重新包装）
- **Phase 17 D1:** KernelLogger.I 静态访问器
- **Phase 18 D10:** 三步合一错误处理（构造 PlayerError → 赋值 lastError → logger 发射）
- **Phase 19 D4:** MemoryMonitor 由 DiagnosticsBundle 持有
- **Phase 20 D9:** DelegationPolicy 按单个方法粒度翻转
- **Phase 20 D10:** 每次方法翻转后跑完整测试套件
- **Phase 20 D11:** 核心优先翻转顺序：open→play→pause→seek→volume→mute→...→其他
- **Blocking #7:** debugPrint release 不剥离 → VERIFY-06 gate

### Claude's Discretion

用户在全部 4 区 12 问都选了具体选项（无 "You decide"）。以下属 planner / executor 实现裁量：

- RegressionFixture 类的具体字段和方法签名（D6：planner 设计）
- 汇总报告的具体格式（D7：planner 定义 DiffReport 结构）
- 分步删除的每步 commit message（D11：planner 规划）
- lint rule 的具体配置方式（D14：planner 查 Dart lint 文档）
- rollback.sh 脚本的具体实现（D19：planner 编写）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 路线图与需求（phase 级权威）
- `.planning/ROADMAP.md` §Phase 21 — Goal/Depends on Phase 20/Requirements VERIFY-01..06/Success Criteria 1-5/Blocking Constraints #7 release 闸门
- `.planning/REQUIREMENTS.md` §VERIFY — VERIFY-01..06 原子需求

### Phase 15-20 诊断基础设施与契约
- `.planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md` — D1（契约在接口）/BASE-04（契约测试）
- `.planning/phases/16-diagnosticsbundle/16-CONTEXT.md` — D10（bundle 所有权）/ADAPT-03（notifier 实例转发）/ADAPT-05（尺寸预算）
- `.planning/phases/20-state-lifecycle/20-CONTEXT.md` — D9（per-method DelegationPolicy）/D10（翻转后跑测试）/D11（翻转顺序）

### LIVE code（验证对象）
- `lib/kernel/adapter/kernel_adapter.dart` — 适配层（P21 验证+闸门，下一里程碑删除）
- `lib/kernel/player_services.dart` — DelegationPolicy 持有者（P21 翻回目标）
- `lib/kernel/engine/fvp_engine.dart` — 新引擎（P20 重构，P21 验证目标）
- `lib/kernel/engine/engine_state_machine.dart` — 状态机（P20 扩展，P21 验证对象）
- `test/contracts/` — 接口级契约测试（P21 保留）
- `test/adapter/` — 适配层测试（P21 删除）
- `test/regression/` — 回归测试目录（P21 新增双轨回归）

### 现有 gate 脚本模式
- `tool/audit/phase16_gates.sh` — Phase 16 gate 脚本（P21 同模式参考）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **DelegationPolicy**（`kernel_adapter.dart`）：per-method routing，P21 验证全部 migratedMethods
- **Contract tests**（`test/contracts/`）：7 组接口契约测试，P21 验证对新引擎通过
- **Regression matrix**（`test/regression/regression_matrix.md`）：现有回归矩阵，P21 扩展双轨回归
- **phase16_gates.sh**（`tool/audit/`）：gate 脚本模式，P21 新增 phase21_gates.sh

### Established Patterns
- **参数化测试**：Flutter test 支持 `group()` + `setUp()` 参数化，P21 用此模式组织双轨回归
- **fakeAsync**：Flutter test 内置，P21 用于全异步场景时序控制
- **ValueNotifier 断言**：现有测试通过 `tester.pump()` + `expect(notifier.value, ...)` 断言，P21 复用

### Integration Points
- **PlayerServices**：DelegationPolicy 持有者，P21 翻回 all-legacy 的唯一改动点
- **tool/audit/**：gate 脚本目录，P21 新增 phase21_gates.sh + phase21_release_gate.sh
- **analysis_options.yaml**：lint 配置，P21 新增 kernel/ 目录 debugPrint 禁止规则

</code_context>

<specifics>
## Specific Ideas

- **参数化测试 + 共享 Fixture**（D1+D6）：用户明确选择参数化而非复制。RegressionFixture 封装 engine factory + 断言逻辑，两个 group 共用。
- **收集+汇总报告**（D7）：不 fail-fast，收集所有差异后统一报告。每个差异项包含 method + expected(old) + actual(new) + context。
- **分步删除**（D11）：先删适配层代码 → 再删测试 → 再清理引用。每步独立提交。
- **双重保障**（D13）：lint rule 防新增 + grep 构建产物验证。不信任单一手段。
- **引擎+诊断回退**（D18）：回退范围包含 KernelLogger/MemoryMonitor 回退到 noop。不碰 UI。

</specifics>

<deferred>
## Deferred Ideas

- **适配层正式删除** — 延后到 v3.1 里程碑（D10 kill-switch 保留一个里程碑）
- **双语注释扫尾** — Phase 22 负责（P21 不交付注释）
- **Helper 接口适配** — Phase 20 D3 "先跑通再改造"，helper 改造可能延后

None of the deferred items block Phase 21. 所有延后项均有明确归属阶段。

</deferred>

---

*Phase: 21-测试与迁移验证+适配层收拢*
*Context gathered: 2026-07-20*
*Decisions captured: 19 (D1-D19) across 5 gray areas*
