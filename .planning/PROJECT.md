# Settings Panel Redesign

## What This Is

重新设计 Simple Player Flutter 的设置面板系统，包括触发方式优化、组件体系精简、交互模式保持、主题样式与控制栏统一。目标是让设置面板在视觉和架构上与播放器整体风格一致，同时减少不必要的抽象层。

## Core Value

设置面板与控制栏视觉风格统一，组件层级精简，用户体验流畅。

## Requirements

### Validated

- ✓ 侧边栏导航 7-tab 结构 — existing
- ✓ 拖拽面板 + 自建遮罩 — existing
- ✓ OK/Cancel/Apply 延迟应用模式 — existing
- ✓ SettingsCard/ExpanderCard/ActionCard/SettingRow 组件体系 — existing
- ✓ 左键完整面板 + 右键快速菜单双入口 — existing

### Active

- [ ] 设置面板主题样式与控制栏统一（毛玻璃风格）
- [ ] 精简组件层级，减少不必要的抽象
- [ ] 双入口触发体验优化
- [ ] 保持延迟应用模式不变

### Out of Scope

- 设置搜索功能 — 长期功能，不在本次范围
- Golden tests — 后续补充
- 新增设置项 — 本次只重构现有功能

## Context

**现有架构:**
- SettingsPanel: 600×480 可拖拽对话框，7 个 tab（通用/均衡器/音频/视频/快捷键/关于/性能）
- 触发: app.dart 中 `_showSettingsPanel`（左键）+ `_showSettingsQuickMenu`（右键快速语言/主题切换）
- 组件: SettingsCard、SettingsExpanderCard、SettingsActionCard、SettingRow（lib/ui/shared/）
- 延迟应用: locale/theme 变更推迟到对话框关闭，避免 MaterialApp 重建丢失状态

**控制栏风格参考:**
- GlassContainer 毛玻璃效果（BackdropFilter + 3-tier blur）
- Tokens.* 设计令牌统一配色
- 圆角、半透明、高光边框

**上次重构:** 2026-05-21/22 完成侧边栏导航 + 卡片化改造

## Constraints

- **设计系统**: 所有视觉值必须使用 Tokens.* — 不硬编码颜色/间距
- **状态管理**: 保持 ValueNotifier + ValueListenableBuilder 模式
- **延迟应用**: locale/theme 变更必须延迟到对话框关闭
- **向后兼容**: 不改变外部调用接口（onSettings 回调签名）

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持双入口 | 左键完整面板 + 右键快速菜单满足不同场景 | — Pending |
| 精简组件层级 | 减少抽象层，降低维护成本 | — Pending |
| 毛玻璃风格统一 | 与控制栏视觉一致，提升整体感 | — Pending |
| 保持延迟应用 | MaterialApp 重建问题依然存在 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

---
*Last updated: 2026-07-08 after initialization*
