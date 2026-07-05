# Phase 24: Features & Verification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-05
**Phase:** 24-Features & Verification
**Areas discussed:** 验证范围, 验证顺序, 非目标文件处理, 模式文档深度

---

## 验证范围

| Option | Description | Selected |
|--------|-------------|----------|
| 仅工具验证 | 跑 flutter analyze + test，50 个 DOC 只检查文件是否存在 | |
| 工具 + 抽查 | 除工具验证外，随机选 3-5 个文件验证注释质量 | |
| 全量重新审计 | 重新审查全部 50 个文件的注释质量，按 A/B/C 分类重新打分 | ✓ |

**User's choice:** 全量重新审计

| Option | Description | Selected |
|--------|-------------|----------|
| 只审计不修复 | 用 A/B/C 分类标准，只报告结果 | |
| 审计 + 修复 | 审计后 A/B 类文件也在这次修复 | |
| 审计 + 生成修复计划 | 审计后生成报告，列出哪些文件需要修复，修复留给后续 phase | ✓ |

**User's choice:** 审计 + 生成修复计划

| Option | Description | Selected |
|--------|-------------|----------|
| 覆盖 + 质量抽查 | 先审计算法覆盖，再抽查质量 | |
| 仅覆盖检查 | 只检查覆盖，不检查质量 | |
| 全量质量检查 | 每个文件都检查注释深度 | ✓ |

**User's choice:** 全量质量检查

| Option | Description | Selected |
|--------|-------------|----------|
| 工具验证优先 | 先确保基线健康，再继续 | ✓ |
| 文档优先 | 先完成文档，最后统一跑 analyze/test | |
| 并行进行 | 文档和工具验证并行 | |

**User's choice:** 工具验证优先

| Option | Description | Selected |
|--------|-------------|----------|
| 沿用 Phase 21 标准 | 4 维度：类级 doc comment、关键方法文档、魔法数字解释、非显而易见逻辑 why 注释 | ✓ |
| 扩展标准 | 在 Phase 21 基础上增加：模块级概述、依赖关系文档、参数范围说明 | |
| 自定义标准 | 用户自定义审计维度 | |

**User's choice:** 沿用 Phase 21 标准

| Option | Description | Selected |
|--------|-------------|----------|
| Markdown 报告 | 生成 markdown 表格保存到 .planning/phases/24-*/ | ✓ |
| 终端输出 | 只在终端输出审计结果 | |
| 更新 REQUIREMENTS.md | 在 REQUIREMENTS.md 中直接标记审计结果 | |

**User's choice:** Markdown 报告

---

## 验证顺序

| Option | Description | Selected |
|--------|-------------|----------|
| 工具 → 文档 → 审计 | 先跑 analyze/test，再写文档，最后审计 | ✓ |
| 文档 → 工具 → 审计 | 先写文档，再跑 analyze/test，最后审计 | |
| 审计 → 文档 → 工具 | 先审计现有文件，再写新文档，最后跑 analyze/test | |

**User's choice:** 工具 → 文档 → 审计

| Option | Description | Selected |
|--------|-------------|----------|
| 修复后再继续 | 全部修复后再继续文档工作 | ✓ |
| 记录不修复 | 记录问题但不修复 | |
| 只修 error | 只修复 error，warning 记录但不修复 | |

**User's choice:** 修复后再继续

| Option | Description | Selected |
|--------|-------------|----------|
| 修复后再继续 | 诊断并修复后再继续 | ✓ |
| 记录不修复 | 记录失败的测试但不修复 | |
| 跳过无关失败 | 如果失败与文档无关，跳过继续 | |

**User's choice:** 修复后再继续

| Option | Description | Selected |
|--------|-------------|----------|
| 统一审计 | 先写完 15 个文件，然后统一审计全部 60 个文件 | ✓ |
| 分批审计 | 先审计 45 个文件，再写 5 个新文档，最后单独审计新写的 5 个 | |

**User's choice:** 统一审计

---

## 非目标文件处理

| Option | Description | Selected |
|--------|-------------|----------|
| 仅 5 个目标文件 | 只处理 DOC-46 ~ DOC-50 | |
| 全部 15 个文件 | 5 个目标文件 + 10 个非目标文件全部补充注释 | ✓ |
| 5 个文件 + 审计标记 | 5 个目标文件 + 审计时标记非目标文件的注释质量 | |

**User's choice:** 全部 15 个文件

| Option | Description | Selected |
|--------|-------------|----------|
| 统一标准 | 15 个文件用相同的标准和深度处理 | ✓ |
| 分层标准 | 5 个目标文件用完整标准，10 个非目标文件用简化标准 | |

**User's choice:** 统一标准

| Option | Description | Selected |
|--------|-------------|----------|
| 添加新 DOC requirement | 在 REQUIREMENTS.md 中添加 DOC-51 ~ DOC-60 | ✓ |
| 不添加，只审计 | 不添加新 requirement，只在审计报告中覆盖 | |
| 记录在 CONTEXT.md | 在 CONTEXT.md 中记录处理决策 | |

**User's choice:** 添加新 DOC requirement

| Option | Description | Selected |
|--------|-------------|----------|
| 架构层级顺序 | 先核心 MVVM，再 models，再 services 子模块 | ✓ |
| 从小到大 | 先处理最短的文件 | |
| 依赖拓扑顺序 | 先处理被依赖最多的文件 | |

**User's choice:** 架构层级顺序

---

## 模式文档深度

| Option | Description | Selected |
|--------|-------------|----------|
| what + why + 架构位置 | 解释在 MVVM 中的角色、与其他层的依赖关系 | |
| 仅 what + why | 只解释功能，不解释架构位置 | |
| 完整模式文档 | what + why + 架构位置 + 使用示例 + 替代方案对比 | ✓ |

**User's choice:** 完整模式文档

| Option | Description | Selected |
|--------|-------------|----------|
| 是 | 每个文件顶部添加模块级概述 | ✓ |
| 否 | 只在类/方法级别加注释 | |

**User's choice:** 是

| Option | Description | Selected |
|--------|-------------|----------|
| 是 | 解释每个类/方法在模式中的角色，以及与其他组件的交互方式 | ✓ |
| 否 | 只解释单个类/方法的功能 | |

**User's choice:** 是

| Option | Description | Selected |
|--------|-------------|----------|
| 是 | 在注释中简要说明为什么选择这个模式而非替代方案 | ✓ |
| 否 | 不解释替代方案 | |

**User's choice:** 是

---

## Claude's Discretion

No areas deferred to Claude's discretion.

## Deferred Ideas

None — discussion stayed within phase scope.
