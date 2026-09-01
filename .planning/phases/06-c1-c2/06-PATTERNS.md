# Phase 6: 能力探测与 C1/C2 钉死 - Pattern Map

**Mapped:** 2026-09-02
**Files analyzed:** 5 (2 new, 2 modify, 1 read-only)
**Analogs found:** 5 / 5

> **Tracked-source note (#3645):** On-disk `lib/kernel/window_Bridge/` (capital B)
> is the Windows case-insensitive mirror of the git-tracked tree
> `lib/kernel/window_bridge/` (lowercase b). All analog paths below cite the
> git-tracked lowercase form (verified via `git ls-files`). No gitignored mirror
> paths are emitted.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| NEW: Dart FFI probe (DwmCapabilities) — `lib/kernel/diagnostics/dwm_capabilities.dart` (+ `dwm_capabilities_probe.dart` FFI leaf) | service / FFI facade | request-response (one-shot startup probe) | `lib/kernel/services/thumbnail_service.dart` + `lib/kernel/window_bridge/window_manager_service.dart` | role-match (platform-aware facade wrapping a platform lib; lib/ has zero `dart:ffi`, so pattern is the facade+state structure, not FFI syntax) |
| NEW: gate script — `tool/audit/c1_c2_gates.sh` | utility / config | batch (CI gate, read-only stdout) | `tool/audit/phase16_gates.sh` | exact (multi-gate bash + grep + structural fingerprint) |
| MODIFY: `lib/kernel/window_bridge/` (Dart consumption of probe snapshot) | service / state | request-response (ValueNotifier) | `lib/kernel/window_bridge/window_service_state.dart` + `lib/kernel/window_bridge/window_mode_coordinator.dart` | exact (same dir, same state+coordinator pattern) |
| MODIFY: `windows/runner/flutter_window.cpp` (guard comment + C1 structure pin) | native C++ / WndProc | event-driven (Win32 message) | (self-anchor — no analog; excerpted as-is) | anchor (file is its own baseline) |
| READ-ONLY: `lib/kernel/diagnostics/kernel_logger.dart` + `lib/kernel/diagnostics/error_reporter.dart` (D-04 failure reporting) | service | event-driven (dedup + report) | (self-anchor — consumed, not modified) | anchor |

## Pattern Assignments

### NEW: `lib/kernel/diagnostics/dwm_capabilities.dart` (service / FFI facade, request-response one-shot)

**Analog (platform-aware facade structure):** `lib/kernel/services/thumbnail_service.dart`
**Analog (platform-lib wrapper + Logger + ValueNotifier state):** `lib/kernel/window_bridge/window_manager_service.dart`

Rationale: `lib/` currently has **zero** `dart:ffi` usage (Win32 bridge lives in
`window_manager` package, not in-project FFI). The closest structural analog is
the platform-aware facade pattern: `ThumbnailService` branches on
`defaultTargetPlatform` and lazily selects a provider; `WindowService` wraps the
`window_manager` package and exposes `ValueNotifier` state. The new
DwmCapabilities probe should follow the same shape: a facade that (a) branches on
platform, (b) wraps the FFI leaf behind a private getter, (c) exposes an
immutable snapshot via `ValueNotifier` (D-01 「Dart 侧统一消费」), and (d) logs
via `KernelLogger.I` (kernel-layer log gate — `lib/kernel/` 禁 `debugPrint`).

**Facade + lazy platform select pattern** (`thumbnail_service.dart:18-43`):
```dart
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService _instance = ThumbnailService._();
  ThumbnailProvider? _impl;

  ThumbnailProvider get _providerImpl {
    final existing = _impl;
    if (existing != null) return existing;
    final created = switch (defaultTargetPlatform) {
      TargetPlatform.windows => const NoopThumbnailProvider(),
      TargetPlatform.linux => const LinuxThumbnailProvider(),
      TargetPlatform.macOS => const MacosThumbnailProvider(),
      _ => const NoopThumbnailProvider(),
    };
    _impl = created;
    return created;
  }
}
```
Copy this shape: lazy `_impl` field + `switch (defaultTargetPlatform)` + Windows
branch probes ntdll/dwmapi; Linux/macOS branches return a placeholder
`LinuxCompositorCapabilities` (Phase 11 对等形态 — D-01 requires the Dart
structure leave a peer slot for Linux; do NOT implement Linux probe now).

**Platform-lib wrapper + Logger + ValueNotifier state** (`window_manager_service.dart:24-36, 74-87`):
```dart
final _log = KernelLogger.I;   // file-scope logger accessor (kernel convention)

class WindowService with WindowListener implements WindowBridge {
  final WindowServiceState _state = WindowServiceState();
  // ...
  @override
  bool get isFullscreen => _state.mode.value.isFullscreen;   // single source of truth
  @override
  ValueNotifier<WindowMode> get mode => _state.mode;          // identity-preserved forwarding
}
```
Copy: file-scope `final _log = KernelLogger.I;`, a state container class
holding `ValueNotifier<DwmCapabilitySnapshot>`, and getters that forward the
notifier instance (identity-preservation — Phase 7/8 attribute gates will read
this notifier; do not wrap in a new notifier).

**Imports pattern** (`window_manager_service.dart:1-14`) — bilingual doc +
`package:flutter/foundation.dart` for `ValueNotifier` + internal package paths
(no barrel files):
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../diagnostics/kernel_logger.dart';
// ... direct file-to-file imports, no barrel
```

**Error handling pattern** (`window_manager_service.dart:96-99, 162-165`):
```dart
} on Exception catch (error, stackTrace) {
  _log.e('[WindowService.init] $error\n$stackTrace');
  rethrow;
}
```
Probe failures (FFI `lookupFunction` miss, DLL absent) MUST route through
`KernelLogger.I.e(...)` with `[DwmCapabilities...]` prefix; the HRESULT-non-S_OK
reporting path additionally calls `ErrorReporterImpl.I.reportPlatformSafely`
(see Shared Patterns D-04).

---

### NEW: `tool/audit/c1_c2_gates.sh` (utility / CI gate, batch read-only)

**Analog (exact):** `tool/audit/phase16_gates.sh`
**Secondary analog (single-rule grep gate):** `tool/audit/kernel_logger_gate.sh`

`phase16_gates.sh` is the exact structural twin of what D-02/D-03 require: a
multi-gate bash script with GATE 1 / GATE 2, mixing grep-based rules and
structural-fingerprint rules, read-only + stdout, exit 0/1 for CI.

**Script skeleton + design principles** (`phase16_gates.sh:1-41`):
```bash
#!/usr/bin/env bash
# tool/audit/c1_c2_gates.sh
#
# C1/C2 钉死静态结构闸门脚本 (Phase 6, D-02/D-03)。
#
# 两个闸门 — Two structural gates:
#   GATE 1 (D-02, C1): WM_NCCALCSIZE 多分支结构指纹 + 守卫注释存在性 +
#     禁止裸 `return 0`（单分支 fallback 视为 C1 回归）。
#   GATE 2 (D-03, C2): 全项目禁止读 VideoState.isFullscreen 作全屏信号
#     （「便宜，一行规则」，用户原话）。
#
# 设计原则（沿用 phase16_gates.sh / inventory.sh）：
#   - 只读 + stdout，无文件写入、无网络、无输入面。
#   - rg/grep 兼容层：优先 ripgrep，降级到 GNU grep。
#   - CI 可自动化：exit 0 = pass, exit 1 = fail，可诊断证据行。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

**Multi-gate dispatch + per-gate evidence** (`phase16_gates.sh:134-148`):
```bash
main() {
  local exit_code=0
  gate1_open_generation || exit_code=1
  echo ""
  gate2_size_budget || exit_code=1
  return "$exit_code"
}
main "$@"
```
Copy this `main` shape: GATE 1 (C1 structural) || GATE 2 (C2 grep) || ...;
each gate prints `GATE N FAIL/PASS (rule-id): <evidence>` and returns 0/1.

**rg/grep compat layer** (`kernel_logger_gate.sh:23-47`) — copy verbatim for
portability across CI runners without ripgrep:
```bash
if command -v rg >/dev/null 2>&1; then
  SEARCH_CMD="rg"
else
  SEARCH_CMD="grep"
fi
search_kernel() {
  local pattern="$1"; local exclude_file="${2:-}"
  if [ "$SEARCH_CMD" = "rg" ]; then
    rg -n "$pattern" --type dart "$KERNEL_DIR" ${exclude_file:+-g "!**/${exclude_file}"} || true
  else
    grep -rn "$pattern" --include='*.dart' "$KERNEL_DIR" ${exclude_file:+| grep -v "/${exclude_file}:"} || true
  fi
}
```

**GATE 2 (D-03 「一行规则」) shape** — single negative-grep gate modeled on
`kernel_logger_gate.sh:53-65` (gate1_package_logger):
```bash
gate2_c2_single_source() {
  local hits
  hits=$(rg -n 'VideoState\.isFullscreen' --type dart "$REPO_ROOT/lib" || true)
  if [ -n "$hits" ]; then
    echo "GATE 2 FAIL (D-03): 'VideoState.isFullscreen' read as fullscreen signal — must use WindowBridge.isFullscreen instead:"
    printf '%s\n' "$hits"
    return 1
  fi
  echo "GATE 2 PASS (D-03): zero 'VideoState.isFullscreen' fullscreen-signal reads."
  return 0
}
```

**GATE 1 (D-02, structural fingerprint) shape** — modeled on
`phase16_gates.sh:46-96` (the doc-comment-vs-code discriminator): the gate must
check (a) the guard comment block exists in `flutter_window.cpp`, (b) the
`WM_NCCALCSIZE` branch structure (currently a single fullscreen→`return 0`
branch per `flutter_window.cpp:63-71`; the gate pins whatever structure is
canonicalized in this phase), (c) no bare `return 0` outside the guarded
branches. Use `grep -n` line evidence the same way gate1_open_generation does.

---

### MODIFY: `lib/kernel/window_bridge/` (service / state, ValueNotifier)

**Analog (exact, same directory):**
- `lib/kernel/window_bridge/window_service_state.dart` — state container pattern
- `lib/kernel/window_bridge/window_mode_coordinator.dart` — serial coordinator consuming state

The probe snapshot needs a consumption entry in the window service layer. The
existing `WindowServiceState` holds the `ValueNotifier<WindowMode>` that C2
declares as the single fullscreen source (`window_service_state.dart:18`,
`:177` via `window_manager_service.dart:76`). The new
`ValueNotifier<DwmCapabilitySnapshot>` should be added as a peer notifier on
`WindowServiceState` (or a sibling state class in the same directory) so
`WindowBridge` can expose it to Phase 7/8 attribute consumers.

**State container pattern** (`window_service_state.dart:13-39`):
```dart
final class WindowServiceState {
  WindowServiceState({Size initialSize = defaultWindowSize})
    : _windowSize = ValueNotifier(initialSize);

  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  final ValueNotifier<Size> _windowSize;
  // ...
  bool _disposed = false;
  bool get disposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mode.dispose();
    // ...
  }
}
```
Copy: nullable-backed `ValueNotifier` fields, `_disposed` guard, idempotent
`dispose()` that disposes every notifier. Add
`final ValueNotifier<DwmCapabilitySnapshot> dwmCapabilities = ValueNotifier(...)`.

**Coordinator consuming state (serial + generation guard)** (`window_mode_coordinator.dart:34-49, 98-101`):
```dart
Future<void> _operation = Future<void>.value();
int _generation = 0;

Future<void> setMode(WindowMode target) {
  final operation = _operation.then((_) => _setSerialized(target));
  _operation = operation.catchError((Object error, StackTrace stackTrace) {
    _log('[WindowModeCoordinator.setMode] $error\n$stackTrace');
  });
  return operation;
}

void _commit(int generation, WindowMode mode) {
  if (_disposed || generation != _generation) return;   // stale-callback guard
  _state.mode.value = mode;
}
```
If the probe needs a settle-point re-read (Phase 7 BORD-03, out of scope here
per CONTEXT `specifics`), the coordinator's generation-guard + serial-queue
pattern is the template — but this phase only delivers the one-shot startup
probe, so a simpler `_state.dwmCapabilities.value = snapshot` write suffices.

**C2 single-source baseline** (`window_manager_service.dart:74-76`) — the line
GATE 2 (D-03) protects as the positive baseline:
```dart
/// 当前是否全屏 — 从 mode 派生，单一数据源。
@override
bool get isFullscreen => _state.mode.value.isFullscreen;
```

---

### MODIFY: `windows/runner/flutter_window.cpp` (native C++ / WndProc, event-driven)

**Self-anchor** — no analog. The file is the canonical C1 location; the gate
script (above) fingerprints its structure. Read as-is for the current C1 state.

**Current C1 NCCALCSIZE handler** (`flutter_window.cpp:46-93`) — the full
MessageHandler. The existing handler is a **single-branch** fullscreen guard
(not the 3-branch fullscreen/maximized/default described in CONTEXT `domain`;
the gate in this phase will pin whichever structure the implementation
canonicalizes). Excerpt:
```cpp
LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // media_kit 原生全屏期间抢先处理 WM_NCCALCSIZE（必须早于插件 delegate，
  // 插件在 HandleTopLevelWindowProc 中先被调用且总是返回结果）。
  // ... [guard comment block — D-02 守卫注释存在性检查的目标] ...
  if (message == WM_NCCALCSIZE && wparam != FALSE)
  {
    const LONG_PTR style = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    if ((style & WS_OVERLAPPEDWINDOW) == 0)
    {
      return 0;   // fullscreen: 客户区=整窗，四边无缝
    }
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) return *result;
  }
  // ...
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
```
**Guard comment** (`flutter_window.cpp:51-62`) — the bilingual block the gate
must verify exists; it documents *why* the early-return exists (window_manager
plugin's 8px inset on non-maximized windows). Any structural change to the
NCCALCSIZE branch must keep this comment or update it.

**Integration point for probe** (`flutter_window.cpp:12-34`, `OnCreate`) —
D-01 chose Dart FFI, so the C++ side does **not** get a new probe call. The
only C++ modification this phase is the guard-comment + structure pin (D-02).
Phase 7/8 attribute *setting* (also Dart FFI per deferred note) likewise adds
no C++ here.

---

### READ-ONLY: `lib/kernel/diagnostics/kernel_logger.dart` + `error_reporter.dart` (D-04 failure reporting)

**Anchors** — consumed, not modified. The probe's HRESULT-non-S_OK path routes
through these two files per D-04.

**KernelLogger singleton + `.e()` signature** (`kernel_logger.dart:483-504, 442-450`):
```dart
final class KernelLoggerImpl extends KernelLogger {
  static KernelLoggerImpl? _instance;
  static KernelLoggerImpl get I {
    final inst = _instance;
    if (inst == null) {
      throw StateError('KernelLoggerImpl.I accessed before init(). ...');
    }
    return inst;
  }
  // ...
}

void e(String m, {
  Map<String, Object?>? context,
  Object? error,
  StackTrace? stackTrace,
}) { this.error(m, context: context, error: error, stackTrace: stackTrace); }
```
D-04 「每次失败必记」→ every HRESULT != S_OK call site does:
```dart
_log.e('[DwmCapabilities] DwmGetWindowAttribute(...) hr=$hr',
       context: {'attribute': attrId, 'build': build}, error: null);
```

**ErrorReporter dedup + `reportPlatformSafely`** (`error_reporter.dart:44-103, 184-192, 344-360`):
```dart
final class ErrorReporterImpl implements ErrorReporter {
  static const Duration _dedupeWindow = Duration(seconds: 10);  // 10s roll-back window
  static ErrorReporterImpl get I { /* throws StateError if pre-init */ }
  // ...
  @override
  void reportPlatformSafely(Object error, StackTrace stackTrace) {
    _reportSafely(
      source: ErrorSource.platformDispatcher,
      severity: ErrorSeverity.error,
      error: error, suppliedStack: stackTrace,
    );
  }

  _AcceptanceResult _accept(ErrorReport candidate) {
    final matchingIndex = _newestInWindowIndex(candidate);  // 10s dedup
    if (matchingIndex != null) {
      final merged = existing.copyWith(
        lastOccurredAt: candidate.lastOccurredAt,
        occurrenceCount: existing.occurrenceCount + 1,   // aggregate, no new card
      );
      // ...
      return _AcceptanceResult(merged, ReportAcceptance.merged);
    }
    // ... else append new
  }
}
```
D-04 「同类失败首次聚合成一条 ErrorReport 上报，卡片不刷屏」→ the probe's
first occurrence of a given HRESULT failure calls
`ErrorReporterImpl.I.reportPlatformSafely(error, StackTrace.current)`; the
10-second `_dedupeWindow` collapses the rest into `occurrenceCount` bumps (no
new card). Per-call logging via `KernelLogger.I.e(...)` is independent of the
dedup gate (log every time, report once).

## Shared Patterns

### Kernel-layer logging (must-use in `lib/kernel/`)
**Source:** `lib/kernel/diagnostics/kernel_logger.dart` (verified tracked)
**Apply to:** NEW `dwm_capabilities.dart` / `dwm_capabilities_probe.dart` (both under `lib/kernel/`)
```dart
final _log = KernelLogger.I;   // file-scope; throws StateError if pre-init
// ...
_log.e('[DwmCapabilities] ...', context: {...}, error: e, stackTrace: st);
```
**Hard rule:** `lib/kernel/**` 禁 `debugPrint()` — enforced by
`tool/audit/kernel_logger_gate.sh`. The new FFI files live under
`lib/kernel/diagnostics/` and MUST use `KernelLogger` exclusively.

### Error reporting dedup (D-04)
**Source:** `lib/kernel/diagnostics/error_reporter.dart` (`ErrorReporterImpl.I.reportPlatformSafely`)
**Apply to:** NEW `dwm_capabilities_probe.dart` HRESULT-non-S_OK path
- Log every failure via `KernelLogger.I.e(...)` (per-call).
- Report once-per-10s-window via `ErrorReporterImpl.I.reportPlatformSafely(error, StackTrace.current)` — the existing `_dedupeWindow` + `_identity` tuple deduplicates by `(source, severity, errorType, code, message, ...)`. Reuse, do NOT build a parallel dedup.

### ValueNotifier + identity-preserved forwarding
**Source:** `lib/kernel/window_bridge/window_service_state.dart`, `window_manager_service.dart:74-87`
**Apply to:** NEW `dwm_capabilities.dart` snapshot exposure
- Expose snapshot as `ValueNotifier<DwmCapabilitySnapshot>` on the state container.
- WindowBridge getter forwards the **same** notifier instance (no wrapping) — Phase 7/8 attribute gates will `addListener` on it; wrapping breaks listener attach (Blocking Constraint #6, documented in CLAUDE.md).

### Sealed result types for fallible ops (convention, not mandated this phase)
**Source:** `lib/kernel/engine/open_result.dart` (sealed `OpenSuccess`/`OpenError`/`OpenSuperseded`)
**Apply to:** probe snapshot could model "probe succeeded / probe failed (DLL absent) / probe unsupported (non-Windows)" as a sealed type if the planner prefers exhaustive dispatch. For a one-shot startup probe, a nullable snapshot field + `KernelLogger` log is simpler (KISS) and matches `ThumbnailService`'s nullable-return convention.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `dwm_capabilities_probe.dart` FFI leaf (`ntdll` RtlGetVersion + `dwmapi` DwmGetWindowAttribute probe) | FFI service | request-response | `lib/` has **zero** `dart:ffi` usage — no in-project FFI analog exists. Structural analog is `thumbnail_service.dart` (platform facade) + `window_manager_service.dart` (platform-lib wrapper). For the FFI syntax itself (DynamicLibrary.open, lookupFunction, NativeFunctionType), the planner must reference RESEARCH.md `STACK.md` + the read-only external pattern `media_kit_video-2.0.1/windows/utils.cc:85` (RtlGetVersion build-detection, per CONTEXT `canonical_refs` — 复制不链接). No tracked in-repo FFI code to copy from. |

## Metadata

**Analog search scope:**
- `lib/kernel/window_bridge/` (8 files)
- `lib/kernel/services/` (11 files)
- `lib/kernel/diagnostics/` (22 files)
- `tool/audit/` (7 scripts)
- `windows/runner/` (3 cpp files)

**Files scanned:** 51
**Pattern extraction date:** 2026-09-02
**Tracked-source verification:** all 11 cited analog paths verified via `git ls-files -- <path>` (non-empty). On-disk `window_Bridge` (capital B) remapped to tracked `window_bridge` (lowercase b) — Windows case-insensitive FS; no gitignored mirror paths emitted.
