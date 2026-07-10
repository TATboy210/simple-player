# Roadmap: Player Fullscreen v2

**Created:** 2026-07-09
**v2 Phases:** 3
**v2 Requirements:** 11
**Mode:** standard

---

## v1 Phases (已完成)

<details>
<summary>✅ v1.0 Fullscreen Architecture (Phases 1-4) — SHIPPED 2026-07-10</summary>

### Phase 1: 架构定稿与核心模型

**Goal:** FullscreenAdapter 抽象层、状态模型、事件流、错误模型
**Status:** Complete (3 plans)

Plans:

- [x] 01-01: FullscreenAdapter 接口定义
- [x] 01-02: 状态模型与事件系统
- [x] 01-03: 错误处理与恢复策略

### Phase 2: 命令队列与恢复策略

**Goal:** per-window 命令串行化、幂等合并、状态回读、恢复策略
**Status:** Complete (3 plans)

Plans:

- [x] 02-01: 命令队列实现
- [x] 02-02: 幂等合并与状态回读
- [x] 02-03: 恢复策略全覆盖

### Phase 3: 平台适配与深化

**Goal:** Windows/macOS/Linux 三端全屏驱动生产级稳定
**Status:** Complete (4 plans)

Plans:

- [x] 03-01: Windows WS_THICKFRAME 剥离/恢复
- [x] 03-02: macOS 系统全屏生命周期
- [x] 03-03: Linux GTK/WM 差异兜底
- [x] 03-04: FullscreenCapability 能力查询

### Phase 4: 质量收尾与迁移完成

**Goal:** 回归矩阵、CI 补齐、旧实现可下线、RC 版本
**Status:** Complete (3 plans)

Plans:

- [x] 04-01: 回归测试矩阵
- [x] 04-02: 旧代码清理 + deprecated 标记
- [x] 04-03: RC 版本 + E2E 验证

</details>

---

## v2 Phases

### Phase 5: 性能与Bug修复

**Goal:** 全屏切换 <100ms 零闪烁，16:9视频无黑边，边框残留修复
**Depends on:** Phase 4
**Requirements:** PERF-01, PERF-02, PERF-03, FIX-01, FIX-02

**Success Criteria** (what must be TRUE):

  1. 全屏切换从按下 F 到画面填满 <100ms
  2. 全屏进入/退出无黑帧/白帧/撕裂
  3. 16:9 视频在16:9显示器上全屏无黑边
  4. 全屏时无 WS_THICKFRAME 边框残留
  5. Win32 FFI 系统调用次数减少50%+
  6. flutter test 全通过，无 regression

**Plans:** 2 plans

Plans:
**Wave 1**

- [ ] 05-01: FIX-01+02: 视频黑边修复 + 边框残留修复（渲染层排查 + FFI 样式剥离）

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 05-02: PERF-01+02+03: FFI 路径优化 + 零闪烁过渡（合并系统调用、原子性操作）

**Risk:** High — 性能优化涉及底层 FFI 和渲染层

---

### Phase 6: 用户体验升级

**Goal:** 全屏过渡动画平滑，控制栏交互响应快
**Depends on:** Phase 5
**Requirements:** UX-01, UX-02

**Success Criteria** (what must be TRUE):

  1. 全屏进入/退出有平滑过渡效果（不突兀跳变）
  2. 全屏时鼠标移动唤醒控制栏响应 <200ms
  3. OSD 提示在全屏时正确显示和消失
  4. 控制栏在全屏时自动隐藏/显示行为符合预期

**Plans:** 2 plans

Plans:

- [ ] 06-01: UX-01: 全屏过渡动画实现（Flutter AnimatedContainer + 淡入淡出）
- [ ] 06-02: UX-02: 控制栏交互优化（鼠标唤醒区域、OSD 响应）

**Risk:** Medium — 动画可能影响性能，需平衡

---

### Phase 7: 技术探索与代码质量

**Goal:** D3D11 可行性验证、旧代码清理、测试覆盖80%+
**Depends on:** Phase 5
**Requirements:** EXP-01, CLEAN-01, CLEAN-02, CLEAN-03

**Success Criteria** (what must be TRUE):

  1. D3D11 独占全屏 POC 验证完成（可行/不可行 + 原因）
  2. 旧 fullscreen_window 直连代码已清理或标记 @deprecated
  3. 全屏相关代码测试覆盖率 ≥80%
  4. 职责不清的模块已重构，flutter analyze 零 warning
  5. 架构文档更新

**Plans:** 3 plans

Plans:

- [ ] 07-01: EXP-01: D3D11 独占全屏 POC（Win32 DXGI 互操作探索）
- [ ] 07-02: CLEAN-01+03: 旧代码清理 + 架构重构
- [ ] 07-03: CLEAN-02: 测试覆盖率提升（全屏切换路径全覆盖）

**Risk:** Medium — D3D11 探索可能证明不可行

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. 架构定稿与核心模型 | v1.0 | 3/3 | Complete | 2026-07-10 |
| 2. 命令队列与恢复策略 | v1.0 | 3/3 | Complete | 2026-07-10 |
| 3. 平台适配与深化 | v1.0 | 4/4 | Complete | 2026-07-10 |
| 4. 质量收尾与迁移完成 | v1.0 | 3/3 | Complete | 2026-07-10 |
| 5. 性能与Bug修复 | v2.0 | 0/2 | Not started | - |
| 6. 用户体验升级 | v2.0 | 0/2 | Not started | - |
| 7. 技术探索与代码质量 | v2.0 | 0/3 | Not started | - |

---

*Created: 2026-07-09*
*Last updated: 2026-07-10 — v2 optimization roadmap, numeric phase format*
