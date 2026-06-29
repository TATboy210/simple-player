# Simple Player Flutter — v1.6 Rendering Performance Optimization

## What This Is

针对 4K 视频播放场景的全面渲染性能优化，覆盖 fvp D3D11 瓶颈、渲染管线、Widget 层三个维度。

## Core Value

**4K 视频流畅播放** — CPU <15%、GPU <30%，窗口调整 120fps 无卡顿，启动到首帧 <500ms。

## Current State

### 已有优化基础

- D3D11 sync safe default (`d3d11.sync.cpu=1`)
- PositionPoller 自适应间隔 (100ms/250ms/1s)
- LRU 缩略图缓存
- Snapshot Debounce（已最优）
- `RepaintBoundary` 部分使用

### 关键瓶颈（来自 memory 分析）

| 瓶颈 | 文件 | 影响 |
|------|------|------|
| d3d11.sync.cpu | fvp 引擎 | CPU 等待 GPU fence |
| Flush 阻塞 | fvp 插件 | 主线程卡顿 |
| mutex 竞争 | fvp 插件 | 帧调度延迟 |
| CopyResource | D3D11 | 纹理拷贝开销 |
| Widget rebuild | player_screen | 不必要的重绘 |
| Opacity 动画 | 多个组件 | saveLayer 开销 |

### 技术债（CONCERNS.md）

- fvp_engine.dart 724 行（P0 待拆分）
- ~20 处 bang 操作符
- 硬编码颜色违反设计系统
- 全屏状态机竞态

## References

- `.planning/refactor/FVPENGINE-DECOMPOSITION.md` — 引擎拆分计划
- `.planning/codebase/CONCERNS.md` — 技术债清单
- Memory: `reference_fvp_performance_bottlenecks.md` — 9 个瓶颈排序
- Memory: `reference_fvp_optimization_plan.md` — 3 层优化方案
- Memory: `reference_rendering_pipeline_comparison.md` — 帧生命周期
