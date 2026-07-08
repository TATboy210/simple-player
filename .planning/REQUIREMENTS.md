# Requirements: Settings Panel Redesign

**Defined:** 2026-07-08
**Core Value:** 设置面板与控制栏视觉风格统一，组件层级精简，用户体验流畅

## v1 Requirements

### 触发优化

- [ ] **TRIG-01**: 左键点击设置按钮打开完整面板（保持现有行为）
- [ ] **TRIG-02**: 右键点击弹出快速语言/主题切换菜单（保持现有行为）
- [ ] **TRIG-03**: 设置按钮 hover 视觉反馈与控制栏其他按钮一致

### 组件精简

- [ ] **COMP-01**: 设置面板主体使用 GlassContainer 毛玻璃背景（替代 SettingsCard 的纯色背景）
- [ ] **COMP-02**: 保留 SettingRow 和 SettingSwitchRow 作为核心行组件
- [ ] **COMP-03**: 移除 SettingsCard/SettingsExpanderCard/SettingsActionCard 中间层，直接用 GlassContainer + Column 组合
- [ ] **COMP-04**: 设置面板标题栏与控制栏标题栏风格统一

### 样式统一

- [ ] **STYLE-01**: 设置面板背景使用 Tokens.bgGlass + BackdropFilter（与控制栏一致）
- [ ] **STYLE-02**: 设置面板圆角使用 Tokens.radiusLarge（与控制栏一致）
- [ ] **STYLE-03**: 设置面板边框使用 Tokens.borderHighlight（与控制栏一致）
- [ ] **STYLE-04**: 侧边栏导航项 hover/selected 样式与控制栏按钮一致

### 交互保持

- [ ] **INTX-01**: OK/Cancel/Apply 延迟应用模式不变
- [ ] **INTX-02**: locale/theme 变更推迟到对话框关闭
- [ ] **INTX-03**: 快捷键取消恢复机制不变
- [ ] **INTX-04**: 面板可拖拽功能不变

## v2 Requirements

### 后续优化

- **COMP-05**: 提取 SwitchRow、RadioRow、SliderRow 语义化变体
- **STYLE-05**: 设置面板响应式布局（窄屏适配）
- **TRIG-04**: 设置按钮长按显示快捷提示

## Out of Scope

| Feature | Reason |
|---------|--------|
| 设置搜索功能 | 长期功能，不在本次范围 |
| Golden tests | 后续补充 |
| 新增设置项 | 本次只重构现有功能 |
| 响应式布局 | v2 再做 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRIG-01 | Phase 1 | Pending |
| TRIG-02 | Phase 1 | Pending |
| TRIG-03 | Phase 1 | Pending |
| COMP-01 | Phase 1 | Pending |
| COMP-02 | Phase 1 | Pending |
| COMP-03 | Phase 1 | Pending |
| COMP-04 | Phase 1 | Pending |
| STYLE-01 | Phase 1 | Pending |
| STYLE-02 | Phase 1 | Pending |
| STYLE-03 | Phase 1 | Pending |
| STYLE-04 | Phase 1 | Pending |
| INTX-01 | Phase 1 | Pending |
| INTX-02 | Phase 1 | Pending |
| INTX-03 | Phase 1 | Pending |
| INTX-04 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-08*
*Last updated: 2026-07-08 after initial definition*
