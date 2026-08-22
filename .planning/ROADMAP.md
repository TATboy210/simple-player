# Roadmap: v1.9 控制栏进度条修复与精简

**Milestone:** v1.9 控制栏进度条修复与精简
**Phases:** 3（Phase 39–41，延续历史编号）
**Granularity:** standard / 中等颗粒度
**Coverage:** 7/7 requirements mapped
**Build order:** 根因诊断+三症状修复 → 数据链局部重构 → 验证收尾

## Overview

进度条三症状（加载视频后不显示、无法交互、悬停无 Tooltip）疑似同源：`duration <= 0` 的禁用态未被解除——即 `MediaKitPlayerPort → PlayerControlsState → ControlBarViewModel → ProgressBar` 数据链在视频加载后未把 duration/position 送达。v1.8 Phase 36 未完成的 listener 生命周期改动（plan 36-03）是首要嫌疑。本路线图先以证据定位根因（不改 media_kit），修复三症状；随后在不动 media_kit 红线内局部重构数据链减少监听/rebuild 占用；最后 analyze+测试+实机 smoke 收尾。

## Phases

- [ ] **Phase 39: 进度条三症状根因诊断与修复** — 用日志/断点证据定位 duration/position 链路断点，修复三症状。
- [ ] **Phase 40: 进度条数据链局部重构** — 消除冗余监听与无效 rebuild，理顺 Tooltip 双轨职责。
- [ ] **Phase 41: 回归验证与实机 Smoke** — analyzer、测试鉴别、实机三症状验证与状态收尾。

## Phase Details

### Phase 39: 进度条三症状根因诊断与修复

**Depends on:** None
**Requirements:** PROG-01, PROG-02, PROG-03

**Success criteria:**

1. 有证据（日志/单测/调试输出）指出 duration/position 链路断点的确切位置（port 订阅、updateSources 时序、或 widget 装配）。
2. 加载视频后 `durationMs` 更新为真实时长，进度条显示且随播放推进。
3. 点击/拖拽 seek 正常，拖拽 thumb 跟手不回跳（修 C 事件驱动 v2 行为保持）。
4. 悬停时间气泡正常显示并跟随指针（AppTooltip 与自绘气泡边界不被破坏）。
5. 修复不触碰 media_kit 包内任何文件（`git diff` 验证）。

**Plans:** 预计 2 个 plan：根因诊断取证；按根因实施修复+针对性单测。

- [x] 39-01-PLAN.md
- [x] 39-02-PLAN.md

### Phase 40: 进度条数据链局部重构

**Depends on:** Phase 39
**Requirements:** REFACTOR-01, REFACTOR-02

**Success criteria:**

1. `PlayerControlsState → ControlBarViewModel → ProgressBar` 各层监听职责单一，无重复 merge/嵌套 AnimatedBuilder 链。
2. 高频 position 更新只重建进度条局部子树，不触发控制栏无关子树（延续 REBUILD 边界）。
3. Tooltip 双轨职责在代码注释与结构上清晰：AppTooltip 管静态动作提示，ProgressBar 自绘气泡管跟随指针的实时预览。
4. 重构后三症状不回归（Phase 39 的针对性单测保持通过）。

**Plans:** 预计 2 个 plan：数据链监听边界重构；Tooltip 职责边界整理。

### Phase 41: 回归验证与实机 Smoke

**Depends on:** Phase 39, Phase 40
**Requirements:** VERIFY-01, VERIFY-02

**Success criteria:**

1. `flutter analyze` 零 error；相关 widget/单测通过，headless mdk.dll 既有失败单独鉴别非本次回归。
2. `git diff` 确认无 media_kit 包内改动。
3. 用户实机 `flutter run -d windows` smoke：三症状消失，seek/悬停/进度推进正常。
4. `.planning/STATE.md` 与里程碑状态同步。

**Plans:** 预计 1 个 plan：质量门+实机验证清单。

## Risks & Dependencies

- 三症状根因可能在 media_kit `Video.controls` builder 的重建时序上（不可修改包本身），只能从项目侧封装适配——诊断阶段需先确认断点在项目侧。
- 当前工作树有未提交增量（window_manager_service 等），修复前需先确认这些改动与进度条链路无耦合。
- v1.8 Phase 36 的 listener 改动未经验证，修复时可能需要回滚或补齐其未完成部分。

## Traceability

| Phase | Requirements |
|---|---|
| 39 | PROG-01, PROG-02, PROG-03 |
| 40 | REFACTOR-01, REFACTOR-02 |
| 41 | VERIFY-01, VERIFY-02 |
