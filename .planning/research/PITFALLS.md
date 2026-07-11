# Domain Pitfalls

**Domain:** Desktop media player fullscreen management
**Researched:** 2026-07-11

## Critical Pitfalls

### Pitfall 1: Removing Fast-Path Without Performance Validation

**What goes wrong:** WindowsFullscreenDriver.enterFullscreenFast() uses 5 FFI calls vs 12 in enterFullscreen(). Removing the fast-path abstraction may cause visible lag on fullscreen toggle.

**Why it happens:** Simplifying the driver interface removes supportsFastPath/enterFullscreenFast methods.

**Consequences:** Fullscreen toggle becomes slower on Windows (12 FFI calls instead of 5).

**Prevention:** Keep the optimized FFI call sequence in the simplified driver. The optimization is in the implementation, not the abstraction. Just call the fast path directly.

**Detection:** Measure fullscreen toggle time before and after simplification.

### Pitfall 2: Losing Restore Snapshot on Error

**What goes wrong:** If fullscreen entry fails after saving bounds, the saved bounds are lost and the window cannot be restored to its original position.

**Why it happens:** Removing the restore snapshot system without replacing it.

**Consequences:** Window stuck in wrong position after failed fullscreen attempt.

**Prevention:** Keep the save/restore logic in WindowService with a simple `Rect? _savedBounds` field. Ensure restore is called in a `finally` block.

**Detection:** Test fullscreen failure scenarios (invalid HWND, display disconnected).

### Pitfall 3: Breaking macOS/Linux Native Callbacks

**What goes wrong:** macOS and Linux fullscreen has ~700ms animation. If the code returns immediately without waiting for confirmation, the UI may show incorrect state during the animation.

**Why it happens:** Removing the confirmation chain (native callback -> polling -> timeout).

**Consequences:** UI flickers or shows wrong state during fullscreen animation.

**Prevention:** Keep a simple await mechanism for macOS/Linux: `await _plugin.setFullScreen(true)` may already await the animation. If not, add a simple `await Future.delayed(Duration(milliseconds: 800))` or listen for the plugin's callback.

**Detection:** Test on macOS/Linux, observe UI state during fullscreen animation.

## Moderate Pitfalls

### Pitfall 4: Losing Test Coverage

**What goes wrong:** Deleting 3,555 lines of tests removes coverage for edge cases (desync recovery, timeout handling, merge logic).

**Why it happens:** Tests are deleted along with the code they test.

**Consequences:** Regressions in edge cases may go undetected.

**Prevention:** Before deleting tests, identify which edge cases are still relevant and write simpler tests for them. Focus on: save/restore bounds, error handling, platform-specific behavior.

### Pitfall 5: Optimistic Update Race Condition

**What goes wrong:** WindowService sets `_state.mode.value = WindowMode.fullscreen` before awaiting the adapter. If the adapter fails, it rolls back. But during the await, the UI shows fullscreen state that may not be real.

**Why it happens:** Keeping the optimistic update pattern from the current code.

**Consequences:** Brief UI inconsistency on failure.

**Prevention:** In the simplified architecture, set `isFullscreen = true` only after the driver confirms success. The 1-frame delay is imperceptible.

## Minor Pitfalls

### Pitfall 6: WindowMode vs Boolean

**What goes wrong:** WindowService.mode is a WindowMode enum (windowed/maximized/fullscreen/minimized). Replacing fullscreen tracking with a boolean creates two separate state variables.

**Why it happens:** WindowMode serves other purposes (maximize, minimize) beyond fullscreen.

**Consequences:** State inconsistency between mode enum and fullscreen boolean.

**Prevention:** Keep WindowMode enum but update it in the same code path as the fullscreen boolean. Or derive `isFullscreen` from `mode == WindowMode.fullscreen`.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Delete command queue | Lost serialization for rapid key presses | Debounce in WindowService (100ms) |
| Delete event stream | Lost ForcedChange detection (OS external changes) | Keep WindowListener.onWindowMaximize handling |
| Merge adapter into WindowService | WindowService becomes too large | Extract FullscreenCoordinator class if >200 lines |
| Simplify driver interface | Lost platform capability information | Add capabilities only when UI needs them |
| Remove error hierarchy | Lost diagnostic context | Include context in exception message string |

## Sources

- Project memory: fullscreen bugs (5 fixed), window anti-patterns, fullscreen architecture anti-patterns
- Direct code analysis: existing error handling, confirmation chain, restore logic
