# Phase 1: Platform Abstraction Layer - Context

**Gathered:** 2026-06-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Refactor WindowBridge into a platform-agnostic abstraction with factory pattern. The current `WindowService` mixes Windows-specific logic (window_manager, Win32PlatformFullscreen) with bridge implementation. This phase extracts the interface, creates a factory for platform selection, adds capability querying, and ensures the shared WindowState model works across platforms — without changing any behavior.

**Deliverables:**
- WindowBridge interface with zero Windows-specific code
- PlatformBridgeFactory that selects correct implementation at startup
- WindowCapabilities enum for platform feature queries
- Shared WindowState model verified platform-agnostic
- All existing Windows tests pass unchanged

**Not in scope:** Linux/macOS bridge implementations (Phases 3/4), new features, behavior changes.

</domain>

<decisions>
## Implementation Decisions

### Factory Pattern
- **D-01:** Static factory method `PlatformBridgeFactory.create()` on a dedicated class (not embedded in WindowService)
- **D-02:** Factory uses `defaultTargetPlatform` for platform detection (Flutter standard, no custom detection)
- **D-03:** Factory throws `UnsupportedError` for unimplemented platforms (Linux/macOS until Phases 3/4)
- [auto] Selected: dedicated factory class, recommended default

### File Organization
- **D-04:** Platform implementations in `lib/kernel/bridge/{platform}/` subdirectories (e.g., `win32/`, `linux/`, `macos/`)
- **D-05:** Current `win32/` directory already exists with `win32_platform_fullscreen.dart` — extend this pattern
- **D-06:** Shared abstractions (`WindowBridge`, `WindowState`, `WindowMode`, `WindowCapabilities`) stay in `lib/kernel/bridge/` root
- [auto] Selected: subdirectory-per-platform, recommended default

### WindowCapabilities
- **D-07:** `WindowCapabilities` as a class with boolean fields (not an enum) — allows per-platform composition
- **D-08:** Fields: `supportsRoundedCorners`, `supportsNativeFullscreen`, `supportsAlwaysOnTop`, `supportsWindowPersistence`, `supportsDragToResize`, `supportsMinimize`
- **D-09:** Each platform bridge returns its capabilities via a `capabilities` getter on WindowBridge
- [auto] Selected: class with boolean fields, recommended default

### WindowService Refactoring
- **D-10:** Rename `WindowService` → `WindowsBridge` implementing `WindowBridge` (clearer naming)
- **D-11:** `WindowsBridge` moves to `lib/kernel/bridge/win32/windows_bridge.dart`
- **D-12:** Existing `FullscreenController`, `WindowPersistence`, `DisplayConfig` stay as internal components of WindowsBridge
- **D-13:** `PlatformFullscreen` strategy pattern stays as-is (already clean abstraction)
- [auto] Selected: rename + move, recommended default

### WindowState Model
- **D-14:** `WindowState` stays in `lib/kernel/bridge/window_state.dart` — already platform-agnostic
- **D-15:** No changes to WindowState fields (mode, windowSize, isResizing, isAlwaysOnTop)
- **D-16:** Platform-specific state (e.g., Win32 DPI) handled internally by platform bridge, not in shared state
- [auto] Selected: no changes, recommended default

### Integration
- **D-17:** `main.dart` creates bridge via `PlatformBridgeFactory.create()` instead of `WindowService()`
- **D-18:** All UI code depends on `WindowBridge` interface — no changes needed (already abstract)
- **D-19:** `FakeWindowService` renamed to `FakeWindowBridge` for consistency
- [auto] Selected: factory in main.dart, rename fake, recommended default

### Claude's Discretion
- WindowCapabilities exact field list (may adjust during implementation)
- Whether to extract WindowBootstrap into WindowsBridge or keep separate
- Exact import path restructuring

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Patterns
- `.planning/codebase/ARCHITECTURE.md` — 3-layer architecture, component responsibilities, import rules
- `.planning/codebase/STRUCTURE.md` — Directory layout, naming conventions, where to add new code
- `.planning/codebase/STACK.md` — Flutter/fvp/window_manager versions, platform constraints

### Requirements
- `.planning/REQUIREMENTS.md` — PLAT-01..04, ARCH-01..04 requirement specs with traceability
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria

### Existing Bridge Code (read before refactoring)
- `lib/kernel/bridge/window_bridge.dart` — Current abstract interface (4 state + 6 commands)
- `lib/kernel/bridge/window_service.dart` — Current implementation to refactor into WindowsBridge
- `lib/kernel/bridge/window_state.dart` — Shared state container (platform-agnostic)
- `lib/kernel/bridge/window_mode.dart` — WindowMode enum
- `lib/kernel/bridge/fullscreen_controller.dart` — Atomic fullscreen with mutex + PlatformFullscreen strategy
- `lib/kernel/bridge/platform_fullscreen.dart` — Platform fullscreen interface
- `lib/kernel/bridge/win32/win32_platform_fullscreen.dart` — Win32 fullscreen implementation
- `lib/kernel/bridge/window_persistence.dart` — Debounce geometry persistence
- `lib/kernel/bridge/display_config.dart` — D3D11 refresh-rate policy

### Test Code
- `test/helpers/fake_window_service.dart` — Test double to rename
- `test/` — All existing tests must pass unchanged

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WindowBridge` abstract interface: already clean (4 ValueNotifiers + 6 commands), no changes needed to interface itself
- `WindowState` pure state container: already platform-agnostic, reusable across all platform bridges
- `WindowMode` enum: platform-neutral (windowed, fullscreen, maximized, minimized)
- `PlatformFullscreen` strategy pattern: already demonstrates platform abstraction for fullscreen
- `FullscreenController` with mutex + Completer: reusable pattern for any platform bridge

### Established Patterns
- Abstract interface → concrete implementation: `PlayerEngine`/`FvpEngine` pattern — same approach for `WindowBridge`/`WindowsBridge`
- Strategy pattern: `PlatformFullscreen` already uses this for fullscreen — extend for full bridge
- Subdirectory per platform: `win32/` already exists — extend to `linux/`, `macos/`
- ValueNotifier + ValueListenableBuilder: all window state exposed this way

### Integration Points
- `main.dart`: WindowService initialization — change to factory call
- `PlayerScreen`: depends on WindowBridge interface — no changes needed
- `SettingsPanel`: queries window state via WindowBridge — no changes needed
- `StartupCoordinator`: window init phase — may need factory call adjustment

</code_context>

<specifics>
## Specific Ideas

- WindowBridge 接口本身已经很干净，不需要修改接口签名
- 重点是把 Windows 特定代码从 WindowService 中分离出来
- Factory pattern 参考 `PlayerEngine` 的抽象模式
- `window_manager` 包是跨平台的，但 WindowsBridge 会用到它；Linux/macOS 可能需要不同的包

</specifics>

<deferred>
## Deferred Ideas

- Linux/macOS bridge implementations: Phase 3/4
- Platform-specific keyboard shortcuts: Phase 2
- Multi-monitor support: v2

</deferred>

---

*Phase: 01-Platform Abstraction Layer*
*Context gathered: 2026-06-23*
