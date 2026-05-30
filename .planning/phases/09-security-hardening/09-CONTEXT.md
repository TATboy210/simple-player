# Phase 9: Security Hardening - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

FFI 指针生命周期安全加固 + 输入验证强化。覆盖 WindowService 中所有 `calloc` 分配路径、fullscreen 超时保护、HTTP/HTTPS URL 结构化验证、文件路径控制字符过滤。

不涉及：架构重构（ARCH-01/02/03 延后至 v1.3+）、性能优化（Phase 11）、Debug 工具（Phase 12）。

</domain>

<decisions>
## Implementation Decisions

### FFI 内存安全 (SEC-01)

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

### 输入验证 (SEC-02)

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### FFI 安全
- `lib/kernel/bridge/window_service.dart` — 所有 calloc 分配、fullscreen 转换、dispose 清理
- `lib/kernel/bridge/win32_bindings.dart` — FFI struct 定义和 Win32Bindings 类
- `lib/kernel/persistence/settings_store.dart` — SettingsStore.saveWindowGeometry（被 _scheduleGeometrySave 调用）

### 输入验证
- `lib/kernel/services/path_validator.dart` — PathValidator 类（URL 协议白名单、路径遍历检测、validate 方法）
- `lib/kernel/models/validation_error.dart` — ValidationError 和 ValidationErrorType
- `lib/kernel/engine/fvp_engine.dart` — _configureNetworkOptions（URL 使用点）、open() 方法

### 测试
- `test/kernel/services/path_validator_test.dart` — 现有 PathValidator 测试（111 行）
- `test/kernel/bridge/window_service_test.dart` — WindowService 测试（如果存在）

</canonical_refs>

<specifics>
## Specific Ideas

### FFI 安全具体方案

1. **try/finally 包裹模式**：
```dart
// 短生命周期指针
final margins = calloc<Margins>();
try {
  // ... use margins ...
} finally {
  calloc.free(margins);
}
```

2. **dispose() 补全**：
```dart
void dispose() {
  _disposed = true;
  _resizeDebounce?.cancel();
  if (_savedFrame != null) {
    calloc.free(_savedFrame!);
    _savedFrame = null;
  }
  if (_savedMaximizeFrame != null) {
    calloc.free(_savedMaximizeFrame!);
    _savedMaximizeFrame = null;
  }
  // ... rest of dispose
}
```

3. **fullscreen 超时保护**：
```dart
Timer? _fullscreenTimeout;

Future<void> setFullscreen(bool value) async {
  if (_fullscreenTransitioning) return;
  _fullscreenTransitioning = true;
  _fullscreenTimeout?.cancel();
  _fullscreenTimeout = Timer(const Duration(seconds: 5), () {
    _fullscreenTransitioning = false;
  });
  try {
    // ... enter/exit fullscreen
  } finally {
    _fullscreenTimeout?.cancel();
    _fullscreenTransitioning = false;
  }
}
```

### 输入验证具体方案

1. **HTTP/HTTPS 结构化验证**：
```dart
static String? validate(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '路径为空';
  if (isUrl(trimmed)) {
    // HTTP/HTTPS 需要结构化验证
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || !uri.hasAuthority) return 'URL 格式无效: $trimmed';
    }
    return null; // 其他协议（RTSP/RTMP/SRT/UDP/TCP）跳过
  }
  // ... rest
}
```

2. **控制字符过滤**：
```dart
static bool _hasControlCharacters(String path) {
  for (var i = 0; i < path.length; i++) {
    final code = path.codeUnitAt(i);
    if (code < 0x20 && code != 0x00) return true; // 0x00 已在 isPathTraversal 检测
  }
  return false;
}
```

</specifics>

<deferred>
## Deferred Ideas

- ARCH-01/02/03: FvpEngine 拆分、SettingsStore 简化、单例迁移 — 延后至 v1.3+（需要详细报告）
- 性能优化（PositionPoller、LRU cache、D3D11 sync）— Phase 11
- Debug 工具（结构化日志、Timeline）— Phase 12

</deferred>

---

*Phase: 9 - Security Hardening*
*Context gathered: 2026-05-30 via codebase analysis*
