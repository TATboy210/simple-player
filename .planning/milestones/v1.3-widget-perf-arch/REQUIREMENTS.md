# Requirements: v1.3 Widget Performance & Architecture

**Defined:** 2026-06-22
**Core Value:** 在不改变外部行为的前提下，让 Widget 层代码更干净、更快、更易维护

## v1 Requirements

### Performance (PERF)

- [x] **PERF-05**: 全面 RepaintBoundary 审计 — 所有独立重绘区域添加 RepaintBoundary（ControlBar, VideoSurface, AuroraBackground, ProgressBar）
- [x] **PERF-06**: BackdropFilter resize 降级 — isResizing 期间完全跳过 BackdropFilter（不仅是 GlassContainer，也包括 popups/dialogs）
- [x] **PERF-07**: 静态 Paint cache — CustomPainter 中的 Paint 对象改为 static final，避免每帧重建
- [x] **PERF-08**: Ticker 生命周期优化 — AuroraBackground 和动画在引擎非 idle/窗口 resize/应用后台时暂停
- [x] **PERF-09**: ValueNotifier rebuild 减少 — 审计嵌套 VLB，合并可合并的 ValueNotifier（如 _MergedListenable 模式）
- [x] **PERF-10**: OverlayEntry 性能 — VolumeSlider/SpeedButton popup 使用 const widget、避免不必要的 setState

### Architecture (ARCH)

- [x] **ARCH-04**: PlayerActions record typedef — 定义 record 替代 PlayerScreen/ControlsOverlay 的 15+ 散落回调参数
- [x] **ARCH-05**: PlayerActions 传播 — PlayerScreen → ControlsOverlay → ControlBar 全链路使用 PlayerActions
- [x] **ARCH-06**: 目录重组 — 按功能域对齐：player/, playlist/, dialogs/, input/, window/, shared/, theme/

### Cleanup (CLEAN)

- [x] **CLEAN-01**: keyboard_handler.dart 去重 — 合并重复版本，保留单一位置
- [x] **CLEAN-02**: drop_handler.dart 去重 — 合并重复文件
- [x] **CLEAN-03**: custom_title_bar.dart 去重 — 合并重复文件
- [x] **CLEAN-04**: path_validator.dart 去重 — 合并 lib/kernel/utils/ 和 lib/kernel/services/ 版本
- [x] **CLEAN-05**: import 路径更新 — 目录重组后全量更新 import 语句

## Out of Scope

| Feature | Reason |
|---------|--------|
| app.dart 拆分 | 改动面大，需单独 milestone 规划 |
| DI 迁移（6 单例→注入）| 风险高，deferred to v1.4+ |
| 新增缺失组件 | 功能性变更，不在优化范畴 |
| ControlBar 子组件拆分 | 当前结构可接受 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PERF-05 | Phase 1 | ✅ Done |
| PERF-06 | Phase 1 | ✅ Done |
| PERF-07 | Phase 1 | ✅ Done |
| PERF-08 | Phase 2 | ✅ Done |
| PERF-09 | Phase 2 | ✅ Done |
| PERF-10 | Phase 2 | ✅ Done |
| ARCH-04 | Phase 3 | ✅ Done |
| ARCH-05 | Phase 3 | ✅ Done |
| ARCH-06 | Phase 4 | ✅ Done |
| CLEAN-01 | Phase 4 | ✅ Done |
| CLEAN-02 | Phase 4 | ✅ Done |
| CLEAN-03 | Phase 4 | ✅ Done |
| CLEAN-04 | Phase 4 | ✅ Done |
| CLEAN-05 | Phase 4 | ✅ Done |

**Coverage:** 14 requirements, 14 mapped, 0 unmapped ✓

---
*Requirements defined: 2026-06-22*
