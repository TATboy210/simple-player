/// Fact-Forcing Gate Context:
/// - Importers: /gsd-new-project, /gsd-plan-phase workflows
/// - Affected API: REQUIREMENTS.md project requirements tracking
/// - Data schema: Markdown requirements with checkboxes
/// - User verbatim: "视频播放区域除开上标题栏是16比9，包括控制栏在内16比9比例，然后播放16比9视频时视频直接铺满画面即可，然后调整窗口大小，允许有黑边，不能裁切画面，然后优化播放视频时调整窗口会卡顿的问题"

# Video Area 16:9 Ratio Optimization — Requirements

## User Stories

**As a** 播放器用户, **I want** 视频播放区域保持 16:9 比例, **so that** 播放 16:9 视频时画面铺满，调整窗口时有黑边但不裁切。

## Requirements

### R1: 16:9 比例约束

- [ ] **R1-1**: 视频播放区域（标题栏+视频+控制栏）整体保持 16:9 比例
- [ ] **R1-2**: 窗口调整大小时，视频区域自动居中
- [ ] **R1-3**: 视频区域超出窗口时，显示黑色背景

### R2: 视频显示

- [ ] **R2-1**: 16:9 视频铺满视频区域
- [ ] **R2-2**: 非 16:9 视频保持原始比例，黑边填充
- [ ] **R2-3**: 视频不能被裁切

### R3: 性能优化

- [ ] **R3-1**: 窗口调整时流畅无卡顿
- [ ] **R3-2**: 使用 RepaintBoundary 隔离重绘区域
- [ ] **R3-3**: 优化 Texture 重绘逻辑

### R4: 兼容性

- [ ] **R4-1**: 全屏模式正常工作
- [ ] **R4-2**: 最大化模式正常工作
- [ ] **R4-3**: 控制栏正常显示和交互
- [ ] **R4-4**: 播放列表面板正常显示

## Technical Approach

### 布局结构

```dart
Column
├── CustomTitleBar (固定高度 32dp)
└── Expanded
    └── ColoredBox(
        color: Colors.black,  // 黑色背景
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack
                ├── VideoSurface
                ├── ControlsOverlay
                └── EmptyState
          )
        )
      )
```

### 视频渲染策略

- **16:9 视频**: `BoxFit.fill` 铺满视频区域
- **非 16:9 视频**: `BoxFit.contain` 保持比例

### 性能优化策略

1. **RepaintBoundary**: 在视频区域外层包裹 RepaintBoundary
2. **缓存动画**: 使用 AnimatedBuilder 缓存窗口尺寸变化
3. **防抖更新**: 窗口调整时使用防抖减少重绘频率

## Files to Modify

| File | Changes |
|------|---------|
| `lib/ui/player/player_screen.dart` | 布局重构，添加 AspectRatio 约束 |
| `lib/ui/player/video_surface.dart` | 视频渲染优化 |
| `lib/ui/player/controls_overlay.dart` | 控制栏布局调整 |
| `lib/ui/theme/tokens.dart` | 新增 16:9 相关常量 |

## Success Criteria

- [ ] 视频区域始终保持 16:9 比例
- [ ] 16:9 视频铺满画面
- [ ] 非 16:9 视频有黑边但不裁切
- [ ] 窗口调整流畅无卡顿
- [ ] 所有现有测试通过

## Out of Scope

- 自定义比例（4:3, 21:9 等）
- 视频旋转
- 画中画模式

---
*Created: 2026-06-25*
