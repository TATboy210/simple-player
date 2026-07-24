# Phase 26: Gamepad & Keyboard Navigation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-24
**Phase:** 26-Gamepad & Keyboard Navigation
**Areas discussed:** SpinControl 视觉设计, 焦点高亮样式, A/B 键物理映射

---

## SpinControl 视觉设计

### Q1: SpinControl 的视觉形态？

| Option | Description | Selected |
|--------|-------------|----------|
| 内联箭头型 | ← [当前值] → 紧凑排列，箭头可点击/键盘触发。适合手柄 D-pad 操作，占用空间小。类似 Kodi 的 SpinControl。 | |
| 滑动动画型 | 当前值居中，左右箭头在两侧稍远位置，值变化时有滑动动画。更像 Steam 的设置项。 | ✓ |
| 迷你 Slider 型 | 类似 Slider 但有离散步长，值在轨道上跳跃。视觉上更直观但占用更多空间。 | |

**User's choice:** 滑动动画型
**Notes:** 值变化时有滑动动画，类似 Steam 设置风格。

### Q2: SpinControl 的箭头指示器何时显示？

| Option | Description | Selected |
|--------|-------------|----------|
| 始终显示箭头 | 箭头始终可见，当前值居中。简洁但可能不够直观。 | ✓ |
| 焦点时显示箭头 | 箭头在 hover/焦点时才出现，平时只显示值。更干净但手柄模式下需要焦点触发。 | |
| 交互时闪现箭头 | 箭头在值变化时短暂出现，然后淡出。动画感强但可能分散注意力。 | |

**User's choice:** 始终显示箭头
**Notes:** 用户一眼可知可操作方向。手柄模式下无需 hover 触发。

### Q3: SpinControl 到达边界值时的行为？

| Option | Description | Selected |
|--------|-------------|----------|
| 停止 + 灰色箭头 | 到达边界时停止，箭头变灰。简单明确，用户知道已到尽头。 | ✓ |
| 循环 wrap-around | 到达边界后循环到另一端。适合枚举选项（如语言列表），不适合数值范围。 | |
| 边界时隐藏箭头 | 到达边界时箭头消失，只剩当前值。最简但可能让用户困惑。 | |

**User's choice:** 停止 + 灰色箭头
**Notes:** 不循环 wrap-around。

### Q4: SpinControl 的适用范围？

| Option | Description | Selected |
|--------|-------------|----------|
| 枚举 + 小范围数值 | 用于枚举选项（如语言、主题、播放模式）和小范围数值（如音量 0-100）。Slider 用于连续范围。 | ✓ |
| 仅替换 Dropdown | 所有 Dropdown 都替换为 SpinControl，Slider 保持不变。统一交互但某些长列表可能不便。 | |
| 全面替代 | 所有设置项都用 SpinControl（包括连续值），Slider 仅保留给已有组件。最统一但交互效率低。 | |

**User's choice:** 枚举 + 小范围数值
**Notes:** Dropdown 保留给长列表（如字幕轨道选择）。

### Q5: SpinControl 在 SettingRow 中的布局位置？

| Option | Description | Selected |
|--------|-------------|----------|
| SettingRow 右侧内联 | 与 SettingRow 左对齐，右侧显示 SpinControl。保持行高一致，紧凑布局。 | ✓ |
| 独立行（标题在上） | SpinControl 独立一行，SettingRow 标题在上，控件在下。更宽敞但占用更多垂直空间。 | |
| 全宽 Slider 风格 | SpinControl 占满整行宽度，左右箭头在两端，值在中间。类似 Slider 的布局方式。 | |

**User's choice:** SettingRow 右侧内联

### Q6: SpinControl 值变化时的动画效果？

| Option | Description | Selected |
|--------|-------------|----------|
| 水平滑入滑出 | 值变化时新值从左/右滑入，旧值滑出。类似 iOS picker 的感觉，动画感强。 | ✓ |
| 淡入淡出 | 值变化时新值淡入，旧值淡出。简洁但不够有方向感。 | |
| 无动画直接切换 | 值直接切换，无动画。最简但缺少交互反馈。 | |

**User's choice:** 水平滑入滑出

### Q7: SpinControl 滑动动画的时长？

| Option | Description | Selected |
|--------|-------------|----------|
| 200ms | 值变化有 200ms 过渡动画，与面板开/关动画节奏一致。 | ✓ |
| 150ms | 150ms 更快，减少等待感但可能不够平滑。 | |
| 300ms | 300ms 更慢，动画更明显但可能感觉迟钝。 | |

**User's choice:** 200ms

### Q8: SpinControl 的数据模型？

| Option | Description | Selected |
|--------|-------------|----------|
| 选项列表 + index | SpinControl 接收 List<String> 选项列表 + 当前 index，内部管理循环逻辑。简单直接。 | ✓ |
| min/max/step 范围 | SpinControl 接收 min/max/step 数值范围，自动生成选项。适合数值型但枚举型需要额外处理。 | |
| Sealed class 双模式 | 统一使用 sealed class：SpinOptions.items(List<String>) 或 SpinOptions.range(min, max, step)。类型安全但更复杂。 | |

**User's choice:** 选项列表 + index

### Q9: SpinControl 是否需要自定义值格式化？

| Option | Description | Selected |
|--------|-------------|----------|
| 可选 formatValue 回调 | SpinControl 接收可选的 formatValue 回调，默认用 toString()。简单灵活。 | ✓ |
| 强制 formatValue | 强制要求 formatValue，确保每个 SpinControl 都有明确的显示格式。更严格但更繁琐。 | |
| 内置格式化器 | SpinControl 内置常见格式化（百分比、时间、枚举），无需外部回调。开箱即用但不够灵活。 | |

**User's choice:** 可选 formatValue 回调

### Q10: SpinControl 获得焦点后，← → 方向键的行为？

| Option | Description | Selected |
|--------|-------------|----------|
| 焦点时直接响应 ← → | ← → 方向键直接调整值，无需先聚焦。D-pad 操作最直接，符合 Kodi/Steam 范式。 | ✓ |
| 进入编辑模式后响应 | ← → 调整值，但需要先按 A/Enter 确认进入编辑模式，再用 ← → 调整，再按 A/Enter 确认。更安全但更繁琐。 | |
| 带撤销的直接响应 | ← → 调整值，同时显示一个确认提示，用户可按 B/ESC 取消。防止误操作但增加复杂度。 | |

**User's choice:** 焦点时直接响应 ← →

---

## 焦点高亮样式

### Q1: SettingRow 获得焦点时的高亮样式？

| Option | Description | Selected |
|--------|-------------|----------|
| 高亮色边框 2px | 使用 Tokens.borderHighlight 颜色，2px 边框，圆角与 SettingRow 一致。与现有 GlassContainer 边框风格统一。 | ✓ |
| 强调色边框 2px | 使用 Tokens.accent 颜色，2px 边框。更醒目但可能与选中态混淆。 | |
| 外发光 glow 效果 | 外发光效果（boxShadow），无实线边框。更柔和但可能不够明显。 | |

**User's choice:** 高亮色边框 2px

### Q2: SettingRow hover 态的样式？

| Option | Description | Selected |
|--------|-------------|----------|
| hover 态叠加 bgHover 背景 | 使用 Tokens.bgHover 背景色，与焦点态边框叠加。提供双重反馈：边框指示焦点，背景指示可交互。 | ✓ |
| 仅背景色变化 | hover 态只显示背景色变化，无边框。与焦点态区分明确。 | |
| 边框但颜色稍淡 | hover 态显示边框（与焦点态相同），但颜色稍淡。统一但可能混淆焦点和 hover。 | |

**User's choice:** hover 态叠加 bgHover 背景

### Q3: 焦点边框出现/消失时是否有动画过渡？

| Option | Description | Selected |
|--------|-------------|----------|
| 立即显示无动画 | 焦点边框立即出现，无过渡动画。最直接，手柄操作时无延迟。 | ✓ |
| 100ms 淡入淡出 | 焦点边框 100ms 淡入，失去焦点时 100ms 淡出。更平滑但可能感觉有延迟。 | |
| 200ms 淡入淡出 | 焦点边框 200ms 淡入，与面板动画节奏一致。更慢但更统一。 | |

**User's choice:** 立即显示无动画

### Q4: D-pad ↑↓ 在内容区 FocusTraversalGroup 内的行为？

| Option | Description | Selected |
|--------|-------------|----------|
| 组内顺序移动，边界停止 | D-pad ↑↓ 在当前 FocusTraversalGroup 内按顺序移动焦点，到达边界时停止。简单可预测。 | ✓ |
| 组内循环 | D-pad ↑↓ 在组内顺序移动，到达边界时循环到另一端。适合长列表。 | |
| 跨组跳转 | D-pad ↑↓ 在组内顺序移动，到达边界时跳转到下一个 FocusTraversalGroup（如从内容区跳到侧边栏）。 | |

**User's choice:** 组内顺序移动，边界停止

### Q5: 禁用（disabled）的 SettingRow 是否可聚焦？

| Option | Description | Selected |
|--------|-------------|----------|
| 跳过禁用控件 | 禁用控件不可聚焦，D-pad 跳过它们。最符合直觉，手柄操作时不会卡在禁用项上。 | ✓ |
| 可聚焦但无焦点边框 | 禁用控件可聚焦但不显示焦点边框，只是被跳过时有视觉反馈。 | |
| 可聚焦 + 灰色边框 | 禁用控件可聚焦，显示灰色焦点边框。用户可以看到禁用项但无法交互。 | |

**User's choice:** 跳过禁用控件

### Q6: 不同控件类型的焦点样式是否统一？

| Option | Description | Selected |
|--------|-------------|----------|
| 统一 2px 边框 | Switch、Slider、SpinControl、Button 都使用相同的焦点边框样式。统一但可能不够精确。 | ✓ |
| 控件特定焦点样式 | Switch 显示高亮背景，Slider 显示高亮轨道，SpinControl 显示高亮箭头。更精确但实现复杂。 | |
| 统一边框 + 内部高亮 | 所有控件使用相同的焦点边框，但 Slider 和 Switch 额外有内部高亮（如 Slider 轨道颜色变化）。 | |

**User's choice:** 统一 2px 边框

### Q7: 侧边栏 tab 获得焦点时的样式？

| Option | Description | Selected |
|--------|-------------|----------|
| 与 SettingRow 相同 | 侧边栏 tab 使用与 SettingRow 相同的焦点边框样式。统一但 tab 是导航元素，不是设置项。 | ✓ |
| 与选中态相同 | 侧边栏 tab 使用 accent 背景色 + 白色文字作为焦点态，与选中态相同。更醒目但可能混淆焦点和选中。 | |
| 底部指示条 | 侧边栏 tab 使用底部指示条（类似 Material TabBar）作为焦点态。独特但增加实现复杂度。 | |

**User's choice:** 与 SettingRow 相同

### Q8: 面板标题栏的关闭按钮是否可聚焦？

| Option | Description | Selected |
|--------|-------------|----------|
| 可聚焦 + 统一边框 | 关闭按钮可聚焦，使用与 SettingRow 相同的焦点边框。D-pad 可以导航到关闭按钮。 | ✓ |
| 可聚焦 + 圆形边框 | 关闭按钮可聚焦，使用圆形焦点边框（因为按钮是圆形的）。更精确但增加实现复杂度。 | |
| 不可聚焦 | 关闭按钮不可聚焦，只能用鼠标点击或 ESC/B 键关闭。简化焦点遍历。 | |

**User's choice:** 可聚焦 + 统一边框

---

## A/B 键物理映射

### Q1: 手柄 A/B 按钮如何映射到 Flutter KeyEvent？

| Option | Description | Selected |
|--------|-------------|----------|
| PhysicalKeyboardKey | 使用 PhysicalKeyboardKey（物理键码），不依赖键盘布局。手柄 A/B 通常映射到 Enter/Escape 物理键。最可靠。 | ✓ |
| LogicalKeyboardKey | 使用 LogicalKeyboardKey（逻辑键码），依赖键盘布局。更语义化但可能因布局不同而变化。 | |
| 双重监听 | 同时监听 PhysicalKeyboardKey 和 LogicalKeyboardKey，任一匹配即触发。最全面但可能有重复触发。 | |

**User's choice:** PhysicalKeyboardKey

### Q2: 手柄 A/B 按钮的具体物理键映射？

| Option | Description | Selected |
|--------|-------------|----------|
| A=Enter, B=Escape | A 键映射到 Enter（确认），B 键映射到 Escape（关闭/返回）。最符合 Kodi/Steam 范式。 | ✓ |
| A=Space, B=Escape | A 键映射到 Space（切换），B 键映射到 Escape。Space 更适合切换 Switch 状态。 | |
| 自定义映射 F13/F14 | 自定义映射，A/B 键映射到不常用的键（如 F13/F14），避免与其他快捷键冲突。 | |

**User's choice:** A=Enter, B=Escape

### Q3: A 键在不同控件上的确认行为是否统一？

| Option | Description | Selected |
|--------|-------------|----------|
| 统一确认行为 | A 键在所有控件上统一触发确认（Switch 切换、SpinControl 选择、Button 点击）。简单一致。 | ✓ |
| 控件特定行为 | A 键在 Switch 上切换，在 SpinControl 上无作用（已用 ← → 调整），在 Button 上点击。更精确但可能让用户困惑。 | |
| SpinControl 上 A=下一个 | A 键在 Switch 上切换，在 SpinControl 上循环到下一个值（与 → 相同），在 Button 上点击。 | |

**User's choice:** 统一确认行为

### Q4: B 键的行为？

| Option | Description | Selected |
|--------|-------------|----------|
| 直接关闭面板 | B 键在任何位置都关闭面板（与 ESC 等效）。简单直接，符合 Kodi/Steam 范式。 | |
| 先退回侧边栏再关闭 | B 键先退回侧边栏（如果焦点在内容区），再按 B 关闭面板。两步关闭，防止误操作。 | ✓ |
| NAV-06 严格实现 | B 键在内容区时退回侧边栏，在侧边栏时关闭面板。与 NAV-06 描述一致。 | |

**User's choice:** 先退回侧边栏再关闭
**Notes:** 两步关闭，防止误操作。

### Q5: 长按 A/B 键是否有特殊行为？

| Option | Description | Selected |
|--------|-------------|----------|
| 无长按行为 | 长按无特殊行为，每次按下只触发一次。简单明确。 | ✓ |
| 长按重复触发 | 长按 A 键重复触发确认（如快速切换 Switch），长按 B 键重复触发返回。 | |
| 长按 B 直接关闭 | 长按 A 键无特殊行为，长按 B 键直接关闭面板（跳过退回侧边栏步骤）。 | |

**User's choice:** 无长按行为

---

## Claude's Discretion

无 — 用户对全部 3 领域均作出明确选择，未出现 "you decide" 延迟。

## Deferred Ideas

None — discussion stayed within phase scope
