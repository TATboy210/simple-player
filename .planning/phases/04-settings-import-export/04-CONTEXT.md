# Phase 4: 设置导入导出 - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

让用户可以将所有设置导出为 JSON 文件，也可以从 JSON 文件导入设置覆盖当前配置。包含格式校验和导入前确认提示。不涉及设置项的增删改，不涉及设置面板 UI 变更。

</domain>

<decisions>
## Implementation Decisions

### 按钮位置
- **D-01:** Import/Export 按钮放在设置面板底部工具栏，与 OK/Cancel/Apply 按钮同行右侧。所有 tab 共享可见，复用现有底部按钮栏布局。
- **D-02:** 不添加键盘快捷键。Import/Export 是低频操作，通过按钮操作即可。

### JSON 文件结构
- **D-03:** 导出的 JSON 包含完整元数据：settingsVersion（格式版本号）、exportedAt（ISO 8601 导出时间）、appVersion（应用版本）、platform（操作系统）、settingsCount（设置项数量统计）。
- **D-04:** 设置数据区域（"settings" key）包含 AppSettings 所有 22 个字段 + locale + themeIndex + shortcuts。全部设置，不排除任何字段。

### 文件操作
- **D-05:** 导出时默认文件名格式 `settings_YYYY-MM-DD.json`（含日期），使用 file_picker 让用户选择保存位置。复用现有 file_operations.dart 的文件选择模式。
- **D-06:** 导入时使用 file_picker 过滤 .json 文件，让用户选择要导入的文件。

### 验证策略
- **D-07:** 宽松+容错验证。忽略 JSON 中的未知字段（向前兼容），缺失字段用 AppSettings 默认值填充。只拒绝完全无法解析的文件（非 JSON、settings key 缺失）。
- **D-08:** 复用 SettingsValidator 已有的各字段校验规则（volume clamp、windowDimension sanitize、rotation 合法值等），导入的每个字段都经过校验。

### 导入确认对话框
- **D-09:** 确认对话框使用 AlertDialog + 毛玻璃风格（BackdropFilter），与 Phase 3 的重置确认对话框风格一致。
- **D-10:** 显示分类摘要：列出将被覆盖的设置类别（如：播放设置、字幕设置、视频效果、窗口设置、快捷键等），不列出每个字段的具体值。简洁明了。
- **D-11:** 确认按钮使用 Tokens.accent 颜色，取消按钮使用 TextButton 样式。

### 错误处理
- **D-12:** 导入失败时显示详细错误信息：JSON 解析错误显示具体原因，版本不兼容显示当前版本 vs 导入版本，字段校验失败显示哪些字段有问题。
- **D-13:** 导出失败时（如磁盘满、权限不足）显示通用错误提示 + debugPrint 详细日志。

### 导入后行为
- **D-14:** 导入成功后立即应用所有设置（不等 OK/Cancel），UI 刷新。与现有 OK/Cancel 延迟应用模式不同 — 导入是显式用户操作，立即生效。
- **D-15:** 导入后设置面板保持打开状态，不自动关闭。

### Claude's Discretion
无 — 所有决策均用户明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划
- `.planning/ROADMAP.md` — Phase 4 目标、成功标准、依赖关系
- `.planning/REQUIREMENTS.md` — IEX-01, IEX-02, IEX-03 需求定义
- `.planning/PROJECT.md` — 项目约束、技术环境

### 数据层
- `lib/kernel/models/app_settings.dart` — AppSettings 不可变容器，22 个字段 + 构造函数默认值 + copyWith
- `lib/kernel/persistence/settings_store.dart` — SharedPreferences 持久化，所有 save/load 方法，key 常量
- `lib/kernel/persistence/settings_validator.dart` — 输入校验规则（volume、windowDimension、rotation 等）

### 设置面板 UI
- `lib/ui/dialogs/settings_panel.dart` — 主面板，底部 OK/Cancel/Apply 按钮栏，_commitChanges() 逻辑
- `lib/ui/shared/settings_card.dart` — 设置卡片组件

### 服务层
- `lib/kernel/services/locale_service.dart` — Locale 持久化（独立于 AppSettings）
- `lib/kernel/services/theme_service.dart` — Theme 持久化（独立于 AppSettings）

### 文件操作
- `lib/features/player/services/file_operations.dart` — 文件选择器使用模式

### 设计系统
- `lib/ui/theme/tokens.dart` — Tokens.* 设计令牌
- `lib/ui/shared/glass_container.dart` — 毛玻璃容器组件

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SettingsStore.load()` — 读取所有设置为 AppSettings 对象，可直接序列化为 JSON
- `SettingsStore` 的所有 `save*()` 方法 — 导入后逐字段写入 SharedPreferences
- `SettingsValidator` — 已有所有字段的校验规则，导入时复用
- `AppSettings` 构造函数默认值 — 缺失字段的回退值
- `file_picker` 包 — 已在 pubspec.yaml 中，file_operations.dart 已有使用模式
- `AlertDialog` + `BackdropFilter` — 确认对话框可复用现有模式

### Established Patterns
- ValueNotifier + ValueListenableBuilder — 设置变更后 UI 自动刷新
- 不可变状态 + copyWith — AppSettings 已支持
- try-catch + debugPrint — 错误处理模式（永不崩溃）
- SharedPreferences key-value — 每个设置项独立 key

### Integration Points
- `SettingsPanel` 底部按钮栏 — Import/Export 按钮添加位置
- `SettingsPanel._commitChanges()` — 导入后触发设置应用
- `LocaleService` / `ThemeService` — locale/theme 独立于 AppSettings，需单独处理导入

</code_context>

<specifics>
## Specific Ideas

- 导出文件名 `settings_2026-07-13.json`，用户可修改
- JSON 结构示例：`{"settingsVersion": 1, "exportedAt": "2026-07-13T10:00:00Z", "appVersion": "1.0.0", "platform": "windows", "settingsCount": 25, "settings": {...}}`
- 确认对话框列出类别：播放设置、字幕设置、视频效果、窗口设置、快捷键等
- 导入成功后 OSD 提示 "设置已导入"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 4-设置导入导出*
*Context gathered: 2026-07-13*
