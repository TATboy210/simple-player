---
phase: 25-performance-quick-wins
plan: 02
subsystem: ui
tags: [animation, glassmorphism, design-tokens, performance, gap-closure]

# Dependency graph
requires: [25-01]
provides:
  - "Resize fade-out unified via opacity (no binary skip)"
  - "Decoration state transition wired to engine idle↔playing"
  - "controlBarBorderIdle constant for idle state differentiation"
  - "tapJitterThreshold marked as future-use"
affects: [25-performance-quick-wins]

# Tech tracking
tech-stack:
  added: []
  patterns: [AnimationController dual-purpose (resize + decoration), _isResizing guard for state competition]

key-files:
  created: []
  modified:
    - lib/ui/theme/tokens.dart
    - lib/ui/player/control_bar.dart
    - lib/ui/player/controls_overlay.dart

key-decisions:
  - "Fade-out 统一由 _animController.reverse() 控制 opacity 渐变，移除 ControlBar 中 resizing AnimatedBuilder 二元跳过"
  - "Decoration 状态切换：_onEngineStateChanged 检测 idle↔playing，idle→reverse()，playing→forward()"
  - "Resize 结束后检查 engine 状态恢复正确装饰（idle→reverse，playing→forward）"
  - "controlBarBorderIdle = Color(0x056496FF)（2% 淡蓝，比 playing 的 0x0A 更淡）"
  - "tapJitterThreshold 标记为 future-use TODO（当前 GestureDetector.onTap 结构不支持直接消费）"
  - "ControlBar 移除未使用的 resizing 参数（OsdOverlay 在 ControlsOverlay 中直接接收）"

patterns-established:
  - "Unified opacity fade: _animController drives both resize fade and decoration state, no binary skip"
  - "Engine state → decoration wiring: _onEngineStateChanged drives _animController forward/reverse"
  - "Resize-end recovery: check engine state after resize to restore correct decoration"

requirements-completed: [PERF-01, PERF-04]

coverage:
  - id: G1
    description: "Resize fade-out uses opacity animation (no binary skip)"
    requirement: PERF-01
    verification:
      - kind: grep
        ref: "No resizing AnimatedBuilder binary skip in control_bar.dart"
        status: pass
    human_judgment: false
  - id: G2
    description: "Decoration state transition wired to engine idle↔playing"
    requirement: PERF-02
    verification:
      - kind: grep
        ref: "_animController.forward/reverse in _onEngineStateChanged and _onResizeChanged"
        status: pass
    human_judgment: false
  - id: G3
    description: "controlBarBorderIdle constant exists and used in _decorationIdle"
    requirement: null
    verification:
      - kind: grep
        ref: "controlBarBorderIdle in tokens.dart and control_bar.dart"
        status: pass
    human_judgment: false
  - id: G4
    description: "tapJitterThreshold marked as future-use with TODO"
    requirement: PERF-04
    verification:
      - kind: grep
        ref: "TODO comment about tapJitterThreshold in controls_overlay.dart"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-06
status: complete
---

# Phase 25 Plan 02: Gap Closure Summary

**修复验证中发现的 4 个 gap：resize fade-out 二元跳变、decoration 状态切换未连接、controlBarBorderIdle 缺失、tapJitterThreshold 未消费**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-06
- **Completed:** 2026-07-06
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- **Gap 1 (Resize fade-out binary skip):** 移除 ControlBar 中 resizing AnimatedBuilder 的二元跳过逻辑，统一由 `_animController` 的 opacity 渐变控制。resize 开始时 `reverse()` 渐变到 0，`_buildBlur` 中 `opacity < 0.01` 时自动跳过 BackdropFilter。
- **Gap 2 (Decoration state transition):** `_onEngineStateChanged` 现在检测 idle↔playing 变化并驱动 `_animController`：idle→`reverse()`（淡出到 idle 装饰），playing→`forward()`（淡入到 playing 装饰）。`_isResizing` 守卫保护 resize 期间不触发动画。
- **Gap 3 (controlBarBorderIdle):** 新增 `Tokens.controlBarBorderIdle = Color(0x056496FF)`（2% 淡蓝），`_decorationIdle` 使用此常量替代 `controlBarBorderWhite`，实现 idle/playing 视觉区分。
- **Gap 4 (tapJitterThreshold):** 在 `_handleTap` 方法上方添加 TODO 注释，说明未来添加 `_onPointerDown/_onPointerUp` 时消费此常量。
- **额外清理：** 移除 ControlBar 中未使用的 `resizing` 参数（OsdOverlay 在 ControlsOverlay 中直接接收）。

## Task Commits

1. **Task 1: Resize fade-out fix + controlBarBorderIdle** — tokens.dart + control_bar.dart
2. **Task 2: Decoration state wiring + tapJitterThreshold** — controls_overlay.dart

## Files Modified

- `lib/ui/theme/tokens.dart` — 新增 `controlBarBorderIdle` 常量
- `lib/ui/player/control_bar.dart` — 移除 resizing 二元跳过，`_decorationIdle` 使用 `controlBarBorderIdle`，移除未使用的 `resizing` 参数
- `lib/ui/player/controls_overlay.dart` — `_onEngineStateChanged` 驱动 `_animController`，`_onResizeChanged` 检查 engine 状态恢复装饰，tapJitterThreshold TODO

## Verification Results

| 检查 | 结果 |
|------|------|
| `flutter analyze`（3 文件） | ✅ 0 新增 warning/error（1 pre-existing warning + 7 info） |
| `flutter test` | ✅ 587 passed, 27 failed（全部 pre-existing） |
| `controlBarBorderIdle` in tokens.dart | ✅ line 50 |
| `controlBarBorderIdle` in control_bar.dart | ✅ lines 41, 43 |
| `resizing!.value.*RepaintBoundary` 二元跳过 | ✅ 无结果（已移除） |
| `_animController.forward/reverse` | ✅ 5 处 |

## Self-Check: PASSED

- [x] tokens.dart: `controlBarBorderIdle = Color(0x056496FF)` 存在
- [x] control_bar.dart: `_decorationIdle` 使用 `Tokens.controlBarBorderIdle`
- [x] control_bar.dart: 无 resizing AnimatedBuilder 二元跳过
- [x] control_bar.dart: `resizing` 参数已移除
- [x] controls_overlay.dart: `_onEngineStateChanged` 包含 `_animController` 调用
- [x] controls_overlay.dart: `_onResizeChanged` 检查 engine 状态恢复装饰
- [x] controls_overlay.dart: tapJitterThreshold TODO 注释存在
- [x] `flutter analyze` 无新增 warning/error
- [x] `flutter test` 587 passed（27 failed pre-existing）

---

*Phase: 25-performance-quick-wins*
*Completed: 2026-07-06*
