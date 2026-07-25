# Security Hardening Plan — Simple Player Flutter

> Generated: 2026-07-20 | Status: DRAFT | Target: Desktop media player (Windows/macOS/Linux)

---

## 1. Executive Summary

### Current Security Posture

Simple Player Flutter is a desktop media player that handles user-provided file paths, JSON persistence, MDK/FFmpeg engine integration, and Win32 FFI bridge calls. The codebase demonstrates **moderate** security awareness with an existing `PathValidator` class covering path traversal and extension whitelisting, but has significant gaps in input validation depth, type safety, and error information leakage.

### Risk Overview

| Risk Level | Count | Description |
|------------|-------|-------------|
| CRITICAL   | 3     | JSON deserialization crashes, unbounded `as` casts, path validation bypass |
| HIGH       | 5     | Error message leakage, missing file size limits, process injection via `openFileLocation` |
| MEDIUM     | 6     | Inconsistent type safety, missing URL scheme hardening, folder scanner depth abuse |
| LOW        | 4     | Debug output in release, missing rate limiting on file operations |

### Primary Attack Vectors

1. **Malicious media files** — crafted files exploiting MDK/FFmpeg parser vulnerabilities
2. **Path traversal** — `../` sequences in drag-and-drop or playlist history
3. **JSON injection** — tampered playlist/settings files causing type cast crashes
4. **URL scheme abuse** — `file://`, `javascript:`, or custom schemes passed as media URLs

---

## 2. Threat Model

### 2.1 Attack Surface Analysis

```
┌─────────────────────────────────────────────────────────┐
│                    External Inputs                       │
├──────────┬──────────┬───────────┬───────────┬───────────┤
│ Drag &   │ File     │ Playlist  │ Settings  │ Stream    │
│ Drop     │ Picker   │ JSON File │ JSON File │ URL       │
│ (OS→App) │ (OS→App) │ (Disk→App)│ (Disk→App)│ (Network) │
└────┬─────┴────┬─────┴─────┬─────┴─────┬─────┴─────┬─────┘
     │          │           │           │           │
     ▼          ▼           ▼           ▼           ▼
┌─────────────────────────────────────────────────────────┐
│              PathValidator.validate()                    │
│         (Single validation gateway — GOOD)              │
└─────────────────────────┬───────────────────────────────┘
                          │
     ┌────────────────────┼────────────────────┐
     ▼                    ▼                    ▼
┌──────────┐      ┌──────────────┐     ┌──────────────┐
│DropHandler│     │FileOperations│     │ MediaOpener  │
│(desktop_ │     │(open/add)    │     │(MDK/FFmpeg)  │
│  drop)   │     │              │     │              │
└──────────┘      └──────────────┘     └──────────────┘
```

### 2.2 Threat Classification

| Threat | STRIDE Category | Entry Point | Impact |
|--------|----------------|-------------|--------|
| Path traversal in dropped files | Tampering | `DropHandler` | Arbitrary file access |
| JSON playlist tampering | Tampering | `PlaylistStore` | App crash, code execution |
| Settings file injection | Tampering | `SettingsStore` | Config manipulation |
| Malicious media file | Elevation of Privilege | `MediaOpener` / FFmpeg | RCE via parser exploit |
| UNC path injection | Information Disclosure | `PathValidator` | NTLM hash leak |
| URL scheme injection | Elevation of Privilege | `MediaOpener` | `file://` local file access |
| Error message leakage | Information Disclosure | All catch blocks | Internal path disclosure |
| `openFileLocation` injection | Elevation of Privilege | `PathUtils` | Arbitrary command execution |
| Folder scanner DoS | Denial of Service | `FolderScanner` | UI freeze on deep dirs |
| `as` cast crashes | Denial of Service | JSON deserialization | Unhandled crash |

### 2.3 Trust Boundaries

```
Trust Level 0 (Untrusted):   User input, dropped files, network URLs
Trust Level 1 (Semi-trusted): Persisted JSON (playlist, settings) — can be tampered on disk
Trust Level 2 (Trusted):     Dart runtime, Flutter framework, compiled app code
Trust Level 3 (Trusted):     MDK/FFmpeg native library — C/C++, potential parser bugs
```

---

## 3. Path Security

### 3.1 Current Implementation (PathValidator)

**File**: `lib/kernel/services/path_validator.dart`

The existing `PathValidator` covers:
- Empty path rejection
- Null byte injection (`\x00`)
- Path traversal (`../`, `..\`)
- UNC network paths (`\\`)
- Home directory expansion (`~`)
- ASCII control character scanning (0x01-0x1F, excluding tab)
- Extension whitelist (27 media formats)
- URL scheme whitelist (http, https, rtmp, rtsp, srt, udp, tcp)
- HTTP/HTTPS authority validation

### 3.2 Vulnerabilities Found

#### V-PATH-01: No Maximum Path Length Check (MEDIUM)

**Description**: No length limit on input paths. Extremely long paths (10,000+ characters) can cause buffer issues in native MDK/FFmpeg libraries or excessive memory allocation.

**Attack Scenario**: Attacker provides a drag-and-drop file with a 100KB path string, causing memory pressure or native buffer overflow.

**Current Code** (`path_validator.dart:113-132`):
```dart
static String? validate(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '路径为空';
  // ... no length check
```

**Fix**:
```dart
/// Maximum allowed path length (Windows MAX_PATH is 260, extended is 32767)
static const _maxPathLength = 1024;

static String? validate(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '路径为空';
  if (trimmed.length > _maxPathLength) {
    return '路径过长 (${trimmed.length} > $_maxPathLength)';
  }
  // ... rest of validation
```

#### V-PATH-02: URL Validation Bypass for Non-HTTP Schemes (HIGH)

**Description**: RTMP, RTSP, SRT, UDP, TCP URLs skip all structural validation. A malicious `rtsp://` URL could contain path traversal sequences that get passed directly to MDK.

**Current Code** (`path_validator.dart:116-125`):
```dart
if (isUrl(trimmed)) {
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return 'URL 格式无效: $trimmed';
    }
  }
  return null; // 其他协议（RTSP/RTMP/SRT/UDP/TCP）跳过
}
```

**Fix**:
```dart
if (isUrl(trimmed)) {
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return 'URL 格式无效: $trimmed';
  // All schemes must have a host
  if (uri.host.isEmpty) return 'URL 缺少主机: $trimmed';
  // Reject file:// scheme (local file access via URL)
  if (uri.scheme == 'file') return '不支持 file:// 协议: $trimmed';
  // Reject userinfo in URL (potential credential phishing)
  if (uri.userInfo.isNotEmpty) return 'URL 不应包含用户信息: $trimmed';
  return null;
}
```

#### V-PATH-03: `isAllowedMedia` Trusts URLs Unconditionally (MEDIUM)

**Description**: `isAllowedMedia` returns `true` for any URL, bypassing extension checks. A URL ending in `.exe` passes the media check.

**Current Code** (`path_validator.dart:73-79`):
```dart
static bool isAllowedMedia(String path) {
  if (isUrl(path)) return true; // URL 信任上游
  // ...
```

**Fix**:
```dart
static bool isAllowedMedia(String path) {
  if (isUrl(path)) {
    // For URLs, check the path component's extension if present
    final uri = Uri.tryParse(path);
    if (uri == null) return false;
    final urlExt = _extractExtension(uri.path);
    if (urlExt != null) return allowedExtensions.contains(urlExt);
    return true; // No extension in URL path (e.g., streaming endpoints)
  }
  // ... existing local file check
}
```

#### V-PATH-04: No Symlink Resolution (MEDIUM)

**Description**: `PathValidator` does not resolve symlinks. A symlink pointing to `/etc/passwd` with a `.mp4` extension appended (via symlink name) could bypass extension checks.

**Fix**: Add optional symlink resolution for local file paths:
```dart
/// Resolve symlinks and re-validate the real path.
/// Call this after initial validation for local file paths.
static Future<String?> resolveAndValidate(String path) async {
  try {
    final resolved = await File(path).resolveSymbolicLinks();
    // Re-validate the resolved path
    return validate(resolved);
  } on Exception {
    return '无法解析路径';
  }
}
```

### 3.3 Path Security Checklist

| Check | Status | Priority |
|-------|--------|----------|
| Empty path rejection | DONE | - |
| Null byte injection | DONE | - |
| Path traversal (`../`) | DONE | - |
| UNC path rejection | DONE | - |
| Home directory expansion | DONE | - |
| Control character scan | DONE | - |
| Extension whitelist | DONE | - |
| Max path length | **MISSING** | P1 |
| URL structural validation (all schemes) | **PARTIAL** | P0 |
| `file://` scheme rejection | **MISSING** | P0 |
| URL userinfo rejection | **MISSING** | P1 |
| Symlink resolution | **MISSING** | P2 |
| Re-validation after path resolution | **MISSING** | P2 |

---

## 4. Input Validation

### 4.1 File Type Validation

#### V-INPUT-01: FolderScanner Uses Separate Extension Set (LOW)

**Description**: `FolderScanner` has its own `_extensions` set (14 video formats) that doesn't include audio formats and is not synchronized with `PathValidator.allowedExtensions` (27 formats). This inconsistency means scanned audio files are silently dropped, but more critically, the two lists can drift apart.

**Current Code** (`folder_scanner.dart:32-47`):
```dart
static const _extensions = {
  '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm',
  '.m4v', '.ts', '.rmvb', '.mpg', '.mpeg', '.3gp', '.vob',
};
```

**Fix**: Use `PathValidator.allowedExtensions` as the single source of truth:
```dart
// Convert PathValidator set to include dot prefix for FolderScanner
static final _extensions = PathValidator.allowedExtensions
    .map((e) => '.$e')
    .toSet();
```

#### V-INPUT-02: No File Size Limit (HIGH)

**Description**: No maximum file size check before passing files to MDK/FFmpeg. A multi-terabyte file (or a file claiming to be) could exhaust memory during metadata parsing.

**Fix** in `MediaOpener.open()`:
```dart
/// Maximum file size: 256 GB (covers 8K HDR content with headroom)
static const _maxFileSizeBytes = 256 * 1024 * 1024 * 1024;

// After file existence check:
final fileSize = await file.length();
if (fileSize > _maxFileSizeBytes) {
  return OpenError(
    FileError(
      FileErrorCode.fileTooLarge,
      '文件过大: ${(fileSize / (1024*1024*1024)).toStringAsFixed(1)} GB',
      null,
      ErrorContext(action: 'open', path: trimmed, module: 'MediaOpener'),
    ),
  );
}
```

### 4.2 Keyboard Input Validation

#### V-INPUT-03: Custom Key Binding Injection (LOW)

**Description**: `KeyboardHandler` accepts `customBindings` map where values are `keyId` strings compared via `==`. If settings JSON is tampered, an attacker could bind actions to unexpected keys, but the impact is limited to UI-level actions (play/pause/seek).

**Current Code** (`keyboard_handler.dart:92-101`):
```dart
bool _keyMatches(LogicalKeyboardKey key, String action, LogicalKeyboardKey defaultKey) {
  if (customBindings.isEmpty) return key == defaultKey;
  final bound = customBindings[action];
  if (bound == null) return key == defaultKey;
  return key.keyId.toString() == bound;
}
```

**Risk**: LOW — keyboard bindings only trigger `VoidCallback` actions that are wired at the widget level, not arbitrary code execution.

**Mitigation**: Validate binding values at load time:
```dart
/// Validate that all binding values are valid keyId strings
static bool isValidBinding(String keyIdStr) {
  final id = int.tryParse(keyIdStr);
  return id != null && id > 0 && id < 0x10FFFF; // Valid Unicode range
}
```

### 4.3 File Operation Rate Limiting

#### V-INPUT-04: No Rate Limiting on Batch File Operations (LOW)

**Description**: `FileOperations.addFiles` processes all paths in a tight loop with no throttling. Dropping 10,000 files simultaneously could cause UI jank.

**Fix**:
```dart
/// Maximum files per batch operation
static const _maxBatchSize = 500;

Future<int> addFiles(List<String> paths) async {
  final limitedPaths = paths.take(_maxBatchSize).toList();
  final validPaths = PathValidator.filterValid(limitedPaths);
  // ... rest of logic
}
```

---

## 5. MethodChannel Security

### 5.1 Architecture Overview

The project uses `WindowBridge` as an abstract interface with `WindowService` as the Win32 implementation. MethodChannel calls go through `com.simple_player/window`. The bridge is properly abstracted — UI layer depends on the interface, not the implementation.

### 5.2 V-MC-01: `openFileLocation` Command Injection (CRITICAL)

**Description**: `PathUtils.openFileLocation` passes a user-controlled path directly to `Process.run` (explorer/xdg-open/open) without sanitization. A crafted path like `C:\Videos & calc.exe` could execute arbitrary commands on Windows via shell metacharacter injection.

**Current Code** (`path_utils.dart:74-90`):
```dart
static void openFileLocation(String path, {
  Future<void> Function(String, List<String>)? runner,
}) {
  final run = runner ?? Process.run;
  final dir = dirname(path);
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      run('explorer', [dir]);  // dir is user-controlled!
    // ...
  }
}
```

**Attack Scenario**:
1. User plays a file from `C:\Videos & calc.exe\movie.mp4`
2. User right-clicks → "Open file location"
3. `dirname` returns `C:\Videos & calc.exe`
4. `Process.run('explorer', ['C:\Videos & calc.exe'])` — on Windows, `explorer` does not invoke shell, so this specific case is safe
5. However, `xdg-open` on Linux DOES invoke shell processing — `dir` with shell metacharacters is dangerous

**Fix**:
```dart
static void openFileLocation(String path, {
  Future<void> Function(String, List<String>)? runner,
}) {
  final run = runner ?? Process.run;
  final dir = dirname(path);

  // Validate directory path — reject shell metacharacters
  if (_hasShellMetacharacters(dir)) {
    log.w('openFileLocation: rejected path with metacharacters');
    return;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      run('explorer', [dir]);
    case TargetPlatform.linux:
      run('xdg-open', [dir]);
    case TargetPlatform.macOS:
      run('open', [dir]);
    default:
      log.w('openFileLocation: unsupported platform');
  }
}

/// Check for shell metacharacters that could enable command injection
static bool _hasShellMetacharacters(String path) {
  // Reject paths containing characters that have special meaning in shells
  const dangerous = ['&', '|', ';', '`', '$', '(', ')', '{', '}',
                     '\n', '\r', '>', '<', '!'];
  return dangerous.any((c) => path.contains(c));
}
```

### 5.3 V-MC-02: Missing Window Command Validation (MEDIUM)

**Description**: `WindowBridge` commands like `setMode`, `setAspectRatio` accept parameters directly. While the abstract interface is clean, the concrete `WindowService` implementation should validate parameters before passing to Win32 FFI.

**Mitigation**:
```dart
// In WindowService implementation:
Future<void> setAspectRatio(double ratio) async {
  assert(ratio >= 0, 'Aspect ratio must be non-negative');
  if (ratio.isNaN || ratio.isInfinite) return; // Reject invalid values
  // ... delegate to platform
}
```

---

## 6. Type Safety

### 6.1 V-TYPE-01: Unsafe `as` Casts in JSON Deserialization (CRITICAL)

**Description**: Multiple files use `as Map<String, dynamic>`, `as int`, `as String` etc. on JSON-decoded data without type guards. If the JSON file is tampered (e.g., a field that should be `int` is a `String`), the app crashes with `TypeError`.

**Affected Files and Lines**:

| File | Line(s) | Unsafe Cast |
|------|---------|-------------|
| `settings_store.dart` | 310 | `jsonDecode(json) as Map<String, dynamic>` |
| `settings_store.dart` | 560 | `jsonDecode(jsonString) as Map<String, dynamic>` |
| `settings_store.dart` | 570 | `rawSettings as Map<String, dynamic>` |
| `settings_store.dart` | 575-646 | `map['volume'] as num?`, `map['lastFile'] as String?`, etc. (30+ casts) |
| `playlist_store.dart` | 138 | `jsonDecode(content) as Map<String, dynamic>` |
| `playlist_store.dart` | 177 | `jsonDecode(content) as Map<String, dynamic>` |
| `playlist_store.dart` | 197 | `jsonDecode(content) as List<dynamic>` |
| `playlist_store.dart` | 203 | `entry as Map<String, dynamic>` |
| `playlist_store.dart` | 204 | `map['path'] as String?` |
| `playlist.dart` | 187-202 | `hist['timestamp'] as num?`, `map['positionMs'] as num?` |
| `playlist.dart` | 275 | `json['mode'] as num?` |
| `playlist.dart` | 281 | `json['items'] as List<dynamic>?` |
| `playlist.dart` | 285 | `item as Map<String, dynamic>` |
| `playlist.dart` | 293 | `json['currentIndex'] as num?` |
| `app_settings.dart` | 145-146 | `windowX as double?`, `windowY as double?` |
| `track_preferences.dart` | 65,68 | `audioTrackIndex as int?`, `subtitleTrackIndex as int?` |

**Attack Scenario**:
1. Attacker modifies `playlist.json` on disk: changes `"mode": 0` to `"mode": "invalid"`
2. App loads playlist → `json['mode'] as num?` throws `TypeError`
3. App crashes on startup (persistent crash loop until user deletes file)

**Fix — Safe JSON Parsing Utility**:
```dart
/// Safe JSON type extraction — returns null instead of throwing
class SafeJson {
  SafeJson._();

  /// Safely extract a Map from dynamic JSON data
  static Map<String, dynamic>? asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Safely extract a List from dynamic JSON data
  static List<dynamic>? asList(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is List) return List<dynamic>.from(data);
    return null;
  }

  /// Safely extract an int (handles num → int coercion)
  static int? asInt(dynamic data) {
    if (data is int) return data;
    if (data is num) return data.toInt();
    if (data is String) return int.tryParse(data);
    return null;
  }

  /// Safely extract a double (handles num → double coercion)
  static double? asDouble(dynamic data) {
    if (data is double) return data;
    if (data is num) return data.toDouble();
    if (data is String) return double.tryParse(data);
    return null;
  }

  /// Safely extract a String
  static String? asString(dynamic data) {
    if (data is String) return data;
    return data?.toString();
  }

  /// Safely extract a bool
  static bool? asBool(dynamic data) {
    if (data is bool) return data;
    if (data is int) return data != 0;
    return null;
  }
}
```

**Migration Example — SettingsStore**:
```dart
// BEFORE (unsafe):
final data = jsonDecode(jsonString) as Map<String, dynamic>;
final map = rawSettings as Map<String, dynamic>;
volume: (map['volume'] as num?)?.toDouble() ?? 1.0,

// AFTER (safe):
final data = SafeJson.asMap(jsonDecode(jsonString));
if (data == null) return AppSettings.defaults;
final map = SafeJson.asMap(data['settings']);
if (map == null) return AppSettings.defaults;
volume: SafeJson.asDouble(map['volume']) ?? 1.0,
```

### 6.2 V-TYPE-02: Unsafe `as` Casts in MDK Callback Handler (HIGH)

**Description**: `FvpCallbackHandler` casts MDK event objects without type guards.

**Current Code** (`fvp_callback_handler.dart:50,67`):
```dart
final stateEvent = event as MdkStateChangedEvent;
final statusEvent = event as MdkMediaStatusEvent;
```

**Fix**: Use `is` type check:
```dart
if (event is MdkStateChangedEvent) {
  // handle state change
} else if (event is MdkMediaStatusEvent) {
  // handle status change
} else {
  log.w('Unknown MDK event type: ${event.runtimeType}');
}
```

### 6.3 V-TYPE-03: Unsafe `as` Casts in MediaOpener Metadata (HIGH)

**Description**: `MediaOpener._parseAudioTracks` and `_parseSubtitleTracks` use extensive `as` casts on MDK media info objects.

**Current Code** (`media_opener.dart:120-132`):
```dart
final List<dynamic>? videos = info.video as List<dynamic>?;
final int w = vc.width as int;
final int h = vc.height as int;
par: (vc.par as num).toDouble(),
codec: vc.codec as String,
```

**Fix**: Use safe extraction helpers or `is` checks:
```dart
final int? w = vc.width is int ? vc.width as int : null;
final int? h = vc.height is int ? vc.height as int : null;
if (w == null || h == null || w <= 0 || h <= 0) {
  // Skip invalid video track
  continue;
}
```

### 6.4 V-TYPE-04: `RenderBox` Cast Without Guard (MEDIUM)

**Description**: Three locations cast `findRenderObject()` to `RenderBox` without null/type check.

**Locations**:
- `app.dart:94` — `Overlay.of(barCtx).context.findRenderObject()! as RenderBox`
- `thumbnail_tile.dart:130-131` — Two `as RenderBox` casts
- `folder_tab.dart:268-269` — Two `as RenderBox` casts

**Fix**:
```dart
final renderObject = Overlay.of(context).context.findRenderObject();
if (renderObject is! RenderBox) return; // Guard against unexpected types
final overlay = renderObject;
```

---

## 7. Error Handling & Information Security

### 7.1 V-ERR-01: Error Messages Leak Internal Paths (HIGH)

**Description**: Error messages throughout the codebase include full file paths, exposing internal directory structures to the user (and potentially to crash reports or logs).

**Examples**:
- `path_validator.dart:129`: `'路径不安全: $trimmed'` — echoes back the malicious path
- `path_validator.dart:130`: `'不支持的文件类型: $trimmed'` — echoes full path
- `media_opener.dart:68`: `'文件不存在: ${PathUtils.basename(trimmed)}'` — good (uses basename)
- `file_operations.dart:53`: `validationError.value = e.toString()` — raw exception message

**Fix — Sanitize error output**:
```dart
/// Sanitize a path for user-facing error messages.
/// Shows only the filename, not the full directory path.
static String sanitizeForDisplay(String path) {
  final basename = PathUtils.basename(path);
  // Truncate extremely long filenames
  if (basename.length > 100) {
    return '${basename.substring(0, 97)}...';
  }
  return basename;
}
```

**Apply to PathValidator**:
```dart
static String? validate(String path) {
  // ...
  if (isPathTraversal(trimmed)) return '路径不安全';  // Don't echo path
  if (!isAllowedMedia(trimmed)) return '不支持的文件类型: ${sanitizeForDisplay(trimmed)}';
  // ...
}
```

### 7.2 V-ERR-02: Raw Exception Strings Exposed to UI (MEDIUM)

**Description**: `FileOperations.openAndPlay` sets `validationError.value = e.toString()` which can leak stack traces and internal paths to the UI layer.

**Current Code** (`file_operations.dart:53`):
```dart
} on Exception catch (e) {
  validationError.value = e.toString();
  return false;
}
```

**Fix**:
```dart
} on Exception catch (e) {
  log.e('openAndPlay failed: $e');
  validationError.value = '无法打开文件';  // Generic user message
  return false;
}
```

### 7.3 V-ERR-03: Debug Logging in Release Builds (LOW)

**Description**: `developer.log` calls in `keyboard_handler.dart` (lines 187, 201) are behind `kDebugMode` guards — this is correct. However, `KernelLogger` outputs via `debugPrint` which is stripped in release builds by Flutter, so this is safe.

**Status**: ACCEPTABLE — existing guards are correct.

---

## 8. MDK/FFmpeg Engine Security

### 8.1 V-ENGINE-01: Malicious Media File Exploitation (CRITICAL — Mitigated by Updates)

**Description**: MDK/FFmpeg parse complex binary formats (MKV, AVI, MP4, etc.) written in C/C++. Historically, media parsers are a major source of vulnerabilities (CVE-2021-30155, CVE-2020-20894, etc.).

**Mitigation Strategy**:
1. **Keep MDK/FFmpeg updated** — subscribe to security advisories
2. **Sandbox the engine process** — consider running MDK in a separate process (future)
3. **Limit file size** — prevent memory exhaustion from crafted headers
4. **Timeout all operations** — already implemented (10s prepare, 5s texture)

**Current Protections**:
- `MediaOpener` has `_prepareTimeoutSeconds = 10` and `_textureTimeoutSeconds = 5`
- Buffer limits: `_localBufferMinMs = 500`, `_localBufferMaxMs = 2000`

**Recommended Addition**:
```dart
/// Maximum media duration to accept (24 hours — covers any reasonable content)
static const _maxDurationSeconds = 24 * 60 * 60;

// After metadata parsing:
if (mediaInfo.duration > _maxDurationSeconds * 1000) {
  return OpenError(/* ... duration exceeded ... */);
}
```

### 8.2 V-ENGINE-02: Network Stream Security (MEDIUM)

**Description**: MDK supports RTMP/RTSP/SRT/UDP/TCP streams. Network streams can be used for:
- SSRF (Server-Side Request Forgery) if the app is on a corporate network
- Fingerprinting (connecting to attacker-controlled servers reveals user IP)

**Current Mitigation**: URL scheme whitelist in `PathValidator` limits to known streaming protocols.

**Recommended Addition**: Add a user confirmation dialog for non-HTTP streams:
```dart
// In MediaOpener, before opening network streams:
if (PathValidator.isUrl(trimmed) && !trimmed.startsWith('http')) {
  // Show confirmation: "Connecting to network stream: [host]. Continue?"
}
```

---

## 9. Persistence Security

### 9.1 V-PERSIST-01: JSON File Integrity (MEDIUM)

**Description**: Playlist and settings JSON files in the application support directory can be tampered with by other processes. No integrity check (checksum, signature) is performed on load.

**Current Protections**:
- `SettingsStore` catches `FormatException` on JSON parse failure
- `PlaylistStore` catches `Exception` on load failures

**Recommended Addition**: Simple checksum validation:
```dart
/// Validate JSON file integrity using a stored hash
static bool _validateIntegrity(String content, String expectedHash) {
  final actualHash = sha256.convert(utf8.encode(content)).toString();
  return actualHash == expectedHash;
}
```

### 9.2 V-PERSIST-02: Atomic File Writes (GOOD)

**Description**: `PlaylistStore` already uses atomic writes (write to `.tmp`, then rename). This prevents corruption from interrupted writes.

**Status**: IMPLEMENTED — `playlist_store.dart:104`:
```dart
final tmpFile = File('${f.path}.tmp');
```

---

## 10. Detailed Vulnerability Inventory

### Priority Matrix

| ID | Vulnerability | Severity | Effort | Phase |
|----|--------------|----------|--------|-------|
| V-MC-01 | `openFileLocation` command injection | CRITICAL | S | 1 |
| V-TYPE-01 | JSON `as` cast crash (30+ locations) | CRITICAL | L | 1 |
| V-PATH-02 | URL validation bypass (non-HTTP schemes) | HIGH | S | 1 |
| V-TYPE-02 | MDK callback `as` cast | HIGH | S | 1 |
| V-TYPE-03 | MediaOpener metadata `as` cast | HIGH | M | 1 |
| V-ERR-01 | Error messages leak internal paths | HIGH | M | 1 |
| V-INPUT-02 | No file size limit | HIGH | S | 1 |
| V-PATH-01 | No max path length | MEDIUM | S | 2 |
| V-PATH-03 | `isAllowedMedia` trusts URLs | MEDIUM | S | 2 |
| V-MC-02 | Window command parameter validation | MEDIUM | M | 2 |
| V-TYPE-04 | `RenderBox` cast without guard | MEDIUM | S | 2 |
| V-ERR-02 | Raw exception strings in UI | MEDIUM | S | 2 |
| V-PERSIST-01 | JSON file integrity | MEDIUM | L | 3 |
| V-PATH-04 | No symlink resolution | MEDIUM | M | 3 |
| V-INPUT-01 | FolderScanner extension drift | LOW | S | 2 |
| V-INPUT-03 | Custom key binding injection | LOW | S | 3 |
| V-INPUT-04 | No batch file rate limiting | LOW | S | 3 |
| V-ERR-03 | Debug logging in release | LOW | - | N/A |

### Effort Scale

- **S** (Small): < 2 hours, single file change
- **M** (Medium): 2-4 hours, 2-3 files
- **L** (Large): 4-8 hours, multiple files, needs testing

---

## 11. Implementation Roadmap

### Phase 1: Critical & High Fixes (Week 1)

**Goal**: Eliminate crash vectors and close high-severity attack surfaces.

| Task | Files | Description |
|------|-------|-------------|
| 1.1 Shell injection fix | `path_utils.dart` | Add `_hasShellMetacharacters` guard to `openFileLocation` |
| 1.2 URL validation hardening | `path_validator.dart` | Validate all URL schemes, reject `file://`, reject userinfo |
| 1.3 SafeJson utility | New: `kernel/utils/safe_json.dart` | Create safe JSON type extraction helpers |
| 1.4 SettingsStore migration | `settings_store.dart` | Replace all `as` casts with `SafeJson.*` calls |
| 1.5 PlaylistStore migration | `playlist_store.dart` | Replace all `as` casts with `SafeJson.*` calls |
| 1.6 Playlist migration | `playlist.dart` | Replace all `as` casts with `SafeJson.*` calls |
| 1.7 MDK callback safety | `fvp_callback_handler.dart` | Replace `as` with `is` type checks |
| 1.8 MediaOpener safety | `media_opener.dart` | Safe metadata extraction with fallbacks |
| 1.9 Error message sanitization | `path_validator.dart`, `file_operations.dart` | Use `sanitizeForDisplay` for user-facing errors |
| 1.10 File size limit | `media_opener.dart` | Add `_maxFileSizeBytes` check |

**Exit Criteria**: Zero `as` casts on untrusted data, all error messages sanitized, shell injection blocked.

### Phase 2: Medium Fixes & Hardening (Week 2)

**Goal**: Defense in depth — close remaining medium-severity gaps.

| Task | Files | Description |
|------|-------|-------------|
| 2.1 Max path length | `path_validator.dart` | Add `_maxPathLength = 1024` check |
| 2.2 URL extension check | `path_validator.dart` | `isAllowedMedia` checks URL path extension |
| 2.3 Window command validation | `window_service.dart` | Validate parameters before FFI calls |
| 2.4 RenderBox guard | `app.dart`, `thumbnail_tile.dart`, `folder_tab.dart` | `is! RenderBox` guard |
| 2.5 Exception sanitization | `file_operations.dart` | Generic user messages, detailed internal logs |
| 2.6 FolderScanner sync | `folder_scanner.dart` | Use `PathValidator.allowedExtensions` |
| 2.7 Batch size limit | `file_operations.dart` | `_maxBatchSize = 500` |

**Exit Criteria**: All medium-severity items addressed, consistent validation across all entry points.

### Phase 3: Low Priority & Defense in Depth (Week 3-4)

**Goal**: Long-term hardening and security infrastructure.

| Task | Files | Description |
|------|-------|-------------|
| 3.1 Symlink resolution | `path_validator.dart` | `resolveAndValidate` for local files |
| 3.2 Key binding validation | `keyboard_handler.dart` | Validate `keyId` range at load time |
| 3.3 JSON integrity | `playlist_store.dart`, `settings_store.dart` | SHA-256 checksum on save/load |
| 3.4 Network stream confirmation | `media_opener.dart` | User dialog for non-HTTP streams |
| 3.5 Security test suite | New: `test/security/` | Path traversal, JSON tampering, type safety tests |
| 3.6 Static analysis rules | `analysis_options.yaml` | Enable `avoid_as` lint rule (warn mode) |

**Exit Criteria**: Security test suite passes, lint rules enforced, defense-in-depth complete.

---

## 12. Security Coding Standards

### 12.1 Input Validation Rules

```
RULE-01: ALL file paths MUST pass through PathValidator.validate() before use
RULE-02: ALL JSON data MUST use SafeJson.* helpers — NEVER raw `as` casts
RULE-03: ALL external strings MUST be length-checked before processing
RULE-04: ALL URLs MUST be parsed with Uri.tryParse() — NEVER string startsWith alone
RULE-05: ALL file operations MUST have timeout guards
RULE-06: ALL user-facing errors MUST use sanitizeForDisplay() — NEVER raw paths
```

### 12.2 Type Safety Rules

```
RULE-07: Use `is` type checks before `as` casts on dynamic data
RULE-08: Prefer `switch` expressions for exhaustive type matching (Dart 3)
RULE-09: Use nullable return types instead of throwing on bad input
RULE-10: Validate constructor parameters with assert() in debug mode
RULE-11: Never use `!` (bang) on values from external sources
```

### 12.3 Error Handling Rules

```
RULE-12: Catch specific exception types — NEVER bare `catch (e)`
RULE-13: Log full error details internally (KernelLogger)
RULE-14: Show generic messages to users — NEVER raw exception.toString()
RULE-15: Always include ErrorContext for structured error reporting
RULE-16: Never swallow errors silently — at minimum, log them
```

### 12.4 Process & Command Rules

```
RULE-17: Validate ALL paths before passing to Process.run()
RULE-18: NEVER construct shell commands via string concatenation
RULE-19: Use argument arrays (not single string) for Process.run()
RULE-20: Sanitize paths for shell metacharacters before external use
```

### 12.5 Persistence Rules

```
RULE-21: ALWAYS wrap JSON decode in try-catch with specific exception types
RULE-22: Use atomic writes (tmp + rename) for all file saves
RULE-23: Validate data types immediately after JSON decode
RULE-24: Provide safe defaults when persisted data is corrupt
RULE-25: NEVER trust file content from disk — validate on every load
```

---

## 13. Security Testing Checklist

### 13.1 Path Traversal Tests

- [ ] `../../../etc/passwd.mp4` — rejected
- [ ] `..\\..\\windows\\system32\\config\\sam.mp4` — rejected
- [ ] `\x00.mp4` — rejected (null byte)
- [ ] `~/.ssh/id_rsa.mp4` — rejected
- [ ] `\\\\attacker\\share\\video.mp4` — rejected (UNC)
- [ ] Path with 10,000 characters — rejected
- [ ] `C:\Videos & calc.exe\movie.mp4` — openFileLocation rejected
- [ ] `rtsp://attacker.com/../../etc/passwd` — rejected
- [ ] `file:///etc/passwd` — rejected
- [ ] `http://user:pass@attacker.com/video.mp4` — rejected (userinfo)

### 13.2 Type Safety Tests

- [ ] Playlist JSON with `"mode": "invalid"` — graceful fallback
- [ ] Playlist JSON with `"items": "not_array"` — graceful fallback
- [ ] Settings JSON with `"volume": "not_number"` — graceful fallback
- [ ] Settings JSON with missing required fields — graceful fallback
- [ ] Empty JSON file `{}` — graceful fallback to defaults
- [ ] Completely empty file — graceful fallback to defaults
- [ ] Binary garbage in JSON file — graceful fallback to defaults

### 13.3 Input Validation Tests

- [ ] Drop 1000 files simultaneously — batch limit enforced
- [ ] Drop a 100GB file — size limit enforced
- [ ] Drop a file with `.exe` extension — rejected
- [ ] Drop a file with double extension `.mp4.exe` — rejected
- [ ] Type extremely fast in keyboard handler — no key queue overflow

### 13.4 Error Handling Tests

- [ ] All error messages show filename only, not full path
- [ ] No stack traces visible in UI
- [ ] Corrupt playlist file does not crash app
- [ ] Corrupt settings file does not crash app
- [ ] Network timeout does not leak connection details

---

## 14. References

- OWASP Top 10 for Desktop Applications
- CWE-78: OS Command Injection (V-MC-01)
- CWE-22: Path Traversal (V-PATH-*)
- CWE-843: Type Confusion (V-TYPE-*)
- CWE-209: Information Exposure Through Error Messages (V-ERR-*)
- Dart Security Guidelines: https://dart.dev/guides/security
- FFmpeg Security: https://ffmpeg.org/security.html

---

## Appendix A: SafeJson Implementation Reference

```dart
// lib/kernel/utils/safe_json.dart

/// Safe JSON type extraction — prevents TypeError from tampered data.
///
/// All JSON deserialization in the project MUST use these helpers
/// instead of raw `as` casts. Returns null on type mismatch,
/// allowing callers to provide safe defaults.
///
/// Design rationale: tampered JSON on disk is a semi-trusted input
/// (Trust Level 1). Using `as` on dynamic data is equivalent to
/// `unsafe` in C — it bypasses the type system.
class SafeJson {
  SafeJson._();

  /// Safely extract a Map from dynamic JSON data.
  ///
  /// Handles both `Map<String, dynamic>` (direct from jsonDecode)
  /// and `Map<dynamic, dynamic>` (nested structures).
  static Map<String, dynamic>? asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Safely extract a List from dynamic JSON data.
  static List<dynamic>? asList(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is List) return List<dynamic>.from(data);
    return null;
  }

  /// Safely extract an int (handles num → int coercion and String parsing).
  static int? asInt(dynamic data) {
    if (data is int) return data;
    if (data is num) return data.toInt();
    if (data is String) return int.tryParse(data);
    return null;
  }

  /// Safely extract a double (handles num → double coercion and String parsing).
  static double? asDouble(dynamic data) {
    if (data is double) return data;
    if (data is num) return data.toDouble();
    if (data is String) return double.tryParse(data);
    return null;
  }

  /// Safely extract a String.
  static String? asString(dynamic data) {
    if (data is String) return data;
    return data?.toString();
  }

  /// Safely extract a bool (handles int → bool coercion for JSON compat).
  static bool? asBool(dynamic data) {
    if (data is bool) return data;
    if (data is int) return data != 0;
    return null;
  }

  /// Safely extract a nested value by key from a Map.
  ///
  /// Convenience for `asMap(data)?[key]` with type safety.
  static T? nested<T>(dynamic data, String key) {
    final map = asMap(data);
    if (map == null) return null;
    final value = map[key];
    if (value is T) return value;
    return null;
  }

  /// Safely decode JSON string and extract as Map.
  ///
  /// Combines jsonDecode + asMap in a single safe operation.
  static Map<String, dynamic>? decodeMap(String json) {
    try {
      final decoded = jsonDecode(json);
      return asMap(decoded);
    } on FormatException {
      return null;
    }
  }

  /// Safely decode JSON string and extract as List.
  static List<dynamic>? decodeList(String json) {
    try {
      final decoded = jsonDecode(json);
      return asList(decoded);
    } on FormatException {
      return null;
    }
  }
}
```

## Appendix B: Error Sanitization Utility

```dart
// lib/kernel/utils/error_sanitizer.dart

import 'path_utils.dart';

/// Sanitize error output for user-facing display.
///
/// Prevents internal path leakage and stack trace exposure.
/// Log full details via KernelLogger; show only safe summaries to users.
class ErrorSanitizer {
  ErrorSanitizer._();

  /// Sanitize a file path for display — shows filename only.
  static String displayPath(String path) {
    final basename = PathUtils.basename(path);
    if (basename.length > 100) {
      return '${basename.substring(0, 97)}...';
    }
    return basename;
  }

  /// Convert an exception to a user-friendly message.
  ///
  /// Maps known exception types to localized messages.
  /// Unknown exceptions get a generic message.
  static String userMessage(Object error) {
    return switch (error) {
      FileSystemException() => '无法访问文件',
      FormatException() => '文件格式错误',
      TimeoutException() => '操作超时',
      _ => '操作失败',
    };
  }
}
```
