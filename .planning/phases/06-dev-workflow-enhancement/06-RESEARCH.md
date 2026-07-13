# Phase 6: 开发工作流增强 - Research

**Researched:** 2026-07-13
**Domain:** Developer tooling — Context7 documentation queries, codegraph source analysis, Quality Pipeline evaluation
**Confidence:** HIGH

## Summary

This phase configures and evaluates three developer workflow tools: Context7 for Flutter API documentation queries, codegraph for source code intelligence, and a Quality Pipeline assessment covering test coverage and performance benchmarks. The scope is configuration, documentation, and evaluation — no CI/CD integration, no code quality rule changes.

All three tools have existing infrastructure in the project: Context7 is already installed as a Claude plugin (`context7@claude-plugins-official`), codegraph is globally installed at v1.1.6 with an existing project index (302 files, 4019 nodes), and the project already has `PerfMonitor`, `MemoryMonitor`, and `EngineMetrics` for performance monitoring. The main work is upgrading codegraph to v1.4.1, writing configuration and documentation, and producing an evaluation document.

**Primary recommendation:** Upgrade codegraph to v1.4.1, write Context7 library ID mapping table into CLAUDE.md, configure codegraph MCP in `.mcp.json`, and produce a QUALITY-PIPELINE.md evaluation document.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Context7 documentation queries | Claude Plugin (global) | CLAUDE.md (project config) | Plugin is already installed globally; project config maps library IDs for quick reference |
| codegraph source analysis | npm CLI (global) | `.mcp.json` (project MCP) | CLI is globally installed; MCP config makes tools available in all sessions |
| Quality Pipeline evaluation | Documentation only | — | No code changes; evaluation document captures findings |

## User Constraints (from CONTEXT.md)

### Implementation Decisions

**Context7 配置策略:**
- **D-01:** 全量覆盖 — 配置 Flutter SDK (API + 指南) + fvp + shared_preferences + window_manager 为常用查询目标。库 ID：`/websites/api_flutter_dev`、`/websites/flutter_dev`、`/wang-bin/fvp`、`/websites/pub_dev_packages_shared_preferences`、`/leanflutter/window_manager`
- **D-02:** 按需查询 — 只在用户明确问或需要查 API 时才调用 Context7，不主动查询
- **D-03:** 精准查询 — 每次用具体问题（如 "AnimatedSlide 用法"），不泛泛搜索，减少返回噪音
- **D-04:** 写入 CLAUDE.md — 添加 Context7 库 ID 映射表 + 使用场景 + 注意事项，新会话自动生效

**codegraph 源码分析:**
- **D-05:** 升级 codegraph — 从 v1.1.6 升到 v1.4.1（最新），获得最新功能和 bug 修复
- **D-06:** 项目级 MCP 配置 — 将 codegraph 配置写入项目 `.mcp.json`，所有会话自动加载 codegraph MCP 工具
- **D-07:** 同时索引 — 项目代码（lib/）和 Flutter SDK 同时索引，覆盖最全
- **D-08:** 已有 codegraph 全局安装 + code-review-graph hooks，升级后验证 MCP 工具正常工作

**Quality Pipeline 评估:**
- **D-09:** 评估维度限定为测试覆盖率 + 性能基准。静态分析（flutter analyze + strict-casts/strict-inference）已就绪，不需要额外评估
- **D-10:** 输出评估文档 — Markdown 格式（QUALITY-PIPELINE.md），包含工具对比、推荐方案、集成步骤。纯文档，不写代码
- **D-11:** 性能基准评估策略：两者结合 — 先分析现有 perf_monitor.dart / memory_monitor.dart 能力，再对比 Flutter 生态工具（flutter benchmark、DevTools）找出差距
- **D-12:** 不含 CI/CD 集成 — 当前是本地桌面应用无 CI，评估文档中提供建议但不实际配置

**工具集成深度:**
- **D-13:** 所有工具使用指南写入 CLAUDE.md — Context7 库 ID 表、codegraph 常用命令、Quality Pipeline 参考。新会话自动生效
- **D-14:** codegraph MCP 配置写入项目 `.mcp.json`，确保 MCP 工具在所有会话中可用

### Claude's Discretion
无 — 所有决策均用户明确选择。

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEV-01 | Flutter SDK 文档查询集成 — 通过 Context7 MCP 在开发时快速查询 Flutter API 文档 | Context7 plugin already installed; 5 library IDs verified via `resolve-library-id`; library ID mapping table ready for CLAUDE.md |
| DEV-02 | Flutter SDK 源码参考能力 — 通过 codegraph 分析 SDK 源码解决疑难问题 | codegraph v1.1.6 installed with existing index (302 files, 4019 nodes); v1.4.1 available on npm; `.mcp.json` pattern established with code-review-graph |
| DEV-03 | Flutter Quality Pipeline 评估 — 理解其设计，输出集成方案建议 | Existing `PerfMonitor` (162 lines), `MemoryMonitor` (193 lines), `EngineMetrics` (91 lines) provide baseline; 91 test files exist; `analysis_options.yaml` has strict mode |

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Context7 (Claude plugin) | `context7@claude-plugins-official` | Real-time Flutter API docs query | Official Claude plugin, already installed, 30k+ snippets for Flutter |
| codegraph | v1.4.1 (upgrade from v1.1.6) | Local-first code intelligence MCP | Tree-sitter based, SQLite WAL, supports Dart/C++/Swift, MCP integration |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| code-review-graph | Already configured in `.mcp.json` | Python-based code review graph | Existing PostToolUse + SessionStart hooks; complements codegraph |
| flutter test | Flutter 3.44.6 | Test runner for coverage | Existing 91 test files; `--coverage` flag for coverage collection |
| flutter analyze | Flutter 3.44.6 | Static analysis | Already configured with strict-casts, strict-inference, strict-raw-types |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Context7 plugin | WebSearch + manual doc lookup | Slower, less accurate, no snippet-level retrieval |
| codegraph MCP | code-review-graph alone | code-review-graph is Python-based, heavier; codegraph is lighter, faster, supports `explore`/`callers`/`impact` |
| flutter benchmark | Custom benchmark harness | flutter benchmark is official but requires CI setup; custom harness is simpler for local use |

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| @colbymchenry/codegraph | npm | Published 2026-07-10 | 83,640/wk | None listed | [SUS] | Flagged — planner must add checkpoint:human-verify before upgrade. Reasons: "too-new" (3 days old), "no-repository" |

**Packages flagged as suspicious [SUS]:** `@colbymchenry/codegraph` v1.4.1 — published 3 days ago, no source repo linked. However, v1.1.6 is already installed and working in the project. The upgrade is incremental. Planner must verify the package works correctly after upgrade.

**Note:** Context7 is a Claude official plugin, not an npm package — no registry verification needed. code-review-graph is a Python package installed via pip, not in scope for this audit.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                  Claude Code Session             │
│                                                  │
│  ┌──────────────┐  ┌──────────────┐             │
│  │  Context7     │  │  codegraph   │             │
│  │  Plugin       │  │  MCP Server  │             │
│  │  (global)     │  │  (project)   │             │
│  └──────┬───────┘  └──────┬───────┘             │
│         │                  │                     │
│  ┌──────▼───────┐  ┌──────▼───────┐             │
│  │ Context7 API  │  │ SQLite WAL   │             │
│  │ (remote)      │  │ .codegraph/  │             │
│  └──────────────┘  └──────────────┘             │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │           CLAUDE.md (project)             │   │
│  │  - Context7 library ID mapping table      │   │
│  │  - codegraph common commands              │   │
│  │  - Quality Pipeline reference             │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │           .mcp.json (project)             │   │
│  │  - codegraph MCP server config            │   │
│  │  - code-review-graph (existing)           │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
.planning/phases/06-dev-workflow-enhancement/
├── 06-CONTEXT.md          # User decisions (exists)
├── 06-RESEARCH.md         # This file
├── 06-01-PLAN.md          # Context7 + codegraph config plan
└── 06-02-PLAN.md          # Quality Pipeline evaluation plan

# Output files (created by implementation):
CLAUDE.md                  # Updated with Context7 IDs + codegraph commands
.mcp.json                  # Updated with codegraph MCP config
.planning/QUALITY-PIPELINE.md  # Quality Pipeline evaluation document
```

### Pattern 1: Context7 Library ID Mapping in CLAUDE.md

**What:** Add a table mapping library names to Context7 IDs so any Claude session can quickly look up docs.
**When to use:** When a project depends on multiple external libraries and developers frequently need API reference.
**Example:**

```markdown
## Context7 Documentation Lookup

Use Context7 MCP to query Flutter API docs. Always use `resolve-library-id` first.

| Library | Context7 ID | Snippets | Use For |
|---------|-------------|----------|---------|
| Flutter API | `/websites/api_flutter_dev` | 30,590 | Widget API, class reference |
| Flutter Guide | `/websites/flutter_dev` | 10,777 | How-to guides, concepts |
| fvp | `/wang-bin/fvp` | 105 | Video player plugin API |
| shared_preferences | `/websites/pub_dev_packages_shared_preferences` | 370 | Key-value storage |
| window_manager | `/leanflutter/window_manager` | 126 | Window control |

**Rules:**
- Only query when user asks or API behavior is unclear
- Use specific queries ("AnimatedSlide usage"), not broad searches
- Chinese docs: `/websites/flutter_cn` (4,266 snippets)
```

### Pattern 2: codegraph MCP Project Configuration

**What:** Configure codegraph as a project-level MCP server in `.mcp.json`.
**When to use:** When codegraph CLI is installed globally and you want MCP tools available in all project sessions.
**Example:**

```json
{
  "mcpServers": {
    "code-review-graph": {
      "command": "D:\\python xuniji\\.ai\\Scripts\\code-review-graph.exe",
      "args": ["serve"],
      "cwd": "D:\\simple_player_flutter",
      "env": { "PYTHONUTF8": "1" },
      "type": "stdio"
    },
    "codegraph": {
      "command": "npx",
      "args": ["-y", "@colbymchenry/codegraph@1.4.1", "serve"],
      "cwd": "D:\\simple_player_flutter",
      "type": "stdio"
    }
  }
}
```

### Anti-Patterns to Avoid

- **Broad Context7 queries:** Searching "Flutter widget" returns thousands of irrelevant snippets. Always use specific class/method names.
- **Skipping `resolve-library-id`:** The library ID can change between sessions. Always resolve first.
- **Manual codegraph index management:** Use `codegraph sync` for incremental updates, not full `index` rebuilds unless needed.
- **Mixing codegraph and code-review-graph tools:** They serve different purposes. codegraph is for source navigation; code-review-graph is for code review with knowledge graph. Use the right tool for the task.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| API documentation lookup | Custom web scraper or manual search | Context7 MCP plugin | 30k+ snippets, snippet-level retrieval, already installed |
| Source code navigation | Manual `grep`/`find` across codebase | codegraph `query`/`explore`/`callers` | Tree-sitter parsed, call graph, impact analysis |
| Performance benchmarking | Custom timer wrappers | `PerfMonitor` + `flutter benchmark` | Existing `PerfMonitor` already tracks build/raster times; `flutter benchmark` is official |

## Common Pitfalls

### Pitfall 1: codegraph Index Staleness After Upgrade

**What goes wrong:** After upgrading codegraph from v1.1.6 to v1.4.1, the existing index may be incompatible or missing new features.
**Why it happens:** Database schema or parser improvements between versions.
**How to avoid:** Run `codegraph index` (full rebuild) after upgrading, not just `sync`.
**Warning signs:** The `codegraph status` output already shows: "Index was built by an earlier version; re-index to pick up this engine's improvements."

### Pitfall 2: codegraph Flutter SDK Index Scope

**What goes wrong:** Indexing the Flutter SDK (`D:/flutter/`) is slow and produces a massive database.
**Why it happens:** The Flutter SDK contains thousands of files across multiple platforms.
**How to avoid:** Use `codegraph init --include "*.dart"` to limit to Dart files only. Consider indexing only `packages/flutter/lib/` rather than the entire SDK.
**Warning signs:** Index takes >5 minutes or database exceeds 100MB.

### Pitfall 3: Context7 Library ID Instability

**What goes wrong:** Library IDs in CLAUDE.md become stale if Context7 reorganizes their index.
**Why it happens:** Context7 IDs are URL-path-based and can change.
**How to avoid:** Document that `resolve-library-id` should always be called first; the table is a convenience, not a guarantee.
**Warning signs:** Queries returning empty results for known libraries.

### Pitfall 4: MCP Server Conflicts

**What goes wrong:** Both codegraph and code-review-graph MCP servers running simultaneously cause resource contention.
**Why it happens:** Both parse the same codebase, both use SQLite.
**How to avoid:** They serve different purposes and can coexist. Monitor for lock contention on `.codegraph/` database.
**Warning signs:** MCP tool calls timing out or returning stale data.

## Code Examples

### codegraph CLI Usage Patterns

```bash
# Initialize index (first time or after upgrade)
codegraph init D:/simple_player_flutter

# Incremental sync after code changes
codegraph sync D:/simple_player_flutter

# Check index status
codegraph status D:/simple_player_flutter

# Search for a symbol
codegraph query "PlaybackController" --path D:/simple_player_flutter

# Explore a symbol: source + call paths
codegraph explore "PlaybackController.open" --path D:/simple_player_flutter

# Find callers of a method
codegraph callers "MediaEngine.play" --path D:/simple_player_flutter

# Impact analysis before refactoring
codegraph impact "SettingsStore" --path D:/simple_player_flutter

# Install MCP server for Claude Code
codegraph install --agent claude
```

### Context7 MCP Query Pattern

```
# Step 1: Resolve library ID
mcp__context7__resolve-library-id(query="AnimatedSlide widget", libraryName="Flutter")

# Step 2: Query docs with specific question
mcp__context7__query-docs(libraryId="/websites/api_flutter_dev", query="How to use AnimatedSlide widget with offset")
```

### Quality Pipeline Assessment Structure

```markdown
# Quality Pipeline Assessment

## Current Capabilities
| Dimension | Tool | Status | Gap |
|-----------|------|--------|-----|
| Static Analysis | flutter analyze + strict mode | ✅ Complete | None |
| Test Coverage | flutter test --coverage | ⚠️ Partial | No coverage reporting configured |
| Performance | PerfMonitor + MemoryMonitor | ⚠️ Partial | No baseline benchmarks |
| Code Review | code-review-graph hooks | ✅ Complete | None |

## Recommended Tools
| Need | Tool | Integration |
|------|------|-------------|
| Coverage reporting | `flutter test --coverage` + lcov | Add to CLAUDE.md |
| Benchmark suite | `flutter benchmark` | Local, no CI needed |
| Memory profiling | DevTools + existing MemoryMonitor | Already available |
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual grep for API docs | Context7 MCP snippet retrieval | Context7 plugin installed | 30k+ Flutter snippets, query-specific |
| Manual file navigation | codegraph tree-sitter index | codegraph v1.1.6 installed | 4019 nodes, call graph, impact analysis |
| No performance baseline | PerfMonitor + MemoryMonitor | Already in codebase | Frame timing, RSS tracking, but no benchmark suite |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All phases | ✓ | 3.44.6 | — |
| Node.js/npm | codegraph install | ✓ | (system) | — |
| Context7 plugin | DEV-01 | ✓ | `context7@claude-plugins-official` | — |
| codegraph CLI | DEV-02 | ✓ | v1.1.6 (upgrade to v1.4.1) | — |
| code-review-graph | Existing hooks | ✓ | Installed at `D:\python xuniji\.ai\Scripts\` | — |
| SQLite | codegraph index | ✓ | Built-in (WAL mode) | — |
| Python | code-review-graph | ✓ | (system) | — |

**Missing dependencies with no fallback:** None

**Missing dependencies with fallback:** None — all dependencies are available.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter 3.44.6) |
| Config file | `analysis_options.yaml` (strict mode) |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEV-01 | Context7 library ID mapping in CLAUDE.md | manual-only | N/A — documentation verification | N/A |
| DEV-02 | codegraph MCP configured and working | manual-only | `codegraph status` + MCP tool test | N/A |
| DEV-03 | Quality Pipeline evaluation document exists | manual-only | N/A — document verification | N/A |

**Note:** This phase produces configuration and documentation, not code. All verification is manual (check that CLAUDE.md has the right content, `.mcp.json` is valid, codegraph MCP tools respond, QUALITY-PIPELINE.md exists and is comprehensive).

### Sampling Rate

- **Per task commit:** Manual verification of outputs
- **Phase gate:** All three deliverables exist and are correct

### Wave 0 Gaps

- None — this phase has no testable code output

## Sources

### Primary (HIGH confidence)
- Context7 `resolve-library-id` — verified all 6 library IDs (Flutter API, Flutter Guide, fvp, shared_preferences, window_manager, Flutter CN)
- npm registry — `@colbymchenry/codegraph@1.4.1` confirmed available (published 2026-07-10)
- codegraph CLI `--help` — confirmed available commands: init/index/sync/query/explore/node/files/callers/callees/impact/affected/install
- codegraph `status` — existing index: 302 files, 4019 nodes, 10984 edges, 23.21 MB, WAL mode

### Secondary (MEDIUM confidence)
- codegraph package legitimacy — [SUS] verdict: "too-new" (3 days), "no-repository". Existing v1.1.6 installation provides confidence in the package.

### Tertiary (LOW confidence)
- Flutter benchmark tooling — based on training knowledge about `flutter benchmark` command. Not verified via Context7 or official docs in this session.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `flutter benchmark` is the official Flutter benchmarking command | Quality Pipeline | May need to use `flutter run --profile` + custom benchmarks instead |
| A2 | codegraph v1.4.1 index format is backward-compatible with v1.1.6 database | Pitfall 1 | May need to delete `.codegraph/` and rebuild from scratch |
| A3 | codegraph MCP server starts via `npx -y @colbymchenry/codegraph@1.4.1 serve` | Pattern 2 | May need different command; verify with `codegraph install --agent claude` |

## Open Questions

1. **codegraph Flutter SDK indexing scope**
   - What we know: D-07 says "同时索引 — 项目代码（lib/）和 Flutter SDK"
   - What's unclear: Full Flutter SDK (`D:/flutter/`) is very large; should we index only `packages/flutter/lib/` or the entire SDK?
   - Recommendation: Index `D:/flutter/packages/flutter/lib/` for Dart source only. Full SDK includes engine, tools, tests — too broad.

2. **codegraph MCP server command format**
   - What we know: `codegraph install --agent claude` can auto-configure MCP
   - What's unclear: Whether auto-install writes to project `.mcp.json` or global settings
   - Recommendation: Use `codegraph install --agent claude` first; if it writes to global, manually add to `.mcp.json` per D-06.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools verified via CLI/npm/Context7
- Architecture: HIGH — existing patterns (`.mcp.json`, CLAUDE.md) clearly define integration points
- Pitfalls: MEDIUM — codegraph upgrade compatibility is assumed, not verified

**Research date:** 2026-07-13
**Valid until:** 2026-08-13 (stable — tools are mature, no rapid changes expected)
