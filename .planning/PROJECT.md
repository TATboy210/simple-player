# Player Fullscreen — 核心能力升级

## What This Is

将 `simple_player_flutter` 的全屏功能从"窗口命令"升级为"播放器核心能力层"。当前全屏通过 `WindowService` 内部调用 `fullscreen_window` 插件实现，缺少独立状态模型、事件流、错误处理和命令串行化。本项目建立 `FullscreenAdapter` 抽象层，使全屏成为有状态、有事件、有错误模型的独立模块。

## Core Value

**全屏切换在任何场景下都稳定可靠** — 播放中/暂停中、最大化→全屏→退出、副屏拖拽后全屏、快速连按 F 10 次，状态始终正确。

## Requirements

### Validated

- ✓ WindowMode 枚举（windowed/maximized/minimized/fullscreen）— 已有
- ✓ window_manager 初始化、尺寸恢复、置顶、拖动 — 已有
- ✓ fullscreen_window.setFullScreen(true) 基础全屏 — 已有
- ✓ F / ESC 快捷键入口 — 已有
- ✓ Win32 FFI 重写解决 WS_THICKFRAME 7px 缝隙 — 已有 (2026-05-20)
- ✓ 5 个全屏 bug 已修复 — 已有 (2026-05-12)

### Active

- [ ] 独立 Fullscreen 状态模型（phase: stable/entering/leaving/forcedChange/error）
- [ ] 统一事件流（enterRequested/entered/leaveRequested/left/forcedChange/error）
- [ ] 显式错误模型（Unsupported/InvalidWindow/PermissionDenied/BusyTransition/PlatformFailure）
- [ ] 命令串行化（per-window 队列，快速切换不乱序）
- [ ] 恢复策略完善（windowed→fullscreen→windowed, maximized→fullscreen→maximized, 副屏→fullscreen→原屏）
- [ ] macOS 原生 fullscreen 生命周期适配
- [ ] Linux GTK/WM 差异兜底
- [ ] 多窗口/多显示器契约预留

### Out of Scope

- 独立 pub 包发布 — 先在项目内完成抽象层
- 复杂全屏动画统一 — 第一阶段不做
- 遥测平台接入 — 只保留事件与错误码接口
- Web/Mobile 深度适配 — 桌面优先，Web/Mobile 采用降级方案

## Context

- **当前全屏实现**: `WindowService.setMode()` 内部调用 `fullscreen_window.setFullScreen(true)`
- **Win32 FFI**: 已有 `win32_fullscreen.dart` 解决 WS_THICKFRAME 问题
- **关键反面教训**: `win32` 包导致全屏一帧卡顿，禁止使用
- **window_manager 风险**: pub 页面提示正迁移到统一原生核心方案，必须通过 adapter 隔离
- **桌面成熟项目参考**: mpv（状态正确性优先）、IINA（macOS 原生生命周期）、VLC（平台能力文档化）
- **记忆参考**: [[project_fullscreen_bugs]] [[project_fullscreen_win32_fix]] [[anti_pattern_fullscreen_ffi]] [[project_window_cross_platform]]

## Constraints

- **Tech Stack**: Flutter desktop (Windows/macOS/Linux), 依赖 window_manager + fullscreen_window + dart:ffi
- **禁止依赖**: `win32` 包（导致一帧卡顿）
- **平台优先级**: Windows > macOS > Linux > Web/Mobile
- **兼容性**: 不破坏现有 WindowBridge 接口，渐进式迁移
- **性能**: 全屏切换必须无感知延迟，快速连按不卡顿

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| FullscreenAdapter 独立于 WindowBridge | 全屏不是窗口命令子集，需独立状态/事件/错误模型 | — Pending |
| per-window 命令队列 | 解决快速连按竞态，保证幂等 | — Pending |
| 执行后回读真实状态 | 平台回调时机不一致，不能假设乐观更新正确 | — Pending |
| 禁止 win32 包 | 用户确认导致全屏一帧卡顿 | ✓ 已确认 |
| 桌面优先 | 当前主战场，Web/Mobile 降级处理 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-09 after initialization*
