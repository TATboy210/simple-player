---
status: testing
phase: 05-e2e-resilience-verification
source: [05-VERIFICATION.md]
started: 2026-09-01T18:00:00+08:00
updated: 2026-09-01T18:00:00+08:00
---

## Current Test

number: 1
name: VER-04 归档边界补测——标题拖动 / ESC / 媒体键(卡片显示期间)
expected: |
  实机 `flutter run -d windows`,先触发一个错误使卡片显示,然后:
  1. 拖动自定义标题栏移动窗口——正常,卡片不抢焦点不跟随错位
  2. 按 ESC——按既有语义工作(退出全屏/关闭播放列表),卡片不拦截
  3. 按媒体键(播放/暂停/上一曲/下一曲)——播放控制正常响应
  全程卡片保持显示,无焦点抢占。
awaiting: user response

## Tests

### 1. VER-04 归档边界补测——标题拖动 / ESC / 媒体键(卡片显示期间)
expected: |
  实机 `flutter run -d windows`,先触发一个错误使卡片显示,然后:
  1. 拖动自定义标题栏移动窗口——正常,卡片不抢焦点不跟随错位
  2. 按 ESC——按既有语义工作(退出全屏/关闭播放列表),卡片不拦截
  3. 按媒体键(播放/暂停/上一曲/下一曲)——播放控制正常响应
  全程卡片保持显示,无焦点抢占。
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
