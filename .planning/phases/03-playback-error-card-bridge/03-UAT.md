---
status: partial
phase: 03-playback-error-card-bridge
source: [03-VERIFICATION.md]
started: 2026-08-31T03:30:00Z
updated: 2026-08-31T06:00:00Z
---

## Current Test

number: 4
name: 调试入口移除(用后即撤)
expected: |
  Ctrl+Shift+I 注入入口及 F1 帮助条目、l10n key 从 debug 构建移除(用户验证完毕,日常使用不需要)
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
result: pass
note: "G-03-1 注入入口按预期工作(用户借此观察到卡片并给出后续反馈);入口本身已由用户决定用后即撤(见 Test 4)"

### 2. 卡片位置——视频区域左上角
expected: |
  卡片出现在视频区域左上角,不遮挡自定义标题栏(当前实现位于窗口左上角压在标题栏前)
result: issue
reported: "报错窗口现在在自定义标题栏前面，调整下位置，在播放视频区域的左上角，而不是在左上角标题栏前面"
severity: major

### 3. F1 快捷键帮助
expected: |
  按 F1 弹出快捷键帮助对话框
result: issue
reported: "按f1没用"
severity: major

### 4. 调试入口移除(用后即撤)
expected: |
  Ctrl+Shift+I 注入入口及 F1 帮助条目、l10n key 从 debug 构建移除(用户验证完毕,日常使用不需要)
result: issue
reported: "还有测试用的入口记得移除"
severity: minor

## Summary

total: 4
passed: 1
issues: 3
pending: 0
skipped: 0
blocked: 0

## Deferred Follow-Ups

- test: 1
  idea: "日志文件默认位置改为正式版编译产物的根目录下 logs/ 文件夹(修订 Phase 2 D-03 的 Application Support 默认值;与 Phase 4 SET-02 日志位置配置合并实现;注意 MSIX 打包下 exe 旁写入会被文件系统虚拟化重定向,构建产物目录分发不受影响)"
  deferred_at: 2026-08-31
- test: 1
  idea: "报错弹窗后端持续优化:功能完备性、代码质量、系统占用(基于既有计划方案滚动推进;用户指示方向,具体范围在下次规划时细化)"
  deferred_at: 2026-08-31
- test: 1
  idea: "错误卡片前端视觉重设计交由前端设计 AI——交接文档已存桌面:错误弹窗前端设计AI交接文档.md(设计规范产出后走实现流程)"
  deferred_at: 2026-08-31

## Gaps

- gap_id: G-03-1
  truth: "存在开发用错误注入入口（调试触发），可按需构造合成错误走真实链路使卡片弹出，供日常验证与调试观察"
  status: resolved
  resolved_by: 03-05-PLAN
  resolved_at: 2026-08-31
- gap_id: G-03-2
  truth: "错误卡片位于视频区域左上角，不遮挡自定义标题栏"
  status: failed
  reason: "User reported: 报错窗口现在在自定义标题栏前面，调整下位置，在播放视频区域的左上角，而不是在左上角标题栏前面"
  severity: major
  test: 2
  root_cause: "D-10 挂载层选择 MaterialApp.builder 顶层 Stack 的 Positioned(left:0, top:0)，坐标系是整个窗口而非视频区域——窗口左上角即标题栏位置"
  artifacts:
    - path: "lib/app.dart"
      issue: "buildErrorCardMount 的 Positioned 定位基于窗口原点"
  missing:
    - "定位改到视频区域左上角:全屏时=窗口左上角(D-10 保持);窗口化时需向下偏移标题栏高度(视频区上缘);可通过 GlobalKey/布局回调取视频区位置或按标题栏高度常量偏移"
- gap_id: G-03-3
  truth: "按 F1 弹出快捷键帮助对话框"
  status: failed
  reason: "User reported: 按f1没用"
  severity: major
  test: 3
  artifacts: []
  missing: []
- gap_id: G-03-4
  truth: "调试注入入口(Ctrl+Shift+I 及其 F1 条目、l10n key)从源码移除"
  status: failed
  reason: "User reported: 还有测试用的入口记得移除"
  severity: minor
  test: 4
  root_cause: "G-03-1 的注入入口已完成验证使命,用户决定用后即撤(日常使用不需要)"
  artifacts:
    - path: "lib/ui/player/keyboard_handler.dart"
      issue: "kDebugMode 门控的 Ctrl+Shift+I 分支与 shortcutDefinitions collection-if 条目"
  missing:
    - "移除 _injectTestError 及 Ctrl+Shift+I 分支、shortcutDefinitions 条目、shortcutDebugInjectError l10n key(双 ARB)、相关测试用例"

  reason: "User reported: 没有个专门启动调试的按钮，不反馈错误我也不知道"
  severity: major
  test: 1
  root_cause: "设计/范围缺失而非缺陷：Phase 3 需求集从未包含开发用错误注入入口；注入缝已生产就绪——ErrorReporterImpl.I 的 4 个公开 intake 方法一次调用即走真实链路（FIFO→presentation→Host→Card+effects 快照+error.log），零 kernel 改动"
  artifacts:
    - path: "lib/kernel/diagnostics/error_reporter.dart"
      issue: "非缺陷——现有公开 intake 即注入接口（reportPlatformSafely/reportPlayerError），forTesting 为测试专用不应使用"
    - path: "lib/ui/player/keyboard_handler.dart"
      issue: "缺少 kDebugMode 门控的注入快捷键（Ctrl+Shift+D 调试导出先例在 :171-178，可循例）"
  missing:
    - "kDebugMode 门控快捷键（建议 Ctrl+Shift+I，循 Ctrl+Shift+D 内联先例）调用 ErrorReporterImpl.I.reportPlatformSafely(StateError('调试注入的合成错误 #<计数>'), StackTrace.current)"
    - "OsdService.I.show('已注入测试错误', icon: Icons.bug_report) 反馈"
    - "合成消息需带计数/时间戳以绕过 reporter 10s 去重窗口，保证每次按下出新卡"
    - "可选：shortcutDefinitions + F1 帮助条目 + l10n ARB key"
  debug_session: ".planning/debug/g03-1-no-error-injection-entry.md"
