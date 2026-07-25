# Simple Player — 设置面板横向重构 + 音频功能（v4.5）

## What This Is

Simple Player Flutter 桌面播放器（fvp / MDK-FFmpeg 引擎）的设置面板体验升级。在 v4.0 框架骨架基础上，把左侧栏布局重构成横向 tab 中部布局（16:9 / 占屏 50%），视觉与交互全程对齐控制栏毛玻璃语言，填充音频调节功能 + 控制栏音轨切换按钮，达到产品级优雅简洁。**v4.5 聚焦面板重构 + 音频功能填充，视频/字幕/播放偏好 tab 推迟到 v4.6+。**

## Core Value

设置面板的产品级体验 — 横向 tab 布局 + 控制栏级视觉/交互一致性 + 输入模式感知导航（键鼠/手柄自适应）、音频功能可用、延迟应用保护设置安全。

## Current Milestone: v4.5 设置面板横向重构 + 音频功能填充

**Goal:** 把设置面板从左侧栏布局重构成横向 tab 中部布局（16:9 / 占屏 50%），视觉与交互对齐控制栏毛玻璃语言，填充音频调节功能 + 控制栏音轨切换按钮，达到产品级优雅简洁。

**Target features:**

1. **Panel Layout Redesign** — 删 200px 左侧栏 → 横向 tab 栏置面板中部（保留上中下垂直结构）；16:9 比例 + 占屏约 50% 面积；通用 tab 排 tab 序列中间位置；上中下结构颜色统一为控制栏色
2. **Visual Design Alignment** — 毛玻璃+边缘光效+颜色对齐控制栏；选项默认无边框/无白光融合于面板，仅选中态高亮（控制栏按钮三态）；选项边界更紧凑；悬停高亮
3. **Navigation & Interaction Polish** — tab 两端竖向圆角左右箭头（持久可见+可点+键盘左右切 tab）；手柄 RB/LB 切 tab + 输入模式感知提示置换（手柄→RB/LB 渐入/方向键渐退；键盘→反向）；上下控制详情选项（仅使用时显提示，渐入渐出）；上下箭头薄毛玻璃盖在选项上下端（透看选项）；键盘上下时箭头发光反馈
4. **Auto-Pause (Always)** — 面板开启即暂停（总是，非 wasPlaying 条件），关闭恢复播放
5. **Audio Settings Tab** — 填充音频 tab 真实功能：EQ / 平衡 / 同步 / 音量标准化（对接 v3.0 TrackControl + VolumeControl）
6. **Control Bar Audio Track Switching** — 控制栏右下区（字幕左/打开文件右）新增音轨切换按钮，弹轨列表，对称字幕按钮

## Requirements

### Validated

- ✓ 播放核心功能（播放/暂停/seek/音量/播放模式）— 现有
- ✓ fvp (MDK/FFmpeg) 播放引擎集成 — 现有
- ✓ ValueNotifier + ValueListenableBuilder 状态管理 — 现有
- ✓ 键盘快捷键系统（20+ 快捷键）— 现有
- ✓ 毛玻璃设计语言（GlassContainer、Tokens.*）— 现有
- ✓ 沉浸式全屏功能 — v2.0
- ✓ 引擎接口分解（ISP：EngineStateView + PlaybackControl + 能力接口）— v2.1
- ✓ 状态机穷举（6 态正交 MediaState）— v2.1
- ✓ `MemoryMonitor` / `EngineMetrics` / `EngineEventLog` 初版 — v2.1
- ✓ 内核基线契约固化（Phase 15）— v3.0
- ✓ 兼容适配层骨架 + DiagnosticsBundle（Phase 16）— v3.0
- ✓ 零依赖 KernelLogger 门面（Phase 17）— v3.0
- ✓ Sealed 错误模型稳化（Phase 18）— v3.0
- ✓ MemoryMonitor 一等化（Phase 19）— v3.0
- ✓ 状态与生命周期重写（Phase 20）— v3.0
- ✓ 测试与迁移验证（Phase 21）— v3.0
- ✓ 双语 API 文档注释标准（Phase 22）— v3.0

### Active

<!-- v4.5 scope — 设置面板横向重构 + 音频功能填充。Building toward these. -->

- [ ] Panel Layout Redesign（横向 tab 中部布局 + 16:9/占屏 50% + 通用 tab 中间位 + 上中下色统一）
- [ ] Visual Design Alignment（毛玻璃+边缘光效对齐控制栏 + 选项三态 + 紧凑边界 + 悬停高亮）
- [ ] Navigation & Interaction Polish（竖向圆角左右箭头 + RB/LB+方向键提示置换 + 上下薄毛玻璃箭头 + 发光反馈）
- [ ] Auto-Pause Always（面板开启即暂停，关闭恢复——改 SettingsPanelController 策略）
- [ ] Audio Settings Tab（EQ/平衡/同步/音量标准化，对接 TrackControl+VolumeControl）
- [ ] Control Bar Audio Track Switching（控制栏右下区音轨切换按钮，弹轨列表，对称字幕按钮）

### Validated (continued)

- ✓ Overlay Shell & State Model（毛玻璃覆盖层 + SettingsPanelState + Controller + wasPlaying 暂停/恢复）— v4.0 (Phase 23)  *v4.5 改总是暂停策略*
- ✓ Sidebar Navigation（固定 200px 侧边栏 + 7 tab + FadeTransition + LB/RB）— v4.0 (Phase 24)  *v4.5 将重构为横向 tab 栏*
- ✓ Tab Content Framework（SettingRow 组件 + OK/Cancel/Apply 延迟应用模式）— v4.0 (Phase 25)
- ✓ Gamepad & Keyboard Navigation（FocusTraversalGroup + SpinControl + D-pad + A/B）— v4.0 (Phase 26)
- ✓ Responsive Scaling（连续面板尺寸 + 5:4 ratio + 800px 断点 + RepaintBoundary）— v4.0 (Phase 27)  *v4.5 将改为 16:9 / 占屏 50%*

### Out of Scope

- 视频调节 tab 功能 — 推迟到 v4.6+（v4.5 仅填充音频 tab，视频 tab 保持 SettingRow 占位）
- 字幕调节 tab 功能 — 推迟到 v4.6+（字幕 tab 保持占位）
- 播放偏好 tab 功能 — 推迟到 v4.6+（播放 tab 保持占位）
- 导入导出 — 非核心功能，推迟到 v4.2+
- 独立窗口模式 — 当前使用覆盖层架构
- 手柄输入适配层 — Steam Input API 自动映射，无需 Flutter 侧代码
- 内核改动 — v3.0 已完成，v4.5 仅对接现有内核接口

## Context

**技术环境：**

- Flutter 桌面播放器，Windows 为主平台
- fvp (MDK/FFmpeg) 作为播放引擎
- ValueNotifier + ValueListenableBuilder 状态管理
- 毛玻璃设计语言（GlassContainer + Tokens.*）

**v3.0 内核状态（已完成）：**

内核经过 Phase 15-22 完整重写：兼容适配层 → 零依赖 Logger → sealed 错误 → MemoryMonitor 一等化 → 状态机重写 → 测试验证 → 双语文档。内核稳定，可作为 v4.5 的基础。v4.5 音频 tab 直接对接 `TrackControl` / `VolumeControl` / `SubtitleConfig` 等一等化接口。

**v4.0 设置面板现状（v4.5 重构对象）：**

- `lib/ui/dialogs/settings_panel.dart` — v4.0 框架（覆盖层壳 + 左侧栏 + 7 tab + SettingRow + 延迟应用）
- `SettingsPanelState` (3 ValueNotifier) + `SettingsPanelController` (open/close/toggle + wasPlaying 暂停/恢复)
- v4.0 已交付 5 框架组件（Overlay Shell / Sidebar Navigation / Tab Content / Gamepad & Keyboard Nav / Responsive Scaling）

**v4.5 要解决的重构点：**

- 删除 200px 左侧栏 → 横向 tab 栏置面板中部（保留上中下垂直结构）
- 比例从 5:4 (clamp 400-600) 改为 16:9 / 占屏约 50% 面积
- 通用 tab 排 tab 序列中间位置
- 视觉/交互全程对齐控制栏（毛玻璃/边缘光效/按钮三态/紧凑边界）
- tab 两端竖向圆角左右箭头 + 输入模式感知提示置换（手柄 RB/LB vs 方向键）
- 上下箭头薄毛玻璃盖在选项上下端（透看选项）+ 键盘上下发光反馈
- 自动暂停从 wasPlaying 条件改为"总是暂停"
- 填充音频 tab 真实功能（EQ/平衡/同步/标准化）
- 控制栏右下区新增音轨切换按钮（对称字幕按钮）

## Constraints

- **设计北极星**: 设置面板视觉与交互全程对齐控制栏（毛玻璃 / 边缘光效 / 按钮三态 / 紧凑边界）
- **状态管理**: 继续使用 ValueNotifier + ValueListenableBuilder，不引入新状态管理框架
- **设计语言**: 所有视觉值通过 `Tokens.*`，毛玻璃 `BackdropFilter` + `bgGlass` + `borderHighlight`
- **平台**: 以 Windows 为主，macOS/Linux 次要
- **手柄兼容**: Steam Input API 自动映射手柄→键盘，无需 Flutter 侧适配层；输入模式检测驱动提示置换
- **覆盖层模式**: 使用居中覆盖层（非独立窗口），16:9 / 占屏约 50% 面积
- **延迟应用**: 音频 EQ 等更改必须延迟到 OK/Apply 时提交（沿用 v4.0 延迟应用框架）
- **范围边界**: v4.5 仅填充音频 tab，视频/字幕/播放 tab 保持 SettingRow 占位

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持 fvp 引擎 | MDK/FFmpeg 能力足够，更换成本高 | ✓ Good (v2.1 验证) |
| ValueNotifier 不变 | 项目已有成熟模式，引入新框架增加复杂度 | ✓ Good (v2.1 验证) |
| 内核与 UI 解耦重构 | 允许独立演进，降低回归风险 | ✓ Good (v2.1 验证) |
| 兼容式替换迁移（v3.0） | 保持 UI→Kernel 契约，适配器逐步替换内核 | ✓ Done (Phase 15-22) |
| `MemoryMonitor` 一等化（v3.0） | 可注入、可关闭、不干扰播放业务 | ✓ Done (Phase 19) |
| 零依赖 `KernelLogger`（v3.0） | `dart:developer` 为主 + 受控 `debugPrint` | ✓ Done (Phase 17) |
| 双语 API 注释（v3.0） | 中文意图 + 英文契约 | ✓ Done (Phase 22) |
| 居中覆盖层（v4.0） | 复用 overlay 架构，不创建独立窗口 | ✓ Good (v4.0 验证) |
| Kodi + Steam 混合导航（v4.0） | D-pad ↑↓ 选项, ←→ 调值, LB/RB 切 tab, A 确认, B 返回 | ✓ Good (v4.0 验证) — v4.5 重构为横向 tab |
| 框架优先（v4.0） | 先建骨架后填功能，SettingRow 占位渲染 | ✓ Good (v4.0 验证) |
| Steam Input API 自动映射（v4.0） | 手柄输入自动转键盘事件，无需 Flutter 适配层 | ✓ Good (v4.0 验证) |
| 横向 tab 中部布局（v4.5） | 删左侧栏，tab 横向排面板中部 + 两端竖向圆角箭头 | — Pending |
| 控制栏为设计北极星（v4.5） | 面板视觉/交互全程对齐控制栏毛玻璃语言 | — Pending |
| 音轨双入口分工（v4.5） | 控制栏按钮=快速切换弹轨；音频 tab=深度调节 EQ | — Pending |
| 总是暂停策略（v4.5） | 面板开启即暂停（非 wasPlaying 条件），关闭恢复 | — Pending |
| v4.5 仅音频 tab（v4.5） | 视频/字幕/播放 tab 占位推迟 v4.6+，范围可控 | — Pending |

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
*Last updated: 2026-07-25 — Milestone v4.5 started (设置面板横向重构 + 音频功能填充)*
