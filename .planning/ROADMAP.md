# Roadmap: Settings Panel Redesign

**Total Phases:** 1
**Total Requirements:** 15
**Mode:** interactive

---

### Phase 1: Settings Panel Glass Redesign

**Goal:** 设置面板从纯色背景+阴影改为毛玻璃风格，精简组件层级，与控制栏视觉统一

**Plans:** 4 plans

Plans:
- [ ] 01-01-PLAN.md — Foundation: extract SectionHeader, glass panel shell, sidebar nav glass
- [ ] 01-02-PLAN.md — Simple tabs: General, Equalizer, Audio, Performance to GlassContainer
- [ ] 01-03-PLAN.md — Complex tabs: Video, Shortcuts, About to GlassContainer
- [ ] 01-04-PLAN.md — Cleanup: remove dead components, visual verification

**Requirements:** TRIG-01, TRIG-02, TRIG-03, COMP-01, COMP-02, COMP-03, COMP-04, STYLE-01, STYLE-02, STYLE-03, STYLE-04, INTX-01, INTX-02, INTX-03, INTX-04

**Success Criteria**:
1. 设置面板使用 GlassContainer 毛玻璃背景，视觉与控制栏一致
2. 移除 SettingsCard/SettingsExpanderCard/SettingsActionCard 中间层
3. 7 个 tab 全部改为直接使用 GlassContainer + SettingRow 组合
4. 侧边栏导航项样式与控制栏按钮一致
5. OK/Cancel/Apply 延迟应用模式正常工作
6. 左键/右键双入口触发正常
7. 面板可拖拽功能正常
8. flutter analyze 无新增 warning

**Dependencies:** None

**Risks:**
- 7 个 tab 全部改造，工作量较大
- 毛玻璃效果可能影响面板可读性（需测试调整）

---

## Requirement Coverage

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

**Coverage:** 15/15 requirements mapped ✓

---
*Created: 2026-07-08*
