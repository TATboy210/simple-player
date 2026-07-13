# Phase 3: Reset to Defaults - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

为设置面板的 5 个 tab（General/EQ/Video/Shortcuts/Performance）添加独立重置按钮。用户点击后确认，确认后仅重置该 tab 的设置项为默认值，UI 立即刷新。不涉及 About 和 Audio tab（无持久化设置）。

</domain>

<decisions>
## Implementation Decisions

### Tab 范围
- **D-01:** 跳过 About 和 Audio tab。About 无设置项，Audio 是 per-file 音轨选择（不持久化）。只在 5 个 tab 加重置按钮：General、Equalizer、Video、Shortcuts、Performance。

### 按钮位置与样式
- **D-02:** 重置按钮放在每个 tab 内容区底部，与 OK/Cancel/Apply 按钮行对齐，但在左边。使用 TextButton 文字按钮样式（如 "恢复默认"），低调不抢焦点。
- **D-03:** 按钮样式为 TextButton，文字为 "恢复默认" 或类似，使用 Tokens.textSecondary 颜色。

### 确认对话框
- **D-04:** 使用 AlertDialog + 毛玻璃风格（BackdropFilter）。确认后仅重置当前 tab 的设置项。
- **D-05:** 对话框标题提示将重置哪些设置项，确认按钮使用警告色（如 Tokens.error 或 Tokens.warning）。

### 默认值来源
- **D-06:** 默认值来自 AppSettings 构造函数的默认参数（volume=50, speed=1.0, brightness=0 等）+ LocaleService/ThemeService 的默认值（locale='zh', themeIndex=0）。
- **D-07:** 不新建 defaults.dart 常量文件，直接复用现有构造函数默认值。

### General tab 重置
- **D-08:** General tab 的 locale/theme 重置采用延迟应用模式 — 重置后 locale/theme 变为默认值（'zh'/0），但等对话框关闭时才生效，与现有 OK/Cancel 行为一致。

### Equalizer tab 重置
- **D-09:** EQ 重置为平坦曲线 — 所有频段增益归零。

### Shortcuts tab 重置
- **D-10:** Shortcuts 重置为应用默认快捷键映射（SettingsStore 中的 hardcoded defaults），不是系统级快捷键。

### 重置反馈
- **D-11:** 确认重置后 UI 立即刷新为默认值，无需额外高亮动画。

### Claude's Discretion
无 — 所有决策均用户明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/ROADMAP.md` — Phase 3 目标、成功标准、依赖关系
- `.planning/REQUIREMENTS.md` — SUI-02 需求定义（每个 tab 独立重置按钮）
- `.planning/PROJECT.md` — 项目约束、技术环境

### 设置面板结构
- `lib/ui/dialogs/settings_panel.dart` — 主面板，侧边栏导航，OK/Cancel/Apply 逻辑
- `lib/ui/dialogs/settings/general_tab.dart` — General tab（语言/主题）
- `lib/ui/dialogs/settings/equalizer_tab.dart` — EQ tab
- `lib/ui/dialogs/settings/video_tab.dart` — Video tab（色彩校正/旋转/宽高比）
- `lib/ui/dialogs/settings/shortcuts_tab.dart` — Shortcuts tab
- `lib/ui/dialogs/settings/settings_tab_performance.dart` — Performance tab

### 数据层
- `lib/kernel/models/app_settings.dart` — AppSettings 不可变容器，构造函数含默认值
- `lib/kernel/persistence/settings_store.dart` — SharedPreferences 持久化
- `lib/kernel/persistence/settings_validator.dart` — 输入校验规则
- `lib/kernel/services/locale_service.dart` — Locale 持久化 + ValueNotifier
- `lib/kernel/services/theme_service.dart` — Theme 持久化 + accent switching

### 设计系统
- `lib/ui/theme/tokens.dart` — Tokens.* 设计令牌（颜色、间距、圆角）
- `lib/ui/shared/glass_container.dart` — 毛玻璃容器组件

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppSettings` 构造函数 — 已有所有默认值参数，可直接用于重置
- `SettingsStore` — 已有 load/save 方法，重置后需调用 save 持久化
- `AlertDialog` + `BackdropFilter` — 可复用现有对话框模式
- `GlassContainer` — 毛玻璃背景可复用于确认对话框

### Established Patterns
- ValueNotifier + ValueListenableBuilder — 设置变更后 UI 自动刷新
- 延迟应用模式 — General tab 的 locale/theme 已有 pending 值机制
- 不可变状态 + copyWith — AppSettings 已支持

### Integration Points
- `SettingsPanel._commitChanges()` — 对话框关闭时应用 pending 值
- `SettingsPanel._cancel()` — 取消时恢复原始值
- 各 tab 的 `onChanged` 回调 — 设置变更通知

</code_context>

<specifics>
## Specific Ideas

- 重置按钮放在 tab 底部左边，与 OK/Cancel/Apply 行对齐
- 确认对话框列出将重置的设置项类别
- TextButton 样式，文字 "恢复默认"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 3-Reset to Defaults*
*Context gathered: 2026-07-13*
