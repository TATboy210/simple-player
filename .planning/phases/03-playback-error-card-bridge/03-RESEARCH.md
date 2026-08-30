# Phase 3: 播放错误桥与非模态卡片 - Research

**Researched:** 2026-08-30
**Domain:** Flutter desktop non-modal overlay UI + ValueNotifier presentation wiring (brownfield, Phase 1/2 contracts already exist)
**Confidence:** HIGH (all integration points read this session; external Flutter behavior verified from framework source/docs)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** 替换 + 计数徽标——新错误替换当前卡片内容;折叠区显示错误计数徽标(如「3 错误」),点击徽标可在捕获的错误间轮览;不堆叠多条卡片(避免遮挡) — reversible — 徽标逻辑独立于卡片本体
- **D-02:** 严重级分层——error/fatal 上常驻卡片(语义色区分);warning 不上卡片,复用 OsdOverlay 短暂提示(与 Phase 1「warning 不落盘」分层一致,防 warning 洪流常驻遮挡) — reversible — 呈现层过滤
- **D-03:** 视觉 = 复用 GlassContainer + Tokens 色板,严重级用语义色(红/fatal 深红)点或边框区分;零新视觉体系 — reversible — 纯样式
- **D-04:** 折叠/展开 = 整卡点击切换,chevron 图标指示状态;折叠显示摘要+严重级+媒体路径 basename(D-07 Phase 2 脱敏边界),展开显示文件:行号/源码行 ±2(D-01 Phase 2)/完整调用栈/日志路径 — reversible
- **D-05:** 挂载 = app/player root Stack 顶层(CARD-06 原文),设置 overlay 之下、控制栏之上;设置打开时卡片被覆盖但仍存活,关闭设置后恢复可见 — reversible — Stack 位置调整
- **D-06:** 复制反馈 = 复用 OsdOverlay pill——成功「已复制」、失败「复制失败」;复制失败不影响卡片与其余反馈(CARD-04) — reversible
- **D-07:** MIG-01 同 phase 内替换+删除——同一组集成测试同时覆盖新旧两条路径,断言新卡片对同一错误源的可见反馈与旧 ErrorBanner 等效后,在 phase 内删除 error_banner.dart 及其挂载;不留双路径 — irreversible-ish — 删除不可逆,但 git 历史可恢复
- **D-08:** 数据源统一——卡片通过 ValueListenableBuilder 订阅 ErrorReporter 呈现状态(ValueNotifier 惯例),所有来源(engine 桥/全局钩子/验证失败)自动汇入同一卡片;PlayerErrorReportBridge 已存在(74 行),本 phase 只需集成测试等效覆盖,不需结构改动 — reversible

### Claude's Discretion
- 计数徽标确切样式与轮览交互细节(上一条/下一条 vs 循环)
- warning OSD 提示的节流参数与时长
- 卡片进出动画曲线/时长(slide-in 自左上角)
- 折叠摘要的字段排版与展开区各段顺序(沿用 D-04 Phase 2 诊断包段序为参考)
- 错误卡片与 OSD 同屏时的位置避让规则
- 等效覆盖测试的具体断言集(与 D-07 判定配合)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CARD-01 | 左上角非模态卡片,常驻手动关,无 route/barrier/autofocus,不抢焦点 | Mount pattern (root Stack `Positioned`), `ExcludeFocus` + `canRequestFocus: false` focus plan; keyboard handler structure verified at `keyboard_handler.dart:74` |
| CARD-02 | hit-test 严格限卡片边界,不遮挡控制 | RenderStack hit-test semantics verified from framework source; `Positioned(left, top)` intrinsic sizing → clicks outside card bounds fall through by default |
| CARD-03 | 折叠摘要+严重级+媒体路径;展开定位/源码行/stack/日志路径 | `ErrorReport`/`ErrorLocation`/`SourceLineReader` contracts already produce all fields (Phase 2); card is pure projection of `ErrorPresentationState.current` |
| CARD-04 | 一键复制诊断包,失败不影响卡片 | `formatDiagnosticPack(report, {logPath})` verified; Clipboard channel failure modes + OsdService feedback pattern documented |
| CARD-05 | build 期错误 post-frame 合并发布,无 markNeedsBuild 次生错误 | Root cause identified: `ErrorReporterImpl._publishSafely` assigns `presentation.value` synchronously during intake; adapter-notifier + schedulerPhase guard pattern documented |
| CARD-06 | root Stack 挂载 + ValueListenableBuilder 订阅 reporter 呈现状态 | `ErrorReporterImpl.presentation` (`ValueNotifier<ErrorPresentationState>`) verified stable-instance; mount point verified in `player_screen.dart` |
| MIG-01 | Bridge 等效覆盖后替换并移除旧 ErrorBanner | Bridge already wired (`player_services.dart:148`); ErrorBanner blast radius enumerated (3 files); equivalence test design + deletion gate documented |
</phase_requirements>

## Summary

This phase is almost entirely **projection and hosting work**, not new diagnostics logic. Phase 1/2 already built and verified the entire data path: four capture sources → `ErrorReporterImpl` bounded FIFO (max 5, 10s dedupe window) → `presentation` `ValueNotifier<ErrorPresentationState>` → `formatDiagnosticPack` for copy/log. The reporter even ships two presentation-host APIs that **nothing in `lib/` currently calls** — `flushPresentation()` (announce readiness) and `dismissCurrent()` (close/advance). The card is the consumer those APIs were designed for.

Three findings dominate the technical risk. **First, CARD-05 has a real, verified failure path:** `_reportSafely` publishes to `presentation` synchronously inside the report call (`error_reporter.dart:277-279`), and `FlutterError.onError` fires *during build* when a widget build throws — so a naive `ValueListenableBuilder` directly on `reporter.presentation` receives `setState` during the build phase and produces exactly the "setState() or markNeedsBuild() called during build" assertion CARD-05 forbids, which itself re-enters `FlutterError.onError` (suppressed by the reentrancy guard, but it pollutes diagnostics). The fix is a small presentation-host adapter (StatefulWidget listening in `initState`, deferring to a post-frame callback when `SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle`), with `ValueListenableBuilder` reading the adapter's own notifier — this honors D-08's "ValueListenableBuilder 订阅" intent without a new state library. **Second, the `isReady` gate:** `_publishSafely` keeps `current == null` until a host announces readiness — without a post-frame `flushPresentation()` call after mount, the card never shows anything, including already-queued bootstrap errors. **Third, hit-test isolation is nearly free** if the card is mounted as a `Positioned(left:, top:)` child with intrinsic sizing: RenderStack hit-tests children in reverse paint order and returns `false` from `hitTestSelf`, so clicks outside the card's bounds fall through to controls below by default — the trap is only `Positioned.fill` wrappers or oversized transparent containers.

MIG-01 is low-risk mechanically (bridge exists and is wired in `PlayerServices._initOnce`; ErrorBanner has exactly one mount point and one test file) but has one equivalence-definition decision: the old banner showed **action buttons** (reopen/select-other-file/retry) that the new card spec does not include — "可见反馈等效" must be understood as message/severity visibility equivalence, and the loss of action buttons should be explicitly confirmed.

**Primary recommendation:** Build an `ErrorCardHost` StatefulWidget (adapter notifier + post-frame deferral + `flushPresentation()` on mount + `dismissCurrent()` on close) rendering an `ErrorCard` widget (GlassContainer, `Positioned(left, top)` in the PlayerScreen inner Stack, `ExcludeFocus` subtree), delete ErrorBanner after the equivalence widget test passes, and keep the reporter kernel untouched except for nothing — no kernel changes are required.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Error presentation state (queue head, counts) | Kernel (`ErrorReporterImpl.presentation`) | — | Already owns FIFO + notifier; card must not duplicate queue state |
| Build-phase deferral (CARD-05) | UI host (`ErrorCardHost` StatefulWidget) | — | Scheduler phase is a UI-binding concern; kernel stays scheduler-agnostic |
| Card rendering/fold-expand (CARD-03) | UI (`ErrorCard` widget) | — | Pure projection of immutable `ErrorReport` |
| Copy to clipboard (CARD-04) | UI (card) | Kernel formatter | Formatting already in kernel (`formatDiagnosticPack`); channel call + failure UX in UI |
| Warning OSD routing (D-02) | UI host (severity filter) | OsdService | Presentation-layer filter per D-02; no kernel change |
| Engine error fan-in | Kernel (`PlayerErrorReportBridge`) | — | Already implemented + wired; MIG-01 is test-coverage only |
| Card mount & z-order (CARD-06/D-05) | UI (`PlayerScreen` root Stack) | — | Stack position controls settings-coverage semantics |

## Standard Stack

No new packages. Everything is in-repo assets + Flutter SDK.

### Core (in-repo, verified this session)
| Asset | Location | Purpose | Why Standard |
|-------|----------|---------|--------------|
| `ErrorReport` / `ErrorPresentationState` | `lib/kernel/diagnostics/error_report.dart:38-153` | Immutable card data source | Phase 1 contract, already fuzz/boundary tested |
| `ErrorReporterImpl.presentation` | `lib/kernel/diagnostics/error_reporter.dart:117-125` | `ValueNotifier<ErrorPresentationState>` to subscribe | Single source of truth; stable instance |
| `flushPresentation()` / `dismissCurrent()` | `lib/kernel/diagnostics/error_reporter.dart:229-245` | Host readiness + close/advance APIs | Unused so far — designed for exactly this host |
| `formatDiagnosticPack(report, {logPath})` | `lib/kernel/diagnostics/diagnostic_pack_formatter.dart:13` | CARD-04 copy text, identical to log format | LOG-05 verified |
| `GlassContainer` + `GlassTier` | `lib/ui/shared/glass_container.dart:56-178` | D-03 card visual | Cached ImageFilter, resize/opacity degradation built in |
| `OsdService.I.show()` | `lib/ui/shared/osd_overlay.dart:38-49` | D-02 warning + D-06 copy feedback | Existing global singleton, auto-hide timer |
| `PlayerErrorReportBridge` | `lib/kernel/diagnostics/player_error_report_bridge.dart` | Engine → reporter bridge (MIG-01 object) | Wired at `lib/kernel/player_services.dart:148-156` |
| `Tokens.*` | `lib/ui/theme/tokens.dart` | All visual values | Project red line |

### Supporting (Flutter SDK, no install)
| API | Purpose | Note |
|-----|---------|------|
| `ValueListenableBuilder<T>` | Rebuild on adapter notifier | Project convention (D-08) |
| `Positioned` in `Stack` | Non-modal mount | See hit-test pattern below |
| `ExcludeFocus` / `FocusNode(canRequestFocus: false)` | CARD-01 no-focus-steal | `CITED: api.flutter.dev/flutter/widgets` (widgets index: "ExcludeFocus prevents descendants from being focusable") |
| `AnimatedSlide`/`SlideTransition` + `RepaintBoundary` | Slide-in animation + repaint isolation | `ASSUMED` — in-repo precedent is `AnimatedOpacity`+`RepaintBoundary` (osd_overlay.dart:121-132) |
| `Clipboard.setData` (`package:flutter/services.dart`) | CARD-04 | `CITED: api.flutter.dev` — `flutter/platform` channel, returns null on success |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Root/inner `Stack` mount (D-05, CARD-06) | `Overlay`/`OverlayEntry` | OverlayEntry sits above **routes** (settings dialog would no longer cover the card, violating D-05) and needs manual lifecycle bookkeeping. Stack mount is simpler and matches the locked decision. |
| Adapter notifier + post-frame guard | Direct `ValueListenableBuilder` on `reporter.presentation` | Direct subscription breaks CARD-05 (see Pitfall 1). Adapter is ~30 lines. |
| Local card history snapshot for badge cycling | New reporter read API (e.g. un-`@visibleForTesting` `queuedReports`) | Local snapshot keeps kernel untouched (D-08 "不需结构改动"); reporter API change is the fallback if snapshot semantics prove wrong. |

## Package Legitimacy Audit

**Not applicable** — this phase installs zero external packages (pure in-repo UI + Flutter SDK APIs). No registry checks required.

## Architecture Patterns

### System Architecture Diagram

```
[FlutterError.onError / PlatformDispatcher / runZonedGuarded]   [engine.lastError]
            | (installed in main.dart, live)                        |
            |                                        PlayerErrorReportBridge
            |                                        (player_services.dart:148)
            v                                                    |
      +-------------------------------------------+--------------+
      |            ErrorReporterImpl (kernel)     |
      |  bounded FIFO (max 5) → presentation:      |
      |  ValueNotifier<ErrorPresentationState>     |
      +--------------------+----------------------+
                           | addListener (initState)
                           v
      +-------------------------------------------+
      |      ErrorCardHost (UI, in PlayerScreen    |
      |      inner Stack, Positioned left/top)     |
      |  1. phase-guard: idle→copy, else           |
      |     addPostFrameCallback (CARD-05)         |
      |  2. severity filter: warning→OsdService    |
      |     (D-02); error/fatal→card notifier      |
      |  3. flushPresentation() post-frame on      |
      |     mount; dismissCurrent() on close       |
      +------+-------------------+----------------+
             |                   |
             v                   v
      ErrorCard (GlassContainer, fold/expand,   OsdOverlay pill
      ExcludeFocus, RepaintBoundary)            「已复制/复制失败」
             |
             v
      formatDiagnosticPack(report, logPath) → Clipboard.setData
```

Primary use case trace: engine open fails → `lastError` notifier → bridge → `reportPlayerError` → FIFO + `presentation` update → host listener (deferred if in build) → card notifier → card visible top-left → user clicks copy → formatter → clipboard → OSD pill.

### Recommended Project Structure
```
lib/ui/player/
├── error_card.dart           # ErrorCard stateless/presentation widget (fold/expand, copy button)
├── error_card_host.dart      # ErrorCardHost StatefulWidget (adapter notifier, phase guard,
│                             #   severity filter, flush/dismiss wiring) — if it grows past
│                             #   ~200 lines, split host from notifier adapter
lib/kernel/diagnostics/       # NO CHANGES expected (D-08: 不需结构改动)
test/widget/player/
├── error_card_test.dart      # new card widget tests
├── error_card_host_test.dart # host scheduling/severity/dismiss tests
├── error_banner_test.dart    # DELETED in this phase (MIG-01)
```

### Pattern 1: CARD-05 build-phase-safe presentation adapter
**What:** The reporter publishes synchronously; a host adapter absorbs notifications and only mutates its own notifier when the scheduler is idle or from a post-frame callback.
**When to use:** Always for this card — `FlutterError.onError` fires during build for any build exception, and `_reportSafely` → `_publishSafely` → `presentation.value = ...` runs inside that window (`[VERIFIED: lib/kernel/diagnostics/error_reporter.dart:277-279, 477-493]`).
**Example:**
```dart
// Source: defensive composition of docs.flutter.dev/testing/common-errors.md
// + SchedulerBinding API (framework)
class _ErrorCardHostState extends State<ErrorCardHost> {
  final ValueNotifier<ErrorPresentationState> _cardState =
      const ErrorPresentationState(current: null, pendingCount: 0, isReady: false)
          as dynamic; // real code: ValueNotifier(initial)

  @override
  void initState() {
    super.initState();
    ErrorReporterImpl.I.presentation.addListener(_onPresentationChanged);
    // Announce readiness AFTER first frame — before this, _publishSafely keeps
    // current == null even when the queue already holds bootstrap errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ErrorReporterImpl.I.flushPresentation();
    });
  }

  void _onPresentationChanged() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      _apply(ErrorReporterImpl.I.presentation.value);
    } else {
      // Build/layout/paint phase: defer. Copying value now would call setState
      // during build (CARD-05 forbidden secondary error).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _apply(ErrorReporterImpl.I.presentation.value);
      });
    }
  }
  // _apply: severity filter (warning→OsdService.I.show) then _cardState.value = ...
}
```
**Key detail:** read `presentation.value` *inside* the post-frame callback (fresh value), not the stale one captured at scheduling time.

### Pattern 2: CARD-02 hit-test-isolated mount
**What:** Mount the card as a `Positioned(left:, top:)` child with intrinsic sizing inside the existing PlayerScreen inner Stack.
**When to use:** Always — this is what makes "严格限卡片边界" free.
**Verified framework behavior:** `RenderStack.hitTestChildren` delegates to `defaultHitTestChildren`, which iterates children in **reverse painting order** (topmost first), and `RenderStack` does not override `hitTestSelf`, so the default `RenderBox.hitTestSelf` returns `false` — positions not covered by any child fall through to render objects behind the stack `[VERIFIED: flutter/flutter packages/flutter/lib/src/rendering/stack.dart, fetched 2026-08-30]`.
```dart
// Inside the Stack at player_screen.dart:250-256 (children after RepaintBoundary(cachedVideoContent)):
Positioned(
  left: Tokens.controlBarMarginH,
  top: 12, // discretion: below title bar, top-left
  child: RepaintBoundary(
    child: ErrorCardHost(...), // card sizes itself; GlassContainer's ClipRRect
                               // clips both paint AND hit-test to the rounded rect
  ),
),
```
**Anti-trap:** do NOT use `Positioned.fill` + `Align`, and do NOT wrap the card in an opaque full-size `Container` — that makes the whole overlay area hit-testable and blocks controls below.

### Pattern 3: CARD-01 no-focus-steal
**What:** The root keyboard handler owns focus via `Focus(autofocus: true, onKeyEvent: _handleKeyEvent, child: child)` `[VERIFIED: lib/ui/player/keyboard_handler.dart:74]`. Any focusable descendant of the card (e.g. `GlassButton`'s `FocusableActionDetector` with its own `focusNode`, `glass_container.dart:388-398`) can steal focus on click — after which Space would activate the button instead of play/pause.
**How to avoid:** wrap the card subtree in `ExcludeFocus` (`CITED: api.flutter.dev — "ExcludeFocus prevents descendants from being focusable"`), and drive the copy button with a plain `GestureDetector`/`InkWell(canRequestFocus: false)` rather than `GlassButton` (or pass `GlassButton(focusNode: FocusNode(canRequestFocus: false, skipTraversal: true))`). The card has no text input, so `ExcludeFocus` is safe. D-04's whole-card tap is a `GestureDetector` — naturally focus-free.

### Pattern 4: D-06 copy with failure isolation
**What:** Copy is an async platform-channel call; success and failure each route to OsdService, and neither can affect the card.
**Verified precedent:** `Clipboard.setData(ClipboardData(text: value))` at `lib/ui/dialogs/media_info_dialog.dart:194` — but note that precedent **never awaits or catches**; the card must improve on it.
```dart
// Clipboard.setData is a 'flutter/platform' channel call returning null on success
// [CITED: api.flutter.dev embedder APIDOC]. Failure modes: PlatformException from
// embedder; MissingPluginException in widget tests when the channel is unmocked.
Future<void> _copyDiagnosticPack(ErrorReport report, String? logPath) async {
  try {
    await Clipboard.setData(
      ClipboardData(text: formatDiagnosticPack(report, logPath: logPath)),
    );
    OsdService.I.show(l10n.copied, icon: Icons.check);
  } on PlatformException catch (e, st) {          // typed catch (project rule)
    OsdService.I.show(l10n.copyFailed, icon: Icons.error_outline);
    debugPrint('copy failed: $e');                 // UI layer may debugPrint
    KernelLogger.I.w('clipboard copy failed', error: e, stackTrace: st);
  } on MissingPluginException catch (e) {
    OsdService.I.show(l10n.copyFailed, icon: Icons.error_outline);
  }
}
```
Log path for the pack: `ErrorReporterImpl.I.diagnosticLogPath` (`ValueListenable<String?>`, `error_reporter.dart:133-135`) — take `.value` at copy time.

### Anti-Patterns to Avoid
- **Direct `ValueListenableBuilder` on `reporter.presentation`:** breaks CARD-05 (Pitfall 1). Use the adapter.
- **Forgetting `flushPresentation()`:** card renders nothing forever; `isReady` gates `current` (`error_reporter.dart:481`: `current = ready && _queue.isNotEmpty ? _queue.first : null`).
- **`Positioned.fill` card wrapper:** destroys CARD-02 hit-test pass-through.
- **Calling `dismissCurrent()` for badge cycling without intent:** it permanently removes the FIFO head (queue-only; file evidence survives, but the card cannot go back). Cycling should page through a **local** snapshot list; only manual close calls `dismissCurrent()`.
- **Warning auto-dismiss loop:** if the head is a warning, show OSD then `dismissCurrent()` once — do not re-show on every rebuild.
- **BackdropFilter during resize:** pass the existing `resizing` `ValueListenable` into `GlassContainer(resizing:)` (`glass_container.dart:73,122-137`) so card blur skips GPU readback during window resize, consistent with the rest of the app.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Diagnostic text formatting | Custom string building in the card | `formatDiagnosticPack` | LOG-05 guarantees card copy == log file format; divergence is a verified-evidence bug |
| Error queue/dedupe/counting | Card-local merging logic | `ErrorReporterImpl` FIFO + `occurrenceCount` | CAP-04 already implemented + tested (`error_reporter_test.dart`) |
| l10nKey → message resolution | New mapping | Reuse the pattern from `error_banner.dart:124-141` (same switch shape) before deleting it | All 13 existing keys + fallback already enumerated |
| Toast/pill feedback | New floating widget | `OsdService.I.show(text, icon:)` | D-06 locked; auto-hide timer built in |
| Glass surface | New blur container | `GlassContainer` | D-03 locked; degradation paths (D-13/D-14, resizing) built in |
| build-phase scheduling | Custom polling/retry | `SchedulerBinding.schedulerPhase` + `addPostFrameCallback` | Framework-blessed; testable with `fake_async`/`tester.pump` |

**Key insight:** the diagnostics kernel is contract-complete and heavily tested. Every hand-rolled alternative in the card would create a *second* diagnostic path — the exact anti-goal of this milestone.

## Runtime State Inventory

> Included because MIG-01 is a replace-and-delete migration.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — `ErrorReport`/queue is in-memory per-process; file evidence is append-only error.log and is never rewritten by the card | None |
| Live service config | None — no external service holds ErrorBanner state (grep-verified: ErrorBanner referenced only by `player_video_controls.dart` mount and its own test) | None |
| OS-registered state | None | None |
| Secrets/env vars | None — no key/env rename involved | None |
| Build artifacts | None — pure Dart source deletion, no codegen depends on `error_banner.dart` | None |

**ErrorBanner deletion blast radius (MIG-01), grep-verified this session:**
1. `lib/ui/player/error_banner.dart` — delete (142 lines).
2. `lib/ui/player/player_video_controls.dart:882-897` — remove the `Positioned(... child: RepaintBoundary(child: ErrorBanner(...)))` subtree and the now-unused import.
3. `test/widget/player/error_banner_test.dart` — delete; its assertion set (l10n message resolution per `PlayerError` subtype, action-button visibility) is the equivalence baseline the new card tests must reproduce **minus action buttons** (see Open Question 2).

## Common Pitfalls

### Pitfall 1: markNeedsBuild secondary error from build-phase report intake (CARD-05)
**What goes wrong:** a widget build throws → framework calls `FlutterError.onError` → hook calls `reportFlutterSafely` → `_publishSafely` sets `presentation.value` synchronously → a directly-attached `ValueListenableBuilder` listener calls `setState` during build → "setState() or markNeedsBuild() called during build" assertion. Worse, that assertion itself is a FlutterError → re-enters the reporter (reentrancy guard suppresses, but diagnostics are polluted and the original error's presentation can be lost).
**Why it happens:** `CITED: docs.flutter.dev/testing/common-errors.md` — the framework forbids marking widgets dirty while building.
**How to avoid:** Pattern 1 adapter (phase check + post-frame deferral). Note `SchedulerPhase.persistentCallbacks` is the build/layout/paint window; only `SchedulerPhase.idle` is safe for synchronous `setState`.
**Warning signs:** during fault-injection tests, the original expected error card is accompanied by an assertion about an unrelated widget being marked dirty.

### Pitfall 2: card never appears (isReady gate)
**What goes wrong:** everything wired, queue non-empty (e.g. a bootstrap error occurred pre-mount), card invisible.
**Why:** `_publishSafely` computes `current = ready && _queue.isNotEmpty ? _queue.first : null`; `isReady` starts `false` and only `flushPresentation()` sets it `[VERIFIED: lib/kernel/diagnostics/error_reporter.dart:477-489, 231]`.
**How to avoid:** post-frame `flushPresentation()` in host `initState` (Pattern 1). `flushPresentation()` is idempotent with respect to readiness (`isReady ?? prior.isReady`).
**Warning signs:** unit tests that drive the reporter directly see `presentation.value.current == null` despite `pendingCount > 0`.

### Pitfall 3: hit-test blockers (CARD-02)
**What goes wrong:** clicking outside the card does nothing / seekbar or title bar unresponsive while card is visible.
**Why:** an oversized wrapper (`Positioned.fill`, full-width `Container`, or a `Stack` child with `StackFit.expand` above the video) becomes a hit-testable rect covering the content area.
**How to avoid:** `Positioned(left:, top:)` + intrinsic card size; verify with a widget test that taps a control below the card's rect and asserts the control's callback fires. `IgnorePointer` is for pass-through-**everything** (OSD already uses it, `osd_overlay.dart:121`) — do not wrap the interactive card in it.
**Warning signs:** Windows manual smoke (VER-04) finds controls dead only while a card is showing.

### Pitfall 4: keyboard focus stolen by card buttons (CARD-01)
**What goes wrong:** clicking copy/close moves focus into the card; Space/arrows stop reaching `KeyboardHandler`.
**Why:** `keyboard_handler.dart:74` uses one root `Focus(autofocus: true)`; `FocusableActionDetector`-based buttons request focus on tap.
**How to avoid:** `ExcludeFocus` around card subtree; `GestureDetector`/`canRequestFocus:false` for interactive elements.
**Warning signs:** after clicking the card, Space toggles the card button instead of play/pause.

### Pitfall 5: fullscreen hides the card silently
**What goes wrong:** an error occurs in fullscreen; user sees nothing.
**Why:** media_kit's fullscreen pushes its own route that replicates the `Video.controls` builder (`player_screen.dart:313-317` comment: "media_kit 全屏 route 会复制此 builder") — a card mounted only in the PlayerScreen body Stack is covered by that route. Settings dialog (`showDialog`, `settings_dialog.dart:19-20`) likewise covers the card, which D-05 explicitly accepts; D-05 is silent on fullscreen.
**How to avoid:** accept coverage as the initial behavior (matches D-05's settings precedent: card stays alive under the Stack), and note it in the plan; duplicating the host inside the `_buildControls` builder is the escalation path but re-introduces two hosts double-calling `flushPresentation`/`dismissCurrent` — avoid unless required.

## Code Examples

### Consuming the verified presentation contract
```dart
// Source: [VERIFIED: lib/kernel/diagnostics/error_report.dart:137-153] — verbatim:
//   final class ErrorPresentationState {
//     const ErrorPresentationState({required this.current, required this.pendingCount, required this.isReady});
//     final ErrorReport? current; final int pendingCount; final bool isReady;
//   }
// Badge (D-01): pendingCount for queued-behind count; current.occurrenceCount for dedupe repeats.
// Queue bounds [VERIFIED: lib/kernel/diagnostics/error_reporter.dart:47-50]:
//   static const int _maxQueueLength = 5;
//   static const Duration _dedupeWindow = Duration(seconds: 10);
```

### Severity routing (D-02)
```dart
// Severity enum [VERIFIED: lib/kernel/diagnostics/error_report.dart:23-32] — verbatim values:
//   enum ErrorSeverity { warning, error, fatal }
void _apply(ErrorPresentationState s) {
  final report = s.current;
  if (report == null) { _cardState.value = s; return; }   // card hides
  if (report.severity == ErrorSeverity.warning) {
    OsdService.I.show(report.message, icon: Icons.warning_amber_outlined);
    ErrorReporterImpl.I.dismissCurrent();                 // advance past warning once
    return;
  }
  _history.add(report);                                   // bounded local snapshot for badge cycling
  _cardState.value = s;
}
```
Note: **no installed hook currently emits `warning`** — the four intakes hardcode `ErrorSeverity.error` or map `PlayerError.isFatal` (`error_reporter.dart:176-216`). The warning branch is future-proofing for Phase 4/5 sources; keep it cheap and tested synthetically.

### Semantic color mapping (D-03)
```dart
// [VERIFIED: lib/ui/theme/tokens.dart:18] — verbatim: static const danger = Color.fromARGB(255, 250, 55, 55);
// No warning/fatal token exists yet (grep-verified tokens.dart) — discretion:
// add Tokens.warning (e.g. amber) + reuse danger for error, a deepened danger for fatal.
Color _severityColor(ErrorSeverity s) => switch (s) {
  ErrorSeverity.fatal   => Tokens.danger /* or new deepened token */,
  ErrorSeverity.error   => Tokens.danger,
  ErrorSeverity.warning => /* new Tokens.warning */,
};
```

### Fold/expand content mapping (CARD-03/D-04)
| Fold section | Data source (all verified contracts) |
|--------------|--------------------------------------|
| 摘要 | `report.message` (redacted, bounded 4096) |
| 严重级 | `report.severity` → semantic color dot/border |
| 媒体路径 | `report.mediaPath` (already basename-safe per Phase 2 D-07; do **not** show `fullMediaPath` here) |
| 展开: 文件:行号 | `report.location?.primaryFrame` → `file:line` (`ErrorLocation.file/line`, `error_location.dart:33-49`) |
| 展开: 源码行 | `report.location?.sourceLines` (already `lineNumber: text`, populated only in debug/profile after containment checks) |
| 展开: 完整调用栈 | `report.rawStackTrace` (raw, terminal section — render verbatim, in a monospace scrollable) |
| 展开: 日志路径 | `ErrorReporterImpl.I.diagnosticLogPath?.value` (`error_reporter.dart:133-135`) |
| 展开: 重复 | `report.occurrenceCount` + `firstOccurredAt`/`lastOccurredAt` |

Expanded long-text container: a `SingleChildScrollView` is sufficient — the raw stack is hard-bounded at 16384 chars (`_maxStackLength`, `error_reporter.dart:56`), so virtualization via `ListView` is unnecessary; prefer `SingleChildScrollView` + `SelectableText` for stack and location sections (also gives free text selection, complementing the copy button).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ErrorBanner` subscribes to `engine.state` + `engine.lastError` directly (`error_banner.dart:31-37`), gated on `MediaState.error` | Card subscribes to `ErrorReporterImpl.presentation` (all four sources, queue-aware) | This phase | One presentation path; engine-independent (works pre-engine / for framework errors) |
| Ad-hoc copy (`media_info_dialog.dart:194`, no await/catch) | Awaited, typed-catch, OSD-feedback copy | This phase | CARD-04 failure isolation |
| Banner auto-bound to error state (no close) | Persistent manual-close card advancing a FIFO | This phase | CAP-04 "关闭卡片推进队列" semantics realized in UI |

**Deprecated/outdated:**
- `ErrorBanner` + its `error_banner_test.dart`: deleted in this phase (MIG-01/D-07). Git history is the recovery path.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Slide-in animation via `AnimatedSlide`/`SlideTransition` + `RepaintBoundary` is adequate (no Context7 doc hit; in-repo precedent only) | Standard Stack / Patterns | Low — pure visual discretion (D-04 discretion grants animation curve/duration freedom) |
| A2 | `SingleChildScrollView` handles the bounded 16KB stack text without perf issues | Code Examples | Low — bounded input; worst case a few hundred lines |
| A3 | media_kit fullscreen route covers the PlayerScreen body Stack (inferred from in-repo comments + memory, not independently re-verified in media_kit source this session) | Pitfall 5 | Medium — if wrong, card visibility in fullscreen differs from expectation; plan should note a manual smoke check |
| A4 | `test/bundle backup` git-recovery assumption for MIG-01 deletion: standard git history suffices | Runtime State Inventory | None (delete is reviewed in diff) |
| A5 | Adapter-notifier approach satisfies D-08's "ValueListenableBuilder 订阅 ErrorReporter 呈现状态" wording (it subscribes via an adapter, not literally to `presentation`) | Summary/Pattern 1 | Low-Medium — deviation is justified by CARD-05; flag in plan for user visibility |

## Open Questions

1. **Card visibility during media_kit fullscreen**
   - What we know: D-05 locks root-Stack mount and settings-coverage semantics; fullscreen route replicates the controls builder and will cover a body-Stack card (A3).
   - What's unclear: should the card also be replicated inside `Video.controls` for fullscreen?
   - Recommendation: accept hidden-in-fullscreen for this phase (note it in the plan + VER-04 smoke checklist); revisit only if the user objects.

2. **Do ErrorBanner's action buttons (reopen/select-other-file/retry) intentionally disappear?**
   - What we know: `error_banner.dart:44-64` maps each `PlayerError` subtype to a recovery action; CARD-01..06 and D-01..D-08 specify copy/close/expand only — no recovery actions. "可见反馈等效" (D-07) is satisfiable without them.
   - What's unclear: whether dropping one-click recovery is user-accepted UX regression.
   - Recommendation: treat equivalence as message+severity visibility equivalence; surface the action-button drop explicitly in the plan for user confirmation (cheap to defer, not to retrofit).

3. **Badge cycling source of truth**
   - What we know: `presentation` exposes only `current` + `pendingCount`; the full queue is `@visibleForTesting` (`error_reporter.dart:169-170`). D-08 says no structural changes needed.
   - What's unclear: whether local-snapshot history (bounded, e.g. last 20 eventIds) is acceptable vs. exposing a read-only reporter API.
   - Recommendation: local snapshot first (zero kernel change); fall back to a reporter read API only if tests show snapshot semantics break (e.g. merged reports changing identity).

4. **Pre-mount window host**
   - What we know: bootstrap errors (e.g. `windowInitError` path, `main.dart:71`) are queued before `PlayerScreen` mounts; the card host lives inside the deferred PlayerFeature module, so a failure during deferred loading leaves the queue un-presented until/unless a host mounts.
   - What's unclear: acceptable for MVP (file evidence still lands).
   - Recommendation: accept; note that `flushPresentation()` on mount retroactively presents queued bootstrap errors — that is the designed behavior.

## Environment Availability

> Step 2.6: SKIPPED (no external dependencies) — this phase adds no packages, tools, or services. It uses the existing Flutter SDK 3.47.0 toolchain, `flutter_test`, and in-repo assets. Headless `flutter test` caveats are covered in Validation Architecture.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK, Flutter 3.47.0); fake_async 1.3.3 available |
| Config file | none beyond `analysis_options.yaml` (no test config file needed) |
| Quick run command | `flutter test test/widget/player/error_card_test.dart test/widget/player/error_card_host_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CARD-01 | Card persists, manual close only, no autofocus/focus steal | widget | `flutter test test/widget/player/error_card_test.dart -x skipped` (focus assertions: `FocusManager.instance.primaryFocus` unchanged after tap) | ❌ Wave 0 |
| CARD-02 | Clicks outside card bounds reach controls below | widget | `flutter test test/widget/player/error_card_test.dart --plain-name 'hit-test'` (tap a control under the card rect, assert callback) + Windows manual smoke | ❌ Wave 0 |
| CARD-03 | Fold shows summary/severity/mediaPath; expand shows file:line, sourceLines, raw stack, log path | widget | `flutter test test/widget/player/error_card_test.dart --plain-name 'expand'` | ❌ Wave 0 |
| CARD-04 | Copy success + failure (mock `flutter/platform` `Clipboard.setData` handler; failure injection) → OSD feedback, card unaffected | widget | `flutter test test/widget/player/error_card_test.dart --plain-name 'copy'` | ❌ Wave 0 |
| CARD-05 | Build-phase report arrival does not throw markNeedsBuild; post-frame merge publishes | widget + unit | `flutter test test/widget/player/error_card_host_test.dart` (fault: throw inside a child build while host mounted; assert no secondary assertion, card appears after `tester.pump`) | ❌ Wave 0 |
| CARD-06 | Host mounted in PlayerScreen root Stack; ValueListenableBuilder over presentation state | widget | `flutter test test/widget/player/error_card_host_test.dart --plain-name 'mount'` | ❌ Wave 0 |
| MIG-01 | New card gives equivalent visible feedback for the same engine error the old banner covered; old files removed | widget + grep gate | `flutter test test/widget/player/error_banner_equivalence_test.dart` (write first against FakeEngine + bridge + reporter, run against BOTH paths pre-deletion) then `flutter test test/widget/player/` and grep gate: `grep -r ErrorBanner lib/ test/` returns nothing | ❌ Wave 0 (equivalence test); deletion task |
| D-02 | warning head → OsdService shown, card not, queue advanced once | widget | `flutter test test/widget/player/error_card_host_test.dart --plain-name 'warning'` (synthetic warning report via `ErrorReporterImpl.forTesting`) | ❌ Wave 0 |

### Headless-test baseline caveats (from project memory, load-bearing)
- ~57 pre-existing failures in headless environments stem from `mdk.dll` FFI load failures — **never construct `MediaKitEngine`/media_kit `Player` in card tests**; use `test/helpers/fake_engine.dart` + reporter fixtures (bridge tests in `test/diagnostics/player_error_report_bridge_test.dart` are the template).
- `KernelLoggerImpl.resetForTesting()` + `init()` in `setUpAll` per existing diagnostics-test convention; `ErrorReporterImpl.resetForTesting()` between tests (singleton).
- Pre-existing unrelated failures (state-machine security tests) must be triaged by `git stash` isolation, not fixed in this phase.
- Clipboard in widget tests: unmocked channel throws `MissingPluginException` — mock via `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler` on the `flutter/platform` channel (this doubles as the CARD-04 failure-injection seam).

### Sampling Rate
- **Per task commit:** quick run command (card + host tests)
- **Per wave merge:** `flutter test` full suite must be green-except-documented-pre-existing; `flutter analyze` 0 errors (red line)
- **Phase gate:** full suite + grep gate (no ErrorBanner refs) + Windows manual smoke (hit-test/controls during card display, VER-04 preview items)

### Wave 0 Gaps
- [ ] `test/widget/player/error_card_test.dart` — CARD-01/02/03/04
- [ ] `test/widget/player/error_card_host_test.dart` — CARD-05/06 + D-02 routing
- [ ] `test/widget/player/error_banner_equivalence_test.dart` — MIG-01 (run against old path BEFORE deletion, retargeted after)
- [ ] New l10n keys in `lib/l10n/app_en.arb` / `app_zh.arb` + regenerate (`flutter gen-l10n`; generated files are committed)

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | Card renders only already-redacted/bounded `ErrorReport` fields (`DiagnosticRedactor` at intake, `error_reporter.dart:299-306`); never render raw exception objects |
| V6 Cryptography | no | N/A |
| V2/V3/V4 | no | No auth/session/access control surface |
| Path/PII disclosure | yes | Presentation uses `mediaPath` (redacted); `fullMediaPath`/`failedOpenPath` appear **only** inside the copied diagnostic pack (developer-evidence contract, `error_report.dart:96-107`) — do NOT render them in the visible card |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Diagnostic text carrying control characters / path leakage into UI | Information Disclosure | Render only reporter-sanitized fields; raw stack is the sole verbatim field (by contract) and stays inside expand + copy |
| Clipboard eavesdropping of diagnostic pack | Information Disclosure | Accepted by design (local developer tool); pack contents already redact ordinary paths |
| Error-message spoofing via crafted file names | Tampering | Message field is redacted+bounded at intake; no rich-text rendering (`Text` only, no HTML/Markdown) |

## Sources

### Primary (HIGH confidence)
- `lib/kernel/diagnostics/error_reporter.dart` (read in full) — presentation notifier, flush/dismiss, isReady gate, queue bounds, intake severity mapping
- `lib/kernel/diagnostics/error_report.dart` (read in full) — ErrorReport/ErrorPresentationState/Severity verbatim contracts
- `lib/kernel/diagnostics/error_location.dart`, `diagnostic_pack_formatter.dart` (read) — location + pack formats
- `lib/ui/player/error_banner.dart`, `player_screen.dart`, `player_video_controls.dart:830-929`, `keyboard_handler.dart`, `osd_overlay.dart`, `glass_container.dart`, `main.dart`, `player_services.dart:120-199`, `media_info_dialog.dart:170-210`, `tokens.dart` (targeted reads)
- flutter/flutter `packages/flutter/lib/src/rendering/stack.dart` (fetched 2026-08-30) — hit-test order + hitTestSelf
- docs.flutter.dev/testing/common-errors.md (via Context7) — setState-during-build

### Secondary (MEDIUM confidence)
- api.flutter.dev widgets index (via Context7) — ExcludeFocus/ExcludeFocusTraversal, IgnorePointer semantics
- api.flutter.dev embedder APIDOC (via Context7) — Clipboard.setData channel contract

### Tertiary (LOW confidence)
- Slide-in animation specifics (A1) — in-repo precedent only, discretion-granted

## Metadata

**Confidence breakdown:**
- Data contracts & integration points: HIGH — every referenced file read this session with line-cited verbatim values
- Flutter framework behavior (hit-test, build-phase, focus, clipboard): HIGH/MEDIUM — framework source + official docs fetched; animation specifics LOW (A1)
- Migration blast radius: HIGH — grep-verified 3-file closure

**Research date:** 2026-08-30
**Valid until:** 2026-09-29 (stable in-repo contracts; Flutter SDK pinned)
