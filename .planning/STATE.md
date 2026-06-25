/// Fact-Forcing Gate Context:
/// - Importers: /gsd-new-project, /gsd-resume-work workflows
/// - Affected API: STATE.md project state tracking
/// - Data schema: YAML frontmatter + markdown phases table
/// - User verbatim: "视频播放区域除开上标题栏是16比9，包括控制栏在内16比9比例，然后播放16比9视频时视频直接铺满画面即可，然后调整窗口大小，允许有黑边，不能裁切画面，然后优化播放视频时调整窗口会卡顿的问题"

---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Video Area 16:9 Ratio Optimization
status: implementing
last_updated: "2026-06-25T23:30:00.000Z"
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 1
  completed_plans: 1
  percent: 25
---

# Project State: Video Area 16:9 Ratio Optimization

## Summary

优化视频播放区域的 16:9 比例显示，解决窗口调整时的卡顿问题。

## Requirements

### 核心需求

1. **16:9 比例约束**：视频播放区域（标题栏+视频+控制栏）整体保持 16:9 比例
2. **16:9 视频铺满**：播放 16:9 视频时，视频直接铺满画面
3. **允许黑边**：调整窗口大小时允许有黑边，不能裁切画面
4. **性能优化**：优化播放视频时调整窗口会卡顿的问题

### 当前实现分析

#### 布局结构
```
Column
├── CustomTitleBar (固定高度 32dp)
└── Expanded (填充剩余空间) ← 问题：没有 16:9 约束
    └── Stack
        ├── VideoSurface (BoxFit.contain)
        ├── EmptyState
        └── ControlsOverlay
```

#### 问题
1. **比例问题**：Expanded 会填充所有空间，不保持 16:9
2. **卡顿问题**：窗口调整时频繁重绘 Texture

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 1. 布局重构 | 使用 AspectRatio 约束视频区域 | ✅ |
| 2. 黑边处理 | 窗口超出时显示黑边 | ✅ (Phase 1 已包含) |
| 3. 视频铺满 | 16:9 视频铺满视频区域 | ✅ (Phase 1 已包含) |
| 4. 性能优化 | 优化窗口调整时的卡顿 | ⏳ |

## Technical Approach

### Phase 1: 布局重构

```dart
// 目标布局
Column
├── CustomTitleBar (固定高度 32dp)
└── Expanded
    └── Center
        └── AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack
                ├── VideoSurface
                ├── ControlsOverlay
                └── EmptyState
          )
```

### Phase 2: 黑边处理

- 窗口比例不是 16:9 时，视频区域居中
- 超出部分显示黑色背景

### Phase 3: 视频铺满

- 16:9 视频：BoxFit.fill 铺满视频区域
- 非 16:9 视频：BoxFit.contain 保持比例

### Phase 4: 性能优化

- 使用 RepaintBoundary 隔离重绘区域
- 优化 Texture 重绘逻辑
- 使用 AnimatedBuilder 缓存动画

## Files to Modify

- `lib/ui/player/player_screen.dart` — 布局重构
- `lib/ui/player/video_surface.dart` — 视频渲染优化
- `lib/ui/player/controls_overlay.dart` — 控制栏布局
- `lib/ui/theme/tokens.dart` — 新增 16:9 相关常量

## Success Criteria

- [ ] 视频区域始终保持 16:9 比例
- [ ] 16:9 视频铺满画面
- [ ] 非 16:9 视频有黑边但不裁切
- [ ] 窗口调整流畅无卡顿
- [ ] 所有现有测试通过

---
*Created: 2026-06-25*
