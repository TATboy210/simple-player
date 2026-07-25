# Phase 23: Overlay Shell & State Model - Context

**Gathered:** 2026-07-22
**Status:** Ready for planning

<domain>
## Phase Boundary

绘制设置面板的覆盖层壳(毛玻璃 + 遮罩 + 标题栏),建立 `SettingsPanelState` 状态模型与 `SettingsPanelController` 控制器,实现打开/关闭/暂停/恢复完整生命周期。**壳先于内容**:Phase 23 只建壳骨架 + 状态/控制器 + 生命周期,不实现 tab 内容与具体设置项(属 Phase 25)。视频暂停/恢复经 `PlaybackController` 协调,不直碰 `MediaEngine`。

覆盖 7 项需求:PANEL-01(状态模型 3 notifier)~ PANEL-07(尺寸 500×400 / ≤窗口 80%)。

</domain>

<decisions>
## Implementation Decisions

### 状态/控制器落点

- **D-01:** 文件落点 — 就地拆 `lib/ui/dialogs/settings_panel.dart`(实测 945 行,PROJECT.md 记的 ~500 已过时),提取 `SettingsPanelState` + `SettingsPanelController` 到**已存在**的 `lib/ui/dialogs/settings/` 子目录(与 7 个 tab 文件同住)。渐进 Strangler 重构,不新建并列目录,不动 `lib/kernel/`。
- **D-02:** 依赖注入 — 构造注入 `SettingsPanelController(playbackController)`,组合根(`app.dart` / `PlayerServices`)装配。不用 DI 框架 / 服务定位 / `BuildContext` 取依赖。
- **D-03:** 暂停契约 — `open()` 调 `PlaybackController.pause()`(**经编排器,不直碰 `MediaEngine`**,避免与 `openGeneration` 守卫竞态);`wasPlaying = MediaEngine.isPlaying` notifier 快照;打开前已暂停则 `wasPlaying=false`,`close()` 不恢复播放;`close()` 仅在 `wasPlaying=true` 时恢复。
- **D-04:** 范围边界 — Phase 23 的 `SettingsPanelState` 仅持 3 个 notifier(`isOpen`/`selectedTab`/`dragOffset` per PANEL-01)。现有 `_pendingLocale`/`_pendingThemeIndex`/`_originalShortcuts` 延迟应用状态**暂留 widget 本地**,Phase 25(TABS-04)再迁移,Phase 23 不触及。

### 覆盖层挂载方式

- **D-05:** 挂载方式 — **Stack in-tree**(跟随 `playlist_panel.dart` 既有模式,非 showDialog)。覆盖层(遮罩 + 面板)作为 `PlayerScreen` Stack 的一层,由 `isOpen` notifier 控制可见性与动画;遮罩与面板为 Stack 兄弟节点,遮罩 `GestureDetector` 点击关闭(PANEL-05)。面板关闭时 `IgnorePointer`/`Visibility` 卸载命中。— **Reversibility:** costly — 切换挂载模型(如改回 showDialog)后须重建壳的组合根 + 动画/拖拽接线,触及整个壳结构。
- **D-06:** 新旧过渡 — **壳取代触发器**(Strangler 渐进)。新壳骨架就位后接管设置入口触发器(齿轮按钮 / 快捷键);tab 内容复用旧 `settings/` 7 文件(已与 showDialog 解耦);老 `settings_panel.dart`(showDialog,945 行)在新壳能完整取代后于**独立提交**删除(永不与 feature 捆绑)。

### 开/关动画实现

- **D-07:** 动画载体与时长 — `AnimatedOpacity` + `AnimatedScale`(PANEL-05 锁定,Scale + Fade);时长 **200ms** 与 P24 侧边栏 `FadeTransition` 一致(面板与侧边栏动画节奏统一)。
- **D-08:** 动画曲线 — **采用 `apple_curves.dart`**。该文件当前**未跟踪**(untracked),Phase 23 须先将其纳入 git 并核实其曲线 API(曲线名/参数/签名)再采用。— **Reversibility:** costly — 依赖未跟踪的 `apple_curves.dart` API;若曲线不适用,事后切换须返工开/关动画的 tween 引用。researcher/planner 须在实现前确认其 commit 状态与可用曲线。

### 拖拽与键盘关闭复用

- **D-09:** 拖拽实现 — **in-canvas 拖拽**更新 `dragOffset` notifier(PANEL-01),clamp 到 `MediaQuery` 窗口边界(承袭"不可拖出播放器窗口")。`custom_title_bar.dart` 拖的是 OS 窗口、PANEL-04 拖的是面板 — 语义不同,仅作**手势模式类比**,非直接复用。
- **D-10:** 键盘作用域与 ESC 优先级 — **面板自管 Focus subtree**(`FocusTraversalGroup`)。面板打开时 ESC/B 优先关面板且**不触发既有全屏切换**;面板关闭后 ESC 恢复既有全屏切换行为(modal overlay 优先消费 ESC 惯例,与 PANEL-06 自洽)。不与 `keyboard_handler.dart` 统一分发重叠,面板自带独立键盘作用域。

### Claude's Discretion

无 — 用户对全部 4 领域均作出明确选择,未出现 "you decide" 延迟。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 计划/需求
- `.planning/PROJECT.md` — v4.0 milestone 定义、Key Decisions(居中覆盖层 / Kodi+Steam 混合导航 / 框架优先 / Steam Input 自动映射)、Constraints(覆盖层模式 / 延迟应用)。
- `.planning/REQUIREMENTS.md` §v4.0 PANEL — PANEL-01..07 逐项需求(状态模型 / 控制器 / 毛玻璃壳 / 标题栏 / 遮罩 / 键盘关闭 / 尺寸)。
- `.planning/ROADMAP.md` §Phase 23 — Goal + 7 条 Success Criteria + Build Order Rationale(壳先于内容)。
- `CLAUDE.md` — Design System(Tokens.* / GlassContainer 毛玻璃模式)、Coding Conventions、Dart/Flutter Rules(strict 模式 / `!`/`late`/`as` 规避 / ValueNotifier)。

### 重写对象与类比代码(LIVE,须核对)
- `lib/ui/dialogs/settings_panel.dart` — **重写对象**(945 行,showDialog 路线)。就地拆分提取 State+Controller,本 phase 末删除(经 Strangler cutover,独立提交)。
- `lib/ui/playlist/playlist_panel.dart`(357 行) — **最强 overlay-shell 类比**:浮动毛玻璃窗 + 动画 + 拖拽,in-tree Stack 组合。挂载方式(D-05)的直接模板。
- `lib/ui/shared/glass_container.dart`(383 行) — PANEL-03 复用资产(BackdropFilter + bgGlass + borderHighlight,3 级 blur)。
- `lib/ui/window/custom_title_bar.dart` — 标题栏拖拽**手势模式类比**(拖 OS 窗口,非面板;D-09 非直接复用)。
- `lib/ui/shared/apple_curves.dart` — ⚠️ **未跟踪**,动画曲线来源(D-08)。**Phase 23 前置依赖**:须 commit + 核实曲线 API。
- `lib/ui/player/keyboard_handler.dart` — 既有 20+ 键 Focus handler,ESC→全屏现状。D-10 的交互对象(面板打开时 ESC 优先关面板,不冒泡至此)。
- `lib/features/player/services/playback_controller.dart` — `pause()` 编排器,D-03 暂停契约的调用入口。
- `lib/ui/player/player_screen.dart` — Stack 组合根,D-05 新覆盖层层的挂载点。

### codebase maps(v2.1 前快照,约定骨架可信,具体路径以 LIVE code 为准)
- `.planning/codebase/CONVENTIONS.md` — 命名 / 严格 lint / Tokens / glass-morphism / ValueNotifier 约定。
- `.planning/codebase/STRUCTURE.md` — `lib/ui/dialogs/settings/` 子目录已存在(7 tab + `_settings_nav_item.dart`)。
- `.planning/codebase/STACK.md` — `animations` 包(Material motion)已在栈;无新依赖。

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `glass_container.dart`(383 行) — PANEL-03 毛玻璃壳复用(3 级 blur + bgGlass + borderHighlight)。
- `playlist_panel.dart`(357 行) — overlay+动画+拖拽模式模板(D-05 挂载方式、D-07 动画节奏、D-09 拖拽手势)。
- `lib/ui/dialogs/settings/` 7 个 tab 文件 — tab 内容复用(已与 showDialog 解耦,D-06 壳取代触发器后直接挂入新壳)。

### Established Patterns
- ValueNotifier + ValueListenableBuilder(无新状态管理框架)— PANEL-01 恰好 3 notifier。
- Tokens.* + 毛玻璃(BackdropFilter + bgGlass + borderHighlight)— 全视觉值经 Tokens,无硬编码。
- in-tree Stack compositing(`PlayerScreen`)— D-05 新覆盖层作为 Stack 一层。
- 承袭 v3.0 ADAPT-03 阻塞约束:状态模型须**转发现有 notifier 实例,不可重新包装**(ValueListenableBuilder 监听器不脱钩)。

### Integration Points
- `PlayerScreen` Stack — 新覆盖层层(遮罩 + 面板)的挂载点。
- `PlayerServices` / `app.dart` 组合根 — `SettingsPanelController(playbackController)` 装配点(D-02)。
- `PlaybackController.pause()` — 打开时暂停入口(D-03,经编排器非直碰引擎)。
- 设置入口触发器(齿轮按钮 / 快捷键)— cutover 后指向新壳(D-06)。

</code_context>

<specifics>
## Specific Ideas

- "不可拖出播放器窗口"(PROJECT.md Constraint)— 拖拽 clamp 到 `MediaQuery` 窗口边界(D-09)。
- 用户历史反馈"按钮不要动画效果,保留 InkWell hover/press 反馈" — 适用于**按钮**,不否定面板开/关动画(PANEL-05 明确要求 AnimatedOpacity+AnimatedScale)。Phase 23 面板内按钮遵循此反馈。
- locale/theme 延迟应用到关闭后(用户历史反馈)— 具体延迟应用属 Phase 25 TABS-04,Phase 23 的 `_pending*` 留 widget 本地(D-04)。
- 面板打开时 ESC 不触发全屏切换(D-10)— modal overlay 优先消费 ESC,关闭后恢复。

</specifics>

<deferred>
## Deferred Ideas

无 — 讨论全程保持在 Phase 23 壳职责范围内。tab 内容框架、手柄导航、响应式缩放分别属 Phase 25/26/27,未在本次讨论引入新范围。

</deferred>

---

*Phase: 23-Overlay Shell & State Model*
*Context gathered: 2026-07-22*
</content>
