# Phase 35: Widget Tree Baseline & Behavior Recovery - Research

**Researched:** 2026-08-11  
**Domain:** Flutter desktop 播放器 widget tree、media_kit controls route 生命周期、窗口桥接与回归测试  
**Confidence:** HIGH（当前源码、测试和本地 Git 历史已核验；Flutter 生命周期 API 的外部资料为 MEDIUM）

## User Constraints

本阶段没有 `35-CONTEXT.md`，以下约束来自已读取的项目里程碑文件，规划必须遵守。

- 不整体 checkout/覆盖历史 tree；当前工作树已有未提交改动，禁止 `reset` 或整树回滚。[VERIFIED: .planning/PROJECT.md:11-13, 42-43]
- 保留 `Video.controls → PlayerVideoControls`、直接 `ControlBar` 和 `CustomTitleBar` 优化；不恢复 `ControlsOverlay`，不恢复旧 fullscreen plugin，不修改 media_kit/libmpv。[VERIFIED: .planning/PROJECT.md:11-13, 27-33]
- 保持 `ValueNotifier + ValueListenableBuilder`，不引入 Provider/Riverpod/Bloc；全部视觉值继续使用 `Tokens.*`。[VERIFIED: .planning/PROJECT.md:36-43]
- 必须先测试再扩展；提交前运行 analyzer、相关测试、review 和 diff check；未追踪截图未经确认不得删除或提交。[VERIFIED: .planning/PROJECT.md:34, 42-43]

## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| BASE-01 | 比较 `e0083842`、`f590cce2`、`6e0edbb8` 与当前工作树，形成按文件基线且不整体覆盖。 | 已给出提交差异范围、比较命令与按组件恢复方法。 |
| BASE-02 | 保留 `PlayerScreen → Video.controls → PlayerVideoControls → ControlBar`，不接回旧树。 | 已核验当前生产链路和历史 `ControlsOverlay` 删除。 |
| BASE-03 | 关键播放、窗口、控制交互保持通过。 | 已盘点现有测试，给出命令和未覆盖的高风险场景。 |
| BASE-04 | 验证并在可复现时修复 GlassButton callback cache 的旧闭包。 | 已定位实现与现有回归测试；建议只补缺口，不重写 cache。 |
| BASE-05 | 验证 source replacement、reparent、activate/deactivate/dispose、subtitle padding 与旧 source 隔离。 | 当前针对这些生命周期的 fake-port 测试已存在；给出必须保持/补强的断言。 |

## Summary

Phase 35 应被规划为“以行为为准的基线冻结”，而非视觉或架构回退。当前生产主路径是 `PlayerScreen` 将 controls builder 交给 media_kit `Video`，builder 再构造 `PlayerVideoControls`；该控件内部持有 `PlayerControlsState`，将当前 route 的 `VideoState` 包装成 `VideoControlsPort`，并向 `ControlBar` 下发局部 listenable。[VERIFIED: lib/ui/player/player_screen.dart:328-392] 这与 `e0083842` 后移除 `ControlsOverlay` 的方向一致；`f590cce2` 进一步删除该旧文件并大幅改造 controls/resize tree；`6e0edbb8` 则仅优化标题栏的缓存与重绘边界。[VERIFIED: local Git commits e0083842, f590cce2, 6e0edbb8]

当前工作树相对 `e0083842` 的 relevant UI/test 范围为 34 个文件、1681 行新增/2505 行删除；其中最关键且不可逆的结构差异是 `lib/ui/player/controls_overlay.dart` 删除，而不是某一份可直接恢复的“完整历史 tree”。[VERIFIED: local `git diff --stat e0083842..HEAD -- lib/ui/player lib/ui/shared/glass_container.dart lib/ui/window test/widget/player test/widget/shared`] 因此恢复方法必须是：先选提交范围作结构基准、逐文件/逐方法以可观察的行为契约比对、先写失败测试、只移植缺失的最小逻辑。绝不执行 `git checkout <commit> -- lib/ui/player`。

已在当前脏工作树上执行目标回归：8 个测试文件共 **78** 项通过；`flutter analyze` 为 “No issues found”；`git diff --check` 没有 whitespace error（仅报告 planning 文件的 LF→CRLF 工作副本警告）。[VERIFIED: local commands executed 2026-08-11] 这些结果是基线证据，不授权覆盖已有未提交源码、测试或图片。

**Primary recommendation:** 将 Phase 35 拆成“Git 行为矩阵 + 高风险 widget 生命周期回归 + 仅在测试失败时的最小修复”三个计划；生产代码任务必须由新增或强化的失败测试驱动。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| 控制栏装配与全屏 route controls 复制 | Flutter 客户端 | media_kit `Video` route | `PlayerScreen` 传入 `Video.controls` builder；每个 route 得到自己的 `VideoState`。 [VERIFIED: lib/ui/player/player_screen.dart:328-392] |
| 播放状态、进度、倍速、音量的展示流 | Flutter 客户端 | 播放器/媒体引擎 | `PlayerControlsState` 订阅 `PlayerPort` stream，写入项目持有的 notifier；音量/静音写回 `MediaEngine`。 [VERIFIED: lib/ui/player/player_video_controls.dart:114-232] |
| fullscreen route 进入/退出 | media_kit `VideoState` | WindowBridge mode 同步 | controls 使用当前 `VideoControlsPort` 执行 route toggle/exit，同时 action 同步窗口 mode。 [VERIFIED: lib/ui/player/player_video_controls.dart:372-381, 417-445] |
| 标题栏窗口操作与状态显示 | Flutter 客户端 | WindowBridge / window_manager | 标题栏依赖抽象桥接的 mode、pin 和命令，不直接依赖具体窗口插件。 [VERIFIED: lib/ui/window/custom_title_bar.dart:19-121; lib/kernel/bridge/window_bridge.dart:15-88] |
| resize 降级绘制、视频 surface identity | Flutter 客户端 | WindowBridge resize notifier | `isResizing` 控制滤镜/`filterQuality`，而稳定 widget 类型与 key 维持 element identity。 [VERIFIED: lib/ui/player/player_screen.dart:236-297, 347-360] |

## Standard Stack

### Core

| Library / 组件 | Version | Purpose | Why Standard |
|---|---:|---|---|
| Flutter SDK | 3.44.8 | StatefulWidget 生命周期、widget/integration tests、Focus/Actions | 本机稳定版已安装，项目当前测试基于 `flutter_test`。 [VERIFIED: local `flutter --version` 2026-08-11] |
| `flutter_test` | SDK 内置 | widget tree、语义、键盘、GlobalKey reparent 测试 | 项目已有 fake-port 与 widget test 基础设施；无需新增测试包。 [VERIFIED: pubspec.yaml:39-50] |
| `media_kit_video` | `^2.0.1` | `Video`、`VideoState`、controls builder/fullscreen route | 项目已安装，当前生产 controls 依赖其 API；本阶段不可替换或修改该基础能力。 [VERIFIED: pubspec.yaml:14-20; lib/ui/player/player_screen.dart:328-392] |
| `window_manager` | `^0.5.2` | `WindowService` 的平台窗口委派 | 仅经 `WindowBridge` 在 UI 使用；本阶段无需新增依赖。 [VERIFIED: pubspec.yaml:29-31; lib/kernel/bridge/window_service.dart:8, 25] |

### Supporting

| Component | Purpose | When to Use |
|---|---|---|
| `FakeVideoControlsPort` + `FakePlayerControls` | 不初始化 libmpv/MDK 的 route 与 stream 替身 | 所有 controls source/reparent/dispose/subtitle padding widget tests。 [VERIFIED: test/helpers/fake_video_controls.dart:6-67] |
| `FakeWindowService` | 无 `window_manager` 平台通道的 WindowBridge 替身 | PlayerScreen identity、标题栏 replacement 和键盘窗口模式测试。 [VERIFIED: test/helpers/fake_window_service.dart:8-86] |
| `fake_async` | WindowService resize debounce 的确定性单测 | 仅 WindowService timer/generation 行为。 [VERIFIED: pubspec.yaml:45-50; test/unit/kernel/bridge/window_service_test.dart:1-8] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| fake-port widget tests | 真实 `VideoController` + media_kit 集成测试 | 真实 native surface 适合 Windows 手工 profile，但 headless 会触及 FFI；不能取代纯 Dart 生命周期测试。 [VERIFIED: lib/ui/player/player_screen.dart:28-42; test/helpers/fake_video_controls.dart:6-10] |
| 文件/方法级历史比对 | 整体 checkout 历史 tree | 会删除当前 resize/title-bar 稳定化与未提交增量，违反项目范围。 [VERIFIED: .planning/PROJECT.md:11-13, 42-43] |

**Installation:** 无。Phase 35 不应安装外部 package。

## Package Legitimacy Audit

不适用：本阶段不安装外部 package。

## Architecture Patterns

### System Architecture Diagram

```text
用户输入（鼠标/键盘/窗口事件/拖放）
        │
        ├── WindowBridge.mode / isResizing ────────────────┐
        │                                                   │
        ▼                                                   ▼
PlayerScreen ── Video.controls builder ──> PlayerVideoControls
     │                    │                       │
     │                    │                       ├── PlayerControlsState
     │                    │                       │      └── PlayerPort streams → local ValueNotifiers
     │                    │                       ├── AutoHide + subtitle padding
     │                    │                       ├── current VideoControlsPort (per route)
     │                    │                       └── ControlBar (局部 listenable)
     │                    ▼
     │              media_kit fullscreen route
     │                    │
     ├── cached CustomTitleBar <── WindowBridge replacement ┘
     └── stable video surface / resize filter-quality boundary
```

### Pattern 1: 历史提交用于“行为差分”，不是用于覆盖源码

**What:** 对每个关键组件分别执行 `git diff -- <file>`、`git show <commit>:<file>` 和现有测试对照；将每项差异归类为“必须保留的当前稳定化”、“被删除的旧架构”或“需要恢复的行为”。

**When to use:** 仅在 BASE-01 的基线梳理和测试发现回归时。

**Prescriptive workflow:**
1. 将 `e0083842` 作为 controls 统一与旧 fullscreen plugin 移除的起点；该提交明确删除了 `packages/fullscreen_window`，并扩展 player lifecycle regression tests。[VERIFIED: local `git show --stat e0083842`]
2. 将 `f590cce2` 作为 resize/control rendering tree 的结构断点；该提交删除 `controls_overlay.dart`、新增 `player_screen_accessibility_resize_test.dart`，并改造 PlayerScreen/PlayerVideoControls。[VERIFIED: local `git show --stat f590cce2`]
3. 将 `6e0edbb8` 作为标题栏性能实现的保留基线；它只修改 `lib/ui/window/custom_title_bar.dart`，缓存静态按钮行、隔离 repaint、保持交互语义。[VERIFIED: local `git show --stat 6e0edbb8`]
4. 针对当前脏树，使用 `git diff e0083842..HEAD -- <file>` 观察已提交基线；另用 `git diff -- <file>` 单独审计未提交增量。不要混淆二者。

### Pattern 2: source replacement 保留下游 notifier identity、替换上游订阅

**What:** `PlayerControlsState.updateSources` 只替换 `_port`/`_engine`，然后 `init()` 先取消八个旧 stream subscription、写入新 snapshot、再订阅新流；其拥有的 `ValueNotifier` 不被重建。[VERIFIED: lib/ui/player/player_video_controls.dart:143-200]

**Must preserve verbatim implementation behavior:**
> `void updateSources(PlayerPort port, {required MediaEngine engine}) {\n    _port = port;\n    _engine = engine;\n    init();\n  }`
>
> `void _cancelSubscriptions() { ... _playingSub?.cancel(); ... _rateSub?.cancel(); ... }`

[VERIFIED: lib/ui/player/player_video_controls.dart:176-200]

**When to use:** `widget.video` 或 `widget.engine` identity 改变；尤其是 fullscreen route/reparent 同帧替换 source。

### Pattern 3: reparent 的 deactivate/activate 对称解绑与恢复

**What:** 全屏 route pop 的 inactive 窗口中，不能调用依赖 ancestor 的 `VideoState` API；先设置 `_isDeactivating`、解绑外部 listeners，`activate` 后再重连并同步当前状态。[VERIFIED: lib/ui/player/player_video_controls.dart:633-657]

**Must preserve verbatim implementation behavior:**
> `void deactivate() {\n    _isDeactivating =\n        true;\n    _detachLifecycleListeners();\n    super.deactivate();\n  }`
>
> `void activate() {\n    super.activate();\n    _isDeactivating = false;\n    _attachLifecycleListeners();\n    _onResizeChanged();\n    _isIdleNotifier.value = widget.engine.state.value == MediaState.idle;\n    _syncSubtitlePadding();\n  }`

[VERIFIED: lib/ui/player/player_video_controls.dart:633-657]

官方 Flutter 文档确认 `StatefulWidget` 的状态由 `initState → didUpdateWidget/build → dispose` 生命周期管理；`FocusableActionDetector` 组合 Focus、Shortcuts、Actions 和 MouseRegion。[CITED: https://docs.flutter.dev/learn/pathway/how-flutter-works] [CITED: https://docs.flutter.dev/ui/interactivity/focus] 对本项目 reparent 的精确时序，优先以当前 fake-port tests 为可执行契约。[VERIFIED: test/widget/player/player_video_controls_test.dart:238-799]

### Pattern 4: subtitle padding 是“基础 padding + 控制栏 inset”，不是累加写入

**What:** 每个 `VideoControlsPort` source 第一次同步时读取自身基础 padding；控件可见则写 `base + inset`，隐藏则回写 `base`。source replacement 必须清空基础缓存，避免新 route 继承旧 route 的值。[VERIFIED: lib/ui/player/player_video_controls.dart:361-408, 595-605]

**Must preserve verbatim implementation behavior:**
> `final base = _subtitleBasePadding ??= videoState.subtitlePadding;`
>
> `final padding = _autoHide.visible.value\n        ? base + _subtitleControlBarInset\n        : base;`
>
> `_subtitleBasePadding = null;`

[VERIFIED: lib/ui/player/player_video_controls.dart:401-408, 595-605]

### Pattern 5: stable widget cache 必须随外部依赖 replacement 重建

**What:** `PlayerScreen` 缓存标题栏 widget 是为了窗口 mode/resize 不重建整棵标题栏；当 `WindowBridge` identity 改变时必须替换缓存。`CustomTitleBar` 自己也对 bridge replacement 重建静态按钮行，避免 button closure 继续指向旧 bridge。[VERIFIED: lib/ui/player/player_screen.dart:107-112, 212-220; lib/ui/window/custom_title_bar.dart:31-49]

**Must preserve verbatim implementation behavior:**
> `if (oldWidget.windowService != widget.windowService) {\n      _titleBar = RepaintBoundary(\n        child: CustomTitleBar(windowService: widget.windowService),\n      );\n    }`

[VERIFIED: lib/ui/player/player_screen.dart:212-220]

### Anti-Patterns to Avoid

- **恢复 `ControlsOverlay`：** 它是被 `f590cce2` 删除的旧控制树；重新接入会使 `Video.controls` builder 内外出现竞争的 controls/lifecycle 路径。[VERIFIED: local `git diff --name-status e0083842..HEAD`; .planning/PROJECT.md:11-13]
- **从 `PlayerScreen._videoKey` 对 fullscreen route 写 subtitle padding 或决定退出路径：** fullscreen route 拥有另一个 `VideoState`；必须通过当前 controls 实例的 `VideoControlsPort` 操作。[VERIFIED: lib/ui/player/player_video_controls.dart:56-111, 372-408]
- **为“优化”而删除 `deactivate` listener detach：** inactive 到 dispose 之间 timer/stream/post-frame 仍可能触发，访问已离树 route 会导致 ancestor assertion 风险。[VERIFIED: lib/ui/player/player_video_controls.dart:633-645]
- **把 cached `CallbackAction` 闭包绑定到 initState 时的 callback 值：** callback 可在 widget rebuild 后替换；调用时必须读 `widget.onPressed`。当前实现符合此规则。[VERIFIED: lib/ui/shared/glass_container.dart:261-279]
- **直接以真实 media_kit 视频 surface 运行全部 headless widget tests：** 测试注入 `videoSurfaceBuilder` 与 fake port 正是为避免原生运行时依赖。[VERIFIED: lib/ui/player/player_screen.dart:28-42, 333-344]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| media_kit fullscreen route | 自定义 fullscreen Navigator/route 或旧 plugin | 当前 route 的 `VideoControlsPort.toggleFullscreen/exitFullscreen` | 当前 route 才拥有正确的 `VideoState` 与 subtitle padding 生命周期。 [VERIFIED: lib/ui/player/player_video_controls.dart:56-111, 372-381] |
| stream source lifecycle fake | 临时 mock 多层 media_kit internals | `FakePlayerControls`、`FakeVideoControlsPort` | 已记录 listener、route、padding 调用，且不加载 libmpv。 [VERIFIED: test/helpers/fake_video_controls.dart:6-67] |
| 窗口实现耦合 | UI 直接调 `window_manager` | `WindowBridge` + `FakeWindowService` | 保持平台桥接替换可测，并隔离 plugin MethodChannel。 [VERIFIED: lib/kernel/bridge/window_bridge.dart:15-88; test/helpers/fake_window_service.dart:8-86] |
| callback action cache | 每 build 分配 Action，或把 callback snapshot 缓存 | 缓存 `CallbackAction`，在 `onInvoke` 读取 `widget.onPressed` | 降低分配同时避免 callback stale closure。 [VERIFIED: lib/ui/shared/glass_container.dart:261-279] |

**Key insight:** 本阶段不是恢复旧 widget 层级；要恢复的是“当前每条用户可见路径在 source、route、窗口桥接发生替换时仍指向当前对象”的行为。

## Current Behavior Contract

### 已锁定的主树

生产主树必须保持如下调用关系：

> `PlayerScreen → Video.controls → PlayerVideoControls → ControlBar`

[VERIFIED: lib/ui/player/player_screen.dart:328-392; .planning/REQUIREMENTS.md:8-13]

具体实现摘录：
> `return Video(\n        key: _videoKey,\n        controller: controller,\n        controls: _buildControls,\n        ...\n      );`
>
> `return playerVideoControls(\n      state,\n      engine: widget.engine,\n      actions: _actions, ...\n    );`

[VERIFIED: lib/ui/player/player_screen.dart:349-360, 376-392]

### GlassButton callback cache

- `_actions` 是 State 生命周期内复用的 map，但 `_effectiveActivateAction` 的 `onInvoke` 在按键实际触发时访问 `widget.onPressed?.call()`，因此同一 State rebuild 后应调用新 callback，而非首帧 callback。[VERIFIED: lib/ui/shared/glass_container.dart:261-279]
- 现有回归已经验证第一次 Space 调旧 callback、rebuild 后 Enter 调新 callback，并断言各自仅一次。[VERIFIED: test/widget/shared/glass_button_test.dart:159-188]
- `enabled=false` 或 `onPressed=null` 时 focus/semantic/tap 都必须失效；当前 `_effectiveEnabled` 同时驱动交互和语义。[VERIFIED: lib/ui/shared/glass_container.dart:288-295, 371-395; test/widget/shared/glass_button_test.dart:190-247]
- Phase 35 不应修改这段实现，除非新增测试可复现实际失效。应补“label 模式的 callback replacement”以防 icon-only 测试掩盖两种 build path 的差异。[ASSUMED]

### PlayerVideoControls source / reparent / dispose

- source replacement 必须取消旧 PlayerPort 的 8 条 stream subscription，读取新 snapshot，订阅新 stream，并将写命令路由至新 engine/port。[VERIFIED: lib/ui/player/player_video_controls.dart:143-232]
- `widget.engine.state` replacement 必须移除旧 listener、添加新 listener、刷新 idle notifier 和 `_mediaIdentityListenable`；`resizing` replacement 也必须先移除旧 listener。[VERIFIED: lib/ui/player/player_video_controls.dart:607-630]
- reparent 必须保持同一个 State，且不能重新创建 8 条 stream subscription。当前测试以 `streamListenAccessCount == 8` 锁定这一点。[VERIFIED: test/widget/player/player_video_controls_test.dart:533-597]
- dispose 后所有 player stream、engine、resize notifier 变化都不得排帧或继续写 subtitle padding。[VERIFIED: test/widget/player/player_video_controls_test.dart:599-696]

### subtitle padding 生命周期

- 每个 source 的初始 `subtitlePadding` 只读一次；visible 时添加控制栏 bottom inset，hidden 时恢复 base；同一 source 多次 activate/reparent 不得重复叠加 inset。[VERIFIED: lib/ui/player/player_video_controls.dart:361-408; test/widget/player/player_video_controls_test.dart:238-323]
- source replacement 后必须将 `_subtitleBasePadding` 设回 null 并对新 source 立即同步当前 visible 状态；即使新旧 port 共享同一个 PlayerPort 也不能跳过。[VERIFIED: lib/ui/player/player_video_controls.dart:595-605; test/widget/player/player_video_controls_test.dart:463-531]
- 当 `VideoControlsPort.isMounted == false`，或 `_isDeactivating == true`，禁止调用 `setSubtitleViewPadding`。[VERIFIED: lib/ui/player/player_video_controls.dart:390-408; test/widget/player/player_video_controls_test.dart:698-742]

### WindowBridge replacement 与标题栏

- `WindowBridge` 是 UI 的窗口状态/命令边界，包含 mode、size、isResizing、resizeSessionId、pin state 和窗口命令。[VERIFIED: lib/kernel/bridge/window_bridge.dart:15-88]
- `PlayerScreen.didUpdateWidget` 仅在 bridge identity 改变时重建缓存标题栏；正常 mode/resize 只由 title bar 内部 listener 更新。[VERIFIED: lib/ui/player/player_screen.dart:107-112, 212-220]
- `CustomTitleBar.didUpdateWidget` 也在 bridge 改变时重新构建 `_staticTitleRow`，因此 pin/minimize/close callback 不会保留旧 bridge。[VERIFIED: lib/ui/window/custom_title_bar.dart:31-49, 51-97]
- 当前**没有** `CustomTitleBar` 或 `PlayerScreen` 的 WindowBridge replacement widget test；这是 Phase 35 的明确高风险缺口。[VERIFIED: codebase grep `CustomTitleBar` under test returned no matches 2026-08-11]

## Common Pitfalls

### Pitfall 1: 用历史 tree 回滚替代行为恢复

**What goes wrong:** 整体 checkout 会同时带回已删除的 `ControlsOverlay`、覆盖 resize/filter/title-bar 的稳定化和用户未提交改动。  
**Why it happens:** Git 历史可快速看到“完整文件”，容易误认为它就是目标基线。  
**How to avoid:** 先对四个 commit 边界做 per-file diff；每个回退候选必须关联一个失败回归测试和单一行为。  
**Warning signs:** plan 出现 `git checkout e0083842 -- lib/ui/player`、恢复 `controls_overlay.dart` 或重新添加 fullscreen plugin。 [VERIFIED: .planning/PROJECT.md:11-13, 27-34]

### Pitfall 2: fullscreen route 操作了窗口态 VideoState

**What goes wrong:** 全屏下字幕 padding、ESC、route toggle 发送到旧/窗口态 `VideoState`，造成控件遮挡、重复 enter 或 inactive ancestor 崩溃。  
**Why it happens:** fullscreen builder 会有不同的 route-local `VideoState`，但外层 GlobalKey 只有窗口态实例。  
**How to avoid:** 所有 route 相关操作只通过 `widget.video`（当前 `VideoControlsPort`）；WindowBridge 仅同步窗口 mode。  
**Warning signs:** 新代码从 `PlayerScreen._videoKey.currentState` 设置 padding，或 `PlayerVideoControls` 重获外层 key。 [VERIFIED: lib/ui/player/player_screen.dart:84-87; lib/ui/player/player_video_controls.dart:372-408]

### Pitfall 3: deactivate 与 dispose 之间仍触发外部 listener

**What goes wrong:** Element 已 inactive 但 State 仍 mounted；timer、animation、post-frame 或 stream 调用 `VideoState` 产生 deactivated ancestor assertion。  
**Why it happens:** 仅在 `dispose` 移除 listener 太晚，且 `mounted` 无法识别 inactive。  
**How to avoid:** 保留 `_isDeactivating` 与 `_detachLifecycleListeners()` 在 `deactivate`；在 `activate` 对称恢复。  
**Warning signs:** 删除 `_isDeactivating`，或把 detach 延后到 dispose。 [VERIFIED: lib/ui/player/player_video_controls.dart:560-657]

### Pitfall 4: subtitle inset 叠加污染

**What goes wrong:** reparent/activate 后把已包含 inset 的 padding 再当 base，字幕不断上移。  
**Why it happens:** 每次同步都读取 port 当前 padding，而 port 已被本控件写过。  
**How to avoid:** 单个 source 缓存 base，only-on-source-change reset；测试必须断言 reparent 后仍是一次 inset。  
**Warning signs:** `_subtitleBasePadding` 改为每次读取，或 source replacement 不清空它。 [VERIFIED: lib/ui/player/player_video_controls.dart:401-408, 595-605; test/widget/player/player_video_controls_test.dart:291-300]

### Pitfall 5: 缓存 widget/action 时未处理依赖 replacement

**What goes wrong:** cache 达到减少重建目的，却让 click/action 仍调用旧 callback/old WindowBridge。  
**Why it happens:** `late final` cache 或 cached action 将“对象 identity 稳定”误写成“依赖值永远不变”。  
**How to avoid:** Action callback 在 invoke 时读取 `widget`；cached widget 在 `didUpdateWidget` 比较外部依赖 identity 后重建。  
**Warning signs:** `onInvoke` 捕获 initState local callback，或 bridge replacement 不触发 cache rebuild。 [VERIFIED: lib/ui/shared/glass_container.dart:261-279; lib/ui/player/player_screen.dart:212-220; lib/ui/window/custom_title_bar.dart:42-49]

## Code Examples

### 推荐的历史基线比较命令

```bash
# 只比较 Phase 35 关心的 UI/test 表面，不修改工作树。
git diff --stat e0083842..HEAD -- lib/ui/player lib/ui/shared/glass_container.dart lib/ui/window test/widget/player test/widget/shared
git diff --name-status e0083842..HEAD -- lib/ui/player lib/ui/shared/glass_container.dart lib/ui/window test/widget/player test/widget/shared

# 按关键提交划分“统一 controls / resize-control rendering / title bar”。
git diff -- lib/ui/player/player_screen.dart lib/ui/player/player_video_controls.dart lib/ui/shared/glass_container.dart lib/ui/window/custom_title_bar.dart
git diff e0083842..f590cce2 -- lib/ui/player/player_screen.dart lib/ui/player/player_video_controls.dart lib/ui/player/controls_overlay.dart
git diff f590cce2..6e0edbb8 -- lib/ui/window/custom_title_bar.dart

# 只审计用户当前未提交增量；禁止 checkout/reset。
git diff -- lib/ui/player lib/ui/shared/glass_container.dart lib/ui/window test/widget/player test/widget/shared
git diff --check
```

### 推荐的 WindowBridge replacement test skeleton

```dart
// 在同一 GlobalKey 下替换 WindowBridge，断言标题栏操作只调用新 bridge。
// `FakeWindowService` 记录 `minimizeCallCount` / `closeCallCount` / `startDraggingCallCount`。
final oldBridge = FakeWindowService();
final newBridge = FakeWindowService();

// 先 pump PlayerScreen(windowService: oldBridge)，再以同一 PlayerScreen key
// pump PlayerScreen(windowService: newBridge)。
// 点击最小化 / close / pin，再断言 oldBridge 对应计数保持 0，newBridge 增加。
```

其中 `FakeWindowService` 的可断言字段原文为：
> `int modeCallCount = 0;`
>
> `int minimizeCallCount = 0;`
>
> `int closeCallCount = 0;`
>
> `int startDraggingCallCount = 0;`

[VERIFIED: test/helpers/fake_window_service.dart:12-20]

### 推荐的 GlassButton label callback replacement test skeleton

```dart
// 用同一个 FocusNode 和相同 GlassButton key，先 pump label 模式的 first callback；
// rebuild 后换成 second callback；发送 Space/Enter。
// 断言 first 只在首次激活，second 只在 rebuild 后激活。
```

此模式的 icon-only 版本已存在，真实行为断言为：
> `expect(firstActivationCount, 1);`
>
> `expect(secondActivationCount, 1);`

[VERIFIED: test/widget/shared/glass_button_test.dart:159-188]

## High-Risk Test Plan

| Priority | Test / 位置 | 必须断言 | 当前状态 |
|---|---|---|---|
| P0 | `test/widget/shared/glass_button_test.dart` | label-mode rebuild 后 Space/Enter 只调用最新 `onPressed`；enabled→disabled 后不激活。 | icon-only replacement 已有；label-mode replacement 缺失。 [VERIFIED: test/widget/shared/glass_button_test.dart:159-247, 382-423] |
| P0 | 新增 `test/widget/player/player_screen_window_bridge_replacement_test.dart` 或扩展现有 PlayerScreen test | 同 key rebuild 替换 WindowBridge 后，title bar pin/minimize/close/drag/maximize 都只调用新 bridge；旧 bridge notifier 改变不再驱动树。 | 缺失。 [VERIFIED: codebase grep `CustomTitleBar` under test returned no matches 2026-08-11] |
| P0 | `test/widget/player/player_video_controls_test.dart` | source replacement + reparent 同帧后：旧 port 无 listener，新 port 恰 8 条 subscriptions，旧 engine/resize/currentFileName 无排帧。 | 已覆盖主路径；保持并补“old resize notifier post-replacement 不排帧”断言。 [VERIFIED: test/widget/player/player_video_controls_test.dart:325-389, 599-667] |
| P0 | 同文件 subtitle 生命周期 | base padding 非零、visible/hidden、reparent 两次、replacement、`isMounted=false`、dispose 后都不重复 inset/不再写。 | 大部分已覆盖；建议把 hidden 后恢复 base 与“replacement 后旧 port 不再写”拆成明确断言。 [VERIFIED: test/widget/player/player_video_controls_test.dart:238-323, 463-531, 698-742] |
| P1 | `test/widget/player/player_screen_accessibility_resize_test.dart` | 三次 resize session 中 surface element identity、核心 progress/play semantics 与设置状态保持。 | 已覆盖；继续作为后续性能改动不可删除的门。 [VERIFIED: test/widget/player/player_screen_accessibility_resize_test.dart:61-210] |
| P1 | `test/widget/player/player_video_controls_test.dart` | F/ESC 在当前 route port 上 route toggle/exit，且 action 同步仅一次。 | 已覆盖 fake-route 语义；真实 Windows route 验证留 Phase 38。 [VERIFIED: test/widget/player/player_video_controls_test.dart:885-926] |
| P1 | `test/widget/player/player_screen_stop_empty_state_test.dart` | stop 卸载前不展示空状态；2 秒隔离期 O 键与按钮都无效，结束后共用入口可打开。 | 已覆盖。 [VERIFIED: test/widget/player/player_screen_stop_empty_state_test.dart:17-92] |
| P1 | `test/integration/error_propagation_test.dart` | engine error→ErrorBanner→dismiss/recovery，File/Playback/Codec/Network action 进入正确入口。 | 已覆盖。 [VERIFIED: test/integration/error_propagation_test.dart:55-191] |
| P2 | `test/widget/player/drop_handler_test.dart` | enter/exit hover 与空文件 drop 行为。真实 OS 文件 drop 仍需 Windows 手测。 | widget callback 已覆盖。 [VERIFIED: test/widget/player/drop_handler_test.dart:90-228] |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `ControlsOverlay` 位于旧控制树 | `Video.controls` builder 中装配 `PlayerVideoControls` | `f590cce2` | fullscreen route 可复制同一 controls 结构，避免两棵 controls tree。 [VERIFIED: local Git commit f590cce2; lib/ui/player/player_screen.dart:328-392] |
| 外层 cross-layer visibility sink 控制 subtitle padding | 每个 `PlayerVideoControls` 用自己的 `VideoControlsPort` 同步 padding | `f590cce2` 后当前实现 | window/fullscreen 具有独立 route-local padding source。 [VERIFIED: lib/ui/player/player_video_controls.dart:272-281, 384-408] |
| 标题栏每次 mode change 重建全部按钮行 | 缓存静态行，动态壳层/最大化图标局部监听 | `6e0edbb8` | 缩小窗口模式转换的 build/repaint 边界，且需处理 bridge replacement。 [VERIFIED: local Git commit 6e0edbb8; lib/ui/window/custom_title_bar.dart:31-121] |
| 每次 build 分配 action/闭包，或可缓存旧 callback | action map 缓存，invoke 时读 `widget.onPressed` | `d0ba3898` | 降低分配且不持有旧 callback。 [VERIFIED: local Git commit d0ba3898; lib/ui/shared/glass_container.dart:261-279] |

**Deprecated/outdated:**
- `ControlsOverlay`：已删除，Phase 35 明确禁止恢复。 [VERIFIED: local `git diff --name-status e0083842..HEAD`; .planning/PROJECT.md:11-13]
- 旧 fullscreen plugin：`e0083842` 删除 `packages/fullscreen_window`，当前计划禁止重新接入。 [VERIFIED: local `git show --stat e0083842`; .planning/PROJECT.md:27-33]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Flutter | analyze、widget/integration tests | ✓ | 3.44.8 stable | — [VERIFIED: local `flutter --version` 2026-08-11] |
| Dart | Flutter toolchain | ✓ | 3.12.2 | — [VERIFIED: local `dart --version` 2026-08-11] |
| Windows native media runtime / libmpv | 真实 `Video` surface、Windows profile | 未在本研究中以 GUI 验证 | — | fake port + injected surface 用于 headless widget tests。 [VERIFIED: lib/ui/player/player_screen.dart:28-42; test/helpers/fake_video_controls.dart:6-10] |
| `window_manager` 平台通道 | WindowService unit tests | ✓（mocked） | pubspec `^0.5.2` | `FakeWindowService` 用于 widget tests。 [VERIFIED: pubspec.yaml:29-31; test/unit/kernel/bridge/window_service_test.dart:382-417] |

**Missing dependencies with no fallback:** 无（Phase 35 自动化基线可由 fake-port 测试完成）。

**Missing dependencies with fallback:** 真正 Windows GUI/texture/fullscreen profile 需要实机环境；Phase 35 使用 fake-port 验证生命周期，Phase 38 再收集真实 profile 证据。[VERIFIED: .planning/ROADMAP.md:61-73]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | Flutter `flutter_test`（SDK）；本机 Flutter 3.44.8。 [VERIFIED: pubspec.yaml:39-44; local `flutter --version` 2026-08-11] |
| Config file | `pubspec.yaml`；未发现独立 test config。 [VERIFIED: pubspec.yaml:1-70] |
| Quick run command | `flutter test test/widget/shared/glass_button_test.dart test/widget/player/player_video_controls_test.dart test/widget/player/player_screen_accessibility_resize_test.dart test/widget/player/player_screen_stop_empty_state_test.dart test/widget/player/player_keyboard_actions_test.dart test/widget/player/drop_handler_test.dart test/integration/controls_flow_test.dart test/integration/error_propagation_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| BASE-01 | historical tree is inspected without overwrite | source/history audit | `git diff --check && git diff --stat e0083842..HEAD -- ...` | N/A（planning evidence） |
| BASE-02 | current controls chain remains | widget/source contract | targeted quick command | ✅ `player_video_controls_test.dart` |
| BASE-03 | playback/seek/volume/speed/subtitle/fullscreen/ESC/empty/error/drop/keyboard | widget + integration | targeted quick command | ✅（但真实 OS drop/fullscreen 仍人工） |
| BASE-04 | latest GlassButton callback invoked after rebuild | widget | `flutter test test/widget/shared/glass_button_test.dart` | ✅，label-path gap 为 Wave 0 |
| BASE-05 | source/reparent/dispose/padding isolation | widget | `flutter test test/widget/player/player_video_controls_test.dart` | ✅ |

### Sampling Rate

- **Per task commit:** 运行该任务修改文件的最小测试命令，再运行 `flutter analyze` 与 `git diff --check`。
- **Per wave merge:** 运行上表 quick command。
- **Phase gate:** `flutter analyze`、quick command、`flutter test`（允许按既有 FFI 基线隔离失败）和 `git diff --check`。

### Wave 0 Gaps

- [ ] `test/widget/shared/glass_button_test.dart`：补 label-mode callback replacement（同 State、同 FocusNode、rebuild 后 latest callback）。
- [ ] 新增或扩展 PlayerScreen widget test：替换 `WindowBridge` 后断言标题栏静态行与动态 maximize 行均绑定新 bridge，旧 bridge 不再有可见影响。
- [ ] `test/widget/player/player_video_controls_test.dart`：将 source replacement 后旧 resize notifier/currentFileName/旧 subtitle port 的无副作用断言显式化。
- [ ] 真实 Windows 手测清单（不放进 headless gate）：F/双击进入全屏、ESC 退出、字幕避让、拖放、连续最大化/还原/resize、标题栏 drag/pin/minimize/close。

### Headless FFI 注意事项

- 项目记忆记录：headless `flutter test` 约 57 个既有失败可由 `mdk.dll` FFI 加载引起，须以 stash/re-run 和模块边界区分，不能直接归咎 Phase 35。[ASSUMED]
- 本阶段的 `PlayerScreen` 支持 `videoSurfaceBuilder` + `testVideoControls`，代码明确说明其目的是避免 widget test 绑定 MDK/libmpv 原生运行时；应优先用该装配。[VERIFIED: lib/ui/player/player_screen.dart:28-42, 333-344]
- 本研究执行的 8 文件 targeted suite 已 **78 passed**，未触发 FFI 加载失败；这说明以上 quick gate 可作为 Phase 35 首选自动化验证。[VERIFIED: local targeted `flutter test` executed 2026-08-11]
- 若完整 `flutter test` 遇到 engine/kernel 的 `mdk.dll` 失败，先在 clean/stashed HEAD 上复跑同一命令并保存失败列表；仅新增、位置变化或 Phase 35 触达模块的失败才作为回归处理。[ASSUMED]

## Security Domain

本阶段没有认证、会话、数据库、网络 API 或密码学实现；安全工作重点是本地文件与平台边界不扩大。

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | 不在范围。 [VERIFIED: .planning/REQUIREMENTS.md:6-13] |
| V3 Session Management | no | 不在范围。 [VERIFIED: .planning/REQUIREMENTS.md:6-13] |
| V4 Access Control | no | 不在范围。 [VERIFIED: .planning/REQUIREMENTS.md:6-13] |
| V5 Input Validation | yes（字幕/拖放文件入口保持既有边界） | 保留 `SubtitlePathValidator.isLoadableLocalFile`，不因 widget tree 恢复绕过它。 [VERIFIED: lib/ui/player/player_screen.dart:116-135] |
| V6 Cryptography | no | 不在范围。 [VERIFIED: .planning/REQUIREMENTS.md:6-13] |

| Threat Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| 将 picker 返回路径直接送入底层加载 | Tampering | 保留 picker 返回后、原生加载前的本地路径/类型/大小复核。 [VERIFIED: lib/ui/player/player_screen.dart:125-135] |
| widget test 为方便而改用真实原生播放器 | Denial of Service / instability | 使用 injected surface 与 fake ports，避免 CI/headless FFI 依赖。 [VERIFIED: lib/ui/player/player_screen.dart:28-42; test/helpers/fake_video_controls.dart:6-10] |

## Project Constraints (from CLAUDE.md)

- 使用 Flutter 标准命令：`flutter analyze`、`flutter test`；状态管理保持 ValueNotifier/ValueListenableBuilder，不引入 Provider/Riverpod/Bloc。[VERIFIED: CLAUDE.md:5-12, 82-87]
- 所有视觉值走 `Tokens.*`；玻璃风格保持 `BackdropFilter + bgGlass + borderHighlight`；日志用 `debugPrint` 而非 `print`；错误必须记录并提供 graceful fallback。[VERIFIED: CLAUDE.md:106-119]
- 新增/修改公开类、mixin、非平凡函数要写 `///`；复杂/副作用/魔法值逻辑写“why”注释；代码应同步注释而不是事后补。[VERIFIED: CLAUDE.md:180-191]
- 避免 `!`、`late`、`as`；局部变量优先 final；函数少于 50 行、文件少于 500 行；指定异常类型，不能 bare catch 或吞 `Error`。[VERIFIED: CLAUDE.md:197-224]
- Future 必须 await 或 `unawaited()`；await 后使用 BuildContext 前检查 `context.mounted`；并行 Future 用 `Future.wait`。[VERIFIED: CLAUDE.md:262-267]
- tests 使用 fakes 优于复杂 mocks；不跳过或删除断言；widget tests 作为 integration tests；测试 controller 名称唯一。[VERIFIED: CLAUDE.md:249-254]
- Win32 桥接使用 `dart:ffi`，不恢复旧 `com.simple_player/window` MethodChannel。[VERIFIED: CLAUDE.md:241-247]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | GlassButton 仍需补 label-mode callback replacement test，icon-only coverage不足以保证 label path。 | Current Behavior Contract / High-Risk Test Plan | 若两个 build path 的 wiring 未来分叉，会遗漏 stale callback 回归。 |
| A2 | headless 全套件约 57 项 `mdk.dll` 失败为既有问题。 | Headless FFI 注意事项 | 若未在干净基线复跑就豁免，可能掩盖真实回归。 |
| A3 | 完整 `flutter test` 中的 FFI 失败应采用 stash/re-run 对比隔离。 | Headless FFI 注意事项 | 需要执行者按当日环境重新验证基线。 |

## Open Questions

1. **WindowBridge replacement 是只测 PlayerScreen 标题栏，还是连 `PlayerActions`/keyboard 闭包一起测？**
   - What we know: `_actions` 是 `initState` 一次构造，但其 fullscreen closure 每次调用读取 `widget.windowService`；标题栏有明确 cache replacement 代码。[VERIFIED: lib/ui/player/player_screen.dart:101-105, 143-170, 212-220]
   - What's unclear: 目前没有同一 State bridge replacement 的 widget test。
   - Recommendation: 一个 PlayerScreen integration-style widget test 同时覆盖 title bar 点击和 F 键切换 mode，断言均只影响 replacement bridge。[ASSUMED]

2. **真实 media_kit fullscreen route 是否应纳入 Phase 35 自动化？**
   - What we know: fake-port tests 已验证 route-local 方法选择；真实 native surface 在 headless 环境不可靠。[VERIFIED: test/widget/player/player_video_controls_test.dart:885-926; lib/ui/player/player_screen.dart:28-42]
   - What's unclear: Windows GUI 可用性与 media_kit route 是否可在 CI 稳定驱动。
   - Recommendation: Phase 35 锁 fake-port 合约，Phase 38 以 Windows 手测/profile 作为真实 route evidence。[ASSUMED]

## Sources

### Primary (HIGH confidence)

- 本地当前源码：`lib/ui/player/player_screen.dart`、`player_video_controls.dart`、`control_bar.dart`、`lib/ui/shared/glass_container.dart`、`lib/ui/window/custom_title_bar.dart`、`lib/kernel/bridge/window_bridge.dart`、`window_service.dart` — 当前 widget tree、lifecycle、bridge 与 resize 行为。
- 本地当前测试：`test/widget/shared/glass_button_test.dart`、`test/widget/player/player_video_controls_test.dart`、`player_screen_accessibility_resize_test.dart`、`player_screen_stop_empty_state_test.dart`、`test/unit/kernel/bridge/window_service_test.dart` — 行为契约与测试缺口。
- 本地 Git commits：`e0083842`、`d0ba3898`、`f590cce2`、`6e0edbb8` — controls、GlassButton、resize 与 title-bar 演进。
- 本机运行：`flutter --version`、`flutter analyze`、targeted `flutter test`、`git diff --check`（2026-08-11）。

### Secondary (MEDIUM confidence)

- [Flutter focus documentation](https://docs.flutter.dev/ui/interactivity/focus) — `FocusableActionDetector` 组合 Actions/Shortcuts/Focus/MouseRegion。
- [Flutter state lifecycle overview](https://docs.flutter.dev/learn/pathway/how-flutter-works) — StatefulWidget State lifecycle 概览。

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 由 `pubspec.yaml`、本机 Flutter/Dart 版本与现有源代码核验。
- Architecture: HIGH — 当前源代码、Git commit history 和 78 项 targeted tests 交叉验证。
- Pitfalls: HIGH — 直接来自 current lifecycle guards、注释和 reparent/source replacement tests；Flutter 文档对通用 Focus 模式为 MEDIUM。

**Research date:** 2026-08-11  
**Valid until:** 2026-09-10（在 PlayerScreen/PlayerVideoControls/WindowBridge 未改变前）
