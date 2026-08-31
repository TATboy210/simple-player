---
status: complete
phase: 03-playback-error-card-bridge
source: [03-VERIFICATION.md]
started: 2026-08-31T03:30:00Z
updated: 2026-08-31T04:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. VER-04 Windows 实机冒烟——错误卡片显示期间宿主窗口交互不变
expected: |
  前置:实机运行 `flutter run -d windows`,触发任意错误使卡片显示(如打开一个损坏/不存在的
  媒体文件)。
  1. 卡片折叠态:点击卡片外控制栏按钮、标题栏、播放列表(若打开)——全部正常响应
  2. 键盘:按 Space/←/→/M——播放控制与静音正常,卡片不抢焦点
  3. 展开:点击卡片展开,确认五段详情可见且可在卡内滚动;点击卡片外区域——命中穿透正常
  4. 一键复制:点复制按钮 → OSD「已复制」;在任意文本框粘贴,确认诊断包内容与日志文件一致
  5. 全屏(D-10):进入全屏(双击画面/快捷键)——卡片仍显示在画面之上;退出全屏——卡片状态一致
  6. 关闭:点卡片关闭按钮——卡片消失,后续错误仍能再次弹出
result: issue
reported: "没有个专门启动调试的按钮，不反馈错误我也不知道"
severity: major

## Summary

total: 1
passed: 0
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-03-1
  truth: "存在开发用错误注入入口（调试触发），可按需构造合成错误走真实链路使卡片弹出，供日常验证与调试观察"
  status: failed
  reason: "User reported: 没有个专门启动调试的按钮，不反馈错误我也不知道"
  severity: major
  test: 1
  artifacts: []
  missing: []
