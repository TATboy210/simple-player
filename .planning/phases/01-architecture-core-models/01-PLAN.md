---
phase: 01-architecture-core-models
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/kernel/models/fullscreen_snapshot.dart
  - lib/kernel/models/fullscreen_event.dart
  - lib/kernel/models/fullscreen_error.dart
  - lib/kernel/models/fullscreen_capability.dart
  - lib/kernel/models/fullscreen_request.dart
  - lib/kernel/bridge/fullscreen_adapter.dart
  - test/kernel/bridge/fullscreen_adapter_test.dart
autonomous: true
requirements: [STATE-01, STATE-02, STATE-03, EVT-01, EVT-02, EVT-03, ERR-01, ERR-02, ERR-03, ARCH-01, ARCH-02]

must_haves:
  truths:
    - FullscreenAdapter 接口独立于 WindowBridge，UI 层只依赖此接口
    - FullscreenSnapshot 采用单一 ValueNotifier 包装不可变数据类 + copyWith 模式
    - phase 状态机为 5 状态线性机: stable ↔ entering/leaving + forcedChange + error
    - FullscreenEvent 流使用 StreamController.broadcast()，不耦合 _WindowListener
    - FullscreenError 采用 sealed class，7 种错误类型可携带上下文字段
    - per-window 状态容器 Map<int, ValueNotifier<FullscreenSnapshot>>，单窗口 defaultWindowId = 0
    - error 不是锁死态，下一次合法操作自动清理为 stable
  artifacts:
    - lib/kernel/models/fullscreen_snapshot.dart
    - lib/kernel/models/fullscreen_event.dart
    - lib/kernel/models/fullscreen_error.dart
    - lib/kernel/models/fullscreen_capability.dart
    - lib/kernel/models/fullscreen_request.dart
    - lib/kernel/bridge/fullscreen_adapter.dart
    - test/kernel/bridge/fullscreen_adapter_test.dart
  key_links:
    - FullscreenAdapter.snapshot(windowId) 返回 ValueNotifier<FullscreenSnapshot>
    - FullscreenAdapter.events 返回 Stream<FullscreenEvent>
    - FullscreenAdapter.toggle() / setFullscreen(bool) 为命令入口
    - WindowBridge 继续保留通用窗口操作（setAlwaysOnTop/setAspectRatio/minimize/close）

---

<objective>
Phase A: 建立 FullscreenAdapter 抽象层、状态模型、事件流和错误模型。

Purpose: 使全屏成为有状态、有事件、有错误模型的独立核心能力模块。UI 层将只依赖 FullscreenAdapter 接口，不再直接调用 fullscreen_window 插件或依赖 WindowBridge 的全屏相关方法。
Output: 5 个数据模型文件 + 1 个抽象接口文件 + 1 个测试文件。本阶段只定义接口和数据模型，不实现命令队列（Phase B）和平台适配（Phase C）。
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-architecture-core-models/01-CONTEXT.md
@lib/kernel/bridge/window_bridge.dart
@lib/kernel/bridge/window_state.dart
@lib/kernel/bridge/window_mode.dart
@lib/kernel/bridge/window_service.dart
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: FullscreenPhase 枚举 + FullscreenSnapshot 数据模型</name>
  <files>lib/kernel/models/fullscreen_snapshot.dart, test/kernel/bridge/fullscreen_adapter_test.dart</files>

  <read_first>
    lib/kernel/bridge/window_state.dart
    lib/kernel/bridge/window_mode.dart
    lib/kernel/models/playlist_item.dart
  </read_first>

  <behavior>
    - Test: FullscreenPhase 有 5 个值: stable, entering, leaving, forcedChange, error
    - Test: FullscreenSnapshot 默认构造创建 stable/非全屏状态
    - Test: FullscreenSnapshot.copyWith 返回新实例，原实例不变
    - Test: FullscreenSnapshot.copyWith 只修改指定字段
    - Test: FullscreenSnapshot 相等性基于值比较
    - Test: FullscreenSnapshot.isFullscreen 为 true 当 phase == stable 且 effectiveMode != windowed
  </behavior>

  <action>
创建 `lib/kernel/models/fullscreen_snapshot.dart`:

1. **FullscreenPhase 枚举** — 5 状态:
   ```dart
   /// 全屏过渡阶段 — 状态机核心。
   ///
   /// 转换路径: stable ↔ entering/leaving, stable → forcedChange → stable,
   /// 任意状态 → error → stable (下次合法操作自动清理)
   enum FullscreenPhase {
     /// 稳态 — 无进行中的过渡。
     stable,

     /// 正在进入全屏。
     entering,

     /// 正在退出全屏。
     leaving,

     /// OS 外部强制变更（如系统快捷键、窗口管理器）。
     forcedChange,

     /// 上次操作出错 — 下次合法操作自动清理。
     error,
   }
   ```

2. **FullscreenMode 枚举** — 全屏模式:
   ```dart
   /// 全屏模式 — 区分普通全屏和独占全屏。
   enum FullscreenMode {
     /// 非全屏。
     windowed,

     /// 无边框全屏（当前实现）。
     borderless,

     /// 独占全屏（预留 v2）。
     exclusive,
   }
   ```

3. **FullscreenSnapshot 不可变数据类**:
   ```dart
   /// 全屏状态快照 — 单一 ValueNotifier 包装的不可变数据。
   ///
   /// 设计约束:
   /// - 纯数据类，不含业务逻辑
   /// - 不可变（final class + final fields）
   /// - copyWith 返回新实例
   /// - 与 WindowState 独立共存，渐进迁移
   final class FullscreenSnapshot {
     const FullscreenSnapshot({
       this.phase = FullscreenPhase.stable,
       this.effectiveMode = FullscreenMode.windowed,
       this.restoreMode = FullscreenMode.windowed,
       this.displayId = 0,
       this.lastError,
     });

     /// 当前过渡阶段。
     final FullscreenPhase phase;

     /// 实际生效的全屏模式。
     final FullscreenMode effectiveMode;

     /// 全屏前的窗口模式 — 退出时恢复目标。
     final FullscreenMode restoreMode;

     /// 当前显示器 ID（多显示器预留）。
     final int displayId;

     /// 最近一次错误（error phase 时非 null）。
     final FullscreenError? lastError;

     /// 是否处于稳定全屏状态。
     bool get isFullscreen =>
         phase == FullscreenPhase.stable &&
         effectiveMode != FullscreenMode.windowed;

     /// 是否正在过渡中。
     bool get isTransitioning =>
         phase == FullscreenPhase.entering ||
         phase == FullscreenPhase.leaving;

     /// 是否处于错误状态。
     bool get hasError => phase == FullscreenPhase.error;

     /// 创建副本 — 只修改指定字段。
     FullscreenSnapshot copyWith({
       FullscreenPhase? phase,
       FullscreenMode? effectiveMode,
       FullscreenMode? restoreMode,
       int? displayId,
       FullscreenError? lastError,
       bool clearError = false,
     }) { ... }

     @override
     bool operator ==(Object other) { ... }

     @override
     int get hashCode { ... }
   }
   ```

关键实现细节:
- `clearError` 参数: 当设置为 true 时，copyWith 将 lastError 设为 null（用于 error → stable 清理）
- 默认构造函数创建 `stable + windowed + windowed + displayId=0 + no error`
- `isFullscreen` 只在 stable phase 且非 windowed 时为 true（transition 中不算全屏）
- 复用 PlaylistItem 的值比较模式

Per D-01: 单一 ValueNotifier 包装不可变数据类，与 WindowState 模式一致。
Per D-02: 5 状态线性机。
Per D-03: 与 WindowState 独立共存。
  </action>

  <verify>
    <automated>flutter test test/kernel/bridge/fullscreen_adapter_test.dart || true; flutter analyze lib/kernel/models/fullscreen_snapshot.dart</automated>
  </verify>

  <acceptance_criteria>
    - `lib/kernel/models/fullscreen_snapshot.dart` 存在并导出 FullscreenPhase, FullscreenMode, FullscreenSnapshot
    - FullscreenPhase 有 5 个值: stable, entering, leaving, forcedChange, error
    - FullscreenMode 有 3 个值: windowed, borderless, exclusive
    - FullscreenSnapshot 有 phase, effectiveMode, restoreMode, displayId, lastError 字段
    - copyWith 返回新实例，原实例不变
    - isFullscreen 在 stable + 非 windowed 时为 true
    - isTransitioning 在 entering/leaving 时为 true
    - clearError 参数可清理 lastError
    - flutter analyze 通过
  </acceptance_criteria>

  <done>
    FullscreenPhase 枚举 + FullscreenMode 枚举 + FullscreenSnapshot 不可变数据类完成，测试通过。
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: FullscreenError sealed class</name>
  <files>lib/kernel/models/fullscreen_error.dart, test/kernel/bridge/fullscreen_adapter_test.dart</files>

  <read_first>
    lib/kernel/models/fullscreen_snapshot.dart (Task 1 产出)
  </read_first>

  <behavior>
    - Test: FullscreenError 是 sealed class
    - Test: Unsupported 有 message 字段
    - Test: InvalidWindow 有 windowId 字段
    - Test: PermissionDenied 有 reason 字段
    - Test: BusyTransition 有 currentPhase 字段
    - Test: PlatformFailure 有 platformMessage 和原始错误
    - Test: RestoreFailure 有 attemptedMode 字段
    - Test: StateDesync 有 expected 和 actual 字段
    - Test: FullscreenError 可用于 FullscreenSnapshot.lastError
  </behavior>

  <action>
创建 `lib/kernel/models/fullscreen_error.dart`:

```dart
/// 全屏操作错误 — sealed class 设计，7 种类型可携带上下文。
///
/// 设计约束:
/// - 每种错误类型携带足够的诊断上下文
/// - error 不是锁死态，下次合法操作自动清理
/// - UI 对 PermissionDenied 和 Unsupported 有明确用户提示
sealed class FullscreenError {
  const FullscreenError();

  /// 平台不支持全屏（如 Web 无用户手势）。
  const factory FullscreenError.unsupported(String message) = Unsupported;

  /// 窗口句柄无效。
  const factory FullscreenError.invalidWindow(int windowId) = InvalidWindow;

  /// 权限拒绝（如 Web 手势限制）。
  const factory FullscreenError.permissionDenied(String reason) = PermissionDenied;

  /// 过渡忙 — 上一个操作尚未完成。
  const factory FullscreenError.busyTransition(FullscreenPhase currentPhase) = BusyTransition;

  /// 平台原生调用失败。
  const factory FullscreenError.platformFailure(
    String platformMessage,
    Object? originalError,
  ) = PlatformFailure;

  /// 退出全屏后恢复失败。
  const factory FullscreenError.restoreFailure(FullscreenMode attemptedMode) = RestoreFailure;

  /// 状态不同步 — 回读状态与预期不一致。
  const factory FullscreenError.stateDesync({
    required FullscreenMode expected,
    required FullscreenMode actual,
  }) = StateDesync;
}

/// 平台不支持全屏。
final class Unsupported extends FullscreenError {
  const Unsupported(this.message);
  final String message;
}

/// 窗口句柄无效。
final class InvalidWindow extends FullscreenError {
  const InvalidWindow(this.windowId);
  final int windowId;
}

/// 权限拒绝。
final class PermissionDenied extends FullscreenError {
  const PermissionDenied(this.reason);
  final String reason;
}

/// 过渡忙。
final class BusyTransition extends FullscreenError {
  const BusyTransition(this.currentPhase);
  final FullscreenPhase currentPhase;
}

/// 平台原生调用失败。
final class PlatformFailure extends FullscreenError {
  const PlatformFailure(this.platformMessage, [this.originalError]);
  final String platformMessage;
  final Object? originalError;
}

/// 退出全屏后恢复失败。
final class RestoreFailure extends FullscreenError {
  const RestoreFailure(this.attemptedMode);
  final FullscreenMode attemptedMode;
}

/// 状态不同步。
final class StateDesync extends FullscreenError {
  const StateDesync({required this.expected, required this.actual});
  final FullscreenMode expected;
  final FullscreenMode actual;
}
```

关键实现细节:
- 使用 Dart 3 sealed class，每个子类是 final class
- 工厂构造函数提供简洁的创建语法: `FullscreenError.unsupported('...')`
- StateDesync 携带 expected vs actual 用于诊断
- PlatformFailure 携带原始错误用于日志
- BusyTransition 携带 currentPhase 用于调试
- 需要在文件顶部导入 fullscreen_snapshot.dart（因为 BusyTransition 引用 FullscreenPhase）

Per D-08: sealed class 设计，7 种错误类型各自可携带上下文字段。
Per D-09: error 不是锁死态，重试即恢复。
  </action>

  <verify>
    <automated>flutter test test/kernel/bridge/fullscreen_adapter_test.dart || true; flutter analyze lib/kernel/models/fullscreen_error.dart</automated>
  </verify>

  <acceptance_criteria>
    - `lib/kernel/models/fullscreen_error.dart` 存在并导出 7 个错误类型
    - FullscreenError 是 sealed class
    - 每种错误类型有预期的上下文字段
    - 可用于 FullscreenSnapshot.lastError 字段
    - flutter analyze 通过
  </acceptance_criteria>

  <done>
    FullscreenError sealed class 完成，7 种错误类型各自携带诊断上下文。
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: FullscreenEvent 事件模型</name>
  <files>lib/kernel/models/fullscreen_event.dart, test/kernel/bridge/fullscreen_adapter_test.dart</files>

  <read_first>
    lib/kernel/models/fullscreen_snapshot.dart (Task 1)
    lib/kernel/models/fullscreen_error.dart (Task 2)
  </read_first>

  <behavior>
    - Test: FullscreenEvent 有 7 个子类型
    - Test: enterRequested 携带 targetMode
    - Test: entered 携带 finalMode
    - Test: leaveRequested 无额外字段
    - Test: left 无额外字段
    - Test: forcedChange 携带 previousMode 和 actualMode
    - Test: syncCorrected 携带 expected 和 actual
    - Test: error 携带 FullscreenError
    - Test: 所有事件携带 timestamp
  </behavior>

  <action>
创建 `lib/kernel/models/fullscreen_event.dart`:

```dart
/// 全屏生命周期事件 — 业务层通过 Stream<FullscreenEvent> 监听。
///
/// 设计约束:
/// - 与 _WindowListener 解耦，Adapter 内部转换原生事件
/// - 每个事件携带 timestamp 用于调试和排序
/// - forcedChange 携带差异信息用于诊断
sealed class FullscreenEvent {
  const FullscreenEvent({required this.timestamp});

  /// 事件发生时间。
  final DateTime timestamp;

  /// 请求进入全屏。
  const factory FullscreenEvent.enterRequested({
    required FullscreenMode targetMode,
    DateTime? timestamp,
  }) = EnterRequested;

  /// 已成功进入全屏。
  const factory FullscreenEvent.entered({
    required FullscreenMode finalMode,
    DateTime? timestamp,
  }) = Entered;

  /// 请求退出全屏。
  const factory FullscreenEvent.leaveRequested({
    DateTime? timestamp,
  }) = LeaveRequested;

  /// 已成功退出全屏。
  const factory FullscreenEvent.left({
    DateTime? timestamp,
  }) = Left;

  /// OS 外部强制变更（系统快捷键、窗口管理器）。
  const factory FullscreenEvent.forcedChange({
    required FullscreenMode previousMode,
    required FullscreenMode actualMode,
    DateTime? timestamp,
  }) = ForcedChange;

  /// 状态校正 — 回读与预期不一致时发出。
  const factory FullscreenEvent.syncCorrected({
    required FullscreenMode expected,
    required FullscreenMode actual,
    DateTime? timestamp,
  }) = SyncCorrected;

  /// 操作出错。
  const factory FullscreenEvent.error({
    required FullscreenError error,
    DateTime? timestamp,
  }) = FullscreenErrorEvent;
}

/// 请求进入全屏。
final class EnterRequested extends FullscreenEvent {
  const EnterRequested({required this.targetMode, DateTime? timestamp})
      : super(timestamp: timestamp ?? _defaultTimestamp);
  final FullscreenMode targetMode;
}

/// 已成功进入全屏。
final class Entered extends FullscreenEvent {
  const Entered({required this.finalMode, DateTime? timestamp})
      : super(timestamp: timestamp ?? _defaultTimestamp);
  final FullscreenMode finalMode;
}

/// 请求退出全屏。
final class LeaveRequested extends FullscreenEvent {
  const LeaveRequested({DateTime? timestamp})
      : super(timestamp: timestamp ?? _defaultTimestamp);
}

/// 已成功退出全屏。
final class Left extends FullscreenEvent {
  const Left({DateTime? timestamp})
      : super(timestamp: timestamp ?? _defaultTimestamp);
}

/// OS 外部强制变更。
final class ForcedChange extends FullscreenEvent {
  const ForcedChange({
    required this.previousMode,
    required this.actualMode,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? _defaultTimestamp);
  final FullscreenMode previousMode;
  final FullscreenMode actualMode;
}

/// 状态校正。
final class SyncCorrected extends FullscreenEvent {
  const SyncCorrected({
    required this.expected,
    required this.actual,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? _defaultTimestamp);
  final FullscreenMode expected;
  final FullscreenMode actual;
}

/// 操作出错。
final class FullscreenErrorEvent extends FullscreenEvent {
  const FullscreenErrorEvent({required this.error, DateTime? timestamp})
      : super(timestamp: timestamp ?? _defaultTimestamp);
  final FullscreenError error;
}

/// 默认时间戳 — 使用 DateTime.now()，测试中可通过参数覆盖。
DateTime get _defaultTimestamp => DateTime.now();
```

关键实现细节:
- sealed class + 工厂构造函数，与 FullscreenError 一致
- 每个事件携带 timestamp，默认 DateTime.now()，测试可覆盖
- EnterRequested 携带 targetMode（borderless vs exclusive）
- Entered 携带 finalMode（实际生效模式，可能与请求不同）
- ForcedChange 携带 previousMode + actualMode（差异信息）
- SyncCorrected 携带 expected + actual（回读校正）
- FullscreenErrorEvent 命名避免与 FullscreenError 冲突

Per D-06: StreamController.broadcast() 实现（在 Adapter 中，此处只定义事件类型）。
Per D-07: Adapter 内部转换原生事件为 FullscreenEvent。
Per EVT-01: 7 种事件类型。
Per EVT-03: forcedChange 携带差异信息。
  </action>

  <verify>
    <automated>flutter test test/kernel/bridge/fullscreen_adapter_test.dart || true; flutter analyze lib/kernel/models/fullscreen_event.dart</automated>
  </verify>

  <acceptance_criteria>
    - `lib/kernel/models/fullscreen_event.dart` 存在并导出 7 个事件类型
    - FullscreenEvent 是 sealed class
    - 每个事件有 timestamp 字段
    - enterRequested 携带 targetMode
    - entered 携带 finalMode
    - forcedChange 携带 previousMode + actualMode
    - error 携带 FullscreenError
    - flutter analyze 通过
  </acceptance_criteria>

  <done>
    FullscreenEvent sealed class 完成，7 种事件类型各自携带上下文。
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: FullscreenCapability + FullscreenRequest 数据模型</name>
  <files>lib/kernel/models/fullscreen_capability.dart, lib/kernel/models/fullscreen_request.dart, test/kernel/bridge/fullscreen_adapter_test.dart</files>

  <read_first>
    lib/kernel/models/fullscreen_snapshot.dart (Task 1)
  </read_first>

  <behavior>
    - Test: FullscreenCapability 描述平台支持的能力
    - Test: FullscreenRequest 有 enter/leave/toggle 三种工厂
    - Test: enter 请求携带 targetMode
    - Test: toggle 请求可携带 preferredMode
  </behavior>

  <action>
创建 `lib/kernel/models/fullscreen_capability.dart`:

```dart
/// 平台全屏能力查询结果 — 每平台返回真实能力。
///
/// 用于 UI 决定是否显示全屏按钮、是否允许多窗口全屏等。
final class FullscreenCapability {
  const FullscreenCapability({
    this.supportsFullscreen = true,
    this.supportsMultiWindow = false,
    this.supportsMultiDisplay = false,
    this.supportsExclusive = false,
    this.requiresUserGesture = false,
    this.platformNotes,
  });

  /// 平台是否支持全屏。
  final bool supportsFullscreen;

  /// 是否支持多窗口同时全屏。
  final bool supportsMultiWindow;

  /// 是否支持指定显示器全屏。
  final bool supportsMultiDisplay;

  /// 是否支持独占全屏模式。
  final bool supportsExclusive;

  /// 是否需要用户手势触发（Web 限制）。
  final bool requiresUserGesture;

  /// 平台特定说明（如 macOS 全屏动画行为）。
  final String? platformNotes;
}
```

创建 `lib/kernel/models/fullscreen_request.dart`:

```dart
/// 全屏操作请求 — 命令队列的输入类型。
///
/// 设计约束:
/// - 不可变值对象
/// - 工厂构造函数提供语义化创建
/// - Phase B 命令队列使用此类型作为入参
sealed class FullscreenRequest {
  const FullscreenRequest({required this.windowId});

  /// 目标窗口 ID（单窗口默认 0）。
  final int windowId;

  /// 进入全屏。
  const factory FullscreenRequest.enter({
    FullscreenMode mode = FullscreenMode.borderless,
    int windowId = 0,
  }) = EnterFullscreen;

  /// 退出全屏。
  const factory FullscreenRequest.leave({
    int windowId = 0,
  }) = LeaveFullscreen;

  /// 切换全屏状态。
  const factory FullscreenRequest.toggle({
    FullscreenMode? preferredMode,
    int windowId = 0,
  }) = ToggleFullscreen;
}

/// 进入全屏请求。
final class EnterFullscreen extends FullscreenRequest {
  const EnterFullscreen({this.mode = FullscreenMode.borderless, super.windowId});
  final FullscreenMode mode;
}

/// 退出全屏请求。
final class LeaveFullscreen extends FullscreenRequest {
  const LeaveFullscreen({super.windowId});
}

/// 切换全屏请求。
final class ToggleFullscreen extends FullscreenRequest {
  const ToggleFullscreen({this.preferredMode, super.windowId});
  final FullscreenMode? preferredMode;
}
```

关键实现细节:
- FullscreenCapability 是纯数据类，Phase C 平台适配时每端返回真实值
- FullscreenRequest 使用 sealed class，Phase B 命令队列 switch 处理
- windowId 默认 0（单窗口），为 MULTI-01 预留
- ToggleFullscreen.preferredMode 可选（null 时切换到 borderless）

Per PLAT-04: FullscreenCapability 查询每平台支持的能力。
Per D-04: per-window Map 容器，windowId 参数预留。
  </action>

  <verify>
    <automated>flutter test test/kernel/bridge/fullscreen_adapter_test.dart || true; flutter analyze lib/kernel/models/fullscreen_capability.dart lib/kernel/models/fullscreen_request.dart</automated>
  </verify>

  <acceptance_criteria>
    - `lib/kernel/models/fullscreen_capability.dart` 存在并导出 FullscreenCapability
    - FullscreenCapability 有 supportsFullscreen, supportsMultiWindow, supportsMultiDisplay, supportsExclusive, requiresUserGesture 字段
    - `lib/kernel/models/fullscreen_request.dart` 存在并导出 FullscreenRequest, EnterFullscreen, LeaveFullscreen, ToggleFullscreen
    - FullscreenRequest 有 windowId 字段，默认 0
    - flutter analyze 通过
  </acceptance_criteria>

  <done>
    FullscreenCapability + FullscreenRequest 数据模型完成。
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 5: FullscreenAdapter 抽象接口</name>
  <files>lib/kernel/bridge/fullscreen_adapter.dart, test/kernel/bridge/fullscreen_adapter_test.dart</files>

  <read_first>
    lib/kernel/bridge/window_bridge.dart
    lib/kernel/bridge/window_state.dart
    lib/kernel/models/fullscreen_snapshot.dart (Task 1)
    lib/kernel/models/fullscreen_event.dart (Task 3)
    lib/kernel/models/fullscreen_request.dart (Task 4)
    lib/kernel/models/fullscreen_capability.dart (Task 4)
  </read_first>

  <behavior>
    - Test: FullscreenAdapter 是 abstract class
    - Test: snapshot(windowId) 返回 ValueNotifier<FullscreenSnapshot>
    - Test: events 返回 Stream<FullscreenEvent>
    - Test: capabilities() 返回 Future<FullscreenCapability>
    - Test: setFullscreen(bool) 是抽象方法
    - Test: toggle() 是抽象方法
    - Test: dispose() 是抽象方法
    - Test: FullscreenAdapter 与 WindowBridge 是并列接口
  </behavior>

  <action>
创建 `lib/kernel/bridge/fullscreen_adapter.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../models/fullscreen_capability.dart';
import '../models/fullscreen_event.dart';
import '../models/fullscreen_request.dart';
import '../models/fullscreen_snapshot.dart';

/// 全屏管理抽象接口 — UI 层依赖此接口，不依赖具体实现。
///
/// 实现方:
/// - DesktopFullscreenAdapter — Windows/macOS/Linux 真实实现 (Phase B)
/// - FakeFullscreenAdapter — 测试替身
///
/// 设计约束:
/// - 与 WindowBridge 并列，不继承不依赖
/// - 内部组合 WindowService 通用方法 + fullscreen_window 插件
/// - per-window 状态容器，默认 windowId = 0
/// - error 不是锁死态，下次合法操作自动清理
abstract class FullscreenAdapter {
  // ─── 状态查询 ───

  /// 获取指定窗口的全屏状态快照。
  ///
  /// 单窗口使用 windowId = 0。返回的 ValueNotifier 在整个窗口生命周期内有效。
  ValueNotifier<FullscreenSnapshot> snapshot([int windowId = 0]);

  /// 全屏生命周期事件流。
  ///
  /// 业务层监听此流获取全屏过渡通知，不直接依赖 _WindowListener。
  Stream<FullscreenEvent> get events;

  // ─── 能力查询 ───

  /// 查询当前平台的全屏能力。
  ///
  /// 返回值描述平台支持的全屏特性（多窗口/多显示器/手势限制等）。
  Future<FullscreenCapability> capabilities();

  // ─── 命令 ───

  /// 设置全屏状态。
  ///
  /// - [fullscreen] true 进入全屏，false 退出全屏
  /// - [windowId] 目标窗口，默认 0
  /// - [mode] 全屏模式，默认 borderless
  ///
  /// 如果当前正在过渡中（entering/leaving），返回 BusyTransition 错误。
  /// 如果平台不支持，返回 Unsupported 错误。
  /// error 状态下调用会自动清理为 stable 并重走流程。
  Future<void> setFullscreen(
    bool fullscreen, {
    int windowId = 0,
    FullscreenMode mode = FullscreenMode.borderless,
  });

  /// 切换全屏状态。
  ///
  /// 等效于 `setFullscreen(!snapshot(windowId).value.isFullscreen)`。
  /// [preferredMode] 指定切换到全屏时的模式，null 时使用 borderless。
  Future<void> toggle({
    int windowId = 0,
    FullscreenMode? preferredMode,
  });

  // ─── Lifecycle ───

  /// 释放资源 — 关闭 StreamController，清理 per-window 状态。
  void dispose();
}
```

关键实现细节:
- abstract class 与 WindowBridge 并列，不继承不依赖
- snapshot() 返回 ValueNotifier<FullscreenSnapshot>，UI 通过 ValueListenableBuilder 监听
- events 返回 Stream<FullscreenEvent>，业务层监听生命周期
- setFullscreen() 是主命令入口，error 状态自动清理
- toggle() 是便捷方法，内部委托 setFullscreen
- capabilities() 返回 Future（可能需要平台调用）
- dispose() 清理 StreamController 和 per-window 状态

Per ARCH-01: FullscreenAdapter 接口独立于 WindowBridge。
Per ARCH-02: WindowBridge 继续负责通用窗口操作。
Per STATE-02: UI 通过 ValueListenable<FullscreenSnapshot> 查询状态。
Per EVT-02: 业务层通过 Stream<FullscreenEvent> 监听。
Per ERR-02: 每次失败通过 error 事件通知 UI。
  </action>

  <verify>
    <automated>flutter test test/kernel/bridge/fullscreen_adapter_test.dart || true; flutter analyze lib/kernel/bridge/fullscreen_adapter.dart</automated>
  </verify>

  <acceptance_criteria>
    - `lib/kernel/bridge/fullscreen_adapter.dart` 存在并导出 FullscreenAdapter
    - FullscreenAdapter 是 abstract class
    - 有 snapshot(windowId) 返回 ValueNotifier<FullscreenSnapshot>
    - 有 events 返回 Stream<FullscreenEvent>
    - 有 capabilities() 返回 Future<FullscreenCapability>
    - 有 setFullscreen(bool) 和 toggle() 方法
    - 有 dispose() 方法
    - 与 WindowBridge 无继承关系
    - flutter analyze 通过
  </acceptance_criteria>

  <done>
    FullscreenAdapter 抽象接口完成，UI 层可依赖此接口进行后续开发。
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 6: FakeFullscreenAdapter 测试替身 + 完整测试套件</name>
  <files>test/kernel/bridge/fullscreen_adapter_test.dart</files>

  <read_first>
    lib/kernel/bridge/fullscreen_adapter.dart (Task 5)
    lib/kernel/models/fullscreen_snapshot.dart (Task 1)
    lib/kernel/models/fullscreen_error.dart (Task 2)
    lib/kernel/models/fullscreen_event.dart (Task 3)
    test/kernel/bridge/window_service_test.dart (参考测试模式)
  </read_first>

  <behavior>
    - Test: FakeFullscreenAdapter 实现 FullscreenAdapter 接口
    - Test: snapshot() 返回 stable/windowed 初始状态
    - Test: setFullscreen(true) 触发 entering → stable(fullscreen) 转换
    - Test: setFullscreen(false) 触发 leaving → stable(windowed) 转换
    - Test: toggle() 在 windowed 时进入全屏
    - Test: toggle() 在 fullscreen 时退出全屏
    - Test: error 状态下 setFullscreen 自动清理为 stable
    - Test: events 流收到正确的 FullscreenEvent 序列
    - Test: capabilities() 返回默认能力
    - Test: dispose() 后 snapshot 不再更新
    - Test: 多窗口独立状态（不同 windowId 互不干扰）
  </behavior>

  <action>
在 `test/kernel/bridge/fullscreen_adapter_test.dart` 中:

1. **FakeFullscreenAdapter** — 实现 FullscreenAdapter 接口的测试替身:
   ```dart
   /// 测试替身 — 模拟全屏操作，不依赖平台。
   ///
   /// 用途:
   /// - widget 测试中替代真实 Adapter
   /// - 验证 UI 对全屏状态变化的响应
   /// - 验证事件流订阅逻辑
   class FakeFullscreenAdapter implements FullscreenAdapter {
     final _snapshots = <int, ValueNotifier<FullscreenSnapshot>>{};
     final _eventsController = StreamController<FullscreenEvent>.broadcast();

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
       final notifier = snapshot(windowId);
       final current = notifier.value;

       // error 状态自动清理
       if (current.hasError) {
         notifier.value = current.copyWith(
           phase: FullscreenPhase.stable,
           clearError: true,
         );
       }

       if (fullscreen) {
         // entering → stable(fullscreen)
         _eventsController.add(EnterRequested(targetMode: mode));
         notifier.value = notifier.value.copyWith(
           phase: FullscreenPhase.entering,
         );
         await Future.delayed(Duration.zero); // 模拟异步
         notifier.value = notifier.value.copyWith(
           phase: FullscreenPhase.stable,
           effectiveMode: mode,
         );
         _eventsController.add(Entered(finalMode: mode));
       } else {
         // leaving → stable(windowed)
         _eventsController.add(const LeaveRequested());
         notifier.value = notifier.value.copyWith(
           phase: FullscreenPhase.leaving,
         );
         await Future.delayed(Duration.zero);
         notifier.value = notifier.value.copyWith(
           phase: FullscreenPhase.stable,
           effectiveMode: FullscreenMode.windowed,
         );
         _eventsController.add(const Left());
       }
     }

     @override
     Future<void> toggle({
       int windowId = 0,
       FullscreenMode? preferredMode,
     }) async {
       final current = snapshot(windowId).value;
       await setFullscreen(
         !current.isFullscreen,
         windowId: windowId,
         mode: preferredMode ?? FullscreenMode.borderless,
       );
     }

     @override
     void dispose() {
       for (final notifier in _snapshots.values) {
         notifier.dispose();
       }
       _snapshots.clear();
       _eventsController.close();
     }
   }
   ```

2. **测试套件** — 覆盖所有行为测试:
   - 默认状态测试: snapshot 返回 stable/windowed
   - setFullscreen(true) 测试: 进入全屏，验证 phase 转换和事件序列
   - setFullscreen(false) 测试: 退出全屏，验证 phase 转换和事件序列
   - toggle() 测试: 双向切换
   - error 恢复测试: error → setFullscreen → stable
   - 多窗口测试: 不同 windowId 独立状态
   - dispose 测试: dispose 后不再更新
   - capabilities 测试: 返回默认值

Per STATE-03: per-window 独立状态容器。
Per ERR-02: error 状态自动清理。
Per D-09: 重试即恢复。
  </action>

  <verify>
    <automated>flutter test test/kernel/bridge/fullscreen_adapter_test.dart</automated>
  </verify>

  <acceptance_criteria>
    - FakeFullscreenAdapter 实现 FullscreenAdapter 接口
    - 所有行为测试通过
    - 覆盖: 默认状态、进入/退出、toggle、error 恢复、多窗口、dispose
    - flutter analyze 通过
  </acceptance_criteria>

  <done>
    FakeFullscreenAdapter 测试替身 + 完整测试套件完成，所有测试通过。
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| None | 纯数据模型和抽象接口定义，无安全敏感代码变更 |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-01-SC | Tampering | npm/pip/cargo installs | high | mitigate | 无外部包安装 — 所有组件为项目本地定义 |
</threat_model>

<verification>
1. `flutter analyze` 通过，无新增 warning
2. `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` 全部通过
3. FullscreenAdapter 接口定义完整（snapshot/events/capabilities/setFullscreen/toggle/dispose）
4. FullscreenSnapshot 有 phase/effectiveMode/restoreMode/displayId/lastError 字段
5. FullscreenEvent 覆盖 7 种事件类型
6. FullscreenError 覆盖 7 种错误类型
7. FullscreenAdapter 与 WindowBridge 无继承关系
8. FakeFullscreenAdapter 可用于后续 widget 测试
</verification>

<success_criteria>
- FullscreenAdapter 接口定义完成，UI 层只依赖此接口
- FullscreenSnapshot 模型包含 phase/effectiveMode/restoreMode/lastError 等完整字段
- FullscreenEvent 流覆盖 7 种事件类型
- FullscreenError 枚举覆盖 7 种错误类型
- WindowBridge 全屏相关职责未变更（Phase B 迁移）
- flutter analyze 通过，无新增 warning
- 测试套件覆盖所有核心行为
</success_criteria>

<output>
创建 `.planning/phases/01-architecture-core-models/01-SUMMARY.md` when done
</output>
