# v1.6 Rendering Performance — Roadmap

## Overview

**4 phases** | **15 requirements mapped** | All requirements covered ✓

| # | Phase | Goal | Requirements | Risk |
|---|-------|------|--------------|------|
| 1 | Widget 层优化 | 低成本高收益的 UI 层优化 | R3-1~R3-5 | 低 |
| 2 | 渲染管线优化 | 帧调度和纹理路径优化 | R2-1~R2-4 | 中 |
| 3 | fvp D3D11 瓶颈 | 引擎层性能突破 | R1-1~R1-4 | 高 |
| 4 | 启动优化 | 首帧时间 <500ms | R4-1~R4-3 | 中 |

**策略：** Phase 1 先做（低风险、立竿见影），Phase 2-3 可并行（独立领域），Phase 4 收尾。

---

### Phase 1: Widget 层优化

**Goal:** 消除不必要的 rebuild 和 saveLayer，窗口调整 120fps

**Requirements:** R3-1, R3-2, R3-3, R3-4, R3-5

**Tasks:**
1. PlayerScreen 添加 RepaintBoundary 分离视频/控制栏/播放列表
2. AuroraBackground Ticker 在 paused 状态暂停
3. 全局搜索 Opacity widget → AnimatedOpacity/FadeTransition
4. 审查 ValueListenableBuilder 绑定粒度
5. 硬编码颜色迁移到 Tokens.*

**验证:** 窗口调整时 DevTools Timeline 显示 120fps

---

### Phase 2: 渲染管线优化

**Goal:** 减少非关键更新对渲染管线的干扰

**Requirements:** R2-1, R2-2, R2-3, R2-4

**Tasks:**
1. PositionPoller：resize 期间暂停轮询
2. Snapshot Debounce 策略验证和调整
3. Texture 零拷贝路径确认（fvp 源码验证）
4. resize 期间暂停 OSD/进度条更新

**验证:** resize 期间 CPU 占用下降 >30%

---

### Phase 3: fvp D3D11 瓶颈

**Goal:** 突破引擎层性能瓶颈，GPU 占用 <30%

**Requirements:** R1-1, R1-2, R1-3, R1-4

**Tasks:**
1. `d3d11.sync.cpu=0` 实验（120Hz 稳定性测试）
2. Flush 频率优化（评估批量提交可行性）
3. UpdateSubresource 直写实验
4. FvpEngine 拆分（配合 FVPENGINE-DECOMPOSITION.md）

**风险:** 引擎层修改可能影响播放稳定性，需要 A/B 测试

**验证:** 4K 视频 GPU 占用 <30%

---

### Phase 4: 启动优化

**Goal:** 启动到首帧 <500ms

**Requirements:** R4-1, R4-2, R4-3

**Tasks:**
1. FvpEngine 延迟初始化（仅加载纹理渲染，其余懒加载）
2. engine_prewarm 效果验证
3. StartupCoordinator 阶段并行化评估

**验证:** 冷启动到首帧 <500ms（3 次取平均）
