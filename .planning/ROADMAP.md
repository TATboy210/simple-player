/// Fact-Forcing Gate Context:
/// - Importers: /gsd-new-project, /gsd-plan-phase workflows
/// - Affected API: ROADMAP.md project roadmap tracking
/// - Data schema: Markdown phases with requirements mapping
/// - User verbatim: "视频播放区域除开上标题栏是16比9，包括控制栏在内16比9比例，然后播放16比9视频时视频直接铺满画面即可，然后调整窗口大小，允许有黑边，不能裁切画面，然后优化播放视频时调整窗口会卡顿的问题"

# Video Area 16:9 Ratio Optimization — Roadmap

## Overview

**4 phases** | **12 requirements mapped** | All requirements covered ✓

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | 布局重构 | 使用 AspectRatio 约束视频区域 | R1-1, R1-2, R1-3 | 3 |
| 2 | 视频显示 | 16:9 视频铺满，非 16:9 黑边 | R2-1, R2-2, R2-3 | 3 |
| 3 | 性能优化 | 窗口调整流畅无卡顿 | R3-1, R3-2, R3-3 | 3 |
| 4 | 兼容性 | 全屏/最大化/控制栏正常 | R4-1, R4-2, R4-3, R4-4 | 4 |

---

### Phase 1: 布局重构

**Goal:** 使用 AspectRatio 约束视频区域，使其保持 16:9 比例

**Mode:** mvp

**Requirements:**
- R1-1: 视频播放区域（标题栏+视频+控制栏）整体保持 16:9 比例
- R1-2: 窗口调整大小时，视频区域自动居中
- R1-3: 视频区域超出窗口时，显示黑色背景

**Success Criteria:**
1. 视频区域始终保持 16:9 比例
2. 窗口调整时视频区域自动居中
3. 超出部分显示黑色背景

**Key Files:**
- `lib/ui/player/player_screen.dart` — 布局重构

**Implementation:**
```dart
// 当前布局
Column
├── CustomTitleBar
└── Expanded ← 问题：没有 16:9 约束
    └── Stack [VideoSurface, ControlsOverlay]

// 目标布局
Column
├── CustomTitleBar
└── Expanded
    └── ColoredBox(color: Colors.black)
        └── Center
            └── AspectRatio(16/9)
                └── Stack [VideoSurface, ControlsOverlay]
```

---

### Phase 2: 视频显示

**Goal:** 16:9 视频铺满视频区域，非 16:9 视频保持比例

**Mode:** mvp

**Requirements:**
- R2-1: 16:9 视频铺满视频区域
- R2-2: 非 16:9 视频保持原始比例，黑边填充
- R2-3: 视频不能被裁切

**Success Criteria:**
1. 16:9 视频铺满画面
2. 非 16:9 视频有黑边但不裁切
3. 视频始终保持原始比例

**Key Files:**
- `lib/ui/player/video_surface.dart` — 视频渲染策略

**Implementation:**
```dart
// 视频渲染策略
BoxFit get videoFit {
  final videoRatio = engine.aspectRatio.value;
  final isStandard = (videoRatio - 16/9).abs() < 0.01;
  return isStandard ? BoxFit.fill : BoxFit.contain;
}
```

---

### Phase 3: 性能优化

**Goal:** 优化窗口调整时的卡顿问题

**Mode:** mvp

**Requirements:**
- R3-1: 窗口调整时流畅无卡顿
- R3-2: 使用 RepaintBoundary 隔离重绘区域
- R3-3: 优化 Texture 重绘逻辑

**Success Criteria:**
1. 窗口调整流畅无卡顿
2. 使用 RepaintBoundary 隔离重绘区域
3. Texture 重绘优化

**Key Files:**
- `lib/ui/player/video_surface.dart` — Texture 渲染优化
- `lib/ui/player/player_screen.dart` — RepaintBoundary 包裹

**Implementation:**
```dart
// RepaintBoundary 隔离
RepaintBoundary(
  child: AspectRatio(
    aspectRatio: 16 / 9,
    child: Stack [...]
  )
)
```

---

### Phase 4: 兼容性

**Goal:** 确保全屏、最大化、控制栏等功能正常工作

**Mode:** mvp

**Requirements:**
- R4-1: 全屏模式正常工作
- R4-2: 最大化模式正常工作
- R4-3: 控制栏正常显示和交互
- R4-4: 播放列表面板正常显示

**Success Criteria:**
1. 全屏模式正常工作
2. 最大化模式正常工作
3. 控制栏正常显示和交互
4. 播放列表面板正常显示

**Key Files:**
- `lib/ui/player/player_screen.dart` — 全屏/最大化处理
- `lib/ui/player/controls_overlay.dart` — 控制栏布局
- `lib/ui/playlist/playlist_panel.dart` — 播放列表

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| R1-1 | 1 | Pending |
| R1-2 | 1 | Pending |
| R1-3 | 1 | Pending |
| R2-1 | 2 | Pending |
| R2-2 | 2 | Pending |
| R2-3 | 2 | Pending |
| R3-1 | 3 | Pending |
| R3-2 | 3 | Pending |
| R3-3 | 3 | Pending |
| R4-1 | 4 | Pending |
| R4-2 | 4 | Pending |
| R4-3 | 4 | Pending |
| R4-4 | 4 | Pending |

---
*Created: 2026-06-25*
