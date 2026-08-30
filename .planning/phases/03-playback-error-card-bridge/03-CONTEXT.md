# Phase 3: 播放错误桥与非模态卡片 - Context

**Gathered:** 2026-08-30
**Status:** Ready for planning

<domain>
## Phase Boundary

播放/引擎错误统一呈现:engine.lastError 经 PlayerErrorReportBridge 汇入 ErrorReporter,左上角常驻非模态错误卡片(折叠摘要/展开详情/一键复制诊断包),同一 phase 内等效覆盖后删除旧 ErrorBanner(CARD-01~06 + MIG-01)。日志可配置路径属 Phase 4;新增错误来源捕获属 Phase 1/2 已完成范围。

</domain>

<decisions>
## Implementation Decisions

### 多错误呈现
- **D-01:** 替换 + 计数徽标——新错误替换当前卡片内容;折叠区显示错误计数徽标(如「3 错误」),点击徽标可在捕获的错误间轮览;不堆叠多条卡片(避免遮挡) — **Reversibility:** reversible — 徽标逻辑独立于卡片本体
- **D-02:** 严重级分层——error/fatal 上常驻卡片(语义色区分);warning 不上卡片,复用 OsdOverlay 短暂提示(与 Phase 1「warning 不落盘」分层一致,防 warning 洪流常驻遮挡) — **Reversibility:** reversible — 呈现层过滤

### 视觉与交互
- **D-03:** 视觉 = 复用 GlassContainer + Tokens 色板,严重级用语义色(红/fatal 深红)点或边框区分;零新视觉体系 — **Reversibility:** reversible — 纯样式
- **D-04:** 折叠/展开 = 整卡点击切换,chevron 图标指示状态;折叠显示摘要+严重级+媒体路径 basename(D-07 Phase 2 脱敏边界),展开显示文件:行号/源码行 ±2(D-01 Phase 2)/完整调用栈/日志路径 — **Reversibility:** reversible

### 挂载与反馈
- **D-05:** 挂载 = app/player root Stack 顶层(CARD-06 原文),设置 overlay 之下、控制栏之上;设置打开时卡片被覆盖但仍存活,关闭设置后恢复可见 — **Reversibility:** reversible — Stack 位置调整
- **D-06:** 复制反馈 = 复用 OsdOverlay pill——成功「已复制」、失败「复制失败」;复制失败不影响卡片与其余反馈(CARD-04) — **Reversibility:** reversible

### 迁移与数据源
- **D-07:** MIG-01 同 phase 内替换+删除——同一组集成测试同时覆盖新旧两条路径,断言新卡片对同一错误源的可见反馈与旧 ErrorBanner 等效后,在 phase 内删除 error_banner.dart 及其挂载;不留双路径 — **Reversibility:** irreversible-ish — 删除不可逆,但 git 历史可恢复
- **D-08:** 数据源统一——卡片通过 ValueListenableBuilder 订阅 ErrorReporter 呈现状态(ValueNotifier 惯例),所有来源(engine 桥/全局钩子/验证失败)自动汇入同一卡片;PlayerErrorReportBridge 已存在(74 行),本 phase 只需集成测试等效覆盖,不需结构改动 — **Reversibility:** reversible

### 研究后修订决策（2026-08-30，用户拍板）
- **D-09:** 新卡片**不保留**旧 ErrorBanner 的 reopen/retry 动作按钮——卡片职责为信息展示+复制（Unix 原则：只做好一件事）；播放中断类错误的恢复由用户重新打开文件；MIG-01 等效覆盖按「消息+严重级可见性」断言，不含按钮行为 — **Reversibility:** reversible — 可后补按钮
- **D-10:** **media_kit 全屏期间卡片仍显示**——卡片须挂载于全屏 route 之上（root Overlay/navigator 层而非 body Stack 内）；研究已提示此形态的 CARD-02 hit-test 风险更高，规划时须给出严格边界 hit-test 验证 — **Reversibility:** reversible — 挂载层调整
- **D-11:** 计数徽标轮览数据源 = 卡片宿主**本地有界错误快照**（自 reporter presentation 通知维护），不给 kernel 新增只读历史 API — **Reversibility:** reversible
- **D-12:** PlayerFeature 挂载完成前的错误（如 deferred 加载失败）= 宿主首次 `flushPresentation()` 时**补呈现**（MVP 接受窗口内不可见，最终可见） — **Reversibility:** reversible

### Claude's Discretion
- 计数徽标确切样式与轮览交互细节(上一条/下一条 vs 循环)
- warning OSD 提示的节流参数与时长
- 卡片进出动画曲线/时长(slide-in 自左上角)
- 折叠摘要的字段排版与展开区各段顺序(沿用 D-04 Phase 2 诊断包段序为参考)
- 错误卡片与 OSD 同屏时的位置避让规则
- 等效覆盖测试的具体断言集(与 D-07 判定配合)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划文档
- `.planning/REQUIREMENTS.md` — CARD-01~06 / MIG-01 需求全文
- `.planning/ROADMAP.md` — Phase 3 Goal(User Story)与 5 条成功标准
- `.planning/PROJECT.md` — 里程碑目标、Unix 九原则约束(避免强制式 UI 原则直接约束本卡片形态)
- `.planning/phases/02-trusted-location-file-evidence/02-CONTEXT.md` — D-01/04/07(源码行、诊断包格式、脱敏边界)直接约束卡片详情区
- `.planning/phases/02-trusted-location-file-evidence/02-VERIFICATION.md` — Phase 2 验证结论(卡片消费的数据已验证)

### 代码事实源
- `lib/kernel/diagnostics/error_report.dart` — 不可变 ErrorReport 契约(卡片渲染的数据源)
- `lib/kernel/diagnostics/error_reporter.dart` — ErrorReporter 单例(卡片订阅的呈现状态来源)
- `lib/kernel/diagnostics/player_error_report_bridge.dart` — engine.lastError → ErrorReporter 桥(MIG-01 等效覆盖对象)
- `lib/kernel/diagnostics/diagnostic_pack_formatter.dart` — 共享 formatter(CARD-04 一键复制直接调用)
- `lib/ui/player/error_banner.dart` — 旧错误横幅(D-07 删除目标)
- `lib/ui/player/player_video_controls.dart:882-891` — ErrorBanner 当前挂载点(移除位置)
- `lib/ui/shared/osd_overlay.dart` — 浮动 pill 先例(D-02 warning 提示、D-06 复制反馈复用)
- `lib/ui/shared/glass_container.dart` — 玻璃拟态容器(D-03 视觉复用)
- `lib/ui/player/player_screen.dart` — root Stack 组合(D-05 挂载点)
- `lib/ui/theme/tokens.dart` — 语义色 token 来源

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GlassContainer` + `GlassTier`:卡片本体视觉直接复用
- `OsdOverlay`:warning 提示与复制反馈两个场景复用,零新浮层组件
- `formatDiagnosticPack(ErrorReport, {logPath})`:CARD-04 复制按钮直出与日志文件一致的诊断包
- `ErrorReport` 不可变契约 + `ErrorReporterImpl.I` 单例 ValueNotifier:卡片订阅即渲染,无需新状态层
- `PlayerErrorReportBridge`:已实现 engine.lastError → ErrorReporter,MIG-01 只差等效覆盖证明

### Established Patterns
- ValueNotifier + ValueListenableBuilder(不引入新状态库,CARD-06)
- 非模态优先(OSD/floating panel),modal 必须三出口——本卡片为纯非模态
- kernel 禁 debugPrint(CI gate);UI 层可用 debugPrint
- 中文双语 doc comment、conventional commits、analyze 0 error / test 全绿红线

### Integration Points
- `player_screen.dart` root Stack:新增 ErrorCard 子树(CARD-05:build 期错误 post-frame 合并发布)
- `player_video_controls.dart:882-891`:移除 ErrorBanner 挂载
- `main.dart` / 全局钩子:错误已统一进 ErrorReporter,卡片无需新捕获入口

</code_context>

<specifics>
## Specific Ideas

无特殊外部引用——决策集中在交互形态(多错误/展开/反馈/层级),技术形态全部复用 Phase 1/2 既有契约与 UI 资产

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 3-播放错误桥与非模态卡片*
*Context gathered: 2026-08-30*
