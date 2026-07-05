# Phase 23: UI Layer Documentation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-05
**Phase:** 23-UI Layer Documentation
**Areas discussed:** FFmpeg 滤镜注释深度, Settings Dialog 参数文档, Player 交互逻辑文档, Shared 组件模式文档, 审计策略, settings_panel 主入口, ValueListenableBuilder2, Phase 20 精简后注释

---

## FFmpeg 滤镜注释深度

| Option | Description | Selected |
|--------|-------------|----------|
| 详细模式（与 Phase 21 一致） | 解释 FFmpeg 滤镜链结构 + 每个参数的音频含义 | ✓ |
| 简单模式（参数含义 only） | 只标注 bass=g=10 意思是 'bass boost 10dB' | |
| You decide | Claude 自行判断 | |

**User's choice:** 详细模式（与 Phase 21 一致）
**Notes:** Phase 21 Engine 层选择了详细模式，Dialog 层保持一致

| Option | Description | Selected |
|--------|-------------|----------|
| 每个预设加效果说明 | 解释每个预设的音频效果目标 | ✓ |
| 只解释语法，不解释听感 | 只解释语法格式 | |

**User's choice:** 每个预设加效果说明

| Option | Description | Selected |
|--------|-------------|----------|
| 内联解释（与 Phase 21 一致） | 不引用外部文档，直接在注释中解释 | ✓ |
| 添加外部文档引用 | 添加 @see FFmpeg documentation | |

**User's choice:** 内联解释（与 Phase 21 一致）

| Option | Description | Selected |
|--------|-------------|----------|
| 只注释现有代码 | 只对已有的 5 个滤镜做注释 | ✓ |
| 补充可用参数提示 | 还添加注释说明其他可用参数 | |

**User's choice:** 只注释现有代码

| Option | Description | Selected |
|--------|-------------|----------|
| 解释滤镜链格式 | 解释通用格式：filter_name=param1=value1 | ✓ |
| 只解释具体参数 | 只解释每个具体的滤镜参数 | |

**User's choice:** 解释滤镜链格式

| Option | Description | Selected |
|--------|-------------|----------|
| 解释设置流程 | 解释如何通过 EngineState.setProperty('af', ...) 设置 | ✓ |
| 只注释数据，不注释方法 | 只在 _presetValues 上加注释 | |

**User's choice:** 解释设置流程

| Option | Description | Selected |
|--------|-------------|----------|
| 解释 dB 单位和增益方向 | 解释 g=10 中的 g 是 gain，单位 dB，正数增强、负数衰减 | ✓ |
| 简单标注 | 只说 g=10 是增益 10 | |

**User's choice:** 解释 dB 单位和增益方向

| Option | Description | Selected |
|--------|-------------|----------|
| 混合语言（与 Phase 21 一致） | 技术注释用英文，听感效果描述用中文 | ✓ |
| 全英文 | 所有注释都用英文 | |
| 全中文 | 所有注释都用中文 | |

**User's choice:** 混合语言（与 Phase 21 一致）

| Option | Description | Selected |
|--------|-------------|----------|
| 解释多滤镜组合语法 | 解释逗号分隔的多滤镜组合 | ✓ |
| 不解释组合语法 | 只解释单个滤镜参数 | |

**User's choice:** 解释多滤镜组合语法

| Option | Description | Selected |
|--------|-------------|----------|
| 解释空字符串含义 | 解释 '' 表示禁用均衡器，原始音频直通 | ✓ |
| 不解释 | 空字符串含义显而易见 | |

**User's choice:** 解释空字符串含义

| Option | Description | Selected |
|--------|-------------|----------|
| 添加模块级概述 | 在文件顶部添加模块级注释 | ✓ |
| 只保留类级注释 | 只保留现有的类级 doc comment | |

**User's choice:** 添加模块级概述

| Option | Description | Selected |
|--------|-------------|----------|
| 添加修改指南 | 说明修改预设值时需要遵循的格式 | ✓ |
| 不添加 | 不添加修改指南 | |

**User's choice:** 添加修改指南

| Option | Description | Selected |
|--------|-------------|----------|
| 解释实时切换机制 | 解释 FFmpeg 滤镜链会实时重新配置 | ✓ |
| 不解释 | 不解释性能相关细节 | |

**User's choice:** 解释实时切换机制

| Option | Description | Selected |
|--------|-------------|----------|
| 添加增益范围警告 | 解释增益范围 -20dB ~ +20dB，过高可能导致削波失真 | ✓ |
| 不添加 | 不添加限制说明 | |

**User's choice:** 添加增益范围警告

---

## Settings Dialog 参数文档

| Option | Description | Selected |
|--------|-------------|----------|
| 完整解释（与 Engine 层一致） | Dialog 层也完整解释每个参数的技术细节 | ✓ |
| 简要 + 引用 Engine 层 | Dialog 层只标注参数名称和简要含义 | |

**User's choice:** 完整解释（与 Engine 层一致）

| Option | Description | Selected |
|--------|-------------|----------|
| 每个参数都解释 | 每个色彩校正参数都添加 doc comment | ✓ |
| 只解释非常见参数 | 只解释非显而易见的参数 | |

**User's choice:** 每个参数都解释

| Option | Description | Selected |
|--------|-------------|----------|
| 解释 sync.cpu 含义 | 解释强制 CPU 同步，避免撕裂 | ✓ |
| 只标注名称 | 只标注 'D3D11 同步模式' | |

**User's choice:** 解释 sync.cpu 含义

| Option | Description | Selected |
|--------|-------------|----------|
| 解释优缺点和开关原因 | 解释硬件解码的优势和潜在问题 | ✓ |
| 只标注名称 | 只标注 '硬件解码开关' | |

**User's choice:** 解释优缺点和开关原因

| Option | Description | Selected |
|--------|-------------|----------|
| 解释音轨选择逻辑 | 解释如何列出可用音轨、切换音轨的 API 调用 | ✓ |
| 只保留现有注释 | AudioTab 已有类级 doc comment | |

**User's choice:** 解释音轨选择逻辑

| Option | Description | Selected |
|--------|-------------|----------|
| 解释每个字段含义 | 解释每个媒体信息字段的含义 | ✓ |
| 只解释非常见字段 | 只解释非显而易见的字段 | |

**User's choice:** 解释每个字段含义

| Option | Description | Selected |
|--------|-------------|----------|
| 每个 tab 都添加模块概述 | 在每个 settings tab 文件顶部添加模块级概述 | ✓ |
| 只在主入口添加概述 | 只在 settings_panel.dart 添加概述 | |

**User's choice:** 每个 tab 都添加模块概述

---

## Player 交互逻辑文档

| Option | Description | Selected |
|--------|-------------|----------|
| 详细解释拖放机制 | 详细解释 desktop_drop 的工作原理 | ✓ |
| 只解释回调用途 | 只解释 onFilesDropped 回调的用途 | |

**User's choice:** 详细解释拖放机制

| Option | Description | Selected |
|--------|-------------|----------|
| 解释设计意图 | 解释为什么将回调集合为一个对象 | ✓ |
| 只解释回调用途 | 只解释每个回调的用途 | |

**User's choice:** 解释设计意图

| Option | Description | Selected |
|--------|-------------|----------|
| 解释显示条件和交互 | 解释错误横幅的显示条件、可操作按钮 | ✓ |
| 只解释用途 | 只解释 ErrorBanner 的用途 | |

**User's choice:** 解释显示条件和交互

| Option | Description | Selected |
|--------|-------------|----------|
| 解释 MergedListenable 使用原因 | 解释为什么使用 MergedListenable | ✓ |
| 只解释显示功能 | 只解释 TimeRangeDisplay 显示功能 | |

**User's choice:** 解释 MergedListenable 使用原因

| Option | Description | Selected |
|--------|-------------|----------|
| 解释 PathValidator 过滤逻辑 | 解释如何过滤文件（路径长度、空字节等） | ✓ |
| 只说明有验证 | 只说明 '文件会经过验证' | |

**User's choice:** 解释 PathValidator 过滤逻辑

| Option | Description | Selected |
|--------|-------------|----------|
| 解释技术选型原因 | 解释为什么使用 desktop_drop 而不是 Flutter 原生 DragTarget | ✓ |
| 不解释选型 | 不解释技术选型 | |

**User's choice:** 解释技术选型原因

| Option | Description | Selected |
|--------|-------------|----------|
| 每个文件都添加模块概述 | 在每个 Player 文件顶部添加模块级概述 | ✓ |
| 只在主入口添加概述 | 只在 player_screen.dart 添加概述 | |

**User's choice:** 每个文件都添加模块概述

---

## Shared 组件模式文档

| Option | Description | Selected |
|--------|-------------|----------|
| 详细解释合并原理和使用场景 | 详细解释 MergedListenable 的工作原理 | ✓ |
| 只解释用途 | 只解释 MergedListenable 的用途 | |

**User's choice:** 详细解释合并原理和使用场景

| Option | Description | Selected |
|--------|-------------|----------|
| 解释响应式设计和视觉规范 | 解释 AppDialog 的响应式设计 | ✓ |
| 只解释用途 | 只解释 AppDialog 的用途 | |

**User's choice:** 解释响应式设计和视觉规范

| Option | Description | Selected |
|--------|-------------|----------|
| 解释提取来源和使用场景 | 解释 ContextMenuRow 的设计来源 | ✓ |
| 只解释用途 | 只解释 ContextMenuRow 的用途 | |

**User's choice:** 解释提取来源和使用场景

| Option | Description | Selected |
|--------|-------------|----------|
| 解释无 l10n 原因 | 解释为什么使用 const 品牌名 | |
| 只解释用途 | 只解释 SplashScreen 的用途 | ✓ |

**User's choice:** 只解释用途

| Option | Description | Selected |
|--------|-------------|----------|
| 每个文件都添加模块概述 | 在每个 Shared 文件顶部添加模块级概述 | ✓ |
| 只在核心组件添加概述 | 只在 glass_container.dart 添加概述 | |

**User's choice:** 每个文件都添加模块概述

| Option | Description | Selected |
|--------|-------------|----------|
| 解释通用设计意图 | 解释 MergedListenable 可复用于任何两个 ValueNotifier<int> | ✓ |
| 只解释当前场景 | 只解释当前使用场景 | |

**User's choice:** 解释通用设计意图

| Option | Description | Selected |
|--------|-------------|----------|
| 解释 LayoutBuilder 逻辑 | 解释 LayoutBuilder 如何调整对话框尺寸 | ✓ |
| 只解释用途 | 只解释 AppDialog 的用途 | |

**User's choice:** 解释 LayoutBuilder 逻辑

---

## 审计策略

| Option | Description | Selected |
|--------|-------------|----------|
| 先审计再动手（与 Phase 21/22 一致） | 先扫描 13 个文件的现有注释质量，标记 A/B/C 类 | ✓ |
| 不审计，直接处理 | 直接对所有 13 个文件添加注释 | |

**User's choice:** 先审计再动手（与 Phase 21/22 一致）

---

## settings_panel 主入口

| Option | Description | Selected |
|--------|-------------|----------|
| 解释导航模式和 tab 概述 | 解释侧边栏导航模式、tab 切换逻辑 | ✓ |
| 只解释用途 | 只解释 settings_panel 的用途 | |
| 跳过（不在范围内） | 不在 DOC-33~DOC-45 范围内 | |

**User's choice:** 解释导航模式和 tab 概述

---

## ValueListenableBuilder2

| Option | Description | Selected |
|--------|-------------|----------|
| 解释 VLB2 的作用 | 解释 ValueListenableBuilder2 的作用 | ✓ |
| 不解释 VLB2 | 只解释 ErrorBanner 的错误显示逻辑 | |

**User's choice:** 解释 VLB2 的作用

---

## Phase 20 精简后注释

| Option | Description | Selected |
|--------|-------------|----------|
| 添加精简后设计意图注释 | 说明 Phase 20 精简后的设计意图 | ✓ |
| 只注释当前行为 | 只注释当前代码的行为 | |

**User's choice:** 添加精简后设计意图注释

---

## Claude's Discretion

无 — 所有决策均由用户明确选择

## Deferred Ideas

None — discussion stayed within phase scope
