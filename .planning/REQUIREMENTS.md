# Requirements: v1.8 播放器 Widget 稳定性与 PC Resize 流畅度

**Defined:** 2026-08-11
**Core Value:** 保持播放器功能/交互不变，降低 PC 窗口频繁变换时的 widget rebuild、布局和渲染卡顿。

## BASE — Widget Tree 基线与恢复（Phase 35）

- [ ] **BASE-01**：从本地 Git 比较 `e0083842`、`f590cce2`、`6e0edbb8` 及父提交，形成按文件的 widget tree 基线；不整体覆盖当前工作树。
- [ ] **BASE-02**：确认 `PlayerScreen → Video.controls → PlayerVideoControls → ControlBar` 主路径存在，旧 `ControlsOverlay` 和旧 fullscreen plugin 不重新接入。
- [ ] **BASE-03**：播放/暂停、seek、音量、倍速、字幕、全屏、ESC、空状态、错误传播、拖放、键盘快捷键和窗口按钮的现有行为测试保持通过。
- [ ] **BASE-04**：验证 `GlassButton` callback 在 widget 更新后仍指向最新回调；修复 action cache 旧闭包风险（若可复现）。
- [ ] **BASE-05**：验证 PlayerVideoControls source replacement、reparent、activate/deactivate、dispose、subtitle padding 和旧 source 隔离。

## REBUILD — 中等颗粒度重建边界（Phase 36）

- [ ] **REBUILD-01**：标题、idle、播放状态、音量、进度和 resize 状态分别在最小必要子树监听，不因单一状态变化重建整条 ControlBar。
- [ ] **REBUILD-02**：保留并验证 `ControlBarTitle.titleListenable`、`CenterGroup.isIdleListenable` 等局部监听链，静态构造参数保持兼容。
- [ ] **REBUILD-03**：PlayerScreen 标题栏和视频 surface 的 widget identity 在普通 build、窗口模式变化和 resize session 中保持稳定；WindowBridge 替换时绑定新 service。
- [ ] **REBUILD-04**：所有新增监听、合并监听器和 timer 具备对称解绑/dispose 行为，不监听旧 notifier 或旧 player。
- [ ] **REBUILD-05**：组件职责保持中等颗粒度；避免恢复旧大 overlay 或产生超过项目文件/函数大小约束的新单体。

## RENDER — 渲染、玻璃与纹理 resize（Phase 37）

- [ ] **RENDER-01**：CustomTitleBar 在有限、窄窗口和测试装配约束下无 RenderFlex assertion，按钮顺序、命中区域和拖拽行为不变。
- [ ] **RENDER-02**：玻璃层、BackdropFilter、RepaintBoundary 和装饰绘制边界经过 profile 验证；不叠加无必要 blur/readback。
- [ ] **RENDER-03**：视频 surface/texture 在连续 resize session 中不因无关 widget rebuild 被重新挂载；resize 期间控制栏可见性语义保持一致。
- [ ] **RENDER-04**：进度条、背景 painter、控制栏动画等高频更新优先走 repaint/listenable 边界，避免重建不相关 tooltip、标题或按钮。
- [ ] **RENDER-05**：Windows 频繁最大化、还原、拖拽和 resize 场景记录 frame timing、jank 峰值和纹理变化；不引入新的明显峰值。

## VERIFY — 回归与性能证据（Phase 38）

- [ ] **VERIFY-01**：`flutter analyze` 无问题，相关播放器 widget/integration 测试通过，`git diff --check` 通过。
- [ ] **VERIFY-02**：关键播放流程和交互行为回归覆盖达到项目目标，headless `mdk.dll` 既有失败与本次回归明确区分。
- [ ] **VERIFY-03**：Windows profile 证据包含 resize 帧耗时、jank 峰值、控制栏/视频 surface 稳定性和内存趋势。
- [ ] **VERIFY-04**：flutter-code-reviewer、dart-testing、flutter-integration-validator 对最终改动检查无 Critical/High 问题。
- [ ] **VERIFY-05**：未追踪截图用途已确认；未经明确授权不删除、不提交；`.planning/STATE.md` 与新里程碑状态同步。

## Out of Scope

| Feature | Reason |
|---|---|
| media_kit/libmpv 底层修改 | 本里程碑只调整项目封装、widget 和测试层 |
| ControlsOverlay 恢复 | 已由 PlayerVideoControls 取代，会造成双控制树和状态竞争 |
| 新状态管理框架 | 当前 ValueNotifier 架构足够且需降低迁移风险 |
| 播放功能改版 | 目标是稳定性和流畅度，不改变用户操作契约 |
| 未经确认的截图清理 | 文件用途尚未确认 |

## Traceability

| Requirement group | Phase | Status |
|---|---:|---|
| BASE-01..05 | 35 | Pending |
| REBUILD-01..05 | 36 | Pending |
| RENDER-01..05 | 37 | Pending |
| VERIFY-01..05 | 38 | Pending |
