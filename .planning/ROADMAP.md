# Roadmap: v1.6 控制栏质量优化与测试补全

## Overview

消除控制栏 P0-P1 技术债务，修复窗口拉伸时毛玻璃突兀跳变，建立控制栏测试基础。

## Milestones

- ✅ **v1.0 MVP** - Phases 1-4 (shipped 2026-05-29)
- ✅ **v1.1 Testing & Quality** - Phases 5-7 (shipped 2026-05-30)
- ✅ **v1.2 Security & Kernel** - Phases 8-11 (shipped 2026-05-31)
- ✅ **v1.2.1 Window Polish** - Phases 12-15 (shipped 2026-06-28)
- ✅ **v1.3 Glass Morphism Coordination** - Phases 16-19 (shipped 2026-07-03)
- ✅ **v1.4 Technical Debt Cleanup** - Phase 20 (completed 2026-07-04)
- ✅ **v1.5 Code Documentation** - Phases 21-24 (completed 2026-07-05)
- 🔲 **v1.6 Control Bar Quality** - Phases 25-27 (Phase 26 ✅)

## Phases

### Phase 25: Performance Quick Wins

**Goal**: 消除 P0 性能问题 — resize 毛玻璃跳变、decoration 缓存、blur 缓存、魔法数字
**Depends on**: Phase 24
**Requirements**: PERF-01, PERF-02, PERF-03, PERF-04
**Success Criteria** (what must be TRUE):

  1. 窗口 resize 时毛玻璃以 150ms 渐变淡出/淡入，无二元跳变
  2. `_decorationPlaying`/`_decorationIdle` 不在 build() 中重复创建
  3. GlassContainer 的 ImageFilter.blur 按 GlassTier 缓存，不在每次 build 重建
  4. 18px 魔法数字提取为命名常量
  5. `flutter analyze` 无新增 warning/error
  6. 所有现有测试通过

**Plans**: 2/2 plans complete

- [x] 25-01-PLAN.md — Resize 渐变 + decoration/blur 缓存 + 魔法数字提取 + 淡蓝辉光
- [x] 25-02-PLAN.md — Gap closure: resize fade-out 修复 + decoration state wiring + controlBarBorderIdle + build errors

**UI hint**: yes

### Phase 26: VolumeSlider Debounce

**Goal**: VolumeSlider 拖拽时 OSD 和引擎调用频率降至合理水平
**Depends on**: Phase 25
**Requirements**: PERF-05
**Success Criteria** (what must be TRUE):

  1. 拖拽期间 OSD 调用频率 ≤10/秒（从 60+/秒降低）
  2. 拖拽结束时立即同步最终音量值（无感知延迟）
  3. 引擎 setVolume 调用频率同步降低
  4. `flutter analyze` 无新增 warning/error
  5. 所有现有测试通过

**Plans**: 1/1 plans complete

- [x] 26-01-PLAN.md — VolumeSlider debounce 实现（含详细逐行解释）

**UI hint**: no

### Phase 27: Control Bar Test Coverage

**Goal**: 补全控制栏核心组件测试覆盖
**Depends on**: Phase 25
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):

  1. AutoHideController 单元测试：覆盖 idle/playing/hidden/paused 状态转换、hover 节流、resize 冻结
  2. ProgressBar Widget 测试：覆盖拖拽阈值(5px)、seek 节流(150ms)、hover tooltip
  3. VolumeButton Widget 测试：覆盖静音切换、音量保存/恢复、滑块联动
  4. SpeedButton Widget 测试：覆盖双击重置(1.0x)、滚轮切换、档位循环
  5. 新增测试全部通过，覆盖率 ≥80%
  6. `flutter test` 无新增失败

**Plans**: 1/1 plans complete

- [x] 27-01-PLAN.md — 控制栏测试补全（+14 tests: AutoHideController 3, ProgressBar 3, VolumeButton 3, SpeedButton 5）

**UI hint**: no

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 25. Performance Quick Wins | 1/1 | Complete   | 2026-07-05 |
| 26. VolumeSlider Debounce | 1/1 | Complete | 2026-07-07 |
| 27. Control Bar Test Coverage | 1/1 | In Progress | — |
