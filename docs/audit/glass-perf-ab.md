# 玻璃模糊性能 — 渲染后端取证与 A/B 度量协议 (v0.0.8.2)

> 目的：用数据裁决 Windows 渲染后端（Impeller vs Skia），并为毛玻璃优化
> （GlassBlurLayer 门控 / seek 挂起 / sigma 降档）提供前后对比证据。
> 背景：Flutter 3.47 起 Windows 默认启用 Impeller，但存在已知回归
> （#191353 变慢 / #191497 内存 450MB / #192918 BackdropFilter 擦内容）。

## 一、后端取证手段

1. **verbose 日志**（首选）：
   `flutter run -d windows --verbose 2>&1 | grep -iE "impeller|skia|vulkan|d3d|renderer"`
2. **反向确认**：加 `--no-enable-impeller` 再跑一次，日志 backend 行变化即证明先前档位
3. **GPU 档位**：`dxdiag` → 显示选项卡记录显卡型号与 D3D 特性级别——
   若为 **FL10_0 档，直接判 Skia**（命中 #192918 BackdropFilter 擦除内容）
4. release 对比用环境变量开关：`SIMPLER_PLAYER_FORCE_SKIA=1`（见 runner main.cpp）

## 二、场景矩阵（每后端 × 每场景 30s × 3 轮取中位数）

| 场景 | 内容 | 主要度量 |
|---|---|---|
| S1 | 播放静置（控制栏 auto-hide 隐藏） | baseline，blur 应近零 |
| S2 | 播放 + 控制栏常显（指针停栏内） | 控制栏 blur 每帧重算主场景 |
| S3 | 播放 + 播放列表开 + 拖窗 resize 3s×5 | 双玻璃叠加 + ResizeFrameMetrics 会话 |
| S4 | 播放 + 设置开 + 拖窗 resize 3s×5 | 同上 |
| S5 | 拖动进度条 5s | DevTools 帧图（C1 落地后对比挂起收益） |
| S6 | 纯 resize 拖拽（无面板） | ResizeFrameMetrics 原生覆盖 |

固定条件：窗口 1280×720、同一 1080p H.264 样本视频。
profile 构建采样（`flutter run -d windows --profile`）——debug 终端日志会污染帧时序；
profile 下 ResizeFrameMetrics 日志在 **DevTools Logging 面板**读（不进终端）。

## 三、指标

- `resize_frame_metrics` JSON：`rasterP95Us / rasterP99Us / rasterAvgUs / jank30Ratio`（S3/S4/S6）
- DevTools Performance 帧图 raster ms（S2/S5）
- MemoryMonitor RSS 30s 日志首末点 + 任务管理器 GPU 占用
- 记录：GPU 型号 / 驱动版本 / 后端档位 / Flutter 版本

## 四、后端切换判定标准（命中任一切 Skia）

1. S2-S4 任一场景 rasterP95 ≥ Skia 侧 1.3 倍，或绝对值 > 12ms（60fps 预算 72%）
2. RSS 稳态差 > 100MB（#191497 特征）
3. 出现 BackdropFilter 内容擦除/花屏（#192918）
4. 测试机 GPU 为 D3D11 FL10_0 档

全部不命中且 Impeller raster 更优 → 维持 Default（Impeller）。

## 五、前后对比表（B/C/D 落地前后各采一轮）

| 场景 | 后端 | rasterP95(μs) 前→后 | rasterP99 前→后 | jank30Ratio 前→后 | RSS(MB) 前→后 | 备注 |
|---|---|---|---|---|---|---|
| S2 播放+控制栏 | | | | | | |
| S3 播放+播放列表+拖窗 | | | | | | |
| S4 播放+设置+拖窗 | | | | | | |
| S5 拖动进度 | | | | | | |

## 六、结论记录区

- 取证日期 / GPU / 后端默认档：_(待填)_
- A/B 数据摘要：_(待填)_
- 裁决：_(待填：锁 Skia / 维持 Impeller)_
- 依据：_(待填)_
