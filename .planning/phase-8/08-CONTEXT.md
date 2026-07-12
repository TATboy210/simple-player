# Phase 8: 删除不必要的抽象层 - Context

**Gathered:** 2026-07-12
**Status:** Ready for planning

<domain>
## Phase Boundary

删除 6 个过度工程化的全屏抽象文件（757 行源码 + ~2,000 行测试），简化 DesktopFullscreenAdapter 内部状态从 `FullscreenSnapshot` 到 `ValueNotifier<bool>`，更新消费者代码（WindowService、main.dart），确保全屏功能不退化。

本阶段不涉及 WindowService 合并（Phase 9）或平台整合（Phase 10）。

</domain>

<decisions>
## Implementation Decisions

### DesktopFullscreenAdapter 内部状态简化
- **D-01:** **Phase 8 内先简化再删除** — 先把 adapter 内部状态从 `FullscreenSnapshot` 简化为 `ValueNotifier<bool>`，然后再删 model 文件。每步都编译通过。（研究推荐方案）
- **D-02:** **保留三级确认链** — Level 1 callback → Level 2 polling → Level 3 timeout。当前在 DesktopFullscreenAdapter 内部实现，简化后保留这个确认机制。
- **D-03:** **删除以下能力** — 恢复策略（_RestoreSnapshot）、Windows FFI 快速路径（is WindowsFullscreenDriver 检测）、事件广播系统（FullscreenEvent stream）。这些在 Phase 8 简化时移除。
- **D-04:** **用 ValueNotifier<bool> 替代事件流** — 删除 FullscreenEvent 事件流，改为 `ValueNotifier<bool> isFullscreen`。WindowService 监听这个 bool 变化来同步状态。（研究推荐方案）
- **D-05:** **用 try-catch + debugPrint 替代错误模型** — 删除 FullscreenError sealed class，全屏操作失败时用 try-catch 捕获 + debugPrint 记录。符合项目现有错误处理模式（ARCHITECTURE.md: "Defensive catch with debugPrint/log + graceful fallback"）。

### Claude's Discretion
- 删除顺序（叶子节点优先）和提交策略留给实现阶段
- 具体的测试更新策略（删除 vs 适配）留给实现阶段
- DesktopFullscreenAdapter 简化后的具体代码结构留给实现阶段

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/PROJECT.md` — 项目全貌、核心价值、约束、已锁定决策
- `.planning/REQUIREMENTS.md` — 22 个 v1 需求，Phase 8 涉及 SIMPLIFY-01/02/03
- `.planning/ROADMAP.md` — v3 路线图，Phase 8 目标和成功标准
- `.planning/STATE.md` — 当前项目状态

### 研究与分析
- `.planning/phase-8/08-RESEARCH.md` — Phase 8 完整研究：文件验证、依赖关系、删除顺序、风险评估
- `.planning/codebase/fullscreen-reverse-analysis.md` — 全屏系统逆向分析：6 个问题、测试覆盖缺口
- `.planning/codebase/ARCHITECTURE.md` — 系统架构、分层、状态管理模式、错误处理策略

### 现有实现（要删除的文件）
- `lib/kernel/bridge/fullscreen_adapter.dart` — Abstract adapter interface (68 lines)
- `lib/kernel/bridge/fullscreen_command_queue.dart` — Per-window 命令队列 (258 lines)
- `lib/kernel/models/fullscreen_snapshot.dart` — 状态快照模型 (127 lines)
- `lib/kernel/models/fullscreen_error.dart` — 7 种错误类型 (145 lines)
- `lib/kernel/models/fullscreen_event.dart` — 7 种生命周期事件 (108 lines)
- `lib/kernel/models/fullscreen_request.dart` — Enter/Leave/Toggle 请求 (51 lines)

### 现有实现（要修改的文件）
- `lib/kernel/bridge/desktop_fullscreen_adapter.dart` — 具体适配器实现 (520 lines)，需简化内部状态
- `lib/kernel/bridge/window_service.dart` — 窗口管理服务 (380 lines)，需改事件同步方式
- `lib/main.dart` — 入口文件，需改类型声明

### 测试文件（要删除的）
- `test/kernel/bridge/fullscreen_adapter_test.dart` — Adapter 测试 (651 lines)
- `test/kernel/bridge/fullscreen_command_queue_test.dart` — 命令队列测试 (536 lines)
- `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` — Adapter 行为测试 (777 lines)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **ValueNotifier 模式** — 项目统一使用 ValueNotifier + ValueListenableBuilder 管理状态，简化后直接复用
- **三级确认链逻辑** — `_waitForConfirmation` / `_registerConfirmation` 方法保留，不依赖删除的 model
- **debugPrint 错误处理** — 项目标准模式：`debugPrint('...')` + graceful fallback

### Established Patterns
- **ValueNotifier + ValueListenableBuilder** — 全项目统一状态管理模式，简化后保持一致
- **Composition over inheritance** — FvpEngine 由 6 个 helper 组成，DesktopFullscreenAdapter 可借鉴
- **Defensive catch** — `try-catch + debugPrint` 是项目标准错误处理模式

### Integration Points
- **WindowService** — 监听 `ValueNotifier<bool> isFullscreen` 替代 `Stream<FullscreenEvent>`
- **main.dart** — 类型声明从 `FullscreenAdapter?` 改为 `DesktopFullscreenAdapter?`
- **测试文件** — 3 个测试文件删除，其余测试文件更新 import

</code_context>

<specifics>
## Specific Ideas

- 简化后的 DesktopFullscreenAdapter 状态管理：`final ValueNotifier<bool> _isFullscreen = ValueNotifier(false);`
- 简化后的 WindowService 事件同步：`_fullscreenAdapter?.isFullscreen.addListener(_onFullscreenChanged);`
- 简化后的 main.dart 初始化：`DesktopFullscreenAdapter? fullscreenAdapter;`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 8-删除不必要的抽象层*
*Context gathered: 2026-07-12*
