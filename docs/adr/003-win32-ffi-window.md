# ADR-003: Win32 FFI for Window Management

## Status

**Adopted** (project inception, validated through Phase 1-14, confirmed for cross-platform strategy)

## Context

A frameless desktop media player requires precise window control:

1. Frameless window with custom title bar (drag, minimize, maximize, close).
2. Fullscreen toggle with zero-frame compositing (no 7px border gap from `WS_THICKFRAME`).
3. Multi-monitor awareness (clamp window to nearest monitor on resize/display change).
4. Window geometry persistence (position, size, maximized/fullscreen state restored on launch).
5. Always-on-top toggle.
6. Responsive layout (compact breakpoint at 500dp, ultra-compact at 360dp).

The key constraint: **the fullscreen transition must be pixel-perfect with no visible artifacts** (no 1-frame flash of a native title bar, no 7px border gap, no compositing flicker). This is the defining visual quality of the player.

### Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **Win32 FFI (dart:ffi)** | Full control, no third-party dep for Windows, zero-frame fullscreen, atomic `SetWindowPos`, direct `WS_THICKFRAME` manipulation | Windows-only, manual FFI binding, C-level error handling | **CHOSEN (Windows primary path)** |
| `window_manager` package | Cross-platform, easy API, frameless support | Cannot fix WS_THICKFRAME 7px gap, fullscreen via package has visible artifacts, slower path for geometry queries | **USED as fallback + geometry utility** |
| `flutter_fullscreen` package | Dedicated fullscreen plugin | Internally depends on window_manager, cannot fix WS_THICKFRAME gap, user confirmed `win32` package causes 1-frame stutter | REJECTED — evaluated and documented (Phase 1 D-06) |
| `bitsdojo_window` | Frameless + snap layout support | Additional dependency, similar WS_THICKFRAME limitation | REJECTED — same fundamental limitation |
| C++ runner modification only | No Dart FFI complexity | Cannot control fullscreen from Dart side, no runtime toggling | INSUFFICIENT — need Dart-side control |

## Decision

Use **Win32 FFI via `dart:ffi`** as the primary window management path on Windows, with `window_manager` as a utility layer for geometry persistence and cross-platform compatibility.

### Architecture

```
WindowBridge (abstract interface)
  ├── WindowService (concrete: WindowListener + FullscreenDriver)
  ├── FullscreenDriver (abstract)
  │   ├── WindowsFullscreenDriver (Win32 FFI primary path)
  │   ├── MacosFullscreenDriver (fullscreen_window package)
  │   └── LinuxFullscreenDriver (fullscreen_window package)
  └── DesktopFullscreenDriverFactory (platform detection + compile-time flag)
```

Key design rules:

- **`WindowBridge`** is the abstract interface (5 state notifiers + 7 command methods). All UI code depends on this interface, never on `WindowService` directly.
- **`WindowsFullscreenDriver`** uses direct Win32 FFI calls: `SetWindowPos` (atomic reposition), `GetWindowLong`/`SetWindowLong` (style bit manipulation), `EnumDisplayMonitors` (multi-monitor enumeration).
- **`Win32FullscreenApi`** is the raw FFI binding layer (~509 lines) wrapping `user32.dll` calls with `calloc`/`free` in `finally` blocks.
- **`WindowService`** coordinates: fullscreen enter/leave with confirmation chain (callback-first, polling fallback), resize debounce (500ms), geometry save/restore, always-on-top.
- **Compile-time flag:** `USE_WINDOWS_NATIVE_FULLSCREEN` (via `--dart-define`) controls whether the Win32 FFI driver is used (`true`) or window_manager fallback (`false`, default).
- **macOS/Linux:** Use `packages/fullscreen_window/` local fork (113-line C++ macOS, 182-line C Linux) via MethodChannel — no Win32 FFI on these platforms.
- **`WindowState`** is an immutable state container with `copyWith` for all window state fields.
- **Geometry persistence** via `WindowPersistence` backed by `shared_preferences`.

### Win32 FFI Safety Patterns

- All `calloc.allocate` calls paired with `free()` in `finally` blocks.
- Style bit manipulation (`WS_THICKFRAME`, `WS_EX_TOPMOST`) documented with decision references (D-P05/D-P06/D-P07/D-P08).
- `SetWindowPos` used atomically (single call for position + size + Z-order) to avoid flicker.
- Multi-monitor clamp via `EnumDisplayMonitors` + `GetMonitorInfo` callback FFI pattern.

## Consequences

### Positive

- **Pixel-perfect fullscreen.** Direct `WS_THICKFRAME` removal + `SetWindowPos` produces zero-frame, zero-gap fullscreen with no compositing artifacts. This is the defining visual quality that no third-party package could deliver.
- **Zero additional dependency for Windows.** `dart:ffi` + `user32.dll` is stdlib + OS — no `win32` package, no `bitsdojo`, no `flutter_fullscreen`.
- **Multi-monitor awareness.** `EnumDisplayMonitors` + `GetMonitorInfo` via FFI enables proper window clamping across displays with different DPI/resolution.
- **Atomic window operations.** `SetWindowPos` sets position, size, and Z-order in a single OS call — no intermediate frames where the window is in a wrong state.
- **Testability.** `WindowBridge` abstract interface enables `FakeWindowService` in tests without any platform dependency.

### Negative

- **Windows-only primary path.** The Win32 FFI code is Windows-specific. macOS and Linux use a different code path (`fullscreen_window` package). Cross-platform behavior differences exist (e.g., Linux Wayland fullscreen callback timing).
- **Fragile FFI layer.** Win32 style bit manipulation depends on undocumented Windows behavior. Changes to Windows 10/11 window management could break the FFI path.
- **Complex state coordination.** `WindowService` (~451 lines) coordinates fullscreen, resize, persistence, geometry, and confirmation chains. Multiple `Timer` instances (`_resizeDebounce`, `_resizeEndTimer`) with cancellation logic add complexity.
- **Platform-specific debugging.** FFI bugs (wrong style bits, HWND invalidation, multi-monitor edge cases) require real Windows testing — mock-based tests verify logic but not FFI behavior.

### Mitigations

- `FakeWindowService` + `FakeFullscreenDriver` for unit tests.
- 765-line test file for `WindowsFullscreenDriver` covering style bit logic, state transitions, and error recovery.
- Confirmation chain with callback-first, polling-fallback pattern handles native callback timing variations.
- `WindowState` immutable container + `copyWith` prevents inconsistent intermediate states.
- Phase 1 simplified the architecture: deleted `DesktopFullscreenDriver` and `DesktopFullscreenDriverFactory` (4 layers to 3).

## Related Decisions

- [ADR-004: Layered Architecture](004-layered-architecture.md) — Window management lives in the Kernel/Bridge layer.
- [ADR-002: fvp/MDK Engine](002-fvp-mdk-engine.md) — Engine rendering (D3D11 texture) is separate from window management (Win32 FFI).
- [ADR-001: ValueNotifier](001-value-notifier-state-management.md) — Window state exposed as `ValueNotifier<WindowMode>`, `ValueNotifier<Size>`, etc.

## References

- `lib/kernel/bridge/window_bridge.dart` — Abstract interface (5 states + 7 commands).
- `lib/kernel/bridge/window_service.dart` — Concrete implementation (~451 lines, coordinates all window operations).
- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` — Win32 FFI fullscreen driver (~459 lines).
- `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` — Raw Win32 FFI bindings (~509 lines).
- `lib/kernel/bridge/win32/win32_display_enumerator.dart` — Multi-monitor enumeration FFI.
- `lib/kernel/bridge/window_state.dart` — Immutable state container with `copyWith`.
- `lib/kernel/bridge/window_persistence.dart` — Geometry save/restore via `shared_preferences`.
- `lib/kernel/bridge/window_mode.dart` — `WindowMode` enum (windowed/maximized/fullscreen/minimized).
- `packages/fullscreen_window/` — Local fork for macOS/Linux fullscreen.
- `.planning/phase-1/01-CONTEXT.md` — Phase 1 decisions: D-01 through D-16, flutter_fullscreen evaluation (D-06: REJECTED).
- `.planning/codebase/CONCERNS.md` — Win32 Fullscreen FFI Layer fragility notes.
- `.planning/codebase/INTEGRATIONS.md` — Platform Bridge section: Win32 FFI + MethodChannel details.
- Project memory: `anti_pattern_fullscreen_ffi.md` — WS_THICKFRAME 7px gap root cause, `win32` package causes 1-frame stutter.
- Project memory: `project_fullscreen_win32_fix.md` — 2026-05-20 Win32 FFI rewrite: atomic `SetWindowPos` fullscreen.
