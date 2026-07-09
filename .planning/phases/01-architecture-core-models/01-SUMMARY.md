---
phase: 01-architecture-core-models
plan: 01
subsystem: bridge
tags: [fullscreen, adapter, sealed-class, value-notifier, state-machine]

# Dependency graph
requires: []
provides:
  - FullscreenAdapter abstract interface
  - FullscreenSnapshot immutable state model (5-phase state machine)
  - FullscreenEvent sealed class (7 event types)
  - FullscreenError sealed class (7 error types)
  - FullscreenCapability platform query model
  - FullscreenRequest command model (enter/leave/toggle)
  - FakeFullscreenAdapter test double
affects: [02-command-queue, 03-platform-adapter, player-screen, keyboard-handler]

# Tech tracking
tech-stack:
  added: []
  patterns: [sealed-class-for-errors, sealed-class-for-events, immutable-data-copywith, value-notifier-wrapper]

key-files:
  created:
    - lib/kernel/models/fullscreen_snapshot.dart
    - lib/kernel/models/fullscreen_error.dart
    - lib/kernel/models/fullscreen_event.dart
    - lib/kernel/models/fullscreen_capability.dart
    - lib/kernel/models/fullscreen_request.dart
    - lib/kernel/bridge/fullscreen_adapter.dart
    - test/kernel/bridge/fullscreen_adapter_test.dart
  modified: []

key-decisions:
  - "FullscreenEvent uses non-const constructors with DateTime.now() default timestamp (const incompatible with runtime values)"
  - "FullscreenRequest sealed class: subclass constructors own default values, not factory constructors"
  - "FakeFullscreenAdapter uses synchronous setFullscreen (no artificial delays) — test reliability over realism"

patterns-established:
  - "Sealed class with factory constructors for type-safe error/event hierarchies"
  - "Immutable data class + copyWith + ValueNotifier wrapper for state snapshots"
  - "Abstract adapter interface independent from existing WindowBridge"

requirements-completed: [STATE-01, STATE-02, STATE-03, EVT-01, EVT-02, EVT-03, ERR-01, ERR-02, ERR-03, ARCH-01, ARCH-02]

coverage:
  - id: D1
    description: "FullscreenPhase 5-state enum + FullscreenMode 3-value enum + FullscreenSnapshot immutable data class"
    requirement: STATE-01
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FullscreenPhase
        status: pass
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FullscreenMode
        status: pass
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FullscreenSnapshot
        status: pass
    human_judgment: false
  - id: D2
    description: "FullscreenError sealed class with 7 error types carrying diagnostic context"
    requirement: ERR-01
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FullscreenError
        status: pass
    human_judgment: false
  - id: D3
    description: "FullscreenEvent sealed class with 7 event types carrying timestamp"
    requirement: EVT-01
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FullscreenEvent
        status: pass
    human_judgment: false
  - id: D4
    description: "FullscreenCapability + FullscreenRequest data models"
    requirement: ARCH-01
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FullscreenCapability
        status: pass
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FullscreenRequest
        status: pass
    human_judgment: false
  - id: D5
    description: "FullscreenAdapter abstract interface with snapshot/events/capabilities/setFullscreen/toggle/dispose"
    requirement: ARCH-02
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FullscreenAdapter
        status: pass
    human_judgment: false
  - id: D6
    description: "FakeFullscreenAdapter test double with error auto-clear, multi-window, toggle, dispose behavior"
    requirement: STATE-03
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_adapter_test.dart#FakeFullscreenAdapter
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-07-09
status: complete
---

# Phase 1 Plan 01: Architecture Core Models Summary

**FullscreenAdapter 抽象层 + 5 个不可变数据模型 + 7 种错误/事件类型 + 测试替身，52 个测试全通过**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-09
- **Completed:** 2026-07-09
- **Tasks:** 6
- **Files modified:** 7

## Accomplishments

- FullscreenSnapshot 不可变数据类：5-phase 状态机 (stable/entering/leaving/forcedChange/error)，3 种全屏模式 (windowed/borderless/exclusive)，copyWith + 值比较 + clearError
- FullscreenError sealed class：7 种错误类型 (Unsupported/InvalidWindow/PermissionDenied/BusyTransition/PlatformFailure/RestoreFailure/StateDesync)，各自携带诊断上下文
- FullscreenEvent sealed class：7 种事件类型 (enterRequested/entered/leaveRequested/left/forcedChange/syncCorrected/error)，每事件携带 timestamp
- FullscreenAdapter 抽象接口：snapshot/events/capabilities/setFullscreen/toggle/dispose，与 WindowBridge 并列无继承
- FakeFullscreenAdapter 测试替身：支持 per-window 独立状态、error 自动清理、事件流验证
- 52 个测试全部通过，flutter analyze 零警告

## Task Commits

1. **Task 1-4: Data models** - `feb9157` (feat)
2. **Task 5: FullscreenAdapter interface** - `a1ac55b` (feat)
3. **Task 6: FakeFullscreenAdapter + tests** - `e02b0f1` (test)

## Files Created/Modified

- `lib/kernel/models/fullscreen_snapshot.dart` - FullscreenPhase 枚举 + FullscreenMode 枚举 + FullscreenSnapshot 不可变数据类
- `lib/kernel/models/fullscreen_error.dart` - FullscreenError sealed class，7 种错误类型
- `lib/kernel/models/fullscreen_event.dart` - FullscreenEvent sealed class，7 种事件类型
- `lib/kernel/models/fullscreen_capability.dart` - FullscreenCapability 平台能力查询
- `lib/kernel/models/fullscreen_request.dart` - FullscreenRequest sealed class (enter/leave/toggle)
- `lib/kernel/bridge/fullscreen_adapter.dart` - FullscreenAdapter 抽象接口
- `test/kernel/bridge/fullscreen_adapter_test.dart` - FakeFullscreenAdapter + 52 个测试

## Decisions Made

- FullscreenEvent 使用非 const 构造函数 + DateTime.now() 默认时间戳：const 构造函数无法调用运行时值
- FullscreenRequest 子类构造函数拥有默认值，而非工厂构造函数：Dart 3 sealed class 限制
- FakeFullscreenAdapter setFullscreen 同步执行：测试可靠性优先于模拟真实异步

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FullscreenEvent const 构造函数不可调用 DateTime.now()**
- **Found during:** Task 3 (FullscreenEvent 事件模型)
- **Issue:** 计划中的代码使用 `const` 构造函数 + `_defaultTimestamp` getter（调用 DateTime.now()），Dart 不允许 const 构造函数调用非 const 表达式
- **Fix:** 移除 `const` 关键字，改用非 const 构造函数 + `DateTime.now()` 默认值
- **Files modified:** lib/kernel/models/fullscreen_event.dart
- **Verification:** flutter analyze 通过，52 测试通过
- **Committed in:** feb9157

**2. [Rule 1 - Bug] FullscreenRequest super.windowId 默认值冲突**
- **Found during:** Task 4 (FullscreenRequest 数据模型)
- **Issue:** sealed class 工厂构造函数设置默认值后，子类构造函数的 `super.windowId` 无法推断默认值
- **Fix:** 移除工厂构造函数的默认值，子类构造函数显式设置 `super.windowId = 0`
- **Files modified:** lib/kernel/models/fullscreen_request.dart
- **Verification:** flutter analyze 通过
- **Committed in:** feb9157

**3. [Rule 1 - Bug] FullscreenMode.maximized 不存在**
- **Found during:** Task 1 (FullscreenSnapshot 测试)
- **Issue:** 测试中引用 `FullscreenMode.maximized`，但枚举只有 windowed/borderless/exclusive
- **Fix:** 改用 `FullscreenMode.borderless`
- **Files modified:** test/kernel/bridge/fullscreen_adapter_test.dart
- **Verification:** 测试通过
- **Committed in:** feb9157

**4. [Rule 1 - Bug] broadcast StreamController 事件丢失**
- **Found during:** Task 6 (FakeFullscreenAdapter 测试)
- **Issue:** `StreamController.broadcast()` 在测试 setUp 中 listen 后，setFullscreen 同步 add 两个事件只收到 1 个
- **Fix:** 改用 `events.take(2).toList()` 异步收集事件，而非 setUp 中同步 listen
- **Files modified:** test/kernel/bridge/fullscreen_adapter_test.dart
- **Verification:** 52 测试全部通过
- **Committed in:** e02b0f1

---

**Total deviations:** 4 auto-fixed (4 bugs)
**Impact on plan:** 所有 auto-fix 均为编译/测试正确性修复，无范围扩展。

## Issues Encountered

None — 除上述 auto-fix 外，计划执行顺利。

## User Setup Required

None — 无外部服务配置。

## Next Phase Readiness

- FullscreenAdapter 接口已定义，Phase B (命令队列) 可直接实现 `DesktopFullscreenAdapter`
- FakeFullscreenAdapter 可用于后续 widget 测试
- 所有数据模型已就绪，UI 层可开始依赖 FullscreenAdapter 接口开发

---
*Phase: 01-architecture-core-models*
*Completed: 2026-07-09*
