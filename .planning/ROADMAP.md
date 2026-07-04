# Roadmap: v1.3 控制栏视觉协调与玻璃质感优化

## Overview

控制栏与背景的视觉协调：添加空状态 token 体系，让控制栏在无视频时自动切换到更淡的配色，调整玻璃质感参数使控制栏与 AuroraBackground 融合。

## Milestones

- ✅ **v1.0 MVP** - Phases 1-4 (shipped 2026-05-29)
- ✅ **v1.1 Testing & Quality** - Phases 5-7 (shipped 2026-05-30)
- ✅ **v1.2 Security & Kernel** - Phases 8-11 (shipped 2026-05-31)
- ✅ **v1.2.1 Window Polish** - Phases 12-15 (shipped 2026-06-28)
- ✅ **v1.3 Glass Morphism Coordination** - Phases 16-19 (shipped 2026-07-03)
- ✅ **v1.4 Technical Debt Cleanup** - Phase 20 (completed 2026-07-04)
- 🔲 **v1.5 Code Documentation** - Phases 21-24

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-4) — SHIPPED 2026-05-29</summary>

- [x] **Phase 1: Window Foundation** - C++ WindowChannel, frameless window, Win32 resize/drag
- [x] **Phase 2: GlassMorphism & Controls** - GlassWidget library, control bar, progress bar
- [x] **Phase 3: Playback Engine** - fvp integration, playlist, media state management
- [x] **Phase 4: D3D11 Performance** - Hardware decoders, ring buffer, PerfMonitor

</details>

<details>
<summary>✅ v1.1 Testing & Quality (Phases 5-7) — SHIPPED 2026-05-30</summary>

- [x] **Phase 5: Integration Tests** - Critical user flow E2E tests
- [x] **Phase 6: Golden Tests** - Glassmorphism component golden tests
- [x] **Phase 7: Code Optimization** - Architecture refactoring, dead code cleanup

</details>

<details>
<summary>✅ v1.2 Security & Kernel (Phases 8-11) — SHIPPED 2026-05-31</summary>

- [x] **Phase 8: FFI Safety** - Memory leak fix, try/finally, fullscreen timeout
- [x] **Phase 9: Input Validation** - URL structure, path length, null byte checks
- [x] **Phase 10: Window Optimization** - WM_NCCALCSIZE, D3D11 sync, PositionPoller
- [x] **Phase 11: Debug Tooling** - Structured logging, Timeline tracing

</details>

<details>
<summary>✅ v1.2.1 Window Polish (Phases 12-15) — SHIPPED 2026-06-28</summary>

- [x] **Phase 12: Window Foundation** - WM_NCCALCSIZE sync frame, zero-flicker startup
- [x] **Phase 13: HLS ABR** - Adaptive bitrate streaming
- [x] **Phase 14: Architecture Simplification** - Window layer cleanup, singleton migration
- [x] **Phase 15: Window Polish** - Multi-monitor, responsive layout, settings fixes

</details>

### ✅ v1.3 Glass Morphism Coordination (Completed 2026-07-03)

**Milestone Goal:** 控制栏颜色/亮度与背景融合，减少视觉突兀感

- [x] **Phase 16: Token Foundation & Independent Fixes** - Idle tokens, glow param, contrast fix (completed 2026-07-03)
- [x] **Phase 17: Adaptive Control Bar** - AnimatedContainer, idle/playing transition, animation tests (completed 2026-07-03)
- [x] **Phase 18: Visual Tuning & Validation** - Token alpha fix, blur merge, validation tests (completed 2026-07-03)
- [x] **Phase 19: Gradient Transition Strip** - 渐变过渡带消除视频与控制栏硬边 (completed 2026-07-03)

## Phase Details

### Phase 16: Token Foundation & Independent Fixes

**Goal**: Project has idle-state design tokens, adjustable EdgeGlow, and WCAG-compliant contrast
**Depends on**: Phase 15
**Requirements**: UI-01, UI-04, UI-05
**Success Criteria** (what must be TRUE):

  1. Six idle-state constants exist in tokens.dart and compile without errors
  2. EdgeGlow widget accepts optional glowIntensity parameter (default null preserves existing behavior)
  3. Secondary text achieves WCAG AA contrast ratio (>= 4.5:1, target 5.3:1) against control bar background
  4. All existing golden and widget tests pass with no regressions

**Plans**: 1/1 plans complete

- [x] 16-01-PLAN.md

**UI hint**: yes

### Phase 17: Adaptive Control Bar

**Goal**: Control bar visually adapts between idle and playing states using idle tokens
**Depends on**: Phase 16
**Requirements**: UI-02, UI-03
**Success Criteria** (what must be TRUE):

  1. GlassContainer accepts optional backgroundColor parameter (default Tokens.bgGlass, backward compatible)
  2. ControlBar shows distinct idle-state decoration when no video is loaded (lighter, more transparent)
  3. ControlBar shows existing decoration during playback (no change from current behavior)
  4. Transition between idle/playing states is visually smooth (no flicker or jump)
  5. Existing call sites of GlassContainer and ControlBar require zero modifications

**Plans**: 1/1 plans complete

- [x] 17-01-PLAN.md

**UI hint**: yes

### Phase 18: Visual Tuning & Validation

**Goal**: All visual parameters are validated and tuned across diverse video content types
**Depends on**: Phase 17
**Requirements**: UI-06
**Success Criteria** (what must be TRUE):

  1. Control bar appearance is validated against dark, bright, mixed, colorful, and letterbox video content
  2. Idle-state border remains visible (alpha >= 15%) in all tested scenarios
  3. glassBlur vs glassBlurThick distinction is confirmed or consolidated based on visual evidence
  4. No visual regressions: playing-state control bar appearance unchanged from pre-v1.3 baseline

**Plans**: 1/1 plans complete

- [x] 18-01-PLAN.md

**UI hint**: yes

### Phase 19: Gradient Transition Strip

**Goal**: 控制栏上方添加渐变过渡带，消除视频内容与玻璃控制栏之间的硬边
**Depends on**: Phase 18
**Requirements**: UI-07
**Success Criteria** (what must be TRUE):

  1. 控制栏上方有 60px 渐变过渡带（透明→控制栏背景色）
  2. 渐变带随控制栏 idle/playing 状态切换颜色
  3. 渐变带与控制栏同步淡入淡出（FadeTransition）
  4. 不拦截鼠标事件（hitTest passthrough）

**Plans**: 1/1 plans complete

- [x] 19-01-PLAN.md

**UI hint**: yes

### Phase 20: Technical Debt Cleanup

**Goal**: 零 warning/零 error，迁移弃用 Color API，修复预存测试失败
**Depends on**: Phase 18
**Requirements**: TECH-01, TECH-02, TECH-03, TECH-04
**Success Criteria** (what must be TRUE):

  1. `flutter analyze` 输出 0 errors, 0 warnings
  2. `flutter test` 905+ tests passing, 0 failures
  3. 所有 Color API 使用新接口（`.a`/`.r`/`.g`/`.b`/`.toARGB32()`）
  4. 所有 `const` 构造函数已补全

**Plans**: 2/2 plans complete

- [x] 20-01-PLAN.md
- [x] 20-02-PLAN.md

**UI hint**: no

## v1.5 Code Documentation

### Phase 21: Kernel Engine & Bridge Documentation

**Goal**: Engine 和 Bridge 层所有文件添加/完善注释
**Depends on**: Phase 20
**Requirements**: DOC-01 ~ DOC-16
**Success Criteria** (what must be TRUE):

  1. Engine 层 12 个文件均有类级 `///` doc comment 和关键方法文档
  2. Bridge 层 4 个文件均有平台特定逻辑的解释性注释
  3. 所有魔法数字已添加行内说明注释（D-09: 保留原始值，不提取为命名常量；3+次出现提取为文件级私有常量）
  4. `flutter analyze` 无新增 warning/error

**Plans**: 2/2 plans complete

- [x] 21-01-PLAN.md — Engine files (DOC-01~DOC-12)
- [x] 21-02-PLAN.md — Bridge files (DOC-13~DOC-16)

**UI hint**: no

### Phase 22: Kernel Models, Utils & Services Documentation

**Goal**: Models、Utils、Services 层所有文件添加/完善注释
**Depends on**: Phase 21
**Requirements**: DOC-17 ~ DOC-32
**Success Criteria** (what must be TRUE):

  1. Models 层 6 个枚举/数据类均有 `///` doc comment 说明用途和取值含义
  2. Utils 层 5 个工具文件均有函数级文档和参数说明
  3. Services 层 7 个文件均有服务职责和依赖关系说明
  4. `flutter analyze` 无新增 warning/error

**Plans**: 2/2 plans complete

- [x] 22-01-PLAN.md — Models + Utils (DOC-17~DOC-25)
- [x] 22-02-PLAN.md — Services + Others (DOC-26~DOC-32)

**UI hint**: no

### Phase 23: UI Layer Documentation

**Goal**: UI 层所有需要改进的文件添加/完善注释
**Depends on**: Phase 22
**Requirements**: DOC-33 ~ DOC-45
**Success Criteria** (what must be TRUE):

  1. Dialogs 层 5 个设置 tab 均有参数说明和 FFmpeg 语法解释
  2. Player 层 4 个文件均有交互逻辑说明
  3. Shared 层 4 个组件均有使用场景和模式说明
  4. `flutter analyze` 无新增 warning/error

**Plans**: 0/2 plans complete

- [ ] 23-01-PLAN.md — Dialogs (DOC-33~DOC-37)
- [ ] 23-02-PLAN.md — Player + Shared (DOC-38~DOC-45)

**UI hint**: no

### Phase 24: Features & Verification

**Goal**: Features 层注释补全 + 全量验证
**Depends on**: Phase 23
**Requirements**: DOC-46 ~ DOC-50
**Success Criteria** (what must be TRUE):

  1. Features 层 5 个文件均有模式说明和依赖关系文档
  2. `flutter analyze` 0 errors, 0 warnings
  3. `flutter test` 905+ tests passing, 0 failures
  4. 所有 50 个 DOC requirement 已验证完成

**Plans**: 0/1 plans complete

- [ ] 24-01-PLAN.md — Features + verification (DOC-46~DOC-50)

**UI hint**: no

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 16. Token Foundation & Independent Fixes | 1/1 | Complete    | 2026-07-03 |
| 17. Adaptive Control Bar | 1/1 | Complete | 2026-07-03 |
| 18. Visual Tuning & Validation | 1/1 | Complete | 2026-07-03 |
| 19. Gradient Transition Strip | 1/1 | Complete | 2026-07-03 |
| 20. Technical Debt Cleanup | 2/2 | Complete   | 2026-07-04 |
| 21. Kernel Engine & Bridge Docs | 2/2 | Complete | 2026-07-04 |
| 22. Kernel Models/Utils/Services Docs | 2/2 | Complete    | 2026-07-04 |
| 23. UI Layer Docs | 0/2 | Pending | - |
| 24. Features & Verification | 0/1 | Pending | - |
