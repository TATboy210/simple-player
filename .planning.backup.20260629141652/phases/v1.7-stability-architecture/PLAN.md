---
gsd_plan_version: 1.0
milestone: v1.7
milestone_name: Stability, Architecture & Cross-Platform Prep
status: draft
created: "2026-06-26"
---

# v1.7 Plan: Stability, Architecture & Cross-Platform Prep

## Goal

从 v1.6 的性能优化基础上，解决技术债务、提升架构质量、打磨功能细节、为跨平台扩展做准备。

**成功标准:**
- 全屏状态机零竞态，快速按键不崩溃
- FvpEngine 从 693 行降至 <300 行
- 零 bang operator (`!.`)、零硬编码颜色
- Win11 圆角、多显示器钳位、响应式布局就绪
- 跨平台抽象层就绪（Linux/macOS 移植只需实现平台适配器）

## Wave 1: Stability & Code Quality (低风险)

> 先修地基，后续所有改动更安全。

### R1-1: Fullscreen State Machine
**文件:** `lib/kernel/bridge/fullscreen_controller.dart`
**问题:** Completer-based mutex 不可重入，快速 F 键导致状态损坏。git 历史有 6 次 revert。
**方案:**
- 用 `enum WindowMode { windowed, fullscreen, transitioning }` 替代 Completer
- `transitioning` 状态下忽略新请求（或排队最后一个）
- 添加 200ms cooldown 防抖
- 状态转换用 `switch` 穷举，编译器强制处理所有分支

### R1-2: Bang Operator Elimination (~20 处)
**文件:** 10+ 文件（见 CONCERNS.md）
**方案:** 逐文件替换：
- `widget.engine!.` → `widget.engine?.` + early return
- `context.findRenderObject()! as RenderBox` → `final ro = context.findRenderObject(); if (ro is! RenderBox) return;`
- `Completer<T>.future` 中的 `!` → nullable 类型 + null check
- 每个文件改完跑对应测试验证

### R1-3: Hardcoded Colors → Tokens
**文件:** `app.dart` (7色), `aurora_background.dart` (5色), `thumbnail_tile.dart`, `osd_overlay.dart`
**方案:**
- 在 `tokens.dart` 中添加缺失的颜色常量
- 逐文件替换 `Color(0x...)` → `Tokens.*`
- 用 grep 验证零残留: `Color(0x` 不应出现在 `ui/` 目录

### R1-4: Silent Catch → Proper Logging
**文件:** `linux_platform_fullscreen.dart`, `folder_scanner.dart`
**方案:** `catch (_) {}` → `catch (e, st) { debugPrint('...: $e\n$st'); }`
- 不改变行为，只确保错误可见

### R1-5: Magic Numbers → Named Constants
**文件:** `settings_store.dart` (窗口尺寸边界), `playback_navigator.dart`, `aspect_ratio_mode.dart`
**方案:** 提取为 `static const` 或 `Tokens.*`

## Wave 2: Architecture Refactoring (中风险)

> 依赖 Wave 1 的稳定性修复。拆大文件、理清职责。

### R2-1: FvpEngine Decomposition — Phase 1: NetworkConfigurator
**文件:** `lib/kernel/engine/fvp_engine.dart` → 新建 `network_configurator.dart`
**方案:**
- 提取 URL 协议检测 + FFmpeg 网络参数配置（RTSP/RTMP/SRT/UDP/HTTP）
- 接口: `class NetworkConfigurator { static void configure(Player player, String url); }`
- 减 ~50 行，FvpEngine 委托调用

### R2-2: FvpEngine Decomposition — Phase 2: MediaOpener
**文件:** 新建 `media_opener.dart`
**方案:**
- 提取 open 流程: 路径校验 → prepare → 元数据解析 → texture 创建
- `sealed class OpenResult { OpenSuccess, OpenError }` 替代 nullable 返回
- 依赖 NetworkConfigurator + PositionPoller + TrackManager
- 减 ~150 行

### R2-3: FvpEngine Decomposition — Phase 3: VideoEffectController
**文件:** 新建 `video_effect_controller.dart`
**方案:**
- 提取亮度/对比度/饱和度/色调 + 旋转/纵横比/去隔行
- 独立于 Phase 1-2，可并行
- 减 ~50 行

### R2-4: Large File Splits
- `progress_bar.dart` (437行) → 提取 `_TooltipWidget`
- `settings_store.dart` (436行) → 提取 `SettingsValidator`
- `control_bar.dart` (429行) → 提取子 widget（已在 center_controls.dart 部分完成）
- `settings_panel.dart` (402行) → 提取 deferred-apply 逻辑

### R2-5: Static Mutable State Cleanup
**文件:** `PlaylistStore`, `SettingsStore`
**方案:** 改为实例方法 + 构造函数注入存储路径，消除测试隔离问题

## Wave 3: Feature Polish (低风险)

> 可与 Wave 2 并行。提升用户体验。

### R3-1: Win11 Rounded Corners
**文件:** `windows/runner/main.cpp` (OnCreate)
**方案:**
```cpp
DWM_WINDOW_CORNER_PREFERENCE pref = DWMWCP_ROUND;
DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &pref, sizeof(pref));
```
3 行 C++，高视觉冲击。

### R3-2: Multi-Monitor Window Clamping
**文件:** `window_service.dart` 或 `window_bridge.dart`
**方案:**
- 窗口恢复时检查是否在可见显示器范围内
- 用 `EnumDisplayMonitors` (Win32 FFI) 获取所有显示器几何
- 超出范围时钳位到最近显示器中心

### R3-3: Window Snap Assist 验证
**方案:** 手动测试 Win+Z Snap Layouts 是否正常工作
- `WS_THICKFRAME` 应该自动支持
- 如不工作，检查 `WM_NCHITTEST` 返回值

### R3-4: Responsive Narrow Layout (<600dp)
**文件:** `player_screen.dart`, `control_bar.dart`
**方案:**
- 控制栏在窄窗口时折叠为单行
- 播放列表覆盖而非并排
- 断点: 600dp (已有部分逻辑)

## Wave 4: Cross-Platform Prep (中高风险)

> 为 Linux/macOS 移植做准备，不实际移植。

### R4-1: Platform Abstraction Layer
**方案:**
- 定义 `abstract class PlatformWindowOps` 接口
- Win32 实现: 现有 `window_bridge.dart` 逻辑
- 接口方法: `setFullscreen`, `setGeometry`, `getDisplays`, `setCornerPreference`
- 文件: `lib/kernel/bridge/platform_window_ops.dart`

### R4-2: Window Manager 抽象
**方案:**
- `WindowService` 依赖 `PlatformWindowOps` 而非直接 Win32 FFI
- 注入点: 构造函数或 `app.dart` 初始化
- 现有 Win32 代码移至 `Win32WindowOps`

### R4-3: Path Provider 迁移
**方案:** `%APPDATA%` 硬编码 → `path_provider` 跨平台路径
- 影响: `log.dart`, `PlaylistStore`, `SettingsStore`

### R4-4: ValueNotifier 线程安全
**方案:** 平台 channel 回调中用 `addPostFrameCallback` 更新 ValueNotifier
- 预防 macOS platform thread ≠ main thread 问题

## Sequencing

```
Wave 1 (stability) ─────────────────────────── 5 tasks, ~3 days
    │
    ├── Wave 2 (architecture) ──────────────── 5 tasks, ~5 days
    │       │
    │       └── Wave 4 (cross-platform prep) ── 4 tasks, ~2 days
    │
    └── Wave 3 (features) ──────────────────── 4 tasks, ~2 days
            (可与 Wave 2 并行)
```

## Risks

| Risk | Mitigation |
|------|------------|
| FvpEngine 拆分破坏现有测试 | 逐步提取，每步跑全量测试 |
| 全屏状态机回归 | 保留现有行为，只加防护 |
| 圆角 C++ 改动影响窗口行为 | 3 行改动，easy revert |
| 跨平台抽象层过度设计 | 只定义接口，不实现非 Windows 平台 |

## Out of Scope (v1.8+)

- Linux 实际移植
- macOS 实际移植
- HLS ABR
- Steam/SteamOS
- System Tray
- PiP
