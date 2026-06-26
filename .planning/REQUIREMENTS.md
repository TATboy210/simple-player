# v1.6 Rendering Performance Optimization — Requirements

## User Stories

**As a** 4K 视频用户, **I want** 播放时 CPU/GPU 占用低且窗口调整流畅, **so that** 不影响其他应用同时运行。

## Performance Targets

| 指标 | 当前值 | 目标值 | 测量方法 |
|------|--------|--------|----------|
| 4K CPU 占用 | ~25% | <15% | Task Manager |
| 4K GPU 占用 | ~45% | <30% | GPU-Z / DevTools |
| 窗口调整 fps | ~45fps | 120fps | Timeline tracing |
| 启动到首帧 | ~800ms | <500ms | Stopwatch |

## Requirements

### R1: fvp D3D11 瓶颈优化

- [ ] **R1-1**: 评估 `d3d11.sync.cpu=0`（async mode）在 120Hz 显示器上的稳定性
- [ ] **R1-2**: 减少 Flush 阻塞频率（批量提交 vs 逐帧 Flush）
- [ ] **R1-3**: 纹理更新路径优化（CopyResource → UpdateSubresource 直写）
- [ ] **R1-4**: FvpEngine 拆分（724→<300 行），提取 MediaOpener、D3D11Configurator 等

### R2: 渲染管线优化

- [ ] **R2-1**: PositionPoller 自适应策略优化（视频播放时降低频率）
- [ ] **R2-2**: Snapshot Debounce 与窗口 resize 事件解耦
- [ ] **R2-3**: Texture 更新零拷贝路径验证（fvp 已优化，确认无额外拷贝）
- [ ] **R2-4**: 帧调度：resize 期间暂停非关键更新（进度条、OSD）

### R3: Widget 层优化

- [ ] **R3-1**: PlayerScreen RepaintBoundary 隔离（视频/控制栏/播放列表分离）
- [ ] **R3-2**: AuroraBackground Ticker 在 paused 状态暂停
- [ ] **R3-3**: Opacity 动画 → AnimatedOpacity 或 FadeTransition（避免 saveLayer）
- [ ] **R3-4**: ValueListenableBuilder 精确绑定（避免父级 rebuild）
- [ ] **R3-5**: 硬编码颜色 → Tokens.*（减少 theme rebuild 影响范围）

### R4: 启动优化

- [ ] **R4-1**: FvpEngine 延迟初始化（首帧后再初始化完整引擎）
- [ ] **R4-2**: fvp 预热策略（engine_prewarm 验证有效性）
- [ ] **R4-3**: StartupCoordinator 阶段并行化

## Definition of Done

- [ ] 4K 视频播放 CPU <15%、GPU <30%
- [ ] 窗口调整 120fps 无卡顿
- [ ] 启动到首帧 <500ms
- [ ] 所有现有测试通过
- [ ] 新增性能基准测试
