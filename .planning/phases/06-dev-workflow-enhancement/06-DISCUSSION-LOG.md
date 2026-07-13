# Phase 6: 开发工作流增强 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 6-开发工作流增强
**Areas discussed:** Context7 配置策略, codegraph 源码分析, Quality Pipeline 评估维度, 工具集成深度

---

## Context7 配置策略

### Q1: 查询范围

| Option | Description | Selected |
|--------|-------------|----------|
| 全量覆盖 | Flutter SDK + fvp + shared_preferences + window_manager | ✓ |
| 仅 Flutter SDK | 只查 Flutter SDK 文档 | |
| Flutter + fvp | Flutter SDK + fvp 核心包 | |

**User's choice:** 全量覆盖 (推荐)
**Notes:** 覆盖项目所有直接依赖，开发时遇到任何库问题都能查

### Q2: 使用策略

| Option | Description | Selected |
|--------|-------------|----------|
| 按需查询 | 只在用户明确问或需要查 API 时才调用 | ✓ |
| 实现前主动查 | 实现功能前先查相关库文档 | |
| 模板化查询 | 在 CLAUDE.md 中记录常用查询模板 | |

**User's choice:** 按需查询 (推荐)
**Notes:** 省 token，按需触发

### Q3: 查询粒度

| Option | Description | Selected |
|--------|-------------|----------|
| 精准查询 | 每次用具体问题，不泛泛搜索 | ✓ |
| 先概览再深入 | 先查概览再深入 | |
| 不限制 | 按需自由查询 | |

**User's choice:** 精准查询 (推荐)
**Notes:** 减少返回噪音，更精准

### Q4: 配置持久化

| Option | Description | Selected |
|--------|-------------|----------|
| 写入 CLAUDE.md | 添加库 ID 映射表 + 使用场景 | ✓ |
| 仅 CONTEXT.md | 不改 CLAUDE.md | |
| 独立参考文档 | 创建 .claude/context7-guide.md | |

**User's choice:** 写入 CLAUDE.md (推荐)
**Notes:** 新会话自动生效

---

## codegraph 源码分析

### Q1: 分析范围

| Option | Description | Selected |
|--------|-------------|----------|
| Flutter SDK 源码 | 分析 Flutter SDK 内部实现 | |
| 项目自身代码 | 分析 lib/ 目录 | |
| 两者都要 | 同时索引项目和 SDK | ✓ |

**User's choice:** 两者都要
**Notes:** 覆盖最全

### Q2: 版本升级

| Option | Description | Selected |
|--------|-------------|----------|
| 升级到最新 | 从 v1.1.6 升到 v1.4.1 | ✓ |
| 保持当前版本 | v1.1.6 够用 | |
| 先看 changelog | 对比新版本变化 | |

**User's choice:** 升级到最新 (推荐)
**Notes:** 用户确认 codegraph 已安装，需要升级

### Q3: MCP 集成方式

| Option | Description | Selected |
|--------|-------------|----------|
| 项目级 MCP 配置 | 写入 .mcp.json，所有会话自动加载 | ✓ |
| 保持现状 | 全局安装 + hooks，CLI 手动调用 | |
| 先测试再配置 | 升级后先测试 MCP 工具 | |

**User's choice:** 项目级 MCP 配置 (推荐)
**Notes:** 用户确认 codegraph 已全局安装

### Q4: 索引策略

| Option | Description | Selected |
|--------|-------------|----------|
| 项目优先，SDK 按需 | 先索引项目代码，Flutter SDK 按需 | |
| 同时索引 | 项目和 SDK 同时索引 | ✓ |
| 仅项目代码 | 不索引 Flutter SDK | |

**User's choice:** 同时索引
**Notes:** 一次性完成

---

## Quality Pipeline 评估维度

### Q1: 评估维度

| Option | Description | Selected |
|--------|-------------|----------|
| 静态分析 & Lint | flutter analyze + very_good_analysis | |
| 代码格式化 | dart format + 自动格式化 | |
| 测试覆盖率 | flutter test + coverage 阈值 | ✓ |
| 性能基准 | 启动时间、帧率、内存、包体积 | ✓ |

**User's choice:** 测试覆盖率 + 性能基准
**Notes:** 静态分析已就绪（strict-casts/strict-inference），不需要额外评估

### Q2: 评估产出物

| Option | Description | Selected |
|--------|-------------|----------|
| 评估文档 | Markdown 格式，工具对比、推荐方案、集成步骤 | ✓ |
| 评估 + 配置 | 评估 + 实际配置脚本 | |
| 仅调研 | 口头汇报，不产出文档 | |

**User's choice:** 评估文档 (推荐)
**Notes:** ROADMAP 说"评估文档，不集成代码"

### Q3: 性能基准评估策略

| Option | Description | Selected |
|--------|-------------|----------|
| 基于现有代码评估 | 分析 perf_monitor.dart 能力 | |
| 调研生态工具 | 调研 Flutter 生态性能测试工具 | |
| 两者结合 | 先看现有代码，再对比生态工具 | ✓ |

**User's choice:** 两者结合
**Notes:** 找出差距

---

## 工具集成深度

### Q1: 配置持久化

| Option | Description | Selected |
|--------|-------------|----------|
| CLAUDE.md 指南 | 添加工具使用指南 | ✓ |
| 仅 CONTEXT.md | 不改 CLAUDE.md | |
| 独立参考文档 | 创建 .claude/DEV-WORKFLOW.md | |

**User's choice:** CLAUDE.md 指南 (推荐)
**Notes:** 新会话自动生效

### Q2: CI/CD 集成

| Option | Description | Selected |
|--------|-------------|----------|
| 不含 CI | 本地桌面应用无 CI，评估文档中提供建议 | ✓ |
| 含 CI 示例 | 包含 GitHub Actions 配置示例 | |
| 实际配置 CI | 创建 .github/workflows/quality.yml | |

**User's choice:** 不含 CI (推荐)
**Notes:** 当前无 CI 需求

---

## Claude's Discretion

无 — 所有决策均用户明确选择。

## Deferred Ideas

None — discussion stayed within phase scope
