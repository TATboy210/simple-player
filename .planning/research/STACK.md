# Technology Stack

**Project:** simple_player_flutter (Fullscreen Simplification)
**Researched:** 2026-07-11

## Recommended Stack

### Core Framework (Unchanged)
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Flutter | stable | Desktop UI framework | Already in use, no change needed |
| Dart | 3.x | Language | Already in use |

### Window Management (Unchanged)
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| window_manager | ^0.4.x | Cross-platform window operations | Already integrated, provides getPosition/getSize/setBounds/maximize |
| fullscreen_window | ^1.x | macOS/Linux native fullscreen | Provides native fullscreen animation + platform callbacks |
| Win32 FFI (dart:ffi) | - | Windows fullscreen | Custom implementation in win32_fullscreen_ffi.dart, solves WS_THICKFRAME gap |

### What to Remove
| Technology | Purpose | Why Remove |
|------------|---------|-----------|
| Custom command queue | Serialization | Single-window app has no concurrency |
| Custom state machine | Phase tracking | Boolean suffices |
| Custom event stream | Lifecycle events | ValueNotifier callback suffices |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| State management | Single ValueNotifier<bool> | Keep dual system | Unnecessary complexity |
| Error handling | try/catch | Keep 7-type hierarchy | 6 of 7 types unused |
| Command pattern | Direct method calls | Keep command queue | No concurrency to serialize |

## Installation

No new dependencies needed. The simplification only removes custom code, not packages.

```bash
# Existing dependencies (keep):
flutter pub get  # window_manager, fullscreen_window already in pubspec.yaml
```

## Sources

- Direct codebase analysis (18 source files, 8 test files)
- Project memory: fullscreen bugs, architecture layers, window patterns
