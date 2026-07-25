# Phase 23: Overlay Shell & State Model - Pattern Map

**Mapped:** 2026-07-22
**Files analyzed:** 7 (3 new source + 2 modify + 1 delete + prerequisite untracked file) + 4 test files
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `lib/ui/dialogs/settings/settings_panel_state.dart` (NEW) | model (state container) | event-driven (ValueNotifier) | `lib/ui/playlist/playlist_panel.dart` (`_selectedTab` notifier, lines 64/108) + `settings_panel.dart` (`_offset`, lines 61/111/117) | role-match (assembled from 2 partial analogs, no single existing "state model" class) |
| `lib/ui/dialogs/settings/settings_panel_controller.dart` (NEW) | service (orchestrator/controller) | request-response (open/close lifecycle) | `lib/kernel/services/playback_controller.dart` (254 lines, facade pattern) | role-match (facade/orchestrator pattern, no direct open/close/pause analog exists) |
| `lib/ui/dialogs/settings/settings_overlay_shell.dart` (NEW) | component (overlay widget) | event-driven (animation + gesture + focus) | `lib/ui/playlist/playlist_panel.dart` (357 lines) | exact (strongest overlay-shell analog: Stack+animation+drag+Focus+BackdropFilter) |
| `lib/kernel/services/playback_controller.dart` (MODIFY — add `pause()`/`play()`/`isPlaying`) | service (facade, gap-fill) | request-response | same file, existing forwarding methods (`playIndex`/`playNext`, lines 145-158) | exact (mirror existing forwarder style in same file) |
| `lib/ui/player/player_screen.dart` (MODIFY — mount overlay Stack layer) | component (composition root) | event-driven (Stack compositing) | same file, existing `PlaylistPanel` Stack mounting (lines 256-296) | exact (mirror existing mounting pattern for new sibling layer) |
| `lib/ui/shared/apple_curves.dart` (MODIFY — `git add` only, no code change) | config/utility (animation curves) | n/a | itself (LIVE, 51 lines, already complete) | exact (prerequisite: lock via git, no code edits) |
| `lib/ui/dialogs/settings_panel.dart` (DELETE, separate commit after cutover) | component (legacy dialog) | request-response (showDialog) | n/a — deletion target | n/a |

## Pattern Assignments

### `lib/ui/dialogs/settings/settings_panel_state.dart` (NEW, model, D-01/D-04)

**Analog:** `lib/ui/playlist/playlist_panel.dart` lines 64, 108 (`_selectedTab` ValueNotifier + dispose) and `lib/ui/dialogs/settings_panel.dart` lines 61, 111, 117 (`_offset` ValueNotifier + dispose + reset-on-close)

**Notifier declaration pattern** (playlist_panel.dart:64):
```dart
final _selectedTab = ValueNotifier<int>(0); // 0=文件夹, 1=历史
```

**Dispose pattern** (playlist_panel.dart:108-111):
```dart
@override
void dispose() {
  _focusNode.dispose();
  _selectedTab.dispose();
  _anim.dispose();
  super.dispose();
}
```

**Offset notifier + reset pattern** (settings_panel.dart:61, 111, 117):
```dart
final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);
// ...
_offset.dispose();
// ...
_offset.value = Offset.zero;  // reset on close
```

**API/signature to replicate:**
```dart
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

**Deviations from analog:** Neither analog is a standalone state class — both embed notifiers directly in a `State<StatefulWidget>`. `SettingsPanelState` extracts this into a plain Dart class (no Flutter State) per D-02 (constructor-injected, composition-root assembled) so it can be unit-tested without `WidgetTester` (see PANEL-01 test requirement). D-04 explicitly excludes `_pendingLocale`/`_pendingThemeIndex`/`_originalShortcuts` — only 3 notifiers, no more.

---

### `lib/ui/dialogs/settings/settings_panel_controller.dart` (NEW, service, D-02/D-03)

**Analog:** `lib/kernel/services/playback_controller.dart` (254 lines) — facade/orchestrator pattern, constructor injection, forwarding methods

**Constructor injection pattern** (playback_controller.dart:46-61):
```dart
class PlaybackController {
  PlaybackController({
    required this.engine,
    required this.playlist,
    required VoidCallback onNeedRebuild,
    void Function(PlayerError error)? onError,
    SubtitleService? subtitleService,
    TrackPreferenceService? trackPreferenceService,
  }) : _onNeedRebuild = onNeedRebuild,
       _onError = onError,
       _subtitleService = subtitleService,
       _trackPreferenceService = trackPreferenceService {
    navigator = PlaybackNavigator(this);
    fileOps = FileOperations(this);
    stateManager = PlaybackStateManager(this);
    autoAdvance = AutoAdvancePolicy(this);
  }
```

**Forwarding-method style** (playback_controller.dart:148-153):
```dart
/// 播放指定索引 — 委托 [PlaybackNavigator.playIndex].
Future<void> playIndex(int i) => navigator.playIndex(i);

/// 播放下一首 — 委托 [PlaybackNavigator.playNext].
Future<void> playNext() => navigator.playNext();
```

**Dispose pattern** (playback_controller.dart:242-253):
```dart
void dispose() {
  autoAdvance.dispose();
  stateManager.dispose();
  unawaited(
    _trackPreferenceService?.save().catchError(
      (Object e) => log.e('TrackPreferenceService.save failed: $e'),
    ),
  );
  currentFileName.dispose();
  fileOps.validationError.dispose();
}
```

**API/signature to replicate:**
```dart
class SettingsPanelController {
  SettingsPanelController(this._playback);
  final PlaybackController _playback;
  final SettingsPanelState state = SettingsPanelState();
  bool _wasPlaying = false;

  void open() {
    if (state.isOpen.value) return;                // no-op guard
    _wasPlaying = _playback.isPlaying;              // D-03 snapshot via NEW getter
    if (_wasPlaying) _playback.pause();             // D-03 via orchestrator, NOT engine directly
    state.isOpen.value = true;
  }

  void close() {
    if (!state.isOpen.value) return;                // no-op guard
    state.isOpen.value = false;
    if (_wasPlaying) _playback.play();
    state.dragOffset.value = Offset.zero;           // reset on close (mirrors settings_panel.dart:117)
  }

  void toggle() => state.isOpen.value ? close() : open();
  void dispose() => state.dispose();
}
```

**Deviations from analog:** `PlaybackController` composes 4 sub-modules via `this`-passing constructor injection (internal composition); `SettingsPanelController` instead takes an *external* collaborator (`PlaybackController`) injected from the composition root (D-02: `app.dart`/`PlayerServices` assembles `SettingsPanelController(playbackController)`, no DI framework, no `BuildContext` lookup). The no-op guards (`if (state.isOpen.value) return;`) are a NEW pattern not present in `PlaybackController` but required by PANEL-02 test spec ("open() already-open is no-op").

---

### `lib/ui/dialogs/settings/settings_overlay_shell.dart` (NEW, component, D-05/D-07/D-08/D-09/D-10)

**Analog:** `lib/ui/playlist/playlist_panel.dart` (357 lines) — STRONGEST overlay-shell analog (Stack + FadeTransition/SlideTransition + BackdropFilter + Focus/onKeyEvent ESC + resize-skip guard)

**Stack mounting: outer tap-to-close + positioned panel** (playlist_panel.dart:130-159):
```dart
@override
Widget build(BuildContext context) {
  return Stack(
    children: [
      // 全屏透明层 — 点击外部关闭
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onClose,
          child: const SizedBox.expand(),
        ),
      ),
      // 浮窗面板
      Positioned(
        right: Tokens.controlBarMarginH,
        bottom: Tokens.controlBarMarginBottom + Tokens.controlBarHeight + Tokens.spLg,
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: _buildPanel(_panelWidth, _panelHeight),
          ),
        ),
      ),
    ],
  );
}
```
D-05/PANEL-05 requires **centered** placement + `AnimatedScale`+`AnimatedOpacity` (implicit animation) rather than `Positioned` bottom-right + `AnimationController`-driven `SlideTransition`/`FadeTransition` — see Pattern 3 in RESEARCH.md for the exact replacement shape (Center + AnimatedScale + AnimatedOpacity, curve = `AppleCurves.fullscreenEnter`/`fullscreenExit`, 200ms).

**BackdropFilter with cached ImageFilter + resize-skip guard** (playlist_panel.dart:113-125, 180-200):
```dart
Widget _buildBackdrop() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(Tokens.radiusLarge),
    child: FadeTransition(
      opacity: _fadeAnim,
      child: BackdropFilter(
        // 使用 GlassTier 缓存的 ImageFilter，避免每帧创建新实例（D-10/D-11）
        filter: GlassTier.thick.blurFilter,
        child: const SizedBox.expand(),
      ),
    ),
  );
}
// ...
Positioned.fill(
  child: widget.resizing != null
      ? AnimatedBuilder(
          animation: widget.resizing!,
          builder: (_, _) {
            final resizing = widget.resizing;
            if (resizing != null && resizing.value) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusLarge),
                child: Container(color: Tokens.bgGlass),
              );
            }
            return _buildBackdrop();
          },
        )
      : _buildBackdrop(),
),
```
Prefer wrapping with `GlassContainer(tier: GlassTier.normal, resizing: ..., opacity: ...)` directly (PANEL-03 explicitly calls for `GlassContainer` reuse) rather than hand-rolling `ClipRRect`+`BackdropFilter` as playlist_panel does — see glass_container.dart excerpt below.

**Focus/onKeyEvent ESC-consumes-and-does-not-bubble pattern** (playlist_panel.dart:162-172):
```dart
Widget _buildPanel(double width, double height) {
  return Focus(
    focusNode: _focusNode,
    autofocus: false,
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onClose();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: GestureDetector(
      onTap: () {}, // 拦截点击，不穿透到外部关闭层
      child: /* ... */
    ),
  );
}
```
D-10 requires also matching `KeyboardKey.keyB` (not just escape) and wrapping in `FocusTraversalGroup` (playlist_panel does not use `FocusTraversalGroup`, this is a NEW addition for D-10's "self-managed Focus subtree" requirement). `KeyEventResult.handled` is the exact mechanism that prevents bubbling to `KeyboardHandler.onExitFullscreen` — same idiom, extend the `||` condition:
```dart
if (event.logicalKey == LogicalKeyboardKey.escape ||
    event.logicalKey == LogicalKeyboardKey.keyB) {
  controller.close();
  return KeyEventResult.handled;
}
```

**Focus request/release on visibility change** (playlist_panel.dart:86-97, 99-103):
```dart
@override
void didUpdateWidget(covariant PlaylistPanel oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.visible != oldWidget.visible) {
    if (widget.visible) {
      _anim.forward();
      _requestFocus();
    } else {
      _anim.reverse();
      _focusNode.unfocus();
    }
  }
}

void _requestFocus() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _focusNode.requestFocus();
  });
}
```

**GlassContainer reuse (PANEL-03)** — from `lib/ui/shared/glass_container.dart` lines 54-90 (constructor) and the `GlassTier` enum (lines 14-47):
```dart
enum GlassTier {
  thin(Tokens.glassBlurThin),   // 标题栏 — 轻模糊
  normal(Tokens.glassBlur),     // 控制栏 — 默认模糊
  thick(Tokens.glassBlur);      // 弹窗/对话框
  final double sigma;
  const GlassTier(this.sigma);
  ui.ImageFilter get blurFilter => switch (this) {
    GlassTier.thin => _thinBlur,
    GlassTier.normal => _normalBlur,
    GlassTier.thick => _thickBlur,
  };
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Border? border;
  final GlassTier tier;
  final ValueListenable<double>? opacity;   // <0.01 skips BackdropFilter (D-13)
  final bool blurEnabled;                    // false skips BackdropFilter (D-14)
  final ValueListenable<bool>? resizing;     // true skips BackdropFilter during resize
  final Color? backgroundColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.width, this.height, this.padding, this.margin,
    this.borderRadius, this.border,
    this.tier = GlassTier.normal,
    this.opacity, this.blurEnabled = true, this.resizing, this.backgroundColor,
  });
}
```
Use `GlassContainer(tier: GlassTier.normal, ...)` directly for the panel body — this already handles BackdropFilter caching, resize-skip, and opacity-skip; do not hand-roll (per RESEARCH.md "Don't Hand-Roll").

**Drag gesture semantic analog** (settings_panel.dart:529-535 — in-canvas drag, closest existing analog to D-09 despite being the file targeted for replacement):
```dart
GestureDetector(
  onPanStart: isFullscreen ? null : (_) {},
  onPanUpdate: isFullscreen
      ? null
      : (d) {
          _offset.value += d.delta;
        },
  child: /* title bar container */,
)
```
D-09 clamp requirement (not present in this analog — settings_panel.dart does NOT clamp, this is a gap to fix in the new shell):
```dart
onPanUpdate: (d) {
  final size = MediaQuery.of(context).size;
  const panelW = 500.0, panelH = 400.0;   // PANEL-07 base size
  final next = controller.state.dragOffset.value + d.delta;
  final maxX = (size.width - panelW) / 2;
  final maxY = (size.height - panelH) / 2;
  controller.state.dragOffset.value = Offset(
    next.dx.clamp(-maxX, maxX),
    next.dy.clamp(-maxY, maxY),
  );
},
```
**Deviation from `custom_title_bar.dart`:** that file's drag gesture moves the OS window (via `window_manager`/Win32 FFI); this is a *pattern-shape* analogy only (GestureDetector.onPanUpdate style), never call `windowManager.startDragging()` or window bridge APIs from the panel drag handler — D-09 is explicit that panel drag is in-canvas (`Transform.translate` + `dragOffset` notifier), semantically unrelated to OS window drag.

**Pointer-hit-test unmounting (D-05)** — no direct excerpt exists for `IgnorePointer`+`Visibility` double-gate in playlist_panel itself (it uses the `(visible, mounted)` tuple one level up in `player_screen.dart`, see next section); apply the same `(bool, bool)` tuple pattern locally inside the shell, or take the tuple as controller state (`isOpen` doubles as both signals since D-05 says "面板关闭时 IgnorePointer/Visibility 卸载命中" — simplest is `IgnorePointer(ignoring: !isOpen)` wrapping a conditionally-built child, matching Pattern 3 in RESEARCH.md which returns `const SizedBox.shrink()` when `!open`).

---

### `lib/kernel/services/playback_controller.dart` (MODIFY, service, D-03 gap-fill)

**Analog:** same file, existing forwarding-method style (lines 145-173, `playIndex`/`playNext`/`playPrevious`/`openAndPlay`/`validationError` getter)

**Exact excerpt to mirror** (playback_controller.dart:148-158):
```dart
/// 播放指定索引 — 委托 [PlaybackNavigator.playIndex].
Future<void> playIndex(int i) => navigator.playIndex(i);

/// 播放下一首 — 委托 [PlaybackNavigator.playNext].
Future<void> playNext() => navigator.playNext();

/// 播放上一首 — 委托 [PlaybackNavigator.playPrevious].
Future<void> playPrevious() => navigator.playPrevious();
```

**Getter-forwarding style** (playback_controller.dart:170-173):
```dart
/// 最近一次路径校验错误（null 表示无错误）— 委托 [FileOperations.validationError].
ValueNotifier<String?> get validationError => fileOps.validationError;
```

**Underlying engine methods to forward to** (from `lib/kernel/engine/fvp_engine.dart:449, 480` and `lib/kernel/engine/engine_state.dart` — `MediaState` enum via `lib/kernel/engine/media_state.dart:10`):
```dart
// fvp_engine.dart:449, 480 — engine-level methods already exist
void play() { /* ... transitionTo(MediaState.playing, 'play') */ }
void pause() { /* ... transitionTo(MediaState.paused, 'pause') */ }
// engine_state_machine.dart:55 — state notifier already exists
final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
```

**API/signature to add** (place in the "── 转发 — UI 层的统一入口 ──" section near line 142-173):
```dart
/// 暂停播放 — 委托 MediaEngine.pause()（D-03 SettingsPanelController 暂停入口）
void pause() => engine.pause();

/// 恢复播放 — 委托 MediaEngine.play()（D-03 close() 恢复入口）
void play() => engine.play();

/// 是否正在播放 — 从 state notifier 派生（D-03 wasPlaying 快照）
bool get isPlaying => engine.state.value == MediaState.playing;
```

**Deviations from analog:** These are thinner than `playIndex`/`playNext` (which delegate to `navigator`); `pause`/`play` delegate directly to `engine` (no sub-module involved), matching the style of other direct-engine-passthrough spots in the codebase (e.g. `player_screen.dart:170` currently calls `widget.engine.togglePlayPause()` directly — this modification is what replaces that anti-pattern per D-03). Must NOT introduce `openGeneration` guard interaction — confirmed safe per RESEARCH.md Assumption A2.

---

### `lib/ui/player/player_screen.dart` (MODIFY, component, D-05 mounting)

**Analog:** same file, existing `PlaylistPanel` Stack-mounting pattern (lines 256-296) driven by `_playlistState` ValueNotifier tuple

**Exact excerpt to mirror — narrow-screen Stack overlay mounting** (player_screen.dart:275-287):
```dart
// 窄屏: Stack overlay
return Stack(
  children: [
    RepaintBoundary(child: videoContent!),
    if (playlistMounted)
      RepaintBoundary(
        child: IgnorePointer(
          ignoring: !playlistVisible,
          child: playlistPanel,
        ),
      ),
  ],
);
```

**Visibility/mount tuple pattern** (player_screen.dart:100-104, 109-124):
```dart
/// (visible, mounted) — 合并为单一 notifier 消除嵌套 VLB
final ValueNotifier<(bool, bool)> _playlistState = ValueNotifier((false, false));

void _togglePlaylist() {
  final (visible, mounted) = _playlistState.value;
  final nowVisible = !visible;
  _playlistState.value = (nowVisible, nowVisible || mounted);
  widget.onTogglePlaylist?.call();
}

void _closePlaylist() {
  _playlistState.value = (false, _playlistState.value.$2);
  // 延迟卸载，等待淡出动画完成
  Future.delayed(const Duration(milliseconds: Tokens.durationSlide), () {
    if (mounted && !_playlistState.value.$1) {
      _playlistState.value = (false, false);
    }
  });
}
```

**Existing `onSettings` callback wiring** (player_screen.dart:59, 354 — cutover point D-06):
```dart
final VoidCallback? onSettings;
// ...
ControlsOverlay(
  // ...
  actions: PlayerActions(
    // ...
    onSettings: widget.onSettings,
    onSettingsSecondary: widget.onSettingsSecondary,
    // ...
```

**API/signature to add:** Per RESEARCH.md Open Question 1 recommendation — mount the new `SettingsOverlayShell` as the topmost sibling in the outermost Stack (covering both the narrow-screen Stack at line 276 AND the wide-screen Row at line 256, but NOT `CustomTitleBar` at line 225). Concretely, wrap the `Expanded(child: LayoutBuilder(...))` region (lines 226-298) plus itself in a new outer `Stack`:
```dart
Expanded(
  child: Stack(
    children: [
      LayoutBuilder(/* existing videoContent / playlistPanel Row-or-Stack logic, unchanged */),
      ValueListenableBuilder<bool>(
        valueListenable: widget.settingsPanelController.state.isOpen,
        builder: (context, open, _) {
          if (!open) return const SizedBox.shrink();
          return SettingsOverlayShell(controller: widget.settingsPanelController);
        },
      ),
    ],
  ),
),
```
`PlayerScreen` constructor needs a new required field `settingsPanelController` (D-02: passed from `app.dart` composition root, mirrors existing `controller: PlaybackController` constructor param at line 54/77).

**Deviations from analog:** `_playlistState`'s `(bool, bool)` tuple exists to support delayed unmount for exit-animation; the new shell can reuse `IgnorePointer(ignoring: !isOpen)` more simply since D-05 explicitly calls for `IgnorePointer`/`Visibility`-based unmounting rather than a timed `Future.delayed` unmount — prefer the simpler `if (!open) return SizedBox.shrink()` pattern from RESEARCH.md Pattern 3 (animation itself, not a delayed widget-tree removal, handles the visual fade-out).

---

### `lib/ui/shared/apple_curves.dart` (MODIFY = `git add` only, D-08 prerequisite)

**No code changes required.** File is complete (51 lines) but UNTRACKED. First task in Phase 23 implementation MUST be:
```bash
git add lib/ui/shared/apple_curves.dart
git commit -m "chore: track apple_curves.dart, lock animation curve API for phase 23"
```

**Full API (already verified, use as-is):**
```dart
class AppleCurves {
  AppleCurves._();
  static const fullscreenEnter = Cubic(0.22, 0.61, 0.36, 1.0);  // ease-out — use for panel open
  static const fullscreenExit  = Cubic(0.55, 0.0, 0.79, 0.34);  // ease-in  — use for panel close
  static const controlBarSlide = Cubic(0.33, 1.0, 0.68, 1.0);   // overshoot — AVOID for modal scale
  static const titleBarFade    = Cubic(0.25, 0.1, 0.25, 1.0);
  static const contentScale    = Cubic(0.2, 0.0, 0.0, 1.0);     // fallback if fullscreenEnter too sharp
  static const backgroundFade  = Cubic(0.4, 0.0, 0.2, 1.0);
  static const elasticEnter    = Cubic(0.175, 0.885, 0.32, 1.275); // overshoot — AVOID
}
```
Use `AppleCurves.fullscreenEnter` for open (Scale+Opacity), `AppleCurves.fullscreenExit` for close, per D-08.

---

### `lib/ui/dialogs/settings_panel.dart` (DELETE, separate commit, D-06)

**No pattern extraction needed** — this file is the deletion target, not a template. Delete ONLY after `SettingsOverlayShell` fully replaces its trigger (`app.dart:66 _showSettingsPanel()` → `showDialog`) and cutover is verified. Must be its own commit per D-06 ("永不与 feature 捆绑" — never bundle with feature code).

**Reusable fragments already identified from this file** (for reference during shell-building, not deletion prep):
- `_offset` ValueNotifier + reset-on-close pattern (lines 61, 111, 117) — informs `SettingsPanelState.dragOffset`
- Drag gesture `onPanUpdate` (lines 529-535) — informs Pattern 4 (lacks clamp; new shell must add it)
- ESC handling (line ~125, `_handleEscape`) — informs Pattern 5, extend with `keyB`

---

## Shared Patterns

### ValueNotifier state model (no new framework)
**Source:** `lib/ui/playlist/playlist_panel.dart:64,108` + `lib/ui/dialogs/settings_panel.dart:61,111,117`
**Apply to:** `settings_panel_state.dart`
```dart
final ValueNotifier<T> foo = ValueNotifier<T>(initial);
// dispose in matching dispose() method, always call super.dispose() last if State
```

### Facade/orchestrator constructor injection (no DI framework, no BuildContext lookup)
**Source:** `lib/kernel/services/playback_controller.dart:46-61`
**Apply to:** `settings_panel_controller.dart`
```dart
class SomeController {
  SomeController(this._dependency);
  final SomeDependency _dependency;
}
```

### Focus + onKeyEvent consumes key, prevents bubble
**Source:** `lib/ui/playlist/playlist_panel.dart:162-172`
**Apply to:** `settings_overlay_shell.dart` (extend with `keyB` + wrap in `FocusTraversalGroup` per D-10)
```dart
Focus(
  autofocus: true,
  onKeyEvent: (node, event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.keyB) {
      controller.close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  },
  child: /* panel */,
)
```

### GlassContainer reuse (never hand-roll BackdropFilter)
**Source:** `lib/ui/shared/glass_container.dart:54-90` (constructor), `:14-47` (GlassTier enum)
**Apply to:** `settings_overlay_shell.dart` panel body
```dart
GlassContainer(
  tier: GlassTier.normal,
  borderRadius: BorderRadius.circular(Tokens.radiusLg),
  resizing: windowService.isResizing,   // skip BackdropFilter during resize
  child: /* panel content */,
)
```

### IgnorePointer hit-test gating for closed overlays
**Source:** `lib/ui/player/player_screen.dart:280-285` (`IgnorePointer(ignoring: !playlistVisible, ...)`)
**Apply to:** `settings_overlay_shell.dart` mounting in `player_screen.dart`
```dart
IgnorePointer(
  ignoring: !open,
  child: settingsOverlayShell,
)
```

### Error handling / debug logging convention
**Source:** CLAUDE.md — `debugPrint()` not `print()`; no silent `catch (_) {}`
**Apply to:** all new files (none of the new files perform I/O or fallible operations requiring try/catch, but any future error paths must follow this convention)

## No Analog Found

None — all 7 files have at least a role-match analog (see table above). The weakest matches are `SettingsPanelState`/`SettingsPanelController`, which are genuinely new abstractions (no prior "extracted state model" class exists in the codebase — state has always lived inline in `StatefulWidget`s); RESEARCH.md Pattern 1/2 code examples were used to fill this gap since they were already derived from LIVE codebase conventions.

## Metadata

**Analog search scope:** `lib/ui/playlist/`, `lib/ui/dialogs/`, `lib/ui/shared/`, `lib/ui/player/`, `lib/kernel/services/`, `lib/kernel/engine/`
**Files scanned:** `playlist_panel.dart`, `settings_panel.dart`, `glass_container.dart`, `apple_curves.dart`, `playback_controller.dart`, `player_screen.dart`, `custom_title_bar.dart` (referenced, not fully read — semantic-only per D-09), `engine_state_machine.dart`, `fvp_engine.dart`, `engine_state_view.dart`, `media_state.dart`
**Pattern extraction date:** 2026-07-22

## PATTERN MAPPING COMPLETE
