# Phase 23: Overlay Shell & State Model - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-22
**Phase:** 23-Overlay Shell & State Model
**Areas discussed:** 状态/控制器落点, 覆盖层挂载方式, 开/关动画实现, 拖拽与键盘关闭复用
**Mode:** default (interactive, resumed from checkpoint — area 1 captured in prior session)

---

## 状态/控制器落点

> 从中断检查点恢复(area 1 已在上一会话捕获,4 项决策直接承接,未重新讨论)。详见 CONTEXT.md D-01..D-04。

**承接决策:** 文件落点(就地拆 settings_panel.dart→settings/ 子目录)/ 依赖注入(构造注入 PlaybackController)/ 暂停契约(经编排器 pause + wasPlaying 快照)/ 范围边界(3 notifier,_pending* 留 Phase 25)。

---

## 覆盖层挂载方式

| Option | Description | Selected |
|--------|-------------|----------|
| Stack in-tree | 跟随 playlist_panel.dart(357行)既有模式:覆盖层作为 PlayerScreen Stack 的一层,由 isOpen notifier 控制可见/动画。复用既有 compositing,设计语言统一,遮罩点击关闭天然命中 | ✓ |
| 保留 showDialog | 沿用当前 settings_panel.dart(945行)的 showDialog,改动最小。但遮罩点击+拖拽需自己接管 ModalRoute,与 playlist_panel 模式分叉,两套 overlay 路径并存 | |
| OverlayEntry 手动 | 经 Overlay.of(context) 手动插入,生命周期自管。介于两者之间,但本面板属播放器内,收益不明显 | |

**User's choice:** Stack in-tree
**Notes:** 锁定后带出子决策 D-06(新旧过渡)。

### 子决策:新旧面板过渡关系

| Option | Description | Selected |
|--------|-------------|----------|
| 壳取代触发器 | 新壳骨架就位后接管设置入口触发器;tab 内容复用旧 settings/ 7 文件;老 settings_panel.dart 在新壳完整取代后独立提交删除。Strangler 渐进 | ✓ |
| 并存到 P25 | 新壳与老面板并存,入口仍指老面板;新壳仅空骨架预览;P25 tab 框架完整后一次性 cutover。过渡期两路径并存 | |
| 立即删除 | P23 直接删老 settings_panel.dart,新壳立即接管全部入口。风险高且越出壳职责边界 | |

**User's choice:** 壳取代触发器

---

## 开/关动画实现

| Option | Description | Selected |
|--------|-------------|----------|
| apple_curves.dart | 复用未跟踪的 apple_curves.dart。与其他动画一致;但文件未 commit 且内容未核实,Phase 23 须先确认状态(纳入 git + 读取 API)再采用 | ✓ |
| Material/标准曲线 | 用 Flutter 内置 Curves.easeInOutCubic(animations 包已入栈)。与控制栏/播放列表现有动画同源,零新增依赖,最低风险。时长 Tokens+200ms 与 P24 一致 | |
| 仅 Tokens+默认ease | 仅时长走 Tokens.*,曲线用 Curves.ease 默认。最简但质感一般,且与既有 overlay 曲线可能不一致 | |

**User's choice:** apple_curves.dart
**Notes:** 载体(AnimatedOpacity+AnimatedScale)与时长(200ms,对齐 P24 侧边栏 FadeTransition)由 PANEL-05/P24 推断,未单独提问。apple_curves.dart 未跟踪 → 标为 Phase 23 前置依赖(researcher/planner 须 commit + 核实曲线 API)。

---

## 拖拽与键盘关闭复用

| Option | Description | Selected |
|--------|-------------|----------|
| 面板优先 | 面板自管 Focus subtree(FocusTraversalGroup),打开时 ESC/B 优先关面板且不触发全屏切换;关闭后 ESC 恢复全屏切换。符合 modal overlay 优先消费 ESC 惯例,与 PANEL-06 自洽 | ✓ |
| 统一分发 | 复用 keyboard_handler.dart 统一分发,面板打开时在其内加 ESC/B 分支。集中但该 handler 已 20+ 键,且与面板自带 FocusTraversalGroup 职责重叠 | |
| 不阻止冒泡 | 面板用 CallbackShortcuts 监听 ESC/B 但不阻止冒泡。双重处理风险:ESC 同时关面板又切全屏,行为不可预测 | |

**User's choice:** 面板优先
**Notes:** 拖拽实现(D-09:in-canvas 拖拽更新 dragOffset notifier + MediaQuery clamp,custom_title_bar.dart 仅作手势类比非直接复用)由既有约束("不可拖出播放器窗口")+ PANEL-04 推断,未单独提问。

---

## Claude's Discretion

无 — 用户对全部 4 领域(含子决策)均作出明确选择,无 "you decide" 延迟。拖拽实现与动画载体/时长由既有需求(PANEL-04/PANEL-05/P24)+ 既有约束("不可拖出播放器窗口")推断,在 CONTEXT.md 中标注为推断决策。

## Deferred Ideas

无 — 讨论全程保持在 Phase 23 壳职责范围内。tab 内容框架(Phase 25)、手柄导航(Phase 26)、响应式缩放(Phase 27)均未引入。
