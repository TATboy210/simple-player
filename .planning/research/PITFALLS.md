# Pitfalls Research

**Domain:** Flutter Windows desktop global error capture, local error logging, and non-modal in-app diagnostic cards
**Researched:** 2026-08-28
**Confidence:** MEDIUM — primary Flutter/Dart documentation establishes the capture, zone, widget-error, and Windows I/O behaviors. The exact release-symbol workflow depends on this app's chosen build flags and must be verified in the implementation phase.

## Critical Pitfalls

### Pitfall 1: Treating `runZonedGuarded` as a universal safety net

**What goes wrong:**
The application installs only `runZonedGuarded`, assumes every exception will reach its handler, and misses framework errors or platform-dispatcher errors. Conversely, wrapping only a later startup fragment creates a second error zone: a `Future` which completes with an error in that zone cannot propagate its error to consumers in a different error zone and can appear never to complete. This produces mysterious stalled startup or logger initialization rather than a visible exception.

**Why it happens:**
The three hooks cover different routes, not three interchangeable spellings of the same hook. Flutter framework callback failures (build/layout/paint) arrive through `FlutterError.onError`; uncaught asynchronous failures without a Flutter callback on the stack arrive through `PlatformDispatcher.instance.onError`; `runZonedGuarded` handles uncaught synchronous/asynchronous work created in its guarded error zone. Dart deliberately prevents asynchronous errors from crossing error-zone boundaries.

**How to avoid:**
- Install all three routes, but make all of them call one small, non-throwing `ErrorReporter.report(...)` boundary. Preserve `FlutterError.presentError(details)` in the framework handler so debug-console diagnostics remain available.
- Return `true` from `PlatformDispatcher.instance.onError` only after the reporter has accepted the event; this declares that the error was handled.
- Prefer no zone unless it is needed for the startup-period catch-all. If it is retained, put `WidgetsFlutterBinding.ensureInitialized()`, diagnostics initialization, hook installation, and `runApp()` inside the *same* `runZonedGuarded` closure. Do not create nested guarded zones around individual services and do not pass `Future`s that may error across zone boundaries.
- Keep ordinary application `await`/`try`/`catch` ownership intact. A zone is a last-resort observer, not a substitute for handling a known failing operation at its boundary. For `Stream`/`async*` work, provide `onError` to subscriptions or handle errors in the producer; do not rely solely on a zone after a stream has crossed an ownership boundary.
- Do not install a custom `ZoneSpecification.handleUncaughtError` in addition to `runZonedGuarded` unless a concrete need is documented. The guarded constructor deliberately wires its own handler; extra zone specifications make reporting order and duplicate events harder to reason about.

**Warning signs:**
- `PlatformDispatcher.onError` tests pass but a deliberately thrown build exception creates no card, or vice versa.
- A `Future` started during startup never completes after moving only `runApp()` into `runZonedGuarded`.
- The same exception is shown twice (for example by a zone handler and a dispatcher handler), or debug console output disappears after installing hooks.
- A test awaits a `Future` created inside a guarded zone from outside that zone and times out.

**Phase to address:**
**Phase 1 — diagnostic model and global-hook foundation.** Define a single normalized report type, hook ownership, deduplication identity, and automated probes for each of the four promised sources (framework, uncaught async, engine, startup). Add the zone-boundary regression test before UI or file logging.

---

### Pitfall 2: Initializing Flutter bindings in one zone and calling `runApp` in another

**What goes wrong:**
A conventional-looking startup sequence calls `WidgetsFlutterBinding.ensureInitialized()` in the root zone, then calls `runApp()` inside `runZonedGuarded`. Flutter 3.10+ emits a debug-only “Zone mismatch” diagnostic; more importantly, framework callbacks can execute under zone values different from initialization and cause unrelated, intermittent behavior.

**Why it happens:**
Many older error-capture snippets initialize the binding before adding a guarded zone. `runZonedGuarded` itself is **not deprecated**. The common deprecation confusion is with `runZoned`'s old `onError` argument, not the guarded API. The real requirement is one zone for Flutter binding initialization and framework execution.

**How to avoid:**
- If a guarded zone remains in the design, make its closure own the complete Flutter startup path, including binding initialization and `runApp`.
- During debug/test startup, set `BindingBase.debugZoneErrorsAreFatal = true` as the first statement before binding initialization, then run a startup smoke test. This makes accidental future drift fail immediately instead of becoming a console warning.
- Do not use zone values for mutable application state or reporter configuration. Construct and inject normal objects instead; zone values behave as implicit globals and make tests less deterministic.

**Warning signs:**
- The debug console prints “The Flutter bindings were initialized in a different zone than is now being used.”
- Diagnostics depend on a `Zone.current[...]` value, and callbacks see missing/default values.
- A refactor that moves only `runApp` causes test-only or keyboard-callback behavior to change.

**Phase to address:**
**Phase 1 — global-hook foundation.** Make zone consistency a startup acceptance criterion, not an after-the-fact cleanup.

---

### Pitfall 3: The reporter or card throws while reporting an error (recursive failure storm)

**What goes wrong:**
A framework error enters `FlutterError.onError`; the handler reads a missing source file, formats an unexpected stack, writes a denied log path, or updates UI state and itself throws. Flutter does not catch an exception thrown by a custom `FlutterError.onError` handler. A more severe loop is: an error triggers a card; the card's build/formatting/theme/localization/clipboard code throws; the global handler reports that new failure; each report attempts to build the same card again.

**Why it happens:**
Error UI is treated as ordinary feature UI even though it runs precisely when application state may be inconsistent. Developers also put I/O, source lookup, asynchronous work, or UI mutation directly in a global hook because it is convenient.

**How to avoid:**
- Make the capture boundary deliberately boring: normalize primitive fields, enqueue the immutable report, and never let a reporting exception escape. Use a private reentrancy guard that suppresses secondary reporter failures and sends a minimal `debugPrint` fallback rather than recursively reporting them.
- Keep UI presentation separate from capture. The reporter emits an immutable `ValueNotifier` state; the root overlay observes it. The card must tolerate absent media path, absent stack, unknown file/line, unreadable source, unavailable clipboard, and disposed app state.
- Use a minimal `ErrorWidget.builder` fallback only for the widget that failed to build. It must be a self-contained, no-I/O, no-state-write fallback. Do not use it to install the normal error card, report an event, navigate, read settings, or look up inherited dependencies.
- Wrap external side effects independently: file append failure must disable only the file sink; clipboard failure must show a local, non-reporting feedback state; source lookup failure must result in “source unavailable.”
- Add a bounded recursion/deduplication policy: fingerprint error type + message + normalized top frames; suppress identical events inside a short window while maintaining a suppressed-count indicator in the card/log entry.

**Warning signs:**
- Repeated identical records appear with increasing timestamps, CPU rises, or the process produces an ever-growing log after a single error.
- The displayed exception changes from the original business error to `setState() or markNeedsBuild() called during build`, layout exceptions, a file-system exception, or a card-specific null error.
- Triggering an exception in a card formatter, source reader, or file sink crashes the application or produces more than one card.
- The reporter's own error is attributed to `FlutterError.onError` rather than kept as a one-line fallback diagnostic.

**Phase to address:**
**Phase 1 — reporter core** must implement reentrancy isolation and normalization. **Phase 3 — error-card UI** must include failure-injection tests for source lookup, formatting, copy, and card-build fallback. **Phase 4 — file sink** must be independently failure-contained.

---

### Pitfall 4: Calling `notifyListeners` while Flutter is building the failed subtree

**What goes wrong:**
A build error synchronously updates the `ValueNotifier` that drives the root error-card overlay. A listening widget is already in the build pass, so the update triggers `setState()`/`markNeedsBuild()` during build. The capture system converts a recoverable original error into a second framework error and can enter the recursive loop above.

**Why it happens:**
`FlutterError.onError` and `ErrorWidget.builder` often execute while Flutter is processing the build/layout/paint pipeline. `ValueNotifier.value = ...` synchronously notifies `ValueListenableBuilder`s; it is not intrinsically safe just because the notifier is global.

**How to avoid:**
- Record and persist the report synchronously without notifying UI listeners during a build-time callback.
- If the card must become visible, coalesce publication through `WidgetsBinding.instance.addPostFrameCallback`, guarded by a pending-publication flag. At the callback, check that the reporter is still alive and publish one immutable snapshot. Do not delay durable error capture merely to delay the UI.
- Place the normal card overlay above the app shell/root `Stack`, not inside the potentially failing page subtree. The overlay's data model should be able to accept a report before `runApp`/first frame and publish it after the UI becomes available.
- Write widget tests that deliberately throw from a child build and assert: one captured report, no “during build” error, and a functional close button after the next frame.

**Warning signs:**
- The first card shown after a build failure contains a `markNeedsBuild` error rather than the original error.
- Tests intermittently fail depending on whether they `pump()` once or twice.
- A ValueNotifier update occurs from `FlutterError.onError`, `ErrorWidget.builder`, or a build method without post-frame scheduling.

**Phase to address:**
**Phase 3 — non-modal error-card integration.** The phase is incomplete without a build-time failure test and frame-deferred publication contract.

---

### Pitfall 5: Promising source-line precision in release without a graceful fallback

**What goes wrong:**
The card assumes every `StackTrace` contains a local `file:line`, calls `File(path).readAsLines()`, and crashes or shows a misleading path in release. Installed desktop builds usually do not contain `lib/` source files. If the release pipeline uses obfuscation and/or `--split-debug-info`, human-readable Dart method/file/line locations depend on retaining the matching per-build debug-information artifacts. A stack that references tree-shaken code is not the main problem: removed code cannot produce a live runtime frame; unreadable locations stem from compilation/symbol information and source availability, not ordinary asset/icon tree shaking.

**Why it happens:**
Debug mode provides local source checkout paths and rich frames, so source lookup appears reliable. The project requirement asks for source lines, which can be misread as a production guarantee rather than best-effort developer tooling.

**How to avoid:**
- Model location enrichment as best effort with explicit states: parsed location, source line available, source unavailable, stack unavailable/unparseable. Never report a guessed line as authoritative.
- Parse conservatively and keep the raw stack in the log. Do not make a single frame format mandatory; native/plugin frames and optimized AOT traces may not match Dart source-frame syntax.
- Only read a source file after strict validation: it must be a local absolute path, exist, be a regular file, and have a positive bounded line number. Catch `FileSystemException`, decoding errors, and line-range failures. Never accept a path from external error text as a command or as an unrestricted file-read instruction.
- For developer-distributed release builds that use `--obfuscate`/`--split-debug-info`, archive the exact build's symbol/debug-info directory alongside the artifact and record the app version/build identifier in every log. This milestone excludes remote symbolication, so the UI should clearly downgrade rather than imply automatic recovery.
- Test release/profile behavior or an equivalent injected “source unavailable” adapter; do not use only debug widget tests as evidence.

**Warning signs:**
- Error-card rendering calls `File.readAsLines` without a `try`/fallback.
- An installed release card exposes local build-machine paths that do not exist on the user machine.
- Obfuscated/split-debug builds produce frames without expected file/line text and the UI becomes blank, throws, or labels it “unknown bug.”
- The build process deletes debug artifacts immediately, making an archived log impossible to interpret later.

**Phase to address:**
**Phase 2 — report enrichment and release fallback.** Establish a testable `SourceContextResolver` boundary before card detail rendering. **Release verification phase** must document the actual Windows build flags and artifact-retention decision.

---

### Pitfall 6: Concurrent or fragile Windows log writes turn logging into a new outage

**What goes wrong:**
Every hook opens and appends to the same text file independently. A burst of playback errors interleaves records, an old writer remains open during application close, or an external viewer/second instance causes sharing/lock failures. On Windows, a `RandomAccessFile` lock belongs to the particular handle that acquired it; writing through another handle—even in the same process—can fail. If log I/O exceptions escape a global handler, the app enters the reporting recursion loop.

**Why it happens:**
A one-line `writeAsString(..., mode: FileMode.append)` is correct for a single awaited write but does not provide queue ordering across concurrent fire-and-forget calls. Developers also assume `IOSink.flush()` means data is physically durable; it only guarantees acceptance by the underlying `StreamConsumer`, not necessarily an OS disk flush.

**How to avoid:**
- Make `FileSink` one owner of one serialized write queue. Every report submits a preformatted immutable line/event; no hook independently opens the same file. Await queue operations internally and explicitly use `unawaited` only at the caller boundary after the sink has captured failures.
- Use application-support storage as the default app-managed location, validate configured paths at the settings boundary, create the parent directory once, and use a fixed explicit UTF-8 encoding. Use `Platform.lineTerminator` if Windows-native CRLF is a desired human-readable convention; Dart does not translate `\n` automatically.
- For this single-process personal player, do **not** add file locks merely by default. A single in-process queue avoids the problem. If supporting multiple processes later, lock/write/flush/unlock/close through the exact same `RandomAccessFile` handle and matching locked range on Windows.
- Catch `FileSystemException` and failures from write, flush, and close. Mark the sink temporarily unavailable, emit a rate-limited `debugPrint`, preserve in-memory/card reporting, and retry only on the next eligible event or configuration change. Never report a file-sink failure back through the same failing file sink.
- On orderly app shutdown, stop accepting new writes, await the queue, and close the writer with a bounded timeout. An OS kill, power loss, or crash cannot be fully solved by shutdown flushing; make this limitation explicit.
- Scope note: the milestone deliberately excludes rotation. Therefore do not silently add rotation, but still surface append failure/disk-full behavior and ensure one pathological failure cannot generate unbounded new writes.

**Warning signs:**
- “The process cannot access the file”/access denied errors during error bursts or close.
- Adjacent error records are concatenated, partially written, or out of order.
- The app hangs on exit while waiting on an unresolved write/flush future.
- Disk-full, read-only directory, invalid configured path, or removed log directory makes the card/reporting path throw.
- Code opens a `RandomAccessFile`, locks it, then uses `File.writeAsString` or another handle to write.

**Phase to address:**
**Phase 4 — durable file sink and settings path.** Include Windows-specific queue, permission-denied, directory-removed, disk-full/flush-failure simulation, and app-close drain tests before connecting it to global hooks.

---

### Pitfall 7: A “non-modal” card steals focus or blocks player controls

**What goes wrong:**
The card is placed in a full-screen `Stack` layer that absorbs pointer events outside the card, uses a modal barrier, invokes focus/autofocus, or sits over the title bar/control bar. A video user cannot seek, drag the frameless window, use keyboard shortcuts, or operate playback until closing a diagnostic card—contradicting the stated non-modal requirement.

**Why it happens:**
Overlay implementations often reuse dialog/snackbar patterns. A `Positioned.fill`, `GestureDetector`, `ModalBarrier`, `FocusScope`, or fullscreen `Material` can accidentally win hit testing even when visually transparent.

**How to avoid:**
- Mount only the card's bounded hit-test region at the top-left and keep the rest of the overlay `IgnorePointer(ignoring: true)` (or absent). Do not use a barrier, route push, autofocus, or focus request for an arriving error.
- Define exclusion/inset rules from existing title-bar and controls layout before choosing the card position. Verify at minimum: window drag region/title-bar buttons, video surface seek interactions, control bar, playlist toggle, keyboard media shortcuts, and ESC behavior remain functional while a card is visible.
- The close/copy controls must be keyboard-accessible only when the user intentionally tabs into the card; automatic arrival must not change the current focus or interrupt fullscreen playback.
- Keep cards persistent by user decision as required, but cap the visible queue (for example current card plus count) rather than stacking a hundred interactive cards.

**Warning signs:**
- A transparent overlay has `Positioned.fill`, `GestureDetector`, `AbsorbPointer`, `ModalBarrier`, or an automatically focused button/text field.
- After an injected error, Space/arrow media shortcuts or title-bar drag stop working.
- Screenshot looks correct but pointer hit tests show the overlay receiving clicks outside card bounds.

**Phase to address:**
**Phase 3 — card UI integration.** Add widget/integration tests for hit testing and focus preservation alongside visual tests; manual Windows smoke testing is required for frameless drag behavior.

---

### Pitfall 8: Error flooding overwhelms UI, logs, and the event loop

**What goes wrong:**
A repeated engine callback, failed periodic timer, or render exception emits hundreds of near-identical reports per second. The app creates a card per report, schedules a frame per update, repeatedly reads source files, and appends each event. The diagnostics system then causes jank, a giant log, and potentially fills the disk while hiding the original signal.

**Why it happens:**
Global hooks see symptoms, not necessarily root causes. A persistent engine error can recur on every event tick; a faulty widget can throw on every rebuild. “Capture every error” is incorrectly implemented as “perform every expensive enrichment and presentation action for every occurrence.”

**How to avoid:**
- Make capture cheap and bounded. Create a stable fingerprint from error type/message plus normalized top stack frames; deduplicate equivalent reports over a short monotonic-time window.
- Retain the first full report, increment a suppressed-occurrence count, and publish/log a bounded summary at a controlled interval. Different fingerprints must still be retained so deduplication does not erase new failures.
- Bound the in-memory card queue and source-enrichment work. One visible latest card plus an error count/history summary is appropriate for this personal diagnostics UI; do not create an unbounded widget list.
- Use a reentrancy flag separate from deduplication: recursion prevention protects correctness, while fingerprint throttling protects performance and disk use.
- Test with a synthetic 100–1,000 identical-event burst and assert stable queue size, bounded log writes, no uncaught reporter error, and playback controls remain responsive.

**Warning signs:**
- Frame time/jank begins exactly when the same error repeats.
- Log size grows linearly at a high rate, the card counter grows without bound, or source reading occurs repeatedly for the same frame.
- The error reporter itself becomes a top contributor in a performance trace.

**Phase to address:**
**Phase 1 — reporter core** defines fingerprint and bounded-buffer semantics. **Phase 4 — file sink** enforces write coalescing. **Phase 5 — integration hardening** runs burst/performance verification with a simulated repeating engine error.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Only install `runZonedGuarded` | Very little startup code | Framework and platform routes remain incomplete; zone-boundary stalls are hard to diagnose | Never for the promised four-source capture scope |
| Report, enrich source, notify UI, and append a file directly inside a hook | One function appears to do everything | Reentrancy, build-time notification failures, slow global handler, no isolated tests | Never |
| Assume every stack has a local Dart `file:line` | Fast debug-only demo | Release card crashes/misleads and can read arbitrary paths | Only in a test-only formatter, never production |
| Fire-and-forget `File.writeAsString` on every error | Minimal FileSink implementation | Record reordering, unhandled I/O futures, exit loss, flood amplification | Only for a short prototype not wired to global hooks |
| Add a modal dialog or route for every exception | Easy visible proof of capture | Breaks media playback/keyboard/frameless interaction and causes focus theft | Never; this milestone explicitly requires non-modal behavior |
| Implement unlimited in-memory error history | No policy required | Memory/UI/log work grows forever during repeated faults | Never; use bounded current/history state |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `FlutterError.onError` | Replace the handler and omit `FlutterError.presentError`; let reporter failures escape | Present original details, then invoke an exception-safe reporter with a reentrancy guard |
| `PlatformDispatcher.instance.onError` | Return `false` after accepting an error, or expect it to receive framework callback failures | Normalize and enqueue the report, then return `true`; retain `FlutterError.onError` for framework routes |
| `runZonedGuarded` + Flutter binding | Initialize binding outside zone and run app inside it | Put binding initialization and `runApp` in the same guarded closure, or omit the zone |
| `ErrorWidget.builder` | Put the normal card, notifier updates, I/O, localization, or report logic in the fallback builder | Return only a dependency-light static fallback; report/publish elsewhere |
| `ValueNotifier` card state | Assign `value` synchronously in a build-time error path | Capture immediately, publish a coalesced immutable state after the current frame |
| `media_kit` engine errors | Treat a recurring engine error callback as a unique event every time | Normalize engine context/media path and dedupe before UI/file work; do not modify media_kit |
| Configurable Windows log path | Trust user-provided path or use process current directory/executable directory | Validate at the settings boundary; default to app-support storage; catch path/permission failures |
| Windows file locks | Lock one handle then append using another | Prefer one serial writer; if locking is necessary, perform lock/write/flush/unlock through the same handle |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Per-event source-file reads and stack parsing | UI jank and repeated disk reads when one error loops | Parse/enrich once per fingerprint and cache bounded results; source lookup is best effort | A repeated build/engine fault, potentially tens to hundreds of events per second |
| One notification/card per report | Rebuild storm, enormous card list, controls become unresponsive | Coalesce post-frame publication; bounded current card/history and duplicate counter | Immediately during a recurring timer/render error |
| Open/close/flush a file for uncontrolled concurrent writes | Reordered lines, I/O failures, slow shutdown | Single serialized writer and controlled flush/close lifecycle | First overlapping async report or app close under an I/O stall |
| Synchronous durable flush on every repeated error | Media playback stutters during log flood | Coalesce/dedupe errors; use bounded orderly shutdown drain rather than per-event expensive work | Any sustained recurring error on a slower disk |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Displaying or logging media paths without considering shared screenshots/logs | Personal directory names and filenames are exposed when logs/cards are shared | Keep full local detail for the developer-focused tool, but label logs as sensitive and provide a future redaction boundary; never upload remotely in this milestone |
| Reading a source path parsed from untrusted/plugin error text without validation | Diagnostic feature becomes an arbitrary local-file reader and can expose content in UI/logs | Accept only validated local regular-file paths and bounded line reads; on any doubt show “source unavailable” |
| Trusting settings-provided output paths blindly | Writes outside expected location, repeated permission failures, accidental overwrite semantics | Validate and normalize configuration, create only intended directories, append only, and surface local non-fatal path errors |
| Logging every error payload verbatim without bounds | Sensitive media paths and huge plugin payloads fill disk or make logs unsafe to share | Bound individual fields/stack size, preserve necessary context, and mark truncation explicitly |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Full-window transparent overlay intercepts input | Cannot seek/play, drag frameless window, or reach title controls | Only the card bounds receive pointers; outside region is ignored by the overlay |
| Automatic focus/autofocus on incoming card | Keyboard shortcuts suddenly operate card controls instead of player | Preserve existing focus; make card controls reachable by deliberate keyboard navigation only |
| A card per repeated error | Screen becomes a stack of diagnostics, original problem is obscured | One current card plus count/summary/history with fingerprint deduplication |
| Card assumes a source line is always available | Release display looks broken or blames incorrect file | Show file/line/source only when independently available; use clear unavailable text otherwise |
| Closing card disables capture or file logging | User loses diagnostics by hiding a visual nuisance | The settings card toggle affects presentation only; capture and error-file append remain active |

## "Looks Done But Isn't" Checklist

- [ ] **Four-route capture:** Deliberately trigger one framework/build error, one uncaught future/platform-dispatcher error, one startup error, and one normalized `PlayerError`; verify exactly one normalized report for each expected route.
- [ ] **Zone startup:** Run debug startup with `BindingBase.debugZoneErrorsAreFatal = true`; no zone mismatch is emitted, and no startup future crosses an error-zone boundary.
- [ ] **Reporter failure isolation:** Make formatter, source resolver, clipboard, directory creation, append, flush, and close fail independently; verify original reporting/card capture survives and no recursive exception storm occurs.
- [ ] **Build safety:** Throw from a child build; verify no `setState`/`markNeedsBuild`-during-build error and that the normal card appears only after the frame boundary.
- [ ] **Release fallback:** Run profile/release-equivalent test with no source checkout/file available and with unparseable/native frames; verify useful raw stack/location fallback, not a second error.
- [ ] **Windows file behavior:** Validate configured path, UTF-8 append ordering, permission-denied/removed-directory/full-disk handling, and bounded shutdown drain without hangs.
- [ ] **Non-modal interaction:** With a persistent card visible, verify title-bar drag/window buttons, seek/control bar, playlist access, Space/arrows/media keys, fullscreen, ESC, and close/copy behavior.
- [ ] **Flood control:** Inject a high-rate duplicate engine error; verify bounded queue, rate-limited log work, duplicate count, and responsive video controls.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Zone mismatch / lost startup error | MEDIUM | Move binding setup and `runApp` into one zone (or remove zone), enable fatal debug diagnostic, add route-specific tests |
| Reporter/card recursion | MEDIUM | Disable card publication temporarily, keep minimal console fallback, add reentrancy guard and isolate each side effect before re-enabling UI |
| `notifyListeners` during build | LOW | Move visual publication to guarded post-frame callback; keep capture/file enqueue synchronous and test the original failing build |
| Release source lookup failure | LOW | Stop treating source lookup as required; retain raw stack and app build ID, use “source unavailable,” archive symbols if relevant |
| Windows file sink outage | MEDIUM | Disable only file sink, retain in-memory/card/console route, show log-path issue locally, retry after path/config change; do not recursively log the failure |
| Error flood | MEDIUM | Activate duplicate suppression and bounded queue, retain first full occurrence plus counts, identify/fix root source separately |
| Overlay blocks playback | LOW | Remove fullscreen hit-test layer/focus request, constrain interactive bounds, add widget and manual Windows regression tests |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Incomplete/error-zone-loss capture | Phase 1 — diagnostic model and global hooks | Four source-specific injection tests; zone-crossing future regression test |
| Binding/runApp zone mismatch | Phase 1 — startup hook installation | Fatal debug-zone-errors startup smoke test |
| Reporter/card recursive failure | Phase 1 core, Phase 3 UI, Phase 4 sink | Fault-inject each reporter dependency and assert one primary report/no uncaught secondary reporter error |
| Notifier update during build | Phase 3 — card integration | Throw from child build, pump frame, assert original error/card and no `markNeedsBuild` exception |
| Release source/symbol assumptions | Phase 2 — enrichment/release fallback | Missing-source and unparseable-stack tests; documented build-artifact policy |
| Windows append/lock/shutdown/disk failure | Phase 4 — FileSink and settings | Serialized-write, denied-path, removed-directory, flush/close, and exit-drain tests on Windows |
| Focus/input interception | Phase 3 — card integration | Widget hit-test/focus tests plus manual frameless Windows control smoke test |
| Error flood and repeated engine events | Phase 1 policy, Phase 5 hardening | Synthetic burst verifies bounded state, log coalescing, and responsive controls |

## Sources

Confidence values are produced by the research confidence classifier: Context7 documentation results are **MEDIUM**; the web-research routing itself is **LOW**, though the following primary documents were directly cross-checked and underpin the findings.

- [Flutter: Handling errors in Flutter](https://docs.flutter.dev/testing/errors) — framework vs. platform-dispatcher routes, custom handler guidance, and `ErrorWidget.builder` behavior. **MEDIUM**
- [Flutter: Zone mismatch breaking change](https://docs.flutter.dev/release/breaking-changes/zone-errors) — Flutter 3.10 zone consistency requirement and debug fatal diagnostic. **MEDIUM**
- [Dart: Zones — handling uncaught errors](https://dart.dev/libraries/async/zones) — error-zone containment and asynchronous Future boundary behavior. **MEDIUM**
- [Dart API: `runZonedGuarded`](https://api.dart.dev/dart-async/runZonedGuarded.html) — guarded-zone API semantics and error handler behavior. **MEDIUM**
- [Flutter API: `FlutterError.onError`](https://api.flutter.dev/flutter/foundation/FlutterError/onError.html) — handler failure caveat and default presentation behavior. **MEDIUM**
- [Flutter API: `ErrorWidget.builder`](https://api.flutter.dev/flutter/widgets/ErrorWidget/builder.html) — build-error fallback lifecycle. **MEDIUM**
- [Flutter: Common errors — setState/markNeedsBuild during build](https://docs.flutter.dev/testing/common-errors) — build-time state mutation failure mode. **MEDIUM**
- [Dart API: `File.writeAsString`](https://api.dart.dev/dart-io/File/writeAsString.html) and [FileMode](https://api.dart.dev/dart-io/FileMode-class.html) — append, UTF-8 default, flush, and newline semantics. **MEDIUM**
- [Dart API: `RandomAccessFile.lock`](https://api.dart.dev/dart-io/RandomAccessFile/lock.html) — Windows handle-specific locking requirements. **MEDIUM**
- [Dart API: `IOSink.flush`](https://api.dart.dev/dart-io/IOSink/flush.html) — flush limitation and close implications. **MEDIUM**
- [Flutter file persistence cookbook](https://docs.flutter.dev/cookbook/persistence/reading-writing-files) — application-managed storage with `path_provider`. **MEDIUM**
- [Sentry Flutter debug symbols](https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/) — corroborating explanation of split-debug-info/obfuscation symbol artifacts. **LOW; validate against the selected Windows build command before relying on it.**

---
*Pitfalls research for: Simple Player Flutter error capture, local diagnostics, and non-modal error-card system*
*Researched: 2026-08-28*
