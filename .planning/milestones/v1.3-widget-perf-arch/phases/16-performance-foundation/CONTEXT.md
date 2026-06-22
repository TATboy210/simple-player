# Phase 16: Performance Foundation — RepaintBoundary & BackdropFilter

## Goal

关键渲染路径添加 RepaintBoundary，resize 期间完全跳过 BackdropFilter，CustomPainter Paint 对象缓存为 static final

## Requirements

- **PERF-05**: 全面 RepaintBoundary 审计 — ControlBar, VideoSurface, AuroraBackground, ProgressBar
- **PERF-06**: BackdropFilter resize 降级 — isResizing 期间完全跳过 BackdropFilter（包括 popups/dialogs）
- **PERF-07**: 静态 Paint cache — CustomPainter 中 Paint 对象改为 static final

## Success Criteria

1. ControlBar, VideoSurface, AuroraBackground, ProgressBar 均有 RepaintBoundary 包裹
2. isResizing 期间所有 BackdropFilter 跳过（包括 popup/dialog）
3. CustomPainter 的 Paint 对象改为 static final
4. 现有测试全部通过，无帧率回归

## Constraints

- 不改变外部行为
- 不引入新依赖
- ValueNotifier + VLB 模式不变
- GlassContainer 3-tier blur 逻辑不变

## Out of Scope

- Ticker 生命周期（Phase 17）
- VLB 合并（Phase 17）
- OverlayEntry 优化（Phase 17）
- PlayerActions 重构（Phase 18）
- 目录重组（Phase 19）
