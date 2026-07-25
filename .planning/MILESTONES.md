# Milestones

## v4.0 设置面板框架重构 (Shipped: 2026-07-25)

**Phases completed:** 14 phases, 44 plans, 68 tasks

**Key accomplishments:**

- Reproducible bash+ripgrep baseline audit scripts replacing the stale "121 call sites/30 files" logger figure with a live-verified 84/28, plus a dynamic 7-interface contract-completeness checker and stale-map watermarking.
- Task 1 — EngineStateView group contract + MediaEngine ISP-count fix (commit `bbec3e9`)
- 7 parameterized ISP contract test suites (57 tests) frozen against the real FvpEngine, including an un-skippable structural regression gate for the open()→play() handoff
- Task 1 — KernelLogger + NullKernelLogger
- `lib/kernel/player_services.dart`
- 7 Phase-15 ISP contract groups re-mounted against KernelAdapter via factory swap, a 13-field same() notifier-identity gate, and DiagnosticsBundle/KernelLogger unit tests — all green with zero changes to production code
- Task 1 — `tool/audit/phase16_gates.sh`
- Concrete KernelLogger facade with kDebugMode-gated DevTools+debugPrint sinks, wired into PlayerServices composition root
- Batch-migrated 24 kernel files from old log.dart to new KernelLogger with zero call site changes, plus CI grep gate script
- Extended kernel_logger_test.dart with 9 behavioral test groups covering all sink types, KernelLoggerImpl lifecycle, and direct redactPath() path redaction testing
- Extended sealed PlayerError with ErrorContext, isFatal/l10nKey accessors, recoverable enum markers, and 13 error l10n keys for UI translation
- End-to-end error propagation chain from engine catch points through service layer, with structured ErrorContext at every point and mdk callback thread marshalling
- ErrorBanner switched from raw error.message to l10nKey → AppLocalizations lookup, decoupling sealed PlayerError internals from UI display text with graceful fallback
- Instance-based MemoryMonitor with RssProvider/Clock injection, 18 passing tests, zero playback interference
- Static MemoryMonitor singleton removed, instance wired into DiagnosticsBundle via PlayerServices, all call sites migrated in one atomic commit
- EngineStateMachine rewritten with LifecyclePhase orthogonal state, embedded OpenGenerationTracker, TransitionResult 3-value return type, recover() method, and KernelLogger.warn for illegal transitions
- FvpEngine gains DiagnosticsBundle injection, generation tracking unified in state machine, PlaybackNavigator delegates generation to state machine, KernelAdapter gains per-method DelegationPolicy
- Switched FvpCallbackHandler from SchedulerBinding.addPostFrameCallback to scheduleMicrotask for uniform callback marshalling, and added 8 race condition tests validating generation guard correctness under rapid-fire scenarios
- Phase 17-02 migration (commit `204bedf`) changed 24 kernel files from `log.dart` to `kernel_logger.dart`, referencing `KernelLogger.I`. However, the `I` static getter only existed on `KernelLoggerImpl`, not the abstract `KernelLogger` class.
- `3bdea62`
- 4-item adapter deletion gate script, emergency rollback with --dry-run, release build debugPrint scanner, and adapter test cleanup preserving contract tests
- 21-05 (VERIFY-03)
- phase21_gates.sh results: 4/4 PASS
- 1. [Rule 1 - Bug] Fixed AudioTrackInfo constructor parameters
- 1. [Rule 1 - Bug] KernelLoggerImpl init required for test compatibility
- mdk.Player dependency injection via MdkPlayerLike interface, unlocking 54 pure Dart test cases for engine open/media paths without mdk.dll
- Flutter 3.44.6 `star_border.dart` imports `package:vector_math/vector_math_64.dart` but the per-package `.dart_tool/package_config.json` was missing.
- Deep test expansion for kernel_logger (100%), memory_monitor (100%), window_service, log, perf_monitor, position_poller, display_enumerator, player_services, clock, engine_metrics, engine_event_log -- 132 new test cases, kernel/ coverage 57.6% -> 69.5%
- Audit confirmed all 12 v3.0 kernel files already have bilingual (Chinese intent + English contract) doc comments on every public symbol — no source modifications needed
- SettingsPanelState (3 ValueNotifiers) + SettingsPanelController (open/close/toggle with wasPlaying pause/resume) built on a new SettingsPanelPlayback narrow-interface boundary added to PlaybackController, via strict TDD RED→GREEN.
- In-tree glass overlay shell with mask/close/ESC/B lifecycle, title-bar drag clamping, responsive 500x400-or-80% sizing, wired through PlayerFeature composition root replacing the old showDialog path.
- 1. [Rule 3 - Blocking] Undersized window overflow from button bar height
- 1. [Rule 1 - Bug] Column overflow in AnimatedSectionList
- Continuous panel sizing (clamp 400-600, 5:4 ratio), 800px breakpoint tab bar adaptation, and RepaintBoundary isolation for 60fps animation
- Panel height aligned to ROADMAP SC (600×480 / 400×320), all 5 success criteria verified by automated tests, full 111-test regression green

---
