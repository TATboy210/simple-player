---
status: complete
phase: 39-progress-bar-three-symptoms-root-cause
source: [39-VERIFICATION.md]
started: 2026-08-22T16:43:49Z
updated: 2026-08-23T00:20:00+08:00
---

## Current Test

[testing complete]

## Tests

### 1. Windows hover-preview visual backstop (真实鼠标悬停时间气泡)
expected: 气泡可见、跟随指针、离开消失、drag 保持、无 AppTooltip 嵌套
result: pass

### 2. Seek-hold no-rollback / timeout invariant (拖拽松手不回跳)
expected: |
  播放中拖拽进度条并松手：
  - 旧 position 事件不使 thumb 回跳（保持拖拽目标直到新位置到达容差内）
  - 松手后 thumb 仅在目标到达或超时兜底时释放
result: issue
reported: "拖拽松手Tooltip会回跳"
severity: minor


## Summary

total: 2
passed: 1
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-39-2
  truth: "拖拽松手后时间气泡保持拖拽目标时间，不随旧 position 事件回跳"
  status: failed
  reason: "User reported: 拖拽松手Tooltip会回跳"
  severity: minor
  test: 2
  artifacts: []
  missing: []
