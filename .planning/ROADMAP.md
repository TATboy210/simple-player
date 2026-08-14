# Roadmap: v1.8 播放器 Widget 稳定性与 PC Resize 流畅度

**Milestone:** v1.8 播放器 Widget 稳定性与 PC Resize 流畅度
**Phases:** 4（Phase 35–38，延续历史编号）
**Granularity:** standard / 中等颗粒度
**Coverage:** 20/20 requirements mapped
**Build order:** 基线恢复 → rebuild 边界 → 渲染/resize → 综合验证

## Overview

本路线图不把历史 widget tree 整体 checkout 到当前分支。Phase 35 先确认最近 Git tree 与当前实现的差异，并以行为测试锁定恢复边界；之后在保留 `Video.controls → PlayerVideoControls`、直接 `ControlBar` 和 `CustomTitleBar` 优化的前提下，逐阶段缩小 rebuild、layout、paint 和纹理生命周期边界。

## Phases

- [x] **Phase 35: Widget Tree Baseline & Behavior Recovery** — 比较本地历史 tree，确认当前主路径，定点恢复缺失行为并补高风险回归测试。
- [ ] **Phase 36: Medium-Grain Rebuild Boundary Refactor** — 拆分标题、idle、媒体状态、音量、进度和 resize 的监听边界，保持 widget identity 与 source 生命周期。
- [ ] **Phase 37: Rendering, Glass & Resize Stability** — 优化 RepaintBoundary、BackdropFilter、painter、视频纹理和 PC resize 期间的布局/raster 行为。
- [ ] **Phase 38: Regression & Windows Performance Evidence** — 完成自动化回归、analyze、review、profile 帧耗时/jank/内存证据和规划状态收尾。

## Phase Details

### Phase 35: Widget Tree Baseline & Behavior Recovery

**Depends on:** None
**Requirements:** BASE-01..05

**Success criteria:**
1. 形成 `e0083842`、`f590cce2`、`6e0edbb8` 与当前工作树的按文件差异基线。
2. 明确不恢复 `ControlsOverlay`、旧 fullscreen plugin，不改变 media_kit。
3. 关键播放/窗口/控制交互测试通过。
4. 完成 GlassButton callback、PlayerVideoControls source/reparent/dispose、CustomTitleBar WindowBridge replacement 的定点验证。

**Plans:** 3 plans

Plans:
- [ ] 35-01-PLAN.md — 建立只读 Git widget tree 与关键行为回归基线
- [ ] 35-02-PLAN.md — 锁定 WindowBridge replacement 与 GlassButton 最新 callback
- [ ] 35-03-PLAN.md — 锁定 PlayerVideoControls source/reparent/subtitle 生命周期

### Phase 36: Medium-Grain Rebuild Boundary Refactor

**Depends on:** Phase 35
**Requirements:** REBUILD-01..05

**Success criteria:**
1. 状态变化只重建必要局部子树；不恢复整条 ControlBar 的单一媒体身份监听。
2. `titleListenable`、`isIdleListenable`、resize/source listeners 的生命周期和 identity 经过测试。
3. PlayerScreen 标题栏、视频 surface 和 PlayerVideoControls 在 build/reparent/resize 后保持稳定。
4. 相关函数和文件维持可维护的中等颗粒度。

**Plans:** 3 个 plan：ControlBar 局部 rebuild、PlayerScreen/video identity、listener/timer 生命周期。

Plans:
- [ ] 36-01-PLAN.md — 以标题 tracer 开始，锁定 ControlBar 的 title/idle/playing/volume/progress 局部 rebuild
- [ ] 36-02-PLAN.md — 验证 PlayerScreen 标题栏、视频 surface、controls identity 与 engine/controller replacement
- [ ] 36-03-PLAN.md — 验证 ProgressBar source replacement、merged listener、timer 与 controls 生命周期对称性

### Phase 37: Rendering, Glass & Resize Stability

**Depends on:** Phase 36
**Requirements:** RENDER-01..05

**Success criteria:**
1. 标题栏在有限/窄/测试约束下无布局 assertion，视觉和交互不变。
2. 玻璃层和高频 painter 的 rebuild/repaint 边界通过 profile 验证。
3. 视频纹理不因 resize 或无关状态被重新挂载，控制栏 hide/show 语义不变。
4. Windows 频繁窗口变换有帧耗时、jank 和纹理变化证据。

**Plans:** 预计 3 个 plan：layout/constraint、glass/painter、texture/resize instrumentation。

### Phase 38: Regression & Windows Performance Evidence

**Depends on:** Phase 35, 36, 37
**Requirements:** VERIFY-01..05

**Success criteria:**
1. analyzer、相关测试、diff check 全部通过。
2. 独立 review 和 integration validation 无 Critical/High 问题。
3. 关键播放交互无回归，既有 headless FFI 失败被单独记录。
4. Windows profile 记录 frame timing、resize jank 峰值和内存趋势。
5. `.planning/STATE.md` 与实际里程碑同步；截图不在未授权情况下处理。

**Plans:** 预计 2 个 plan：自动化质量门、Windows profile 与最终审查。

## Risks & Dependencies

- 当前工作树有未提交代码和未追踪图片；所有历史应用必须文件/方法级，不得整体 reset。
- `PlayerVideoControls` 依赖 media_kit `VideoState` 生命周期；headless 测试优先使用 fake port，实机验证保留到 Phase 38。
- BackdropFilter、texture resize 和 window mode transition 可能存在只在 Windows profile 暴露的 raster 峰值。
- `GlassButton` action cache 和 source replacement 是高风险行为点，必须在扩展性能优化前验证。

## Traceability

| Phase | Requirements |
|---|---|
| 35 | BASE-01, BASE-02, BASE-03, BASE-04, BASE-05 |
| 36 | REBUILD-01, REBUILD-02, REBUILD-03, REBUILD-04, REBUILD-05 |
| 37 | RENDER-01, RENDER-02, RENDER-03, RENDER-04, RENDER-05 |
| 38 | VERIFY-01, VERIFY-02, VERIFY-03, VERIFY-04, VERIFY-05 |

---
*Roadmap created: 2026-08-11 — ready for `/gsd-plan-phase 35`*
