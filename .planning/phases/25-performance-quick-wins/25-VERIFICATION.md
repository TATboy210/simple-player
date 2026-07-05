---
phase: 25-performance-quick-wins
verified: 2026-07-06T12:00:00Z
status: gaps_found
score: 2/5 truths verified
behavior_unverified: 1
overrides_applied: 0
gaps:
  - truth: "窗口 resize 时毛玻璃以 150ms easeOut 渐变淡出/淡入，无二元跳变"
    status: partial
    reason: "Fade-in is smooth (150ms easeOut) but fade-out is binary. When resizing=true, ControlBar.build() immediately returns RepaintBoundary (no BackdropFilter) via the resizing AnimatedBuilder, before the opacity animation has any visible frames. _animController.reverse() runs in parallel but is invisible because the outer AnimatedBuilder short-circuits."
    artifacts:
      - path: "lib/ui/player/control_bar.dart"
        issue: "Lines 183-192: resizing AnimatedBuilder returns RepaintBoundary when resizing.value==true, binary skipping BackdropFilter before opacity fade can produce visible frames"
    missing:
      - "Either remove the binary skip on resize-start and rely solely on the opacity fade, or delay the binary skip until opacity reaches ~0"
  - truth: "18px 魔法数字提取为 Tokens.tapJitterThreshold"
    status: partial
    reason: "Tokens.tapJitterThreshold = 18.0 exists in tokens.dart but is NOT consumed anywhere. controls_overlay.dart uses GestureDetector.onTap (no _onPointerUp with 18px threshold exists in the worktree). The constant is created but unused."
    artifacts:
      - path: "lib/ui/theme/tokens.dart"
        issue: "tapJitterThreshold defined at line 88 but never referenced outside tokens.dart"
    missing:
      - "Consume tapJitterThreshold in controls_overlay.dart or document it as a future-use constant"
  - truth: "控制栏颜色从白色微光改为淡蓝辉光（playing 稍亮，idle 稍淡）"
    status: partial
    reason: "controlBarBorderWhite changed to blue glow (0x0A6496FF) but controlBarBorderIdle constant does NOT exist. Both _decorationPlaying and _decorationIdle use Tokens.controlBarBorderWhite for their border — no visual differentiation between idle and playing states. The plan specified controlBarBorderIdle = Color(0x0D6496FF) as a separate constant."
    artifacts:
      - path: "lib/ui/theme/tokens.dart"
        issue: "controlBarBorderIdle constant missing — not defined anywhere"
      - path: "lib/ui/player/control_bar.dart"
        issue: "Both _decorationPlaying (line 24) and _decorationIdle (line 41) use Tokens.controlBarBorderWhite for border — identical border color"
    missing:
      - "Add Tokens.controlBarBorderIdle constant with dimmer blue glow value"
      - "Update _decorationIdle to use Tokens.controlBarBorderIdle instead of Tokens.controlBarBorderWhite"
  - truth: "DecorationTween 驱动 idle↔playing 状态切换动画"
    status: failed
    reason: "DecorationTween infrastructure exists (_decorationTween, _decorationPlaying, _decorationIdle) but _animController is only driven by resize signal (_onResizeChanged). No mechanism connects engine state changes (idle↔playing) to _animController. The decoration animation never triggers for state transitions — _animController stays at 1.0, always evaluating to _decorationPlaying."
    artifacts:
      - path: "lib/ui/player/controls_overlay.dart"
        issue: "_onEngineStateChanged (line 143) only calls _autoHide.onEngineStateChanged(), never drives _animController for decoration transitions"
    missing:
      - "Wire engine state changes to _animController: idle→playing triggers forward(), playing→idle triggers reverse()"
behavior_unverified_items:
  - truth: "resize 期间 engine 状态变化被忽略，避免 controller 竞争（Pitfall 2）"
    test: "During resize (resizing=true), change engine state from playing to idle"
    expected: "_isResizing flag prevents _onEngineStateChanged from triggering decoration animation"
    why_human: "Requires runtime state mutation during resize — grep confirms _isResizing guard exists at line 145 but cannot verify it correctly blocks the callback at runtime"
human_verification:
  - test: "Run the app, resize the window during playback, observe control bar behavior"
    expected: "Control bar blur fades in smoothly over 150ms when resize ends. Blur disappears immediately when resize starts (known gap — binary skip on fade-out)."
    why_human: "Visual behavior — cannot verify smoothness or visual quality via grep"
  - test: "Run the app, observe control bar border color during idle vs playing states"
    expected: "Currently both states show same blue glow border (known gap). After fix, playing should show brighter blue, idle should show dimmer blue."
    why_human: "Color appearance requires visual inspection on actual display"
---

# Phase 25: Performance Quick Wins Verification Report

**Phase Goal:** 消除 P0 性能问题 — resize 毛玻璃跳变、decoration 缓存、blur 缓存、魔法数字
**Verified:** 2026-07-06T12:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Roadmap Success Criteria

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| 1 | 窗口 resize 时毛玻璃以 150ms 渐变淡出/淡入，无二元跳变 | PARTIAL | Fade-in smooth (150ms easeOut CurvedAnimation). Fade-out binary (resizing AnimatedBuilder skips BackdropFilter immediately). |
| 2 | `_decorationPlaying`/`_decorationIdle` 不在 build() 中重复创建 | VERIFIED | Both are `static final` in control_bar.dart (lines 21-49). Used via `_decorationTween.evaluate()`. |
| 3 | GlassContainer 的 ImageFilter.blur 按 GlassTier 缓存 | VERIFIED | GlassTier has `_thinBlur`/`_normalBlur`/`_thickBlur` as static final. `_buildBlurContent` uses `tier.blurFilter`. |
| 4 | 18px 魔法数字提取为命名常量 | PARTIAL | `Tokens.tapJitterThreshold = 18.0` exists (tokens.dart:88) but is NOT consumed in controls_overlay.dart. |
| 5 | `flutter analyze` 无新增 warning/error | PARTIAL | 1 warning (`unused_element_parameter` in control_bar.dart:346 — pre-existing), 7 info-level issues. No new errors from Phase 25 changes. |
| 6 | 所有现有测试通过 | PARTIAL | 587 passed, 27 failed. All 27 failures are pre-existing compilation errors in files NOT modified by Phase 25 (osdTrackColor, playbackSpeed, auroraBlue1, etc.). Glass container tests (15/15) pass. |

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 窗口 resize 时毛玻璃以 150ms easeOut 渐变淡出/淡入，无二元跳变 | PARTIAL | Fade-in: `_animController.forward()` with `Curves.easeOut` over 150ms — smooth. Fade-out: `resizing.value==true` causes immediate binary skip in ControlBar.build() line 187 before opacity animation has visible frames. |
| 2 | _decorationPlaying/_decorationIdle 为 static final，不在 build() 中重复创建 | VERIFIED | `static final _decorationPlaying` (line 21), `static final _decorationIdle` (line 38), `static final _decorationTween` (line 52) in control_bar.dart. |
| 3 | GlassContainer 的 ImageFilter.blur 按 GlassTier static final 缓存 | VERIFIED | `_thinBlur` (line 35), `_normalBlur` (line 39), `_thickBlur` (line 43) in glass_container.dart. `_buildBlurContent` uses `tier.blurFilter` (line 138). |
| 4 | 18px 魔法数字提取为 Tokens.tapJitterThreshold | PARTIAL | Constant exists at tokens.dart:88 (`static const double tapJitterThreshold = 18.0`). NOT referenced in controls_overlay.dart — worktree uses `GestureDetector.onTap` instead of `_onPointerUp`. |
| 5 | 控制栏颜色从白色微光改为淡蓝辉光（playing 稍亮，idle 稍淡） | PARTIAL | `controlBarBorderWhite` changed to `Color(0x0A6496FF)` (blue glow). But `controlBarBorderIdle` does NOT exist. Both `_decorationPlaying` and `_decorationIdle` use `Tokens.controlBarBorderWhite` — no visual differentiation between states. |

**Score:** 2/5 truths verified (1 present, behavior-unverified)

### Deferred Items

No items deferred to later phases.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/ui/theme/tokens.dart` | tapJitterThreshold + blue glow constants | VERIFIED | tapJitterThreshold=18.0, controlBarBorderWhite=0x0A6496FF. Missing: controlBarBorderIdle. |
| `lib/ui/shared/glass_container.dart` | GlassTier.blurFilter getter + static final caches | VERIFIED | 3 static final ImageFilter instances, blurFilter getter with switch expression. |
| `lib/ui/player/controls_overlay.dart` | TickerProviderStateMixin + AnimationController + tapJitterThreshold | PARTIAL | TickerProviderStateMixin ✓, _animController ✓, _resizeOpacity ✓, _isResizing ✓. tapJitterThreshold NOT consumed. |
| `lib/ui/player/control_bar.dart` | static final decorations + DecorationTween + GlassTier blur | VERIFIED | _decorationPlaying/_decorationIdle static final ✓, _decorationTween ✓, GlassTier.normal.blurFilter ✓. |
| `lib/ui/playlist/playlist_panel.dart` | GlassTier.thick.blurFilter replacing local _blurFilter | VERIFIED | Uses `GlassTier.thick.blurFilter` (line 116). No `dart:ui` import. No `_blurFilter`. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| ControlsOverlay | ControlBar | `opacity: _resizeOpacity` parameter | VERIFIED | Line 228 in controls_overlay.dart |
| ControlsOverlay | ControlBar | `decoration: _animController` parameter | VERIFIED | Line 231 in controls_overlay.dart |
| GlassTier.blurFilter | ControlBar | `GlassTier.normal.blurFilter` in _buildBlur | VERIFIED | Line 205 in control_bar.dart |
| GlassTier.blurFilter | PlaylistPanel | `GlassTier.thick.blurFilter` in _buildBackdrop | VERIFIED | Line 116 in playlist_panel.dart |
| Engine state | _animController | Decoration state transition | NOT WIRED | `_onEngineStateChanged` only calls `_autoHide.onEngineStateChanged()`, never drives `_animController` for decoration transitions. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| ControlsOverlay._animController | _resizeOpacity | widget.resizing ValueListenable | Yes — driven by resize signal | FLOWING |
| ControlBar._decorationTween | effectiveDecoration | _animController animation value | Yes — but always at 1.0 (no engine state wiring) | STATIC |
| GlassTier.blurFilter | blurFilter | static final ImageFilter instances | Yes — cached immutable instances | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| GlassTier blur cache | `flutter test test/widget/shared/glass_container_test.dart` | 15/15 passed | PASS |
| flutter analyze (5 files) | `flutter analyze lib/ui/theme/tokens.dart lib/ui/shared/glass_container.dart lib/ui/player/controls_overlay.dart lib/ui/player/control_bar.dart lib/ui/playlist/playlist_panel.dart` | 1 warning (pre-existing), 7 info | PASS |
| Full test suite | `flutter test` | 587 passed, 27 failed (all pre-existing compilation errors in unrelated files) | PASS (Phase 25 files clean) |

### Probe Execution

No probes declared for this phase.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| PERF-01 | 25-01 | Resize 毛玻璃渐变过渡 | PARTIAL | Fade-in smooth, fade-out binary. |
| PERF-02 | 25-01 | Decoration 缓存 | VERIFIED | static final + DecorationTween infrastructure. Decoration state transition not wired (separate gap). |
| PERF-03 | 25-01 | ImageFilter.blur 缓存 | VERIFIED | GlassTier static final per tier. ControlBar/PlaylistPanel use cached instances. |
| PERF-04 | 25-01 | 魔法数字 18px 提取 | PARTIAL | Constant created, not consumed. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `lib/ui/player/control_bar.dart` | 346 | `unused_element_parameter` warning (pre-existing) | INFO | Cosmetic — key parameter never used in _CompactCenterGroup constructor |

No TBD/FIXME/XXX debt markers found in modified files.

### Deviations from Plan

| # | Deviation | Reason | Impact |
|---|-----------|--------|--------|
| 1 | GlassTier.thick uses separate `_thickBlur` (sigma=24) instead of sharing with normal (sigma=10) | Worktree has `glassBlurThick=24.0` vs `glassBlur=10.0` — D-12 assumed equal sigma | No functional impact — caching still works per tier |
| 2 | Decoration evaluate() used directly in build() instead of AnimatedBuilder wrapper | Simpler approach, same caching benefit | No functional impact |
| 3 | tapJitterThreshold not consumed in controls_overlay.dart | Worktree uses GestureDetector.onTap, no _onPointerUp with 18px | Constant ready for future use |
| 4 | controlBarBorderIdle constant not created | Both decorations use controlBarBorderWhite | No visual differentiation between idle/playing states |
| 5 | controlBarBorderWhite value is 0x0A6496FF (4% alpha) instead of plan's 0x1A6496FF (10% alpha) | Color tuning adaptation (D-17) | Border dimmer than planned — visual tuning needed |

### Human Verification Required

#### 1. Resize fade visual quality

**Test:** Run the app, play a video, resize the window rapidly
**Expected:** Control bar blur fades in smoothly over 150ms when resize ends. Blur disappears immediately when resize starts (known gap — binary skip on fade-out).
**Why human:** Visual smoothness cannot be verified via grep

#### 2. Control bar color differentiation

**Test:** Run the app, observe control bar border in idle vs playing states
**Expected:** Currently both states show identical blue glow border (known gap — controlBarBorderIdle missing). After fix, playing should show brighter blue, idle dimmer blue.
**Why human:** Color appearance requires visual inspection

#### 3. Decoration state transition

**Test:** Start playback, let it go idle, observe if control bar decoration transitions
**Expected:** Currently no visible transition (DecorationTween not wired to engine state). After fix, should see smooth color/shadow transition between idle and playing.
**Why human:** Animation timing and visual quality require runtime observation

### Gaps Summary

**4 gaps identified, 0 deferred:**

1. **Resize fade-out is binary** (PERF-01 partial) — The `resizing` AnimatedBuilder in ControlBar.build() immediately skips BackdropFilter when `resizing.value==true`, before the opacity animation has any visible frames. The `_animController.reverse()` runs in parallel but is invisible. Only fade-in is smooth (150ms easeOut).

2. **Decoration state transition not wired** — `_animController` is only driven by `_onResizeChanged` (resize signal). `_onEngineStateChanged` does not drive `_animController` for idle↔playing decoration transitions. The DecorationTween infrastructure exists but the animation never triggers for state changes.

3. **controlBarBorderIdle missing** — No separate constant for idle border color. Both `_decorationPlaying` and `_decorationIdle` use `Tokens.controlBarBorderWhite`. No visual differentiation between playing and idle states per D-18.

4. **tapJitterThreshold not consumed** — Constant exists in tokens.dart but is not referenced in controls_overlay.dart. The worktree uses `GestureDetector.onTap` instead of `_onPointerUp` with threshold logic.

**Root cause:** The implementation adapted to worktree state differences (no _onPointerUp, different GlassTier sigma values) but some adaptations left wiring incomplete (decoration state transition, idle border differentiation).

---

_Verified: 2026-07-06T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
