# Phase 3: Reset to Defaults - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 3-Reset to Defaults
**Areas discussed:** Tab 范围, 按钮位置, 确认样式, General 重置, 默认值来源, Shortcuts 重置, 按钮样式, EQ 重置, 重置反馈

---

## Tab 范围

| Option | Description | Selected |
|--------|-------------|----------|
| 跳过 About 和 Audio | 只在有持久化设置的 5 个 tab 加重置按钮（General/EQ/Video/Shortcuts/Performance） | ✓ |
| 只跳过 About | Audio 也加重置按钮（重置为无音轨选择状态），6 个 tab 有重置 | |
| 所有 7 个 tab 都加 | About 也加（重置按钮置灰或提示无设置可重置） | |

**User's choice:** 跳过 About 和 Audio
**Notes:** About 无设置项，Audio 是 per-file 音轨选择（不持久化）

---

## 按钮位置

| Option | Description | Selected |
|--------|-------------|----------|
| Tab 内容区右上角 | 每个 tab 的 GlassContainer 内部右上角，靠近设置项 | |
| Sidebar tab 名称旁 | 侧边栏每个 tab 名称右侧加小图标按钮 | |
| Tab 内容区底部 | 每个 tab 最底部，与 OK/Cancel/Apply 按钮行对齐 | ✓ |

**User's choice:** Tab 内容区底部，与 OK/Cancel/Apply 按钮行对齐，但在左边
**Notes:** 用户明确要求在左边，不是右边

---

## 确认样式

| Option | Description | Selected |
|--------|-------------|----------|
| AlertDialog + 毛玻璃 | 复用现有对话框风格，BackdropFilter 毛玻璃背景 | ✓ |
| 简单 Snackbar | 底部 Snackbar 提示，无需确认（直接重置） | |
| 自定义确认弹窗 | 新建 GlassContainer 风格的确认弹窗，列出将重置的设置项 | |

**User's choice:** AlertDialog + 毛玻璃
**Notes:** 复用现有对话框风格

---

## General 重置

| Option | Description | Selected |
|--------|-------------|----------|
| 延迟应用（推荐） | 重置后 locale/theme 变为默认值，但等对话框关闭时才生效，与现有行为一致 | ✓ |
| 立即应用 | 重置后立即切换语言和主题，可能触发 MaterialApp 重建 | |

**User's choice:** 延迟应用（推荐）
**Notes:** 与现有 OK/Cancel 行为一致，避免 MaterialApp 重建丢失对话框状态

---

## 默认值来源

| Option | Description | Selected |
|--------|-------------|----------|
| AppSettings 构造函数 + 服务默认值（推荐） | AppSettings 构造函数的默认值（volume=50, speed=1.0, brightness=0 等），locale='zh', themeIndex=0 | ✓ |
| 新建 defaults.dart 常量文件 | 新建一个 defaults.dart 常量文件，集中管理所有默认值 | |

**User's choice:** AppSettings 构造函数 + 服务默认值（推荐）
**Notes:** 不新建文件，复用现有构造函数默认值

---

## Shortcuts 重置

| Option | Description | Selected |
|--------|-------------|----------|
| 重置为应用默认快捷键（推荐） | 重置为 SettingsStore 中的默认快捷键映射（hardcoded defaults） | ✓ |
| 重置为系统默认快捷键 | 重置为系统级快捷键（如 Ctrl+O 打开文件） | |

**User's choice:** 重置为应用默认快捷键（推荐）
**Notes:** 应用默认快捷键，不是系统级

---

## 按钮样式

| Option | Description | Selected |
|--------|-------------|----------|
| TextButton 文字按钮（推荐） | 文字按钮 'Reset' 或 '恢复默认'，低调不抢焦点 | ✓ |
| OutlinedButton + Icon | 带图标的 outlined 按钮，更明显 | |
| IconButton 图标按钮 | 只有图标（refresh/reset icon），最小占用空间 | |

**User's choice:** TextButton 文字按钮（推荐）
**Notes:** 低调不抢焦点

---

## EQ 重置

| Option | Description | Selected |
|--------|-------------|----------|
| 重置为平坦（所有频段=0）（推荐） | 所有频段增益归零，恢复平坦均衡曲线 | ✓ |
| 重置为预设均衡器 | 重置为某个预设（如 'Default' 或 'Flat'） | |

**User's choice:** 重置为平坦（所有频段=0）（推荐）
**Notes:** 所有频段归零

---

## 重置反馈

| Option | Description | Selected |
|--------|-------------|----------|
| UI 立即刷新（推荐） | 设置项立即更新为默认值，用户能看到变化 | ✓ |
| UI 刷新 + 高亮动画 | 设置项更新 + 短暂高亮动画提示哪些值被重置了 | |

**User's choice:** UI 立即刷新（推荐）
**Notes:** 无需额外高亮动画

---

## Claude's Discretion

无 — 所有决策均用户明确选择

## Deferred Ideas

None — discussion stayed within phase scope
