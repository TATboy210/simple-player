# Phase 3: 播放错误桥与非模态卡片 - Pattern Map

**Mapped:** 2026-08-30
**Files analyzed:** 9 (5 new + 4 modified/deleted)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/ui/player/error_card.dart` (new) | component | request-response (fold/expand, copy) | `lib/ui/player/error_banner.dart` (l10n/Tokens structure) + `lib/ui/shared/glass_container.dart` (visual) | role-match |
| `lib/ui/player/error_card_host.dart` (new) | component (stateful host) | event-driven (listener → post-frame apply) | `lib/ui/shared/osd_overlay.dart` (initState addListener/dispose pattern) | role-match |
| `lib/ui/player/player_screen.dart` (modify) | component (screen) | n/a | self — existing root Stack at lines 242-259 | exact |
| `lib/ui/player/player_video_controls.dart` (modify) | component | n/a | self — ErrorBanner mount at lines 882-897 is the removal target | exact |
| `lib/ui/theme/tokens.dart` (modify) | config | n/a | self — add `Tokens.warning` etc. next to `danger` (line 18) | exact |
| `lib/l10n/app_en.arb` + `app_zh.arb` (modify) | config | n/a | existing `error.*` keys consumed by `error_banner.dart:124-141` | exact |
| `test/widget/player/error_banner_equivalence_test.dart` (new) | test (widget, integration-flavored) | event-driven | `test/diagnostics/player_error_report_bridge_test.dart` (fixture + reporter wiring) | exact |
| `test/widget/player/error_card_test.dart` (new) | test (widget) | n/a | `test/widget/player/error_banner_test.dart` | exact |
| `test/widget/player/error_card_host_test.dart` (new) | test (widget) | event-driven | `test/diagnostics/player_error_report_bridge_test.dart` + `error_banner_test.dart` setUp/tearDown | role-match |
| `lib/ui/player/error_banner.dart` + `test/widget/player/error_banner_test.dart` (DELETE) | — | — | deletion only; MIG-01 grep gate after | — |

All analogs verified git-tracked (`git ls-files` non-empty for every named path).

## Pattern Assignments

### `lib/ui/player/error_card.dart` (component, request-response)

**Analog A (visual shell):** `lib/ui/shared/glass_container.dart:56-178`

Card body is a plain composition — GlassContainer takes width/padding/border/tier/resizing; ClipRRect clips paint AND hit-test to the rounded rect (this is what gives CARD-02 for free):

```dart
// glass_container.dart:78-92 — constructor params to use
const GlassContainer({
  super.key,
  required this.child,
  this.width, this.height, this.padding, this.margin,
  this.borderRadius, this.border,
  this.tier = GlassTier.normal,
  this.opacity, this.blurEnabled = true,
  this.resizing,              // pass windowService.isResizing through (anti-pattern: blur during resize)
  this.backgroundColor,
});

// glass_container.dart:98-106 — default surface = bgGlass + borderHighlight
final content = Container(
  decoration: BoxDecoration(
    color: backgroundColor ?? Tokens.bgGlass,
    borderRadius: rRect,
    border: border ?? Border.all(color: Tokens.borderHighlight, width: 1),
  ),
  child: child,
);
```

Severity border (D-03): pass `border: Border.all(color: _severityColor(severity), width: 1)` — no new visual system.

**Analog B (l10n message resolution + row layout):** `lib/ui/player/error_banner.dart:31-141`

The card must reproduce the l10nKey → AppLocalizations switch **before deleting** the banner (research "Don't Hand-Roll" #2):

```dart
// error_banner.dart:39-41 — resolve l10nKey, fallback to raw message (D7)
final l10n = AppLocalizations.of(context);
final displayMessage = _resolveMessage(l10n, error);

// error_banner.dart:124-141 — COPY THIS SWITCH into error_card.dart (or a
// shared helper) before MIG-01 deletion; it is the complete key enumeration
String _resolveMessage(AppLocalizations l10n, PlayerError error) {
  return switch (error.l10nKey) {
    'error.file.pathEmpty' => l10n.errorFilePathEmpty,
    // ... all 13 keys ...
    _ => error.message,
  };
}
```

Note D-09 (user decision): the **action-button switch block** (error_banner.dart:44-64) is intentionally NOT carried over — card is display+copy only.

**Card content mapping (CARD-03/D-04)** — all fields from verified contracts (research §Code Examples):
- 折叠: `report.message` + severity color + `report.mediaPath` (basename; NEVER `fullMediaPath` in visible UI)
- 展开: `report.location?.primaryFrame` → `file:line`; `report.location?.sourceLines`; `report.rawStackTrace` (verbatim, `SingleChildScrollView` + `SelectableText`, bounded 16384 chars); log path via `ErrorReporterImpl.I.diagnosticLogPath?.value`; `report.occurrenceCount`
- Interactive elements: `GestureDetector` / `canRequestFocus: false` — NOT `GlassButton` (CARD-01 focus-steal; `GlassButton` uses `FocusableActionDetector` with its own focusNode)

### `lib/ui/player/error_card_host.dart` (component, event-driven)

**Analog:** `lib/ui/shared/osd_overlay.dart:74-140`

OsdOverlay is the in-repo precedent for a StatefulWidget that adds a listener in initState, removes it in dispose, and renders via `ValueListenableBuilder` with an auto-hidden opacity animation:

```dart
// osd_overlay.dart:99-102 — lifecycle discipline to copy
@override
void dispose() {
  widget.resizing?.removeListener(_handleResizeChanged);
  super.dispose();
}

// osd_overlay.dart:116-135 — ValueListenableBuilder + AnimatedOpacity + RepaintBoundary
return ValueListenableBuilder<OsdMessage?>(
  valueListenable: OsdService.I.message,
  builder: (_, msg, _) {
    return IgnorePointer(          // NOTE: OSD is pass-through-everything; the CARD must NOT do this (CARD-02)
      child: AnimatedOpacity(
        opacity: visibleMessage != null ? 1.0 : 0.0,
        duration: _fadeDuration,
        curve: Curves.easeOut,
        child: ... RepaintBoundary(child: _OsdBubble(...)),
      ),
    );
  },
);
```

**Host skeleton (CARD-05 + D-02 + D-11 + D-12)** — composed in research §Pattern 1; key obligations:
1. `initState`: `ErrorReporterImpl.I.presentation.addListener(_onPresentationChanged)` + post-frame `flushPresentation()` (Pitfall 2: without it, `isReady=false` keeps `current==null` forever)
2. `_onPresentationChanged`: if `SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle` apply immediately, else `addPostFrameCallback` and re-read `presentation.value` **inside** the callback (fresh value)
3. `_apply`: severity filter — `warning` → `OsdService.I.show(...)` + one `dismissCurrent()` (no rebuild loop); `error/fatal` → append to bounded local snapshot list (badge cycling, D-11) then set adapter notifier value
4. Close button → `ErrorReporterImpl.I.dismissCurrent()`; badge cycling pages the local snapshot only, never `dismissCurrent()`
5. `ValueListenableBuilder` in build reads the **adapter's own** `ValueNotifier<ErrorPresentationState>`, not `reporter.presentation` (A5 — flag in plan)
6. Wrap subtree in `ExcludeFocus` (CARD-01)

### `lib/ui/player/player_screen.dart` (modify — mount point, D-05/CARD-06)

**Analog:** self, root Stack at `player_screen.dart:249-256`

```dart
// player_screen.dart:249-256 — current inner Stack; card goes here as a
// Positioned(left, top) child AFTER RepaintBoundary(cachedVideoContent):
Expanded(
  child: Stack(
    children: [
      RepaintBoundary(child: cachedVideoContent),
      // NEW:
      // Positioned(
      //   left: Tokens.controlBarMarginH,
      //   top: 12,
      //   child: RepaintBoundary(child: ErrorCardHost(...)),
      // ),
    ],
  ),
),
```

**Anti-trap:** no `Positioned.fill`, no full-size transparent wrapper — intrinsic sizing only (CARD-02 hit-test pass-through). Also note `_buildVideoContent`/`Video.controls` builder (`player_screen.dart:293-317`) is replicated by the media_kit fullscreen route — the card is NOT mounted there (D-05 keeps it in the body Stack; settings/fullscreen coverage accepted, per research Open Question 1 / D-10 note: plan must record a VER-04 fullscreen smoke check).

### `lib/ui/player/player_video_controls.dart` (modify — ErrorBanner removal, MIG-01)

**Analog:** self, the exact subtree to delete at `player_video_controls.dart:882-897`:

```dart
// player_video_controls.dart:882-897 — DELETE this Positioned subtree + the
// 'error_banner.dart' import; host mount moves to player_screen.dart instead.
// ErrorBanner 自己监听 state + lastError，父层不再重复监听。
Positioned(
  left: Tokens.controlBarMarginH + 16,
  right: Tokens.controlBarMarginH + 16,
  bottom: ...,
  child: RepaintBoundary(
    child: ErrorBanner(engine: widget.engine, ...),
  ),
),
```

Precedent for mount position/size: old banner used `Positioned` + `RepaintBoundary` — same two wrappers for the card host, but `left/top` instead of `left/right/bottom`.

### `lib/ui/shared/osd_overlay.dart` consumers (D-02 warning + D-06 copy feedback — reuse, no modification)

**Analog:** `lib/ui/shared/osd_overlay.dart:25-56`

```dart
// osd_overlay.dart:38-49 — the API both call sites use
OsdService.I.show(
  text,                      // l10n-resolved string
  icon: Icons.check,         // copy success / Icons.warning_amber_outlined for warning
  // hold defaults to Tokens.osdDefaultHoldMs — discretion for warning duration
);
```

### Copy with failure isolation (CARD-04, D-06)

**Analog (what NOT to copy verbatim):** `lib/ui/dialogs/media_info_dialog.dart:194` — `Clipboard.setData` without await/catch. The card must improve:

```dart
// Research §Pattern 4 — typed catch, OSD feedback both paths, card unaffected
Future<void> _copyDiagnosticPack(ErrorReport report, String? logPath) async {
  try {
    await Clipboard.setData(
      ClipboardData(text: formatDiagnosticPack(report, logPath: logPath)),
    );
    OsdService.I.show(l10n.copied, icon: Icons.check);
  } on PlatformException catch (e, st) {
    OsdService.I.show(l10n.copyFailed, icon: Icons.error_outline);
    debugPrint('copy failed: $e');   // UI layer may debugPrint
    KernelLogger.I.w('clipboard copy failed', error: e, stackTrace: st);
  } on MissingPluginException catch (e) {
    OsdService.I.show(l10n.copyFailed, icon: Icons.error_outline);
  }
}
```

`formatDiagnosticPack(report, {logPath})` — `lib/kernel/diagnostics/diagnostic_pack_formatter.dart:13`; log path from `ErrorReporterImpl.I.diagnosticLogPath` (`ValueListenable<String?>`, take `.value` at copy time).

### `lib/ui/theme/tokens.dart` (modify — semantic severity colors, D-03)

**Analog:** `Tokens.danger` at `tokens.dart:18`:

```dart
// tokens.dart:18 — the only existing semantic danger token; no warning/fatal
// token exists. Add Tokens.warning (amber) next to it; fatal = deepened danger.
static const danger = Color.fromARGB(255, 250, 55, 55);
```

### `test/widget/player/error_banner_equivalence_test.dart` (MIG-01)

**Analog:** `test/diagnostics/player_error_report_bridge_test.dart:12-191` — this is the exact wiring template: `_BridgeFixture` grouping FakeEngine + bridge + reporter, dispose in dependency order, `flushPresentation()` before asserting presentation.

```dart
// bridge test:184-191 — deterministic reporter construction to copy
ErrorReporterImpl _reporter() {
  return ErrorReporterImpl.forTesting(
    clock: FakeClock(DateTime.utc(2026, 8, 28)),
    eventIdGenerator: () => 'bridge-${++sequence}',
    currentMediaPath: () => null,
  );
}

// bridge test:22-35 — equivalence assertion shape: drive an engine open
// failure through the real bridge, flush, then assert presentation
fixture.reporter.flushPresentation();
expect(fixture.reporter.presentation.value.current, same(report));
```

Equivalence per D-07/D-09: assert **message + severity visibility** on the card for the same engine error the banner covered (see l10n assertion set below). Do NOT assert action buttons.

**Analog:** `test/widget/player/error_banner_test.dart:20-57` — the widget harness + l10n assertion baseline to reproduce (minus buttons):

```dart
// error_banner_test.dart:20-32 — buildSubject harness with real delegates
Widget buildSubject({...}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ErrorBanner(...)),
  );
}

// error_banner_test.dart:48-57 — l10nKey assertion style to replicate per subtype
engine.simulateError('raw message ignored by l10nKey');
expect(find.text('An unexpected error occurred'), findsOneWidget);
```

**Analog:** `test/diagnostics/player_error_report_bridge_test.dart:160-182` — `_RecordingReporter implements ErrorReporter` shows the full `ErrorReporter` interface (6 methods) for hand-written fakes (fakes-over-mocks rule).

## Shared Patterns

### ValueNotifier + ValueListenableBuilder (D-08, CARD-06)
**Source:** `lib/ui/shared/osd_overlay.dart:116`, `lib/ui/player/error_banner.dart:31`
**Apply to:** error_card.dart, error_card_host.dart — no new state library; single-source notifiers, no duplicate state.

### Lifecycle listener discipline
**Source:** `lib/ui/shared/osd_overlay.dart:78-102`
**Apply to:** error_card_host.dart — addListener in initState, removeListener in dispose, `mounted` check before setState from async/post-frame callbacks.

### Tokens-only visual values + GlassContainer surface
**Source:** `lib/ui/shared/glass_container.dart:98-106`, `lib/ui/theme/tokens.dart:18`
**Apply to:** error_card.dart — zero hardcoded colors/fonts/spacing; pass `resizing` through.

### l10n: bilingual doc comments, l10nKey switch, ARB regeneration
**Source:** `lib/ui/player/error_banner.dart:120-141`, `test/widget/player/error_banner_test.dart:21-23`
**Apply to:** error_card.dart + new ARB keys (`copied`, `copyFailed`, card section labels) — must run `flutter gen-l10n`; generated `app_localizations_*.dart` are committed.

### Test setup convention (diagnostics singletons)
**Source:** project memory + `test/diagnostics/player_error_report_bridge_test.dart:184-191`
**Apply to:** all three new test files — `KernelLoggerImpl.resetForTesting()` + `init()` in `setUpAll`; `ErrorReporterImpl.forTesting(clock:/eventIdGenerator:)` for determinism; `addTearDown` dispose in dependency order; NEVER construct `MediaKitEngine`/media_kit `Player` (use `test/helpers/fake_engine.dart` — headless mdk.dll FFI failures are pre-existing).

### Typed catch + KernelLogger in kernel, debugPrint allowed in UI
**Source:** project rule; `media_info_dialog.dart:194` counter-example
**Apply to:** copy handler (typed `on PlatformException` / `on MissingPluginException`); no bare catch; no `Error` subtypes caught.

## No Analog Found

| File | Role | Data Flow | Reason | Fallback |
|------|------|-----------|--------|----------|
| ErrorCardHost phase-guard adapter (CARD-05) | component | event-driven | No in-repo precedent for `SchedulerBinding.schedulerPhase` + post-frame deferral | Use research §Pattern 1 skeleton verbatim; test with `tester.pump` |
| Badge local-snapshot cycling (D-11) | component | event-driven | No multi-error cycling UI exists | Research §Code Examples severity-routing `_history.add(report)` sketch |

## Metadata

**Analog search scope:** `lib/ui/player/`, `lib/ui/shared/`, `lib/ui/theme/`, `lib/kernel/diagnostics/`, `test/widget/player/`, `test/diagnostics/`
**Files read:** error_banner.dart, osd_overlay.dart, glass_container.dart (partial), player_screen.dart (partial), player_video_controls.dart (partial), error_banner_test.dart, player_error_report_bridge_test.dart
**Git-tracked verification:** all 7 named analog paths pass `git ls-files`
**Pattern extraction date:** 2026-08-30
