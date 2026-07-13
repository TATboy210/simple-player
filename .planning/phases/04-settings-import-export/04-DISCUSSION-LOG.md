# Phase 4: 设置导入导出 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 4-设置导入导出
**Areas discussed:** 按钮位置, JSON结构, 验证策略, 确认对话框, 文件操作, 错误处理, 快捷键, 导出范围

---

## 按钮位置

| Option | Description | Selected |
|--------|-------------|----------|
| 底部工具栏（推荐） | 在 OK/Cancel/Apply 按钮行的右侧加 Import/Export 按钮，所有 tab 共享可见 | ✓ |
| General tab 内 | 放在 General tab 底部，与其他通用设置在一起 | |
| 侧边栏底部 | 在侧边栏导航列表下方加独立的 Import/Export 区域 | |

**User's choice:** 底部工具栏（推荐）
**Notes:** 复用现有底部按钮栏布局

---

## JSON 结构

| Option | Description | Selected |
|--------|-------------|----------|
| 版本+时间戳（推荐） | 包含 settingsVersion、exportedAt、appVersion | |
| 仅版本号 | 只包含 settingsVersion，最简结构 | |
| 完整元数据 | 版本+时间戳+设备信息+设置项数量统计 | ✓ |

**User's choice:** 完整元数据
**Notes:** 用户希望导入前能了解文件详情

---

## 验证策略

| Option | Description | Selected |
|--------|-------------|----------|
| 宽松+容错（推荐） | 未知字段忽略，缺失字段用默认值填充 | ✓ |
| 严格匹配 | JSON 结构必须完全匹配当前版本 | |
| 版本感知 | 根据 settingsVersion 选择不同的解析策略 | |

**User's choice:** 宽松+容错（推荐）
**Notes:** SettingsValidator 已有各字段校验规则，复用即可

---

## 确认对话框

| Option | Description | Selected |
|--------|-------------|----------|
| 分类摘要（推荐） | 显示将被覆盖的设置类别，不列出每个字段的具体值 | ✓ |
| 差异对比 | 显示当前设置 vs 导入设置的逐字段差异 | |
| 简单确认 | 只显示「将覆盖所有设置，是否继续？」 | |

**User's choice:** 分类摘要（推荐）
**Notes:** 简洁明了

---

## 文件操作

| Option | Description | Selected |
|--------|-------------|----------|
| 日期命名+file_picker（推荐） | 导出默认文件名含日期，导入用 file_picker 选择 | ✓ |
| 固定路径 | 导出到固定位置，无需文件选择器 | |
| 剪贴板 | 导出到剪贴板，最轻量 | |

**User's choice:** 日期命名+file_picker（推荐）
**Notes:** 复用现有 file_operations.dart 的文件选择模式

---

## 错误处理

| Option | Description | Selected |
|--------|-------------|----------|
| 详细错误信息（推荐） | 显示具体错误原因，帮助用户定位问题 | ✓ |
| 通用错误提示 | 只显示「文件格式无效」，不暴露技术细节 | |

**User's choice:** 详细错误信息（推荐）
**Notes:** JSON 解析错误显示具体原因，版本不兼容显示版本对比

---

## 快捷键

| Option | Description | Selected |
|--------|-------------|----------|
| 不加快捷键（推荐） | Import/Export 是低频操作，通过按钮操作即可 | ✓ |
| 添加快捷键 | Ctrl+E 导出，Ctrl+I 导入 | |

**User's choice:** 不加快捷键（推荐）
**Notes:** 低频操作不需要快捷键

---

## 导出范围

| Option | Description | Selected |
|--------|-------------|----------|
| 全部设置（推荐） | 导出 AppSettings 所有字段 + locale + themeIndex + shortcuts | ✓ |
| 排除设备相关设置 | 排除 lastFile 和窗口位置/大小 | |
| 用户选择 | 让用户选择要导出哪些设置类别 | |

**User's choice:** 全部设置（推荐）
**Notes:** 导入时全部覆盖

---

## Claude's Discretion

无 — 所有决策均用户明确选择。

## Deferred Ideas

None — discussion stayed within phase scope
