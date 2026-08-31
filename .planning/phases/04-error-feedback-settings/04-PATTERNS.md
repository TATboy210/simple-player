# Phase 4: 错误反馈设置 - Pattern Map

**Mapped:** 2026-08-31
**Files analyzed:** 11 (new + modified)
**Analogs found:** 11 / 11 (all git-tracked, verified via `git ls-files`)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/ui/dialogs/settings/error_feedback_settings.dart` (NEW — store) | store (ValueNotifier + JSON persistence, non-kernel) | file-I/O + CRUD | `lib/kernel/persistence/window_persistence.dart` (silent-fallback mode) + `lib/kernel/diagnostics/source_line_reader.dart:236-268` (shape-checked decode) | role-match (backend swapped: shared_preferences → dart:io JSON) |
| `lib/ui/dialogs/settings/general_settings_content.dart` (NEW) | component (settings rows + inline validation) | request-response (debounced probe) | `lib/ui/shared/setting_action_row.dart` + `lib/ui/shared/setting_slider_row.dart` (debounce) | exact (row grammar + Timer debounce in-repo) |
| `lib/ui/dialogs/settings/settings_dialog.dart` (MODIFY) | component (dialog shell → selected-tab state) | request-response | self (`_NavEntry`, `AboutContent` switch-in) | exact (structural change documented below) |
| `lib/kernel/diagnostics/error_log_location.dart` (MODIFY — the one allowed kernel edit) | service (location resolver, sealed Result) | transform (chain + probe) | self (`resolve()` contract + provider typedef seam) | exact |
| `lib/main.dart` (MODIFY — settings load + re-target wiring) | config / composition root | event-driven (unawaited activation) | self (`_activateDiagnosticLog`, main.dart:116-145) | exact |
| re-target coordinator (NEW, small — main.dart private fn or `lib/kernel/diagnostics/` sibling consumed by main) | utility (dispose→activate protocol) | event-driven (ordered buffering) | `lib/kernel/diagnostics/error_reporting_dependencies.dart` (activate latch) + `lib/kernel/diagnostics/error_log_file_sink.dart` (drain semantics) | exact |
| `lib/ui/player/error_card_host.dart` (MODIFY — render gate) | component (presentation gate) | pub-sub (ValueListenable) | self (`build()` hide gate, error_card_host.dart:207-213) | exact (one outer ValueListenableBuilder) |
| `lib/l10n/app_en.arb` + `app_zh.arb` + generated (MODIFY) | config (l10n keys) | transform | self (existing `errorCard*` key block, app_en.arb:439-470; `generalTab` already at :66) | exact |
| `test/diagnostics/error_feedback_settings_store_test.dart` (NEW) | test (unit, injected File seam) | CRUD | `test/diagnostics/error_log_location_test.dart` conventions | role-match |
| `test/diagnostics/error_log_location_test.dart` (EXTEND) | test (unit, injected providers + temp dirs) | transform | self | exact |
| `test/widget/dialogs/settings_dialog_test.dart` + `test/widget/player/error_card_host_test.dart` (EXTEND) | test (widget) | request-response | self | exact |

## Pattern Assignments

### 1. `error_feedback_settings.dart` (NEW store, SET-03 / D-01)

**Analog A (silent-fallback persistence mode):** `lib/kernel/persistence/window_persistence.dart:52-80`

```dart
    } on Exception {
      return const PersistedWindowState(   // ← 失败静默回退默认值,不阻断启动
        size: defaultWindowSize,
        position: null,
        alwaysOnTop: false,
        isMaximized: false,
      );
    }
```
Also note the injectable-backend constructor at :36-37 (`WindowPersistence({SharedPreferences? preferences})`) — copy this shape but inject a `File Function()? settingsFile` seam instead (research Pitfall 4: never let tests touch `Platform.resolvedExecutable`).

**Analog B (shape-checked JSON decode — the load template):** `lib/kernel/diagnostics/source_line_reader.dart:242-267`

```dart
    final config = jsonDecode(configText);
    if (config is! Map<String, Object?>) {   // ← load-bearing: [1,2] decodes to List
      return null;
    }
    // ... per-field is! type checks ...
  } on FormatException {
    // Invalid package metadata must not establish a filesystem root.
  }
```

**Key semantics to copy (research-verified):**
- Schema: `{"version": 1, "errorCardEnabled": true, "logDirectory": ""}` — flat keys + version; `""` = use default chain (D-01 discretion area).
- Load failure inputs that MUST be survived: missing file, trailing garbage / empty string (`FormatException`), `[1,2]` (List → Map guard), UTF-8 BOM (handled by `utf8.decode` fine).
- Write strategy: `settings.json.tmp` writeAsString(flush) → `tmp.rename(target)`. Rename replace-on-existing works on Windows but transiently fails `PathAccessException (errno 5)` — mitigation: one retry → delete-target-then-rename → direct `writeAsString`. Any residue is non-fatal (next load silently falls back to defaults).
- Save triggers: toggle flip → save immediately; logDirectory → save only after validation passes (D-03/CONTEXT discretion).
- State exposure: `final ValueNotifier<ErrorFeedbackSettingsData> state` — project ValueNotifier convention, no new state lib. Store lives in UI layer (main.dart:20 already imports a UI-layer file — precedent).

### 2. `error_log_location.dart` extension (SET-02 / D-02, allowed kernel edit)

**Analog:** self, `lib/kernel/diagnostics/error_log_location.dart:7, 37-67`

Contract to preserve verbatim (lines 40-44): `logsDirectoryName = 'logs'`, `logFileName = 'error.log'`; sealed `ErrorLogLocationResult` → `ErrorLogLocationResolved(file)` / `ErrorLogLocationUnavailable(error, stackTrace)` (lines 10-31) stays the return type.

Seam style to copy (line 7):
```dart
typedef ApplicationSupportDirectoryProvider = Future<Directory> Function();
```
Add, in the same style:
```dart
typedef ExecutableDirectoryProvider = Directory Function(); // sync — Platform.resolvedExecutable
typedef WritableDirectoryProbe = Future<bool> Function(Directory);
```

Existing chain shape to extend (lines 47-67): try/catch with narrowing `on FileSystemException` / `on IOException` / `on Exception` → typed `Unavailable` result (never throws). New chain: configured dir (skip when empty) → exe-root `logs/` → Application Support `logs/` (existing behavior unchanged as last tier). Each tier: `create(recursive: true)` (line 56 idempotent-prepare comment pattern) + temp-file probe.

Probe implementation (research Pattern 1, verified exception shapes):
```dart
// 临时文件探测 — 证明 sink 真正要做的操作(create/write/delete)可行。
// 实测异常形态:目标段被同名文件占据时 Directory.create → PathExistsException(errno 183);
// writeAsString 落在 file-as-dir 下 → PathNotFoundException(errno 3)。
// 注意:attrib +r 目录**不**阻止写入(实测可写),目录只读属性不是有效探测目标。
Future<bool> isDirectoryWritable(Directory dir) async {
  final probe = File('${dir.path}${Platform.pathSeparator}.write_probe');
  try {
    await probe.writeAsString('probe', flush: true);
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}
```
Probe placement: settings load / debounced UI validation / sink rebuild only — **never** per log write (Phase 2 `logsAvailable` containment already covers mid-session loss).

### 3. Re-target coordinator (SET-02, zero kernel change)

**Analog:** `lib/kernel/diagnostics/error_reporting_dependencies.dart:126-148, 166-179`

Activate is once-only via `_isActivated` latch (:127-134); `dispose()` resets it (:167-179) — this is the whole reason the swap works. Copy the protocol (research Pattern 2):
```dart
// 1) 新位置先 resolve+probe 确认成功,再 dispose(消除失败窗口;
//    dispose 后新链失败会留下已停用的 delegate,pending 仅 32 条)。
final resolved = await ErrorLogLocation.resolve(...);
// 2) dispose → drain 旧 Future 链 → 旧文件完整收尾(每条记录都是独立
//    writeAsString append,无撕裂;ErrorLogFileSink 不持 OS 句柄)。
await effect.dispose();
// 3) activate → gap 期到达记录已由 pending FIFO(容量 32, drop-oldest)
//    保序缓冲,activate 先 flush 再接受直写。
effect.activate(sink: ErrorLogFileSink(file: file), resolvedPath: file.path);
```
Hard rules (research Pitfall 2): **always dispose→activate, never activate→activate** (second activate is a silent no-op + warning). Startup and re-target must share one activation code path. Known flicker: `dispose()` momentarily sets `logPath=null, logsAvailable=false` (:174-175) — UI should read the settings store's effective path during the swap. Catch `ErrorLogFileSink.dispose() => drain()` (:82) semantics — no file lock on old path.

### 4. `general_settings_content.dart` (NEW, SET-01/02 UI)

**Analog A (row grammar):** `lib/ui/shared/setting_action_row.dart:54-76` — MouseRegion hover + AnimatedContainer(`Tokens.durationFast`, `Tokens.bgHover`, `Tokens.radiusSm`) + Row[Expanded(label), trailing control]. Colors/spacing/fonts exclusively via `Tokens.*`.
**Analog B (debounce Timer):** `lib/ui/shared/setting_slider_row.dart:45-53, 94-97`
```dart
  Timer? _debounce;
  ...
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }
  ...
  _debounce?.cancel();
  _debounce = Timer(widget.debounceDuration, () { widget.notifier.value = v; });
```
For text input use ~300ms (slider default is 50ms — do not copy that value); parameterize `debounceDuration` for `fakeAsync` tests.
**Switch row:** first Switch in codebase — thin variation of the row grammar, theme via `Tokens.accent`.
**Browse button:** analog `lib/features/player/file_picker_adapters.dart:19-31` (`FilePicker` usage), but for directories use `FilePicker.getDirectoryPath(windowsOptions: WindowsOptions(lockParentWindow: true))` — the top-level `lockParentWindow` param (used at :23) is **deprecated in file_picker v11; do not copy it into new code**. `getDirectoryPath` returns `Future<String?>` — null on cancel must be ignored, not treated as "clear path". `initialDirectory` is ignored on Windows.

### 5. `settings_dialog.dart` modification (General tab enablement)

**Analog:** self. Current shell hardcodes `const Expanded(child: AboutContent())` (:35) and `_SettingsNav` renders four `_NavEntry` with **no onTap** (:42-66) — the doc comment at :10-12 over-promises. Required changes:
1. Track selected tab (`ValueNotifier<_SettingsTab>` or StatefulWidget state).
2. `_NavEntry` gains `onTap` + selected flag (keep the existing `enabled`/`IgnorePointer` opacity grammar at :86-94; add selected highlight distinct from hover).
3. Content switches: `AboutContent` (About) / `GeneralSettingsContent` (General) — keep `AppDialog` shell (:25-38) and 1px `Tokens.borderHighlight` divider (:34) untouched.
4. Video/Audio tabs stay disabled placeholders (zero code beyond what exists).

### 6. `main.dart` modification (settings load + re-target wiring)

**Analog:** self, `lib/main.dart:43-49, 116-145`

Startup slot (copy exactly): store constructed with defaults synchronously before `runApp` (card host must subscribe at first build); the settings file load happens **inside** the unawaited `_activateDiagnosticLog` path, before `ErrorLogLocation.resolve` — never a blocking await above `MediaKit.ensureInitialized`/`runApp` (research Pitfall 7; Phase 2 locked decision "activation never blocks startup"). `resolve()` call site at :120-122 gains `executableDirectory:` / `configuredDirectory:` / `writable:` arguments. `switch (result)` exhaustive pattern at :123-135 is the template for both startup activation and re-target dispatch.

### 7. `error_card_host.dart` modification (D-05 gate, zero kernel)

**Analog:** self, `lib/ui/player/error_card_host.dart:206-240`

Wrap the existing build in an outer `ValueListenableBuilder<bool>`; `!cardEnabled → SizedBox.shrink()` (same-frame hide, D-05 "立即消失"). Existing hide gate at :211-213 (`if (state.current == null) return const SizedBox.shrink();`) and all snapshot/badge/dismiss logic (:219-237) stay untouched. Do not add gating to `_apply` (:143-157) — the build-level gate keeps warning OSD routing (:165-170) unaffected. Semantics verified: `ErrorCaptureSnapshot.record()` never consults any toggle, so reports keep flowing to snapshot + sink while hidden; on re-enable the newest retained snapshot report renders immediately (no reporter API change).

### 8. l10n keys (MODIFY)

**Analog:** `lib/l10n/app_en.arb:439-470` — existing `errorCard*` block shows the key + `@key` description convention. `generalTab` already exists (:66-67). Add new keys (开关标签/路径状态可写✓✗/回退中/浏览/OSD「日志已回退到默认位置」) to **both** `app_en.arb` and `app_zh.arb`, then run `flutter gen-l10n` and commit generated `app_localizations_*.dart` together (they are tracked; git status shows them currently modified — beware of unrelated pending diffs).

## Shared Patterns

### Silent fallback on I/O failure
**Source:** `lib/kernel/persistence/window_persistence.dart:72-79, 106-108`
**Apply to:** settings store load AND save — `on Exception` → defaults / no-op; never block startup or UI.

### Typed sealed results + narrowing `on` clauses
**Source:** `lib/kernel/diagnostics/error_log_location.dart:60-66`
**Apply to:** resolver extension and re-target coordinator — typed result out, never a thrown exception across the kernel boundary; never bare `catch (e)`, never catch `Error` subtypes.

### Injectable provider seams for filesystem/platform
**Source:** `error_log_location.dart:7` (AS provider), `error_log_file_sink.dart:14-18` (`ErrorLogWriter` typedef), `window_persistence.dart:36-37` (optional backend)
**Apply to:** exe-dir provider, writable-probe, settings-file seam — all tests inject temp dirs/fakes; production wiring happens only in `main.dart`.

### Kernel discipline
**Source:** CLAUDE.md + 04-CONTEXT.md
**Apply to:** kernel edits limited to `error_log_location.dart` extension + sink wiring; no `debugPrint` in `lib/kernel/` (gate: `bash tool/audit/kernel_logger_gate.sh`); reporter/单写者语义 untouched. UI layer may use `debugPrint`; UI strings via `AppLocalizations`, visuals via `Tokens.*`.

### Doc comments (bilingual, written while coding)
**Source:** `error_log_location.dart:1-7`, `error_card_host.dart:137-142` (Chinese first line + English explanation, side effects documented)
**Apply to:** every new public class/function in store, content widget, coordinator, resolver extension.

## No Analog Found

| File | Role | Data Flow | Reason | Fallback |
|------|------|-----------|--------|----------|
| Switch row in `general_settings_content.dart` | component | — | First `Switch` in the codebase — no existing Switch styling precedent | Thin variation of `setting_action_row.dart` grammar, theme via `Tokens.accent` |
| Atomic-rename write in settings store | utility | file-I/O | `File.rename` replace-on-existing is newly introduced (no prior use) | research-verified protocol: tmp write → rename → retry → delete-then-rename → direct write, all non-fatal |

## Metadata

**Analog search scope:** `lib/kernel/diagnostics/`, `lib/kernel/persistence/`, `lib/ui/dialogs/settings/`, `lib/ui/shared/`, `lib/ui/player/`, `lib/features/player/`, `lib/main.dart`, `test/diagnostics/`, `test/widget/`
**Files scanned:** ~20; 11 analogs read in full/targeted; all named analog paths verified git-tracked via `git ls-files` (none are gitignored mirrors)
**Pattern extraction date:** 2026-08-31
