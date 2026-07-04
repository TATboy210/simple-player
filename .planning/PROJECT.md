# Simple Player Flutter

## What This Is

Simple Player Flutter 桌面媒体播放器持续迭代项目。

## Current Milestone: v1.5 代码注释补全

**Goal:** 为所有重要组件、程序和代码添加/完善注释，提升代码可读性和可维护性

**Target features:**
- 公共 API 补全 `///` doc comments（类、方法、属性）
- 非显而易见逻辑添加 "why" 注释（而非 "what"）
- 魔法数字/字符串提取为命名常量并添加说明
- FFmpeg 滤镜语法等专业领域添加解释性注释

**背景:** 代码库审计显示 135 个 .dart 文件中 ~115 个已有良好注释，~20 个需要针对性改进

---

## Previous Milestone: PlayerEngine 架构优化与依赖清理

Simple Player Flutter 的引擎层架构优化项目：移除外部 `player_engine` path 依赖，优化 FvpEngine 内部结构，评估 media_kit 1.2.6 作为未来替代方案的可行性。

## Why

**直接原因：** 项目依赖一个外部 path 包 `player_engine`（位于 `../widget_tree_flutter/player_engine`），但本地 `lib/kernel/engine/` 已有完全相同的 1:1 副本。这个跨目录依赖脆弱且不必要。

**架构原因：** FvpEngine 中 VolumeController/SubtitleConfigurator/D3D11Configurator 的逻辑被内联而非委托，违反组合模式。

**战略原因：** 需要评估 media_kit 1.2.6 是否能替代 fvp，基于实际 API 能力对比而非传闻。

## Context

### 当前架构

```
UI Layer (57 files)
  → import 'package:player_engine/player_engine.dart'  ← 外部 path 依赖
  → PlayerEngine (abstract, 12 ValueNotifiers, 30 methods)
      ↑
  FvpEngine (concrete, 547 lines)
      → fvp/mdk.Player (FFmpeg + D3D11)
      → 5 helpers: FvpCallbackHandler, PositionPoller, TrackManager, MediaOpener, VideoEffectController
```

### 外部 player_engine 包结构

```
../widget_tree_flutter/player_engine/lib/
├── player_engine.dart          # barrel (8 exports)
└── src/
    ├── media_error_type.dart   # 5-value enum
    ├── media_state.dart        # 9-value enum
    ├── player_engine_base.dart # abstract class
    ├── video_effect_type.dart  # 4-value enum
    └── models/
        ├── audio_track_info.dart
        ├── media_info.dart
        ├── subtitle_track_info.dart
        └── video_codec_info.dart
```

**所有文件与 `lib/kernel/engine/` 下的本地副本完全一致。**

### 业界参考

| 播放器 | 引擎 | 有抽象层 | 原因 |
|--------|------|---------|------|
| IINA (45.4k ★) | mpv | ❌ | 单引擎直接绑定 |
| VLC | 100+ 模块 | ✅ | 多格式/协议/渲染器 |
| media_kit (1.8k ★) | libmpv | ❌ | 直接封装 |
| Harmonoid (1.5k ★) | media_kit | ✅ | 只做音乐，功能简单 |
| **本项目** | **fvp** | **✅** | **单引擎 + 抽象层** |

### fvp vs media_kit 能力对比

| 能力 | fvp (MDK) | media_kit (libmpv) |
|------|-----------|-------------------|
| `setProperty()` 万能接口 | ✅ | ❌ |
| D3D11 精确控制 | ✅ | ❌ |
| FFmpeg 均衡器 (`af`) | ✅ | ❌ |
| 视频特效 API | ✅ `setVideoEffect()` | ❌ |
| 解码器链配置 | ✅ `video.decoders` | ❌ |
| 社区规模 | 345 ★ | 1.8k ★ |
| 跨平台 | 6 平台 | 5 平台 |

### 关键技术发现

1. **fvp 的 `setProperty()` 继承自 mpv 的属性系统** — 万能 key-value 接口控制一切 MDK 参数
2. **media_kit 无法替代 fvp 的核心能力** — 成功迁移案例（Smarters IPTV、Geogram）都不使用高级功能
3. **IINA (45.4k ★) 是最佳架构参考** — 单引擎 mpv，无抽象层，直接绑定
4. **PlayerEngine 抽象层有测试价值** — MockEngine 用于 widget 测试，保留合理

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 移除外部 player_engine 依赖 | 本地已有 1:1 副本，跨目录依赖脆弱 | ✅ Done (Phase 1, commit a5e4882 + 01-02) |
| 保留 PlayerEngine 抽象层 | MockEngine 测试价值 + 接口隔离 | — Pending |
| 保留 fvp 作为唯一引擎 | setProperty/D3D11/均衡器无法替代 | — Pending |
| 不引入 media_kit | API 能力不兼容，功能损失严重 | — Pending |
| FvpEngine 委托给 helpers | 消除内联重复，符合组合模式 | — Pending |

## Requirements

### Validated

- ✓ PlayerEngine 抽象接口 (12 ValueNotifiers, 30 methods) — existing
- ✓ FvpEngine 实现 (fvp/mdk.Player) — existing
- ✓ 5 个 helper 组件 (CallbackHandler, PositionPoller, TrackManager, MediaOpener, VideoEffectController) — existing
- ✓ MockEngine 测试替身 — existing
- ✓ Barrel export 文件 (player_engine.dart) — existing

### Active (v1.3)

- [ ] UI-01: 空状态控制栏背景优化 — 无视频时更淡、更融合
- [ ] UI-02: 控制栏颜色亮度向背景看齐 — 毛玻璃效果不变
- [ ] UI-03: 整体玻璃质感调优 — 边框、透明度参数协调

### Previous Active (PlayerEngine, deferred)

- [x] 移除 pubspec.yaml 中的 `player_engine` path 依赖
- [x] 将 56 个文件的 import 从 `package:player_engine/` 改为本地相对路径
- [ ] FvpEngine 委托 VolumeController/SubtitleConfigurator/D3D11Configurator 而非内联
- [ ] 生成 media_kit 1.2.6 深度 API 对比报告

### Out of Scope

- 引入 media_kit 作为引擎 — API 能力不兼容
- 将 PlayerEngine 发布为独立包 — 只有一个消费者
- 实现第二个引擎 — 无实际需求

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

---
*Last updated: 2026-07-02 — milestone v1.3 started*
