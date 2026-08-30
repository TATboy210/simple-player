# Roadmap: Simple Player — 错误捕获定位反馈系统

## Overview

本里程碑以一条可隔离的本地诊断管线交付“出错可定位”：先建立四源统一的错误契约、安全捕获和有界报告队列；再让每个报告具备可信定位和可回溯的纯文本文件证据；随后把播放引擎错误与统一的非模态界面反馈接通；最后提供持久化配置，并以端到端、洪流和 Windows 实机验证证明系统不会妨碍播放器正常操作。

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: 统一捕获与报告契约** - 四类错误安全地汇入同一个有界、可展示的报告服务。 (completed 2026-08-30)
- [x] **Phase 2: 可信定位与文件证据** - 每份报告获得安全的位置富化和独立、可回溯的错误日志。 (completed 2026-08-30)
- [ ] **Phase 3: 播放错误桥与非模态卡片** - 播放器内所有错误以不妨碍操作的统一卡片反馈给用户。
- [ ] **Phase 4: 错误反馈设置** - 用户可持久控制卡片显示和安全配置日志落点。
- [ ] **Phase 5: 端到端韧性验证** - 证明四源捕获、洪流处理和 Windows 交互在交付环境中可靠可用。

## Phase Details

### Phase 1: 统一捕获与报告契约

**Goal**: 应用可将四类错误来源安全归一化为可追踪、可去重、可按序处理的报告，而不会因报告自身失败造成新的应用故障。
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: CAP-01, CAP-02, CAP-03, CAP-04
**Success Criteria** (what must be TRUE):

  1. 框架异常、未捕获异步异常、启动期异常和播放引擎异常都可产生同一种含事件 ID、时间、严重级、错误、调用栈及当时媒体路径的不可变报告。
  2. 应用启动后，框架错误仍保留开发调试输出，异步未捕获错误被应用接管而不会作为未处理错误继续冒泡。
  3. 连续发生的相同错误会在当前报告中合并重复次数；不同错误按发生顺序等待用户处理，关闭当前项会展示下一项而不丢失已记录证据。
  4. 报告服务、其任一副作用或错误处理重入发生故障时，播放器不会因错误反馈链再次崩溃。

**Plans**: 4/4 plans executed
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Build and fully test the immutable ErrorReport kernel tracer, singleton reporter, bounded FIFO, dedupe, flush, and fault isolation.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Wire Flutter/Dart global hooks and same-zone guarded startup to the reporter; consolidate diagnostic initialization ownership.

**Wave 3** *(gap closure; blocked on Waves 1–2 completion)*

- [x] 01-03-PLAN.md — Connect one lifecycle-owned player-error bridge, redact diagnostic paths before fan-out, and reject rollback-negative dedupe intervals.

**Wave 4** *(gap closure; blocked on Waves 1–3 completion)*

- [x] 01-04-PLAN.md — Redact whitespace-bearing local paths end to end and preserve severity, structured player code, and media target in dedupe identity.

### Phase 2: 可信定位与文件证据

**Goal**: As a developer using the player daily, I want to see a trusted project location, media context, and readable, copyable local diagnostic evidence for every error report, so that I can pinpoint the problem without attaching a debugger.
(中文原意：每份错误报告都能给出可信的项目位置和媒体上下文，并独立写入可读取、可复制的本地诊断证据。)
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: LOC-01, LOC-02, LOC-03, LOG-01, LOG-02, LOG-03, LOG-04, LOG-05
**Success Criteria** (what must be TRUE):

  1. 发生项目代码错误时，报告保留完整原始调用栈并优先显示首个项目文件与行号；无法可靠定位时仍能安全显示完整错误信息。
  2. 在 debug/profile 可读取且位于受信源码根目录的源码行会随报告显示；release 或不可读、越界路径时仅降级为定位文本，不出现新的错误或闪退。
  3. 报告始终冻结发生时的当前媒体路径和 failed-open 尝试路径，使之后切换媒体不会改写历史证据。
  4. 每个 error/fatal 报告都会以 UTF-8 追加到默认或已验证的本地单一日志文件；普通 debug/info 输出不会污染该文件，关闭卡片也不会停止落盘。
  5. 日志写入或关闭失败时，应用仍可继续使用，并以受限调试输出和“日志不可用”状态降级；文件内容和复制内容使用相同的稳定诊断包格式。

**Plans**: 4/4 plans executed
Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Prove the reporter-effect → shared formatter → durable UTF-8 append tracer and harden single-writer failure isolation.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Extract trustworthy project frames and read debug/profile source context within a contained project root.

**Wave 3** *(blocked on Waves 1–2 completion)*

- [x] 02-03-PLAN.md — Freeze full current/failed-open media evidence and enrich immutable reports before effect fan-out.

**Wave 4** *(blocked on Waves 1–3 completion)*

- [x] 02-04-PLAN.md — Resolve Application Support/logs/error.log, wire the production sink before global hooks, and close quality gates.

### Phase 3: 播放错误桥与非模态卡片

**Goal**: As a player user, I want to see every error in one unified, expandable non-modal card that never blocks playback controls, so that I get immediate feedback without a second error display path.
(中文原意：用户在播放器界面中可获得所有错误的统一、可展开且不阻碍控制的即时反馈，旧错误横幅不再形成第二条展示路径。)
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: CARD-01, CARD-02, CARD-03, CARD-04, CARD-05, CARD-06, MIG-01
**Success Criteria** (what must be TRUE):

  1. 错误发生时，用户可在播放器左上角看到常驻的非模态错误卡片，并可手动关闭它；卡片不会自动消失、抢占焦点或打开 route/barrier。
  2. 用户可从折叠卡片读取摘要、严重级和媒体路径，并可展开查看文件:行号、可用源码行、完整调用栈和日志路径。
  3. 用户可一键复制与日志文件一致的完整诊断包；复制失败或关闭卡片时，播放和后续错误反馈仍保持可用。
  4. 卡片以外的界面区域仍可正常命中，标题栏、控制栏和播放列表操作不被遮挡；卡片显示期间键盘快捷键保持可用。
  5. 播放引擎错误经桥接后与其他来源显示在同一错误卡片中，且在等效覆盖得到验证后旧 ErrorBanner 已被移除。

**Plans**: 3/4 plans executed
Plans:
**Wave 1**

- [x] 03-01-PLAN.md — 贯通 presentation → ErrorCardHost → ErrorCard 折叠视图到 app root Stack（D-10 挂载层）的端到端 tracer，锁死 CARD-05 build 期安全与 D-12 补呈现。

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 03-02-PLAN.md — 折叠/展开五段详情与严重级语义色（CARD-03/D-03/D-04），常驻手动关、零焦点抢占与严格 hit-test（CARD-01/CARD-02）。

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 03-03-PLAN.md — 一键复制诊断包与失败隔离（CARD-04/D-06），warning 分流与计数徽标轮览（D-01/D-02/D-11）。

**Wave 4** *(blocked on Wave 3 completion; 含人工删除确认门)*

- [ ] 03-04-PLAN.md — MIG-01 双路径等效覆盖测试（D-07/D-09），人工确认后删除 ErrorBanner 并收尾质量门。

### Phase 4: 错误反馈设置

**Goal**: 用户可在设置界面持久选择是否显示错误卡片，并安全地配置诊断日志输出位置而不削弱捕获和落盘。
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: SET-01, SET-02, SET-03
**Success Criteria** (what must be TRUE):

  1. 用户可在设置“通用”tab 开关错误卡片，默认开启；关闭后错误仍被捕获并写入日志，只是不再显示卡片。
  2. 用户可配置日志输出路径，应用会在采用前验证可写性；无效路径自动回退到默认或最后一个可用位置，而不会中断错误记录。
  3. 用户修改卡片偏好或有效日志路径后重启应用，设置仍被保留；切换日志路径不会损坏写入中的诊断记录。

**Plans**: TBD
**UI hint**: yes

### Phase 5: 端到端韧性验证

**Goal**: 用户和开发者可确信该诊断系统在真实错误、高频错误及 Windows 播放器交互期间完整捕获、可回溯且不妨碍使用。
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: VER-01, VER-02, VER-03, VER-04, VER-05
**Success Criteria** (what must be TRUE):

  1. 对四个错误来源分别进行故障注入时，每次都产生一份报告、相应的文件证据，并在卡片开启时展示一张卡片。
  2. 发生 100–1000 个合成错误的爆发时，内存和排队保持有界、重复项被合并、写盘保持受控，播放控制仍能响应。
  3. 捕获钩子与 runApp 在同一 zone 中工作，报告重入、复制失败和关闭失败均不会造成第二个未处理错误。
  4. Windows 实机中卡片显示期间，标题拖动、窗口控制、seek、播放列表、全屏、ESC 和媒体键仍全部可用。
  5. 开发者可查阅 release 下源码/符号可用性的降级策略，以及 Dart 错误钩子无法捕获 libmpv/FFI 原生进程崩溃的边界。

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. 统一捕获与报告契约 | 4/4 | Complete    | 2026-08-30 |
| 2. 可信定位与文件证据 | 4/4 | Complete    | 2026-08-30 |
| 3. 播放错误桥与非模态卡片 | 3/4 | In Progress|  |
| 4. 错误反馈设置 | 0/TBD | Not started | - |
| 5. 端到端韧性验证 | 0/TBD | Not started | - |
