---
status: complete
phase: 35-widget-tree-baseline-behavior-recovery
source:
  - .planning/phases/35-widget-tree-baseline-behavior-recovery/35-01-SUMMARY.md
  - .planning/phases/35-widget-tree-baseline-behavior-recovery/35-02-SUMMARY.md
  - .planning/phases/35-widget-tree-baseline-behavior-recovery/35-03-SUMMARY.md
started: 2026-08-11
updated: 2026-08-11
---

## Current Test

## Current Test

[testing complete]

## Tests

### 1. 替换 WindowBridge 后窗口操作仍正常
expected: 在保持同一个 PlayerScreen key 的情况下替换 FakeWindowService：视频 surface 保持同一 element identity；标题栏的 pin、最小化、最大化/还原、关闭和 F 键操作只作用于新的 bridge，旧 bridge 的 notifier 变化不再影响标题栏图标。
result: pass

### 2. GlassButton 重建后回调和禁用语义正确
expected: 同一 identity 重建后，Space/Enter 键分别只调用当前有效回调；从 enabled 变为 disabled 或 onPressed 为 null 后，点击和键盘激活均被阻止，并发布 disabled button semantics。
result: skipped
reason: 用户选择跳过人工确认

### 3. 自动化：历史 widget-tree 基线和禁止恢复边界已锁定
expected: Per-file read-only history baseline locks the current controls path and forbidden restoration boundaries.
result: pass
source: automated
coverage_id: D1

### 4. 自动化：PlayerScreen 到 ControlBar 组合保持正确
expected: Current PlayerScreen through ControlBar composition is evidenced by source and lifecycle tests.
result: pass
source: automated
coverage_id: D2

### 5. 自动化：Phase 35 播放器交互 quick gate 通过
expected: Playback, control, window, empty-state, error, drag/drop, and keyboard quick gate is repeatable without native MDK.
result: pass
source: automated
coverage_id: D3

### 6. 自动化：替换依赖和 GlobalKey reparent 只响应新 source
expected: Only the replacement PlayerVideoControls dependencies drive the retained State after same-frame source replacement and GlobalKey reparenting.
result: pass
source: automated
coverage_id: D1

### 7. 自动化：字幕 padding 生命周期隔离
expected: Subtitle padding preserves per-source base padding, applies the control-bar inset once, freezes replaced routes, and receives no writes after disposal.
result: pass
source: automated
coverage_id: D2

### 8. 自动化：Phase 35 完整回归 gate 通过
expected: The Phase 35 player and interaction regression gate remains passing.
result: pass
source: automated
coverage_id: D3

## Summary

total: 8
passed: 7
issues: 0
pending: 0
skipped: 1
blocked: 0

## Gaps

[none yet]
