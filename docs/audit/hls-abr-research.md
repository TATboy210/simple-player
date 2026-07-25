# HLS ABR 自适应码率技术深度研究

> 研究日期: 2026-07-20
> 研究目的: 为 simple_player_flutter 项目提供 HLS ABR 技术方案
> 状态: 研究完成，待启动实现

---

## 目录

1. [HLS 协议原理](#1-hls-协议原理)
2. [ABR 算法对比](#2-abr-算法对比)
3. [MDK/FFmpeg 对 HLS 的支持](#3-mdkffmpeg-对-hls-的支持)
4. [现有代码分析](#4-现有代码分析)
5. [实现方案设计](#5-实现方案设计)
6. [实现路线图](#6-实现路线图)
7. [预期收益](#7-预期收益)

---

## 1. HLS 协议原理

### 1.1 协议概述

HLS (HTTP Live Streaming) 是 Apple 于 2009 年提出的基于 HTTP 的自适应码率流媒体协议。当前规范为 [RFC 8216](https://tools.ietf.org/html/rfc8216)，最新草案为 [draft-pantos-hls-rfc8216bis](https://tools.ietf.org/html/draft-pantos-hls-rfc8216bis)。

**核心思想**: 将视频流切割成一系列小的 HTTP 文件（分片），通过播放列表（Playlist）索引，客户端根据网络状况选择不同码率的分片下载。

### 1.2 Master Playlist 结构

Master Playlist 是 ABR 的入口，定义了所有可用的码率变体：

```m3u8
#EXTM3U
#EXT-X-VERSION:6

#EXT-X-STREAM-INF:BANDWIDTH=800000,AVERAGE-BANDWIDTH=750000,
  RESOLUTION=640x360,CODECS="avc1.64001e,mp4a.40.2",
  FRAME-RATE=30
low/playlist.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=2000000,AVERAGE-BANDWIDTH=1800000,
  RESOLUTION=1280x720,CODECS="avc1.640020,mp4a.40.2",
  FRAME-RATE=30
mid/playlist.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=5000000,AVERAGE-BANDWIDTH=4500000,
  RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2",
  FRAME-RATE=30
high/playlist.m3u8
```

### 1.3 Media Playlist 结构

每个变体对应一个 Media Playlist，定义分片列表：

```m3u8
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0

#EXTINF:5.005,
segment0.ts
#EXTINF:6.006,
segment1.ts
#EXTINF:5.505,
segment2.ts
#EXT-X-ENDLIST
```

### 1.4 关键标签说明

| 标签 | 用途 | ABR 相关性 |
|------|------|-----------|
| `#EXT-X-STREAM-INF` | 定义码率变体 | **核心** — BANDWIDTH, RESOLUTION, CODECS |
| `#EXT-X-TARGETDURATION` | 最大分片时长 | 重要 — 影响缓冲策略 |
| `#EXTINF` | 分片实际时长 | 重要 — 影响带宽计算 |
| `#EXT-X-MEDIA-SEQUENCE` | 分片序号 | 播放位置跟踪 |
| `#EXT-X-MAP` | 初始化分片 | fMP4 格式必需 |
| `#EXT-X-ENDLIST` | 直播/点播标识 | 直播流无此标签 |

### 1.5 LL-HLS (Low Latency HLS)

[LL-HLS 草案](https://tools.ietf.org/html/draft-pantos-hls-rfc8216bis) 引入的低延迟扩展：

- **Partial Segments**: 更小的分片单元，降低首帧延迟
- **Preload Hints** (`#EXT-X-PRELOAD-HINT`): 提示客户端预请求下一资源
- **Blocking Playlist Reload** (`CAN-BLOCK-RELOAD=YES`): 服务器持有请求直到有新内容
- **Rendition Reports** (`#EXT-X-RENDITION-REPORT`): 跨变体同步信息

**与 ABR 的关系**: LL-HLS 的 Partial Segments 使码率切换粒度更细（1-2秒 vs 6秒），但需要更精确的带宽估算。

### 1.6 分片格式

| 格式 | 特点 | ABR 影响 |
|------|------|---------|
| MPEG-TS (`.ts`) | 传统格式，每个分片独立 | 切换点清晰，但有 PAT/PMT 开销 |
| fMP4 (`.m4s`) | 现代格式，共享初始化段 | 更高效，但需要关键帧对齐 |

**关键帧对齐**: ABR 切换的关键前提 — 所有变体必须在相同时间点有关键帧（IDR 帧），否则切换时会出现花屏或解码错误。FFmpeg 的 `-hls_flags independent_segments` 确保每个分片以关键帧开头。

---

## 2. ABR 算法对比

### 2.1 算法分类

ABR 算法按决策信号可分为三大类：

```
┌─────────────────────────────────────────────────────┐
│                 ABR 算法分类                          │
├─────────────┬───────────────┬───────────────────────┤
│ Throughput- │ Buffer-based  │ Hybrid / Learning-    │
│ based       │               │ based                 │
├─────────────┼───────────────┼───────────────────────┤
│ 简单带宽估计 │ 缓冲区水位     │ 多信号融合             │
│ 反应快但震荡 │ 稳定但保守     │ 最优但复杂             │
├─────────────┼───────────────┼───────────────────────┤
│ 算法:       │ 算法:          │ 算法:                  │
│ - 简单阈值  │ - BBA         │ - MPC                 │
│ - 滑动窗口  │ - BOLA        │ - Pensieve (RL)       │
│ - EWMA      │ - BBA+        │ - Comyco              │
└─────────────┴───────────────┴───────────────────────┘
```

### 2.2 BBA (Buffer-Based Approach)

**论文**: Huang et al., *"A Buffer-based Approach to Rate Adaptation"*, [SIGCOMM 2014](https://dl.acm.org/doi/10.1145/2619239.2626296)

**核心思想**: 仅基于缓冲区水位选择码率，不依赖带宽估算。

**算法伪代码**:

```
function getQuality(bufferLevel):
    bufferMin = 0           // 安全下限
    bufferMax = MAX_BUFFER  // 例如 60 秒

    // 为每个码率计算缓冲阈值
    for i in 0..numBitrates:
        threshold[i] = bufferMin + (bufferMax - bufferMin) * reservation[i]

    // 选择最高满足阈值的码率
    for i in (numBitrates-1)..0:
        if bufferLevel >= threshold[i]:
            return bitrate[i]

    return bitrate[0]  // 最低码率兜底
```

**reservation 参数**: 将缓冲区间 [0, MAX_BUFFER] 按码率比例划分，高码率需要更高缓冲水位。

**优点**:
- 实现简单，计算开销极低
- 不依赖带宽估算，避免测速噪声
- 缓冲区天然平滑振荡

**缺点**:
- 对突发带宽变化反应慢（需等缓冲上升）
- 码率选择偏保守（Netflix 实测比最优低 10-15%）
- 直播流场景不适用（缓冲区小）

### 2.3 BOLA (Buffer Occupancy based Lyapunov Algorithm)

**论文**: Spiteri et al., *"BOLA: Near-Optimal Bitrate Adaptation for Online Videos"*, [IEEE INFOCOM 2016](https://arxiv.org/abs/1512.02696)

**核心思想**: 用 Lyapunov 优化理论，在缓冲稳定性约束下最大化 QoE。

**算法要点**:
- 定义 Lyapunov 函数 V(buffer) 衡量缓冲区偏移
- 每个决策周期最小化 drift-plus-penalty
- 证明了相对于离线最优的有界竞争比

**与 BBA 的区别**:
- BOLA 有理论最优性保证，BBA 是经验性的
- BOLA 的缓冲映射曲线更平滑
- BOLA 可扩展为 BOLA-O（加入带宽过载保护）

### 2.4 MPC (Model Predictive Control)

**论文**: Yin et al., *"A Control-Theoretic Approach for Dynamic Adaptive Video Streaming over HTTP"*, [SIGCOMM 2015](https://dl.acm.org/doi/10.1145/2785956.2787486)

**核心思想**: 在有限前瞻窗口内，预测未来吞吐量，求解最优码率序列。

**目标函数**:

```
maximize:
    Σ_{k=t}^{t+L} [ log(q_k) - λ * |q_k - q_{k-1}| ] - μ * Σ rebuffer_time_k

subject to:
    q_k ∈ {available bitrates}
    L = lookahead window (typically 5 chunks)
```

其中:
- `log(q_k)`: 码率效用（对数效用函数，高码率边际收益递减）
- `λ * |q_k - q_{k-1}|`: 码率切换惩罚
- `μ * rebuffer_time_k`: 重缓冲惩罚

**吞吐量预测**:

```
predicted_throughput = harmonic_mean(past_N_samples)
    = N / Σ (1 / sample_i)
```

使用调和平均而非算术平均，因为它对异常值更鲁棒（低带宽样本权重更大）。

**求解**: 对 5 个分片 × 4 个码率 = 1024 种组合穷举搜索，计算量可控。

**优点**:
- 综合考虑码率、平滑性、重缓冲三个维度
- 前瞻优化，避免贪心决策
- 学术界标准 baseline

**缺点**:
- 吞吐量预测不准确时性能下降显著
- 前瞻窗口有限（计算复杂度指数增长）
- 参数 λ, μ 需要调优

### 2.5 Pensieve (Reinforcement Learning)

**论文**: Mao et al., *"Pensieve: Reinforcement Learning for Adaptive Video Streaming"*, [SIGCOMM 2017](https://dl.acm.org/doi/10.1145/3098822.3098843)

**核心思想**: 用深度强化学习（A3C 算法）自动学习 ABR 策略，替代手工设计的算法。

**状态特征**:
- 过去 N 个分片的下载时间
- 过去 N 个分片的大小
- 当前缓冲区水位
- 当前可用码率列表
- 上一次选择的码率

**动作**: 选择下一个分片的码率

**奖励**: QoE 函数（同 MPC 的目标函数）

**结果**: 比 MPC 提升约 15-25% 的 QoE。

**优点**:
- 自动适应各种网络环境
- 无需手工调参
- 可持续学习优化

**缺点**:
- 需要训练数据和 GPU
- 推理延迟（神经网络前向传播）
- 可解释性差
- 桌面播放器场景训练数据有限

### 2.6 算法对比总结

| 维度 | BBA | BOLA | MPC | Pensieve |
|------|-----|------|-----|----------|
| **决策信号** | 缓冲区 | 缓冲区 | 缓冲区 + 带宽 | 缓冲区 + 带宽 + 历史 |
| **计算复杂度** | O(1) | O(n) | O(n^L) | O(inference) |
| **稳定性** | 高 | 高 | 中 | 中 |
| **QoE** | 中 | 中高 | 高 | 最高 |
| **实现难度** | 低 | 中 | 中高 | 高 |
| **直播适用性** | 差 | 差 | 中 | 中 |
| **参数调优** | 1 个 | 2 个 | 2 个 | 自动 |
| **适用场景** | 长视频、稳定网络 | 公平性要求高 | 通用 | 大规模部署 |

### 2.7 推荐方案

**分阶段实现**:

1. **Phase 1 (Baseline)**: Throughput-based — 简单滑动窗口测速，快速上线
2. **Phase 2 (优化)**: BBA — 基于缓冲区水位，稳定可靠
3. **Phase 3 (高级)**: Hybrid MPC — 带宽 + 缓冲 + 前瞻，最优 QoE
4. **Phase 4 (可选)**: Pensieve — 如果有足够训练数据和 GPU 资源

---

## 3. MDK/FFmpeg 对 HLS 的支持

### 3.1 FFmpeg HLS Demuxer 内置 ABR

FFmpeg 的 `libavformat/hls.c` 内置了基本的 ABR 支持：

**关键函数**:
- `hls_read_header()`: 初始码率选择（选择不超过 max_bitrate 的最高变体）
- `read_data()`: 运行时带宽测量
- `recheck_discard_flags()`: 变体切换决策

**内置算法**:
1. 初始选择: 选择 BANDWIDTH 最接近（但不超过）max_bitrate 的变体
2. 运行时适应: 测量实际下载速度 vs 分片时长，动态调整
3. 切换逻辑: 如果实际带宽持续高于/低于当前变体，切换到更高/更低码率

### 3.2 FFmpeg HLS Demuxer 配置选项

通过 `avformat.*` 属性传递给 FFmpeg：

| 属性 | 说明 | 默认值 | ABR 相关性 |
|------|------|--------|-----------|
| `avformat.hls_prefer_list` | 优先选择的码率列表 | 无 | **高** — 手动码率选择 |
| `avformat.hls_allowed_extensions` | 允许的文件扩展名 | ts,m3u8 | 安全配置 |
| `avformat.hls_segment_type` | 分片类型 (mpegts/fmp4) | mpegts | 格式选择 |
| `avformat.hls_flags` | HLS 行为标志 | 无 | 功能开关 |
| `avformat.hls_time` | 目标分片时长 | 6 | 分片策略 |
| `avformat.probesize` | 流探测大小 | 5MB | 启动速度 |
| `avformat.analyzeduration` | 流分析时长 | 5s | 启动速度 |
| `protocol_whitelist` | 允许的协议列表 | 无 | 安全配置 |

### 3.3 MDK Player 配置

MDK 通过 `setProperty()` 传递 FFmpeg 参数：

```dart
// 基础配置
player.setProperty('avformat.probesize', '1000000');  // 1MB
player.setProperty('avformat.analyzeduration', '5000000');  // 5s

// HLS 特定配置
player.setProperty('avformat.hls_prefer_list', '1080p:720p:480p');
player.setProperty('protocol_whitelist', 'file,http,https,tcp,tls,crypto');

// 缓冲配置
player.setProperty('demux.buffer.ranges', '3');  // 更大的缓冲区
player.setProperty('buffer', '5000000');  // 5MB 缓冲

// 不设置低延迟标志（与 ABR 冲突）
// 不设置 fflags +nobuffer
// 不设置 setBufferRange(drop: true)
```

### 3.4 关键矛盾：低延迟 vs ABR

当前 `NetworkConfigurator` 中的低延迟策略与 ABR 直接冲突：

| 配置项 | 低延迟值 | ABR 需要 | 冲突程度 |
|--------|---------|---------|---------|
| `fflags +nobuffer` | 所有实时流 | **不能设置** | **严重** |
| `setBufferRange(drop: true)` | 所有实时流 | **不能设置** | **严重** |
| `demux.buffer.ranges` | 0 (实时流) | 2-3 | **中等** |
| `buffer` | 0-1MB | 5-10MB | **中等** |
| `probesize` | 500KB (RTSP) | 1-2MB | 低 |
| `timeout` | 10s | 10-30s | 低 |

**解决路由**: 通过 URL 协议判断自动选择策略：

```dart
// 路由逻辑（伪代码）
if (url.contains('.m3u8') || url.contains('hls')) {
  // HLS ABR 模式：大缓冲、不丢帧
  configureForAbr(player, url);
} else if (url.startsWith('rtsp://') || url.startsWith('rtmp://')) {
  // 低延迟模式：小缓冲、允许丢帧
  configureForLowLatency(player, url);
} else {
  // 通用 HTTP 模式
  configureForHttp(player, url);
}
```

### 3.5 fvp 网络协议白名单

fvp 通过 `avio.protocol_whitelist` 配置允许的协议：

```dart
player.setProperty('avio.protocol_whitelist',
    'file,ftp,rtmp,http,https,tls,rtp,tcp,udp,crypto,httpproxy,data,concatf,concat,subfile');
```

HLS 需要的协议: `http,https,tcp,tls` — 已在白名单中。

---

## 4. 现有代码分析

### 4.1 NetworkConfigurator (现有)

**文件**: `lib/kernel/engine/network_configurator.dart`

**当前职责**:
- 通用网络超时 (10s)、探测大小 (1MB)、分析时长 (5s)
- 协议特定低延迟配置 (RTSP/RTMP/SRT/UDP/TCP)
- HTTP 基础配置 (`demux.buffer.ranges = 1`)
- 动态缓冲策略（高延迟 > 500ms 时增大到 5MB）

**缺失的 HLS/ABR 支持**:
- 无 `.m3u8` URL 识别
- 无变体解析
- 无码率选择逻辑
- HTTP 配置过于简单（`demux.buffer.ranges = 1` 对 ABR 不够）

### 4.2 MediaOpener (现有)

**文件**: `lib/kernel/engine/media_opener.dart`

**当前缓冲配置**:
- 本地文件: `setBufferRange(min: 1000, max: 4000, drop: true)` + `demux.buffer.ranges = 0`
- 网络流: 委托给 NetworkConfigurator

**ABR 需要的修改**:
- HLS URL 不应使用 `drop: true`（丢帧对 ABR 有害）
- 需要更大的缓冲区范围（至少 5-10 秒）

### 4.3 FvpEngine (现有)

**文件**: `lib/kernel/engine/fvp_engine.dart`

**当前状态**: 纯播放引擎，无网络流感知。ABR 需要在引擎层之上添加服务层。

### 4.4 PathValidator (现有)

**文件**: `lib/kernel/services/path_validator.dart`

**已有 URL 识别**: `isUrl` 方法可判断 http/https/rtmp/rtsp/srt/udp/tcp。需要扩展支持 `.m3u8` 识别。

---

## 5. 实现方案设计

### 5.1 架构总览

```
lib/kernel/
├── engine/
│   ├── network_configurator.dart     ← 修改: 添加 HLS ABR 配置路由
│   └── fvp_engine.dart               ← 不修改: 保持纯播放引擎
│
├── services/
│   ├── abr_service.dart              ← 新增: ABR 决策引擎
│   ├── bandwidth_estimator.dart      ← 新增: 带宽估算器
│   ├── quality_selector.dart         ← 新增: 码率选择算法
│   ├── playlist_parser.dart          ← 新增: M3U8 解析器
│   └── segment_prefetcher.dart       ← 新增: 分片预加载（Phase 3）
│
└── models/
    ├── abr_state.dart                ← 新增: ABR 状态模型
    ├── quality_variant.dart          ← 新增: 码率变体模型
    └── hls_segment.dart              ← 新增: HLS 分片模型
```

### 5.2 核心数据模型

```dart
/// HLS 码率变体
class QualityVariant {
  final int bandwidth;      // 声明带宽 (bps)
  final int? averageBandwidth;
  final int width;
  final int height;
  final String codecs;
  final double? frameRate;
  final String url;         // Media Playlist URL

  String get resolution => '${width}x$height';
  String get label => _resolutionLabel(height);

  static String _resolutionLabel(int h) => switch (h) {
    >= 2160 => '4K',
    >= 1080 => '1080p',
    >= 720  => '720p',
    >= 480  => '480p',
    >= 360  => '360p',
    _       => '${h}p',
  };
}

/// ABR 状态
class AbrState {
  final QualityVariant? currentVariant;
  final int bufferLevelMs;          // 当前缓冲区水位 (ms)
  final double estimatedBandwidth;  // 估算带宽 (bps)
  final double downloadSpeed;       // 最近一次下载速度 (bps)
  final int switchCount;            // 码率切换次数
  final Duration totalRebufferTime; // 总重缓冲时长
}

/// HLS 分片信息
class HlsSegment {
  final String url;
  final Duration duration;
  final int sequenceNumber;
  final bool isDiscontinuity;
}
```

### 5.3 带宽估算器

```dart
/// 基于滑动窗口的带宽估算器
///
/// 使用指数加权移动平均 (EWMA) 平滑带宽波动。
/// 低 α 值更平滑（适合稳定网络），高 α 值更敏感（适合波动网络）。
class BandwidthEstimator {
  static const _windowSize = 5;         // 最近 5 个分片
  static const _alpha = 0.3;            // EWMA 权重 (0-1, 越大越敏感)
  static const _minSamples = 2;         // 最少样本数才开始估算

  final _samples = <double>[];          // 最近下载速度样本 (bps)
  double _ewma = 0;                     // EWMA 估算值

  /// 记录一次下载
  void recordDownload(int bytes, Duration duration) {
    final speed = bytes * 8 / duration.inSeconds;  // bps
    _samples.add(speed);
    if (_samples.length > _windowSize) {
      _samples.removeAt(0);
    }

    // 更新 EWMA
    if (_samples.length == 1) {
      _ewma = speed;
    } else {
      _ewma = _alpha * speed + (1 - _alpha) * _ewma;
    }
  }

  /// 获取估算带宽 (bps)，样本不足时返回 0
  double get estimatedBandwidth =>
      _samples.length >= _minSamples ? _ewma : 0;

  /// 获取样本数
  int get sampleCount => _samples.length;

  /// 重置
  void reset() {
    _samples.clear();
    _ewma = 0;
  }
}
```

### 5.4 码率选择算法

#### 5.4.1 Throughput-based (Phase 1)

```dart
/// 基于吞吐量的码率选择
///
/// 选择带宽利用率不超过 70% 的最高码率（安全余量）。
class ThroughputSelector implements QualitySelector {
  static const _safetyFactor = 0.7;  // 70% 带宽利用率

  @override
  QualityVariant? select({
    required List<QualityVariant> variants,
    required double estimatedBandwidth,
    required int bufferLevelMs,
    required QualityVariant? currentVariant,
  }) {
    if (estimatedBandwidth <= 0) return variants.first;

    final safeBandwidth = estimatedBandwidth * _safetyFactor;

    // 从高到低选择不超过安全带宽的最高码率
    for (final v in variants.reversed) {
      if (v.bandwidth <= safeBandwidth) {
        return v;
      }
    }
    return variants.first;  // 最低码率兜底
  }
}
```

#### 5.4.2 BBA (Phase 2)

```dart
/// BBA: 基于缓冲区水位的码率选择
///
/// 参考: Huang et al., SIGCOMM 2014
class BbaSelector implements QualitySelector {
  static const _bufferMinMs = 5000;    // 缓冲下限 5s
  static const _bufferMaxMs = 60000;   // 缓冲上限 60s

  @override
  QualityVariant? select({
    required List<QualityVariant> variants,
    required double estimatedBandwidth,
    required int bufferLevelMs,
    required QualityVariant? currentVariant,
  }) {
    final bufferRatio = (bufferLevelMs - _bufferMinMs) /
        (_bufferMaxMs - _bufferMinMs);

    // 为每个码率计算缓冲阈值
    for (int i = variants.length - 1; i >= 0; i--) {
      final threshold = i / (variants.length - 1);
      if (bufferRatio >= threshold) {
        return variants[i];
      }
    }
    return variants.first;
  }
}
```

#### 5.4.3 MPC (Phase 3)

```dart
/// MPC: 基于模型预测控制的码率选择
///
/// 参考: Yin et al., SIGCOMM 2015
class MpcSelector implements QualitySelector {
  static const _lookahead = 5;       // 前瞻 5 个分片
  static const _lambda = 1.0;        // 切换惩罚权重
  static const _mu = 5.0;            // 重缓冲惩罚权重

  @override
  QualityVariant? select({
    required List<QualityVariant> variants,
    required double estimatedBandwidth,
    required int bufferLevelMs,
    required QualityVariant? currentVariant,
  }) {
    // 使用穷举搜索（5 个分片 × N 个码率）
    // 实际实现需要预测未来吞吐量和分片下载时间
    // 这里给出框架，完整实现需要更多状态
    return _dynamicProgramming(
      variants: variants,
      predictedThroughput: estimatedBandwidth,
      currentBuffer: bufferLevelMs,
      currentBitrate: currentVariant?.bandwidth ?? 0,
      depth: _lookahead,
    );
  }

  QualityVariant? _dynamicProgramming({
    required List<QualityVariant> variants,
    required double predictedThroughput,
    required int currentBuffer,
    required int currentBitrate,
    required int depth,
  }) {
    // 穷举搜索实现（简化版）
    // 完整实现需要递归计算每个分支的 QoE 累积值
    // 返回 QoE 最高的码率序列的第一个码率
    // TODO: Phase 3 完整实现
    return variants.first;
  }
}
```

### 5.5 ABR Service

```dart
/// ABR 自适应码率服务
///
/// 协调带宽估算、码率选择、分片下载。
/// 作为 FvpEngine 之上的服务层，不修改引擎本身。
class AbrService {
  final BandwidthEstimator _bandwidthEstimator;
  final QualitySelector _selector;
  final List<QualityVariant> _variants;

  AbrState _state;

  AbrService({
    required List<QualityVariant> variants,
    QualitySelector? selector,
  })  : _variants = variants,
        _bandwidthEstimator = BandwidthEstimator(),
        _selector = selector ?? ThroughputSelector(),
        _state = AbrState.initial();

  /// 获取当前 ABR 状态
  AbrState get state => _state;

  /// 获取可用码率列表
  List<QualityVariant> get variants => List.unmodifiable(_variants);

  /// 记录分片下载结果，更新带宽估算
  void recordSegmentDownload(int bytes, Duration duration) {
    _bandwidthEstimator.recordDownload(bytes, duration);
  }

  /// 选择下一个分片的码率
  ///
  /// 在每个分片下载前调用，返回推荐的码率变体。
  QualityVariant? selectQuality(int bufferLevelMs) {
    final selected = _selector.select(
      variants: _variants,
      estimatedBandwidth: _bandwidthEstimator.estimatedBandwidth,
      bufferLevelMs: bufferLevelMs,
      currentVariant: _state.currentVariant,
    );

    // 更新状态（不可变）
    _state = _state.copyWith(
      currentVariant: selected,
      bufferLevelMs: bufferLevelMs,
      estimatedBandwidth: _bandwidthEstimator.estimatedBandwidth,
    );

    return selected;
  }

  /// 重置状态（切换视频时调用）
  void reset() {
    _bandwidthEstimator.reset();
    _state = AbrState.initial();
  }
}
```

### 5.6 M3U8 解析器

```dart
/// M3U8 Master Playlist 解析器
///
/// 解析 #EXT-X-STREAM-INF 标签，提取码率变体列表。
class PlaylistParser {
  /// 解析 Master Playlist，返回码率变体列表
  static List<QualityVariant> parseMasterPlaylist(String content) {
    final variants = <QualityVariant>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attrs = _parseAttributes(line);
        final url = i + 1 < lines.length ? lines[i + 1].trim() : '';

        if (url.isNotEmpty && !url.startsWith('#')) {
          variants.add(QualityVariant(
            bandwidth: int.parse(attrs['BANDWIDTH'] ?? '0'),
            averageBandwidth: attrs['AVERAGE-BANDWIDTH'] != null
                ? int.parse(attrs['AVERAGE-BANDWIDTH']!)
                : null,
            width: _parseResolution(attrs['RESOLUTION']).$1,
            height: _parseResolution(attrs['RESOLUTION']).$2,
            codecs: attrs['CODECS'] ?? '',
            frameRate: attrs['FRAME-RATE'] != null
                ? double.parse(attrs['FRAME-RATE']!)
                : null,
            url: url,
          ));
        }
      }
    }

    // 按带宽排序（低到高）
    variants.sort((a, b) => a.bandwidth.compareTo(b.bandwidth));
    return variants;
  }

  /// 解析 Media Playlist，返回分片列表
  static List<HlsSegment> parseMediaPlaylist(String content) {
    final segments = <HlsSegment>[];
    final lines = content.split('\n');
    Duration accumulated = Duration.zero;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        final durationStr = line.substring(8).split(',').first;
        final duration = Duration(
          milliseconds: (double.parse(durationStr) * 1000).round(),
        );
        final url = i + 1 < lines.length ? lines[i + 1].trim() : '';

        if (url.isNotEmpty && !url.startsWith('#')) {
          segments.add(HlsSegment(
            url: url,
            duration: duration,
            sequenceNumber: segments.length,
            isDiscontinuity: false, // 简化
          ));
        }
      }
    }
    return segments;
  }

  static Map<String, String> _parseAttributes(String line) {
    final attrs = <String, String>{};
    final regex = RegExp(r'(\w[\w-]*)=([^,]+)');
    for (final match in regex.allMatches(line)) {
      attrs[match.group(1)!] = match.group(2)!.replaceAll('"', '');
    }
    return attrs;
  }

  static (int, int) _parseResolution(String? res) {
    if (res == null) return (0, 0);
    final parts = res.split('x');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }
}
```

### 5.7 NetworkConfigurator 修改

在现有 `NetworkConfigurator` 中添加 HLS ABR 路由：

```dart
/// 在 NetworkConfigurator.configure() 中添加 HLS 分支
static void configure(mdk.Player player, String url) {
  // 通用网络超时
  player.setProperty('timeout', _networkTimeoutMs.toString());
  player.setProperty('avformat.probesize', _networkProbeSize.toString());
  player.setProperty('avformat.analyzeduration', _networkAnalyzeDurationUs.toString());

  // 协议特定配置
  if (_isHlsUrl(url)) {
    _configureHlsAbr(player);
  } else if (url.startsWith('rtsp://')) {
    _configureRtsp(player);
  } else if (url.startsWith('rtmp://')) {
    _configureRtmp(player);
  } else if (url.startsWith('srt://')) {
    _configureSrt(player);
  } else if (url.startsWith('udp://') || url.startsWith('tcp://')) {
    _configureUdpTcp(player);
  } else if (url.startsWith('http://') || url.startsWith('https://')) {
    _configureHttp(player);
  }
}

/// HLS URL 识别
static bool _isHlsUrl(String url) =>
    url.contains('.m3u8') || url.contains('hls');

/// HLS ABR 专用配置 — 大缓冲、不丢帧
static void _configureHlsAbr(mdk.Player player) {
  // 不设置 fflags +nobuffer（ABR 需要缓冲）
  // 不设置 setBufferRange(drop: true)（ABR 不能丢帧）

  // 启用 demux 缓存
  player.setProperty('demux.buffer.ranges', '3');

  // 较大的播放缓冲（10 秒）
  player.setProperty('buffer', '10000000');

  // 协议白名单
  player.setProperty('protocol_whitelist',
      'file,http,https,tcp,tls,crypto,httpproxy,data');
}
```

---

## 6. 实现路线图

### Phase 1: 基础 ABR (1-2 天)

**目标**: HLS 播放 + 简单码率切换

**任务**:
- [ ] 实现 `PlaylistParser`（M3U8 解析）
- [ ] 实现 `QualityVariant` / `HlsSegment` 数据模型
- [ ] 实现 `BandwidthEstimator`（EWMA 滑动窗口）
- [ ] 实现 `ThroughputSelector`（简单带宽选择）
- [ ] 修改 `NetworkConfigurator` 添加 HLS 路由
- [ ] 集成到 `MediaOpener`（检测 HLS URL，应用 ABR 配置）
- [ ] 单元测试（解析器、估算器、选择器）

**交付**: 可播放 HLS 流，自动选择合适码率

### Phase 2: 缓冲优化 (1 天)

**目标**: BBA 算法 + 平滑切换

**任务**:
- [ ] 实现 `BbaSelector`（缓冲区水位选择）
- [ ] 实现 `AbrService`（协调器）
- [ ] 码率切换防抖（避免频繁切换）
- [ ] 切换时关键帧对齐检查
- [ ] 集成测试（模拟带宽波动）

**交付**: BBA 算法上线，码率切换更稳定

### Phase 3: 高级特性 (2-3 天)

**目标**: MPC 算法 + 预加载

**任务**:
- [ ] 实现 `MpcSelector`（前瞻优化）
- [ ] 实现 `SegmentPrefetcher`（分片预加载）
- [ ] 网络抖动检测和降级策略
- [ ] 多 CDN 源支持
- [ ] 性能测试和调优

**交付**: MPC 算法上线，QoE 接近最优

### Phase 4: UI 集成 (1 天)

**目标**: 用户可感知的 ABR 控制

**任务**:
- [ ] 码率选择器 UI（自动/手动切换）
- [ ] 当前码率 OSD 显示
- [ ] 缓冲状态可视化
- [ ] 设置面板集成

**交付**: 用户可手动选择码率，查看 ABR 状态

### Phase 5: LL-HLS 支持 (可选，2-3 天)

**目标**: 低延迟 HLS 流支持

**任务**:
- [ ] Partial Segment 解析
- [ ] Preload Hint 处理
- [ ] Blocking Playlist Reload
- [ ] Rendition Reports 解析
- [ ] 低延迟 ABR 算法适配

**交付**: 支持 LL-HLS 流，延迟 < 3 秒

---

## 7. 预期收益

### 7.1 用户体验提升

| 指标 | 当前（单码率） | ABR 后 | 提升 |
|------|---------------|--------|------|
| 首帧时间 | 2-5s | 1-3s | 50%+ |
| 卡顿率 | 依赖网络 | < 1% | 显著降低 |
| 画质适应 | 无 | 自动最优 | 从无到有 |
| 网络波动容忍 | 差 | 优秀 | 本质提升 |

### 7.2 技术收益

- **架构解耦**: ABR 作为服务层，不侵入引擎层
- **算法可插拔**: 通过 `QualitySelector` 接口，可随时切换算法
- **可观测性**: `AbrState` 暴露完整状态，便于调试和监控
- **渐进式实现**: 4 个 Phase 可独立交付，风险可控

### 7.3 竞争力提升

- 当前主流播放器（VLC、PotPlayer、mpv）均支持 HLS ABR
- 桌面播放器作为流媒体客户端的使用场景日益增多
- 支持 ABR 是"桌面播放器也能播网络流"的关键差异化

---

## 附录

### A. 参考文献

- [RFC 8216 - HTTP Live Streaming](https://tools.ietf.org/html/rfc8216)
- [draft-pantos-hls-rfc8216bis (LL-HLS)](https://tools.ietf.org/html/draft-pantos-hls-rfc8216bis)
- [Huang et al., "A Buffer-based Approach to Rate Adaptation", SIGCOMM 2014](https://dl.acm.org/doi/10.1145/2619239.2626296)
- [Spiteri et al., "BOLA: Near-Optimal Bitrate Adaptation for Online Videos", INFOCOM 2016](https://arxiv.org/abs/1512.02696)
- [Yin et al., "A Control-Theoretic Approach for Dynamic Adaptive Video Streaming over HTTP", SIGCOMM 2015](https://dl.acm.org/doi/10.1145/2785956.2787486)
- [Mao et al., "Pensieve: Reinforcement Learning for Adaptive Video Streaming", SIGCOMM 2017](https://dl.acm.org/doi/10.1145/3098822.3098843)
- [FFmpeg HLS Documentation](https://ffmpeg.org/ffmpeg-formats.html#hls)
- [FFmpeg hls.c Source](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/hls.c)

### B. 关键术语

| 术语 | 说明 |
|------|------|
| ABR | Adaptive Bitrate — 自适应码率 |
| BBA | Buffer-Based Approach — 基于缓冲区的方法 |
| BOLA | Buffer Occupancy based Lyapunov Algorithm |
| MPC | Model Predictive Control — 模型预测控制 |
| QoE | Quality of Experience — 体验质量 |
| EWMA | Exponential Weighted Moving Average — 指数加权移动平均 |
| LL-HLS | Low Latency HLS — 低延迟 HLS |
| IDR | Instantaneous Decoder Refresh — 即时解码刷新（关键帧） |
| fMP4 | Fragmented MP4 — 分片 MP4 |

### C. 与现有代码的集成点

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `network_configurator.dart` | 修改 | 添加 HLS ABR 配置路由 |
| `media_opener.dart` | 修改 | HLS URL 不使用 drop:true |
| `path_validator.dart` | 扩展 | 添加 `isHls` 方法 |
| `engine_constants.dart` | 扩展 | 添加 ABR 相关常量 |
| `abr_service.dart` | 新增 | ABR 协调器 |
| `bandwidth_estimator.dart` | 新增 | 带宽估算 |
| `quality_selector.dart` | 新增 | 码率选择接口 |
| `playlist_parser.dart` | 新增 | M3U8 解析 |
