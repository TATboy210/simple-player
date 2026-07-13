# Roadmap: 沉浸式全屏重构

**Created:** 2026-07-13
**Mode:** standard
**Granularity:** standard (4 phases)

## Overview

| # | Phase | Goal | Requirements | Est. Time |
|---|-------|------|--------------|-----------|
| 1 | 旧架构移除 | 删除 FullscreenDriver、平台驱动、Win32 FFI、旧测试 | ARCH-REM-01~04 | 2h |
| 2 | WindowService 简化 | 移除确认链，直接调用 fullscreen_window 包 | WIN-SVC-01~03 | 1.5h |
| 3 | 沉浸式全屏 UI | 标题栏隐藏、控制栏自动隐藏、ESC 退出 | IMM-UI-01~03 | 1.5h |
| 4 | 测试更新 | 更新 WindowService 和 UI 测试 | TEST-UPD-01~02 | 1h |

**Total estimated:** ~6h
**Total requirements mapped:** 12/12

---

## Phase Details

### Phase 1: 旧架构移除

**Goal:** 完全移除现有的多层全屏架构

**Requirements:** ARCH-REM-01~04
**Plans:** 0/2 plans complete

Plans:
**Wave 1**

- [ ] 01-01-PLAN.md — 删除 FullscreenDriver 抽象层和平台驱动 (ARCH-REM-01, ARCH-REM-02)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 01-02-PLAN.md — 删除 Win32 FFI 绑定和旧测试文件 (ARCH-REM-03, ARCH-REM-04)

**Success Criteria:**

1. fullscreen_driver.dart、fullscreen_capability.dart 已删除
2. platform/ 目录下所有驱动文件已删除
3. win32_fullscreen_ffi.dart 已删除
4. 旧测试文件已删除
5. `flutter analyze` 无错误

---

### Phase 2: WindowService 简化

**Goal:** 简化 WindowService，直接调用 fullscreen_window 包

**Requirements:** WIN-SVC-01~03
**Plans:** 0/1 plans complete

Plans:

- [ ] 02-01-PLAN.md — 移除确认链，添加 fullscreen_window 包调用和流监听

**Success Criteria:**

1. 确认链相关方法和字段已移除
2. setMode 直接调用 FullScreenWindow.setFullScreen()
3. 订阅 onFullScreenChanged 流
4. `flutter analyze` 无错误

**Dependencies:** Phase 1

---

### Phase 3: 沉浸式全屏 UI

**Goal:** 沉浸式全屏体验

**Requirements:** IMM-UI-01~03
**Plans:** 0/1 plans complete

Plans:

- [ ] 03-01-PLAN.md — 标题栏隐藏、控制栏自动隐藏、ESC 退出

**Success Criteria:**

1. 全屏时标题栏隐藏
2. 控制栏自动隐藏+鼠标唤醒
3. ESC 退出全屏
4. 过渡动画平滑

**Dependencies:** Phase 2

---

### Phase 4: 测试更新

**Goal:** 更新测试以匹配新架构

**Requirements:** TEST-UPD-01~02
**Plans:** 0/1 plans complete

Plans:

- [ ] 04-01-PLAN.md — 更新 WindowService 和 UI 测试

**Success Criteria:**

1. WindowService 测试覆盖新逻辑
2. UI 测试覆盖全屏行为
3. 所有测试通过

**Dependencies:** Phase 3

---

## Phase Dependency Graph

```
Phase 1 → Phase 2 → Phase 3 → Phase 4
```

---
*Created: 2026-07-13*
