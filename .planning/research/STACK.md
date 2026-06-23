# Stack Research — Cross-Platform Window Management

**Researched:** 2026-06-23
**Confidence:** MEDIUM

## Core Recommendation

Keep `window_manager` (0.5.1) as primary cross-platform window API. No new packages needed. Supplement with platform-specific FFI where window_manager falls short.

## Recommended Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| `window_manager` | ^0.5.1 | Cross-platform window API (resize, move, fullscreen, titlebar) |
| `ffi` | ^2.1.0 | Platform-specific FFI (Win32, X11/Wayland, NSWindow) |
| `fvp` | ^0.37.2 | Media engine (D3D11/OpenGL/Vulkan/Metal internally) |
| Platform channels | Flutter built-in | Dart ↔ native code for macOS traffic lights, Linux CSD |

## What NOT to Use

| Library | Why Not |
|---------|---------|
| `bitsdojo_window` | Unmaintained since ~2023, broken on recent Flutter |
| `desktop_window` | Too limited — no titlebar, no frameless, no events |
| `yaru_window` | Ubuntu-only, GNOME-specific |
| `flutter_acrylic` | Windows-only; project uses cross-platform BackdropFilter |

## x86 + ARM Matrix

| Component | Win x86_64 | Win ARM64 | Linux x86_64 | Linux ARM64 | macOS x86_64 | macOS ARM64 |
|-----------|-----------|-----------|-------------|-------------|-------------|-------------|
| Flutter | Stable | Experimental | Stable | Stable | Stable | Stable |
| window_manager | Stable | Likely | Stable | Stable | Stable | Stable |
| fvp (MDK) | Stable | Needs test | Stable | Stable | Stable | Stable |

## Platform-Specific Risks

| Area | Risk | Notes |
|------|------|-------|
| Linux frameless | HIGH | GTK CSD varies by DE/WM |
| Linux fullscreen | MEDIUM | Wayland vs X11 differences |
| macOS fullscreen | LOW | Native toggleFullScreen API |
| Windows ARM64 | LOW | MDK ARM64 binary availability unknown |
| macOS ARM64 | HIGH confidence | Universal2 binaries |

---
*Researched: 2026-06-23*
