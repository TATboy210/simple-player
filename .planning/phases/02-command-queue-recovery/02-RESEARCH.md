# Phase B: 命令队列与恢复策略 - Research

**Researched:** 2026-07-09
**Domain:** Dart Completer 链模式 + window_manager API + 全屏状态机
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CMD-01 | per-window 命令队列，同一 windowId 只允许一个 in-flight 命令 | Completer 链模式 + per-windowId Map 隔离 |
| CMD-02 | 连续两次相同目标命令合并为一次 | toggle 先解析 + target+displayId 相同则复用 Completer |
| CMD-03 | 原生执行完成后回读真实状态，若与目标不一致发出 StateDesync | windowManager.isFullScreen() 轮询 + StateDesync 事件 |
| RST-01 | windowed→fullscreen→exit 恢复到最近一次普通窗口几何 | getBounds() 快照 + setBounds() 恢复 |
| RST-02 | maximized→fullscreen→exit 恢复到 maximized | maximize() 语义恢复，不用几何模拟 |
| RST-03 | 副屏→fullscreen→exit 恢复到副屏原始位置和大小 | DisplayEnumerator + setBounds() + 降级 center |
| RST-04 | minimized 状态不直接切全屏，先恢复窗口再进入 | isMinimized() 检测 + restore() + 串行执行 |
| ARCH-03 | 旧 fullscreen_window 调用点渐进迁移到 FullscreenAdapter | 仅 WindowService.setMode() 一处，UI 层无直调 |
</phase_requirements>

## Summary

Phase B 的核心是实现 `FullscreenCommandQueue` 和 `DesktopFullscreenAdapter`。当前代码库中 fullscreen_window 插件的调用点仅有一处（`WindowService.setMode()` 第 247 行），UI 层（keyboard_handler、player_screen）通过 `WindowBridge.setMode(WindowMode.fullscreen)` 间接调用，无直调。这大大简化了迁移工作。

window_manager API 提供了完整的方法集：`isFullScreen()`、`setFullScreen()`、`getBounds()`、`setBounds()`、`maximize()`、`unmaximize()`、`restore()`、`minimize()`、`isMinimized()`、`isMaximized()`、`getPosition()`、`getSize()`。所有方法均返回 Future，适合异步队列模式。WindowListener 提供 `onWindowEnterFullScreen()`/`onWindowLeaveFullScreen()` 回调用于状态确认。

fullscreen_window 插件的 Windows 原生实现（C++）在进入全屏时保存窗口样式和 placement，退出时恢复。它使用 `SC_MAXIMIZE` 消息实现全屏覆盖，这与 window_manager 的 `setFullScreen()` 行为可能重叠。Phase B 的 legacy 分支应继续使用 fullscreen_window，新分支使用 window_manager。

**Primary recommendation:** 实现 FullscreenCommandQueue（Completer 链 + per-windowId Map + 合并逻辑），DesktopFullscreenAdapter 内部持有队列并协调 windowManager + fullscreen_window + WindowListener 回调。

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| window_manager | 0.5.0 (locked) | 窗口管理 API | 项目已集成，提供 isFullScreen/setFullScreen/getBounds/setBounds/maximize/restore |
| fullscreen_window | local package | 全屏原生实现 | 项目本地包，Windows C++ 实现 WS_THICKFRAME 样式操作 |
| flutter/foundation | SDK | ValueNotifier | 项目唯一状态管理模式 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:async | SDK | Completer, Timer, StreamController | 命令队列核心、超时轮询、事件广播 |
| dart:ui | SDK | Offset, Size, Rect | 窗口几何快照 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Completer 链 | async Queue 包 | Queue 包引入外部依赖，Completer 是 Dart 原生，项目已有 openGeneration 模式参考 |
| windowManager.isFullScreen() | WindowBridge.mode 缓存 | mode 缓存可能与真实状态不同步（D-21 已锁定用 isFullScreen） |

## Architecture Patterns

### System Architecture Diagram

```
用户按键 (F)
    │
    ▼
KeyboardHandler.onToggleFullscreen
    │
    ▼
PlayerScreen → WindowService.setMode(fullscreen)  ← Phase B: 改为委托 FullscreenAdapter
    │
    ▼
FullscreenAdapter.toggle()
    │
    ├── 解析 toggle → setFullscreen(true/false) 基于 snapshot.isFullscreen
    │
    ▼
FullscreenCommandQueue.enqueue(request)
    │
    ├── 检查 in-flight: 有 → 排队或合并（同 target+displayId → 复用 Completer）
    │                  无 → 立即执行
    │
    ▼
DesktopFullscreenAdapter._execute(request)
    │
    ├── 1. 更新 snapshot.phase = entering/leaving
    ├── 2. 快照 restoreMode + position + size + displayId（仅 enter 时）
    ├── 3. 检测 minimized → restore() 先恢复窗口
    ├── 4. 调用原生: fullscreen_window.setFullScreen() 或 windowManager.setFullScreen()
    ├── 5. 等待确认: WindowListener 回调 → 500ms 超时 → 轮询 isFullScreen() 100ms×20
    ├── 6. 回读状态: 与目标比较
    │       ├── 一致 → snapshot 更新为 stable + effectiveMode
    │       └── 不一致 → StateDesync 事件 + snapshot 更新为真实状态 + error phase
    │
    ▼
Completer 完成 → 队列消费下一个命令
```

### Recommended Project Structure
```
lib/kernel/bridge/
├── fullscreen_adapter.dart          # 抽象接口 (Phase A 已有)
├── desktop_fullscreen_adapter.dart  # 新: 真实实现
├── fullscreen_command_queue.dart    # 新: 命令队列
├── window_service.dart              # 修改: setMode(fullscreen) 委托 adapter
├── window_bridge.dart               # 不变
├── window_state.dart                # 不变
└── window_mode.dart                 # 不变

lib/kernel/models/
├── fullscreen_snapshot.dart         # Phase A 已有
├── fullscreen_error.dart            # Phase A 已有
├── fullscreen_event.dart            # Phase A 已有
├── fullscreen_request.dart          # Phase A 已有
└── fullscreen_capability.dart       # Phase A 已有
```

### Pattern 1: Completer 链命令队列

**What:** per-windowId 独立队列，一个 Completer 代表当前 in-flight 命令，新命令到达时检查前一个是否完成。

**When to use:** 需要串行化异步操作、支持幂等合并、超时控制的场景。

**Example:**
```dart
// Source: 基于项目 openGeneration 模式 + Completer 链设计
class FullscreenCommandQueue {
  final _queues = <int, _WindowQueue>{};

  Future<void> enqueue(int windowId, FullscreenRequest request) async {
    final queue = _queues.putIfAbsent(windowId, () => _WindowQueue());
    return queue.enqueue(request);
  }

  void dispose() {
    for (final queue in _queues.values) {
      queue.dispose();
    }
    _queues.clear();
  }
}

class _WindowQueue {
  Completer<void>? _inFlight;
  _PendingCommand? _pending;

  Future<void> enqueue(FullscreenRequest request) async {
    // 合并: 如果 pending 存在且目标相同，复用其 Completer
    if (_pending != null && _pending!.canMergeWith(request)) {
      return _pending!.completer.future;
    }

    final completer = Completer<void>();
    final command = _PendingCommand(request, completer);

    if (_inFlight != null) {
      // 有 in-flight: 替换 pending（最新 wins）
      _pending?.completer.complete(); // 完成旧 pending
      _pending = command;
      return completer.future;
    }

    // 无 in-flight: 立即执行
    await _execute(command);
  }

  Future<void> _execute(_PendingCommand command) async {
    _inFlight = command.completer;
    try {
      await command.execute(); // 实际执行
      command.completer.complete();
    } on Exception catch (e) {
      command.completer.completeError(e);
    } finally {
      _inFlight = null;
      // 消费 pending
      final next = _pending;
      _pending = null;
      if (next != null) await _execute(next);
    }
  }

  void dispose() {
    _pending?.completer.complete();
    _pending = null;
  }
}
```

### Pattern 2: 状态回读三级策略

**What:** 等回调 + 超时轮询的混合确认机制。

**When to use:** 原生操作完成后需要确认真实状态是否与目标一致。

**Example:**
```dart
// Source: 基于 D-19 决策 + windowManager API
Future<bool> _confirmState({
  required bool expectedFullscreen,
  required int windowId,
}) async {
  // Level 1: 等 WindowListener 回调（主路径）
  final confirmed = await _waitForCallback(
    expectedFullscreen: expectedFullscreen,
    timeout: const Duration(milliseconds: 500),
  );
  if (confirmed) return true;

  // Level 2: 短轮询 windowManager.isFullScreen()
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final actual = await windowManager.isFullScreen();
    if (actual == expectedFullscreen) return true;
  }

  // Level 3: 超时 — 最终 query 校正
  return false;
}
```

### Pattern 3: restoreMode 快照与恢复

**What:** 进入全屏前保存窗口模式+几何，退出时按 restoreMode 分支恢复。

**When to use:** 全屏退出后需要恢复到之前窗口状态的场景。

**Example:**
```dart
// Source: 基于 D-22/D-23/D-24/D-25 决策
class _RestoreSnapshot {
  final WindowMode mode;      // P1-7: 用 WindowMode 而非 FullscreenMode（maximized 是窗口状态不是全屏模式）
  final Offset position;
  final Size size;
  final int displayId;
  final bool isMaximized;     // P1-7: 独立标记，不混入 FullscreenMode
}

Future<void> _restoreWindow(_RestoreSnapshot snapshot) async {
  switch (snapshot.restoreMode) {
    case FullscreenMode.windowed:
      await windowManager.setBounds(
        null,
        position: snapshot.position,
        size: snapshot.size,
      );
    case FullscreenMode.borderless:
      // 不应出现在 restoreMode 中（borderless 是全屏模式）
      await windowManager.setBounds(
        null,
        position: snapshot.position,
        size: snapshot.size,
      );
    case FullscreenMode.exclusive:
      // v2 预留
      break;
  }

  // D-23: 如果之前是 maximized，调用 maximize() 恢复语义
  // （restoreMode 需要扩展为包含 maximized 状态，见建议调整）
}
```

### Anti-Patterns to Avoid

- **在入队时更新 phase:** 排队中的命令不应改变 phase，否则 UI 显示"正在切换"但实际在排队。D-16 已锁定：执行时才更新。
- **toggle 直接参与合并:** toggle 必须先解析为 setFullscreen(true/false) 再合并，否则 toggle+setFullscreen(true) 无法合并。D-18 已锁定。
- **使用 WindowBridge.mode 作回读依据:** mode 是缓存值，可能与原生状态不同步。D-21 已锁定用 windowManager.isFullScreen()。
- **fullscreen_window 和 windowManager.setFullScreen() 同时调用:** 两者都会修改窗口样式，同时调用会导致样式冲突。legacy 分支用 fullscreen_window，新分支用 windowManager。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 窗口几何查询 | 自建 FFI 调用 GetWindowRect | windowManager.getBounds() | 已有跨平台封装，返回 Rect |
| 全屏状态查询 | 自建 FFI 调用 IsZoomed | windowManager.isFullScreen() | 跨平台，返回 bool |
| 窗口最大化检测 | 自建 FFI 调用 IsZoomed | windowManager.isMaximized() | 跨平台 |
| 窗口最小化检测 | 自建 FFI | windowManager.isMinimized() | 跨平台 |
| Timer 管理 | 手动 Timer 生命周期 | 已有 WindowPersistence 模式参考 | 项目已有 debounce + write lock 模式 |

## Common Pitfalls

### Pitfall 1: fullscreen_window 与 windowManager API 冲突

**What goes wrong:** fullscreen_window 的 C++ 实现使用 `SetWindowLong(GWL_STYLE)` 修改窗口样式 + `SC_MAXIMIZE` 消息。windowManager 的 `setFullScreen()` 也修改窗口样式。两者同时调用会导致样式冲突或状态不一致。

**Why it happens:** 两个库各自管理窗口样式，互不知道对方的存在。

**How to avoid:** FullscreenAdapter 内部二选一：legacy 分支用 fullscreen_window，新分支用 windowManager.setFullScreen()。不要混用。

**Warning signs:** 全屏后窗口边框残留、退出全屏后窗口大小异常。

### Pitfall 2: WindowListener 回调时序不确定性

**What goes wrong:** `onWindowEnterFullScreen()`/`onWindowLeaveFullScreen()` 的触发时机因平台而异。Windows 上可能是同步的（SendMessage 返回后立即触发），macOS 上是异步的（系统动画完成后触发）。

**Why it happens:** 各平台窗口管理器的实现差异。

**How to avoid:** 不依赖回调的精确时序，使用三级确认策略（回调 + 轮询 + 超时）。回调只是加速路径，不是唯一确认手段。

**Warning signs:** macOS 上全屏操作偶尔超时。

### Pitfall 3: minimized 状态下全屏的两步操作竞态

**What goes wrong:** `restore()` 后立即 `setFullScreen(true)`，但 restore 可能还未完成（OS 动画），导致全屏命令作用在 minimized 窗口上。

**Why it happens:** restore() 和 setFullScreen() 都是异步的，中间可能有时序间隙。

**How to avoid:** restore() 完成后再调用 setFullScreen()。使用 await 串行执行，不要 unawaited。

**Warning signs:** minimized 状态按 F 键无反应或窗口闪烁。

### Pitfall 4: 副屏拔出后 setBounds 失败

**What goes wrong:** 退出全屏时尝试恢复到副屏位置，但副屏已不可用，setBounds 设置到不可见区域。

**Why it happens:** 显示器拓扑变化未被检测。

**How to avoid:** 恢复前检查 displayId 对应的显示器是否仍在 DisplayEnumerator.enumerateDisplays() 中。不可用时降级到主屏 center（D-24 已锁定）。

**Warning signs:** 退出全屏后窗口"消失"（在不可见区域）。

### Pitfall 5: openGeneration 式守卫与 Completer 链的交互

**What goes wrong:** 如果使用 openGeneration 计数器丢弃过期结果，但 Completer 链中的 pending 命令仍持有旧 Completer，可能导致 complete() 被调用两次或永远不被 complete。

**Why it happens:** 两种并发控制机制混用。

**How to avoid:** 命令队列内部统一使用 Completer 链，不混用 openGeneration。队列的 dispose 时 complete 所有 pending Completer。

**Warning signs:** 内存泄漏（Completer 未完成）、Future 永远 pending。

### Pitfall 6: snapshot 更新的线程安全

**What goes wrong:** ValueNotifier.notifyListeners() 必须在 UI 线程调用。如果命令队列的回调在 platform thread 触发（macOS/Linux），直接更新 ValueNotifier 会崩溃。

**Why it happens:** macOS/Linux 的 WindowListener 回调可能在 platform thread。

**How to avoid:** 复用 WindowService._updateOnUIThread() 模式：检查 SchedulerPhase，不在 idle 时用 addPostFrameCallback。

**Warning signs:** macOS 上全屏切换时崩溃。

## Code Examples

> ⚠️ **以下代码示例已被 02-01/02-02-PLAN.md 中的设计取代。**
> 以下已过时：单 `_callbackConfirm` Completer<void>（→ P0-1: `_confirmByWindowId` Map + `Completer<bool>`）、
> `_RestoreSnapshot` 用 `FullscreenMode restoreMode`（→ P1-7: `WindowMode mode` + `bool isMaximized`）、
> Adapter 内直接调用 `windowManager.xxx()` / `fullScreenWindow.xxx()`（→ P0-3: 全部通过 `_driver.xxx()` 转发）。
> 实现时以 PLAN.md 为准。

### Completer 链完整实现

```dart
// Source: 基于项目 openGeneration 模式 + Completer 链设计
import 'dart:async';

import '../models/fullscreen_request.dart';

/// 单窗口命令队列 — Completer 链实现。
///
/// 设计约束:
/// - 同一 windowId 只允许一个 in-flight 命令
/// - 待执行命令可合并（同 target + displayId）
/// - toggle 先解析为明确目标再参与合并
/// - dispose 时 complete 所有 pending Completer
class WindowCommandQueue {
  Completer<void>? _inFlight;
  _PendingCommand? _pending;
  bool _disposed = false;

  /// 入队命令。返回 Future 在命令执行完成时 resolve。
  ///
  /// 如果有 in-flight 命令：
  /// - 新命令与 pending 相同目标 → 复用 pending 的 Completer
  /// - 新命令与 pending 不同目标 → 替换 pending（最新 wins）
  Future<void> enqueue(
    FullscreenRequest request,
    Future<void> Function(FullscreenRequest) executor,
  ) async {
    if (_disposed) return;

    // 合并检查
    if (_pending != null && _pending!.canMergeWith(request)) {
      return _pending!.completer.future;
    }

    final completer = Completer<void>();
    final command = _PendingCommand(request, completer, executor);

    if (_inFlight != null) {
      // 有 in-flight: 替换 pending
      final old = _pending;
      _pending = command;
      old?.completer.complete(); // 完成旧 pending（避免泄漏）
      return completer.future;
    }

    // 无 in-flight: 立即执行
    await _execute(command);
    return completer.future;
  }

  Future<void> _execute(_PendingCommand command) async {
    _inFlight = command.completer;
    try {
      await command.executor(command.request);
      if (!command.completer.isCompleted) {
        command.completer.complete();
      }
    } on Exception catch (e) {
      if (!command.completer.isCompleted) {
        command.completer.completeError(e);
      }
    } finally {
      _inFlight = null;
      // 消费 pending
      final next = _pending;
      _pending = null;
      if (next != null && !_disposed) {
        await _execute(next);
      }
    }
  }

  /// 当前是否有 in-flight 命令。
  bool get isBusy => _inFlight != null;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending?.completer.complete();
    _pending = null;
  }
}

/// 待执行命令 — 携带请求、Completer 和执行器。
class _PendingCommand {
  _PendingCommand(this.request, this.completer, this.executor);

  final FullscreenRequest request;
  final Completer<void> completer;
  final Future<void> Function(FullscreenRequest) executor;

  /// 判断两个命令是否可合并。
  ///
  /// 合并规则 (D-17):
  /// 1. 同一 windowId
  /// 2. toggle 已解析为 setFullscreen(target)
  /// 3. target + displayId 相同
  bool canMergeWith(FullscreenRequest other) {
    if (request.windowId != other.windowId) return false;

    // 解析 toggle 为明确目标
    final thisTarget = _resolveTarget(request);
    final otherTarget = _resolveTarget(other);

    return thisTarget == otherTarget;
  }

  /// 解析命令为目标全屏状态。
  ///
  /// toggle 需要基于当前 snapshot 解析，但队列中无法访问 snapshot。
  /// 因此 toggle 在入队前必须已被 FullscreenAdapter 解析为
  /// EnterFullscreen 或 LeaveFullscreen。
  static (bool fullscreen, int displayId) _resolveTarget(
    FullscreenRequest request,
  ) {
    return switch (request) {
      EnterFullscreen(:final mode) => (true, 0), // displayId 从 request 获取
      LeaveFullscreen() => (false, 0),
      ToggleFullscreen() => throw StateError(
        'Toggle must be resolved before enqueueing',
      ),
    };
  }
}
```

### DesktopFullscreenAdapter 核心流程

```dart
// Source: 基于 D-12~D-31 决策 + windowManager API
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:window_manager/window_manager.dart';

import '../models/fullscreen_capability.dart';
import '../models/fullscreen_error.dart';
import '../models/fullscreen_event.dart';
import '../models/fullscreen_request.dart';
import '../models/fullscreen_snapshot.dart';
import 'fullscreen_adapter.dart';
import 'fullscreen_command_queue.dart';

/// 桌面平台全屏适配器 — Phase B 核心实现。
///
/// 组合:
/// - FullscreenCommandQueue: per-window 命令串行化
/// - windowManager: 窗口状态查询 + 几何操作
/// - fullscreen_window: 旧全屏实现（legacy 分支）
/// - WindowListener 回调: 状态确认
class DesktopFullscreenAdapter extends FullscreenAdapter {
  DesktopFullscreenAdapter();

  final _snapshots = <int, ValueNotifier<FullscreenSnapshot>>{};
  final _eventsController = StreamController<FullscreenEvent>.broadcast();
  final _commandQueue = FullscreenCommandQueue();
  final _restoreSnapshots = <int, _RestoreSnapshot>{};

  // D-19: 回调确认的 Completer
  Completer<void>? _callbackConfirm;
  Timer? _pollTimer;

  @override
  ValueNotifier<FullscreenSnapshot> snapshot([int windowId = 0]) {
    return _snapshots.putIfAbsent(
      windowId,
      () => ValueNotifier(const FullscreenSnapshot()),
    );
  }

  @override
  Stream<FullscreenEvent> get events => _eventsController.stream;

  @override
  Future<FullscreenCapability> capabilities() async {
    return const FullscreenCapability();
  }

  @override
  Future<void> setFullscreen(
    bool fullscreen, {
    int windowId = 0,
    FullscreenMode mode = FullscreenMode.borderless,
  }) async {
    final request = fullscreen
      ? FullscreenRequest.enter(mode: mode, windowId: windowId)
      : FullscreenRequest.leave(windowId: windowId);

    await _commandQueue.enqueue(
      windowId,
      request,
      (req) => _execute(req),
    );
  }

  @override
  Future<void> toggle({
    int windowId = 0,
    FullscreenMode? preferredMode,
  }) async {
    // D-18: toggle 先解析再入队
    final current = snapshot(windowId).value;
    final targetFullscreen = !current.isFullscreen;

    final request = targetFullscreen
      ? FullscreenRequest.enter(
          mode: preferredMode ?? FullscreenMode.borderless,
          windowId: windowId,
        )
      : FullscreenRequest.leave(windowId: windowId);

    await _commandQueue.enqueue(
      windowId,
      request,
      (req) => _execute(req),
    );
  }

  Future<void> _execute(FullscreenRequest request) async {
    final windowId = request.windowId;
    final notifier = snapshot(windowId);
    final current = notifier.value;

    // error 状态自动清理 (D-09)
    if (current.hasError) {
      notifier.value = current.copyWith(
        phase: FullscreenPhase.stable,
        clearError: true,
      );
    }

    final isEnter = request is EnterFullscreen;

    // D-16: 执行时才更新 phase
    notifier.value = notifier.value.copyWith(
      phase: isEnter ? FullscreenPhase.entering : FullscreenPhase.leaving,
    );

    // 发出事件
    if (isEnter) {
      _eventsController.add(EnterRequested(
        targetMode: request.mode,
      ));
    } else {
      _eventsController.add(LeaveRequested());
    }

    // D-22: 仅在 enter 时快照 restoreMode
    if (isEnter && !_restoreSnapshots.containsKey(windowId)) {
      await _snapshotRestoreState(windowId);
    }

    // RST-04: minimized 先 restore
    if (isEnter) {
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
        // 等待 restore 完成
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    // 调用原生
    try {
      if (isEnter) {
        await fullScreenWindow.setFullScreen(true);
      } else {
        await fullScreenWindow.setFullScreen(false);
        // 退出全屏后恢复窗口几何
        await _restoreWindow(windowId);
      }
    } on Exception catch (e) {
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.error,
        lastError: PlatformFailure('Native call failed', e),
      );
      _eventsController.add(FullscreenErrorEvent(
        error: PlatformFailure('Native call failed', e),
      ));
      return;
    }

    // D-19: 三级确认
    final expectedFullscreen = isEnter;
    final confirmed = await _confirmState(
      expectedFullscreen: expectedFullscreen,
      windowId: windowId,
    );

    if (confirmed) {
      // 成功
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.stable,
        effectiveMode: isEnter
          ? (request as EnterFullscreen).mode
          : FullscreenMode.windowed,
      );
      if (isEnter) {
        _eventsController.add(Entered(
          finalMode: (request as EnterFullscreen).mode,
        ));
      } else {
        _eventsController.add(Left());
      }
    } else {
      // D-20: StateDesync — 报错 + snapshot 更新为真实状态
      final actualFullscreen = await windowManager.isFullScreen();
      final actualMode = actualFullscreen
        ? FullscreenMode.borderless
        : FullscreenMode.windowed;

      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.error,
        effectiveMode: actualMode,
        lastError: StateDesync(
          expected: isEnter
            ? FullscreenMode.borderless
            : FullscreenMode.windowed,
          actual: actualMode,
        ),
      );
      _eventsController.add(FullscreenErrorEvent(
        error: StateDesync(
          expected: isEnter
            ? FullscreenMode.borderless
            : FullscreenMode.windowed,
          actual: actualMode,
        ),
      ));
    }
  }

  /// D-19: 三级状态确认。
  Future<bool> _confirmState({
    required bool expectedFullscreen,
    required int windowId,
  }) async {
    // Level 1: 等 WindowListener 回调
    _callbackConfirm = Completer<void>();
    final callbackResult = await _callbackConfirm!.future
      .timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      );
    _callbackConfirm = null;

    if (callbackResult != null) return true;

    // Level 2: 短轮询
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final actual = await windowManager.isFullScreen();
      if (actual == expectedFullscreen) return true;
    }

    // Level 3: 超时
    return false;
  }

  /// WindowListener 回调入口 — 由 WindowService 转发。
  void onNativeFullScreenChanged(bool isFullscreen) {
    _callbackConfirm?.complete();
  }

  /// D-22: 快照当前窗口状态用于恢复。
  Future<void> _snapshotRestoreState(int windowId) async {
    // 判断当前模式
    final isMaximized = await windowManager.isMaximized();
    final bounds = await windowManager.getBounds();

    _restoreSnapshots[windowId] = _RestoreSnapshot(
      mode: isMaximized ? WindowMode.maximized : WindowMode.windowed,  // P1-7: 统一用 WindowMode
      isMaximized: isMaximized,  // P1-7: 独立标记
      position: Offset(bounds.left, bounds.top),
      size: Size(bounds.width, bounds.height),
      displayId: 0, // Phase C 实现真实 displayId
    );
  }

  /// D-23/D-24: 退出全屏后恢复窗口。
  Future<void> _restoreWindow(int windowId) async {
    final snapshot = _restoreSnapshots.remove(windowId);
    if (snapshot == null) return;

    // D-23: maximized 恢复调用 maximize()
    if (snapshot.restoreMode == FullscreenMode.borderless) {
      // 这里需要一个 maximized 标志，见建议调整
      await windowManager.maximize();
      return;
    }

    // D-24: 副屏恢复用 setBounds
    try {
      await windowManager.setBounds(
        null,
        position: snapshot.position,
        size: snapshot.size,
      );
    } on Exception catch (e) {
      // 降级: 主屏 center
      debugPrint('[FullscreenAdapter] Restore failed, centering: $e');
      await windowManager.center();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _callbackConfirm?.complete();
    _commandQueue.dispose();
    for (final notifier in _snapshots.values) {
      notifier.dispose();
    }
    _snapshots.clear();
    _eventsController.close();
  }
}

/// 恢复快照 — 退出全屏时恢复窗口几何。
class _RestoreSnapshot {
  const _RestoreSnapshot({
    required this.restoreMode,
    required this.position,
    required this.size,
    required this.displayId,
  });

  final FullscreenMode restoreMode;
  final Offset position;
  final Size size;
  final int displayId;
}
```

### 编译时 flag 模式

```dart
// Source: lib/main.dart 已有 USE_MOCK_ENGINE 模式
const bool _useNewFullscreen = bool.fromEnvironment(
  'USE_NEW_FULLSCREEN',
  defaultValue: false,
);
```

## Runtime State Inventory

> Phase B 是功能实现阶段，不涉及 rename/refactor。此节记录需要关注的运行时状态。

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | SettingsStore.saveIsFullscreen() 持久化全屏状态 | 不变 — FullscreenAdapter 内部调用 |
| Live service config | WindowService._state.mode 是当前 mode SSOT | Phase B 保持同步: FullscreenAdapter 更新 snapshot 时同步更新 WindowService.mode |
| OS-registered state | fullscreen_window 的 C++ 全局变量 g_saved_window_info | 不变 — fullscreen_window 内部管理 |
| Secrets/env vars | USE_NEW_FULLSCREEN 编译时 flag | 新增，无已有冲突 |
| Build artifacts | 无 | — |

**关键同步点:** WindowService.mode 和 FullscreenSnapshot 是两个独立状态源。Phase B 需要确保两者一致：FullscreenAdapter 更新 snapshot 时，同时更新 WindowService.mode（通过 WindowBridge 接口）。

## Common Pitfalls (补充)

### Pitfall 7: FullscreenSnapshot 与 WindowService.mode 双源不一致

**What goes wrong:** UI 同时监听 FullscreenSnapshot.isFullscreen 和 WindowService.mode.isFullscreen，两者更新时序不同导致 UI 闪烁或逻辑矛盾。

**Why it happens:** 两个独立的 ValueNotifier，更新时机不同。

**How to avoid:** Phase B 过渡期：FullscreenAdapter 更新 snapshot 后，立即同步更新 WindowService.mode。长期：UI 层只依赖 FullscreenAdapter.snapshot，不再读取 WindowService.mode 的 fullscreen 相关状态。

**Warning signs:** 全屏切换后控制栏状态不一致。

### Pitfall 8: dispose 时 Completer 泄漏

**What goes wrong:** 命令队列 dispose 时，in-flight 的 Completer 未被 complete，导致 await 永远 pending。

**Why it happens:** dispose 只清理了 pending，没有处理 in-flight。

**How to avoid:** dispose 时 complete 所有 pending Completer。in-flight 的 Completer 由 _execute 的 finally 块处理（但需要检查 _disposed 标志）。

**Warning signs:** 内存泄漏，Timer 持续触发。

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WindowService.setMode(fullscreen) 直调 fullscreen_window | FullscreenAdapter 命令队列 + 状态机 | Phase B | 串行化、幂等合并、状态确认 |
| WindowListener.onWindowEnterFullScreen 直接更新 mode.value | FullscreenAdapter 三级确认 + snapshot 更新 | Phase B | 状态回读准确，StateDesync 可检测 |
| 无恢复策略（全屏退出后窗口大小可能异常） | restoreMode 快照 + 分支恢复 | Phase B | RST-01~04 全覆盖 |
| UI 层通过 WindowService.mode.isFullscreen 判断 | UI 层通过 FullscreenAdapter.snapshot.isFullscreen 判断 | Phase B~后续 | 单一真相源 |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | windowManager.isFullScreen() 在 Windows 上返回 true 当窗口覆盖整个屏幕（SC_MAXIMIZE 方式） | 状态回读 | 低 — window_manager 内部检查 WS_MAXIMIZE 样式或窗口几何 |
| A2 | fullscreen_window 的 SC_MAXIMIZE 消息会触发 onWindowMaximize() 回调 | WindowListener | 中 — 如果不触发，需要其他方式确认全屏状态 |
| A3 | windowManager.getBounds() 在全屏状态下返回屏幕尺寸而非窗口原始尺寸 | 恢复快照 | 低 — getBounds 返回当前窗口 rect，全屏时即屏幕尺寸 |
| A4 | windowManager.restore() 从 minimized 状态恢复后窗口可见 | RST-04 | 低 — restore() 是标准 API |
| A5 | DisplayEnumerator.getCurrentDisplay() 返回的 displayId 可用于判断窗口在哪个显示器 | RST-03 | 中 — Phase C 实现真实 displayId，Phase B 可用 position 推断 |

## Open Questions (RESOLVED)

1. **FullscreenMode 缺少 maximized 值** (RESOLVED)
   - Decision: 在 _RestoreSnapshot 内部保存 `bool isMaximized` 独立标志，不修改 FullscreenMode 枚举。FullscreenSnapshot.restoreMode 仍用 FullscreenMode.windowed 表示非全屏状态，isMaximized 作为恢复时的分支条件。
   - Rationale: FullscreenMode 描述全屏模式（windowed/borderless/exclusive），maximized 是窗口状态而非全屏模式，不应混入枚举。

2. **fullscreen_window 的 SC_MAXIMIZE 是否触发 onWindowMaximize()** (RESOLVED)
   - Decision: 不依赖回调确认，直接走轮询路径（Level 2: windowManager.isFullScreen()）。回调作为加速路径，但不作为唯一确认手段。
   - Rationale: SC_MAXIMIZE 的回调行为因平台版本而异，三级确认策略（D-19）已覆盖此场景，无需额外依赖回调。

3. **WindowService.mode 与 FullscreenSnapshot 的同步机制** (RESOLVED)
   - Decision: 单向同步 — FullscreenAdapter 更新 snapshot 后，通过内部调用 windowManager 方法触发 WindowListener 回调，由 WindowService 自然更新 mode。不显式调用 WindowBridge.setMode()。
   - Rationale: windowManager 的原生操作（setFullScreen/maximize/restore）会触发 WindowListener 回调，WindowService 已有回调处理逻辑，无需额外同步代码。

4. **副屏 displayId 获取方式** (RESOLVED)
   - Decision: Phase B 用 `windowManager.getPosition()` + `DisplayEnumerator.enumerateDisplays()` 推断当前显示器索引。displayId 字段暂用 0（单窗口场景）。Phase C 实现真实 displayId。
   - Rationale: DisplayEnumerator 已有 enumerateDisplays() 方法返回显示器列表，可通过位置匹配推断。Phase B 的 RST-03 副屏恢复用 position+size 快照即可，不需要真实 displayId。

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| window_manager | 窗口状态查询 + 几何操作 | ✓ | locked in pubspec.lock | — |
| fullscreen_window | 旧全屏实现 | ✓ | local package | — |
| DisplayEnumerator | 副屏检测 | ✓ | Win32DisplayAdapter | — |
| dart:async (Completer) | 命令队列 | ✓ | SDK | — |

**Missing dependencies with no fallback:** 无

**Missing dependencies with fallback:** 无

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | analysis_options.yaml |
| Quick run command | `flutter test test/kernel/bridge/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CMD-01 | per-window 命令串行化 | unit | `flutter test test/kernel/bridge/fullscreen_command_queue_test.dart` | Wave 0 |
| CMD-02 | 连续相同目标命令合并 | unit | `flutter test test/kernel/bridge/fullscreen_command_queue_test.dart` | Wave 0 |
| CMD-03 | 状态回读 + StateDesync | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | Wave 0 |
| RST-01 | windowed 恢复 | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | Wave 0 |
| RST-02 | maximized 恢复 | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | Wave 0 |
| RST-03 | 副屏恢复 | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | Wave 0 |
| RST-04 | minimized 先 restore | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | Wave 0 |
| ARCH-03 | 迁移调用点 | integration | `flutter test test/kernel/bridge/window_service_test.dart` | ✅ exists |

### Sampling Rate
- **Per task commit:** `flutter test test/kernel/bridge/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/kernel/bridge/fullscreen_command_queue_test.dart` — covers CMD-01, CMD-02
- [ ] `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` — covers CMD-03, RST-01~04

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | 窗口命令不涉及用户输入验证 |
| V6 Cryptography | no | — |

全屏命令队列不涉及安全敏感操作。无 ASVS 类别适用。

## Sources

### Primary (HIGH confidence)
- Context7: /leanflutter/window_manager — isFullScreen, setFullScreen, getBounds, setBounds, maximize, restore, WindowListener API
- 项目源码: lib/kernel/bridge/window_service.dart — 当前全屏实现，仅 1 处 fullscreen_window 调用
- 项目源码: packages/fullscreen_window/windows/fullscreen_window_plugin.cpp — C++ 原生实现，SC_MAXIMIZE 方式
- 项目源码: lib/features/player/services/playback_navigator.dart — openGeneration 并发守卫模式

### Secondary (MEDIUM confidence)
- 项目记忆: project_fullscreen_bugs.md — 5 个全屏 bug 修复经验
- 项目记忆: anti_pattern_fullscreen_ffi.md — 禁止 win32 包的反面教训

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — window_manager 和 fullscreen_window 均为项目已集成依赖
- Architecture: HIGH — Completer 链模式是 Dart 标准并发模式，项目已有 openGeneration 参考
- Pitfalls: MEDIUM — fullscreen_window 与 windowManager 的交互行为需要实测验证

**Research date:** 2026-07-09
**Valid until:** 2026-07-23 (14 days — 涉及 window_manager API 行为假设，需实测确认)
