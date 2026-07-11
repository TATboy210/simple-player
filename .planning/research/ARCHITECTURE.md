# Architecture Patterns

**Domain:** Desktop media player fullscreen management
**Researched:** 2026-07-11

## Recommended Architecture

**Current (5 layers):**
```
UI -> WindowService -> FullscreenAdapter -> FullscreenCommandQueue -> FullscreenDriver -> Platform
```

**Recommended (2 layers):**
```
UI -> WindowService -> FullscreenDriver -> Platform
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| PlayerScreen | UI toggle (F key, double-click, ESC) | WindowService.setMode |
| ControlsOverlay | Auto-hide based on isFullscreen | Receives bool from PlayerScreen |
| WindowService | Coordinator: save/restore bounds, state tracking | FullscreenDriver |
| FullscreenDriver (interface) | Platform abstraction: enter/leave/query | Platform-specific impl |
| WindowsFullscreenDriver | Win32 FFI: style manipulation, focus recovery | user32.dll |
| MacosFullscreenDriver | fullscreen_window plugin + delegate | macOS native |
| LinuxFullscreenDriver | fullscreen_window plugin + GDK signal | GTK native |

### Data Flow: Toggle Fullscreen

**Current (10 steps):**
1. UI callback
2. WindowService.setMode (optimistic update)
3. FullscreenAdapter.setFullscreen
4. FullscreenCommandQueue.enqueue (serialize, merge)
5. DesktopFullscreenAdapter._executeCommand (capture snapshot)
6. FullscreenDriver.enterFullscreen (native call)
7. Three-tier confirmation (callback -> poll -> timeout)
8. Update FullscreenSnapshot
9. Broadcast FullscreenEvent
10. WindowService syncs mode via event listener

**Recommended (4 steps):**
1. UI callback
2. WindowService.toggleFullscreen (save bounds, call driver, restore on exit)
3. FullscreenDriver.enterFullscreen (native call)
4. Update ValueNotifier<bool> isFullscreen

## Patterns to Follow

### Pattern 1: Direct Method Calls Over Command Pattern

**What:** Call methods directly instead of enqueueing command objects
**When:** Operations are not concurrent (single-window fullscreen)
**Example:**
```dart
// Current: 258 lines of queue logic
await _queue.enqueue(request, _executeCommand, currentFullscreen: ...);

// Recommended: direct call
await _driver.enterFullscreen();
_isFullscreen = true;
```

### Pattern 2: Single State Source

**What:** One ValueNotifier for fullscreen state, not two parallel systems
**When:** UI only needs to know "is fullscreen or not"
**Example:**
```dart
// Current: dual system requiring sync
WindowService.mode: ValueNotifier<WindowMode>
FullscreenAdapter._snapshots: Map<int, ValueNotifier<FullscreenSnapshot>>

// Recommended: single source
WindowService.isFullscreen: ValueNotifier<bool>
```

### Pattern 3: Platform Driver as Implementation Detail

**What:** Driver interface has minimal methods, platform specifics are internal
**When:** Abstracting platform differences for a single use case
**Example:**
```dart
// Current: 15 methods in FullscreenDriver interface
// Recommended: 5 methods
abstract class FullscreenDriver {
  Future<void> enterFullscreen();
  Future<void> leaveFullscreen();
  Future<bool> isFullscreen();
  Future<Rect> getWindowBounds();
  Future<void> setWindowBounds(Rect bounds);
  void dispose();
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Abstraction for Abstraction's Sake

**What:** Creating interfaces with single implementations
**Why bad:** Adds indirection without polymorphism benefit
**Instead:** Use the concrete class directly, extract interface only when second implementation appears

### Anti-Pattern 2: State Machine for Simple State

**What:** 5-state enum (stable/entering/leaving/forcedChange/error) for a boolean
**Why bad:** Each state requires handling, testing, and documentation
**Instead:** `bool isFullscreen` + `try/catch` for errors

### Anti-Pattern 3: Per-Window Data Structures for Single Window

**What:** `Map<int, ...>` keyed by windowId when only windowId=0 exists
**Why bad:** Adds lookup complexity, null handling, and per-window lifecycle management
**Instead:** Direct field access

## Scalability Considerations

| Concern | At 1 window (current) | At N windows (future) |
|---------|----------------------|----------------------|
| State tracking | Single bool | Map<int, bool> |
| Command serialization | Not needed | Queue per window |
| Restore bounds | Single Rect? | Map<int, Rect?> |
| Event broadcast | ValueNotifier callback | Stream per window |

**Note:** Multi-window support is not planned. If needed in the future, the simplified architecture can be extended at that point. YAGNI applies.

## Sources

- Direct codebase analysis (18 source files)
- Project memory: architecture layers, window anti-patterns, bridge layer design
