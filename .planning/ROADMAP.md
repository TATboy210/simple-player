# Roadmap: Simple Player — 设置面板 & 全屏重构

**Created:** 2026-07-12
**Mode:** standard
**Granularity:** standard (5-8 phases)

## Overview

| # | Phase | Goal | Requirements | Est. Time |
|---|-------|------|--------------|-----------|
| 1 | 全屏代码简化 | 2/0 | Complete    | 2026-07-12 |
| 2 | 设置面板视觉升级 | 毛玻璃风格现代化，圆角/间距/动画/交互反馈 | SUI-01 | ~3h |
| 3 | Reset to Defaults | 每个 tab 独立重置按钮，确认提示 | SUI-02 | ~2h |
| 4 | 设置导入导出 | JSON 导出/导入，格式校验，确认提示 | IEX-01, IEX-02, IEX-03 | ~2h |
| 5 | 全屏与设置面板交互规范化 | 进入/退出全屏时设置面板行为正确 | SUI-03 | ~1.5h |
| 6 | 开发工作流增强 | Context7、codegraph、Quality Pipeline 评估 | DEV-01, DEV-02, DEV-03 | ~2h |

**Total estimated:** ~13.5h
**Total requirements mapped:** 12/12 ✓

---

## Phase Details

### Phase 1: 全屏代码简化

**Goal:** 减少全屏代码层数，建立 WindowService 为单一数据源，评估是否引入 flutter_fullscreen 包

**Requirements:** FULL-01, FULL-02, FULL-03
**Plans:** 2/0 plans complete

Plans:

- [x] 01-01-PLAN.md — Delete dead driver layer + inline platform detection + FullscreenResult sealed class (FULL-01, FULL-02)
- [x] 01-02-PLAN.md — Consolidate fullscreen state + simplify timers and confirmation chain (FULL-03)

**Success Criteria:**

1. FullscreenDriver/WindowService/SettingsStore 间接层减少 1 层以上
2. flutter_fullscreen 评估文档完成，明确结论
3. SettingsStore 不再有 saveIsFullscreen/isFullscreen（UI 层直接调用 WindowService）
4. 全屏进入/退出功能正常，无回归

**Pitfalls:** Fullscreen dual-source truth — 先建立单一 owner；Win32 FFI 资源泄漏 — try/finally

---

### Phase 2: 设置面板视觉升级

**Goal:** 毛玻璃风格现代化，更新圆角、间距、动画、交互反馈

**Requirements:** SUI-01
**Plans:** 2 plans

Plans:

- [ ] 02-01-PLAN.md — Panel shell upgrade: radius 22px, sidebar 88px, nav hover/selection, tab slide, bottom button feedback (SUI-01)
- [ ] 02-02-PLAN.md — Content section stagger animations for all 7 tabs (SUI-01)

**Success Criteria:**

1. 圆角/间距与 Tokens.* 一致
2. tab 切换有过渡动画
3. 交互反馈与播放器控制栏风格一致
4. 毛玻璃效果正常

**Dependencies:** Phase 1

---

### Phase 3: Reset to Defaults

**Goal:** 每个 tab 独立重置按钮

**Requirements:** SUI-02

**Success Criteria:**

1. 每个 tab 右上角有重置按钮
2. 点击后显示确认提示
3. 确认后仅重置该 tab 设置项
4. 重置后 UI 立即刷新

**Dependencies:** Phase 2

---

### Phase 4: 设置导入导出

**Goal:** JSON 导出/导入设置

**Requirements:** IEX-01, IEX-02, IEX-03

**Success Criteria:**

1. 导出按钮 → 选择保存位置 → .json 文件
2. 导入按钮 → 选择 .json 文件
3. 导入前确认对话框
4. JSON 包含版本号
5. 格式校验失败显示错误

**Dependencies:** 无（可独立开发）

---

### Phase 5: 全屏与设置面板交互规范化

**Goal:** 进入/退出全屏时设置面板行为正确

**Requirements:** SUI-03

**Success Criteria:**

1. 进入全屏时面板不遮挡视频
2. 退出全屏时面板状态保持
3. 全屏下打开/关闭面板正常
4. 面板位置自适应

**Dependencies:** Phase 1

---

### Phase 6: 开发工作流增强

**Goal:** Context7 文档查询、codegraph 源码参考、Quality Pipeline 评估

**Requirements:** DEV-01, DEV-02, DEV-03

**Success Criteria:**

1. Context7 MCP 查询 Flutter API 文档可用
2. codegraph 分析 Flutter SDK 源码可用
3. Quality Pipeline 评估文档完成

**Dependencies:** 无（可独立开发）

---

## Phase Dependency Graph

```
Phase 1 (全屏简化) ──→ Phase 2 (视觉升级) ──→ Phase 3 (Reset)
       │
       └──→ Phase 5 (全屏交互)

Phase 4 (导入导出) — 独立
Phase 6 (工作流) — 独立
```

**Parallelizable:** Phase 4 和 Phase 6 可与任何 phase 并行

---
*Roadmap created: 2026-07-12*
