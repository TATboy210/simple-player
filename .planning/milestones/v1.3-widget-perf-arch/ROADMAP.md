# Roadmap: v1.3 Widget Performance & Architecture

**Milestone Goal:** Widget 层性能全面优化 + 架构清理 + 代码去重

## Phases

### Phase 16: Performance Foundation — RepaintBoundary & BackdropFilter
**Goal:** 关键渲染路径添加 RepaintBoundary，resize 期间完全跳过 BackdropFilter
**Mode:** mvp
**Requirements**: PERF-05, PERF-06, PERF-07
**Success Criteria**:
1. ControlBar, VideoSurface, AuroraBackground, ProgressBar 均有 RepaintBoundary 包裹
2. isResizing 期间主 widget 树中所有 BackdropFilter 跳过（GlassContainer, ControlBar, PlaylistPanel）。Dialog 为模态 overlay，resize 期间不会打开，不在范围内
3. CustomPainter 的 Paint 对象改为 static final
4. 现有测试全部通过，无帧率回归

**Plans:** 2 plans (parallel)
- 16-01: RepaintBoundary 全面审计 + 添加
- 16-02: BackdropFilter resize 降级 + Paint cache

### Phase 17: Performance Deep — Ticker & ValueNotifier
**Goal:** Ticker 生命周期智能暂停，减少不必要的 VLB rebuild
**Mode:** mvp
**Requirements**: PERF-08, PERF-09, PERF-10
**Success Criteria**:
1. AuroraBackground Ticker 在引擎非 idle/resize/后台时暂停
2. 嵌套 VLB 审计完成，可合并的 ValueNotifier 已合并
3. OverlayEntry popup 使用 const widget，无不必要 setState
4. 内存使用无增长（ticker dispose 正确）

**Plans:** 2 plans (parallel)
- 17-01: Ticker 生命周期优化
- 17-02: VLB 审计 + OverlayEntry 优化

### Phase 18: Architecture — PlayerActions Record
**Goal:** 用类型安全的 record typedef 替代 callback drilling
**Mode:** mvp
**Requirements**: ARCH-04, ARCH-05
**Success Criteria**:
1. PlayerActions record typedef 定义完成，包含所有回调
2. PlayerScreen 参数从 15+ VoidCallback 减至 1 个 PlayerActions
3. ControlsOverlay 参数从 10+ VoidCallback 减至 1 个 PlayerActions
4. 全链路编译通过，所有交互行为不变

**Plans:** 1 plan
- 18-01: PlayerActions record 定义 + 全链路替换

### Phase 19: Cleanup — Dedup & Directory Reorg
**Goal:** 消除重复文件，目录按功能域重组
**Mode:** mvp
**Requirements**: ARCH-06, CLEAN-01~05
**Success Criteria**:
1. 4 个重复文件合并为单一位置
2. 目录结构对齐功能域
3. 全量 import 路径更新，零编译错误
4. 所有测试通过

**Plans:** 2 plans (sequential)
- 19-01: 重复文件合并（4 files）
- 19-02: 目录重组 + import 更新

## Progress

| Phase | Requirements | Plans | Status |
|-------|-------------|-------|--------|
| 16. Performance Foundation | PERF-05,06,07 | 2 | ✅ Done |
| 17. Performance Deep | PERF-08,09,10 | 2 | ✅ Done |
| 18. PlayerActions Record | ARCH-04,05 | 1 | ✅ Done |
| 19. Dedup & Reorg | ARCH-06, CLEAN-01~05 | 2 | ✅ Done |

**Total:** 4 phases, 7 plans, 14 requirements

---
*Created: 2026-06-22*
