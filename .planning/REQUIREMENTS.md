# Requirements: Control Bar Polish

**Defined:** 2026-07-07
**Core Value:** 沉浸式观看体验 — 控制栏"隐形但可用"

## v1 Requirements

### 动画体验 (CB-01)

- [ ] **CB-01a**: 播放状态下控制栏隐藏/显示 fade 动画时长优化（参考 VLC 500ms）
- [ ] **CB-01b**: fade 动画曲线优化（可能需要调整 Curves.easeOut 参数或换用更平滑曲线）
- [ ] **CB-01c**: idle→playing 状态切换时控制栏装饰过渡平滑

### 毛玻璃质感 (CB-02)

- [ ] **CB-02a**: GlassTier.normal sigma 从 10.0 提升至 ~11.5（+15%）
- [ ] **CB-02b**: 验证 GlassContainer / EdgeGlow 缓存的 ImageFilter 正确更新
- [ ] **CB-02c**: 确认 BackdropFilter 跳过优化（opacity<0.01 / resize / blurEnabled）不受影响

### 按钮交互 (CB-03)

- [ ] **CB-03a**: GlassButton hover 颜色 Tokens.bgHover 提升对比度（当前 #1E2232 偏暗）
- [ ] **CB-03b**: InkWell hover 高亮区域缩小，不与控制栏底部边框重叠
- [ ] **CB-03c**: idle 和 playing 状态下 hover 反馈一致且显眼

### 布局压缩 (CB-04)

- [ ] **CB-04a**: 评估 3 行（标题/进度条/按钮）当前比例（等分 flex:1/1/1）
- [ ] **CB-04b**: 确定是否可压缩总高度（110px → 更小值）
- [ ] **CB-04c**: 如可压缩，调整 Row flex 比例或改用固定高度

### 底部辉光移除 (CB-05)

- [ ] **CB-05a**: 删除 controls_overlay.dart 中 TransmittedLight 组件
- [ ] **CB-05b**: 验证移除后不影响控制栏布局和定位

### Resize 接线修复 (CB-06)

- [ ] **CB-06a**: ControlBar 新增 `resizing` 字段并透传给 ProgressBar — 修复断路的 resize 缓存优化链
- [ ] **CB-06b**: ControlsOverlay._onResizeChanged() 同步 `_autoHide.resizing` — 修复 resize 期间自动隐藏计时器泄漏
- [ ] **CB-06c**: ControlsOverlay.initState 防御性同步 resizing 初始状态
- [ ] **CB-06d**: ControlsOverlay.didUpdateWidget 切换 listener 后同步当前值
- [ ] **CB-06e**: ProgressBar._cachedCustomPaint 加 doc comment 说明缓存语义
- [ ] **CB-06f**: 手动验收 — resize 压测 5-10s 无抖动/闪隐，自动隐藏行为正确

## Out of Scope

| Feature | Reason |
|---------|--------|
| 新增按钮/功能 | 仅微调 |
| 浅色主题 | v2+ |
| AutoHideController 状态机重构 | 已完善，仅调参 |
| PlayerActions 接口变更 | 架构重构 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CB-01a | Phase 1 | Pending |
| CB-01b | Phase 1 | Pending |
| CB-01c | Phase 1 | Pending |
| CB-02a | Phase 2 | Pending |
| CB-02b | Phase 2 | Pending |
| CB-02c | Phase 2 | Pending |
| CB-03a | Phase 3 | Pending |
| CB-03b | Phase 3 | Pending |
| CB-03c | Phase 3 | Pending |
| CB-04a | Phase 4 | Pending |
| CB-04b | Phase 4 | Pending |
| CB-04c | Phase 4 | Pending |
| CB-05a | Phase 5 | Pending |
| CB-05b | Phase 5 | Pending |

---
*Requirements defined: 2026-07-07*
