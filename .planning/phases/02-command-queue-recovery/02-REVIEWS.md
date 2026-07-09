---
phase: 02-command-queue-recovery
reviewers: [claude-self]
reviewed_at: 2026-07-09T00:00:00Z
plans_reviewed:
  - 02-01-PLAN.md (FullscreenCommandQueue)
  - 02-02-PLAN.md (DesktopFullscreenAdapter)
  - 02-03-PLAN.md (WindowService Migration)
note: >
  Self-review by Claude Code — no external AI CLIs detected (Gemini, Codex, OpenCode,
  Qwen, Cursor, Antigravity all unavailable). This is not a true cross-AI review.
  Install at least one external CLI for independent perspective:
  - gemini: https://github.com/google-gemini/gemini-cli
  - codex: https://github.com/openai/codex
---

# Cross-AI Plan Review — Phase 2: Command Queue & Recovery

## Claude Self-Review

> ⚠️ **Self-review caveat:** This review is performed by the same AI that wrote the plans.
> Findings should be weighted lower than an independent reviewer. Cross-reference with
> your own judgment and consider installing external CLIs for future reviews.

### Summary

Phase B 三个计划整体设计严谨，遵循 Phase A 建立的模型层契约。Completer 链命令队列、三级状态确认、完整恢复策略的架构选型合理。但发现 2 个 HIGH 级别问题需要在实现前解决：`_callbackConfirm` 单 Completer 并发安全问题，以及 FullscreenDriver 与 WindowService 的循环创建依赖。此外，Plan 02 的实现代码使用 `windowManager` 直调，与 FullscreenDriver 抽象层设计不一致，需要统一。

### Strengths

- **Phase A 模型层复用充分**: FullscreenRequest sealed class、FullscreenSnapshot、FullscreenError、FullscreenEvent 全部已在 Phase A 定义完成，Phase B 直接使用无需修改。代码证据：`lib/kernel/models/fullscreen_request.dart` 3 个子类完整覆盖 enter/leave/toggle，`fullscreen_snapshot.dart` 的 `copyWith(clearError: true)` 支持 error→stable 清理
- **命令队列设计清晰**: Completer 链模式是 Dart 标准并发原语，per-windowId 隔离避免多窗口干扰，toggle 先解析再合并（D-18）避免了 toggle+setFullscreen 无法合并的陷阱
- **三级状态确认策略务实**: D-19 的"回调→轮询→超时"三级策略覆盖了 Windows/macOS/Linux 的回调时序差异，不依赖任何单一确认路径
- **恢复策略考虑全面**: D-22~D-25 覆盖 windowed/maximized/副屏/minimized 四种场景，降级策略（副屏不可用→主屏 center）防止窗口"消失"
- **迁移方案低风险**: 02-03 的编译时 flag + fallback 设计确保新旧实现可切换，默认关闭新实现避免生产风险
- **FullscreenAdapter 抽象接口干净**: `lib/kernel/bridge/fullscreen_adapter.dart` 68 行，4 个方法（snapshot/capabilities/setFullscreen/toggle）+ dispose，职责边界明确

### Concerns

#### HIGH-1: `_callbackConfirm` 单 Completer 并发安全问题

**File:** 02-RESEARCH.md `_confirmState` 实现示例 / 02-02-PLAN.md `_waitForConfirmation`

`_callbackConfirm` 是一个实例级 `Completer<void>?`。如果两个不同 windowId 的命令同时执行（理论上 per-windowId 队列允许不同 windowId 并发），`onNativeFullScreenChanged` 回调会调用 `_callbackConfirm?.complete()`，但无法区分是哪个 windowId 的确认。

更严重的是：如果 windowId=0 的命令正在 `_confirmState` 中等待 `_callbackConfirm`，此时 windowId=1 的命令也进入 `_confirmState`，会覆盖 `_callbackConfirm` 为新的 Completer，导致 windowId=0 的确认丢失。

**建议:** 将 `_callbackConfirm` 改为 `Map<int, Completer<void>>`，按 windowId 隔离。或者在 `DesktopFullscreenAdapter` 层面保证同一时刻只有一个 windowId 在执行 `_confirmState`（但这会降低多窗口并发能力）。

#### HIGH-2: FullscreenDriver 与 WindowService 的循环创建依赖

**File:** 02-03-PLAN.md Task 2

Plan 02 定义了 `FullscreenDriver` 抽象接口（`enterFullscreen`/`leaveFullscreen`/`queryFullscreen` 等），Plan 03 的 `DesktopFullscreenDriver` 实现使用 `windowManager` API。但 Plan 02 的 `_executeCommand` 实现示例中，`_captureRestoreSnapshot` 需要读取 `WindowBridge.mode.value` 来判断 `isMaximized`。

创建顺序问题：app.dart 中 `DesktopFullscreenDriver` → `DesktopFullscreenAdapter` → `WindowService`。但 `DesktopFullscreenDriver.isMaximized` 可能需要从 `WindowService`（即 `WindowBridge`）读取状态。此时 `WindowService` 尚未创建。

**建议:** `FullscreenDriver` 应完全独立于 `WindowBridge`，所有状态查询通过 `windowManager` API（`windowManager.isMaximized()`）而非 `WindowBridge.mode`。Plan 02 的实现示例中 `_captureRestoreSnapshot` 已使用 `windowManager.isMaximized()`，这是正确的。确认 `FullscreenDriver` 不持有 `WindowBridge` 引用即可解决。

#### MEDIUM-1: Plan 02 实现代码与 FullscreenDriver 抽象不一致

**File:** 02-02-PLAN.md Task 2 / 02-RESEARCH.md 代码示例

Plan 02 Task 1 定义了 `FullscreenDriver` 抽象接口（10 个方法），但 Task 2 的 `_executeCommand` 实现示例直接使用 `windowManager.setFullScreen()`、`windowManager.isFullScreen()`、`windowManager.restore()` 等 `window_manager` API，而非通过 `_driver.enterFullscreen()`、`_driver.queryFullscreen()`、`_driver.restore()` 调用。

这会导致：1) FullscreenDriver 抽象层形同虚设，DesktopFullscreenAdapter 直接依赖 window_manager；2) 未来替换平台驱动时需要修改 Adapter 代码而非仅替换 Driver。

**建议:** Task 2 的实现示例应使用 `_driver.xxx()` 而非 `windowManager.xxx()`。例如 `_driver.enterFullscreen()` 代替 `fullScreenWindow.setFullScreen(true)`，`_driver.queryFullscreen()` 代替 `windowManager.isFullScreen()`。

#### MEDIUM-2: FullscreenMode 枚举用于 _RestoreSnapshot 的语义混用

**File:** 02-02-PLAN.md _RestoreSnapshot / 02-RESEARCH.md 已解决

`_RestoreSnapshot` 使用 `FullscreenMode`（windowed/borderless/exclusive）表示恢复目标，但 maximized 状态用 `bool isMaximized` 独立标记。RESEARCH.md 中已记录此为"已解决"问题，但方案是"用 borderless 表示 maximized"——这在语义上不正确（borderless 是全屏模式，maximized 是窗口状态）。

**建议:** `_RestoreSnapshot` 使用独立的 `WindowState` 枚举（如 `windowed`/`maximized`/`minimized`）而非 `FullscreenMode`。或者至少在注释中明确说明 `FullscreenMode` 在此处的语义扩展。Plan 02 Task 2 的 `_RestoreSnapshot` 已使用 `WindowMode mode` + `bool isMaximized`，这是更干净的设计，但 RESEARCH.md 的代码示例仍在用 `FullscreenMode restoreMode`，需要统一。

#### MEDIUM-3: _confirmState Level 1 超时返回值语义不清

**File:** 02-RESEARCH.md `_confirmState` 代码示例

```dart
final callbackResult = await _callbackConfirm!.future
  .timeout(
    const Duration(milliseconds: 500),
    onTimeout: () {},
  );
_callbackConfirm = null;

if (callbackResult != null) return true;
```

`onTimeout: () {}` 返回 `void`，所以 `callbackResult` 在超时后为 `null`。但 `_callbackConfirm?.complete()` 也返回 `void`，所以正常完成时 `callbackResult` 也是 `null`。这意味着 Level 1 永远无法通过 `callbackResult != null` 判断成功——它总是会 fall through 到 Level 2 轮询。

**建议:** 改用 `Completer<bool>` 而非 `Completer<void>`，`complete(true)` 表示确认，超时返回 `false`。或者用 `_callbackConfirmed` 布尔标志在回调中设置，超时后检查标志。

#### LOW-1: Plan 01 executor 返回类型与 Plan 02 不一致

**File:** 02-01-PLAN.md `Future<bool> Function(FullscreenRequest)` vs 02-RESEARCH.md `Future<void> Function(FullscreenRequest)`

Plan 01 定义 executor 返回 `Future<bool>`（成功/失败），但 RESEARCH.md 的 `WindowCommandQueue` 示例返回 `Future<void>`。Plan 02 的 `_executeCommand` 实际返回 `Future<bool>`。

**建议:** 统一为 `Future<bool>`，Plan 01 的设计更合理（队列需要传播执行结果）。

#### LOW-2: dispose 时 in-flight Completer 处理

**File:** 02-RESEARCH.md `WindowCommandQueue.dispose()`

```dart
void dispose() {
  if (_disposed) return;
  _disposed = true;
  _pending?.completer.complete();
  _pending = null;
}
```

只 complete 了 `_pending`，但 `_inFlight` 的 Completer 仍在 `_execute` 的 try/finally 中处理。如果 `_execute` 正在 `await command.executor(command.request)` 中等待，dispose 后 `_disposed = true` 但 executor 的 Future 仍在运行。finally 块会检查 `_disposed` 并跳过 pending，但 in-flight 的 Completer 要等 executor 自然完成或超时才会被 complete。

**建议:** 在 dispose 中也 cancel in-flight 的超时 Timer（如果有的话），或者给 executor 提供一个 CancellationToken。至少在文档中说明 dispose 后 in-flight 命令的行为。

#### LOW-3: Plan 02 Task 2 的 FullscreenDriver 接口方法过多

**File:** 02-02-PLAN.md Task 1 FullscreenDriver 定义

10 个方法（enterFullscreen/leaveFullscreen/queryFullscreen/getPosition/getSize/setBounds/maximize/restore/focus/isMaximized），但 DesktopFullscreenAdapter 只使用其中约 6 个。`focus()` 和 `isMaximized` getter 的使用场景不明确。

**建议:** 先实现 Adapter 实际使用的方法，其余标记为预留。避免 YAGNI（接口过大增加实现负担）。

### Suggestions

1. **统一 FullscreenDriver 使用点**: Plan 02 Task 2 的实现代码应通过 `_driver.xxx()` 调用，而非直接使用 `windowManager`。这样 FullscreenDriver 抽象才有实际价值
2. **_RestoreSnapshot 使用独立状态枚举**: 避免用 FullscreenMode 表示 maximized，使用 `WindowMode` 或自定义枚举
3. **添加 command queue 的 maxQueueSize 限制**: 虽然合并逻辑会减少队列长度，但极端情况下（合并条件不满足的快速连按）可能积累大量 pending 命令
4. **Plan 03 补充初始化顺序图**: app.dart 中的创建顺序（Driver → Adapter → WindowService）及其依赖关系应明确文档化
5. **测试中覆盖 "回调永不触发" 场景**: _confirmState 的 Level 1→Level 2 降级路径需要专门测试

### Risk Assessment

**Overall Risk: MEDIUM**

- **HIGH-1 (并发安全)** 是最需要关注的问题，但影响范围有限（单窗口场景不会触发）
- **HIGH-2 (循环依赖)** 通过确保 Driver 不依赖 WindowBridge 可以轻松解决
- **MEDIUM-1 (抽象不一致)** 是实现阶段的代码质量问题，不影响架构
- Phase A 模型层已完成且测试通过，为 Phase B 提供了坚实基础
- 核心风险在于 window_manager 与 fullscreen_window 的交互行为（Pitfall 1），需要实测验证

---

## Consensus Summary

> ⚠️ Single reviewer (self-review) — no consensus to synthesize.
> Install external AI CLIs for multi-perspective review.

### Agreed Strengths (self-assessed)
- Phase A 模型层复用充分，sealed class 设计覆盖完整
- Completer 链 + per-windowId 隔离是正确的并发模式选型
- 三级状态确认策略务实，不依赖单一确认路径

### Agreed Concerns (self-assessed, priority order)
1. **HIGH** — `_callbackConfirm` 单 Completer 并发安全（多窗口场景）
2. **HIGH** — FullscreenDriver 与 WindowService 创建顺序依赖
3. **MEDIUM** — Plan 02 实现代码绕过 FullscreenDriver 抽象直接调用 windowManager
4. **MEDIUM** — `_confirmState` Level 1 超时判断逻辑 bug（Completer<void> 永远返回 null）

### Divergent Views
N/A — single reviewer
