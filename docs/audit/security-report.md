# Security Audit Report — simple_player_flutter

**Date:** 2026-07-20
**Auditor:** Flutter Security Agent
**Scope:** Full codebase security review
**Branch:** feat/v1.8-stability-polish-plan-02-02

---

## Security Score: 8.5 / 10

The project demonstrates strong security practices for a desktop media player. Path validation is centralized and well-tested, error handling is structured with sealed classes, and there are no hardcoded secrets. The remaining issues are MEDIUM/LOW severity and relate to defense-in-depth gaps rather than exploitable vulnerabilities.

---

## Executive Summary

| Category | Status |
|----------|--------|
| Path Traversal Protection | STRONG — PathValidator covers all main entry points |
| Hardcoded Secrets | CLEAN — None found |
| User Input Validation | GOOD — FilePicker + drag-drop + history all validated |
| Error Information Leakage | GOOD — Localized UI messages, no raw exceptions to user |
| MethodChannel Security | N/A — Uses window_manager package, no custom channels |
| JSON Deserialization | GOOD — Defensive parsing with try-catch and safe defaults |
| Settings Tampering | GOOD — SettingsValidator clamps all values |
| Command Injection | LOW RISK — One gap in openFileLocation() |

---

## Findings

### M-01: setExternalSubtitle() Missing Path Validation [MEDIUM]

**File:** `lib/ui/player/player_screen.dart:132`
**Also:** `lib/kernel/services/subtitle_service.dart:57,80`

```dart
// player_screen.dart — _openSubtitle()
widget.engine.setExternalSubtitle(result.files.single.path!);
```

**Issue:** The external subtitle path from FilePicker is passed directly to the native MDK engine via `setExternalSubtitle()` without `PathValidator.validate()`. The `SubtitleConfigurator.setExternalSubtitle()` sets the path as a raw MDK property (`subtitle.external`).

**Risk:** While FilePicker limits extensions to `['srt', 'ass', 'ssa', 'sub', 'vtt']`, the path itself is not validated for traversal (`../`) or null bytes. A crafted `.srt` file with a path containing `../` could potentially reference files outside the intended directory when passed to the native FFmpeg subtitle loader.

**Exploitability:** LOW — requires user to pick a maliciously-named subtitle file via FilePicker, which is an unlikely attack vector for a local desktop app.

**Fix:**
```dart
// player_screen.dart
Future<void> _openSubtitle() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['srt', 'ass', 'ssa', 'sub', 'vtt'],
  );
  if (result != null && result.files.single.path != null) {
    final path = result.files.single.path!;
    if (PathValidator.isPathTraversal(path)) return; // ADD THIS
    widget.engine.setExternalSubtitle(path);
  }
}
```

Apply the same pattern in `SubtitleService.detectAndLoad()` and `detectAndLoadSync()`.

---

### M-02: openFileLocation() Missing Path Validation [MEDIUM]

**File:** `lib/kernel/utils/path_utils.dart:56-72`

```dart
static void openFileLocation(String path, {runner}) {
  final run = runner ?? Process.run;
  final dir = dirname(path);
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      run('explorer', [dir]);  // dir passed directly to Process.run
    // ...
  }
}
```

**Issue:** `openFileLocation()` passes the directory path directly to `Process.run('explorer', [dir])` without validating the path. If a playlist item contains a crafted path (e.g., from a malicious playlist.json), the dirname could contain shell metacharacters or reference unexpected locations.

**Risk:** MEDIUM — `Process.run` in Dart uses argument arrays (not shell string), so shell injection is mitigated by Dart's process model. However, the path could still reference sensitive directories (e.g., `C:\Windows\System32`).

**Callers:**
- `lib/ui/playlist/thumbnail_tile.dart:189` — uses `item.path` from playlist
- `lib/ui/playlist/folder_tab.dart:196` — uses `group.folderPath` from scanner

**Fix:**
```dart
static void openFileLocation(String path, {runner}) {
  if (PathValidator.isPathTraversal(path)) {
    log.w('openFileLocation: rejected unsafe path');
    return;
  }
  final run = runner ?? Process.run;
  final dir = dirname(path);
  // ... rest unchanged
}
```

---

### M-03: Network URL Validation Gaps [MEDIUM]

**File:** `lib/kernel/services/path_validator.dart:95-103`

```dart
if (isUrl(trimmed)) {
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    // HTTP/HTTPS: validates URI structure and authority
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return 'URL 格式无效: $trimmed';
    }
  }
  return null; // RTSP/RTMP/SRT/UDP/TCP: no validation
}
```

**Issue:** Non-HTTP URL schemes (RTSP, RTMP, SRT, UDP, TCP) bypass all validation except the protocol prefix check. A malformed URL like `rtsp://` or `rtsp://[]` would pass validation.

**Risk:** MEDIUM — these URLs are passed directly to FFmpeg/MDK for network streaming. Malformed URLs could cause unexpected behavior in the native FFmpeg parser. However, FFmpeg has its own URL parsing and the network timeout provides a safety net.

**Fix:** Add basic URI parsing for all URL schemes:
```dart
if (isUrl(trimmed)) {
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return 'URL 格式无效: $trimmed';
  }
  return null;
}
```

---

### M-04: FolderScanner Missing Path Validation [LOW]

**File:** `lib/kernel/scanner/folder_scanner.dart:53`

```dart
static Future<List<VideoFile>> scan(String directory) async {
  final dir = Directory(directory);
  if (!await dir.exists()) return [];
  // scans without validating 'directory' parameter
}
```

**Issue:** `FolderScanner.scan()` accepts a directory path without validating it through PathValidator. The `directory` parameter comes from `PathUtils.dirname()` of the current media file, which was validated at playback time.

**Risk:** LOW — the scanner only reads directory contents (no writes), and the input is derived from already-validated paths. Defense-in-depth suggests adding validation.

**Fix:**
```dart
static Future<List<VideoFile>> scan(String directory) async {
  if (PathValidator.isPathTraversal(directory)) return [];
  // ... rest unchanged
}
```

---

### L-01: Silent Error Swallowing in WindowService [LOW]

**File:** `lib/kernel/bridge/window_service.dart:110`

```dart
} catch (_) {
  update();
}
```

**Issue:** A bare `catch (_)` silently swallows all exceptions including programming errors (Error subtypes). This is in `_updateOnUIThread()` which is called from window event handlers.

**Risk:** LOW — the fallback `update()` call ensures the UI still updates. However, swallowing errors makes debugging harder and could mask security-relevant issues.

**Fix:**
```dart
} on Exception catch (e) {
  log.w('_updateOnUIThread fallback: $e');
  update();
}
```

---

### L-02: ErrorContext.path Exposes File System Paths [LOW]

**File:** `lib/kernel/models/player_error.dart:83-91`

```dart
Map<String, Object?> toMap() => {
  if (path != null) 'path': path,
  // ...
};
```

**Issue:** `ErrorContext.toMap()` includes the full file path in its serialized output. This data flows to `KernelLogger` which writes to log files. Log files could expose directory structure information.

**Risk:** LOW — this is a local desktop application, logs are stored in the app's support directory. No network transmission of error data. The UI uses localized messages via `l10nKey`, not raw paths.

**Mitigation:** Log files are already in the user's app data directory with standard permissions. No action required unless log shipping is added in the future.

---

### L-03: Unsafe Type Casts in Settings Import [LOW]

**File:** `lib/kernel/persistence/settings_store.dart:311,645-646`

```dart
return decoded.map((k, v) => MapEntry(k, v as String));  // line 311
rawShortcuts.map((k, v) => MapEntry(k as String, v as String))  // line 646
```

**Issue:** Direct `as String` casts on JSON-decoded values. If the JSON contains non-string values for shortcut keys, this throws a `TypeError` at runtime.

**Risk:** LOW — the data comes from `SharedPreferences` (controlled storage) or user-imported JSON files. The `importSettings` method has a top-level try-catch, but individual field casts could produce confusing error messages.

**Fix:**
```dart
return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
```

---

### L-04: saveLastFile() Stores Unvalidated Path [LOW]

**File:** `lib/kernel/persistence/settings_store.dart:228-229`

```dart
static Future<void> saveLastFile(String path) =>
    _save('saveLastFile', (p) => p.setString(_keyLastFile, path));
```

**Issue:** `saveLastFile()` persists the path directly without running it through `PathValidator.validate()`. This path is later loaded and used to restore playback on app restart.

**Risk:** LOW — the path was already validated when it was originally opened. However, if the playlist.json or SharedPreferences are externally modified, the stored path could be malicious.

**Mitigation:** The path is validated again by `PlaybackNavigator.playIndex()` before playback, so the stored path is re-validated on use.

---

## Security Strengths

### 1. Centralized Path Validation (PathValidator)
- Extension whitelist: 30 media formats
- Path traversal: `../`, `..\`, null byte, UNC, `~`
- Control character filtering: 0x01-0x1F (excluding tab)
- URL scheme whitelist: HTTP/HTTPS/RTSP/RTMP/SRT/UDP/TCP
- HTTP/HTTPS structural validation (authority, host)
- Well-tested: 20+ test cases in `path_validator_test.dart`

### 2. All File Entry Points Validated
| Entry Point | Validation |
|-------------|-----------|
| FilePicker (open file) | `PathValidator.validate()` via FileOperations |
| Drag-and-drop | `PathValidator.validate()` in DropHandler |
| History playback | `PathValidator.validate()` in PlaybackNavigator |
| Folder scanner | Extension filter in FolderScanner |
| Batch add | `PathValidator.filterValid()` in FileOperations |

### 3. Structured Error System
- Sealed class hierarchy: `FileError` / `CodecError` / `PlaybackError` / `NetworkError` / `UnknownError`
- Error codes with recoverability flags
- Localized UI messages via `l10nKey` (raw exception messages never shown to user)
- `ErrorContext` with timestamp, module, action for debugging

### 4. Settings Tamper Protection (SettingsValidator)
- Window dimensions: NaN/Infinity/negative protection
- All numeric values: range clamping
- Rotation: whitelist (0/90/180/270 only)
- Import: per-field validation with safe defaults

### 5. No Hardcoded Secrets
- No API keys, passwords, tokens, or credentials found
- No `.env` files or dotenv usage
- No external API calls requiring authentication

### 6. Atomic File Writes (PlaylistStore)
- Write-to-temp (.tmp) then rename pattern
- Exponential backoff retry (3 attempts)
- Debounce to prevent rapid-fire writes

### 7. Defensive JSON Parsing
- All `jsonDecode()` calls wrapped in try-catch
- `Playlist.fromJson()` skips corrupted items gracefully
- `SettingsStore.importSettings()` validates every field
- Safe defaults on parse failure

### 8. Process Execution Safety
- `Process.run` uses argument arrays (not shell strings), preventing shell injection
- `openFileLocation()` has injectable runner for testing
- Only 2 process invocations in entire codebase (`explorer`/`xdg-open`/`open`)

---

## Recommendations

### Priority 1 (Implement Soon)
1. **Add PathValidator to setExternalSubtitle paths** — prevents potential path traversal in subtitle loading
2. **Add PathValidator to openFileLocation()** — defense-in-depth for process execution

### Priority 2 (Nice to Have)
3. **Validate non-HTTP URLs** — add `Uri.tryParse()` for RTSP/RTMP/SRT/UDP/TCP
4. **Add PathValidator to FolderScanner.scan()** — defense-in-depth
5. **Replace bare `catch (_)` with `on Exception catch`** — better error visibility

### Priority 3 (Future Consideration)
6. **Log sanitization** — consider truncating paths in log output if log shipping is added
7. **Type-safe JSON deserialization** — use `toString()` instead of `as String` casts
8. **Playlist integrity** — consider checksumming playlist.json to detect tampering

---

## Test Coverage

PathValidator has dedicated unit tests covering:
- Extension whitelist (video + audio)
- Non-media rejection
- Case insensitivity
- URL passthrough (HTTP/HTTPS/RTSP/RTMP/SRT)
- Null byte injection
- Path traversal (`../`)
- UNC path detection
- Home directory expansion (`~`)
- Control character filtering
- Batch filtering

**Gap:** No integration tests for the full file-open pipeline (FilePicker -> PathValidator -> PlaybackNavigator -> MediaOpener).

---

## Conclusion

The project has a solid security foundation. The `PathValidator` class is well-designed and covers the primary attack surfaces (file paths, URLs, control characters). The structured error system prevents information leakage to users. The main gaps are defense-in-depth issues (M-01 through M-04) where certain code paths bypass the centralized validator. None of the findings represent critical or exploitable vulnerabilities in the context of a local desktop media player.

**Overall assessment: The codebase is production-ready from a security perspective with the recommended MEDIUM fixes applied.**
