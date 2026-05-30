# Technology Stack: v1.2 Additions

**Project:** Simple Player Flutter
**Researched:** 2026-05-30
**Scope:** Stack additions/changes for security hardening, debug tooling, architecture optimization

## Executive Summary

**No new packages required.** All four capabilities (FFI memory safety, URL/path validation, debug tooling, SettingsStore simplification) can be achieved with Dart SDK built-in features and the existing `logger` package. The project already has everything it needs in `dart:ffi` (Arena, Finalizer), `dart:core` (Uri.tryParse, Finalizer), and `logger` 2.7.0 (custom LogPrinter/LogOutput).

## Actual Versions (from `flutter pub deps`)

| Package | pubspec.yaml | Resolved | Notes |
|---------|-------------|----------|-------|
| Dart SDK | ^3.11.5 | 3.13.0-103.1.beta | Beta channel |
| Flutter SDK | (latest) | 3.45.0-0.1.pre | Beta channel |
| ffi | ^2.1.4 | 2.2.0 | Has Arena/using() |
| logger | ^2.5.0 | 2.7.0 | Has custom LogPrinter |
| shared_preferences | ^2.5.5 | 2.5.5 | Stable |
| fvp | ^0.36.2 | 0.36.2 | 0.37.0 available |

---

## 1. FFI Memory Safety

### Problem

`WindowService` manually manages `calloc`/`free` for 6+ pointer allocations across `_enterFullscreen()`, `_exitFullscreen()`, `maximize()`, `restore()`, and `removeBorderImmediate()`. Leak risks:

- `_savedFrame` not freed in `dispose()` (only `_savedMaximizeFrame` is)
- Exception between `calloc` and `free` leaks memory
- No timeout on `_fullscreenTransitioning` boolean guard

### Solution: Zero New Packages

**Tool A: `using()` + `Arena` from `dart:ffi`** (available since Dart 2.17)

Scoped allocations that auto-free on scope exit, even on exceptions:

```dart
import 'dart:ffi';

// BEFORE (leaky)
final frame = calloc<Rect>();
win32.getWindowRect(hwnd, frame);
final saved = calloc<Rect>()
  ..ref.left = frame.ref.left
  ..ref.top = frame.ref.top;
_savedFrame = saved;
calloc.free(frame);  // leaks if exception above

// AFTER (safe)
using((Arena arena) {
  final frame = arena<Rect>();
  win32.getWindowRect(hwnd, frame);
  _savedFrame = calloc<Rect>()  // long-lived, freed in dispose()
    ..ref.left = frame.ref.left
    ..ref.top = frame.ref.top;
  // frame auto-freed when arena exits
});
```

**Tool B: `try/finally` for long-lived pointers**

`_savedFrame` and `_savedMaximizeFrame` have lifetimes spanning method calls. These cannot use Arena. Use try/finally:

```dart
Future<void> _enterFullscreen() async {
  final hwnd = await windowManager.getId();
  final saved = calloc<Rect>();
  try {
    // ... populate saved ...
    _savedFrame = saved;
    // ... Win32 API calls ...
  } finally {
    // Only free if we didn't hand off ownership
    if (_savedFrame != saved) calloc.free(saved);
  }
}
```

**Tool C: `Finalizer<T>` from `dart:core`** (optional, for defense-in-depth)

Register a finalizer on `WindowService` to catch GC-time leaks:

```dart
class WindowService with WindowListener {
  static final _pointerFinalizer = Finalizer<Pointer<Rect>>((ptr) {
    calloc.free(ptr);
  });

  void _attachFrame(Pointer<Rect> frame) {
    _savedFrame = frame;
    _pointerFinalizer.attach(this, frame, detach: this);
  }
}
```

**Recommendation:** Use `using()` for all short-lived allocations (frame, margins, MonitorInfo). Use `try/finally` for long-lived pointers (`_savedFrame`, `_savedMaximizeFrame`). Skip `Finalizer` — it adds complexity for marginal safety gain when try/finally is correct.

**Tool D: Timer-based fullscreen timeout**

Pure Dart, no package:

```dart
Timer? _fullscreenTimeout;

Future<void> setFullscreen(bool value) async {
  if (_fullscreenTransitioning) return;
  _fullscreenTransitioning = true;
  _fullscreenTimeout = Timer(const Duration(seconds: 2), () {
    _fullscreenTransitioning = false;  // force-reset stuck guard
    log.w('Fullscreen transition timeout — guard reset');
  });
  try {
    // ... transition logic ...
  } finally {
    _fullscreenTimeout?.cancel();
    _fullscreenTransitioning = false;
  }
}
```

### Integration Points

- `lib/kernel/bridge/window_service.dart` — all 6 allocation sites
- `dispose()` — add `_savedFrame` cleanup
- No new imports needed beyond `dart:ffi` (already imported)

---

## 2. URL/Path Validation

### Problem

`PathValidator.isUrl()` only checks string prefix (`startsWith`). No structural URL validation. Malformed URLs pass through to FFmpeg.

### Solution: Zero New Packages

**`Uri.tryParse()` from `dart:core`** — built-in, zero dependencies:

```dart
static String? validateUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return 'URL 格式无效';
  if (!uri.hasScheme) return 'URL 缺少协议';
  if (!_urlSchemes.contains('${uri.scheme}://')) {
    return '不支持的协议: ${uri.scheme}';
  }
  if (uri.host.isEmpty) return 'URL 缺少主机名';
  // Length check: Windows MAX_PATH = 260, but URLs can be longer
  if (url.length > 2048) return 'URL 过长 (${url.length} > 2048)';
  return null;  // valid
}
```

**Enhance existing `PathValidator`:**

```dart
/// 完整校验：扩展名 + 路径遍历 + URL 结构
static String? validate(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '路径为空';
  if (isUrl(trimmed)) return validateUrl(trimmed);  // NEW: structural validation
  if (isPathTraversal(trimmed)) return '路径不安全: $trimmed';
  if (trimmed.length > 260) return '路径过长 (${trimmed.length} > 260)';  // NEW
  if (!isAllowedMedia(trimmed)) return '不支持的文件类型: $trimmed';
  return null;
}
```

### Integration Points

- `lib/kernel/services/path_validator.dart` — add `validateUrl()` and path length check
- `lib/kernel/engine/fvp_engine.dart` — already calls `PathValidator.validate()`
- No new imports needed

---

## 3. Debug Tooling

### Problem

Current logging uses `logger` package with `PrettyPrinter` + `_RotatingFileOutput`. `PerfMonitor` uses `dart:developer` with ring buffer. No structured JSON output for automated analysis, no diagnostics panel.

### Solution: One Package Enhancement (Optional)

**Already have: `logger` 2.7.0** — supports custom `LogPrinter` and `LogOutput`.

**Enhancement A: Structured JSON printer** (no new package)

```dart
class StructuredPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final json = jsonEncode({
      'ts': DateTime.now().toIso8601String(),
      'level': event.level.name,
      'msg': event.message,
      if (event.error != null) 'error': event.error.toString(),
      if (event.stackTrace != null) 'trace': event.stackTrace.toString(),
    });
    return [json];
  }
}
```

**Enhancement B: Named logger instances** (no new package)

Replace global `log` with named instances for subsystem filtering:

```dart
// Current: single global logger
Logger log = Logger(...);

// Proposed: named loggers per subsystem
final logEngine = Logger(printer: ..., filter: ...);  // engine subsystem
final logWindow = Logger(printer: ..., filter: ...);  // window subsystem
final logUI = Logger(printer: ..., filter: ...);       // UI subsystem
```

**Enhancement C: `dart:developer` Timeline integration** (no new package)

Add timeline events for DevTools Performance tab:

```dart
import 'dart:developer';

Future<void> _enterFullscreen() async {
  Timeline.startSync('WindowService.enterFullscreen');
  try {
    // ... existing logic ...
  } finally {
    Timeline.finishSync();
  }
}
```

**Enhancement D: Diagnostics panel** (no new package)

Extend existing `PerfMonitor.exportStats()` with engine state:

```dart
Map<String, dynamic> exportDiagnostics() => {
  'perf': PerfMonitor.instance.exportStats(),
  'engine': {
    'position': _positionNotifier.value,
    'volume': _volumeNotifier.value,
    'isPlaying': _isPlayingNotifier.value,
  },
  'window': {
    'isFullscreen': isFullscreen.value,
    'isMaximized': isMaximized.value,
    'size': '${windowSize.value.width}x${windowSize.value.height}',
  },
};
```

### Optional Package: `logging` (dart:logging)

The `logger` package (sourcehorizon) is separate from Dart's built-in `logging` package. Consider:

| Option | Pros | Cons |
|--------|------|------|
| Keep `logger` 2.7.0 | Pretty output, file rotation built-in | Not Dart-standard |
| Switch to `logging` | Dart-standard, integrates with `dart:developer` | Need custom output/formatting |

**Recommendation:** Keep `logger` 2.7.0. It works, file rotation is custom-built, and switching adds churn for no user-visible benefit.

### Integration Points

- `lib/kernel/utils/log.dart` — add StructuredPrinter option, named loggers
- `lib/kernel/utils/perf_monitor.dart` — add Timeline integration
- `lib/kernel/bridge/window_service.dart` — add Timeline.startSync/finishSync
- No new packages needed

---

## 4. SettingsStore Simplification

### Problem

439 lines, 25+ individual save methods, 6 touch points per new setting. Each method: key constant + save method + load() case + saveAll() case + default fallback + AppSettings field.

### Solution: Generic Save Helper (No New Packages)

**Pattern: `_saveField<T>()` with type dispatch**

```dart
/// Generic field save — eliminates per-field save methods
static Future<void> _saveField<T>(String key, T value, {T? clamp(T v)?}) async {
  try {
    final prefs = await _getPrefs();
    final safeValue = clamp != null ? clamp(value) : value;
    switch (safeValue) {
      case double v => await prefs.setDouble(key, v);
      case int v => await prefs.setInt(key, v);
      case bool v => await prefs.setBool(key, v);
      case String v => await prefs.setString(key, v);
      default => throw ArgumentError('Unsupported type: ${T.runtimeType}');
    }
  } on Exception catch (e) {
    log.e('SettingsStore._saveField($key) failed: $e');
  }
}

// Usage: replaces 25+ individual methods
static Future<void> saveVolume(double value) =>
    _saveField(_keyVolume, value, clamp: (v) => v.clamp(0.0, 1.0));

static Future<void> saveIsMuted(bool value) =>
    _saveField(_keyIsMuted, value);

static Future<void> savePlayMode(int mode) =>
    _saveField(_keyPlayMode, mode, clamp: (v) => v.clamp(0, PlayMode.values.length - 1));
```

**Pattern: JSON serialization for bulk save/load**

```dart
/// Serialize entire AppSettings to JSON — single write
static Future<void> saveAllJson(AppSettings s) async {
  try {
    final prefs = await _getPrefs();
    await prefs.setString(_keySettings, jsonEncode(s.toJson()));
  } on Exception catch (e) {
    log.e('SettingsStore.saveAllJson failed: $e');
  }
}

/// Deserialize with defaults fallback
static Future<AppSettings> loadJson() async {
  try {
    final prefs = await _getPrefs();
    final json = prefs.getString(_keySettings);
    if (json != null) return AppSettings.fromJson(jsonDecode(json));
  } on Exception catch (e) {
    log.e('SettingsStore.loadJson failed: $e');
  }
  return const AppSettings.defaults();
}
```

**Recommendation:** Use `_saveField<T>()` pattern. It preserves the existing SharedPreferences key structure (backward compatible), eliminates boilerplate, and keeps individual field saves for settings panel deferred-apply. JSON serialization is cleaner but breaks backward compatibility with existing persisted data.

### Migration Strategy

1. Add `_saveField<T>()` helper
2. Rewrite individual save methods to one-liners using `_saveField`
3. Keep `saveAll()` for batch writes (settings panel Apply)
4. Keep `load()` with per-field reads (backward compatible)
5. Delete the 25+ individual save method bodies

### Integration Points

- `lib/kernel/persistence/settings_store.dart` — rewrite save methods
- `lib/kernel/models/app_settings.dart` — already has `toJson()`/`fromJson()` (freezed)
- No new packages needed

---

## What NOT to Add

| Tempting Package | Why Not |
|-----------------|---------|
| `get_it` / service locator | v1.2 scope is singleton cleanup, not full DI migration |
| `riverpod` / `bloc` | ValueNotifier preserved per constraints |
| `hive` / `isar` / `drift` | SharedPreferences is sufficient for ~25 settings keys |
| `flutter_secure_storage` | No secrets in a media player |
| `sentry` / `crashlytics` | Overkill for desktop-only, user-owned app |
| `intl` (for structured logging) | `logger` already handles this |

---

## Summary: Zero New Dependencies

| Capability | Solution | New Package? |
|-----------|----------|-------------|
| FFI memory safety | `using()` + Arena from `dart:ffi` | No |
| URL/path validation | `Uri.tryParse()` from `dart:core` | No |
| Debug tooling | Custom `LogPrinter` + `Timeline` from `dart:developer` | No |
| SettingsStore simplification | Generic `_saveField<T>()` | No |
| Fullscreen timeout | `Timer` from `dart:async` | No |

The only version-adjacent action: **upgrade fvp from 0.36.2 to 0.37.0** (one minor version, check changelog for breaking changes before upgrading).

---

*Research: 2026-05-30. Confidence: HIGH — all solutions use Dart SDK built-ins already available in Dart 3.13.*
