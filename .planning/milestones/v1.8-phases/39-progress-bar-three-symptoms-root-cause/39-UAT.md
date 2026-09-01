---
status: diagnosed
phase: 39-progress-bar-three-symptoms-root-cause
source: [39-VERIFICATION.md]
started: 2026-08-22T16:43:49Z
updated: 2026-08-23T00:35:00+08:00
audit_acknowledged:
  milestone: v1.0
  at: 2026-09-01
  gap_snapshot: "diagnosed::scenarios=0"
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
  root_cause: "seek() 的乐观更新 (positionMs.value = clamped) 同步满足 _beginSeekHold 的到达容差，_dragNotifier 立即清除（保持 0ms）；随后 Tooltip 回退到陈旧的 hover.x（拖拽开始时的鼠标 x 坐标，拖拽中 onHover 不触发），短暂显示旧位置时间后才被下一次指针移动纠正"
  artifacts:
    - path: "lib/ui/player/player_video_controls.dart"
      issue: "L207-211 seek() 乐观写入 positionMs 使 seek-hold 容差立即满足，v2 事件驱动保持逻辑被完全旁路"
    - path: "lib/ui/player/progress_bar.dart"
      issue: "L216-219 _beginSeekHold 注册后立即 listener.call() 同步清除 drag；L343 dragEnd 重赋陈旧 _hoverX；L377-381 Tooltip 分支无陈旧 position 防护"
  missing:
    - "seek-hold 不由组件自身乐观写入满足：拆分乐观/流确认两个 listenable，或跳过 onSeek 后首次通知，或 hold 期间抑制流 position"
    - "dragEnd 时将 hover.x 同步为松手分数，避免清除 drag 后回退拖拽前位置"
    - "回归测试：拖拽松手 pump 一帧（无指针移动），断言 Tooltip 仍显示拖拽目标时间"
  debug_session: ""
