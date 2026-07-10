# Phase D: 质量收尾与迁移完成 - Context

**Gathered:** 2026-07-10
**Status:** Ready for planning

<domain>
## Phase Boundary

回归矩阵验证、CI 补齐、旧实现可下线、RC 版本发布。这是全屏升级项目的收尾阶段，确保所有 v1 需求验收通过，旧代码可安全移除。

本阶段不实现新功能，只做验证、收尾和发布。

</domain>

<decisions>
## Implementation Decisions

### 回归矩阵验证标准 (REG)
- **D-32:** **标准版测试深度**（24-40 用例）：8 项必测场景每项 3-5 个测试用例，覆盖正常+异常路径。分层配比：单元 40%（队列/幂等/错误/恢复策略）、集成 40%（Driver + Adapter + WindowService）、E2E 20%（真实窗口行为）。
- **D-33:** **每项 3 类覆盖**：正常路径、超时/回调缺失路径、恢复/重试路径。
- **D-34:** **平台优先级**：Windows 深测（最多用例）、macOS 次之、Linux 至少覆盖 GNOME + 1 个补充 WM。
- **D-35:** **高风险套件**（必须单独建）：快速连按 F（10/50 次）、maximized → fullscreen → exit、副屏拔插后恢复、StateDesync 后手动重试恢复。
- **D-36:** **通过门槛**：P0 用例 100% 通过、不允许 silent failure、同一失败可稳定复现并有错误事件/日志可追踪。
- **D-37:** **平台覆盖范围**：Windows 深测 + macOS/Linux 冒烟测试。最小门槛：Windows 全量关键场景、macOS/Linux 8 项场景各至少 1 条主路径冒烟。升级触发条件：若 macOS/Linux 冒烟失败率 >10% 或出现 blocker，立刻提升该平台为"深测"。Linux 说明：冒烟至少覆盖 1 个主流 WM（建议 GNOME），并在报告写明"其余 WM best-effort"。发布判定：任何平台出现"状态错乱/无法恢复窗口/卡死"即阻断发布。
- **D-38:** **文档格式**：混合模式（Markdown 文档 + JSON 配置）。统一用例 ID（如 FS-WIN-001）、字段标准化（平台/场景/前置条件/步骤/期望/结果/日志链接）、结果状态枚举（pass/fail/blocked/flaky/skipped）、阻断规则（哪些失败直接阻断发布）、证据链接（截图、日志、错误事件、commit/PR）、回归基线版本（每次测试必须标注分支、构建号、flag 配置）。
- **D-39:** **执行策略**：渐进式验证（每个 Plan 完成后跑相关场景的回归）。组合策略：现在用渐进式验证做主流程，同时把最小冒烟子集接入 CI（渐进式 + 轻量 CI）。建议节奏：每个 Plan 完成后跑对应回归子集、每周跑一次跨平台冒烟、里程碑（RC 前）跑全量回归。
- **D-40:** **执行方式**：半自动化。自动化优先清单：队列/幂等/超时/错误模型、maximized → fullscreen → exit、快速切换（10/50 次）。手动保留清单：多显示器拔插/拓扑变化、焦点与置顶残留、Linux WM 差异体验确认。通过门槛：自动化 P0 100% 通过、手动 blocker 为 0。失败分级：blocker/high/medium/low，明确是否阻断发布。
- **D-41:** **执行环境**：混合执行（本地 + CI）。本地必须和 CI 使用同一回归配置文件（避免"本地过、CI 挂"）。CI 先跑自动化子集；手动项在 RC 阶段补证据。每次结果都记录构建号 + flag（如 USE_NEW_FULLSCREEN）。失败必须附日志/事件证据链接（不是只写 fail）。

### CI 补齐策略 (CI)
- **D-42:** **CI 平台**：GitHub Actions。
- **D-43:** **CI 阶段**：测试 + 构建。跑单元测试、集成测试 + 三端构建冒烟测试。
- **D-44:** **CI 平台覆盖**：三端覆盖。Windows 深测 + macOS/Linux 冒烟。
- **D-45:** **CI 触发时机**：全触发（PR 合并 + 定时 + 手动触发）。

### 旧实现下线时机 (DECOM)
- **D-46:** **下线时机**：RC 版本发布后保留 1-2 个版本，确保稳定后再移除。下线门槛：2 个版本内无 blocker 级 fullscreen 问题、StateDesync/PlatformFailure 率低于阈值、回归矩阵连续通过后再删旧实现。
- **D-47:** **删除方式**：渐进式删除。先标记为 deprecated，再删除。

### RC 版本发布流程 (RC)
- **D-48:** **版本号策略**：语义化版本（如 v1.0.0-rc.1）。
- **D-49:** **发布渠道**：GitHub Release + MSIX 打包。
- **D-50:** **用户验收流程**：小范围测试（内部验证 + 小范围用户测试）。
- **D-51:** **打包方式**：CI 自动打包。
- **D-52:** **发布方式**：混合发布（手动触发 + CI 自动执行）。

### Claude's Discretion
- 具体的测试用例编写细节留给实现阶段
- CI 的具体配置（如 GitHub Actions YAML）留给实现阶段
- MSIX 打包的具体配置留给实现阶段
- 小范围用户测试的具体人选和流程留给实现阶段

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/PROJECT.md` — 项目全貌、核心价值、约束、已锁定决策
- `.planning/REQUIREMENTS.md` — 22 个 v1 需求，Phase D 涉及所有需求验收
- `.planning/ROADMAP.md` — 4 阶段路线图，Phase D 目标和成功标准
- `.planning/STATE.md` — 当前项目状态
- `.planning/phases/01-architecture-core-models/01-CONTEXT.md` — Phase A 决策（D-01~11），Phase D 必须遵循
- `.planning/phases/02-command-queue-recovery/02-CONTEXT.md` — Phase B 决策（D-12~31），命令队列/恢复策略/迁移路径
- `.planning/phases/03-platform-adaptation/03-CONTEXT.md` — Phase C 决策（D-P01~P13），平台驱动实现

### 现有实现
- `lib/kernel/bridge/fullscreen_adapter.dart` — FullscreenAdapter 抽象接口
- `lib/kernel/bridge/desktop_fullscreen_adapter.dart` — DesktopFullscreenAdapter 实现
- `lib/kernel/bridge/fullscreen_command_queue.dart` — 命令队列实现
- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` — Windows 平台驱动
- `lib/kernel/bridge/platform/macos_fullscreen_driver.dart` — macOS 平台驱动
- `lib/kernel/bridge/platform/linux_fullscreen_driver.dart` — Linux 平台驱动
- `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` — 驱动工厂
- `lib/kernel/models/fullscreen_snapshot.dart` — 状态快照模型
- `lib/kernel/models/fullscreen_event.dart` — 事件模型
- `lib/kernel/models/fullscreen_error.dart` — 错误模型
- `lib/kernel/models/fullscreen_capability.dart` — 能力查询模型

### 测试相关
- `test/kernel/bridge/fullscreen_adapter_test.dart` — Adapter 测试
- `test/kernel/bridge/fullscreen_command_queue_test.dart` — 命令队列测试
- `test/platform/windows_fullscreen_driver_test.dart` — Windows 驱动测试
- `test/platform/macos_fullscreen_driver_test.dart` — macOS 驱动测试
- `test/platform/linux_fullscreen_driver_test.dart` — Linux 驱动测试

### CI/发布相关
- `.github/workflows/` — GitHub Actions 配置目录（待创建）
- `distribute_options.yaml` — MSIX 打包配置

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **现有测试框架**: flutter_test + integration_test，可直接用于回归矩阵
- **MSIX 打包配置**: distribute_options.yaml 已有基础配置
- **编译时 flag**: USE_NEW_FULLSCREEN + USE_WINDOWS_NATIVE_FULLSCREEN，CI 需要测试两种配置

### Established Patterns
- **ValueNotifier + ValueListenableBuilder**: 状态管理模式，测试需要验证
- **Composition over inheritance**: 模块组合模式，集成测试需要验证模块间协作
- **三级确认**: 回调→轮询→超时，需要测试超时和回调缺失路径

### Integration Points
- **FullscreenAdapter**: 所有测试的入口点
- **WindowService**: 迁移验证的关键点
- **GitHub Actions**: CI/CD 集成点

</code_context>

<specifics>
## Specific Ideas

- 回归矩阵必须包含高风险套件：快速连按 F（10/50 次）、maximized → fullscreen → exit、副屏拔插后恢复、StateDesync 后手动重试恢复
- CI 必须测试两种配置：USE_NEW_FULLSCREEN=true 和 USE_NEW_FULLSCREEN=false
- 旧实现下线必须有明确门槛：2 个版本内无 blocker 级问题、StateDesync/PlatformFailure 率低于阈值
- RC 版本发布必须有小范围用户验收流程

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: D-质量收尾与迁移完成*
*Context gathered: 2026-07-10*
