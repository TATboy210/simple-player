# Milestones

## v1.0 错误捕获定位反馈系统 (Shipped: 2026-09-01)

**Phases completed:** 5 phases, 20 plans, 25 tasks

**Key accomplishments:**

- Shipped a local, immutable four-source error reporter that snapshots unsafe diagnostic inputs, retains a five-item FIFO, merges immediate repeats, and prevents reporting failures from cascading into the player.
- Shipped synchronous, failure-contained Flutter framework and root-isolate hooks plus a single guarded startup zone that initializes diagnostics before application services.
- Shipped one lifecycle-owned player-error bridge plus pre-fan-out local-path redaction and rollback-safe ten-second deduplication for immutable diagnostic reports.
- Local diagnostic paths now retain only safe basenames through every report observation, while FIFO deduplication preserves distinct player severity, typed code, and media-target evidence.
- 一份真实接纳的 ErrorReport 全链路贯通：`ErrorReporterImpl.presentation` → CARD-05 相位守卫宿主 → 折叠视图卡片 → app root Navigator 之上的左上角常驻显示，build 期故障注入与同帧多报告时序由回归测试锁死。
- ErrorCard 从「能看到」升级为「能定位」且「不妨碍操作」——整卡点击展开定位/源码行/调用栈/日志路径/重复五段（D-04 段序）、严重级三值语义色 token、l10nKey 13 key 解析迁移基线，以及常驻手动关、零焦点抢占与卡内外双向 hit-test 边界（含 D-10 route 命中）。
- 卡片补齐「复制即证据」闭环（复制文本与日志文件逐字符同源，成功/失败两态 OSD 反馈且异常不外溢）与多错误回看能力（warning 分流 OSD 恰好一次推进、徽标在 20 条本地有界快照内向旧循环轮览），至此除 MIG-01 迁移外的全部卡片行为到位。
- 旧错误横幅（142 行 widget + 测试 + 挂载子树 + doc 引用）经删前双路径等效证明与用户批准后全量删除，错误展示收敛为 ErrorCard 单一路径，四重质量门（grep 零残留 / analyze 0 error / 313 测试全绿 / kernel_logger_gate）收尾。
- Ctrl+Shift+I（kDebugMode 门控）构造带计数后缀的合成错误，经 `ErrorReporterImpl.I.reportPlatformSafely` 现有公开 intake 走 FIFO → presentation → ErrorCardHost → ErrorCard + 捕获徽标 + error.log 全真实链路，伴随 OSD「已注入测试错误」pill 与 F1 帮助 debug 条目，快速连按绕过 10s 去重窗每次出新卡——补上 UAT 实测缺失的开发用触发入口，零 kernel 改动、零 media_kit 接触。
- 一句话：
- settings.json（便携 JSON）经 load 驱动三层位置链（配置目录 → exe 根 → Application Support）解析出首个可写落点并完成 sink 激活，诊断包当次启动即落在配置目录；存储层加固到生产级（原子写 + 四级降级 + 保存失败静默 + 重启 round-trip）。
- 用户配置的日志目录先经 kernel 单层校验证明可写才被采用，变更经「先确认新位置 → dispose → activate」完成零丢失零乱序的安全换位，启动回退以一次性 OSD 告知——SET-02 的写入前校验、无效回退、sink 安全重建三件事全部落地。
- ErrorCardHost.build 外层一行门控锁死 SET-01 全部呈现语义：关→同帧消失只落盘不弹卡、开→恢复含队列中错误的最新报告、缺省→默认开，捕获/快照/落盘链零接触（D-05 零 kernel 由 diff 面与 kernel gate 双重证明）。
- 设置壳从静态 About 页升级为可导航选中态架构，「通用」tab 承载错误卡片开关行（翻转即生效+持久化）与日志目录路径行（手输防抖校验/浏览回填/行内状态/有效路径常显）——SET-01/02/03 的用户可见面全部落地，Phase 4 质量门全绿（analyze 0 error / 1377 tests / kernel gate 1&2）。
- 日志路径配置功能按 D-07 整体移除：通用 tab 只剩错误卡片开关行，日志固定落 exe 根 logs/error.log（Application Support 静默回退的双层链），settings.json 收窄为两键且旧文件第三键向后兼容，D-04 通知桥与运行时重定向协议不复存在——UAT Test 3/5 作废项获得自动化对应面，G-04-1 关账。
- 四源端到端整合注入 + 爆发/关闭隔离补差用例全绿,VER-01~05 证据映射表与开发者边界文档归档,产品实现零 diff,质量四门禁(analyze/machine 基线 diff/kernel_logger_gate/零 diff)全绿——里程碑验证闭环收官。

---

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

## v4.5 设置面板横向重构 + 音频功能填充 (Shipped: 2026-07-30)

**Phases completed:** 5/7 (28-32 done; 33 deferred; 34 skipped)

**Key accomplishments:**

- Phase 28: settings shell split — 517-line shell 拆为 3 个聚焦文件 + 删除 legacy 88px sidebar panel(在任何 feature 落地前完成,避免中期重构死锁)
- Phase 29: auto-pause-detector — settings 打开时总是暂停(always-pause 策略)
- Phase 30: panel layout redesign — 16:9 主约束 + 50% 面积次约束,连续 sizing clamp 400-600,800px tab bar 适配
- Phase 31: visual design alignment — 毛玻璃语言对齐控制栏
- Phase 32: navigation & interaction polish — InputModeDetector(v4.5 唯一新基础设施)+ L/R tab 箭头 + 输入模式感知 hint
- Phase 33 (DEFERRED): audio EQ tab — MDK `af` 滤镜路线未验证(pan/adelay/dynaudnorm 在链接 FFmpeg build 中可用性未确认);代码保留,1 行属性名改动可能救活
- Phase 34 (SKIPPED): control bar audio track switching — 耳机按钮 + track popup,推迟到 v4.6+
- Wrap 决策:用户撤回"不允许部分遗漏"硬约束;af 验证止损(未试 30 秒验证)
- Wrap commit:`d4ec8b57 docs(33): defer audio tab — af route unverified; skip P34; wrap v4.5`
- 技术债:ROADMAP Progress 表 P28-32 标 "Not started" 但实际完成,留作后续校准

## v1.8 播放器 Widget 稳定性与 PC Resize 流畅度 (Started: 2026-08-11)

**Phases planned:** 4 (35–38)

**Goal:** 在不改变播放功能、视觉状态和交互契约的前提下，按组件确认/恢复当前 widget tree，并降低 PC 窗口频繁变换时的 rebuild、layout、raster 和纹理卡顿。

**Key decisions:**

- 保留 `Video.controls → PlayerVideoControls → ControlBar`，不恢复 `ControlsOverlay`。
- 基于 Git 历史按文件/方法比较，不整体 checkout 或覆盖当前未提交工作树。
- 采用中等颗粒度 4 阶段：基线恢复、rebuild 边界、渲染/resize、回归与 Windows 性能证据。
- 验收同时包含自动化行为、Windows profile 帧耗时/jank 和内存稳定性。

---
