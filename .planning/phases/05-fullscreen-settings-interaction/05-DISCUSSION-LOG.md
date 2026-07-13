# Phase 5: 全屏与设置面板交互规范化 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 5-全屏与设置面板交互规范化
**Areas discussed:** Fullscreen enter behavior, Panel position in fullscreen, Backdrop style in fullscreen, Exit fullscreen restore

---

## Fullscreen Enter Behavior

### Q1: 用户在设置面板打开时进入全屏，面板应该怎么处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 自动关闭面板 | 面板关闭，设置未保存的修改丢失。视频立即全屏无遮挡。实现最简单。 | |
| 保持打开 + 重定位 | 面板保持打开，自动重定位到屏幕中心。用户可继续调设置。需要监听 WindowService.mode 变化。 | ✓ |
| 保持打开 + 不动 | 面板保持打开，位置不变。最简单但面板可能超出屏幕边界。 | |

**User's choice:** 保持打开 + 重定位
**Notes:** 用户选择推荐选项

### Q2: 进入全屏时，面板中有未保存的修改（pending 状态），应该怎么处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 不触发保存，保持 pending | 进入全屏时面板保持原样，pending 状态不丢失。面板居中后用户继续编辑，关闭时按 OK/Cancel 决定。 | ✓ |
| 自动保存 pending 修改 | 进入全屏时自动应用当前修改（等同按了 OK）。用户不需要额外操作。 | |

**User's choice:** 不触发保存，保持 pending
**Notes:** 用户选择推荐选项

### Q3: 面板从当前位置重定位到屏幕中心，应该有动画吗？

| Option | Description | Selected |
|--------|-------------|----------|
| 平滑动画过渡 | 面板平滑滑动到新位置，视觉连续性好。用 AnimatedSlide 或类似。 | ✓ |
| 瞬间跳转 | 面板瞬间跳到新位置，无动画。实现最简单。 | |

**User's choice:** 平滑动画过渡
**Notes:** 用户选择推荐选项

### Q4: 全屏下设置面板打开时，按 ESC 键应该怎么处理？

| Option | Description | Selected |
|--------|-------------|----------|
| ESC 先关面板，再退全屏 | ESC 先关闭设置面板，再按 ESC 退出全屏。符合"最近打开的先关闭"原则。 | ✓ |
| ESC 直接退出全屏 + 关面板 | ESC 直接退出全屏，面板跟着关闭。一步到位但可能意外丢失设置。 | |
| ESC 只关面板 | ESC 只关闭面板，不退出全屏。需要单独按键退出全屏。 | |

**User's choice:** ESC 先关面板，再退全屏
**Notes:** 用户选择推荐选项

---

## Panel Position in Fullscreen

### Q1: 全屏下打开设置面板时，面板应该怎么定位？

| Option | Description | Selected |
|--------|-------------|----------|
| 屏幕居中 | 面板在屏幕正中，视觉平衡，不遮挡视频关键区域。全屏体验更沉浸。 | ✓ |
| 保持当前偏移 | 保持 topLeft + (80, 48) 偏移。一致性好但 4K 屏下面板偏左上。 | |
| 自适应 | 大屏居中，小屏偏移。灵活但实现复杂。 | |

**User's choice:** 屏幕居中
**Notes:** 用户选择推荐选项

---

## Backdrop Style in Fullscreen

### Q1: 全屏下面板的半透明背景是否需要调整？

| Option | Description | Selected |
|--------|-------------|----------|
| 加深到 black87 | 全屏下视频是唯一内容，加深背景让面板更突出，减少视频干扰。 | |
| 保持 black54 不变 | 一致性好，用户仍能看到视频。不增加复杂度。 | ✓ |

**User's choice:** 保持 black54 不变
**Notes:** 用户选择推荐选项

---

## Exit Fullscreen Restore

### Q1: 退出全屏时，如果设置面板是打开的，面板应该怎么处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 恢复到窗口模式位置 | 面板平滑滑动回窗口模式的默认位置 (topLeft + 80, 48)。视觉连续性好。 | ✓ |
| 保持当前位置 | 面板保持当前位置不动。最简单但可能在窗口模式下位置不合适。 | |
| 关闭再重新打开 | 关闭面板再重新打开。最简单但打断用户操作流。 | |

**User's choice:** 恢复到窗口模式位置
**Notes:** 用户选择推荐选项

---

## Claude's Discretion

无 — 所有决策均用户明确选择。

## Deferred Ideas

None — discussion stayed within phase scope
