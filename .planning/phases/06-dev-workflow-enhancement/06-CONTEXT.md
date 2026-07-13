# Phase 6: 开发工作流增强 - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

配置和评估三个开发工具：Context7 文档查询（Flutter SDK + 第三方包）、codegraph 源码分析（项目代码 + Flutter SDK）、Quality Pipeline 质量管线评估（测试覆盖率 + 性能基准）。输出 Context7 使用指南写入 CLAUDE.md、codegraph MCP 配置 + 索引、Quality Pipeline 评估文档。不涉及实际 CI/CD 集成，不涉及代码质量规则变更。

</domain>

<decisions>
## Implementation Decisions

### Context7 配置策略
- **D-01:** 全量覆盖 — 配置 Flutter SDK (API + 指南) + fvp + shared_preferences + window_manager 为常用查询目标。库 ID：`/websites/api_flutter_dev`、`/websites/flutter_dev`、`/wang-bin/fvp`、`/websites/pub_dev_packages_shared_preferences`、`/leanflutter/window_manager`
- **D-02:** 按需查询 — 只在用户明确问或需要查 API 时才调用 Context7，不主动查询
- **D-03:** 精准查询 — 每次用具体问题（如 "AnimatedSlide 用法"），不泛泛搜索，减少返回噪音
- **D-04:** 写入 CLAUDE.md — 添加 Context7 库 ID 映射表 + 使用场景 + 注意事项，新会话自动生效

### codegraph 源码分析
- **D-05:** 升级 codegraph — 从 v1.1.6 升到 v1.4.1（最新），获得最新功能和 bug 修复
- **D-06:** 项目级 MCP 配置 — 将 codegraph 配置写入项目 `.mcp.json`，所有会话自动加载 codegraph MCP 工具
- **D-07:** 同时索引 — 项目代码（lib/）和 Flutter SDK 同时索引，覆盖最全
- **D-08:** 已有 codegraph 全局安装 + code-review-graph hooks，升级后验证 MCP 工具正常工作

### Quality Pipeline 评估
- **D-09:** 评估维度限定为测试覆盖率 + 性能基准。静态分析（flutter analyze + strict-casts/strict-inference）已就绪，不需要额外评估
- **D-10:** 输出评估文档 — Markdown 格式（QUALITY-PIPELINE.md），包含工具对比、推荐方案、集成步骤。纯文档，不写代码
- **D-11:** 性能基准评估策略：两者结合 — 先分析现有 perf_monitor.dart / memory_monitor.dart 能力，再对比 Flutter 生态工具（flutter benchmark、DevTools）找出差距
- **D-12:** 不含 CI/CD 集成 — 当前是本地桌面应用无 CI，评估文档中提供建议但不实际配置

### 工具集成深度
- **D-13:** 所有工具使用指南写入 CLAUDE.md — Context7 库 ID 表、codegraph 常用命令、Quality Pipeline 参考。新会话自动生效
- **D-14:** codegraph MCP 配置写入项目 `.mcp.json`，确保 MCP 工具在所有会话中可用

### Claude's Discretion
无 — 所有决策均用户明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/ROADMAP.md` — Phase 6 目标、成功标准、依赖关系（无依赖，可独立开发）
- `.planning/REQUIREMENTS.md` — DEV-01, DEV-02, DEV-03 需求定义
- `.planning/PROJECT.md` — 项目约束、技术环境

### Context7 配置
- `~/.claude/settings.json` — 已有 Context7 plugin 配置（`context7@claude-plugins-official`）
- Context7 库 ID 映射表（见 D-01）

### codegraph 工具
- `@colbymchenry/codegraph` v1.4.1 — npm 包，本地优先代码智能 MCP
- 项目 `.claude/settings.json` — 已有 code-review-graph hooks（PostToolUse + SessionStart）
- codegraph CLI：`init/index/sync/query/explore/node/files/callers` 命令

### 项目现有监控
- `lib/kernel/utils/perf_monitor.dart` — 帧计时、jank 检测
- `lib/kernel/utils/memory_monitor.dart` — 内存使用跟踪
- `lib/kernel/engine/engine_metrics.dart` — 引擎级性能计数器
- `lib/kernel/engine/engine_event_log.dart` — 结构化事件日志

### 设计系统
- `lib/ui/theme/tokens.dart` — Tokens.* 设计令牌
- `analysis_options.yaml` — strict-casts, strict-inference, strict-raw-types

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `codegraph` CLI — 已全局安装 v1.1.6，需升级到 v1.4.1
- `code-review-graph` hooks — 已配置 PostToolUse + SessionStart hooks，codegraph MCP 可复用此模式
- `perf_monitor.dart` — 已有帧计时和 jank 检测，可作为性能基准评估基础
- `memory_monitor.dart` — 已有内存跟踪，可作为内存基准评估基础
- `engine_metrics.dart` — 引擎级性能计数器，与 Quality Pipeline 性能维度相关

### Established Patterns
- `flutter analyze` + strict analysis — 已启用，静态分析基线就绪
- `flutter test` — 测试框架已配置，可扩展覆盖率收集
- MCP plugin 系统 — Context7 通过 plugin 安装，codegraph 可类似配置

### Integration Points
- `CLAUDE.md` — 工具使用指南写入位置
- `.mcp.json` — codegraph MCP 配置写入位置（项目级）
- `~/.claude/settings.json` — 全局 MCP/plugin 配置

</code_context>

<specifics>
## Specific Ideas

- Context7 的 Flutter 中文文档（`/websites/flutter_cn`，4266 snippets）也可作为备选，中文查询时优先使用
- codegraph 的 `explore` 命令可一次返回符号源码 + 调用路径，适合调试疑难问题
- Quality Pipeline 评估文档应包含：当前能力矩阵、生态工具对比、差距分析、推荐方案、集成步骤
- 性能基准可参考：启动时间（ms）、首帧时间（ms）、内存峰值（MB）、包体积（MB）

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 6-开发工作流增强*
*Context gathered: 2026-07-13*
