---
status: testing
phase: 39-progress-bar-three-symptoms-root-cause
source: [39-VERIFICATION.md]
started: 2026-08-22T16:43:49Z
updated: 2026-08-22T16:43:49Z
---

## Current Test

number: 1
name: Windows hover-preview visual backstop (真实鼠标悬停时间气泡)
expected: |
  打开真实视频后，鼠标悬停进度条：
  - 时间气泡可见且随指针横向移动更新（25% 处约 0:15，75% 处约 0:45，以 60000ms 时长计）
  - 指针普通离开后气泡消失
  - 拖拽中指针离开不清除 drag 气泡
  - 气泡未被 AppTooltip 替换或出现嵌套
awaiting: user response

## Tests

### 1. Windows hover-preview visual backstop (真实鼠标悬停时间气泡)
expected: 气泡可见、跟随指针、离开消失、drag 保持、无 AppTooltip 嵌套
result: [pending]

### 2. Seek-hold no-rollback / timeout invariant (拖拽松手不回跳)
expected: |
  播放中拖拽进度条并松手：
  - 旧 position 事件不使 thumb 回跳（保持拖拽目标直到新位置到达容差内）
  - 松手后 thumb 仅在目标到达或超时兜底时释放
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
