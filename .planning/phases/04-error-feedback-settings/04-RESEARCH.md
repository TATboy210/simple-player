# Phase 4: 错误反馈设置 - Research

**Researched:** 2026-08-31
**Domain:** Flutter desktop settings persistence (portable JSON beside exe), log-location priority chain with writability probing, runtime sink re-targeting on a single-writer Future chain, presentation-layer card gating
**Confidence:** HIGH (all integration points read from repo source this session with line citations; filesystem semantics verified by live probes on the target machine; MSIX/deeplink facts from official docs via search)

## Summary

Phase 4 wires three settings into the existing error-feedback stack: an error-card on/off toggle (SET-01), a configurable diagnostic-log directory with writability validation and fallback (SET-02), and restart persistence of both (SET-03) in a portable `settings.json` beside the executable (D-01). The codebase is unusually well-prepared: every seam needed already exists and was built for exactly this extension.

The four load-bearing verified findings:

1. **Sink re-targeting needs zero kernel changes.** `DelegatingDiagnosticLogEffect` is once-only via `activate()` (`_isActivated` guard, error_reporting_dependencies.dart:127-148), but `dispose()` resets `_isActivated = false` (error_reporting_dependencies.dart:167-179). The composition root can therefore swap the log location with the existing public API: `await effect.dispose()` (drains the old sink's Future chain) → build a new `ErrorLogFileSink(file: newFile)` → `effect.activate(sink: ..., resolvedPath: ...)`. The reporter holds only the stable delegate created at init (main.dart:43-47), so the swap is invisible to it. Records arriving during the swap buffer in the delegate's bounded pending FIFO (capacity 32) in original order — no loss, no reordering for realistic error volumes.
2. **`File.rename` on Windows is replace-on-existing but transiently flaky.** Live probe: rename over an existing target succeeds (target content replaced, source gone) — BUT the same operation was observed failing with `PathAccessException (OS Error: 拒绝访问。, errno = 5)` in an adjacent probe run seconds earlier. The atomic-write pattern must tolerate a failed rename (retry or delete-then-rename), and a torn `settings.json` must fall back to defaults anyway (D-01 mandates silent fallback).
3. **Writability probing: use a temp-file create/write/delete probe.** Live probes give exact exception shapes to catch: `Directory.create(recursive: true)` where a file occupies the segment → `PathExistsException` (errno 183); `writeAsString` under a file-as-directory → `PathNotFoundException` (errno 3); a plain read-only Windows attribute (`attrib +r`) does **not** block directory writes — so the temp-file probe is the only reliable check. The probe is cheap and belongs at validation time (settings load, debounced UI input, sink rebuild), **not** before every log write (the Phase 2 failure-containment path already handles mid-session I/O loss via `logsAvailable`).
4. **The card toggle gate is a one-line presentation filter with queue semantics already correct.** `ErrorCardHost` renders from `ErrorCaptureSnapshot.I.reports` (bounded 20, keeps all non-warning reports regardless of any toggle — error_capture_snapshot.dart:39-54) and gates rendering on `state.current == null` (error_card_host.dart:210-213). Adding a settings toggle to that gate means: off → card disappears same-frame, reports keep flowing into snapshot + sink; on → next render shows the newest retained report (D-05 "开启=恢复显示(含队列中错误)" — satisfied by the existing snapshot, no reporter API change). The `ErrorReporter` FIFO/dedupe/dismiss semantics are untouched.

The exe-root story for D-02 is clean: `Platform.resolvedExecutable` (OS-resolved absolute exe path) + `File(...).parent` gives the exe directory [CITED: dart-lang/sdk; VERIFIED: live probe]. Debug runs resolve to `build/windows/x64/runner/Debug/` (gitignored, wiped by `flutter clean`); release/MSIX resolves into `C:\Program Files\WindowsApps\...` where only TrustedInstaller can write — so the writability probe automatically falls back to Application Support, which is exactly D-02's design. MSIX AppData writes get copy-on-write redirected to `LocalCache` (uninstall deletes them) — accepted per D-02, documented only.

**Primary recommendation:** Build a UI-layer `ErrorFeedbackSettings` store (ValueNotifier + portable JSON, silent fallback, injected file seam per the `WindowPersistence`/`source_line_reader` precedents), extend `ErrorLogLocation.resolve()` with an exe-root-first priority chain using a temp-file writability probe, re-target the sink via the existing `dispose()`→`activate()` cycle in the composition root, and gate `ErrorCardHost` rendering on the toggle notifier. Enable the General tab by adding selection state to `SettingsDialog` (the current shell hardcodes `AboutContent` and `_NavEntry` has no tap handling — slightly more work than its doc comment implies).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** 便携 JSON——设置存 exe 旁 `settings.json`(纯文本,Unix 原则 5),与便携日志哲学一致;debug run 时存项目目录旁。读写失败静默回退默认值,不阻断启动。**不**用 shared_preferences(漫游 AppData 与便携哲学分裂;WindowPersistence 先例仅作实现模式参考) — **Reversibility:** reversible — 存储层单点
- **D-02:** D-03(Phase 2)修订落地:默认日志位置 = **exe 根目录 `logs/error.log`**;Application Support **降为回退**(exe 旁不可写时,如 MSIX);旧日志不迁移(零迁移代码,AS 旧文件原地作历史存档,新日志从新位置起写);MSIX 虚拟化重定向**接受差异**,代码不做特殊处理,文档记录即可 — **Reversibility:** reversible — 位置解析函数单点(error_log_location.dart 扩展)
- **D-03:** 日志路径配置 UI = 手输文本框(显示当前有效路径)+ 「浏览」按钮(file_picker 已是依赖,选目录回填);输入即校验(防抖),校验结果行内展示(可写✓/不可写✗/回退中) — **Reversibility:** reversible
- **D-04:** 无效路径回退告知 = 双通道:设置页行内状态文字(当前有效路径 + 回退原因)+ 应用层 OSD pill 提示一次「日志已回退到默认位置」 — **Reversibility:** reversible
- **D-05:** 卡片开关语义 = **立即生效**:关闭 → 已显示卡片立即消失 + 后续错误只落盘不弹卡;开启 → 恢复显示(含队列中错误)。实现接缝在 UI 呈现层(ErrorCardHost/快照过滤),**零 kernel 改动**——ErrorReporter 捕获/落盘/effects 链完全不受开关影响 — **Reversibility:** reversible
- **D-06:** 后端持续优化(用户方向)**不混入**本 phase——SET-01/02/03 之外不做 sink/序列化优化;优化作为独立轮,在设置功能落地后按 profile 驱动细化 — **Reversibility:** n/a(范围决策)

### Claude's Discretion
- settings.json 的字段命名/结构(建议扁平 key-value + version 字段)
- 「输入即校验」的防抖时长与校验实现(临时目录探测 vs 直接 open/write 探测)
- 浏览按钮回填后是否自动保存(建议:校验通过即保存,失败则行内报错不保存)
- 开关状态与 settings.json 读写时序(启动加载→内存 ValueNotifier→UI 订阅)
- 日志路径变更时 sink 重建的安全接线细节(复用 Phase 2 单写者 drain 语义,不中断写入中记录)
- 通用 tab 内两个设置项的排版(设置行组件已有先例:setting_action_row/setting_slider_row)

### Deferred Ideas (OUT OF SCOPE)
- **错误卡片前端视觉重设计** — 交接文档已交付(`C:\Users\35490\Desktop\错误弹窗前端设计AI交接文档.md`),设计 AI 产出规范后独立实现流程
- **后端持续优化轮** — sink/序列化/系统占用,设置功能落地后按 profile 驱动独立立项
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SET-01 | 设置"通用"tab 错误卡片开关（默认开；关掉后只落盘不弹卡，捕获与落盘不受影响） | Verified render-gate seam at error_card_host.dart:210-213 + snapshot retention (error_capture_snapshot.dart:39-54); sink is an independent reporter effect — toggle never touches capture/persistence. See Patterns 4-5 |
| SET-02 | 设置"通用"tab 日志输出路径可配置，写入前可写性校验，无效路径回退默认/last-known-good，配置变更后 sink 安全重建 | Verified priority-chain extension point (error_log_location.dart:37-67), probe exception shapes (live probes), and zero-kernel re-target via `dispose()`→`activate()` (error_reporting_dependencies.dart:127-148, 167-179). See Patterns 1-2 |
| SET-03 | 设置值重启持久化 | Verified portable JSON store precedents: defensive load (source_line_reader.dart:236-268), silent-fallback persistence (window_persistence.dart:52-80), startup wiring slot in `_activateDiagnosticLog` (main.dart:116-145). See Pattern 3 |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **media_kit 不可改动** — irrelevant here, no playback surface touched
- **kernel 改动红线（本 phase 放宽版，04-CONTEXT.md）:** kernel 只动 `error_log_location.dart` 的解析扩展 + 必要的 sink 接线；不碰 reporter / 单写者语义。推荐设置存储放 **kernel 之外**（UI 层/组合根可达），组合根消费它做 sink 接线 —— `main.dart:20` 已有导入 UI 层文件（`error_capture_snapshot.dart`）的先例
- **状态管理惯例:** ValueNotifier + ValueListenableBuilder，不引入新状态库
- **质量红线:** flutter analyze 0 error；flutter test 全绿；kernel 禁 debugPrint（`tool/audit/kernel_logger_gate.sh` GATE 1 禁 kernel 导入 package:logger）
- **注释纪律:** 写代码同时写中文双语 `///` doc comment；错误处理用 sealed Result + 具体异常类型 `on` 子句
- **Git:** conventional commits；`commit_docs: true`

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Settings persistence (portable JSON) | UI/composition layer (new store file, non-kernel) | dart:io | Kernel red line limits kernel edits to location resolver + sink wiring; store is consumed by composition root (precedent: main.dart imports UI-layer snapshot) |
| Settings in-memory state | Composition root-owned ValueNotifier store | UI (dialog, host) subscribe | Single data source; matches ValueNotifier convention |
| Log location priority chain + probe | Kernel (`error_log_location.dart` extension — the one allowed kernel edit) | composition root supplies providers | Resolver must stay pure/injectable for tests; providers (exe dir, AS dir) are platform seams injected at main.dart |
| Sink re-target on path change | Composition root (main.dart or a small wiring coordinator) | DelegatingDiagnosticLogEffect (existing public API only) | Kernel stays untouched; reporter holds the stable delegate forever |
| Card on/off gate | UI (`ErrorCardHost` render gate) | — | D-05 mandates presentation-layer only; snapshot/reporter semantics unchanged |
| General tab UI + inline validation | UI (`SettingsDialog` + new General content widget) | file_picker | Pure presentation; debounce precedent exists in setting_slider_row.dart |
| Fallback OSD notice | UI (`OsdService.I.show`) | — | Existing global OSD singleton; kernel never calls OSD |
| Security re-audit T-01-13/19 | Phase SECURITY.md + plan threat model | — | See Security Domain |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:io `File`/`Directory` | SDK (Dart 3.13, pubspec.yaml:7 `sdk: ^3.13.1`) | settings.json read/write, probe, log dir | Dependency-free; same primitive as Phase 2 sink |
| dart:convert `jsonDecode`/`jsonEncode`/`utf8` | SDK | settings serialization | In-repo precedent source_line_reader.dart:242 |
| `Platform.resolvedExecutable` | dart:io | exe-root resolution | OS-resolved absolute path of running executable [CITED: github.com/dart-lang/sdk lib/io/platform.dart]; `File(exe).parent` yields the directory [VERIFIED: live probe this session] |
| `ValueNotifier` + `ValueListenableBuilder` | Flutter SDK | settings state | Project convention; no new state lib |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| file_picker | ^11.0.3 (pubspec.yaml:23) | 「浏览」directory picker (`FilePicker.getDirectoryPath`) | Already used at file_picker_adapters.dart:19-31 |
| path_provider | ^2.1.6 (pubspec.yaml:22) | Application Support fallback provider (unchanged role) | Existing `_activateDiagnosticLog` wiring |
| fake_async | 1.3.3 | debounce + settings-save timer tests | Project standard |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Portable JSON beside exe (D-01, locked) | shared_preferences | Rejected by D-01: roaming AppData splits from portable philosophy |
| `dispose()`→`activate()` re-bind (existing API) | Add `retarget()` to `ErrorLogFileSink` kernel sink | retarget touches sink internals (`_file` is final) and re-opens the single-writer file for review; dispose→activate is public-API-only and already order-safe — strongly preferred |
| Temp-file writability probe | `Directory.create` as the probe | `create` alone does not prove write permission (e.g., pre-existing read-only-flagged dir still accepts writes — probe confirmed `attrib +r` does NOT block; and create succeeds on a dir that denies file creation under some ACLs). Temp-file create/write/delete proves the actual operation the sink will perform |
| `package:path` for dirname | `File(exe).parent` | Zero new dependency; `parent` is a built-in FileSystemEntity getter |

**Installation:** None. Zero new packages; all dependencies already locked in pubspec.lock.

## Package Legitimacy Audit

**No new external packages are installed by this phase.** Existing dependencies consumed:

| Package | Registry | Version | Source Repo | Verdict | Disposition |
|---------|----------|---------|-------------|---------|-------------|
| file_picker | pub.dev | ^11.0.3 (pubspec.yaml:23) | github.com/miguelpruivo/flutter_file_picker [CITED: Context7 /miguelpruivo/flutter_file_picker] | OK (existing, in use) | Approved (existing) |
| path_provider | pub.dev | ^2.1.6 (pubspec.yaml:22) | flutter/packages (first-party) | OK (existing) | Approved (existing) |
| shared_preferences | pub.dev | ^2.5.5 (pubspec.yaml:24) | flutter/packages (first-party) | OK (existing) | Not used by this phase (D-01) |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                        ┌──────────────────────────────────────────────┐
                        │ settings.json (beside exe; portable, D-01)   │
                        └──────────────┬───────────────────────────────┘
                                       │ load (silent fallback to defaults)
                                       ▼
   startup (main.dart)      ErrorFeedbackSettings store (non-kernel)
   _activateDiagnosticLog    ValueNotifier<ErrorFeedbackSettingsData>
        │                       │ cardEnabled        │ logDirectory ('' = default)
        │                       │                    │
        │                       │                    ▼
        │                       │     ErrorLogLocation.resolve(...)  [KERNEL EXTENSION]
        │                       │       1. configured dir → probe → ok? use
        │                       │       2. exe-root logs/   → probe → ok? use
        │                       │       3. Application Support/logs (existing)
        │                       │       failure → ErrorLogLocationUnavailable
        │                       ▼                    │
        │              ┌─ enabled=false ─┐            ▼
        ▼              │ (sink still     │   ErrorLogFileSink(newFile)
 ErrorReporter.init    │  activates;     │        │
 effects: [delegate,   │  card hidden)   │        ▼
 snapshot]             └─────────────────┘   delegate.dispose() → delegate.activate()
        │                                     (existing public API; drains old chain,
        ▼                                      buffers arrivals in bounded FIFO 32)
 Global hooks ── reports ──► ErrorReporter FIFO(5) ──► presentation
                                                     │
                                    ErrorCardHost (UI): ValueListenableBuilder<bool> cardEnabled
                                      off → SizedBox.shrink() (same-frame hide)
                                      on  → renders newest from ErrorCaptureSnapshot (20)
                                                     │
 Settings dialog General tab ── flips notifiers ─────┤
   (Switch + path field + debounce probe + inline    ▼
    status + browse via FilePicker.getDirectoryPath) OsdService.I.show("日志已回退…") — once per fallback
```

Entry points: startup load (main.dart `_activateDiagnosticLog`), settings dialog interactions. Decision points: probe pass/fail per chain tier, toggle on/off. External dependencies: filesystem only (plus file_picker dialog).

### Recommended Project Structure
```
lib/
├── ui/
│   ├── dialogs/settings/
│   │   ├── settings_dialog.dart        # MODIFY: tab selection state + General enabled
│   │   ├── general_settings_content.dart  # NEW: toggle row + log-path row + inline status
│   │   └── error_feedback_settings.dart   # NEW: store (ValueNotifier + JSON load/save,
│   │                                       #   injected File seam, silent fallback)
│   └── player/error_card_host.dart     # MODIFY: outer ValueListenableBuilder<bool> gate
└── kernel/diagnostics/
    └── error_log_location.dart         # MODIFY (allowed): exe-root priority chain + probe
main.dart                                # MODIFY: load settings before location resolve;
                                         #   path-change wiring (dispose→activate)
test/
├── diagnostics/error_log_location_test.dart   # EXTEND: chain priority + probe failures
├── widget/dialogs/settings_dialog_test.dart   # EXTEND: general tab interaction
└── widget/player/error_card_host_test.dart    # EXTEND: toggle gate semantics
```

### Pattern 1: Log-location priority chain with temp-file probe (SET-02, D-02 revision)

**What:** Extend `ErrorLogLocation.resolve()` (currently AS-only, error_log_location.dart:47-67) to walk a candidate chain, keeping the sealed `ErrorLogLocationResult` contract and the provider-seam style.

**Current contract to preserve (verbatim, error_log_location.dart:40-44):**
```dart
  /// Single source of truth for the default child directory.
  static const String logsDirectoryName = 'logs';

  /// Single source of truth for the default diagnostic filename.
  static const String logFileName = 'error.log';
```

**Extension shape:**
- New injectable providers: `typedef ExecutableDirectoryProvider = Directory Function();` (sync — `Platform.resolvedExecutable` is sync) and reuse the existing async AS provider. Plus a `WritableDirectoryProbe` seam so tests never touch real permissions.
- Chain: (1) configured directory from settings (skipped when empty), (2) exe-root `logs/`, (3) Application Support `logs/` (existing behavior, unchanged as last tier). Each tier: create directory (recursive) + probe (write/delete temp file) → first success wins → `ErrorLogLocationResolved(file)`. All tiers fail → `ErrorLogLocationUnavailable` (existing degraded path).
- Probe implementation (verified shape):

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

**When to probe:** (a) once at settings load / location resolve; (b) debounced on each validated path edit in the UI; (c) once per sink rebuild. **Never** before every log write — mid-session I/O loss is already handled by the Phase 2 containment (`logsAvailable` notifier flip + rate-limited degraded output, error_log_file_sink.dart:84-106); SET-02's fallback governs configuration-time validation.

### Pattern 2: Sink re-target via existing `dispose()` → `activate()` cycle (SET-02, zero kernel change)

**What:** On a validated path change, rebuild the durable sink without touching the reporter or the single-writer semantics. Both APIs verified this session:

**Activate is once-only (error_reporting_dependencies.dart:126-135):**
```dart
  /// Activates [sink] once and flushes unresolved reports in their original order.
  void activate({
    required DiagnosticLogSink sink,
    required String resolvedPath,
  }) {
    if (_isActivated) {
      _warnRepeatedActivation();
      return;
    }
```

**Dispose resets the latch (error_reporting_dependencies.dart:166-179):**
```dart
  /// Drains and releases the active writer for test reset or process shutdown.
  Future<void> dispose() async {
    final sink = _sink;
    sink?.logsAvailable.removeListener(_syncAvailability);
    _sink = null;
    _isActivated = false;
```

**Re-target protocol (composition root):**
```dart
Future<void> retargetDiagnosticLog(
  DelegatingDiagnosticLogEffect effect, {
  required File newFile,
}) async {
  // 1) drain + release old sink (old chain completes into the OLD file;
  //    each record is a whole writeAsString append, so no torn records).
  await effect.dispose();
  // 2) new location already probed by the resolver chain.
  final sink = ErrorLogFileSink(file: newFile);
  // 3) re-activate: flushes anything buffered during the gap, in order.
  effect.activate(sink: sink, resolvedPath: newFile.path);
}
```

**Why this is safe (all verified from source):**
- The reporter was constructed once with `diagnosticLogEffect.record` in its effects list (main.dart:43-47) and holds the *delegate*, not the concrete sink (error_reporter.dart:76-81) — swapping the delegate's internal sink is invisible to the reporter.
- During the gap, `record()` routes arrivals into `_pending` (error_reporting_dependencies.dart:108-115) — a bounded FIFO with `static const int _pendingCapacity = 32;` (:91) that drops-oldest on overflow (:118-124). Overflow of 32 error events inside a sub-second swap is implausible given the 10s dedupe window and FIFO(5) upstream. `activate()` flushes pending before accepting direct writes and keeps mid-flush arrivals queued (`_isFlushingPending`, :137-147) — original order preserved.
- The old `ErrorLogFileSink` retains **no OS handle** — every record is a fresh `file.writeAsString(mode: FileMode.append, flush: true)` (error_log_file_sink.dart:35-42), so dispose = await the Future chain (`dispose() => drain()`, :78-82). No file-lock risk on the old path (relevant: the new location may be on the same directory).

**Caveats to plan for:**
- `dispose()` momentarily publishes `_logPath.value = null; _logsAvailable.value = false;` (:174-175) — the settings "当前有效路径" readout flickers null during the swap. Either tolerate (sub-second) or have the UI read the settings store's effective path rather than the delegate's notifier during the swap.
- `activate()` a second time **without** an intervening `dispose()` is a no-op with a warning — the protocol must always be dispose→activate, never activate→activate.
- Startup and re-target share the same `_activateDiagnosticLog`-style code path so there is exactly one activation implementation.

### Pattern 3: Portable settings store (SET-03, D-01)

**What:** A small non-kernel store: load `settings.json` beside the exe → immutable data object → `ValueNotifier` → UI subscribes; every write persists (fire-and-forget, failures swallowed per D-01 "读写失败静默回退默认值").

**Recommended shape (discretion area; CONTEXT suggests flat keys + version):**
```json
{ "version": 1, "errorCardEnabled": true, "logDirectory": "" }
```
`"logDirectory": ""` = "use default chain". Non-empty = configured directory (validated before activation; a stale invalid value does NOT block startup — the chain simply skips it and the UI shows the effective path + fallback reason, D-04).

**Load hardening (both precedents verified in-repo):**
- Shape-checked decode — `source_line_reader.dart:236-268` is the exact template: `jsonDecode` → `if (config is! Map<String, Object?>) return null;` → per-field type checks → `on FormatException` contained. Live probes confirmed the failure inputs it must survive: trailing garbage and empty input throw `FormatException`; a UTF-8 BOM is handled fine by `utf8.decode` (probe: BOM+JSON decodes correctly); `[1,2]` decodes to a `List` — hence the `is! Map` check is load-bearing, not decoration.
- Silent fallback defaults — `window_persistence.dart:52-80` is the persistence-mode template (injectable backend, `on Exception` → defaults).

**Write strategy with the verified Windows rename semantics:**
- Preferred: write `settings.json.tmp` (flush) → `tmp.rename(target)`. Probe result: rename onto an existing target **replaces** it (probe: `dstNow=new-content srcExists=false`) — the atomic-replace primitive works on Windows.
- BUT the same operation was observed failing with `PathAccessException (OS Error: 拒绝访问。, errno = 5)` in an adjacent probe run — transient scanner/AV lock. Mitigation: on rename failure, fall back to delete-target-then-rename (probe-verified to work), and ultimately to a direct `writeAsString` (D-01 makes any failure non-fatal — worst case a torn file is silently reset to defaults on next load).
- Save trigger: toggle flip → save immediately; log-directory change → save only after validation passes (CONTEXT discretion: "校验通过即保存,失败则行内报错不保存").

### Pattern 4: Card toggle gate (SET-01, D-05 — presentation layer only)

**What:** An outer `ValueListenableBuilder<bool>` in `ErrorCardHost.build` that collapses to `SizedBox.shrink()` when the toggle is off. The existing render gate is (error_card_host.dart:210-213):
```dart
        // 隐藏门保持 03-01 语义：reporter 队列空（current == null）→ 卡片
        // 隐藏 —— 防止「关闭后快照残留项」形成永远关不掉的僵尸卡片。
        if (state.current == null) return const SizedBox.shrink();
```

**Semantics audit (all verified):**
- **关闭 → 立即消失:** the toggle notifier flips → outer builder rebuilds in the same frame → card removed. No exit animation required by D-05 ("立即消失").
- **后续错误只落盘不弹卡:** while gated, reports still flow into `ErrorCaptureSnapshot` (its `record()` never consults any toggle — error_capture_snapshot.dart:39-54) and into the sink effect. Reporter queue/dedupe untouched.
- **开启 → 恢复显示(含队列中错误):** un-gating re-renders from the snapshot; the newest retained report appears immediately. The presentation gate (`state.current == null`) is satisfied because `_publishSafely` keeps `current = queue.first` whenever the queue is non-empty and `isReady` (error_reporter.dart:479-485). No new reporter API needed — this resolves the CONTEXT question about reporter queue support affirmatively.
- **Warning 分流不受影响:** `_routeWarning` (error_card_host.dart:152-157, 165-170) runs in `_apply`, not in `build` — a build-level gate does not silence warning OSDs. Note: today no capture source emits warnings, so this branch is dormant either way; the toggle's scope stays "错误卡片" (error/fatal), which matches D-05's wording.

### Pattern 5: General tab enablement (SET-01/02 UI)

**What the shell actually has (verified — slightly more than the doc comment suggests):** settings_dialog.dart:10-12 says "未来接入真实分区时将对应 [_NavEntry] 置 enabled 并提供内容 builder 即可,布局无需重写", but the code has **no selection mechanism**: `SettingsDialog` is a `StatelessWidget` that hardcodes `const Expanded(child: AboutContent())` (:35), and `_SettingsNav` renders four `_NavEntry` widgets with **no `onTap`** (:42-66). Enabling General therefore requires:
1. `SettingsDialog` → track selected tab (a `ValueNotifier<_SettingsTab>` or StatefulWidget state).
2. `_NavEntry` → accept `onTap` + selected flag (visual: existing `enabled` styling already differentiates; add a selected highlight distinct from hover).
3. Content switch → `AboutContent` when About selected; new `GeneralSettingsContent` when General selected.
4. `GeneralSettingsContent`: Switch row (first `Switch` in the codebase — theme it with `Tokens.*`; no precedent exists), log-path text field + inline status + 浏览 button.

**Row precedents (verified):** `SettingActionRow` (label + value + action icon, lib/ui/shared/setting_action_row.dart:17-41) for layout grammar; `setting_slider_row.dart:45-95` for an in-widget `Timer` debounce (`static const Duration` default 50ms — for text input, ~300ms is the recommended debounce; testable with `fakeAsync`). The Switch row itself is new but is a thin variation of the row grammar.

**Browse button (verified API):** `FilePicker.getDirectoryPath()` returns `Future<String?>` — null on cancel; on Windows use `windowsOptions: WindowsOptions(lockParentWindow: true)` (the top-level `lockParentWindow` parameter is **deprecated in v11**; the existing `pickFiles` call at file_picker_adapters.dart:22-23 still uses the old top-level param — do not copy that into new code). `initialDirectory` is Linux/macOS only — ignored on Windows [CITED: Context7 /miguelpruivo/flutter_file_picker].

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Directory picking | Custom folder browser UI | `FilePicker.getDirectoryPath` | Native dialog, modal-lock option, already a dependency |
| Atomic file replace | Custom write-through-both-files scheme | write temp → `rename` (replace-on-existing verified) with delete-then-rename fallback | dart:io rename is the OS primitive; D-01 makes residual failure non-fatal |
| Writability detection | ACL parsing / read-only attribute checks | Temp-file create/write/delete probe | `attrib +r` does not block writes (probe-verified); only the real operation proves writability |
| Bounded startup/swap buffering | New queue while swapping sinks | `DelegatingDiagnosticLogEffect` pending FIFO (32) | Already implements bounded, ordered, drop-oldest buffering with flush-on-activate |
| JSON shape validation | Ad-hoc `as` casts | `is! Map<String, Object?>` guards (source_line_reader.dart:236-268 template) | Type-checked degradation survives every corrupted-input shape |
| Debounce | New Debouncer class | `Timer` pattern from setting_slider_row.dart:45-95 | In-repo precedent, fakeAsync-testable |

**Key insight:** Phase 2/3 deliberately left every seam this phase needs (provider seam, delegate effect, snapshot, presentation host). The phase's real work is *wiring and policy* (chain order, probe placement, save timing), not algorithms — any new "clever" mechanism is a design smell.

## Runtime State Inventory

> Phase 4 changes the *default data location* (D-02 revision) and adds a new persisted file. Answering the five categories explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Existing `error.log` under Application Support `logs/` (Phase 2+ writes) — **stays in place by design** (D-02: 旧日志不迁移, AS 旧文件原地作历史存档). No DB/store migration. | None (documented non-migration) |
| Live service config | None — no external services hold phase-relevant config. | None — verified: no service integrations in diagnostics stack |
| OS-registered state | None — no Task Scheduler/registry/plist entries. | None |
| Secrets/env vars | None — no `.env`; settings.json holds no secrets (only a bool + a directory path). | None |
| Build artifacts | Debug runs will write `build/windows/x64/runner/Debug/settings.json` + `logs/` (exe-adjacent). `build/` is gitignored (.gitignore:33) and wiped by `flutter clean` — debug settings are ephemeral by nature. | None (document as debug quirk) |

## Common Pitfalls

### Pitfall 1: Assuming `File.rename` is atomic on Windows
**What goes wrong:** The temp+rename pattern intermittently fails with `PathAccessException (OS Error: 拒绝访问。, errno = 5)` — observed live on this machine in an otherwise-identical probe run.
**Why it happens:** Transitive handle locks (antivirus/scanner opening freshly written files) make `MoveFileEx` fail with access denied even though a retry succeeds.
**How to avoid:** On rename failure: one retry → delete-target-then-rename → direct write. Never crash: D-01's silent fallback covers the residue.
**Warning signs:** settings.json occasionally reset to defaults after edits.

### Pitfall 2: Calling `activate()` twice
**What goes wrong:** Second `activate()` is silently ignored with only a warning log (`_warnRepeatedActivation`) — the new sink never activates and errors stop reaching the new file while appearing healthy.
**Why it happens:** `_isActivated` is a one-way latch; only `dispose()` resets it.
**How to avoid:** The re-target protocol is always `await dispose()` → `activate()`. Assert in tests: after retarget, `logPath` notifier equals the new path and a probe report reaches the new file.
**Warning signs:** new log file stays empty after a path switch.

### Pitfall 3: Probing writability with `attrib`/read-only assumptions
**What goes wrong:** Treating a read-only-flagged directory as unwritable (false negative), or assuming `Directory.create` success implies writability (false positive).
**Why it happens:** Windows ignores the RO attribute on directories for file creation (probe: writable after `attrib +r`); create ≠ write permission.
**How to avoid:** Temp-file create/write/delete probe as the single source of truth.
**Warning signs:** user picks a valid directory that the UI mislabels ✗ (or vice versa).

### Pitfall 4: Using `Platform.resolvedExecutable` directly in tests
**What goes wrong:** Under `flutter test` the "executable" is `D:\flutter\bin\cache\artifacts\engine\windows-x64\flutter_tester.exe` (probed) — exe-root logic would resolve into the Flutter SDK cache and pollute/depend on SDK paths.
**How to avoid:** Injection seam for the exe-directory provider (same pattern as `ApplicationSupportDirectoryProvider` typedef, error_log_location.dart:7). Tests inject temp directories.
**Warning signs:** tests writing stray files into the Flutter SDK cache; non-hermetic test failures.

### Pitfall 5: Debug-vs-release location expectations
**What goes wrong:** Surprise that debug-run settings/logs land in `build/windows/x64/runner/Debug/` (wiped by `flutter clean`), or that MSIX builds "lose" logs written beside the exe.
**Why it happens:** `Platform.resolvedExecutable` is honest — it reports the real exe. In MSIX that is `C:\Program Files\WindowsApps\...` where **only TrustedInstaller can write** (probe fails → chain falls back to AS, exactly D-02's design); AS writes under MSIX are copy-on-write redirected to `%LOCALAPPDATA%\Packages\<family>\LocalCache\Roaming\...` and are deleted on uninstall [CITED: Microsoft Learn packaged-app docs via WebSearch].
**How to avoid:** Document in-plan; show the *effective* path in the UI (D-03 already mandates the field shows 当前有效路径) so the user always sees where logs actually are.
**Warning signs:** user reports "settings reset" after flutter clean (debug) or "logs gone" after MSIX reinstall.

### Pitfall 6: Over-validating the configured directory with `PathValidator.isPathTraversal`
**What goes wrong:** Rejecting legitimate user choices — `..` segments, UNC network paths (`\\server\share`) — because the media-path validator is stricter than a log-directory policy needs.
**Why it happens:** Reusing `isPathTraversal` wholesale (path_validator.dart:90-96 flags `\\` and `../`).
**How to avoid:** For a *directory* (never opened as media), validate: non-empty, no null bytes/control characters (reuse path_validator.dart:98-107 philosophy), absolute-ish, then let the temp-file probe decide. Decide explicitly whether UNC is allowed (recommendation: reject in v1 for consistency, document as limitation).
**Warning signs:** probe passes but validation rejects a real directory.

### Pitfall 7: Settings load racing log activation
**What goes wrong:** Location resolution runs before settings.json is loaded, so a configured path is ignored on this launch (works next launch) — or, worse, someone makes startup `await` settings I/O and blocks MediaKit/window init.
**Why it happens:** `_activateDiagnosticLog` is already fired unawaited after hooks install (main.dart:43-50); the natural mistake is adding a blocking await above it.
**How to avoid:** Load settings **inside** the unawaited activation path, before `ErrorLogLocation.resolve` (chain preserved: "Pending or failed activation never blocks MediaKit, window initialization, runApp" — locked Phase 2 decision). The card toggle notifier must be created before `runApp` though, so the host can subscribe — construct the store (defaults) synchronously, then let the unawaited loader fill values.
**Warning signs:** configured path honored only on second launch.

### Pitfall 8: Forgetting l10n regeneration
**What goes wrong:** New UI strings (开关标签/路径状态/OSD 文案) hardcoded in widgets break the ARB convention; or generated files drift out of sync.
**Why it happens:** `lib/l10n/app_en.arb` + generated `app_localizations_*.dart` are committed (git status shows them modified); keys like `generalTab` already exist (app_en.arb:66-67).
**How to avoid:** Add ARB keys (en + zh) → run `flutter gen-l10n` → commit generated output together.
**Warning signs:** `flutter analyze` l10n complaints or untranslated strings at runtime.

## Code Examples

### Settings store skeleton (non-kernel, silent fallback)
```dart
// Source: precedents — window_persistence.dart:52-80 (silent defaults),
// source_line_reader.dart:236-268 (shape-checked decode)
final class ErrorFeedbackSettingsData {
  const ErrorFeedbackSettingsData({
    this.errorCardEnabled = true,
    this.logDirectory = '',
  });
  final bool errorCardEnabled;   // SET-01, 默认开
  final String logDirectory;     // '' = 走默认链; 否则已校验目录
}

final class ErrorFeedbackSettings {
  ErrorFeedbackSettings({File Function()? settingsFile}) // 测试注入 seam
      : _settingsFile = settingsFile;
  final ValueNotifier<ErrorFeedbackSettingsData> state =
      ValueNotifier(const ErrorFeedbackSettingsData());

  Future<void> load() async {
    try {
      final text = await _settingsFile().readAsString();
      final json = jsonDecode(text);
      if (json is! Map<String, Object?>) return; // 静默回退默认值 (D-01)
      state.value = ErrorFeedbackSettingsData(
        errorCardEnabled: json['errorCardEnabled'] is bool
            ? json['errorCardEnabled'] as bool
            : true,
        logDirectory: json['logDirectory'] is String
            ? json['logDirectory'] as String
            : '',
      );
    } on FormatException {
      return; // 损坏文件 → 默认值 (实测: 尾随垃圾/空串抛 FormatException)
    } on FileSystemException {
      return; // 无文件/不可读 → 默认值
    }
  }
}
```

### Location chain extension (kernel edit — the allowed one)
```dart
// Source: error_log_location.dart:37-67 (existing contract to extend)
static Future<ErrorLogLocationResult> resolve({
  required ApplicationSupportDirectoryProvider applicationSupportDirectory,
  ExecutableDirectoryProvider? executableDirectory,   // NEW: File(Platform.resolvedExecutable).parent
  String? configuredDirectory,                        // NEW: settings.logDirectory ('' = skip)
  WritableProbe? writable,                            // NEW: injectable probe seam
}) async {
  // 候选链: 配置目录 → exe 根 logs/ → Application Support logs/ (原行为)
  // 每层: create(recursive) + 临时文件探测; 首个可写层胜出。
  // 全部失败 → ErrorLogLocationUnavailable (既有降级态, 不抛出)。
}
```

### Toggle gate (UI, zero kernel)
```dart
// Source: error_card_host.dart:206-213 (existing build + hide gate)
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<bool>(
    valueListenable: ErrorFeedbackSettings.I.state
        .select((s) => s.errorCardEnabled), // 或拆两个 notifier, 任选
    builder: (context, cardEnabled, child) {
      if (!cardEnabled) return const SizedBox.shrink(); // D-05 立即消失
      return ValueListenableBuilder<ErrorPresentationState>(
        valueListenable: _presentation,
        builder: (context, state, _) {
          if (state.current == null) return const SizedBox.shrink();
          // … 既有渲染逻辑原样保留 (快照最新/轮览)
        },
      );
    },
  );
}
```

### Sink re-target (composition root)
```dart
// Source: error_reporting_dependencies.dart:127-148 (activate) + :167-179 (dispose reset)
await diagnosticLogEffect.dispose();           // drain 旧链 → 旧文件完整收尾
final resolved = await ErrorLogLocation.resolve(...); // 新链已探测
switch (resolved) {
  case ErrorLogLocationResolved(:final file):
    diagnosticLogEffect.activate(
      sink: ErrorLogFileSink(file: file),
      resolvedPath: file.path,
    ); // gap 期到达的记录由 pending FIFO 保序补发
  case ErrorLogLocationUnavailable():
    // 保留旧 sink 已不可能 (已 dispose) → 走既有 unavailable 降级 + OSD/行内告知 (D-04)
}
```
Note: if the new chain fails *after* dispose, the delegate stays deactivated (records buffer in pending, capacity 32) — prefer resolving/probing the new location **before** disposing the old sink, and dispose only on confirmed success. That ordering eliminates the failure window entirely.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 2 D-03: default log = AS only, "no exe/cwd fallback" | D-02 revision: exe-root first, AS fallback | 2026-08-31 (04-CONTEXT.md) | error_log_location.dart chain extension; STATE.md's Phase-02 decision line is superseded for Phase 4+ |
| shared_preferences for app settings | Portable settings.json beside exe (D-01) | 2026-08-31 | WindowPersistence remains window-only; new store for error-feedback settings |
| Settings dialog = static About shell | Selected-tab architecture with per-tab content | This phase | `_NavEntry` gains tap/selection; content switch added |

**Deprecated/outdated:**
- file_picker top-level `lockParentWindow` parameter — deprecated in v11 in favor of `WindowsOptions(lockParentWindow: true)` [CITED: Context7 /miguelpruivo/flutter_file_picker]. Existing `pickFiles` call still uses the old form (works); new code must use the options object.
- `Platform.script` for exe location — unreliable in AOT; use `Platform.resolvedExecutable` [CITED: dart-lang/sdk].

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | MSIX exe-root probe failure triggers the AS fallback exactly as designed (probe on `C:\Program Files\WindowsApps\...` fails for non-elevated processes) | Pitfall 5 / Pattern 1 | Low: WindowsApps ACL is well-documented [CITED: Microsoft Learn via WebSearch]; if some install location were writable, behavior degrades gracefully (logs beside exe) |
| A2 | Debounce ~300ms for path text validation is acceptable UX (slider precedent uses 50ms) | Pattern 5 | Low: discretionary per CONTEXT; pure tuning |
| A3 | UNC log directories can be rejected in v1 | Pitfall 6 | Low: single-user dev tool; user can be unblocked later |
| A4 | Mid-session loss of a previously valid configured directory (e.g., disconnected network drive) is covered by the existing Phase 2 degradation (`logsAvailable=false`) rather than auto-re-fallback | Pattern 1 | Medium: if the user expects auto-recovery, an extra "re-probe on failure" step would be needed — flagged as Open Question 3 |
| A5 | `flutter gen-l10n` runs as part of `flutter pub get`/build in this project's toolchain (standard Flutter l10n.yaml setup) | Pitfall 8 | Low: worst case an explicit command step in the plan |

## Open Questions

1. **Should the fallback reason persist anywhere?**
   - What we know: D-04 mandates inline status + one-shot OSD at fallback time. The settings.json keeps the *configured* value.
   - What's unclear: whether the UI should also persist/display *why* the fallback happened after restart (e.g., last probe error) or recompute live.
   - Recommendation: recompute live at each startup (cheap probe); no persistence of the reason. Confirm in plan review.

2. **"last-known-good" interpretation**
   - What we know: SET-02 says "无效路径回退默认/last-known-good"; the chain (configured → exe-root → AS) effectively *is* last-known-good because the AS location from Phase 2 still exists on disk.
   - What's unclear: whether the user expects a separate persisted lastKnownGood key.
   - Recommendation: no extra key — the chain's exe-root/AS tiers are inherently known-good; document this interpretation in PLAN.md for user visibility.

3. **Auto re-fallback mid-session?**
   - What we know: the sink's containment flips `logsAvailable=false` if the active directory becomes unwritable mid-session.
   - What's unclear: whether Phase 4 should add "re-probe + re-fallback on repeated write failure" (a behavior extension beyond SET-02's wording).
   - Recommendation: defer to the deferred backend-optimization round (D-06); Phase 4 covers configuration-time validation only.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | everything | ✓ | 3.47.0 stable (D:/flutter) | — |
| Dart `sdk: ^3.13.1` | pubspec constraint | ✓ | 3.13.x | — |
| file_picker (Windows dir dialog) | SET-02 browse | ✓ | 11.x locked | Manual text entry only (D-03 text field is primary anyway) |
| Windows filesystem | probe/persist | ✓ | — | — |
| l10n codegen | new UI strings | ✓ (l10n.yaml present) | — | — |

**Missing dependencies with no fallback:** none.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + fake_async 1.3.3 (debounce/timer tests) |
| Config file | none (convention: mirror lib path under test/; kernel diagnostics in `test/diagnostics/`, widgets in `test/widget/...`) |
| Quick run command | `flutter test test/diagnostics/ test/widget/dialogs/ test/widget/player/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SET-01 | Toggle off → host renders nothing; toggle on → newest snapshot report renders; snapshot keeps receiving reports while off | widget | `flutter test test/widget/player/error_card_host_test.dart` | ✅ extend |
| SET-01 | Toggle default = enabled when settings.json absent/corrupt | unit | `flutter test test/diagnostics/…` (store tests; planner places file) | ❌ Wave 0 |
| SET-02 | Chain priority: configured(valid) > exe-root > AS; configured invalid skips to next tier | unit (injected providers + temp dirs) | `flutter test test/diagnostics/error_log_location_test.dart` | ✅ extend |
| SET-02 | Probe: file-as-dir (PathExistsException/PathNotFoundException shapes) → tier fails; writable temp dir → passes | unit | same as above | ✅ extend |
| SET-02 | Re-target: dispose→activate preserves order; records during gap buffered then flushed; new file receives post-swap records; old file has all pre-swap records | unit (injectable `ErrorLogWriter`) | `flutter test test/diagnostics/error_log_file_sink_test.dart` + new coordinator test | ✅ extend + ❌ Wave 0 |
| SET-02 | UI validation: debounced probe, inline state (✓/✗/回退中), browse null-cancel ignored | widget + fakeAsync | `flutter test test/widget/dialogs/settings_dialog_test.dart` | ✅ extend |
| SET-03 | Load: missing file, garbage JSON, wrong shape (List), BOM → defaults; save → reload round-trip; save failure swallowed | unit (injected File seam + temp dirs) | new store test file | ❌ Wave 0 |
| SET-03 | Toggle + path survive a fresh store instance (restart simulation) | unit | same | ❌ Wave 0 |
| — | General tab nav: selection state switches content; About still reachable | widget | `flutter test test/widget/dialogs/settings_dialog_test.dart` | ✅ extend |

### Sampling Rate
- **Per task commit:** `flutter test test/diagnostics/ test/widget/dialogs/ test/widget/player/`
- **Per wave merge:** `flutter test` + `flutter analyze` (0-error red line) + `bash tool/audit/kernel_logger_gate.sh` (kernel touched: error_log_location.dart extension must keep GATE 1/2 clean)
- **Phase gate:** full suite green before `/gsd-verify-work`

### Headless Baseline Caveats
- **~57 pre-existing failures in headless `flutter test` runs are the mdk.dll FFI baseline** (MEMORY: reference_mdk_dll_headless_test_failures) — not regressions. Discriminate new failures via the documented stash/re-run method; judge only deltas against baseline.
- **2 pre-existing state-machine security test failures** (MEMORY: reference_state_machine_security_preexisting_failure) — likewise baseline.
- Widget tests here avoid libmpv FFI (fakes/port pattern); the new tests (store, location chain, host gate, dialog) are pure Dart/Flutter and must be **fully green** in headless — do not accept "flaky on CI" for them.

### Wave 0 Gaps
- [ ] `test/diagnostics/error_feedback_settings_store_test.dart` (or planner-chosen location) — load/save/fallback matrix for SET-03
- [ ] Re-target coordinator test (dispose→activate ordering + buffering) — may live in `test/diagnostics/`
- [ ] Injected exe-directory provider + writable-probe seams in `error_log_location.dart` signature (before tests can be written)
- [ ] ARB keys (en+zh) for all new UI strings + regenerated `app_localizations_*.dart`

### Human-Check Items (machine cannot verify)
- 实机 debug run:开关切换后卡片立即消失/恢复,日志路径变更后新错误写入新位置,旧行不丢
- 实机:回退场景的 OSD「日志已回退到默认位置」出现一次且不重复刷屏 (D-04)
- MSIX 包内冒烟:exe-root 探测失败 → 行内状态显示 AS 有效路径(接受差异, D-02)
- 设置对话框输入非法路径(如指向一个文件)的行内 ✗ 呈现与不保存行为

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | **yes** | settings.json = new untrusted input boundary: shape-checked decode (Map guard), bounded path string, control-char/null-byte rejection (path_validator.dart:98-107 philosophy), probe-before-activation |
| V6 Cryptography | no | — |
| V2/V3/V4 | no | No auth/session/access surfaces |
| V7 Error Handling/Logging | yes (carry-over) | Existing redaction/bounding untouched; configured log path displayed only to local user |

### T-01-13/19 Re-audit (required this phase)

Phase 1 accepted two threats on the rationale that retained diagnostic strings had **no sink** — AR-01/AR-02 (01-SECURITY.md:64-68) explicitly triggered re-verification "if a future phase introduces file export (Phase 02 落盘) or clipboard effects". Phase 2 introduced the file sink but authored **no 02-SECURITY.md** (verified: no such file exists in the phase dir); Phase 3's register (03-SECURITY.md) covered card/clipboard surfaces but not the location-config surface. **Phase 4 adds the strongest sink-coupling yet: a persisted settings file drives a filesystem write path.** The plan must include a threat-model block re-verifying T-01-13/19 with the new surface:

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Corrupted/malicious settings.json → hostile log path (e.g., write into a system dir) | Elevation/Tampering | Probe-before-activation (fails on unwritable targets), bounded path length, control-char rejection, silent-fallback-to-defaults on any parse anomaly; single-user dev tool context documented |
| Log forging via report fields (carry-over from Phase 2) | Tampering | Unchanged: pack field escaping, raw stack terminal (diagnostic_pack_formatter contract) |
| Diagnostic evidence path disclosure in UI | Information Disclosure | Effective log path shown to the local user is the feature itself; no remote surface exists |

## Sources

### Primary (HIGH confidence)
- Repo source read this session (line-cited inline): `lib/kernel/diagnostics/error_log_location.dart`, `error_log_file_sink.dart`, `error_reporting_dependencies.dart`, `error_reporter.dart`, `source_line_reader.dart`; `lib/ui/player/error_card_host.dart`, `error_capture_snapshot.dart`; `lib/ui/dialogs/settings/settings_dialog.dart`, `lib/ui/shared/setting_action_row.dart`, `setting_slider_row.dart`; `lib/ui/shared/osd_overlay.dart`; `lib/main.dart`; `lib/kernel/persistence/window_persistence.dart`; `lib/kernel/services/path_validator.dart`; `lib/features/player/file_picker_adapters.dart`; `tool/audit/kernel_logger_gate.sh`; `.planning/phases/01-unified-capture-contract/01-SECURITY.md`; planning docs 02/03/04
- Live probes (this repo + temp dir, this session): `File.rename` replace-on-existing success + transient errno-5 `PathAccessException`; `PathExistsException` (183) / `PathNotFoundException` (3) shapes; temp-file probe correctness; `attrib +r` non-blocking; `jsonDecode` failure shapes + BOM tolerance; `File(Platform.resolvedExecutable).parent`; `flutter test` resolvedExecutable = flutter_tester.exe

### Secondary (MEDIUM confidence)
- [Context7 /dart-lang/sdk](https://github.com/dart-lang/sdk/blob/main/lib/io/platform.dart) — `Platform.resolvedExecutable` contract
- [Context7 /miguelpruivo/flutter_file_picker](https://github.com/miguelpruivo/flutter_file_picker/wiki/API) — `getDirectoryPath` return/cancel/lockParentWindow/initialDirectory semantics
- [Microsoft Learn packaged-app docs via WebSearch](https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-behind-the-scenes) — MSIX AppData copy-on-write redirection to `LocalCache`, WindowsApps ACL (TrustedInstaller-only writes)

### Tertiary (LOW confidence)
- A1/A4 behavioral nuances under exotic ACLs/MSIX configurations — mitigated by probe-first design and graceful fallback

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies; every consumed API verified in-repo or via Context7
- Architecture: HIGH — all integration seams (delegate effect, snapshot, host gate, shell state) read from source with line citations; re-target protocol uses only existing public API
- Pitfalls: HIGH — filesystem behaviors verified by live probes on the target OS this session; A1/A4 are the residual platform unknowns, each with a graceful fallback
- Security: MEDIUM — re-audit scope identified and mitigation patterned; final disposition is a plan-time threat-model decision

**Research date:** 2026-08-31
**Valid until:** 2026-09-30 (stable local stack; no fast-moving dependencies; D-decisions are locked in 04-CONTEXT.md)
