# Phase 3: D3D11 瓶颈优化 — 执行计划

**目标**: 减少 D3D11 渲染管线的 CPU 等待和 GPU 色彩转换开销
**依赖**: Phase 2（渲染管线优化已完成）
**需求**: R3-1, R3-2, R3-3
**风险**: 中（涉及解码器配置和 CPU-GPU 同步策略）

## 成功标准

| 需求 | 标准 | 验证方式 |
|------|------|----------|
| R3-1 | shader_resource=1 启用 GPU 色彩转换 | 代码审查 + 手动验证 |
| R3-2 | d3d11.sync.cpu=0 异步模式测试 | 手动验证（撕裂检测） |
| R3-3 | 解码器链更新为 D3D11:shader_resource=1 | 代码审查 |
| 总体 | 4K 播放 CPU 占用下降 | DevTools CPU Profiler |

## 架构决策

**D-04: 应用层优化优先（Tier 1）**
- 不 fork fvp，仅通过 `setProperty` 调整 MDK 配置
- 所有改动可回滚（单行配置变更）
- 风险最低，收益可量化

**D-05: shader_resource=1 启用 GPU 色彩转换**
- 当前 `shader_resource=0` 禁用 GPU 色彩转换，YUV→RGB 在 CPU 完成
- 启用后 YUV→RGB 转换在 GPU 完成，减少 CPU 负担和内存带宽
- 风险: 某些旧显卡驱动可能不兼容，会自动回退

**D-06: d3d11.sync.cpu 按显示器刷新率自适应**
- 已有 `DisplayConfig.d3d11SyncMode()` 逻辑（60Hz=1, 120Hz+=0）
- 确认高刷屏使用异步模式，低刷屏保持同步

---

## Task 1: 启用 GPU 色彩转换 (shader_resource=1)

**文件**:
- `lib/kernel/engine/fvp_engine.dart` (724 行) — 主改动

**改动详情**:

### fvp_engine.dart

1. 修改 `_defaultVideoDecoders` 常量（第 46 行）:
   ```dart
   // Before:
   static const _defaultVideoDecoders = 'D3D11,NVDEC,FFmpeg';
   
   // After:
   static const _defaultVideoDecoders = 'D3D11:shader_resource=1,NVDEC,FFmpeg';
   ```

2. 在 `_applyD3d11Defaults()` 方法中（第 143 行后）添加:
   ```dart
   // shader_resource: 启用 GPU 色彩空间转换
   //   YUV→RGB 转换在 GPU 完成，减少 CPU 负担
   p.setProperty('video.shader', '1');
   ```

**测试**:
- `test/kernel/engine/fvp_engine_test.dart` — 验证解码器配置包含 shader_resource

**验证**: `flutter test test/kernel/engine/fvp_engine_test.dart`

---

## Task 2: 验证 d3d11.sync.cpu 异步模式

**文件**:
- `lib/kernel/bridge/display_config.dart` — 确认逻辑正确

**改动详情**:

这是验证任务，不修改代码。确认:
1. `DisplayConfig.d3d11SyncMode()` 在 120Hz+ 显示器返回 '0'
2. `FvpEngine._applyD3d11Defaults()` 正确调用此方法
3. 手动测试: 在 120Hz 显示器上播放 4K 视频，观察是否有撕裂

**验证**: 代码审查 + 手动测试

---

## Task 3: 日志级别优化

**文件**:
- `lib/kernel/engine/engine_prewarm.dart` (72 行) — 添加全局日志配置

**改动详情**:

### engine_prewarm.dart

在 `prewarm()` 方法中，创建 player 后立即设置日志级别:
```dart
// 在 player = mdk.Player() 后添加:
player.setProperty('log', 'warning');  // 只输出警告和错误
```

**预期收益**: 减少字符串格式化和 I/O 开销

---

## 执行顺序

```
Task 1 (GPU 色彩转换) ──→ Task 3 (日志级别)
Task 2 (验证 async 模式) — 独立验证任务
```

---

## 风险缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| shader_resource=1 旧驱动不兼容 | 低 | 中 | MDK 会自动回退到 CPU 色彩转换 |
| d3d11.sync.cpu=0 出现撕裂 | 中 | 中 | 仅在 120Hz+ 显示器启用，60Hz 保持同步 |
| GPU 色彩转换质量差异 | 低 | 低 | GPU 和 CPU 转换结果视觉上无差异 |

---

## 验证计划

### 自动化验证

```bash
# 单元测试
flutter test test/kernel/engine/fvp_engine_test.dart

# 全量回归
flutter test
```

### 手动验证

1. **GPU 色彩转换**
   - 打开 4K 视频播放
   - 观察 CPU 占用是否下降
   - 检查画面颜色是否正确（无偏色）

2. **异步模式**
   - 在 120Hz 显示器上播放
   - 快速拖拽窗口，观察是否有撕裂
   - 如果有撕裂，回退到同步模式

3. **日志优化**
   - 播放视频时观察控制台输出
   - 确认只有警告和错误日志

---

## Phase Gate（阻塞完成）

**必须在 Phase 3 完成前通过:**

1. **CPU 测量** — DevTools CPU Profiler 确认 4K 播放 CPU 占用下降
2. **画面质量** — GPU 色彩转换后画面颜色正确（无偏色）
3. **全量测试** — `flutter test` 全部通过
4. **撕裂检测** — 120Hz 显示器无可见撕裂（或确认回退到同步模式）

**如果 CPU 占用未下降:**
- 检查 shader_resource=1 是否生效
- 检查 d3d11.sync.cpu 是否正确设置
- 考虑是否需要进一步调优解码器参数

---

## 输出

完成后创建 `.planning/phases/3-d3d11-bottleneck/SUMMARY.md`
