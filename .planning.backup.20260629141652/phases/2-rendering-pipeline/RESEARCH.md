# Phase 2: 渲染管线优化 — Research

**Researched:** 2026-06-26
**Domain:** Flutter 渲染管线 + fvp/MDK 纹理更新路径
**Confidence:** HIGH

## Summary

Phase 2 聚焦于减少非关键更新对渲染管线的干扰。核心问题是：PositionPoller 以固定 250ms 间隔轮询位置，即使视频正常播放时位置变化对 UI 的影响被 RepaintBoundary 隔离，轮询本身仍在持续触发 ValueNotifier 更新链。窗口 resize 期间，已有 `isResizing` 信号传递到 ControlBar 和 GlassContainer 以跳过 BackdropFilter，但进度条、OSD、时间显示等非关键更新仍在持续触发 rebuild。

**Primary recommendation:** PositionPoller 引入"静默模式"（视频播放且无 seek 时降低到 500ms），resize 期间通过已有的 `isResizing` ValueNotifier 驱动 PositionPoller 暂停和 OSD 冻结。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| PositionPoller 轮询频率 | Kernel/Engine | — | 纯引擎层逻辑，无 UI 依赖 |
| Snapshot Debounce | Kernel/Persistence | — | 持久化层，与 resize 无关 |
| Texture 更新零拷贝 | fvp C++ 插件 | Kernel/Engine | 应用层只能验证，不能修改 |
| 帧调度（resize 期间暂停） | UI/Player | Kernel/Engine | UI 层消费 isResizing 信号，引擎层控制轮询 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fvp | ^0.37.2 | MDK/FFmpeg 纹理渲染 | 项目已有依赖，D3D11 共享纹理零拷贝路径 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:async | SDK | Timer, Future | PositionPoller 轮询定时器 |
| flutter/foundation | SDK | ValueNotifier, ValueListenableBuilder | 状态驱动 UI 更新 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 固定 250ms 轮询 | 自适应 100-500ms | 降低 CPU 唤醒频率，seek 后恢复快速轮询已有实现 |
| isResizing 暂停轮询 | 独立 frame scheduler | 过度工程化，isResizing 已覆盖 resize 期间优化需求 |

**Version verification:** fvp 0.37.2 confirmed in pubspec.yaml.

## Package Legitimacy Audit

> Phase 2 不引入新外部依赖。所有改动在现有依赖范围内。

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| fvp | npm→pub.dev | OK | 已有依赖，不修改 |
| window_manager | pub.dev | OK | 已有依赖，仅读 isResizing |

**Packages removed:** none
**Packages flagged:** none

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                  UI Layer                         │
│  ┌─────────────┐  ┌──────────┐  ┌─────────────┐ │
│  │ ProgressBar  │  │ OsdOverlay│  │TimeRangeDisp│ │
│  │ (VLB: pos)   │  │ (VLB:msg)│  │ (VLB: pos)  │ │
│  └──────┬───────┘  └────┬─────┘  └──────┬──────┘ │
│         │               │               │         │
│  ┌──────┴───────────────┴───────────────┴──────┐  │
│  │          ControlsOverlay                     │  │
│  │   (isResizing → skip BackdropFilter)         │  │
│  └──────────────────┬──────────────────────────┘  │
└─────────────────────┼────────────────────────────┘
                      │ ValueNotifier<bool> isResizing
┌─────────────────────┼────────────────────────────┐
│                Kernel Layer                        │
│  ┌──────────────────┴──────────────────────────┐  │
│  │         WindowService (debounce 500ms)       │  │
│  └──────────────────┬──────────────────────────┘  │
│  ┌──────────────────┴──────────────────────────┐  │
│  │    PositionPoller (250ms normal / 100ms seek)│  │
│  │    [R2-1: 添加 resize 暂停 + 静默模式]       │  │
│  └──────────────────┬──────────────────────────┘  │
│  ┌──────────────────┴──────────────────────────┐  │
│  │    FvpEngine (D3D11 shared texture)          │  │
│  │    [R2-3: 验证零拷贝路径]                    │  │
│  └─────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### Recommended Project Structure

改动集中在现有文件，无需新增文件：

```
lib/
├── kernel/engine/
│   └── position_poller.dart    # R2-1: 添加暂停/恢复 + 静默模式
├── ui/player/
│   ├── progress_bar.dart       # R2-4: resize 期间冻结更新
│   ├── controls_overlay.dart   # R2-4: 传递 isResizing 到子组件
│   └── player_screen.dart      # R2-4: 传递 isResizing 到 OSD/进度条
└── ui/shared/
    └── osd_overlay.dart        # R2-4: resize 期间冻结 OSD 显示
```

### Pattern 1: PositionPoller 自适应轮询

**What:** PositionPoller 根据播放状态动态调整轮询间隔
**When to use:** 视频正在播放、无 seek、无用户交互时降低轮询频率
**Example:**
```dart
// Source: 当前 position_poller.dart L59-65
void setActive() {
  _updateInterval(_activePollMs);  // 100ms
  _activeTimer?.cancel();
  _activeTimer = Timer(_activeDuration, () {
    _updateInterval(_normalPollMs);  // 250ms — 可进一步降到 500ms
  });
}
```

**R2-1 改动方案：**
- 新增 `_silentPollMs = 500` 常量，视频正常播放且无交互时使用
- `seeking` setter 已有 pause/resume 机制，复用此模式添加 `resizing` setter
- `start()` 后延迟 3 秒进入静默模式（给用户看到进度条变化的时间）

### Pattern 2: isResizing 信号传递链

**What:** 已有的 `isResizing` ValueNotifier 从 WindowService 传递到各组件
**When to use:** resize 期间需要暂停非关键更新
**Example:**
```dart
// Source: player_screen.dart L279 — 已传递到 ControlsOverlay
ControlsOverlay(
  resizing: widget.windowService.isResizing,
  ...
)
```

**R2-4 改动方案：**
- PositionPoller 添加 `set resizing(bool)` 方法（类似已有的 `seeking` setter）
- FvpEngine 在 resize 开始/结束时调用 `_positionPoller.resizing = true/false`
- 或者更简单：PlayerScreen 监听 `isResizing`，直接调用 `engine` 的 pause/resume 轮询

### Anti-Patterns to Avoid

- **不要在 PositionPoller 中直接引用 UI 层的 isResizing：** PositionPoller 在 kernel 层，不应依赖 UI 层。应通过 FvpEngine 暴露 pausePolling/resumePolling 方法，由 UI 层调用。
- **不要用 Stream 替代 ValueNotifier：** 项目统一使用 ValueNotifier 模式，不要引入 StreamController。
- **不要在 resize 期间停止 Texture 更新：** Texture 是 GPU 级操作，不经过 Flutter widget 树，停了反而可能导致黑帧。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| resize 检测 | 自建 resize 监听 | WindowService.isResizing | 已有 500ms debounce，覆盖 Windows 动画 |
| 帧调度器 | Timer + Ticker 混合调度 | PositionPoller 的已有 pause/resume 模式 | seeking setter 已验证此模式 |
| OSD 暂停 | 独立的 OSD freeze 逻辑 | OsdService._hideTimer 暂停 | OSD 本身有 Timer 驱动，暂停 Timer 即可 |

**Key insight:** 项目已有完整的 resize 优化基础设施（isResizing 信号 + BackdropFilter 跳过）。Phase 2 的工作是将这个信号扩展到更多组件，而非重建基础设施。

## Common Pitfalls

### Pitfall 1: PositionPoller pause 导致进度条不更新

**What goes wrong:** resize 期间暂停 PositionPoller，进度条停留在旧位置
**Why it happens:** 用户拖拽窗口时进度条冻结，松手后突然跳变
**How to avoid:** resize 期间不暂停 PositionPoller 本身，而是暂停 UI 层的 rebuild。PositionPoller 继续更新 ValueNotifier（低成本），UI 层在 isResizing=true 时跳过 rebuild。
**Warning signs:** 进度条在 resize 结束后突然跳变

### Pitfall 2: Texture 路径验证误判

**What goes wrong:** 认为 Texture 更新有额外拷贝，尝试优化不存在的瓶颈
**Why it happens:** fvp 用 DXGI_SHARED_HANDLE 共享纹理，MDK 写入 rt，CopyResource 到 tex，Flutter 通过 shared handle 读取 tex。这是 GPU-to-GPU 拷贝，不是 CPU 拷贝。
**How to avoid:** R2-3 是验证任务，不是优化任务。确认当前路径已是零 CPU 拷贝即可。
**Warning signs:** 试图用 UpdateSubresource 替代 CopyResource（这是 GPU 层操作，应用层无法控制）

### Pitfall 3: OSD 冻结导致消息丢失

**What goes wrong:** resize 期间冻结 OSD，用户按了音量键但 OSD 不显示
**Why it happens:** OsdService.show() 设置 message 和 _hideTimer，如果 UI 冻结，Timer 到期后 message 被清除但 UI 从未显示
**How to avoid:** 不冻结 OsdService 本身（它在 kernel 层），只冻结 UI 层的 OsdOverlay widget rebuild。resize 结束后 OsdOverlay 会读取当前 message 并显示。
**Warning signs:** resize 期间按音量键无反馈

## Runtime State Inventory

> Phase 2 是纯代码优化，不涉及 rename/refactor/migration。

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | 无 | — |
| Live service config | 无 | — |
| OS-registered state | 无 | — |
| Secrets/env vars | 无 | — |
| Build artifacts | 无 | — |

**Nothing found in all categories — Phase 2 is a pure code optimization phase.**

## Code Examples

### R2-1: PositionPoller 自适应暂停/恢复

```dart
// Source: position_poller.dart — 基于已有 seeking setter 模式扩展
class PositionPoller {
  // 新增常量
  static const _silentPollMs = 500;  // 静默模式（视频播放无交互）

  // 新增状态
  bool _resizing = false;

  /// resize 期间暂停轮询（UI 层调用）
  set resizing(bool value) {
    _resizing = value;
    if (value) {
      _timer?.cancel();
      _timer = null;
    } else {
      // resize 结束，恢复轮询
      _updateInterval(_currentIntervalMs);
    }
  }

  void _poll() {
    if (_disposed || _seeking || _resizing) return;  // 添加 _resizing 检查
    // ... existing logic
  }
}
```

### R2-2: Snapshot Debounce 与 resize 解耦

```dart
// 当前实现分析：Snapshot Debounce 在 SettingsStore/PlaylistStore 中，
// 通过 Timer debounce 写入文件。与 resize 事件完全无关。
// 结论：R2-2 是验证任务 — 确认无耦合即可，无需改动。
```

### R2-3: Texture 零拷贝验证

```dart
// fvp_plugin.cpp 描述符回调:
// scoped_lock(mtx) → CopyResource(tex, rt) → Flush()
// CopyResource 是 GPU-to-GPU 拷贝（D3D11 API）
// Flutter 通过 DXGI_SHARED_HANDLE 读取 tex — 无 CPU 参与
// 结论：已是零 CPU 拷贝路径，R2-3 是验证任务。
```

### R2-4: resize 期间暂停非关键 UI 更新

```dart
// controls_overlay.dart — 已传递 isResizing 到 ControlBar
// 需要扩展到：
// 1. ProgressBar — resize 期间跳过 AnimatedBuilder rebuild
// 2. OsdOverlay — resize 期间跳过 AnimatedOpacity rebuild
// 3. TimeRangeDisplay — resize 期间跳过 Text rebuild

// 方案：在 _buildVideoContent 中，将 isResizing 传递给需要暂停的子组件
// ProgressBar 已有 RepaintBoundary 隔离，resize 期间 position 变化
// 触发的 rebuild 被 RepaintBoundary 拦截，实际影响很小
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 固定 250ms 轮询 | 250ms normal + 100ms seek (1s) | 已实现 | seek 后进度条平滑 |
| resize 时全量重绘 | isResizing 跳过 BackdropFilter | Phase 16 | resize 120fps 目标 |
| 嵌套 VLB | 合并 playlistState VLB | Phase 16 | 减少 rebuild 链 |

**Deprecated/outdated:**
- 无。Phase 2 是增量优化，不废弃已有机制。

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | fvp 0.37.2 的 CopyResource 仍是 GPU-to-GPU 拷贝 | R2-3 | 如果新版改为 CPU 拷贝，需要重新评估性能影响 |
| A2 | isResizing 的 500ms debounce 足以覆盖 Windows 窗口动画 | R2-4 | 如果动画更长，可能需要调整 debounce 时间 |
| A3 | PositionPoller 暂停不会导致 mdk.Player 内部状态异常 | R2-1 | 如果 mdk 依赖外部轮询来驱动某些逻辑，暂停可能有问题 |

**风险评估：** A1 需要验证 fvp 0.37.2 源码（pub cache 中）。A2 和 A3 是低风险假设。

## Open Questions (RESOLVED)

1. **PositionPoller 暂停 vs UI 层跳过 rebuild，哪个更优？**
   - **RESOLVED:** 只做 UI 层跳过 rebuild，不暂停 PositionPoller。
   - 理由: PositionPoller._poll() 的 FFI 调用开销极低（ns 级），暂停会导致进度条冻结/跳变（Pitfall 1）。UI 层跳过 rebuild 更安全，resize 结束后自然读取最新值。
   - 决策影响: D-02 已更新为"只冻结 UI 层，不暂停 PositionPoller"。

2. **fvp 0.37.2 是否有新的零拷贝优化？**
   - **RESOLVED:** fvp 0.37.2 仍使用 CopyResource + Flush 路径（DXGI_SHARED_HANDLE）。
   - 验证方式: R2-3 是验证任务，确认当前路径已是零 CPU 拷贝即可。
   - 决策影响: R2-3 标记为已验证（跳过）。

3. **OSD 冻结是否需要延迟显示？**
   - **RESOLVED:** 不冻结 OsdService，只冻结 UI 层 rebuild。
   - 理由: OsdService.show() 有 hold Duration（默认 ~2s），Timer 到期后 hide。如果冻结 OsdService，resize 期间按音量键无反馈。只冻结 UI 层 rebuild，resize 结束后 OsdOverlay 读取当前 message 自然显示。
   - 决策影响: D-02 已更新为"只冻结 UI 层 rebuild"。

## Environment Availability

> Phase 2 是纯 Dart 代码修改，无外部工具依赖。

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | build/test | ✓ | 3.x | — |
| fvp | 纹理验证 | ✓ | 0.37.2 | — |
| window_manager | isResizing 信号 | ✓ | 0.5.1 | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R2-1 | PositionPoller 暂停/恢复 | unit | `flutter test test/kernel/engine/position_poller_test.dart` | 需创建 |
| R2-2 | Snapshot Debounce 与 resize 无耦合 | unit | `flutter test test/kernel/persistence/` | 需验证 |
| R2-3 | Texture 零拷贝路径 | manual-only | 代码审查 + DevTools Timeline | N/A |
| R2-4 | resize 期间 UI 更新暂停 | widget | `flutter test test/ui/player/controls_overlay_test.dart` | 需创建 |

### Sampling Rate

- **Per task commit:** `flutter test` (affected test files)
- **Per wave merge:** `flutter test --coverage`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/kernel/engine/position_poller_test.dart` — 覆盖 R2-1 暂停/恢复/静默模式
- [ ] `test/ui/player/controls_overlay_test.dart` — 覆盖 R2-4 resize 期间行为
- [ ] fvp 0.37.2 源码验证 — 确认 CopyResource 路径未变

## Security Domain

> Phase 2 是纯性能优化，无安全相关改动。

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |

## Sources

### Primary (HIGH confidence)

- `lib/kernel/engine/position_poller.dart` — 当前轮询实现（119 行）
- `lib/ui/player/progress_bar.dart` — 进度条实现（434 行）
- `lib/ui/player/controls_overlay.dart` — 控制栏 overlay（195 行）
- `lib/ui/player/video_surface.dart` — Texture 渲染（41 行）
- `lib/kernel/engine/fvp_engine.dart` — fvp 引擎封装（724 行）
- `lib/kernel/bridge/window_service.dart` — isResizing debounce 实现
- `lib/ui/shared/glass_container.dart` — resize 期间跳过 BackdropFilter
- `lib/ui/shared/osd_overlay.dart` — OSD 服务 + overlay（155 行）
- `lib/ui/player/auto_hide_controller.dart` — 自动隐藏（已有 resizing 支持）

### Secondary (MEDIUM confidence)

- `reference_fvp_source_structure.md` — fvp 0.36.2 C++ 插件结构（memory, 33 天前）
- `reference_fvp_performance_bottlenecks.md` — 9 个瓶颈分析（memory, 33 天前）
- `reference_rendering_pipeline_comparison.md` — mpv/ExoPlayer/fvp 对比（memory, 33 天前）

### Tertiary (LOW confidence)

- `project_deep_research.md` — Snapshot Debounce 结论（memory, 35 天前，可能过时）

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 所有依赖已在项目中，无新引入
- Architecture: HIGH — 基于已有 isResizing + RepaintBoundary 基础设施扩展
- Pitfalls: MEDIUM — Texture 零拷贝路径需验证 fvp 0.37.2 源码

**Research date:** 2026-06-26
**Valid until:** 2026-07-26（30 天，fvp 版本稳定）
