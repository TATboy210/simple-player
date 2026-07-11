# Phase 8: 删除不必要的抽象层 - Research

**Researched:** 2026-07-11
**Domain:** Fullscreen architecture simplification — deletion of v1 abstraction layer
**Confidence:** HIGH

## Summary

Phase 8 的目标是删除 v1 阶段建立的 6 个文件（757 行源码 + ~2,000 行测试），这些文件构成了过度工程化的全屏抽象层。研究发现：

1. **文件验证完成** — ROADMAP 声称的 6 个文件全部存在，行数完全匹配（757 行）
2. **依赖关系清晰** — 消费者主要集中在 `desktop_fullscreen_adapter.dart`、`window_service.dart`、`main.dart` 和测试文件
3. **UI 层无直接依赖** — `lib/ui/` 目录下没有任何文件直接导入这些模型
4. **删除风险可控** — 所有消费者都在 bridge/kernel 层，迁移路径明确

**Primary recommendation:** 按照依赖关系从叶子节点开始删除，先删 model 文件，再删 adapter/queue。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fullscreen state management | Kernel/Bridge | — | DesktopFullscreenAdapter 内部状态机 |
| Command serialization | Kernel/Bridge | — | FullscreenCommandQueue per-window 队列 |
| Error handling | Kernel/Bridge | UI (via events) | FullscreenError sealed class |
| Event broadcasting | Kernel/Bridge | UI (via Stream) | FullscreenEvent 事件流 |
| Platform abstraction | Kernel/Bridge | — | FullscreenDriver 接口 |

## Current Architecture Map

### Files Targeted for Deletion

| File | Location | Lines | Purpose |
|------|----------|-------|---------|
| `fullscreen_adapter.dart` | `lib/kernel/bridge/` | 68 | Abstract adapter interface — UI 层依赖此接口 |
| `fullscreen_command_queue.dart` | `lib/kernel/bridge/` | 258 | Per-window 命令串行化队列 |
| `fullscreen_snapshot.dart` | `lib/kernel/models/` | 127 | 全屏状态快照 + FullscreenPhase/Mode 枚举 |
| `fullscreen_error.dart` | `lib/kernel/models/` | 145 | 7 种错误类型的 sealed class |
| `fullscreen_event.dart` | `lib/kernel/models/` | 108 | 7 种生命周期事件的 sealed class |
| `fullscreen_request.dart` | `lib/kernel/models/` | 51 | Enter/Leave/Toggle 请求类型 |
| **Total** | | **757** | |

### Files to Keep (NOT deleted in Phase 8)

| File | Lines | Purpose | Why Kept |
|------|-------|---------|----------|
| `fullscreen_driver.dart` | 134 | 平台驱动抽象接口 | Phase 9 精简，Phase 10 重写 |
| `desktop_fullscreen_driver.dart` | 133 | window_manager fallback 驱动 | Phase 9 合并进 WindowService |
| `desktop_fullscreen_adapter.dart` | 520 | 具体适配器实现 | Phase 9 合并进 WindowService |
| `desktop_fullscreen_driver_factory.dart` | 100 | 平台驱动工厂 | Phase 10 整合 |
| `window_service.dart` | 380 | 窗口管理服务 | 保留，Phase 9 修改调用方式 |
| `platform/windows_fullscreen_driver.dart` | 608 | Windows FFI 驱动 | Phase 10 整合 |
| `platform/macos_fullscreen_driver.dart` | 212 | macOS 驱动 | Phase 10 整合 |
| `platform/linux_fullscreen_driver.dart` | 246 | Linux 驱动 | Phase 10 整合 |
| `fullscreen_capability.dart` | 32 | 平台能力查询 | 被 Driver 使用，保留 |

### Test Files Targeted for Deletion

| File | Lines | Tests |
|------|-------|-------|
| `fullscreen_adapter_test.dart` | 651 | FullscreenAdapter 接口 + FakeFullscreenAdapter 测试 |
| `fullscreen_command_queue_test.dart` | 536 | CommandQueue 串行化、合并、超时测试 |
| `desktop_fullscreen_adapter_test.dart` | 777 | DesktopFullscreenAdapter 完整行为测试 |
| **Total** | **1,964** | |

## Deletion Impact Matrix

### fullscreen_adapter.dart (68 lines)

| Consumer | Import | Impact | Replacement |
|----------|--------|--------|-------------|
| `main.dart` | `import 'kernel/bridge/fullscreen_adapter.dart'` | 类型声明 `FullscreenAdapter? fullscreenAdapter` | 删除类型声明，直接用 `DesktopFullscreenAdapter` |
| `window_service.dart` | `import 'fullscreen_adapter.dart'` | 构造函数参数 `FullscreenAdapter? fullscreenAdapter` | 改为 `DesktopFullscreenAdapter? fullscreenAdapter` |
| `desktop_fullscreen_adapter.dart` | `import 'fullscreen_adapter.dart'` | `implements FullscreenAdapter` | 删除 implements，保留类 |
| `fullscreen_adapter_test.dart` | `import '...'` | 测试 `FullscreenAdapter` 接口 | 删除整个测试文件 |
| `fullscreen_e2e_test.dart` | `import '...'` | E2E 测试类型引用 | 更新 import |
| `smoke_suite_test.dart` | `import '...'` | 冒烟测试类型引用 | 更新 import |
| `high_risk_suite_test.dart` | `import '...'` | 高风险测试类型引用 | 更新 import |

### fullscreen_command_queue.dart (258 lines)

| Consumer | Import | Impact | Replacement |
|----------|--------|--------|-------------|
| `desktop_fullscreen_adapter.dart` | `import 'fullscreen_command_queue.dart'` | 内部 `_queue = FullscreenCommandQueue()` | 删除队列，简化为直接调用 |
| `fullscreen_command_queue_test.dart` | `import '...'` | 测试队列行为 | 删除整个测试文件 |

### fullscreen_snapshot.dart (127 lines)

| Consumer | Import | Impact | Replacement |
|----------|--------|--------|-------------|
| `fullscreen_adapter.dart` | `import '../models/fullscreen_snapshot.dart'` | 接口返回 `ValueNotifier<FullscreenSnapshot>` | 随 adapter 删除 |
| `fullscreen_command_queue.dart` | `import '../models/fullscreen_snapshot.dart'` | 未直接使用 | 随 queue 删除 |
| `desktop_fullscreen_adapter.dart` | `import '../models/fullscreen_snapshot.dart'` | 状态容器 `Map<int, ValueNotifier<FullscreenSnapshot>>` | 改用简单 `ValueNotifier<bool>` |
| `fullscreen_event.dart` | `import 'fullscreen_snapshot.dart'` | 使用 `FullscreenMode` | 随 event 删除 |
| `fullscreen_error.dart` | `import 'fullscreen_snapshot.dart'` | 使用 `FullscreenPhase`, `FullscreenMode` | 随 error 删除 |
| `fullscreen_request.dart` | `import 'fullscreen_snapshot.dart'` | 使用 `FullscreenMode` | 随 request 删除 |
| `window_service.dart` | `import '../models/fullscreen_snapshot.dart'` | `_onFullscreenEvent` 使用 `FullscreenMode` | 改用简单 bool |
| 6 个测试文件 | 各自 import | 测试断言使用类型 | 随测试文件删除或更新 |

### fullscreen_error.dart (145 lines)

| Consumer | Import | Impact | Replacement |
|----------|--------|--------|-------------|
| `fullscreen_snapshot.dart` | `import 'fullscreen_error.dart'` | `FullscreenError? lastError` 字段 | 随 snapshot 删除 |
| `fullscreen_event.dart` | `import 'fullscreen_error.dart'` | `FullscreenErrorEvent` 子类 | 随 event 删除 |
| `desktop_fullscreen_adapter.dart` | `import '../models/fullscreen_error.dart'` | `FullscreenError.platformFailure(...)` | 改用 `debugPrint` + 简单错误处理 |
| 3 个测试文件 | 各自 import | 错误类型断言 | 随测试删除或更新 |

### fullscreen_event.dart (108 lines)

| Consumer | Import | Impact | Replacement |
|----------|--------|--------|-------------|
| `fullscreen_adapter.dart` | `import '../models/fullscreen_event.dart'` | `Stream<FullscreenEvent> get events` | 随 adapter 删除 |
| `desktop_fullscreen_adapter.dart` | `import '../models/fullscreen_event.dart'` | 事件广播 `_events.add(...)` | 删除事件系统，状态通过 ValueNotifier 同步 |
| `window_service.dart` | `import '../models/fullscreen_event.dart'` | `_onFullscreenEvent` switch | 改为监听 `ValueNotifier<bool>` |
| 2 个测试文件 | 各自 import | 事件类型断言 | 随测试删除 |

### fullscreen_request.dart (51 lines)

| Consumer | Import | Impact | Replacement |
|----------|--------|--------|-------------|
| `fullscreen_command_queue.dart` | `import '../models/fullscreen_request.dart'` | 入参类型 `FullscreenRequest` | 随 queue 删除 |
| `desktop_fullscreen_adapter.dart` | `import '../models/fullscreen_request.dart'` | `FullscreenRequest.enter(...)` | 直接调用 driver |
| 2 个测试文件 | 各自 import | 请求构造 | 随测试删除 |

## Risk Assessment

### HIGH Risk: DesktopFullscreenAdapter 状态系统重构

**What breaks:** 删除 `FullscreenSnapshot`、`FullscreenPhase`、`FullscreenMode` 后，`DesktopFullscreenAdapter` 内部的 520 行状态管理代码全部失效。

**Migration complexity:** MEDIUM
- 当前: `Map<int, ValueNotifier<FullscreenSnapshot>>` + 5 种 phase + 3 种 mode + 7 种 error
- 目标: `ValueNotifier<bool>` (isFullscreen)

**What to preserve:**
- 三级状态确认链 (Level 1 callback → Level 2 polling → Level 3 timeout)
- 恢复策略 (maximized/secondary display restore)
- 快速路径 (Windows FFI fast path)

### MEDIUM Risk: WindowService 事件同步

**What breaks:** `WindowService._onFullscreenEvent` 使用 `FullscreenEvent` 类型进行模式同步。

**Migration complexity:** LOW
- 当前: `_fullscreenAdapter?.events.listen(_onFullscreenEvent)` + switch on event types
- 目标: `_fullscreenAdapter?.isFullscreen.addListener(...)` + 简单 bool 检查

### LOW Risk: 测试文件删除

**What breaks:** 3 个测试文件（1,964 行）直接导入被删除的类型。

**Migration complexity:** NONE — 直接删除，Phase 9 重写测试。

### LOW Risk: main.dart 初始化

**What breaks:** `FullscreenAdapter? fullscreenAdapter` 类型声明。

**Migration complexity:** LOW
- 当前: `FullscreenAdapter? fullscreenAdapter = DesktopFullscreenAdapter(driver)`
- 目标: `DesktopFullscreenAdapter? fullscreenAdapter = DesktopFullscreenAdapter(driver)`

## Recommended Deletion Order

### Step 1: Delete model files (叶子节点)

先删除被其他 model 引用的文件，从依赖链末端开始：

1. `fullscreen_request.dart` (51 lines) — 仅被 queue 和 adapter 引用
2. `fullscreen_event.dart` (108 lines) — 被 adapter 和 window_service 引用
3. `fullscreen_error.dart` (145 lines) — 被 snapshot 和 event 引用
4. `fullscreen_snapshot.dart` (127 lines) — 被所有其他文件引用

### Step 2: Delete adapter/queue 文件

5. `fullscreen_command_queue.dart` (258 lines) — 仅被 desktop_fullscreen_adapter 引用
6. `fullscreen_adapter.dart` (68 lines) — 被 main 和 window_service 引用

### Step 3: Update consumers

7. Update `desktop_fullscreen_adapter.dart` — 删除 import，改用简单状态
8. Update `window_service.dart` — 删除 import，改用 ValueNotifier<bool>
9. Update `main.dart` — 删除 import，改用具体类型

### Step 4: Delete test files

10. `fullscreen_adapter_test.dart` (651 lines)
11. `fullscreen_command_queue_test.dart` (536 lines)
12. `desktop_fullscreen_adapter_test.dart` (777 lines)

### Step 5: Update remaining test files

13. Update `smoke_suite_test.dart` — 删除 import，改用具体类型
14. Update `high_risk_suite_test.dart` — 删除 import，改用具体类型
15. Update `fullscreen_e2e_test.dart` — 删除 import，改用具体类型

## Validation Architecture

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SIMPLIFY-01 | 删除 6 个文件 | smoke | `flutter analyze && flutter test` | N/A — 编译验证 |
| SIMPLIFY-02 | 零 import 残留 | grep | `grep -r "fullscreen_adapter\|fullscreen_command_queue\|fullscreen_snapshot\|fullscreen_error\|fullscreen_event\|fullscreen_request" lib/ test/` | N/A |
| SIMPLIFY-03 | 功能不退化 | regression | `flutter test test/regression/` | Yes |

### Sampling Rate

- **Per task commit:** `flutter analyze && flutter test`
- **Per wave merge:** Full regression suite
- **Phase gate:** `flutter analyze` 零 error + `flutter test` 全通过

### Wave 0 Gaps

- [ ] `desktop_fullscreen_adapter.dart` 简化测试 — 删除旧测试后需要新测试覆盖简化后的行为
- [ ] `window_service.dart` 全屏路径测试 — 确认 ValueNotifier<bool> 同步正确

## Common Pitfalls

### Pitfall 1: 循环依赖删除顺序

**What goes wrong:** 按文件大小排序删除，遇到循环依赖卡住。

**How to avoid:** 按依赖图拓扑排序，从叶子节点开始。

### Pitfall 2: 残留 import

**What goes wrong:** 删除文件后忘记清理 import，`flutter analyze` 报错。

**How to avoid:** 每删除一个文件后立即运行 `flutter analyze`。

### Pitfall 3: DesktopFullscreenAdapter 状态丢失

**What goes wrong:** 删除 `FullscreenSnapshot` 后，三级确认链、恢复策略、快速路径全部失效。

**How to avoid:** 在删除 model 之前，先将 DesktopFullscreenAdapter 简化为使用 `ValueNotifier<bool>`。

### Pitfall 4: WindowService 事件同步断裂

**What goes wrong:** 删除 `FullscreenEvent` 后，`_onFullscreenEvent` switch 无法编译。

**How to avoid:** 在删除 event 之前，先将 WindowService 改为监听 `ValueNotifier<bool>`。

## Code Examples

### 简化后的 DesktopFullscreenAdapter 状态管理

```dart
// BEFORE: 复杂状态快照
final Map<int, ValueNotifier<FullscreenSnapshot>> _snapshots = {};
ValueNotifier<FullscreenSnapshot> snapshot([int windowId = 0]) {
  return _snapshots.putIfAbsent(windowId, () => ValueNotifier(const FullscreenSnapshot()));
}

// AFTER: 简单布尔值
final ValueNotifier<bool> _isFullscreen = ValueNotifier(false);
ValueNotifier<bool> get isFullscreen => _isFullscreen;
```

### 简化后的 WindowService 事件同步

```dart
// BEFORE: 复杂事件 switch
void _onFullscreenEvent(FullscreenEvent event) {
  switch (event) {
    case Entered(): _state.mode.value = WindowMode.fullscreen;
    case Left(): _state.mode.value = WindowMode.windowed;
    case ForcedChange(:final actual): ...
    case SyncCorrected(:final actual): ...
    default: break;
  }
}

// AFTER: 简单监听器
void _onFullscreenChanged() {
  if (_disposed) return;
  _updateOnUIThread(() {
    _state.mode.value = _isFullscreen.value ? WindowMode.fullscreen : WindowMode.windowed;
  });
}
```

### 简化后的 main.dart 初始化

```dart
// BEFORE: 抽象类型
FullscreenAdapter? fullscreenAdapter;
if (_useNewFullscreen) {
  final driver = DesktopFullscreenDriverFactory.create();
  fullscreenAdapter = DesktopFullscreenAdapter(driver);
}

// AFTER: 具体类型
DesktopFullscreenAdapter? fullscreenAdapter;
if (_useNewFullscreen) {
  final driver = DesktopFullscreenDriverFactory.create();
  fullscreenAdapter = DesktopFullscreenAdapter(driver);
}
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Phase 9 会合并 DesktopFullscreenAdapter 进 WindowService | Deletion Order | 如果 Phase 9 不合并，删除 adapter 会破坏功能 |
| A2 | 删除后只需 `ValueNotifier<bool>` 即可满足状态需求 | Risk Assessment | 如果需要更复杂状态，需要重新设计 |
| A3 | 测试文件可以全部删除，Phase 9 重写 | Validation Architecture | 如果保留旧测试，需要大幅修改 |

## Open Questions (RESOLVED)

1. **DesktopFullscreenAdapter 删除时机 (RESOLVED)**
   - What we know: Phase 8 删除 adapter 接口和内部依赖，Phase 9 合并 adapter 逻辑进 WindowService
   - What's unclear: Phase 8 是否应该保留 DesktopFullscreenAdapter 但删除其内部依赖？
   - RESOLVED: Phase 8 只删除 model 和接口，保留 DesktopFullscreenAdapter 壳子供 Phase 9 合并（Plan 08-01 Task 1 实施此方案）

2. **三级确认链保留策略 (RESOLVED)**
   - What we know: DesktopFullscreenAdapter 内部有 Level 1/2/3 确认链
   - What's unclear: 删除 model 后确认链如何工作？
   - RESOLVED: 确认链逻辑保留，状态表示从 FullscreenSnapshot 简化为 bool（Plan 08-01 Task 1 显式保留 _waitForConfirmation / _registerConfirmation）

3. **恢复策略保留策略 (RESOLVED)**
   - What we know: DesktopFullscreenAdapter 内部有 _RestoreSnapshot 恢复策略
   - What's unclear: 删除 model 后恢复策略如何工作？
   - RESOLVED: 恢复策略保留，_RestoreSnapshot 是私有类不依赖删除的 model（Plan 08-01 Task 1 显式保留 _RestoreSnapshot / _captureRestoreSnapshot / _restoreFromSnapshot）

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build/Test | ✓ | 3.x | — |
| flutter analyze | 验证 | ✓ | — | — |
| flutter test | 验证 | ✓ | — | — |
| grep | 残留检查 | ✓ | — | — |

**Missing dependencies with no fallback:**
- None

**Missing dependencies with fallback:**
- None

## Sources

### Primary (HIGH confidence)
- Direct codebase analysis — all files read and verified
- Line counts verified with `wc -l`
- Import relationships verified with `grep`

### Secondary (MEDIUM confidence)
- ROADMAP.md — Phase 8 definition and success criteria
- STATE.md — Current project state

### Tertiary (LOW confidence)
- None — all claims verified from codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — direct codebase analysis
- Architecture: HIGH — all files read and dependencies mapped
- Pitfalls: HIGH — based on concrete code patterns

**Research date:** 2026-07-11
**Valid until:** 2026-07-25 (14 days — active development phase)
