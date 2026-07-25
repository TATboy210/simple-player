# Phase 21: 测试与迁移验证 + 适配层收拢 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-20
**Phase:** 21-测试与迁移验证+适配层收拢
**Areas discussed:** 双轨回归方法论, 适配层删除闸门, Release CI 闸门, 回退策略

---

## 双轨回归方法论

### Q1: 测试组织方式

| Option | Description | Selected |
|--------|-------------|----------|
| 参数化测试（推荐） | 一个测试文件，参数化传入 engine factory（old vs new），跑两遍断言一致 | ✓ |
| 复制+切换 | 复制现有 widget 测试，一套用 old engine，一套用 new engine | |
| 录制+回放 | 先跑 old engine 测试录制 baseline，再跑 new engine 对比差异 | |

**User's choice:** 参数化测试（推荐）

### Q2: 覆盖范围

| Option | Description | Selected |
|--------|-------------|----------|
| 全方法覆盖（推荐） | 所有 MediaEngine 方法全覆盖 | ✓ |
| 核心路径 only | 只覆盖 open→play→pause→seek→close | |
| 渐进扩展 | 先跑核心路径，全绿再扩展 | |

**User's choice:** 全方法覆盖（推荐）

### Q3: fakeAsync 范围

| Option | Description | Selected |
|--------|-------------|----------|
| 全异步场景（推荐） | 所有涉及异步的测试都用 fakeAsync | ✓ |
| 仅时序敏感场景 | 只对已知时序敏感的场景用 fakeAsync | |
| 不用 fakeAsync | 全部用真实 async + 合理 timeout | |

**User's choice:** 全异步场景（推荐）

### Q4: 断言策略

| Option | Description | Selected |
|--------|-------------|----------|
| 状态值对比（推荐） | 对比两套 engine 的最终 ValueNotifier 值 | |
| 调用序列对比 | 对比两套 engine 的方法调用序列（spy/recording） | |
| 混合断言 | 状态值 + 关键回调触发次数 + 错误状态 | ✓ |

**User's choice:** 混合断言

### Q5: 测试夹具设计

| Option | Description | Selected |
|--------|-------------|----------|
| 共享 Fixture 类（推荐） | 一个共享的 RegressionFixture 类，封装 engine factory + 断言辅助方法 | ✓ |
| 独立构造 | 每个测试独立构造 engine + 断言 | |
| 模板方法继承 | 基类定义测试逻辑，子类提供 engine factory | |

**User's choice:** 共享 Fixture 类（推荐）

### Q6: 失败报告格式

| Option | Description | Selected |
|--------|-------------|----------|
| 逐用例断言（推荐） | 每个测试用例独立断言，失败时输出 old 值 vs new 值的 diff | |
| 收集+汇总报告 | 收集所有差异到最后统一报告 | ✓ |
| fail-fast | 逐用例断言，第一个失败就停止 | |

**User's choice:** 收集+汇总报告

### Q7: 测试目录

| Option | Description | Selected |
|--------|-------------|----------|
| test/regression/（推荐） | 与现有 regression_matrix.md 一致 | ✓ |
| test/adapter/ | 与 adapter 测试放一起 | |
| test/contracts/ | 与契约测试放一起 | |

**User's choice:** test/regression/（推荐）

---

## 适配层删除闸门

### Q8: 闸门清单

| Option | Description | Selected |
|--------|-------------|----------|
| 4 项硬性检查（推荐） | 100% 调用方迁移、双轨回归全绿、守卫已移入、回退路径已审计 | ✓ |
| 扩展检查清单 | 加上覆盖率 ≥ 80%、flutter analyze 干净、release 冒烟通过 | |
| 最小检查 | 只检查 DelegationPolicy 全部 migratedMethods + 双轨回归全绿 | |

**User's choice:** 4 项硬性检查（推荐）

### Q9: kill-switch 保留时间

| Option | Description | Selected |
|--------|-------------|----------|
| 保留到下一里程碑（推荐） | 适配层在 v3.0 里程碑内保留，v3.1 才正式删除 | ✓ |
| Phase 21 内删除 | 验证通过后立即删除 | |
| 保留但 @deprecated | 代码保留但标记 deprecated | |

**User's choice:** 保留到下一里程碑（推荐）

### Q10: 删除提交策略

| Option | Description | Selected |
|--------|-------------|----------|
| 原子删除提交（推荐） | 一个原子提交删除所有适配层文件 | |
| 分步删除 | 先删适配层代码，再删测试，再清理引用 | ✓ |
| deprecate → 删除 | 标记 deprecated → 下一里程碑再删 | |

**User's choice:** 分步删除

### Q11: adapter 测试处理

| Option | Description | Selected |
|--------|-------------|----------|
| 删 adapter 测试，保留契约测试（推荐） | 删除 adapter 专用测试，保留接口级契约测试 | ✓ |
| 保留+改写 | 所有测试保留，adapter 测试改为直接测试新引擎 | |
| 归档到 regression/ | adapter 测试移到 test/regression/ 作为历史参考 | |

**User's choice:** 删 adapter 测试，保留契约测试（推荐）

---

## Release CI 闸门

### Q12: 验证方式

| Option | Description | Selected |
|--------|-------------|----------|
| grep 脚本（推荐） | shell 脚本：flutter build --release → grep 产物 | |
| lint rule | analysis_options.yaml 中添加 lint rule 禁止 debugPrint | |
| 双重保障 | lint rule + grep 脚本都做 | ✓ |

**User's choice:** 双重保障

### Q13: lint rule 范围

| Option | Description | Selected |
|--------|-------------|----------|
| kernel/ 目录 lint（推荐） | 为 kernel/ 目录添加禁止 debugPrint 的 lint rule | ✓ |
| 全局 lint | 全局禁止 debugPrint | |
| 仅 grep | 不加 lint rule，只用 grep 脚本 | |

**User's choice:** kernel/ 目录 lint（推荐）

### Q14: grep 检查目标

| Option | Description | Selected |
|--------|-------------|----------|
| grep 构建产物（推荐） | grep 构建产物中的字符串 | ✓ |
| grep 源码 | grep 源码中 lib/kernel/** 的 debugPrint/print 调用 | |
| 双重 grep | 源码 grep + 构建产物 grep | |

**User's choice:** grep 构建产物（推荐）

### Q15: gate 脚本位置

| Option | Description | Selected |
|--------|-------------|----------|
| tool/audit/（推荐） | 与 Phase 16 的 phase16_gates.sh 同模式 | ✓ |
| test/ 目录 | 作为集成测试 | |
| CI workflow | .github/workflows/ | |

**User's choice:** tool/audit/（推荐）

---

## 回退策略

### Q16: 回退方式

| Option | Description | Selected |
|--------|-------------|----------|
| Policy 翻回（推荐） | DelegationPolicy 翻回 all-legacy，一行代码改动 | ✓ |
| git revert | revert 整个 Phase 20 的 git commits | |
| 分级回退 | Policy 翻回 + git revert 都作为可选方案 | |

**User's choice:** Policy 翻回（推荐）

### Q17: 触发条件

| Option | Description | Selected |
|--------|-------------|----------|
| 用户可感知故障（推荐） | 无法播放、崩溃、音画不同步等立即触发回退 | ✓ |
| 仅崩溃/数据丢失 | 只有崩溃/数据丢失才回退 | |
| 自动监控触发 | 监控指标异常自动触发回退 | |

**User's choice:** 用户可感知故障（推荐）

### Q18: 回退范围

| Option | Description | Selected |
|--------|-------------|----------|
| 仅引擎层（推荐） | 只回退播放引擎 | |
| 引擎+诊断 | 回退引擎 + 诊断组件 | ✓ |
| 全量回退 | 回退整个 v3.0 改动 | |

**User's choice:** 引擎+诊断

### Q19: 回退记录方式

| Option | Description | Selected |
|--------|-------------|----------|
| 文档记录（推荐） | 在文档中添加"紧急回退"章节 | |
| 自动化脚本 | rollback.sh 脚本自动翻回 | |
| 文档+脚本 | 文档 + 脚本都做 | ✓ |

**User's choice:** 文档+脚本

---

## Claude's Discretion

用户在全部 19 问都选了具体选项（无 "You decide"）。实现裁量归 planner/executor。

## Deferred Ideas

- **适配层正式删除** — 延后到 v3.1 里程碑（D10 kill-switch 保留一个里程碑）
- **双语注释扫尾** — Phase 22 负责
- **Helper 接口适配** — Phase 20 D3 "先跑通再改造"，可能延后
