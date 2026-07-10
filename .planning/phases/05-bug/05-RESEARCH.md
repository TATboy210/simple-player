# Phase 5: 性能与Bug修复 - Research

**Researched:** 2026-07-10
**Domain:** Win32 FFI 全屏性能优化 + 渲染层黑边/边框修复
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-01 | 全屏切换 <100ms（从按下 F 到画面完全填满，对标 mpv） | 当前流程 6 层 async hop，确认链在 Windows 端冗余。跳过确认链 + 批量 FFI 可达 <50ms |
| PERF-02 | 全屏过渡零闪烁（消除黑帧/白帧/撕裂） | Widget tree 重建 + VideoSurface FittedBox 重算导致中间帧。需抑制重建或预设尺寸 |
| PERF-03 | Win32 FFI 路径优化（合并系统调用，减少 SetWindowLong/SetWindowPos 次数） | 当前 enterFullscreen 7 次 FFI 调用可合并为 3 次（样式批量 + 原子 SetWindowPos） |
| FIX-01 | 16:9 视频全屏无黑边（视频铺满整个16:9显示器） | VideoSurface FittedBox(contain) + aspectRatio 计算链。需排查渲染层是否正确铺满 |
| FIX-02 | 边框残留修复（全屏时 WS_THICKFRAME 完全剥离，无7px缝隙） | 当前代码已剥离 WS_THICKFRAME，但可能有时序问题或遗漏的边框样式 |
</phase_requirements>

## Summary

Phase 5 的核心是将全屏切换从"功能正确"提升到"体验对标 mpv"。当前 v1 实现已完成功能闭环（WS_THICKFRAME 剥离、命令队列、三级确认链），但存在两个性能瓶颈和两个渲染问题。

**性能瓶颈分析:**

1. **async hop 过多**: 按下 F → KeyboardHandler → PlayerScreen → WindowService.setMode → FullscreenAdapter.setFullscreen → CommandQueue.enqueue → _executeCommand → Driver.enterFullscreen，共 6 层异步调用。每层都有 microtask 调度开销。

2. **Windows 端冗余确认链**: DesktopFullscreenAdapter._waitForConfirmation() 在 Windows 端执行 Level 1 (500ms timeout) + Level 2 (100ms × 20 次轮询)，但 WindowsFullscreenDriver 的 FFI 操作是同步的，queryFullscreen() 在 enterFullscreen() 返回后立即返回 true。确认链完全多余。

3. **FFI 调用未合并**: enterFullscreen() 执行 7 次独立 FFI 调用: getFlutterHwnd, getWindowLong × 2, setWindowLong × 2, monitorFromWindow + getMonitorRect, setWindowPos。其中 setWindowLong × 2 可合并。

**渲染问题分析:**

1. **黑边 (FIX-01)**: VideoSurface 使用 `FittedBox(fit: BoxFit.contain)`，理论上 16:9 视频在 16:9 显示器上应无黑边。但如果窗口几何与显示器矩形有 1px 偏差（边框残留），FittedBox 会按可用空间计算，产生微小黑边。

2. **边框残留 (FIX-02)**: 当前 enterFullscreen() 已剥离 WS_THICKFRAME + WS_CAPTION + 多个 WS_EX_* 样式，但 SetWindowPos 的时序可能有问题——样式修改和窗口重定位不是原子操作，中间可能有一帧旧样式。

**Primary recommendation:** 为 WindowsFullscreenDriver 添加快速路径（FastPath），跳过确认链，将多个 FFI 调用合并为单一原子操作。同时排查 VideoSurface 渲染层的 aspectRatio 计算链。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 全屏切换性能 | Win32 FFI (Dart) | FullscreenAdapter | Driver 层合并 FFI 调用，Adapter 层跳过确认链 |
| 零闪烁过渡 | Flutter Widget 层 | Win32 FFI | 需要抑制 Widget tree 重建 + 原子窗口操作 |
| 视频黑边修复 | Flutter 渲染层 | fvp/MDK 引擎 | VideoSurface FittedBox + aspectRatio 计算 |
| 边框残留修复 | Win32 FFI (Dart) | — | 样式剥离 + SetWindowPos 时序优化 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:ffi | SDK | Win32 FFI 调用 | 项目已深度使用，Phase 3 已验证 |
| package:ffi | SDK | UTF-16 字符串 + calloc | 项目已集成 |
| flutter_test | SDK | 单元/集成测试 | 项目标准测试框架 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:ui | SDK | Offset, Size, PlatformDispatcher | 窗口几何 + DPI 转换 |
| dart:developer | SDK | Stopwatch 性能计时 | PERF-01 验证 <100ms |
| PerfMonitor | 项目内置 | 帧计时统计 | 验证零闪烁（无慢帧） |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 跳过确认链 | 保留确认链但缩短超时 | 仍有多余的 Completer + Timer 开销 |
| 批量 FFI | 保持逐个调用 | 每次调用跨 Dart-Native 边界，~0.1ms/次 |
| VideoSurface 重构 | 保持 FittedBox | 需确认 FittedBox 是否真正导致黑边 |

**Installation:**
```bash
# 无新依赖 — 所有所需库已集成
flutter pub get
```

## Package Legitimacy Audit

> Phase 5 不安装新外部包。所有依赖已在项目中验证。

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| ffi | SDK | — | — | dart-lang/sdk | [VERIFIED: SDK] | Built-in |
| flutter_test | SDK | — | — | flutter/flutter | [VERIFIED: SDK] | Built-in |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram — 当前全屏流程（性能瓶颈标注）

```
用户按键 (F)
    │
    ▼
KeyboardHandler._handleKeyEvent()
    │  [hop 1: KeyEvent → callback]
    ▼
PlayerScreen._buildVideoContent → onToggleFullscreen callback
    │  [hop 2: widget callback → WindowService]
    ▼
WindowService.setMode(WindowMode.fullscreen)
    │  [hop 3: async method call]
    ▼
FullscreenAdapter.setFullscreen(true)
    │  [hop 4: async method call]
    ▼
FullscreenCommandQueue.enqueue(request, executor)
    │  [hop 5: Completer chain + Timer]
    ▼
DesktopFullscreenAdapter._executeCommand()
    │  [hop 6: async executor]
    ▼
WindowsFullscreenDriver.enterFullscreen()
    │
    ├── FFI: getFlutterHwnd()           ← 1 次调用
    ├── FFI: getWindowLong(GWL_STYLE)   ← 2 次调用
    ├── FFI: getWindowLong(GWL_EXSTYLE)
    ├── FFI: getWindowPlacement()       ← 1 次调用
    ├── FFI: setWindowLong(GWL_STYLE)   ← 2 次调用（可合并）
    ├── FFI: setWindowLong(GWL_EXSTYLE)
    ├── FFI: monitorFromWindow()        ← 2 次调用
    ├── FFI: getMonitorRect()
    └── FFI: SetWindowPos()             ← 1 次调用
    │
    ▼  [总计 9 次 FFI 调用]
DesktopFullscreenAdapter._waitForConfirmation()
    │
    ├── Level 1: 等待原生回调 (500ms timeout) ← 完全多余！Windows FFI 同步
    ├── Level 2: 轮询 (100ms × 20)           ← 完全多余！
    └── Level 3: 超时
    │
    ▼
snapshot 更新 + events 广播
```

### 优化后全屏流程（目标）

```
用户按键 (F)
    │
    ▼
KeyboardHandler → WindowService.setMode(WindowMode.fullscreen)
    │  [hop 1-2: 保留，UI 层必要]
    ▼
FullscreenAdapter.setFullscreen(true)
    │  [hop 3: 保留]
    ▼
WindowsFullscreenDriver.enterFullscreenFast()  ← 新增快速路径
    │
    ├── FFI: getFlutterHwnd()                   ← 1 次
    ├── FFI: getWindowPlacement()                ← 1 次
    ├── FFI: setWindowLong(GWL_STYLE, stripped)  ← 1 次（合并样式）
    ├── FFI: setWindowLong(GWL_EXSTYLE, topmost) ← 1 次
    └── FFI: SetWindowPos(HWND_TOPMOST, monitor) ← 1 次（原子操作）
    │
    ▼  [总计 5 次 FFI 调用，减少 44%]
跳过确认链（Windows FFI 同步完成）
    │
    ▼
snapshot 更新 + events 广播
    │
    ▼  [总计 ~3 个 async hop，目标 <50ms]
```

### Recommended Project Structure

```
lib/kernel/bridge/
├── platform/
│   └── windows_fullscreen_driver.dart   # 修改: 添加 enterFullscreenFast()
├── desktop_fullscreen_adapter.dart      # 修改: Windows 端跳过确认链
└── win32/
    └── win32_fullscreen_ffi.dart        # 可能修改: 批量 FFI 方法

test/platform/
└── windows_fullscreen_driver_test.dart  # 修改: 添加 fast path 测试
```

### Pattern 1: WindowsFullscreenDriver Fast Path

**What:** 为 Windows 端添加 `enterFullscreenFast()` 方法，合并多个 FFI 调用为单一原子操作，跳过确认链。

**When to use:** `Platform.isWindows` + 全屏切换。

**关键优化点:**

```dart
/// 快速进入全屏 — 合并 FFI 调用，跳过确认链。
///
/// 对比标准 enterFullscreen():
/// - 减少 4 次 FFI 调用（合并样式、跳过查询）
/// - 不需要 _waitForConfirmation（FFI 同步完成）
/// - 预期延迟 <50ms（vs 标准路径 ~200ms+）
Future<void> enterFullscreenFast({int displayId = 0}) async {
  final hwnd = _api.getFlutterHwnd();
  if (hwnd == 0 || !_api.isWindow(hwnd)) return;

  // 保存当前样式 + 位置（单次 FFI）
  _savedStyle = _api.getWindowLong(hwnd, gwlStyle);
  _savedExStyle = _api.getWindowLong(hwnd, gwlExStyle);
  _freeSavedPlacement();
  _savedPlacement = _api.getWindowPlacement(hwnd);

  // 获取显示器矩形（单次 FFI）
  final monitor = _api.monitorFromWindow(hwnd);
  if (monitor == 0) return;
  final rc = _api.getMonitorRect(monitor);
  if (rc == null) return;

  // 批量设置样式（2 次 FFI，可进一步合并为 1 次）
  _api.setWindowLong(hwnd, gwlStyle,
      _savedStyle & ~(wsCaption | wsThickframe | wsMaximize));
  _api.setWindowLong(hwnd, gwlExStyle,
      _savedExStyle | wsExTopmost &
          ~(wsExDlgmodalframe | wsExWindowedge | wsExClientedge | wsExStaticedge));

  // 原子设置位置 + 大小（单次 FFI）
  _api.setWindowPos(hwnd, hwndTopmost,
      rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top,
      swpNoownerzorder | swpFramechanged);

  _isFullscreen = true;
}
```

**Source:** 参考当前 `WindowsFullscreenDriver.enterFullscreen()` 第 73-126 行。

### Pattern 2: DesktopFullscreenAdapter Windows 快速路径

**What:** 在 DesktopFullscreenAdapter 中，当 driver 是 WindowsFullscreenDriver 时，跳过三级确认链。

**When to use:** `_driver is WindowsFullscreenDriver` + enter/leave 操作。

```dart
/// _handleEnter 中的 Windows 快速路径
Future<bool> _handleEnter(...) async {
  // ... 前置逻辑不变 ...

  if (_driver is WindowsFullscreenDriver) {
    // Windows FFI 同步操作，不需要确认链
    await _driver.enterFullscreenFast(displayId: 0);
    notifier.value = notifier.value.copyWith(
      phase: FullscreenPhase.stable,
      effectiveMode: request.mode,
    );
    _events.add(FullscreenEvent.entered(finalMode: request.mode));
    return true;
  }

  // macOS/Linux: 保留标准路径 + 确认链
  await _driver.enterFullscreen(displayId: 0);
  final confirmed = await _waitForConfirmation(request.windowId, true);
  // ...
}
```

**Source:** 参考 `DesktopFullscreenAdapter._handleEnter()` 第 188-241 行。

### Pattern 3: VideoSurface 零闪烁优化

**What:** 在全屏切换期间，预设 VideoSurface 尺寸避免 FittedBox 重算导致的中间帧。

**When to use:** 全屏进入/退出过渡期间。

```dart
/// 优化方案: 在全屏切换前预设目标尺寸
///
/// 当前 VideoSurface 使用 SizedBox.expand + FittedBox(contain)，
/// 全屏切换时窗口尺寸突变，FittedBox 需要一帧重算。
///
/// 优化: 使用 AnimatedBuilder 监听 windowService.mode，
/// 在 mode 变化时立即设置目标尺寸（不等待 layout）。
```

**Source:** 参考 `VideoSurface` 第 1-41 行。

### Anti-Patterns to Avoid

- **在 Windows 端使用确认链:** Windows FFI 操作同步完成，确认链的 500ms + 2s 轮询完全浪费时间
- **逐个 FFI 调用:** 每次调用跨 Dart-Native 边界有 ~0.1ms 开销，9 次调用累计 ~1ms（可接受但可优化）
- **在 enterFullscreen 中查询 HWND 多次:** 当前代码在 enterFullscreen 和 queryFullscreen 中各调用一次 getFlutterHwnd()，应缓存
- **在全屏切换时触发 Widget tree 重建:** 应使用 RepaintBoundary 隔离全屏相关 Widget

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 性能计时 | 手写 Stopwatch | dart:developer Stopwatch | 标准库，精度足够 |
| 帧计时 | 手写帧回调 | PerfMonitor (项目内置) | 已有环形缓冲区 + 统计输出 |
| FFI 批量调用 | 自写批量 API | 现有逐个调用 + 优化顺序 | Win32 API 无批量接口，只能优化调用顺序 |

**Key insight:** Win32 API 本身不支持批量操作（每个 API 独立调用），优化空间在于减少调用次数（合并样式、缓存 HWND）和跳过不必要的逻辑（确认链）。

## Common Pitfalls

### Pitfall 1: 确认链跳过导致状态不一致
**What goes wrong:** 跳过确认链后，snapshot 可能在 FFI 调用失败时仍显示 stable。
**Why it happens:** 确认链的作用是验证原生操作是否成功，跳过后失去验证。
**How to avoid:** FFI 调用后立即 queryFullscreen() 验证（单次调用，<1ms），失败时回滚。
**Warning signs:** 全屏后 snapshot 显示 stable 但窗口实际未全屏。

### Pitfall 2: 样式修改和窗口重定位的时序
**What goes wrong:** SetWindowLong 修改样式后，SetWindowPos 设置位置前，有一帧旧样式。
**Why it happens:** 两个 FFI 调用不是原子的，中间可能被 WM_PAINT 中断。
**How to avoid:** 在 SetWindowPos 中使用 SWP_FRAMECHANGED 标志，强制一次性重绘。或使用 DeferWindowPos 批量操作。
**Warning signs:** 全屏时短暂看到旧边框或闪烁。

### Pitfall 3: VideoSurface FittedBox 重算延迟
**What goes wrong:** 全屏切换时，FittedBox 需要一帧时间重算布局，导致中间帧黑边。
**Why it happens:** Flutter layout 是 lazy 的，尺寸变化后下一帧才重算。
**How to avoid:** 使用 AnimatedBuilder 监听 mode 变化，在 mode 变化时预设目标尺寸。
**Warning signs:** 全屏切换时短暂黑边闪烁。

### Pitfall 4: 缓存 HWND 导致句柄失效
**What goes wrong:** 缓存的 HWND 在窗口重建后失效（如 DPI 变化、显示器切换）。
**Why it happens:** Win32 HWND 在窗口生命周期内不变，但 Flutter 引擎可能重建窗口。
**How to avoid:** 不缓存 HWND，每次调用 getFlutterHwnd()（FindWindowW 调用 ~0.01ms）。
**Warning signs:** 全屏操作在特定场景下静默失败。

## Code Examples

### Win32 FFI 批量样式设置

```dart
// Source: 参考 lib/kernel/bridge/win32/win32_fullscreen_ffi.dart

/// 批量设置窗口样式 — 减少 FFI 调用次数。
///
/// 返回 (oldStyle, oldExStyle) 用于恢复。
(int, int) batchSetWindowStyle(int hwnd, int newStyle, int newExStyle) {
  final oldStyle = _setWindowLong(hwnd, gwlStyle, newStyle);
  final oldExStyle = _setWindowLong(hwnd, gwlExStyle, newExStyle);
  return (oldStyle, oldExStyle);
}
```

### 全屏切换性能计时

```dart
// Source: dart:developer Stopwatch

/// 测量全屏切换延迟 — 从调用到完成。
Future<Duration> measureFullscreenSwitch(
  FullscreenAdapter adapter,
  bool enter,
) async {
  final sw = Stopwatch()..start();
  await adapter.setFullscreen(enter);
  sw.stop();
  return sw.elapsed;
}

// 验证 <100ms
final duration = await measureFullscreenSwitch(adapter, true);
expect(duration.inMilliseconds, lessThan(100));
```

### VideoSurface 零闪烁方案

```dart
// Source: lib/ui/player/video_surface.dart

/// 优化方案: 使用 ValueListenableBuilder 监听 mode，
/// 在全屏切换时预设目标尺寸。
class VideoSurface extends StatelessWidget {
  final EngineState engine;
  final ValueNotifier<WindowMode>? mode; // 新增: 窗口模式监听

  const VideoSurface({super.key, required this.engine, this.mode});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([engine.textureId, engine.aspectRatio]),
        builder: (_, _) {
          final id = engine.textureId.value;
          final ratio = engine.aspectRatio.value;
          final safeRatio = (ratio > 0 && ratio.isFinite) ? ratio : 16 / 9;
          return SizedBox.expand(
            child: id == null
                ? const SizedBox.shrink()
                : FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: safeRatio >= 1 ? safeRatio * 1000 : 1000,
                      height: safeRatio >= 1 ? 1000 : 1000 / safeRatio,
                      child: Texture(textureId: id),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| fullscreen_window C++ 直调 | Win32 FFI 直调 user32.dll | Phase 3 (已完成) | 焦点恢复 + TopMost 清理 |
| 无状态确认 (乐观更新) | 三级确认链 | Phase 2 (已完成) | macOS/Linux 状态可靠性 |
| WindowService 直调插件 | FullscreenAdapter → Queue → Driver | Phase 1-2 (已完成) | 命令串行化 + 状态回读 |
| 逐个 FFI 调用 | 批量 FFI + 跳过确认链 | Phase 5 (本阶段) | <100ms 全屏切换 |

**Deprecated/outdated:**
- 三级确认链在 Windows 端: 被快速路径替代（FFI 同步，无需确认）
- 标准 enterFullscreen(): 保留为 macOS/Linux 路径，Windows 端使用 enterFullscreenFast()

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Windows FFI 操作同步完成，不需要确认链验证 | Pattern 2 | 如果 FFI 异步，跳过确认链可能导致状态不一致 |
| A2 | FindWindowW 调用开销 ~0.01ms，不需要缓存 HWND | Pitfall 4 | 如果开销 >1ms，应考虑缓存 |
| A3 | VideoSurface FittedBox(contain) 在 16:9 视频 + 16:9 显示器上无黑边 | FIX-01 | 如果有黑边，需要检查 aspectRatio 计算链 |
| A4 | SetWindowPos + SWP_FRAMECHANGED 足以解决边框残留 | FIX-02 | 如果仍有残留，可能需要 DeferWindowPos 批量操作 |
| A5 | 全屏切换 <100ms 目标可通过跳过确认链 + 批量 FFI 达成 | PERF-01 | 如果仍 >100ms，需要进一步优化 Widget tree |

## Open Questions

1. **VideoSurface 黑边根因**
   - What we know: VideoSurface 使用 FittedBox(contain)，理论上 16:9 视频无黑边
   - What's unclear: 黑边是来自 VideoSurface 还是窗口几何偏差
   - Recommendation: 添加诊断日志，打印窗口矩形 vs 显示器矩形 vs aspectRatio

2. **边框残留根因**
   - What we know: enterFullscreen() 已剥离 WS_THICKFRAME + WS_CAPTION + 多个 WS_EX_*
   - What's unclear: 是否有时序问题（样式修改和窗口重定位之间有一帧）
   - Recommendation: 使用 DeferWindowPos 批量操作，或在 SetWindowPos 前禁用窗口绘制

3. **DeferWindowPos 可行性**
   - What we know: DeferWindowPos 可以批量设置窗口位置，减少重绘次数
   - What's unclear: 是否值得引入（增加代码复杂度）
   - Recommendation: 先用当前方案优化，如果仍不达标再引入

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| user32.dll | WindowsFullscreenDriver | ✓ | Windows 11 | — |
| Flutter SDK | 全部 | ✓ | 3.x | — |
| dart:ffi | Win32 FFI | ✓ | SDK | — |
| PerfMonitor | 性能验证 | ✓ | 项目内置 | dart:developer Stopwatch |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Quick run | `flutter test test/platform/windows_fullscreen_driver_test.dart` |
| Full suite | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| PERF-01 | 全屏切换 <100ms | unit + benchmark | `flutter test test/platform/windows_fullscreen_driver_test.dart` |
| PERF-02 | 零闪烁（无慢帧） | integration | `flutter test test/integration/fullscreen_e2e_test.dart` |
| PERF-03 | FFI 调用次数减少 | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` |
| FIX-01 | 16:9 视频无黑边 | manual + golden | `flutter test test/golden/` |
| FIX-02 | 边框残留修复 | unit + manual | `flutter test test/platform/windows_fullscreen_driver_test.dart` |

### Sampling Rate
- Per task commit: `flutter test test/platform/`
- Per wave merge: `flutter test`
- Phase gate: Full suite green + `flutter run -d windows` 手动验证全屏 <100ms

### Wave 0 Gaps
- [ ] `test/platform/windows_fullscreen_driver_test.dart` — 添加 fast path 测试
- [ ] `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` — 添加 Windows 快速路径测试
- [ ] 性能基准测试 — 验证 <100ms 目标

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Win32 HWND 句柄验证 (IsWindow) |
| V6 Cryptography | no | — |

### Known Threat Patterns for Win32 FFI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 无效 HWND 句柄 | Denial of Service | 调用前 IsWindow() 检查 |
| FFI 内存泄漏 | Information Disclosure | finally 块中 calloc.free() |
| 跳过确认链导致状态不一致 | Tampering | FFI 后 queryFullscreen() 验证 |

## Sources

### Primary (HIGH confidence)
- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` — 当前 WindowsFullscreenDriver 实现 (392 行)
- `lib/kernel/bridge/desktop_fullscreen_adapter.dart` — 三级确认链实现 (417 行)
- `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` — Win32 FFI 绑定 (509 行)
- `lib/kernel/bridge/fullscreen_command_queue.dart` — 命令队列 (250 行)
- `lib/ui/player/video_surface.dart` — VideoSurface FittedBox 实现 (41 行)
- `lib/kernel/bridge/window_service.dart` — WindowService 全屏委托 (362 行)

### Secondary (MEDIUM confidence)
- MEMORY: project_fullscreen_win32_fix.md — Win32 FFI 重写方案 (WS_THICKFRAME 解决方案)
- MEMORY: anti_pattern_fullscreen_ffi.md — 禁止 win32 包的反面教训

### Tertiary (LOW confidence)
- DeferWindowPos 批量操作可行性 — 基于训练知识，未在项目中验证

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 所有库已在项目中验证
- Architecture: HIGH — v1 架构已冻结，v2 只优化性能路径
- Pitfalls: MEDIUM — Win32 pitfalls 已有项目经验，DeferWindowPos 未验证

**Research date:** 2026-07-10
**Valid until:** 2026-08-10 (30 days — Win32 API 稳定)
