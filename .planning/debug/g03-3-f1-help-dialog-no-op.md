---
status: diagnosed
trigger: "UAT G-03-3: 按 F1 弹出快捷键帮助对话框 — actual: 按f1没用 (real machine, Windows)"
created: 2026-08-31T00:00:00Z
updated: 2026-08-31T11:00:00Z
goal: find_root_cause_only
audit_acknowledged:
  milestone: v1.0
  at: 2026-09-01
  status: diagnosed
---

## Current Focus

hypothesis: CONFIRMED (mechanism level) — F1 的 KeyDownEvent 从未到达 KeyboardHandler._handleKeyEvent；从「按键到达」到「对话框可见」的整条代码链路在同一台实机上被全部测试证明为正确。首要具体成因为全屏进出循环后主焦点滞留在 handler Focus 子树之外（死键盘态），次选为物理 F1 未以 VK_F1 送达（Fn/厂商热键层）。
test: 5秒用户判别 — F1 失效瞬间立即按 Space：Space 同死 → 焦点链（代码可治）；Space 正常 → 硬件层（环境问题）
expecting: 判别结果决定修复方向（见 Resolution.fix）
next_action: 向用户回报 ROOT CAUSE FOUND + 判别步骤；修复走 gap-closure 计划

## Symptoms

expected: 按 F1 弹出快捷键帮助对话框
actual: 按f1没用 (real machine, Windows, Phase 3 UAT, error card visible at the time)
errors: none reported
reproduction: UAT Test 3, real machine `flutter run -d windows`
started: discovered 2026-08-31 during UAT

## Eliminated

- hypothesis: onShowHelp 回调未接线（null → 静默 no-op）
  evidence: player_keyboard_actions.dart:54 `onShowHelp: () => _showShortcutsHelp(context)` 非空；context 为 AnimatedBuilder builder context（alive，其上有 root Navigator）
  timestamp: 2026-08-31T00:30
- hypothesis: customBindings 覆盖破坏 F1 匹配
  evidence: player_feature.dart:82 `_customBindings = const {}` 硬编码空表；_keyMatches 空表走 key==defaultKey
  timestamp: 2026-08-31T00:35
- hypothesis: KeyF 全屏分支抢走 F1（分支顺序冲突）
  evidence: LogicalKeyboardKey.keyF ≠ LogicalKeyboardKey.f1，line 155 不匹配 F1；22 个 handler 单测全过（含 F1 与 ? 两分支）
  timestamp: 2026-08-31T00:40
- hypothesis: 内层 PlayerVideoControls Focus(autofocus) 截停按键
  evidence: player_video_controls.dart:459-497 该 handler 对 F1 返回 ignored → 冒泡；复现测试 H1c 证明内层持焦点时 F1 仍冒泡到 root 弹出对话框
  timestamp: 2026-08-31T00:45
- hypothesis: Phase 3 回归（error_banner 删除/挂载区改动移除 Focus 祖先）
  evidence: git log 5ef2a30e..HEAD 触碰键盘链的仅 2abb2645/a267a966（注入入口，非接线）；实机 error.log 栈帧行号(:199,:236)与 HEAD 完全一致 → UAT 跑的就是现行代码；同一会话同函数后置分支(注入 :199)实测可达
  timestamp: 2026-08-31T01:00
- hypothesis: 对话框 push 抛异常被吞 / l10n 缺 key
  evidence: 实机 error.log 当日 19 份报告全部为调试注入，F1 时点无任何异常入库（platformDispatcher 钩子会捕获并落盘）；编译期若缺 getter 则无法构建运行
  timestamp: 2026-08-31T01:10
- hypothesis: 对话框被错误卡片挂载层遮住（z-order）
  evidence: 复现测试 H1/H3：builder 挂载 + 卡片可见时 dialog 正常渲染可见；卡片为 Positioned 内在尺寸 + hit-test 穿透（CARD-02），不遮挡居中对话框
  timestamp: 2026-08-31T01:20
- hypothesis: 错误卡片抢焦点（CARD-01 反向担忧）
  evidence: error_card_host.dart:223 ExcludeFocus 包裹 ErrorCard（注释明确"卡内无焦点可请求"），点击卡片不会移动主焦点
  timestamp: 2026-08-31T00:50
- hypothesis: route 转场普遍破坏焦点恢复（全屏 pop / 对话框关闭）
  evidence: 复现测试 H2a（autofocus route push/pop）与 H2b（dialog open/close）均通过，pop 后 primaryFocus 正常回归且 F1 恢复工作
  timestamp: 2026-08-31T01:30

## Evidence

- timestamp: 2026-08-31T00:01
  checked: keyboard_handler.dart 全文
  found: F1 分支 :159-163（logicalKey 匹配 + ? 字符变体）→ onShowHelp?.call() → handled；handler 为 Focus(autofocus:true) 包裹整个 Scaffold（player_screen.dart:261-281 实际挂载）
  implication: 代码路径存在且挂载正确
- timestamp: 2026-08-31T00:20
  checked: shortcuts_help_dialog.dart / player_keyboard_actions.dart / player_screen.dart
  found: _showShortcutsHelp 用 PlayerScreen 存活 context 调 showDialog；dialog 渲染单一数据源 shortcutDefinitions
  implication: 对话框链路代码无缺陷
- timestamp: 2026-08-31T00:42
  checked: media_kit_video-2.0.1 video_texture.dart:461-464
  found: controls builder 每帧无条件调用，auto-hide 是 FadeTransition 不卸载子树 → 内层 Focus 恒挂载
  implication: 无「controls 隐藏卸载焦点节点」机制
- timestamp: 2026-08-31T01:05
  checked: flutter test test/widget/player/keyboard_handler_test.dart（实机）
  found: 22/22 全过，含 "F1 key triggers showHelp callback" 与 "? character" 用例（记忆中的 "KeyboardHandler F键" headless 失败未复现）
  implication: handler 逻辑在实机亦正确
- timestamp: 2026-08-31T01:25
  checked: 一次性复现测试（6 用例，已删，配方记录于 Resolution.fix 备注）
  found: H1 卡片可见+F1 → 对话框 PASS；H1 control 无卡片 PASS；H1c 内层 autofocus 持焦 PASS；H2a 全屏式 push/pop PASS；H2b dialog 开关 PASS；H2 焦点释放 differential → F1 静默死亡（复现症状形态）
  implication: 「主焦点在 handler 子树之外」是唯一能产生「F1 无声无息且零报错」的代码级机制
- timestamp: 2026-08-31T01:50
  checked: 实机 error.log（C:/Users/35490/AppData/Roaming/com.example/simple_player_flutter/logs/error.log，UAT 当日）
  found: 当日 3 会话 19 份报告全为 Ctrl+Shift+I 注入（08:52×2 / 09:58×16 / 10:03 UTC×1=18:03:34 本地，即 UAT 会话，启动后 8 秒）；栈帧 :199/:236 与 HEAD 行号逐一吻合 → UAT 实例跑现行代码；F1 时点之后零异常入库
  implication: (1) 同会话同函数的按键分发实测可达（注入成功）；(2) F1 若到达 handler 并 push 失败必有异常落盘 → F1 的 KeyDown 从未到达 handler
- timestamp: 2026-08-31T02:10
  checked: 实机进程/窗口侦察
  found: UAT 实例(PID 7328, 18:03:26 启动)至今仍存活；VM service 需 auth token 不可读取；尝试向其窗口发合成 F1 时发现用户正在直播（前台为直播工具，SetForegroundWindow 被系统阻断）→ 立即终止桌面实验并清理
  implication: 无法无损读取 UAT 实例活体焦点状态；合成键实验不作数（前台非目标窗口）
- timestamp: 2026-08-31T02:15
  checked: UAT 记录时序（03-UAT.md Test 1 步骤序）
  found: Test1 键盘验证(步骤2: Space/←/→/M)在全屏进出循环(步骤5)**之前**；步骤5 之后至 Test3 F1 之间无任何键盘验证记录
  implication: F1 是全屏循环后首次键盘观测 → 「循环致焦点滞留」与记录完全自洽，且无反证

## Resolution

root_cause: F1 的 KeyDownEvent 从未到达 KeyboardHandler._handleKeyEvent —— 从按键到达至对话框可见的整条代码链路（分支匹配/回调接线/showDialog/渲染 z-order/卡片遮挡）在同一台实机上被 22+6 项测试证明正确，且实机 error.log 证明 F1 时点零异常（若到达必留痕）。可达不成只剩「焦点链断裂」一类机制：按键分发起点 FocusManager.primaryFocus 的祖先链不含 KeyboardHandler 的 Focus 节点（dead-keyboard 态，签名=无声无息）。首要具体成因：UAT 序列中 F1 紧跟全屏进出循环（Test1 步骤5，空置态 F 键路径，已知「焦点回落边界」问题域 player_video_controls.dart:466-468），循环后主焦点滞留在 handler 子树外（route scope/root scope）；次选（环境侧）：物理 F1 未以 VK_F1 送达（Fn/厂商热键层）——弱势，因相邻 F 键在全屏循环中实测有效。
fix: (1) 判别实验（5 秒，用户执行）：F1 失效瞬间按 Space——Space 同死→焦点链；Space 正常→硬件层。(2) 若焦点链：最小治本 = KeyboardHandler 的快捷键分发从「per-route Focus 冒泡」改为 `HardwareKeyboard.instance.addHandler` 全局入口（UI 层单文件，绕开焦点树脆弱性，匹配无边框自绘壳定位；保留既有 EditableText 守卫与 media 键语义，零 kernel 改动）；并可在 addHandler 内对「F1 到达但 primaryFocus 在子树外」打 KernelLogger 埋点留证。(3) 若硬件层：非代码缺陷，建议帮助入口增加可点击按钮（title bar ? 按钮）作为不依赖物理 F1 的冗余入口。
verification: 待用户判别实验 + gap-closure 计划实现后实机复验
files_changed: []
note: 调查用一次性复现测试已按 read-only 约定删除；配方 = MaterialApp(builder: buildErrorCardMount) + home 内 KeyboardHandler(onShowHelp→showDialog) + ErrorReporterImpl.init(effects:[ErrorCaptureSnapshot.I.record]) 注入真实卡片 + 内层 Focus(autofocus:true) 返回 ignored 模拟 controls —— 6 用例结论已录 Evidence，gap-closure 时可原样重建为回归测试
