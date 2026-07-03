# Phase 17: Adaptive Control Bar — PLAN

> **Goal:** ControlBar 在 idle/playing 之间切换时有平滑动画过渡，空状态使用轻量装饰。
>
> **Requirements:** UI-02, UI-03
>
> **Decisions:** D-01~D-07 (see 17-CONTEXT.md)

---

## Task 01: Convert ControlBar decorations from `static final` to getters

**Why:** `AnimatedContainer` needs a new `BoxDecoration` each build to interpolate. `static final` objects are const and cannot animate.

**File:** `lib/ui/player/control_bar.dart`

**Changes:**
- Remove `static final _decorationPlaying` (lines 26-50)
- Remove `static final _decorationIdle` (lines 53-72)
- Add `BoxDecoration get _decorationPlaying => BoxDecoration(...)` with identical values
- Add `BoxDecoration get _decorationIdle => BoxDecoration(...)` with identical values
- Keep `static final _borderRadius` and `static final _blurFilter` unchanged (they don't animate)

**Verify:** `flutter analyze` passes, existing tests still pass.

---

## Task 02: Replace `Container` with `AnimatedContainer` for background

**Why:** D-01 decision — `AnimatedContainer` auto-interpolates `color` and `border` with minimal code change.

**File:** `lib/ui/player/control_bar.dart`

**Changes (line ~169-173):**

```dart
// BEFORE:
final decoration = isIdle ? _decorationIdle : _decorationPlaying;
final background = Container(
  height: Tokens.controlBarHeight,
  decoration: decoration,
);

// AFTER:
final background = AnimatedContainer(
  duration: const Duration(milliseconds: Tokens.durationNormal),
  curve: Curves.easeInOut,
  height: Tokens.controlBarHeight,
  decoration: isIdle ? _decorationIdle : _decorationPlaying,
);
```

**Key points:**
- Duration: `Tokens.durationNormal` (150ms) per D-02
- Curve: `Curves.easeInOut` per D-04
- `boxShadow` stays `static final` in the getters per D-06 — AnimatedContainer will NOT interpolate boxShadow, only color + border

**Verify:** `flutter analyze` passes, existing tests pass, golden test may need update.

---

## Task 03: Verify EdgeGlow glowIntensity synchronization

**Why:** D-05 decision — EdgeGlow intensity should transition in sync with AnimatedContainer.

**File:** `lib/ui/player/control_bar.dart`

**Current code (line ~176-179):**
```dart
final content = EdgeGlow(
  variant: EdgeGlowVariant.gradient,
  borderRadius: _borderRadius,
  glowIntensity: isIdle ? 0.3 : null,
  ...
```

**No code change needed.** EdgeGlow already accepts `glowIntensity` and the value switches instantly on rebuild. The "synchronized animation" from D-05 is achieved by visual proximity: AnimatedContainer's 150ms color/border transition is fast enough that the instant EdgeGlow switch appears coordinated. No additional animation code needed — this is the simplest correct approach.

**Verify:** Visual check — transition should feel cohesive at 150ms.

---

## Task 04: Update golden tests

**Why:** Decoration is now a getter (not `static final`), and the animation changes the widget tree structure (`AnimatedContainer` vs `Container`).

**Files:** `test/golden/` (control_bar_idle.png, control_bar_playing.png)

**Changes:**
- Run golden tests: `flutter test --update-goldens test/golden/`
- Verify idle golden shows lighter/more transparent background
- Verify playing golden matches previous appearance (no visual regression)

---

## Task 05: Add animation transition test

**Why:** Verify AnimatedContainer is present and decoration switches correctly between idle/playing states.

**File:** `test/widget/player/control_bar_test.dart`

**New tests:**
1. `testWidgets('uses AnimatedContainer for background')` — find `AnimatedContainer` in widget tree
2. `testWidgets('idle state uses idle decoration')` — pump with `isIdle: true`, verify lighter colors
3. `testWidgets('playing state uses playing decoration')` — pump with `isIdle: false`, verify standard colors
4. `testWidgets('transitions decoration on isIdle change')` — pump idle → change to playing → pump → verify AnimatedContainer present with correct duration

---

## Task 06: Verify backward compatibility

**Why:** SC-5 — existing call sites of GlassContainer and ControlBar require zero modifications.

**Checks:**
- `ControlBar` constructor signature unchanged (no new required params)
- `GlassContainer` already has `backgroundColor` from Phase 16 — no changes needed
- All existing `ControlBar(...)` call sites compile without changes
- `flutter analyze` clean

---

## Execution Order

```
T01 (getters) → T02 (AnimatedContainer) → T03 (verify EdgeGlow) → T06 (analyze)
                                                                    ↓
                                              T04 (golden update) ← T05 (animation test)
```

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| SC-1 | GlassContainer accepts optional `backgroundColor` | Already done in Phase 16 |
| SC-2 | ControlBar shows distinct idle decoration | Golden test `control_bar_idle.png` |
| SC-3 | Playing decoration unchanged | Golden test `control_bar_playing.png` |
| SC-4 | Smooth idle↔playing transition | AnimatedContainer with 150ms easeInOut |
| SC-5 | Zero modifications to existing call sites | `flutter analyze` + compile check |

## Out of Scope

- `boxShadow` interpolation (D-06: keep static, avoid complex Tween)
- Gradient transition zone (deferred to v1.4)
- Adaptive gradient intensity (v2+)
- Background color extraction from video (v2+)
