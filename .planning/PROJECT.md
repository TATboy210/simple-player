# Control Bar Polish

## What This Is

控制栏（ControlBar）微调优化项目 — 在不改变现有功能的前提下，优化控制栏的视觉效果和交互体验。目标是让控制栏在播放视频时既能响应用户操作又不遮挡观看，同时提升毛玻璃质感、按钮交互反馈和布局紧凑度。

## Core Value

**沉浸式观看体验** — 控制栏在播放状态下"隐形但可用"，用户需要时立即响应，不需要时完全不干扰视频内容。

## Requirements

### Validated

- ✓ 控制栏 3 行布局（标题/进度条/按钮）— Phase 22-27
- ✓ 自动隐藏状态机（idle/playing/paused/hidden）— Phase 22-27
- ✓ 响应式 3 级断点（360/500/默认）— Phase 22-27
- ✓ 毛玻璃 BackdropFilter + 跳过优化 — Phase 22-27
- ✓ 15+ GlassButton 按钮组（左/中/右）— Phase 22-27

### Active

- [x] **CB-01**: 控制栏渐隐渐显动画优化 — 播放状态下自动隐藏/显示的过渡更加平滑自然
- [x] **CB-02**: 毛玻璃模糊强度 +15% — 提升 glassBlur 从 10→12（或等效调整）
- [x] **CB-03**: 按钮 hover 高亮区域优化 — 更显眼的 hover 反馈 + 更紧凑的高亮区域 + 不与控制栏边框重叠
- [x] **CB-04**: 控制栏垂直压缩 — 评估上/中/下 3 行是否可以进一步压缩高度
- [x] **CB-05**: 移除控制栏底部辉光 — 删除 TransmittedLight 效果
- [x] **CB-06**: Resize 接线修复 — ControlBar→ProgressBar 透传 + AutoHideController 同步（P0 bug fix）

### Out of Scope

| Feature | Reason |
|---------|--------|
| 新增按钮/功能 | 本次仅微调现有 UI，不扩展功能 |
| 浅色主题 | Deferred to v2+ |
| 按钮插件化架构 | Deferred to v2+ |
| PlayerActions 拆分 | 架构重构，非微调范围 |
| InheritedWidget 重构 | 架构重构，非微调范围 |

## Context

### 当前控制栏架构

- **12 个核心文件**，~2578 行代码
- **3 行布局**：Row 1 标题+时间 / Row 2 ProgressBar / Row 3 按钮组
- **3 行等分**：Expanded × 3，每行占 1/3 高度（110px / 3 ≈ 36.7px）
- **毛玻璃**：GlassTier.normal = 10 sigma，GlassTier.thin = 8 sigma
- **自动隐藏**：窗口 5s / 全屏 3s 无操作后隐藏，300ms fade 动画（Curves.easeOut）
- **底部辉光**：TransmittedLight(type: bottom, intensity: 0.6) 在 controls_overlay.dart:225-235

### VLC/mpv 参考行为

- VLC 默认 fadetime = 500ms（比当前 300ms 更平滑）
- VLC 使用 CTRL_ID_VISIBLE 事件驱动显示/隐藏切换
- mpv 的 OSC（On Screen Controller）采用类似策略：播放时自动隐藏，鼠标移动时显示
- 业界标准：fade 动画 300-500ms，隐藏延迟 3-5s

### 现有 Token 值

- controlBarHeight = 110.0
- glassBlur = 10.0（控制栏使用 GlassTier.normal）
- glassBlurThin = 8.0
- durationFade = 300ms（AutoHide 动画时长）
- hideDelayWindowed = 5s
- hideDelayFullscreen = 3s

## Constraints

- **功能不变**: 所有现有按钮、快捷键、手势保持不变
- **性能不退化**: BackdropFilter 跳过优化、RepaintBoundary 隔离必须保留
- **设计系统**: 所有视觉值通过 Tokens.* 管理
- **向后兼容**: 不改变 PlayerActions/EngineState 接口

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 渐隐渐显仅调整动画参数，不改状态机 | AutoHideController 状态机已完善，仅需调优时长/曲线 | Pending |
| 毛玻璃 +15% 通过调整 sigma 值 | 最小改动，GlassTier 已有缓存机制 | Pending |
| 按钮 hover 通过 InkWell 参数调整 | 不改 GlassButton 架构，仅调色值和区域 | Pending |
| 底部辉光直接移除 TransmittedLight | 最简单删除，不影响其他组件 | Pending |

---
*Created: 2026-07-07*
*Last updated: 2026-07-07 after initial creation*
