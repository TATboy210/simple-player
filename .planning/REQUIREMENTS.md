# Requirements: Simple Player — 设置面板 & 全屏重构

**Defined:** 2026-07-12
**Core Value:** 设置面板和全屏功能的代码质量与用户体验同步提升 — 重构后代码更简洁可维护，UI 更现代化，两个功能模块彻底解耦。

## v1 Requirements

### Settings UI — 设置面板视觉与交互升级

- [x] **SUI-01**: 设置面板整体视觉现代化 — 圆角、间距、动画、交互反馈保持毛玻璃风格但更新细节
- [x] **SUI-02**: 每个 tab 有独立的 Reset to defaults 按钮 — 用户可单独重置某个 tab 的所有设置项为默认值
- [ ] **SUI-03**: 设置面板在全屏进入/退出时行为规范化 — 不遮挡、不错位、状态同步

### Fullscreen — 全屏代码简化

- [x] **FULL-01**: 全屏代码层数减少 — 合并分散逻辑，降低 FullscreenDriver/WindowService/SettingsStore 之间的间接层
- [x] **FULL-02**: 评估 flutter_fullscreen 包适用性 — 对比现有 Win32 FFI 实现，决定是否引入或保持自研
- [x] **FULL-03**: 全屏状态单一数据源 — WindowService 作为唯一 owner，移除 SettingsStore 中的全屏相关状态

### Import/Export — 设置导入导出

- [ ] **IEX-01**: 用户可以将所有设置导出为 JSON 文件 — 包含全部 SettingsStore 数据
- [ ] **IEX-02**: 用户可以从 JSON 文件导入设置 — 覆盖当前配置，导入前需校验格式
- [ ] **IEX-03**: 导入前显示确认提示 — 告知用户将覆盖哪些设置

### Dev Workflow — 开发工作流增强

- [ ] **DEV-01**: Flutter SDK 文档查询集成 — 通过 Context7 MCP 在开发时快速查询 Flutter API 文档
- [ ] **DEV-02**: Flutter SDK 源码参考能力 — 通过 codegraph 分析 SDK 源码解决疑难问题
- [ ] **DEV-03**: Flutter Quality Pipeline 评估 — 理解其设计，输出集成方案建议（评估文档，不集成代码）

## v2 Requirements

### Settings UI (deferred)

- **SUI-V2-01**: 7 tab 内部布局全面重做 — 每个 tab 的布局、交互、样式升级（deferred: 本次只做视觉层）
- **SUI-V2-02**: Settings search/filter — 在 7 个 tab 中快速定位设置项
- **SUI-V2-03**: 快捷键冲突检测 — 检测重复键绑定，显示警告

### Data Layer (deferred)

- **DATA-V2-01**: AppSettings god-object 拆分 — 26 字段拆为 PlaybackConfig/WindowConfig/SubtitleConfig/VideoConfig/EngineConfig
- **DATA-V2-02**: SettingsStore 拆分 — 25+ 静态方法拆为 domain-specific stores
- **DATA-V2-03**: Settings migration key — 加 settingsVersion key，安全迁移

### Fullscreen (deferred)

- **FULL-V2-01**: 全屏与设置面板彻底解耦 — 代码/状态/展示三层面全部解耦

## Out of Scope

| Feature | Reason |
|---------|--------|
| 新增设置项 | 现有设置项够用，只改 UI 和代码结构 |
| 播放器核心功能改动 | 播放引擎、播放列表等不动 |
| 跨平台全屏统一 | 本次只简化代码，不做平台行为统一 |
| 移动端适配 | 桌面端专属 |
| Live preview | 需要非模态对话框重设计，高工作量 |
| Settings presets | 依赖 import/export，属于 v2+ |
| Per-file settings | 复杂持久化层，不在本次范围 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SUI-01 | Phase 2 | Complete |
| SUI-02 | Phase 3 | Complete |
| SUI-03 | Phase 5 | Pending |
| FULL-01 | Phase 1 | Complete |
| FULL-02 | Phase 1 | Complete |
| FULL-03 | Phase 1 | Complete |
| IEX-01 | Phase 4 | Pending |
| IEX-02 | Phase 4 | Pending |
| IEX-03 | Phase 4 | Pending |
| DEV-01 | Phase 6 | Pending |
| DEV-02 | Phase 6 | Pending |
| DEV-03 | Phase 6 | Pending |

**Coverage:**

- v1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-12*
*Last updated: 2026-07-12 after initial definition*
