# Phase 9: Security Hardening - Research

**Researched:** 2026-05-30
**Domain:** FFI 内存安全 + 输入验证加固
**Confidence:** HIGH

## Summary

Phase 9 聚焦两类安全加固：(1) WindowService 中 6+ 处 `calloc` 分配的指针生命周期安全，包括短生命周期指针的异常保护、长生命周期指针的所有路径释放、fullscreen 转换超时保护、dispose() 泄漏修复；(2) PathValidator 输入验证强化，包括 HTTP/HTTPS URL 结构化验证、文件路径控制字符过滤。

代码审查确认了 CONTEXT.md 中描述的所有安全问题。核心发现：`_exitFullscreen()` L214 的 `_savedStyle!` 如果抛异常会导致 `_savedFrame` 永远不释放；`dispose()` L319-321 释放 `_savedMaximizeFrame` 但遗漏 `_savedFrame`；`PathValidator.validate()` L82 对所有 URL 直接 return null 完全跳过验证。

**主要建议：** 使用 `dart:ffi` Arena 包裹短生命周期分配 + try/catch 保证异常安全；长生命周期指针在 finally 块中释放 + dispose() 兜底；Timer 5 秒超时保护 fullscreen 转换标志；`Uri.tryParse()` 验证 HTTP/HTTPS URL 结构。

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEC-01 | FFI 内存安全：6 处 calloc 生命周期管理、_savedFrame dispose 泄漏、fullscreen 超时保护 | 代码审查确认所有 6 处分配位置、异常路径分析、Arena/try-catch 方案 |
| SEC-02 | 输入验证：HTTP/HTTPS Uri.tryParse、RTSP/RTMP 保持、控制字符过滤 | 代码审查确认 validate() 跳过 URL、现有测试基线、ValidationError 模型 |
</phase_requirements>

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01: 短生命周期指针用 Arena/try/finally 包裹**
- `removeBorderImmediate()` 的 `calloc<Margins>()`（L62-68）— 已有 `calloc.free()`，需用 try/finally 保护异常路径
- `_enterFullscreen()` 的 `calloc<Rect>()` frame（L165）、`calloc<Margins>()`（L179）、`calloc<MonitorInfo>()`（L189）— 同上
- `maximize()` 的 `calloc<Rect>()` frame（L258）、`calloc<MonitorInfo>()`（L269）— 同上

**D-02: 长生命周期指针确保所有异常路径释放**
- `_savedFrame`: `_enterFullscreen` 分配（L167-172），`_exitFullscreen` 释放（L227）
  - 风险：`_exitFullscreen` L214 `_savedStyle!` 可能抛异常，导致 L227 `calloc.free` 不执行
  - 修复：将 free 移到 finally 块
- `_savedMaximizeFrame`: `maximize` 分配（L260-265），`restore` 释放（L305）
  - 风险同上
- `dispose()` L319-321: 释放 `_savedMaximizeFrame` 但**遗漏** `_savedFrame` — 内存泄漏
  - 修复：添加 `_savedFrame` 的 null 检查和释放

**D-03: fullscreen 转换超时保护**
- `_fullscreenTransitioning`（L23）在 `setFullscreen()` L145-156 中用 try/finally 重置
- 但如果 `_enterFullscreen()` 或 `_exitFullscreen()` 内部 await 永不完成（如 Win32 API 死锁），标志永久锁定
- 修复：添加 Timer 超时（如 5 秒），超时后强制重置 `_fullscreenTransitioning = false`

**D-04: dispose() 清理完整性**
- 当前 dispose() 释放 `_savedMaximizeFrame` 但不释放 `_savedFrame`
- 添加 `_savedFrame` 释放
- 确保 ValueNotifier 全部 dispose（当前已有，验证即可）

**D-05: HTTP/HTTPS 使用 Uri.tryParse 结构化验证**
- `PathValidator.validate()` L82: `isUrl(trimmed)` 直接返回 null — URL 完全跳过验证
- 修复：对 http:// 和 https:// URL 使用 `Uri.tryParse()` 验证结构合法性
- RTSP/RTMP/SRT/UDP/TCP 保持前缀检测（不阻断 FFmpeg 支持的协议）

**D-06: 文件路径控制字符过滤**
- 当前 `isPathTraversal()` 检测 null byte、`../`、`..\`、UNC、`~`
- 缺失：ASCII 控制字符（0x01-0x1F，除 0x00 外）— 可用于终端注入或其他攻击
- 修复：在 `validate()` 中添加控制字符过滤

**D-07: PathValidator.validate() 中 URL 的 RTSP/RTMP 仍跳过路径遍历检查**
- `isUrl(trimmed)` 返回 true 后直接 return null — 即 RTSP URL 也跳过所有验证
- 可接受：RTSP URL 由 FFmpeg 处理，路径遍历不适用
- 仅 HTTP/HTTPS 需要结构化验证

### Claude's Discretion

- 具体的 try/finally 包裹粒度（每个 calloc 单独保护 vs 整个方法块保护）
- Timer 超时时长（5 秒 vs 3 秒 vs 10 秒）
- 控制字符过滤的具体实现方式（正则 vs 字符遍历）
- 测试策略：新增测试文件 vs 扩展现有 path_validator_test.dart

### Deferred Ideas (OUT OF SCOPE)

- ARCH-01/02/03: FvpEngine 拆分、SettingsStore 简化、单例迁移 — 延后至 v1.3+（需要详细报告）
- 性能优化（PositionPoller、LRU cache、D3D11 sync）— Phase 11
- Debug 工具（结构化日志、Timeline）— Phase 12
</user_constraints>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| FFI 指针生命周期管理 | Kernel/Bridge | — | WindowService 独占 Win32 FFI 交互，指针分配/释放在同一模块 |
| Win32 API 调用 | Kernel/Bridge | — | win32_bindings.dart 封装所有 Win32 函数签名 |
| 输入验证 | Kernel/Services | Engine | PathValidator 是唯一验证入口，FvpEngine.open() 是主要消费者 |
| URL 结构化验证 | Kernel/Services | — | PathValidator.validate() 是集中校验点 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:ffi | SDK 3.11.5 | Arena 内存管理、Pointer 生命周期 | Dart SDK 内建，零依赖 |
| package:ffi | ^2.1.4 | calloc/malloc 分配器 | 已有依赖，提供 Allocator 接口 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:core Uri | SDK 3.11.5 | URL 结构化验证 | HTTP/HTTPS 输入校验 |
| dart:async Timer | SDK 3.11.5 | fullscreen 超时保护 | 防止 `_fullscreenTransitioning` 永久锁定 |
| flutter_test | SDK | 单元测试 | PathValidator 测试扩展 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Arena (dart:ffi) | 手动 try/finally 每个 calloc | Arena 代码更简洁但不适合长生命周期指针 |
| 正则控制字符检测 | 字符遍历 `codeUnitAt` | 正则更简洁但性能略差，现有代码用字符风格一致 |

**安装：** 零新依赖，全部使用 Dart SDK 内建能力。

## Package Legitimacy Audit

本阶段不安装任何外部包。所有改动使用 Dart SDK 内建的 `dart:ffi` Arena、`Uri.tryParse`、`dart:async Timer`。

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | — | — | — | — | — | — |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
用户输入 (文件路径/URL)
    │
    ▼
PathValidator.validate()          ← SEC-02: 新增 HTTP/HTTPS Uri.tryParse + 控制字符过滤
    │                               ← SEC-02: RTSP/RTMP/SRT 保持前缀检测跳过
    ├─ URL? ──► FvpEngine.open()  ← _configureNetworkOptions 设置 FFmpeg 参数
    │
    └─ 本地文件? ──► File.exists() ──► FvpEngine.open()

WindowService                     ← SEC-01: Arena/try-catch 包裹所有 calloc
    │
    ├─ removeBorderImmediate()    ← Margins: 短生命周期，Arena 包裹
    ├─ _enterFullscreen()         ← frame: 短生命周期 Arena; saved/margins/mi: try-catch
    ├─ _exitFullscreen()          ← _savedFrame: finally 块释放
    ├─ maximize()                 ← frame: Arena; mi: try-catch
    ├─ restore()                  ← _savedMaximizeFrame: finally 块释放
    └─ dispose()                  ← 补全 _savedFrame 释放
```

### Recommended Project Structure

```
lib/kernel/
├── bridge/
│   ├── window_service.dart      # MODIFIED: Arena + try-catch + Timer 超时 + dispose 修复
│   └── win32_bindings.dart      # NO CHANGE: FFI struct 定义不变
├── services/
│   └── path_validator.dart      # MODIFIED: Uri.tryParse + 控制字符过滤
└── models/
    └── validation_error.dart    # NO CHANGE: ValidationErrorType 已有 invalidUrl

test/kernel/services/
└── path_validator_test.dart     # MODIFIED: 新增 URL 验证 + 控制字符测试用例
```

### Pattern 1: Arena for Short-Lived FFI Allocations

**What:** 使用 `dart:ffi` 的 `Arena` 分配器包裹短生命周期指针，在 Arena 离开作用域时自动释放所有分配。

**When to use:** 指针仅在单个方法内使用，不需要跨方法保存。

**Example:**
```dart
// Source: dart:ffi SDK documentation
// removeBorderImmediate() — Margins 仅在此方法内使用
static Future<int> removeBorderImmediate() async {
  final hwnd = await windowManager.getId();
  final style = win32.getWindowLongPtr(hwnd, gwlStyle);
  final newStyle = style & ~wsCaption;
  win32.setWindowLongPtr(hwnd, gwlStyle, newStyle);

  // Arena 自动管理 margins 生命周期
  using((arena) {
    final margins = arena<Margins>()
      ..ref.left = 0
      ..ref.right = 0
      ..ref.top = 1
      ..ref.bottom = 0;
    win32.dwmExtendFrameIntoClientArea(hwnd, margins);
  });

  win32.setWindowPos(hwnd, 0, 0, 0, 0, 0,
    swpNoOwnerZOrder | swpFrameChanged | 0x0001 | 0x0002);
  return newStyle;
}
```

### Pattern 2: try/catch for Long-Lived Pointer Exception Safety

**What:** 长生命周期指针（`_savedFrame`, `_savedMaximizeFrame`）在分配后存储为实例字段，在释放方法中用 try/catch 确保异常路径也释放。

**When to use:** 指针需要跨方法边界保存（分配在一个方法，释放在另一个方法）。

**Example:**
```dart
Future<void> _exitFullscreen() async {
  if (!isFullscreen.value) return;
  final hwnd = await windowManager.getId();

  try {
    win32.setWindowLongPtr(hwnd, gwlStyle, _savedStyle!);
    if (_savedFrame != null) {
      win32.setWindowPos(hwnd, 0,
        _savedFrame!.ref.left,
        _savedFrame!.ref.top,
        _savedFrame!.ref.right - _savedFrame!.ref.left,
        _savedFrame!.ref.bottom - _savedFrame!.ref.top,
        swpNoOwnerZOrder | swpFrameChanged,
      );
    }
  } finally {
    // 确保异常路径也释放
    if (_savedFrame != null) {
      calloc.free(_savedFrame!);
      _savedFrame = null;
    }
    _savedStyle = null;
  }

  if (isFullscreen.value) isFullscreen.value = false;
}
```

### Pattern 3: Timer Timeout Guard for Transition Flags

**What:** 使用 `Timer` 为异步转换标志设置超时保护，防止标志永久锁定。

**When to use:** 异步操作设置了阻塞标志，如果内部 await 永不完成会导致标志永久锁定。

**Example:**
```dart
Timer? _fullscreenTimeout;

Future<void> setFullscreen(bool value) async {
  if (_fullscreenTransitioning) return;
  _fullscreenTransitioning = true;
  _fullscreenTimeout?.cancel();
  _fullscreenTimeout = Timer(const Duration(seconds: 5), () {
    if (_fullscreenTransitioning) {
      debugPrint('WindowService: fullscreen transition timeout, force reset');
      _fullscreenTransitioning = false;
    }
  });
  try {
    if (value) {
      await _enterFullscreen();
    } else {
      await _exitFullscreen();
    }
  } finally {
    _fullscreenTimeout?.cancel();
    _fullscreenTransitioning = false;
  }
}
```

### Anti-Patterns to Avoid

- **Arena 用于长生命周期指针：** Arena 在作用域结束时释放所有分配，如果指针需要跨方法保存会导致 use-after-free。长生命周期指针用 try/catch + 手动释放。
- **裸 `!` 操作符无保护：** `_savedStyle!` 在 `_exitFullscreen` 中如果为 null 会抛异常，导致后续 `calloc.free(_savedFrame!)` 不执行。用 null 检查替代 `!`。
- **URL 验证假设所有协议等价：** HTTP/HTTPS 需要结构化验证（用户可控输入），RTSP/RTMP 由 FFmpeg 内部处理（不阻断）。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FFI 内存自动释放 | 自定义 RAII wrapper | `dart:ffi` Arena (`using`) | SDK 内建，标准模式，零维护 |
| URL 结构验证 | 自定义 URL parser | `Uri.tryParse()` | SDK 内建，处理编码/端口/路径等边界情况 |
| 异步超时保护 | 自定义 Completer + delay | `Timer` + `Future.timeout` | SDK 内建，简单直接 |

## Common Pitfalls

### Pitfall 1: Arena 用于需要跨作用域的指针
**What goes wrong:** 将 `_savedFrame` 放入 Arena，Arena 在方法结束时释放它，后续 `_exitFullscreen` 访问已释放内存。
**Why it happens:** Arena 的设计是作用域绑定的，不适合长生命周期分配。
**How to avoid:** 短生命周期用 Arena，长生命周期用 try/catch + 手动释放。
**Warning signs:** 指针赋值给实例字段 (`_savedFrame = ...`) 时不应使用 Arena。

### Pitfall 2: _exitFullscreen 中 _savedStyle! 的空安全
**What goes wrong:** 如果 `_enterFullscreen` 未执行（如窗口已全屏但状态不同步），`_savedStyle` 为 null，`_savedStyle!` 抛异常。
**Why it happens:** 没有 null 守卫，依赖 `!` 操作符。
**How to avoid:** 用 `if (_savedStyle != null)` 替代 `_savedStyle!`，或在 early return 中检查。
**Warning signs:** `!` 操作符在 FFI 代码中使用。

### Pitfall 3: URL 验证破坏现有测试
**What goes wrong:** 添加 HTTP/HTTPS 结构化验证后，现有测试 `test('returns null for URL', ...)` 期望所有 URL 返回 null。
**Why it happens:** 测试用例 `'https://example.com/stream'` 是合法 URL，但如果验证逻辑有 bug 可能失败。
**How to avoid:** 保持合法 URL 返回 null，仅对结构无效的 URL 返回错误。新增测试覆盖无效 URL。
**Warning signs:** `flutter test` 中 path_validator_test 失败。

### Pitfall 4: 控制字符过滤误杀合法路径
**What goes wrong:** 过于宽泛的控制字符过滤可能误杀包含特殊字符的合法文件名。
**Why it happens:** 0x09 (tab) 在某些文件系统中是合法字符。
**How to avoid:** 仅过滤 0x01-0x1F（排除 0x00 已在 isPathTraversal 检测），保留 0x09 (tab) 作为可选。
**Warning signs:** 合法文件名被拒绝。

### Pitfall 5: dispose() 双重释放
**What goes wrong:** `_exitFullscreen` 的 finally 块释放 `_savedFrame` 并设为 null，但 dispose() 也尝试释放。
**Why it happens:** 释放后未将指针设为 null。
**How to avoid:** 每次 `calloc.free(ptr)` 后立即 `ptr = null`。dispose() 中先检查 null。
**Warning signs:** 访问违规或 double-free 崩溃。

## Code Examples

### 短生命周期指针 — Arena 包裹

```dart
// Source: dart:ffi SDK — using() 函数
// removeBorderImmediate() 中的 margins 分配
using((arena) {
  final margins = arena<Margins>()
    ..ref.left = 0
    ..ref.right = 0
    ..ref.top = 1
    ..ref.bottom = 0;
  win32.dwmExtendFrameIntoClientArea(hwnd, margins);
});
```

### _enterFullscreen — 混合 Arena + 手动管理

```dart
Future<void> _enterFullscreen() async {
  if (isFullscreen.value) return;
  final hwnd = await windowManager.getId();

  // 保存 style
  _savedStyle = _baseStyle ?? win32.getWindowLongPtr(hwnd, gwlStyle);

  // 保存窗口位置 — 长生命周期，手动管理
  using((arena) {
    final frame = arena<Rect>();
    win32.getWindowRect(hwnd, frame);
    final saved = calloc<Rect>()
      ..ref.left = frame.ref.left
      ..ref.top = frame.ref.top
      ..ref.right = frame.ref.right
      ..ref.bottom = frame.ref.bottom;
    _savedFrame = saved; // 跨方法保存，不放入 Arena
  });

  // 设置 WS_POPUP
  win32.setWindowLongPtr(hwnd, gwlStyle, wsPopup);

  // 移除 DWM 阴影 — 短生命周期
  using((arena) {
    final margins = arena<Margins>()
      ..ref.left = -1
      ..ref.right = -1
      ..ref.top = -1
      ..ref.bottom = -1;
    win32.dwmExtendFrameIntoClientArea(hwnd, margins);
  });

  // 获取监视器边界并定位 — 短生命周期
  final hMonitor = win32.monitorFromWindow(hwnd, monitorDefaultToNearest);
  using((arena) {
    final mi = arena<MonitorInfo>()
      ..ref.cbSize = sizeOf<MonitorInfo>();
    win32.getMonitorInfo(hMonitor, mi);
    win32.setWindowPos(hwnd, hwndTop,
      mi.ref.rcMonitor.left, mi.ref.rcMonitor.top,
      mi.ref.rcMonitor.right - mi.ref.rcMonitor.left,
      mi.ref.rcMonitor.bottom - mi.ref.rcMonitor.top,
      swpNoOwnerZOrder | swpFrameChanged,
    );
  });

  if (!isFullscreen.value) isFullscreen.value = true;
}
```

### _exitFullscreen — finally 块保证释放

```dart
Future<void> _exitFullscreen() async {
  if (!isFullscreen.value) return;
  final hwnd = await windowManager.getId();

  try {
    if (_savedStyle != null) {
      win32.setWindowLongPtr(hwnd, gwlStyle, _savedStyle!);
    }
    if (_savedFrame != null) {
      win32.setWindowPos(hwnd, 0,
        _savedFrame!.ref.left,
        _savedFrame!.ref.top,
        _savedFrame!.ref.right - _savedFrame!.ref.left,
        _savedFrame!.ref.bottom - _savedFrame!.ref.top,
        swpNoOwnerZOrder | swpFrameChanged,
      );
    }
  } finally {
    if (_savedFrame != null) {
      calloc.free(_savedFrame!);
      _savedFrame = null;
    }
    _savedStyle = null;
  }

  if (isFullscreen.value) isFullscreen.value = false;
}
```

### dispose() 补全

```dart
void dispose() {
  _disposed = true;
  _resizeDebounce?.cancel();
  _fullscreenTimeout?.cancel();

  if (_savedFrame != null) {
    calloc.free(_savedFrame!);
    _savedFrame = null;
  }
  if (_savedMaximizeFrame != null) {
    calloc.free(_savedMaximizeFrame!);
    _savedMaximizeFrame = null;
  }

  windowManager.removeListener(this);
  isFullscreen.dispose();
  isAlwaysOnTop.dispose();
  isMaximized.dispose();
  windowSize.dispose();
}
```

### PathValidator — HTTP/HTTPS 结构化验证 + 控制字符

```dart
static String? validate(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '路径为空';

  if (isUrl(trimmed)) {
    // HTTP/HTTPS 需要结构化验证
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || !uri.hasAuthority) {
        return 'URL 格式无效: $trimmed';
      }
    }
    // RTSP/RTMP/SRT/UDP/TCP 跳过验证（FFmpeg 内部处理）
    return null;
  }

  if (_hasControlCharacters(trimmed)) {
    return '路径包含非法控制字符: $trimmed';
  }
  if (isPathTraversal(trimmed)) return '路径不安全: $trimmed';
  if (!isAllowedMedia(trimmed)) return '不支持的文件类型: $trimmed';
  return null;
}

static bool _hasControlCharacters(String path) {
  for (var i = 0; i < path.length; i++) {
    final code = path.codeUnitAt(i);
    if (code < 0x20 && code != 0x00) return true; // 0x00 已在 isPathTraversal 检测
  }
  return false;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 手动 calloc.free() 无异常保护 | Arena + try/finally | Phase 9 | 异常路径不再泄漏内存 |
| URL 完全跳过验证 | HTTP/HTTPS Uri.tryParse 结构化验证 | Phase 9 | 防止畸形 URL 进入 FFmpeg |
| 无控制字符过滤 | 0x01-0x1F 控制字符检测 | Phase 9 | 防止终端注入攻击 |

**Deprecated/outdated:**
- 无。本阶段不引入新的废弃项。

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `dart:ffi` Arena 在 SDK 3.11.5 中可用 | Standard Stack | 如果不可用，回退到手动 try/finally 每个 calloc |
| A2 | `_savedStyle!` 在 `_exitFullscreen` 中可能为 null（如果 `_enterFullscreen` 未执行） | Pitfall 2 | 如果不可能为 null，则 null 检查是冗余但无害的 |
| A3 | 0x09 (tab) 不需要过滤（Windows 文件名允许 tab） | D-06 | 如果需要过滤 tab，需调整 `_hasControlCharacters` 范围 |
| A4 | Timer 5 秒超时适合所有硬件 | D-03 | 较慢机器可能需要更长时间，但 5 秒有足够余量 |

## Open Questions

1. **Arena 在 `using()` 中分配后赋值给实例字段是否安全？**
   - What we know: Arena 在 `using()` 块结束时释放所有分配。如果 `_savedFrame = calloc<Rect>()` 在 Arena 内但赋值给实例字段，Arena 结束后指针被释放。
   - What's unclear: 需要确认长生命周期分配**不能**放入 Arena。
   - Recommendation: 长生命周期分配（`_savedFrame`, `_savedMaximizeFrame`）保持 `calloc` 直接分配 + 手动释放。仅短生命周期用 Arena。

2. **PathValidator.validate() 返回类型是否需要改为 ValidationError？**
   - What we know: `validation_error.dart` 已有 `ValidationError` 和 `ValidationErrorType`（含 `invalidUrl`）。
   - What's unclear: 当前 `validate()` 返回 `String?`，改为 `ValidationError?` 会改变调用方签名。
   - Recommendation: Phase 9 保持 `String?` 返回类型（最小改动），后续 Phase 可考虑迁移。

3. **_hasControlCharacters 是否应排除 0x09 (tab)？**
   - What we know: Windows 文件名允许 tab 字符。0x09 (tab) 在 0x01-0x1F 范围内。
   - What's unclear: 实际场景中文件名包含 tab 的概率极低。
   - Recommendation: 排除 0x09（`code != 0x09`），避免误杀合法文件名。

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Dart SDK | Arena, Uri.tryParse, Timer | ✓ | ^3.11.5 | — |
| package:ffi | calloc, Struct allocation | ✓ | ^2.1.4 | — |
| flutter_test | 单元测试 | ✓ | SDK | — |
| window_manager | WindowService 依赖 | ✓ | ^0.5.1 | — |

**Missing dependencies with no fallback:**
- 无。所有依赖已就绪。

**Missing dependencies with fallback:**
- 无。

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test test/kernel/services/path_validator_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SEC-01 | Arena 包裹短生命周期 calloc | unit | `flutter test test/kernel/bridge/window_service_test.dart` | ❌ Wave 0 (需要新建或用 fake) |
| SEC-01 | finally 块释放 _savedFrame | unit | 同上 | ❌ Wave 0 |
| SEC-01 | dispose() 释放 _savedFrame | unit | 同上 | ❌ Wave 0 |
| SEC-01 | fullscreen 超时重置 | unit | `flutter test test/kernel/bridge/window_service_timeout_test.dart` | ❌ Wave 0 |
| SEC-02 | HTTP URL 有效返回 null | unit | `flutter test test/kernel/services/path_validator_test.dart` | ✅ 扩展 |
| SEC-02 | HTTP URL 无效返回错误 | unit | 同上 | ❌ Wave 0 |
| SEC-02 | HTTPS URL 有效返回 null | unit | 同上 | ❌ Wave 0 |
| SEC-02 | RTSP/RTMP 保持跳过验证 | unit | 同上 | ❌ Wave 0 |
| SEC-02 | 控制字符被拒绝 | unit | 同上 | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/kernel/services/path_validator_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/kernel/services/path_validator_test.dart` — 扩展：新增 HTTP/HTTPS 验证、RTSP 保持、控制字符过滤测试组
- [ ] WindowService 测试 — 由于 FFI 依赖，建议通过 FakeWindowService 或集成测试覆盖 dispose/timeout 逻辑
- [ ] Arena 可用性验证 — 确认 `dart:ffi` `using()` 在 SDK 3.11.5 中编译通过

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | 桌面播放器无认证需求 |
| V3 Session Management | no | 无会话管理 |
| V4 Access Control | no | 无角色/权限系统 |
| V5 Input Validation | yes | PathValidator + Uri.tryParse + 控制字符过滤 |
| V6 Cryptography | no | 无加密需求 |

### Known Threat Patterns for Flutter Desktop + FFI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-----|
| FFI 内存泄漏/use-after-free | Denial of Service | Arena + try/finally + dispose 完整性 |
| Path traversal (../) | Elevation of Privilege | isPathTraversal() 已有检测 |
| Control character injection | Tampering | 0x01-0x1F 过滤 |
| Malformed URL to FFmpeg | Denial of Service | Uri.tryParse 结构化验证 |
| Null byte injection | Elevation of Privilege | \x00 检测已有 |
| Fullscreen transition lock | Denial of Service | Timer 超时保护 |

## Sources

### Primary (HIGH confidence)
- `lib/kernel/bridge/window_service.dart` — 代码审查确认所有 6 处 calloc 位置、异常路径分析
- `lib/kernel/services/path_validator.dart` — 代码审查确认 URL 跳过验证、控制字符缺失
- `lib/kernel/models/validation_error.dart` — 确认 ValidationErrorType 枚举含 invalidUrl
- `pubspec.yaml` — 确认 SDK ^3.11.5、ffi ^2.1.4、无新依赖

### Secondary (MEDIUM confidence)
- dart:ffi Arena — 训练数据确认 Arena 从 Dart 2.17 起可用（[ASSUMED] SDK 3.11.5 包含）

### Tertiary (LOW confidence)
- 无。

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 全部使用 Dart SDK 内建能力，零新依赖
- Architecture: HIGH — 代码审查确认所有安全问题位置和修复方案
- Pitfalls: HIGH — 基于代码分析的具体风险点，非泛泛而谈

**Research date:** 2026-05-30
**Valid until:** 2026-06-13 (14 天 — 代码库活跃期)
