# Phase 6: Window Code Optimization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 6-Window Code Optimization
**Areas discussed:** 全屏按钮恢复, DragToResizeArea 配置, 标题栏布局层级, WindowService 传递方式

---

## 讨论区域选择

| Option | Description | Selected |
|--------|-------------|----------|
| DragToResizeArea 配置 | resizeEdgeSize=11px 判定区域、透明边框、全屏时禁用 | ✓ |
| 标题栏布局层级 | CustomTitleBar 在 Column 中占用空间，浮在视频上方 vs 不遮住视频 | ✓ |
| WindowService 传递方式 | 构造函数逐层传递 vs InheritedWidget/Provider | ✓ |
| 全屏按钮恢复 | 控制栏全屏按钮消失，需排查渲染逻辑 | ✓ |

**User's choice:** 全选 + 补充具体反馈
**Notes:** 用户明确要求"小改动"，并补充了以下具体问题：
- 全屏后无法点击按钮退出
- 全屏时标题栏仍然可见
- 16:9 视频应与窗口完美匹配

---

## 修复范围确认

| Option | Description | Selected |
|--------|-------------|----------|
| 按 4 点修复 | 全屏按钮+标题栏+DragToResizeArea+16:9匹配 | ✓ |
| 只修全屏问题 | 只修复全屏相关，不改其他 | |
| 全做 + 传递方式优化 | 额外优化 WindowService 传递方式 | |

**User's choice:** 按 4 点修复
**Notes:** 最小改动原则，不重构架构

---

## Claude's Discretion

- DragToResizeArea 具体数值 (建议 5-8px)
- 全屏退出交互方案
- VideoSurface 渲染逻辑优化

## Deferred Ideas

- WindowService 传递方式优化（InheritedWidget）— 用户未选择，保持构造函数传递
