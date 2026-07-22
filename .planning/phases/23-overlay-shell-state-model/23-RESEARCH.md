# Phase 23: Overlay Shell & State Model - Research

**Researched:** 2026-07-22
**Domain:** Flutter 桌面 UI 覆盖层架构 / ValueNotifier 状态模型 / 绞杀者模式（Strangler）重构
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 就地拆 `lib/ui/dialogs/settings_panel.dart`（实测 945 行），提取 `SettingsPanelState` + `SettingsPanelController` 到**已存在**的 `lib/ui/dialogs/settings/` 子目录。渐进 Strangler 重构，不新建并列目录，不动 `lib/kernel/`。
- **D-02:** 构造注入 `SettingsPanelController(playbackController)`，组合根（`app.dart` / `PlayerServices`）装配。不用 DI 框架 / 服务定位 / `BuildContext` 取依赖。
- **D-03:** `open()` 调 `PlaybackController.pause()`（**经编排器，不直碰 `MediaEngine`**，避免与 `openGeneration` 守卫竞态）；`wasPlaying = MediaEngine.isPlaying` notifier 快照；打开前已暂停则 `wasPlaying=false`，`close()` 不恢复播放；`close()` 仅在 `wasPlaying=true` 时恢复。
- **D-04:** Phase 23 的 `SettingsPanelState` 仅持 3 个 notifier（`isOpen`/`selectedTab`/`dragOffset` per PANEL-01）。现有 `_pendingLocale`/`_pendingThemeIndex`/`_originalShortcuts` 延迟应用状态**暂留 widget 本地**，Phase 25（TABS-04）再迁移，Phase 23 不触及。
- **D-05:** **Stack in-tree**（跟随 `playlist_panel.dart` 既有模式，非 showDialog）。覆盖层（遮罩 + 面板）作为 `PlayerScreen` Stack 的一层，由 `isOpen` notifier 控制可见性与动画；遮罩与面板为 Stack 兄弟节点，遮罩 `GestureDetector` 点击关闭（PANEL-05）。面板关闭时 `IgnorePointer`/`Visibility` 卸载命中。
- **D-06:** **壳取代触发器**（Strangler 渐进）。新壳骨架就位后接管设置入口触发器（齿轮按钮 / 快捷键）；tab 内容复用旧 `settings/` 7 文件；老 `settings_panel.dart`（showDialog，945 行）在新壳能完整取代后于**独立提交**删除（永不与 feature 捆绑）。
- **D-07:** `AnimatedOpacity` + `AnimatedScale`（PANEL-05 锁定，Scale + Fade）；时长 **200ms** 与 P24 侧边栏 `FadeTransition` 一致。
- **D-08:** 采用 `lib/ui/shared/apple_curves.dart`。该文件当前**未跟踪**（untracked），Phase 23 须先将其纳入 git 并核实其曲线 API 再采用。
- **D-09:** **in-canvas 拖拽**更新 `dragOffset` notifier（PANEL-01），clamp 到 `MediaQuery` 窗口边界（承袭"不可拖出播放器窗口"）。`custom_title_bar.dart` 拖的是 OS 窗口、PANEL-04 拖的是面板 — 语义不同，仅作**手势模式类比**，非直接复用。
- **D-10:** **面板自管 Focus subtree**（`FocusTraversalGroup`）。面板打开时 ESC/B 优先关面板且**不触发既有全屏切换**；面板关闭后 ESC 恢复既有全屏切换行为。不与 `keyboard_handler.dart` 统一分发重叠，面板自带独立键盘作用域。

### Claude's Discretion

无 — 用户对全部 4 领域均作出明确选择，未出现 "you decide" 延迟。

### Deferred Ideas (OUT OF SCOPE)

无 — tab 内容框架、手柄导航、响应式缩放分别属 Phase 25/26/27，未在本次讨论引入新范围。
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PANEL-01 | `SettingsPanelState` 状态模型 — `ValueNotifier<bool> isOpen`、`ValueNotifier<int> selectedTab`、`ValueNotifier<Offset> dragOffset`；视频暂停/恢复由 `PlaybackController` 协调 | 见 Architecture Pattern 1（状态模型）+ D-03 gap 分析（`PlaybackController.pause()`/`isPlaying` 不存在，须加转发器）|
| PANEL-02 | `SettingsPanelController` — `open()`/`close()`/`toggle()` 方法，打开时暂停视频并记录 `wasPlaying`，关闭时恢复先前状态 | 见 Pattern 2（控制器生命周期）+ Common Pitfall 1（无 `isPlaying` notifier，须从 `engine.state.value == MediaState.playing` 派生）|
| PANEL-03 | 毛玻璃覆盖层壳 — `BackdropFilter(sigmaX/Y)` + `bgGlass` + `borderHighlight`，居中定位，拖拽约束在窗口内 | 见 Pattern 3（覆盖层挂载）+ 复用 `GlassContainer`（已验证 383 行，`GlassTier.normal` sigma=11.5）|
| PANEL-04 | 标题栏 — 左侧 "设置" 文字 + 右侧 × 关闭按钮（`GlassIconButton`），拖拽区域仅标题栏 | 见 Pattern 4（in-canvas 拖拽 clamp）；关闭按钮复用 `GlassButton.iconOnly`（`glass_container.dart:211`）|
| PANEL-05 | 遮罩层 — 半透明遮罩覆盖整个播放器，点击遮罩关闭面板，`AnimatedOpacity` + `AnimatedScale` 开关动效 | 见 Pattern 3 + D-08 曲线推荐（open=`fullscreenEnter` ease-out / close=`fullscreenExit` ease-in，200ms）|
| PANEL-06 | 键盘关闭 — `ESC` 和 `B` 键关闭面板（`FocusTraversalGroup` 内 `LogicalKeySet` 处理）| 见 Pattern 5（Focus subtree 自管）+ Pitfall 2（ESC 不冒泡至 `KeyboardHandler.onExitFullscreen`）|
| PANEL-07 | 面板尺寸 — 500×400 基础尺寸，全屏时按窗口比例缩放（`MediaQuery.size` 计算），最大不超过窗口 80% | 见 Pattern 3 尺寸约束；`MediaQuery.size` clamp 逻辑在 `build` 内计算 |
</phase_requirements>

## Summary

Phase 23 是 v4.0 的第一个阶段，目标是绘制设置面板的**覆盖层壳骨架**（毛玻璃 + 遮罩 + 标题栏）并建立 `SettingsPanelState`/`SettingsPanelController` 状态模型与开/关/暂停/恢复生命周期。本阶段**不实现** tab 内容与具体设置项（属 Phase 25），仅建壳 + 3 个 ValueNotifier + 控制器。

研究覆盖了全部 7 项 canonical references 的 LIVE 代码，核心发现如下：

1. **D-08 `apple_curves.dart` 已完全核实**：文件确认 UNTRACKED（`git ls-files --error-unmatch` 返回 error），在盘但未入 git index。API 枚举出 7 个静态 `Cubic` 常量，头注释明确 Apple HIG 约定（enter=ease-out 快启慢停 / exit=ease-in 加速离场）。推荐 open 用 `fullscreenEnter`、close 用 `fullscreenExit`，overshoot 曲线（`controlBarSlide`/`elasticEnter`）**不适合**居中模态的 Scale 动画。Phase 23 首任务须 `git add` 该文件锁定 API。

2. **D-03 存在两个落地缺口**（planner 必须处理）：(a) `PlaybackController` 门面**没有** `pause()`/`play()` 转发方法 — UI 现状直接调 `widget.engine.togglePlayPause()`；D-03 要求"经编排器，不直碰 MediaEngine"，故须在 `PlaybackController` 加 `void pause()`/`void play()` 薄转发器 + `bool get isPlaying` 便捷 getter。(b) 引擎**没有** `isPlaying` ValueNotifier — `EngineStateView` 暴露的是 `ValueNotifier<MediaState> state`（6 态枚举）；`wasPlaying` 快照须从 `engine.state.value == MediaState.playing` 派生。

3. **最强类比 `playlist_panel.dart`（357 行）已验证**：Stack（Positioned.fill GestureDetector 点击外部关闭 + Positioned 浮窗）+ FadeTransition + BackdropFilter（`GlassTier.thick.blurFilter` 缓存实例）+ Focus(onKeyEvent ESC) + resize-skip-BackdropFilter 守卫（line ~181，避免 GPU readback 卡顿）。新设置覆盖层应镜像此结构，但用 `AnimatedScale`+`AnimatedOpacity`（PANEL-05）替换 Slide+Fade，且居中（`Alignment.center`）而非右下角。

4. **挂载点 D-05 已定位**：`player_screen.dart` 有两处 Stack — 内层 `_buildVideoContent` Stack（line 333，VideoSurface + overlays + ControlsOverlay）和外层窄屏 Stack（line 276，videoContent + playlistPanel）。设置模态覆盖整个播放器（含控制栏与播放列表面板），应作为**最顶层**兄弟节点。推荐方案：在窄屏 Stack（line 276）与宽屏 Row（line 256）之外，用 `ValueListenableBuilder<bool>(isOpen)` 包裹的最外层 Stack 挂载遮罩 + 面板，确保覆盖控制栏与播放列表面板。

5. **D-06 cutover 触发器已定位**：`app.dart:66 _showSettingsPanel()` → `showDialog` → `SettingsPanel`（line 72-82）；`PlayerScreen.onSettings` callback（`app.dart:171`）→ 齿轮按钮 `right_button_group.dart:46`。新壳就位后，`onSettings` 触发器改为调 `settingsPanelController.open()`，覆盖层由 `isOpen` notifier 驱动显隐；老 `settings_panel.dart` 在新壳完整取代后于**独立提交**删除。

**Primary recommendation:** Phase 23 的实现顺序应为：(1) `git add lib/ui/shared/apple_curves.dart` 锁定曲线 API → (2) 在 `PlaybackController` 加 `pause()`/`play()` 转发器 + `isPlaying` getter → (3) 在 `lib/ui/dialogs/settings/` 落地 `SettingsPanelState` + `SettingsPanelController` → (4) 在 `PlayerScreen` Stack 挂载覆盖层壳（遮罩 + 毛玻璃面板 + 标题栏 + 拖拽 clamp + ESC/B Focus）→ (5) cutover 触发器（`onSettings` → `controller.open()`）→ (6) 独立提交删除老 `settings_panel.dart`。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 面板开/关状态（isOpen/selectedTab/dragOffset）| App State (ValueNotifier) | — | 3 notifier 状态模型属应用层，无跨层持久化，PANEL-01 锁定 ValueNotifier 不引新框架 |
| 视频暂停/恢复契约 | Service (PlaybackController) | Kernel (MediaEngine) | D-03 经编排器协调；`PlaybackController` 门面转发 `engine.pause()/play()`，UI 不直碰引擎 |
| wasPlaying 快照与恢复 | Service (SettingsPanelController) | Service (PlaybackController) | 控制器持有快照，经 `PlaybackController.isPlaying` 读取 + `pause()/play()` 写入 |
| 覆盖层挂载与动画 | UI (PlayerScreen Stack) | — | D-05 in-tree Stack 组合，`AnimatedScale`+`AnimatedOpacity` + BackdropFilter |
| 拖拽 clamp | UI (面板标题栏 GestureDetector) | UI (MediaQuery 窗口边界) | D-09 in-canvas 拖拽更新 `dragOffset`，clamp 到 `MediaQuery.size` |
| 键盘关闭（ESC/B）| UI (面板 Focus subtree) | — | D-10 面板自管 `FocusTraversalGroup`，ESC/B 优先关面板不冒泡至 `KeyboardHandler` |
| 毛玻璃视觉 | UI (GlassContainer) | UI (Tokens.*) | 复用 `GlassContainer` + `GlassTier.normal` + `bgGlass` + `borderHighlight` |
| 动画曲线 | UI (apple_curves.dart) | — | D-08 锁定 `AppleCurves.fullscreenEnter`/`fullscreenExit` |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK (AnimatedScale/AnimatedOpacity) | Flutter 3.x stable | PANEL-05 Scale+Fade 开关动效 | 隐式动画 Widget，无新依赖，项目已全局依赖 Flutter [VERIFIED: codebase — playlist_panel.dart 用 FadeTransition；settings_panel.dart 用 AnimatedAlign/AnimatedSwitcher] |
| ValueNotifier + ValueListenableBuilder | Flutter foundation | PANEL-01 状态模型（3 notifier）| 项目既有状态管理约定，CLAUDE.md 明确"不引新框架" [VERIFIED: codebase — PlaybackController.currentFileName / playlist_panel._selectedTab / settings_panel._offset] |
| BackdropFilter + ImageFilter | dart:ui | PANEL-03 毛玻璃壳 | 既有 `GlassContainer`（383 行）封装，3 级 blur + 缓存 ImageFilter [VERIFIED: codebase — glass_container.dart] |
| Focus + FocusTraversalGroup + onKeyEvent | Flutter widgets | PANEL-06 键盘关闭 + D-10 自管 Focus | 项目既有模式（playlist_panel Focus+onKeyEvent ESC；settings_panel Focus+onKeyEvent ESC）[VERIFIED: codebase] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AppleCurves (in-tree, untracked) | — | D-08 动画曲线 | open 用 `fullscreenEnter`(ease-out) / close 用 `fullscreenExit`(ease-in)，200ms [CITED: lib/ui/shared/apple_curves.dart 头注释 Apple HIG] |
| GlassContainer / GlassTier | in-tree | PANEL-03 毛玻璃复用 | `GlassTier.normal`（sigma=11.5）匹配控制栏设计语言；`blurFilter` 缓存实例避免每帧分配 [VERIFIED: codebase — glass_container.dart] |
| Tokens.* | in-tree | 全视觉值 | radiusLg(22)/spMd(12)/fontBody(14)/bgGlass/borderHighlight/durationFast(80) 等 [VERIFIED: codebase — tokens.dart] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AnimatedScale + AnimatedOpacity（隐式）| AnimationController + ScaleTransition + FadeTransition（显式）| 隐式更简单，PANEL-05 锁定 AnimatedScale+AnimatedOpacity；显式适合需要中途取消/复杂时序的场景 — 本阶段不需要 |
| Stack in-tree（D-05）| showDialog（现状）| D-05 已锁 Stack in-tree；showDialog 会被新壳取代并删除（D-06）|
| apple_curves.dart（D-08）| Curves.easeOut / Curves.easeIn（Flutter 内置）| D-08 锁定 apple_curves 以匹配项目既有 Apple HIG 手感；内置 Curves 是 fallback 但手感略异 |

**Installation:**
```bash
# 无新依赖 — 本阶段纯用 in-tree 组件 + Flutter SDK
# 唯一前置动作：将未跟踪的 apple_curves.dart 纳入 git
git add lib/ui/shared/apple_curves.dart
```

**Version verification:** 本阶段无新增第三方包，所有依赖已在 `pubspec.yaml`（Flutter SDK / window_manager / fvp / file_picker 等既有）。无须 `npm view` / `pip index versions` / `cargo search`。

## Package Legitimacy Audit

> 本阶段**不安装任何外部包** — 所有实现基于 Flutter SDK + in-tree 组件（GlassContainer / Tokens / AppleCurves / ValueNotifier）。Package Legitimacy Gate 不适用（无新 npm/PyPI/crates 包）。

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | — | — | — | — | N/A | No new packages this phase |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
[用户点击齿轮按钮 / 按快捷键]
        │
        ▼
[PlayerScreen.onSettings callback]  ──cutover──▶  [SettingsPanelController.open()]
                                                       │
                                                       ├─▶ PlaybackController.pause()   (新增薄转发器)
                                                       │       └─▶ MediaEngine.pause()   (state→paused)
                                                       ├─▶ wasPlaying = PlaybackController.isPlaying  (新增 getter, 读 state==playing)
                                                       └─▶ SettingsPanelState.isOpen.value = true
                                                       │
        ┌────────────────────────────────────────────┘
        ▼
[PlayerScreen Stack (D-05 挂载点)]
   ├─ [videoContent (VideoSurface + ControlsOverlay + PlaybackStatusOverlay)]  ◀── IgnorePointer when isOpen
   ├─ [PlaylistPanel (既有, 闭合时不受影响)]
   └─ [SettingsOverlayLayer (新, ValueListenableBuilder<bool> isOpen)]   ◀── 顶层兄弟
        ├─ [遮罩 GestureDetector onTap→close()  (半透明, AnimatedOpacity)]
        └─ [面板 (AnimatedScale + AnimatedOpacity, Alignment.center)]
             ├─ [GlassContainer (BackdropFilter + bgGlass + borderHighlight)]
             ├─ [标题栏 GestureDetector onPanUpdate→dragOffset += delta (clamp to MediaQuery)]
             │     ├─ Text "设置"
             │     └─ GlassButton.iconOnly(icons.close) → close()
             └─ [内容占位 (Phase 25 tab 内容挂入点)]

[ESC / B 键] ─▶ [面板 Focus subtree onKeyEvent] ─▶ close()  (不冒泡至 KeyboardHandler.onExitFullscreen)
[点击遮罩]   ─▶ [遮罩 GestureDetector onTap]   ─▶ close()

[close()]
   ├─▶ SettingsPanelState.isOpen.value = false
   ├─▶ if (wasPlaying) PlaybackController.play()  (新增薄转发器)
   └─▶ (动画 200ms 反向播放, 面板卸载命中 via IgnorePointer/Visibility)
```

### Recommended Project Structure
```
lib/ui/dialogs/settings/
├── settings_panel_state.dart         # SettingsPanelState (3 ValueNotifier: isOpen/selectedTab/dragOffset) [PANEL-01]
├── settings_panel_controller.dart     # SettingsPanelController (open/close/toggle + wasPlaying 快照) [PANEL-02]
├── settings_overlay_shell.dart       # 覆盖层壳 (Stack: 遮罩 + 面板 + 动画 + 拖拽 + Focus) [PANEL-03/04/05/06/07]
├── _settings_nav_item.dart           # 既有 — tab 导航项
├── about_tab.dart                   # 既有 — Phase 25 复用
├── audio_tab.dart                   # 既有
├── equalizer_tab.dart               # 既有
├── general_tab.dart                 # 既有
├── settings_tab_performance.dart    # 既有
├── shortcuts_tab.dart               # 既有
└── video_tab.dart                   # 既有
lib/ui/dialogs/settings_panel.dart    # 既有 945 行 — 重写对象, Phase 23 末独立提交删除 [D-06]
lib/ui/shared/apple_curves.dart      # 未跟踪 — Phase 23 首任务 git add 锁定 [D-08]
lib/kernel/services/playback_controller.dart  # 加 pause()/play() 转发器 + isPlaying getter [D-03 gap]
```

### Pattern 1: SettingsPanelState — 3 ValueNotifier（PANEL-01）
**What:** 纯状态容器，持有恰好 3 个 ValueNotifier，无业务逻辑。
**When to use:** PANEL-01 锁定；D-04 明确 `_pending*`/`_original*` 不迁入，留 widget 本地。
**Example:**
```dart
// Source: 项目既有模式（playlist_panel._selectedTab / settings_panel._offset）+ D-04 边界
class SettingsPanelState {
  SettingsPanelState();
  final ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);
  final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);
  final ValueNotifier<Offset> dragOffset = ValueNotifier<Offset>(Offset.zero);

  void dispose() {
    isOpen.dispose();
    selectedTab.dispose();
    dragOffset.dispose();
  }
}
```

### Pattern 2: SettingsPanelController — open/close 生命周期 + wasPlaying 快照（PANEL-02, D-03）
**What:** 控制器经 `PlaybackController` 协调暂停/恢复，持有 `wasPlaying` 快照。
**When to use:** PANEL-02；D-03 "经编排器，不直碰 MediaEngine"。
**Example:**
```dart
// Source: D-03 暂停契约 + D-02 构造注入
class SettingsPanelController {
  SettingsPanelController(this._playback);
  final PlaybackController _playback;
  final SettingsPanelState state = SettingsPanelState();
  bool _wasPlaying = false;

  void open() {
    if (state.isOpen.value) return;
    _wasPlaying = _playback.isPlaying;          // 新增 getter: engine.state.value == MediaState.playing
    if (_wasPlaying) _playback.pause();          // 新增薄转发器: engine.pause()
    state.isOpen.value = true;
  }

  void close() {
    if (!state.isOpen.value) return;
    state.isOpen.value = false;
    if (_wasPlaying) _playback.play();          // 新增薄转发器: engine.play()
    state.dragOffset.value = Offset.zero;        // 关闭后重置偏移
  }

  void toggle() => state.isOpen.value ? close() : open();
  void dispose() => state.dispose();
}
```

### Pattern 3: 覆盖层挂载 — Stack in-tree（D-05, PANEL-03/05/07）
**What:** 遮罩 + 面板作为 `PlayerScreen` Stack 顶层兄弟，由 `isOpen` notifier 驱动显隐与动画。
**When to use:** D-05 锁定；镜像 `playlist_panel.dart` 既有 Stack 模式。
**Example:**
```dart
// Source: playlist_panel.dart Stack 结构 + PANEL-05 AnimatedScale+AnimatedOpacity
ValueListenableBuilder<bool>(
  valueListenable: controller.state.isOpen,
  builder: (context, open, _) {
    if (!open) return const SizedBox.shrink();   // 卸载命中
    return Stack(
      children: [
        // 遮罩层 — 点击关闭 (PANEL-05)
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: open ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: AppleCurves.fullscreenEnter,   // D-08
            child: GestureDetector(
              onTap: controller.close,
              child: Container(color: Colors.black54),
            ),
          ),
        ),
        // 面板 — 居中, Scale+Fade (PANEL-05/07)
        Center(
          child: AnimatedScale(
            scale: open ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 200),
            curve: AppleCurves.fullscreenEnter,   // D-08 open=ease-out
            child: AnimatedOpacity(
              opacity: open ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: AppleCurves.fullscreenEnter,
              child: _buildPanel(controller),    // GlassContainer + 标题栏 + 占位内容
            ),
          ),
        ),
      ],
    );
  },
)
```

### Pattern 4: in-canvas 拖拽 clamp（D-09, PANEL-04）
**What:** 标题栏 `GestureDetector.onPanUpdate` 更新 `dragOffset`，clamp 到 `MediaQuery` 窗口边界。
**When to use:** D-09；与 `custom_title_bar.dart` 拖 OS 窗口语义不同，仅手势模式类比。
**Example:**
```dart
// Source: settings_panel.dart 既有 _offset.value += d.delta + D-09 clamp 要求
GestureDetector(
  onPanUpdate: (d) {
    final size = MediaQuery.of(context).size;
    final panelW = 500.0, panelH = 400.0;   // PANEL-07 基础尺寸
    // clamp 到窗口内, 面板中心不可超出窗口边界
    final next = controller.state.dragOffset.value + d.delta;
    final maxX = (size.width - panelW) / 2;
    final maxY = (size.height - panelH) / 2;
    controller.state.dragOffset.value = Offset(
      next.dx.clamp(-maxX, maxX),
      next.dy.clamp(-maxY, maxY),
    );
  },
  child: /* 标题栏 */,
)
```

### Pattern 5: 面板自管 Focus subtree — ESC/B 不冒泡（D-10, PANEL-06）
**What:** 面板用 `Focus`/`FocusTraversalGroup` 自管键盘，ESC/B 优先关面板且不触发 `KeyboardHandler.onExitFullscreen`。
**When to use:** D-10；modal overlay 优先消费 ESC 惯例。
**Example:**
```dart
// Source: playlist_panel.dart Focus+onKeyEvent ESC 模式 + settings_panel._handleEscape
Focus(
  autofocus: true,
  onKeyEvent: (node, event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.keyB) {   // PANEL-06: ESC + B
      controller.close();
      return KeyEventResult.handled;   // 不冒泡至 KeyboardHandler.onExitFullscreen
    }
    return KeyEventResult.ignored;
  },
  child: /* 面板 */,
)
```

### Anti-Patterns to Avoid
- **直碰 MediaEngine**: `SettingsPanelController` 调 `engine.pause()` 绕过 `PlaybackController` 违反 D-03；与 `openGeneration` 守卫竞态风险。**改用** `PlaybackController.pause()` 转发器。
- **用 showDialog 挂载**: 违反 D-05（Stack in-tree 已锁）；showDialog 路线正是被取代的老实现。
- **用 overshoot 曲线做 Scale**: `AppleCurves.controlBarSlide`/`elasticEnter` 是 overshoot 曲线，居中模态 Scale 会"过冲回弹"，对设置面板显得轻浮/不专业。**改用** `fullscreenEnter`/`fullscreenExit`。
- **跨提交捆绑删除老文件**: D-06 明确老 `settings_panel.dart` 须在独立提交删除，永不与 feature 捆绑。
- **重包装现有 notifier 实例**: 承袭 v3.0 ADAPT-03 约束 — `SettingsPanelState` 的新 notifier 是**新创建**的（isOpen/selectedTab/dragOffset 不存在既有实例），不涉及转发；但若 Phase 25 迁移 `selectedTab` 时须注意：若复用既有 `_selectedIndex` 须转移实例非重包装。Phase 23 的 3 notifier 全新创建，无此风险。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 毛玻璃模糊 | 手写 `BackdropFilter` + 每帧 `ImageFilter.blur` | `GlassContainer`（383 行，3 级 blur + 缓存 ImageFilter + resize-skip 守卫）| 已封装 GPU readback 优化（D-10/D-11/D-13/D-14），手写会丢失缓存与降级逻辑 [VERIFIED: codebase — glass_container.dart] |
| 动画曲线 | 手写 `Cubic(...)` 试参 | `AppleCurves.fullscreenEnter`/`fullscreenExit` | D-08 锁定，已对齐 Apple HIG，头注释文档化约定 [CITED: apple_curves.dart] |
| 拖拽 clamp | 手写边界检测函数 | `Offset.clamp` + `MediaQuery.size` 计算 | Dart `clamp` 是内置；逻辑仅 2 行（见 Pattern 4）|
| 键盘关闭 | 重写全局键盘分发 | 面板内 `Focus` + `onKeyEvent` 返回 `KeyEventResult.handled` | 既有模式（playlist_panel / settings_panel），`handled` 阻止冒泡 [VERIFIED: codebase] |
| 状态管理 | 引入 Provider/Riverpod/Bloc | `ValueNotifier` + `ValueListenableBuilder` | CLAUDE.md / PANEL-01 明确不引新框架 |

**Key insight:** 本阶段全部实现可由 in-tree 组件 + Flutter SDK 隐式动画完成。最大风险不是"缺库"，而是 D-03 的 `PlaybackController.pause()` 缺口与 D-08 的 `apple_curves.dart` 未跟踪状态 — 两者均为"已存在但未接线/未入库"的资产，须在实现前先补齐。

## Common Pitfalls

### Pitfall 1: `PlaybackController.pause()`/`isPlaying` 不存在（D-03 落地缺口）
**What goes wrong:** D-03 写"`open()` 调 `PlaybackController.pause()`"且"`wasPlaying = MediaEngine.isPlaying` notifier 快照"，但 `PlaybackController`（254 行）**没有** `pause()`/`play()` 转发方法，`EngineStateView`（71 行）**没有** `isPlaying` notifier。
**Why it happens:** D-03 用了理想化表述。`PlaybackController` 门面当前只转发 `playNext`/`playPrevious`/`playIndex`/`openAndPlay`/`addFiles`（经 navigator/fileOps），UI 现状直接调 `widget.engine.togglePlayPause()`（`player_screen.dart:170`）。`EngineStateView` 暴露的是 `ValueNotifier<MediaState> state`（6 态枚举），无 `isPlaying` 便捷 notifier。
**How to avoid:** (a) 在 `PlaybackController` 加 `void pause() => engine.pause();` + `void play() => engine.play();` 薄转发器 + `bool get isPlaying => engine.state.value == MediaState.playing;` getter。(b) `wasPlaying` 快照从 `_playback.isPlaying` 读取。三者均小改动，不碰 `openGeneration` 守卫（`pause`/`play` 不触发 open 路径）。
**Warning signs:** 若 planner 直接让 `SettingsPanelController` 调 `playbackController.engine.pause()`，违反 D-03 "不直碰 MediaEngine" — review 时须拦截。

### Pitfall 2: ESC 冒泡触发全屏切换（D-10 竞态）
**What goes wrong:** 面板打开时按 ESC，既触发面板关闭又触发 `KeyboardHandler.onExitFullscreen`（`keyboard_handler.dart:156` `_keyMatches(key, 'exitFullscreen', escape)`），导致面板关闭同时退出全屏。
**Why it happens:** `KeyboardHandler` 是 `PlayerScreen` 的外层 `Focus`（`autofocus: true`），面板 `Focus` 若未正确捕获 ESC 或返回 `ignored`，事件冒泡至外层。
**How to avoid:** 面板 `Focus` 用 `autofocus: true` + `onKeyEvent` 返回 `KeyEventResult.handled` 消费 ESC/B；`FocusTraversalGroup` 包裹面板确保焦点不逃逸。参考 `playlist_panel.dart:162-172` 既有 ESC 处理模式（返回 `handled`）。
**Warning signs:** widget 测试中按 ESC 后 `isOpen` 变 false **且** `windowService.mode` 变 windowed — 须断言 mode 不变。

### Pitfall 3: `apple_curves.dart` 未跟踪导致曲线 API 漂移
**What goes wrong:** 实现期间他人修改/删除 `apple_curves.dart`（未入 git 无保护），曲线名或 Cubic 参数变更，动画行为漂移。
**Why it happens:** 文件当前 UNTRACKED（`git ls-files --error-unmatch` 返回 error，已确认）。
**How to avoid:** **Phase 23 首任务** `git add lib/ui/shared/apple_curves.dart` + 提交，锁定 API。planner 须在 Wave 0/首 plan 前置此步。
**Warning signs:** 实现中引用 `AppleCurves.fullscreenEnter` 报 undefined — 文件被改。

### Pitfall 4: BackdropFilter GPU readback 卡顿（resize/动画期间）
**What goes wrong:** 面板开/关动画期间 BackdropFilter 每帧 GPU readback 导致掉帧。
**Why it happens:** `BackdropFilter` 本身开销高；动画叠加模糊更重。
**How to avoid:** 复用 `GlassContainer` 的 `opacity` 参数（`< 0.01` 跳过 BackdropFilter）+ `resizing` 信号守卫（窗口 resize 时跳过）。`playlist_panel.dart:181-198` 已示范此守卫模式。面板 `AnimatedOpacity` 可驱动 `GlassContainer.opacity`，淡出时自动跳过模糊。
**Warning signs:** 动画帧率 < 60fps；profile 模式观察 BackdropFilter 层重建。

### Pitfall 5: 覆盖层未卸载命中导致下层控件接收点击
**What goes wrong:** 面板关闭后（`isOpen=false`），若遮罩/面板仍在 widget 树且未 `IgnorePointer`，点击穿透到下层 `ControlsOverlay` 按钮。
**Why it happens:** `AnimatedOpacity` 动画期间 widget 仍在树中（opacity=0 但仍命中）。
**How to avoid:** D-05 明确"面板关闭时 `IgnorePointer`/`Visibility` 卸载命中"。用 `IgnorePointer(ignoring: !isOpen)` 包裹覆盖层；动画结束后 `Visibility`/条件渲染彻底移除（参考 `playlist_panel._playlistState` 的 `(visible, mounted)` 双态模式）。
**Warning signs:** widget 测试中面板关闭后点击仍命中下层按钮。

## Code Examples

### apple_curves.dart 完整 API（D-08 核实）
```dart
// Source: lib/ui/shared/apple_curves.dart（UNTRACKED, 在盘未入 git）
// 头注释约定（Apple HIG）：进入=ease-out（快启慢停）/ 退出=ease-in（加速离场）

class AppleCurves {
  AppleCurves._();

  // ── 主要动画曲线 ──
  static const fullscreenEnter = Cubic(0.22, 0.61, 0.36, 1.0);  // ease-out — 推荐用于面板 open
  static const fullscreenExit  = Cubic(0.55, 0.0, 0.79, 0.34);  // ease-in  — 推荐用于面板 close

  // ── 元素级曲线 ──
  static const controlBarSlide = Cubic(0.33, 1.0, 0.68, 1.0);   // overshoot — ⚠️ 不适合居中模态 Scale
  static const titleBarFade    = Cubic(0.25, 0.1, 0.25, 1.0);    // 平滑 ease-out

  // ── 辅助曲线 ──
  static const contentScale    = Cubic(0.2, 0.0, 0.0, 1.0);      // iOS ease-out — Scale 维度备选
  static const backgroundFade  = Cubic(0.4, 0.0, 0.2, 1.0);     // Material standard
  static const elasticEnter    = Cubic(0.175, 0.885, 0.32, 1.275); // easeOutBack — ⚠️ overshoot, 不适合居中模态
}
```

### D-08 曲线选择推荐
| 动画维度 | open（进入）| close（退出）| 理由 |
|---------|-------------|-------------|------|
| Scale | `AppleCurves.fullscreenEnter` | `AppleCurves.fullscreenExit` | 匹配 HIG enter=ease-out/exit=ease-in；fullscreenEnter 是代码库中最接近模态进入的曲线 |
| Opacity | `AppleCurves.fullscreenEnter` | `AppleCurves.fullscreenExit` | 与 Scale 同曲线保持节奏一致 |
| **避免** | `controlBarSlide`/`elasticEnter` | — | overshoot 曲线使居中模态"过冲回弹"，对设置面板显得轻浮 |

### PlaybackController 薄转发器（D-03 gap 修复）
```dart
// Source: D-03 要求 + PlaybackControl 接口（playback_control.dart:42/60）
// 在 lib/kernel/services/playback_controller.dart 追加:

/// 暂停播放 — 委托 MediaEngine.pause()（D-03 SettingsPanelController 暂停入口）
void pause() => engine.pause();

/// 恢复播放 — 委托 MediaEngine.play()（D-03 close() 恢复入口）
void play() => engine.play();

/// 是否正在播放 — 从 state notifier 派生（D-03 wasPlaying 快照）
bool get isPlaying => engine.state.value == MediaState.playing;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| showDialog 挂载设置面板 | Stack in-tree + ValueNotifier isOpen 驱动（D-05）| v4.0 Phase 23 | 覆盖层可控动画/拖拽/键盘作用域；摆脱 Navigator 路由限制 |
| 状态散落 StatefulWidget 内（`_selectedIndex`/`_offset`/`_pending*`）| `SettingsPanelState` 3 notifier + 控制器 | v4.0 Phase 23 | 状态可测试、可注入；Phase 25 再迁移 `_pending*` |
| UI 直碰 `engine.togglePlayPause()` | `PlaybackController.pause()/play()` 转发器 | v4.0 Phase 23 | 统一经编排器，符合 D-03 边界 |

**Deprecated/outdated:**
- `lib/ui/dialogs/settings_panel.dart`（945 行 showDialog 路线）：Phase 23 末独立提交删除（D-06）。
- `PROJECT.md` 记的"settings_panel ~500 行"：已过时，实测 945 行（`wc -l` 确认）。

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `AnimatedScale` + `AnimatedOpacity` 隐式动画足以满足 PANEL-07 "流畅无卡顿"（60fps）| Standard Stack / Pattern 3 | 若实测掉帧，须改用显式 `AnimationController` + `RepaintBoundary` 优化；但 playlist_panel 的 FadeTransition 已验证 60fps 可达 |
| A2 | `PlaybackController.pause()`/`play()` 转发器与 `openGeneration` 守卫无竞态（pause/play 不走 open 路径）| Pitfall 1 / Pattern 2 | 若 `engine.pause()` 内部意外触发 state 转换与 openGeneration 交互，须 planner 复核 `fvp_engine.dart:474` pause() 实现 — 但 pause 只做 `state→paused` 转换，不碰 open 路径 |
| A3 | `AppleCurves.fullscreenEnter` 的手感对"居中设置模态"足够贴切（而非需要 `contentScale`）| D-08 推荐 | 主观判断；若用户觉得 fullscreenEnter 不够柔和，可改用 `contentScale`（更柔的 ease-out）。两者均 ease-out 族，差距小 |

## Open Questions (RESOLVED)

1. **覆盖层挂载的精确插入点** — RESOLVED: 在 `PlayerScreen` 的内容区域 Stack 顶层挂载一个 `SettingsOverlayShell`,位于 `CustomTitleBar` 之下,覆盖宽屏 Row 与窄屏 Stack 两种布局(Plan 23-02 Task 2 的 `<action>` 与 key_links 锁定:"mount one SettingsOverlayShell as the topmost content-region Stack child below CustomTitleBar","above both wide/narrow playlist presentations")。
   - What we know: D-05 锁 Stack in-tree；`player_screen.dart` 有两处 Stack（内层 `_buildVideoContent` line 333 / 外层窄屏 line 276）+ 宽屏 Row（line 256）。
   - What's unclear: 覆盖层应插在窄屏 Stack 顶层（覆盖 videoContent + playlistPanel）还是用新外层 Stack 包裹整个 `Scaffold` body（含 CustomTitleBar）？
   - Recommendation: 插在窄屏 Stack 顶层 + 宽屏 Row 之外用 `ValueListenableBuilder<bool>` 包裹的最外层 Stack — 确保覆盖控制栏与播放列表面板但不覆盖 `CustomTitleBar`（标题栏始终可见）。planner 须在首个挂载 task 决定具体 widget 树改造。

2. **SettingsPanelController 的依赖传递路径** — RESOLVED: 经构造注入,`PlayerScreen` 新增 required `settingsPanelController` 构造参(与既有 `controller` 参一致),`PlayerFeature` 组合根从 `_services.controller` 构造 `SettingsPanelController` 并下传、负责 dispose;`App` 与 `DeferredPlayerFeature` 移除旧的 `onSettings` 回调路径(Plan 23-02 Task 2 的 `<action>` 与 artifacts 锁定)。
   - What we know: D-02 组合根（`app.dart` / `PlayerServices`）装配 `SettingsPanelController(playbackController)`。
   - What's unclear: 控制器如何从 `app.dart` 传到 `PlayerScreen`？`PlayerScreen` 现有构造参 `controller: PlaybackController`；须加 `settingsPanelController` 参还是经 `PlayerServices` 全局取？
   - Recommendation: 经构造注入 `PlayerScreen(settingsPanelController: ...)`，与既有 `controller` 参一致；`app.dart` 组合根创建并下传。

## Environment Availability

> 本阶段纯 Flutter UI + 内核薄转发器，无外部工具/服务/CLI 依赖。Step 2.6: SKIPPED（无外部依赖 identified — 仅依赖 Flutter SDK 与 in-tree 组件）。

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | 全阶段 | ✓ | 项目既有 | — |
| `lib/ui/shared/apple_curves.dart` | D-08 动画曲线 | ✓（在盘,未入 git）| — | `git add` 首任务 |
| `lib/ui/shared/glass_container.dart` | PANEL-03 毛玻璃 | ✓ | 383 行 | — |
| `lib/kernel/services/playback_controller.dart` | D-03 暂停契约 | ✓ | 254 行 | 加 pause()/play() 转发器 |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test`（项目既有，`test/` 目录已存在多文件）|
| Config file | `pubspec.yaml`（flutter_test dev_dependency）+ 既有 test/ 约定 |
| Quick run command | `flutter test test/ui/dialogs/settings_panel_state_test.dart test/ui/dialogs/settings_panel_controller_test.dart -x` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PANEL-01 | `SettingsPanelState` 持 3 notifier, 初始值 isOpen=false/selectedTab=0/dragOffset=Offset.zero | unit | `flutter test test/ui/dialogs/settings_panel_state_test.dart -x` | ❌ Wave 0 新建 |
| PANEL-02 | `open()` 暂停视频 + wasPlaying 快照; `close()` 仅 wasPlaying=true 时恢复 | unit | `flutter test test/ui/dialogs/settings_panel_controller_test.dart -x` | ❌ Wave 0 新建 |
| PANEL-02 | `open()` 已打开时 no-op; `close()` 已关闭时 no-op | unit | 同上 | ❌ Wave 0 |
| PANEL-02 | `toggle()` 等价 open/close 切换 | unit | 同上 | ❌ Wave 0 |
| PANEL-03 | 覆盖层 isOpen=true 时渲染 GlassContainer(BackdropFilter + bgGlass + borderHighlight) | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart -x` | ❌ Wave 0 新建 |
| PANEL-04 | 标题栏拖拽更新 dragOffset, clamp 到窗口边界 | widget | 同上 | ❌ Wave 0 |
| PANEL-05 | 点击遮罩调用 close() | widget | 同上 | ❌ Wave 0 |
| PANEL-05 | AnimatedScale + AnimatedOpacity 动画 200ms | widget | 同上（fakeAsync + pump）| ❌ Wave 0 |
| PANEL-06 | ESC 键关闭面板, 不冒泡触发 onExitFullscreen | widget | 同上（KeyEvent 模拟）| ❌ Wave 0 |
| PANEL-06 | B 键关闭面板 | widget | 同上 | ❌ Wave 0 |
| PANEL-07 | 面板基础尺寸 500×400 | widget | 同上 | ❌ Wave 0 |
| PANEL-07 | 面板不超过窗口 80% | widget | 同上（MediaQuery override）| ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/ui/dialogs/settings_panel_state_test.dart test/ui/dialogs/settings_panel_controller_test.dart test/ui/dialogs/settings_overlay_shell_test.dart -x`
- **Per wave merge:** `flutter test`（全量回归 — 注意 mdk.dll headless FFI 预存在失败 ~57 项，非本阶段回归，须 stash/re-run 鉴别）
- **Phase gate:** `flutter analyze` 严格干净 + 上述 3 测试文件全绿 + 全量套件无新增失败

### Wave 0 Gaps
- [ ] `test/ui/dialogs/settings_panel_state_test.dart` — 覆盖 PANEL-01（3 notifier 初始值 + dispose）
- [ ] `test/ui/dialogs/settings_panel_controller_test.dart` — 覆盖 PANEL-02（open/close/toggle + wasPlaying 快照 + 已开/已关 no-op）。需 `FakePlaybackController`（手写 fake，实现 `pause()`/`play()`/`isPlaying` — CLAUDE.md "Fakes over mocks"）
- [ ] `test/ui/dialogs/settings_overlay_shell_test.dart` — 覆盖 PANEL-03/04/05/06/07（widget 测试：挂载/动画/拖拽 clamp/ESC+B/尺寸）
- [ ] `FakePlaybackController`（共享 fixture）— 在 controller 测试中替代 `PlaybackController`，避免真实 MediaEngine（mdk.dll headless FFI 风险）

### Flakiness Risks
- **动画时序断言**: `AnimatedScale`/`AnimatedOpacity` 200ms 动画 — 须用 `tester.pumpAndSettle(const Duration(milliseconds: 200))` 或 `fakeAsync`，避免真实时钟断言。推荐断言"动画结束后 scale==1.0/opacity==1.0"而非中间帧。
- **BackdropFilter GPU**: widget 测试中 `BackdropFilter` 可能无实际 GPU 模糊（headless）— 避免断言像素级模糊效果，改断言 `BackdropFilter` widget 存在性 + `GlassContainer` 层级。
- **Focus subtree 时序**: ESC/B 键测试须 `tester.pump()` 让 Focus 获得焦点后再 `tester.sendKeyEvent`；参考 `playlist_panel` 既有测试模式。
- **mdk.dll headless FFI**: 全量 `flutter test` 有 ~57 预存在 mdk.dll FFI 加载失败（MEMORY.md 记录），非本阶段回归。Wave 0 新测试**不依赖** MediaEngine（用 FakePlaybackController），规避此风险。

## Security Domain

> 本阶段为纯 UI 覆盖层 + 状态模型，无网络/认证/文件系统/加密/SQL 操作。Security enforcement 低风险。本节按协议列出适用类别。

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | 无认证逻辑（本地桌面播放器）|
| V3 Session Management | no | 无会话 |
| V4 Access Control | no | 无权限边界 |
| V5 Input Validation | yes | 拖拽 `dragOffset` clamp 到 `MediaQuery` 边界（防负值/越界）；`selectedTab` 须 clamp 到 [0,6]（防越界 tab 索引）|
| V6 Cryptography | no | 无加密操作 |

### Known Threat Patterns for Flutter UI overlay

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 点击穿透（面板关闭后命中下层控件）| Tampering | `IgnorePointer(ignoring: !isOpen)` + 动画结束后条件渲染移除（D-05）|
| ESC 键竞态触发全屏切换 | Tampering | 面板 `Focus.onKeyEvent` 返回 `KeyEventResult.handled` 消费 ESC（D-10）|
| 拖拽越界（面板拖出窗口）| Tampering | `Offset.clamp` 到 `MediaQuery.size` 边界（D-09）|

## Sources

### Primary (HIGH confidence)
- `lib/ui/playlist/playlist_panel.dart`（357 行）— LIVE 全文 Read — overlay+动画+拖拽+ESC+BackdropFilter resize 守卫的 in-tree 模板
- `lib/ui/shared/glass_container.dart`（383 行）— LIVE 全文 Read — GlassContainer/GlassTier/GlassButton 复用资产
- `lib/ui/dialogs/settings_panel.dart`（945 行）— LIVE 全文 Read — 重写对象，既有 `_offset`/`_selectedIndex`/`_handleEscape`/`_Sidebar` 模式
- `lib/kernel/services/playback_controller.dart`（254 行）— LIVE 全文 Read — 确认无 `pause()`/`play()` 转发器，无 `isPlaying` getter
- `lib/kernel/engine/playback_control.dart` — LIVE Read — `void pause()` / `void play()` / `void togglePlayPause()` 接口契约
- `lib/kernel/engine/engine_state_view.dart`（71 行）— LIVE 全文 Read — 确认无 `isPlaying` notifier，有 `ValueNotifier<MediaState> state`
- `lib/ui/player/keyboard_handler.dart`（223 行）— LIVE 全文 Read — ESC→`onExitFullscreen` 现状（line 156），D-10 交互对象
- `lib/ui/player/player_screen.dart`（452 行）— LIVE 全文 Read — Stack 挂载点（line 276/333）+ `onSettings` callback
- `lib/app.dart:50-179` — LIVE Read — `_showSettingsPanel` showDialog 路线（line 66-82）+ `onSettings` 接线（line 171-173）
- `lib/ui/shared/apple_curves.dart`（51 行）— LIVE 全文 Read — 7 个 Cubic 常量 + Apple HIG 头注释；`git ls-files --error-unmatch` 确认 UNTRACKED
- `lib/ui/theme/tokens.dart`（249 行）— LIVE 全文 Read — radiusLg/glassBlur(11.5)/durationFast(80)/bgGlass/borderHighlight 等
- `lib/kernel/engine/media_state.dart` — LIVE Read — 6 态枚举（playing/paused/idle/...）
- `.planning/config.json` — LIVE Read — `nyquist_validation: true`（Validation Architecture 段必含）

### Secondary (MEDIUM confidence)
- `.planning/codebase/CONVENTIONS.md` — v2.1 前快照（已标注陈旧，骨架可信，具体路径以 LIVE code 为准）

### Tertiary (LOW confidence)
- 无 — 所有关键断言均由 LIVE code Read 验证

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 全部 in-tree 组件已全文 Read 验证，无新依赖
- Architecture: HIGH — 7 项 canonical references 全部 LIVE 验证；D-03 gap 与 D-08 untracked 状态已确认
- Pitfalls: HIGH — 5 项 pitfall 均基于 LIVE 代码具体行号与 `git ls-files` 实测
- D-08 曲线推荐: MEDIUM-HIGH — API 已全文枚举，但"fullscreenEnter 对居中模态手感最贴切"含主观判断（A3）

**Research date:** 2026-07-22
**Valid until:** 2026-08-21（30 天 — 稳定内部架构，无外部依赖漂移；若 `apple_curves.dart` 或 `playback_controller.dart` 在此期间被他人修改须重核）
