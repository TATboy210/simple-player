# Simple Player — 设置面板 & 全屏重构

## What This Is

对 Simple Player Flutter 桌面播放器的设置功能和全屏功能进行全面重构。包括设置面板 UI/UX 升级、数据层重构、全屏代码简化与解耦，以及开发工作流增强（Flutter SDK 文档/源码集成、质量管线探索）。

## Core Value

设置面板和全屏功能的代码质量与用户体验同步提升 — 重构后代码更简洁可维护，UI 更现代化，两个功能模块彻底解耦。

## Requirements

### Validated

- ✓ 播放器核心功能（播放/暂停/seek/音量/播放模式）— 现有
- ✓ 7-tab 设置面板（General/EQ/Audio/Video/Shortcuts/About/Performance）— 现有
- ✓ 全屏功能（Win32 FFI、快捷键、状态管理）— 现有
- ✓ 毛玻璃设计语言（GlassContainer、Tokens.*）— 现有
- ✓ 键盘快捷键系统（20+ 快捷键）— 现有

### Active

- [ ] 设置面板视觉升级 — 保持毛玻璃风格但更新细节（圆角、间距、动画、交互反馈）
- [ ] 7 个 tab 内部重做 — 每个 tab 的布局、交互、样式全面升级
- [ ] settings_store 数据层重构 — 存储、持久化、验证逻辑清理
- [ ] 全屏代码简化 — 减少层数、合并分散逻辑、降低复杂度
- [ ] 全屏与设置面板解耦 — 代码层面、状态层面、展示层面全部解耦
- [ ] 全屏状态转换处理 — 进入/退出全屏时设置面板行为规范化
- [ ] Flutter SDK 文档查询集成 — Context7 接入，开发时快速查 API
- [ ] Flutter SDK 源码参考能力 — 需要时能分析 SDK 源码解决问题
- [ ] Flutter Quality Pipeline 理解与评估 — 理解设计，决定集成方式

### Out of Scope

- 新增设置项 — 现有设置项够用，只改 UI 和代码结构
- 播放器核心功能改动 — 播放引擎、播放列表等不动
- 跨平台全屏统一 — 本次只简化代码，不做平台行为统一
- 移动端适配 — 桌面端专属

## Context

**技术环境：**
- Flutter 桌面播放器，Windows 为主平台
- fvp (MDK/FFmpeg) 作为播放引擎
- Win32 FFI 用于窗口控制和全屏
- ValueNotifier + ValueListenableBuilder 状态管理
- 毛玻璃设计语言（GlassContainer + Tokens.*）

**当前设置面板结构：**
- `lib/ui/dialogs/settings_panel.dart` (403行) — 主面板，侧边栏导航
- `lib/kernel/persistence/settings_store.dart` (450行) — 设置存储
- `lib/kernel/persistence/settings_validator.dart` (105行) — 设置验证
- `lib/ui/dialogs/settings/` — 7 个 tab 文件
- `lib/ui/shared/settings_card.dart` (154行) — 设置卡片组件

**当前全屏实现：**
- `lib/kernel/bridge/fullscreen_driver.dart` — 全屏驱动抽象
- `lib/kernel/bridge/desktop_fullscreen_driver.dart` — 桌面全屏实现
- `lib/kernel/bridge/platform/` — 平台特定全屏实现
- `lib/kernel/bridge/window_service.dart` — 窗口服务

**已知问题：**
- 全屏代码层数多、逻辑分散
- 全屏与设置面板在代码/状态/展示三个层面耦合
- 设置面板视觉风格需要现代化
- settings_store 450 行需要重构

## Constraints

- **设计语言**: 保持毛玻璃风格，不换设计系统
- **Tab 结构**: 保持 7 个 tab 划分，只重做内部
- **设置项**: 不增不减，只改 UI 和代码结构
- **平台**: 以 Windows 为主，macOS/Linux 次要

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持毛玻璃但升级 | 延续品牌一致性，现代化细节 | — Pending |
| 7 tab 保持不变 | 划分合理，问题在内部实现 | — Pending |
| 全屏与设置彻底解耦 | 降低复杂度，独立演进 | — Pending |
| Quality Pipeline 先理解再集成 | 避免盲目引入复杂度 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-12 after initialization*
