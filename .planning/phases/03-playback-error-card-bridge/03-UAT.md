---
status: testing
phase: 03-playback-error-card-bridge
source: [03-VERIFICATION.md]
started: 2026-08-31T03:30:00Z
updated: 2026-08-31T03:30:00Z
---

## Current Test

number: 1
name: VER-04 Windows 实机冒烟——错误卡片显示期间宿主窗口交互不变
expected: |
  卡片矩形外的一切交互照常:标题栏拖动/按钮、控制栏(播放/暂停/进度/音量)、播放列表操作;
  键盘快捷键(Space/←→/M/N/P/O 等)在卡片显示期间保持可用;进入 media_kit 全屏后卡片仍显示
  (D-10)、退出全屏后状态一致;一键复制将诊断包写入真实剪贴板(粘贴可验证)。
awaiting: user response

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
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
