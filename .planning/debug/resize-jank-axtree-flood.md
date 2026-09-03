---
status: awaiting_human_verify
trigger: "立会话：已有仪器基线（今天 3 会话数据可入库），主攻 AXTree 洪流（嫌疑最大、最便宜：定位每帧改语义的 widget，视频区 ExcludeSemantics 一试便知）+ build 侧重建热点"
created: 2026-09-03
updated: 2026-09-03
---

## Current Focus

<!-- OVERWRITE on each update - reflects NOW -->

reasoning_checkpoint:
  hypothesis: "resize 期间界面抖动的主线程成本之一 = 控制栏子树（visible 态，~34 semantics 节点）随 MediaQuery 每帧 rebuild 每帧重新发射 semantics → accessibility_bridge 每帧 AXTree 同步失败（'Nodes left pending by the update: 34'）+ 错误日志洪流 + 语义遍历成本，白烧主线程 build 预算。根因机制：AutoHideController.resizing setter 只冻结 hide timer，既不 hide 控件也不 suppress 语义 → _autoHide.visible 全程 true → Visibility 保留控件挂载+活跃语义；isResizing 仅 bool 翻转（非每帧驱动），每帧驱动来自 MediaQuery/窗口 metrics 经全树传播。"
  confirming_evidence:
    - "auto_hide_controller.dart:99 hide() 被 `if (!_isPlaying.value || _resizing) return` 门禁；resizing setter(132-139) 只 cancel hide timer，不触碰 visible/不调 hide → resize 期间 _autoHide.visible 恒 true"
    - "player_video_controls.dart:810 Visibility(visible: _autoHide.visible) 在 visible=true 时保留 ControlBar 子树挂载并发射全部 semantics（~34 节点：按钮+滑块+glass+focus）"
    - "console 实测 resize 期间每帧刷 'Nodes left pending by the update: 34'，恒为 34 → 固定子树反复 pending，匹配控制栏固定 semantics 拓扑"
    - "Web 研究：该错误源自 Flutter/Chromium accessibility_bridge（ax_tree.cc），已知由快速 semantics 重建触发；非项目代码 bug"
    - "build-boundary 测试(1245行)已覆盖 hidden+resize 不再暴露语义，但未覆盖 visible+resize 的语义洪流——即本 bug 场景"
  falsification_test: "控制栏包 ExcludeSemantics(gated on resizing) 后：(a) AXTree error 流消失 → 确认控制栏是该 34 节点来源；(b) build P50 显著下降 → 语义遍历是 build 主成本之一。若 (a) 成立但 build P50 仍 8-11ms → 语义遍历非 build 主成本，真凶是 MediaQuery 驱动的全树 widget rebuild（次嫌转主嫌）；若 (a) 不成立（34 持续）→ 来源是标题栏或 Video texture 而非控制栏。"
  fix_rationale: "ExcludeSemantics(excluding: resizing) 在 resize 期间丢弃控制栏子树 semantics：消除每帧 AXTree 同步失败+错误日志+语义遍历三项主线程成本。机制直击：控制栏在 resize 期间本就视觉淡出（_animController.reverse）且用户在拖窗不读控件，suppress 语义零可用性损失；settle 后 VLB 自动恢复 excluding=false，语义即恢复。用 ValueListenableBuilder 而非 .value 直读，保证 settle 时 isResizing true→false 触发重建翻回 excluding=false（parent build 不被 resizing notifier 触发）。"
  blind_spots:
    - "未实测 34 节点是否精确等于控制栏子树（可能含标题栏 CustomTitleBar ~6 按钮 或 Video texture semantics）——ExcludeSemantics 实验即鉴别"
    - "未量化语义遍历占 build P50 的比例（vs widget rebuild 主体）——须人工 profile"
    - "raster P50 10-15ms（BackdropFilter blur 每帧重算 + 纹理采样）不在本 fix 覆盖范围——total jank 可能 build 降但 raster 仍超预算"
  candidate_causes:
    - "code: resize 期间控制栏 visible 子树每帧 re-emit semantics → AXTree 同步失败洪流（本 fix 主治）"
    - "code: MediaQuery 每帧变更驱动全树 widget rebuild（build P50 主成本候选，本 fix 不治，须次轮）"
    - "native/environment: BackdropFilter blur 每帧重算 + 纹理采样（raster P50 主成本，本 fix 不治）"
  and_gate: "YES for total jank. total P50>16.6ms 须 build+raster 双超预算。本 fix 只治 build-语义部分。若 build 降入预算但 raster 仍>16ms，total jank 持续。故本 fix 必要但可能不充分——人工 profile 验证 sufficiency。"

bug_class: Bohrbug
next_action: "CHECKPOINT 已达 — 待人工 profile 验证：播放视频→快速拖拽窗口→确认 (a) console 不再刷 'Failed to update ui::AXTree, Nodes left pending' 洪流；(b) jank60 是否显著下降。若 jank 仍高 → and_gate 命中，次轮治 MediaQuery 全树 rebuild（build）+ BackdropFilter blur（raster）。回复 'confirmed fixed' 或残留症状。"

## Symptoms

<!-- Written during gathering, then IMMUTABLE -->

expected: 窗口边缘拖拽/快速拉伸改变大小时，播放器界面平滑无抖动。
actual: 快速拉伸改变窗口大小时界面抖动（拖拽缩放期间）。
errors: console 每帧刷 "[ERROR:flutter/shell/platform/common/accessibility_bridge.cc(114)] Failed to update ui::AXTree, error: Nodes left pending by the update: 34"（数百条）。另：启动期 DwmCapabilities attribute 34/35/36 探测报错（Phase 6 06-01 半成品 D-04 RED，另案不混入本会话）。
reproduction: 播放视频 → 拖住窗口边缘快速拉伸改变大小 → 界面抖动。
started: bitsdojo 迁移（2026-09-03）后被用户注意到；仪器签名与迁移前 13 个 profile 会话一致（resize×播放慢性病），非迁移回归。

## Eliminated

<!-- APPEND only - prevents re-investigating -->

- (2026-09-03) 双包抢权力假设：bitsdojo 的 adjustChildWindowSize 仅在 bypass_wm_size==TRUE 时执行，该标志恒 FALSE 无处置位（bitsdojo_window_windows bitsdojo_window.cpp:22,484,541 死代码）；搬 Flutter 子窗口的只有模板 win32_window.cpp WM_SIZE → MoveWindow 一处。
- (2026-09-03) 纹理重建假设：4 会话 textureIdChanges=0（与迁移前 13 会话历史一致）。
- (2026-09-03) media_kit rect 驱动假设：rectChanges=0，rect 全程冻结 1280×720，media_kit 不参与 resize 期间的布局变化。

## Evidence

<!-- APPEND only - facts discovered -->

- timestamp: 2026-09-03
  checked: 仪器基线（bitsdojo 迁移后，播放中 drag+settle，4 会话）
  found: 会话1(16s): totalP50=22.4ms totalP95=45.8ms buildP50=8.0ms rasterP50=10.8ms jank60=56.9% samples=673；会话2(10s): totalP50=32.1ms buildP50=11.5ms rasterP50=15.2ms jank60=73.1% samples=428；会话3(1.4s): totalP50=18.6ms buildP50=2.6ms rasterP50=6.2ms jank60=54.8% samples=62；会话5(18s): totalP50=23.6ms totalP95=39.3ms buildP50=6.7ms buildP95=11.8ms rasterP50=14.0ms rasterP95=23.8ms jank60=67.2% samples=900。帧预算 16.6ms，totalP50 全部超标，jank60 55-73%。
  implication: 每帧 total 超预算是抖动直接来源；build 与 raster 双高。
- timestamp: 2026-09-03
  checked: console AXTree 洪流
  found: "[ERROR] accessibility_bridge.cc(114) Failed to update ui::AXTree, error: Nodes left pending by the update: 34" 在 resize 期间每帧刷出（数百条），Nodes pending 恒为 34。
  implication: 语义树每帧变更且 bridge 同步持续失败——主线程每帧白烧语义重建；"恒 34" 提示同一批节点反复 pending，来源可能固定于某个每帧 rebuild 的 semantics 子树。
- timestamp: 2026-09-03
  checked: 历史对照（memory: project_profile_session_findings / project_resize_render_three_fix / project_controlbar_resize_constant）
  found: 迁移前 13 会话同签名（resize×播放 build P50 2-9ms vs 空态 0.2ms）；textureIdChanges=0 曾据此实施三源修复与 filterQuality 动态切换；AXTree 洪流已知但从未专项治理。
  implication: 慢性病非迁移回归；AXTree 专项是新增量方向。
- timestamp: 2026-09-03
  checked: 相关代码入口
  found: lib/ui/player/player_screen.dart（WindowBorder 包 MouseRegion 包 keyboardHandler→scaffold→Video.controls builder；line ~337 builder (_, resizing, _) => Video(...) 响应 isResizing）；lib/kernel/diagnostics/video_texture_resize_probe.dart 与 resize_frame_metrics.dart（isResizing/resizeSessionId 信号源=window_resize_coordinator）；lib/kernel/window_bridge/window_resize_coordinator.dart（isResizing 置位/防抖复位）。
  implication: 语义树变更来源大概率在这些 resize 响应链上的 widget 中。
- timestamp: 2026-09-03
  checked: resize→可见性→语义链路全读（auto_hide_controller.dart / player_video_controls.dart build）
  found: AutoHideController.resizing setter(132-139) 只 cancel hide timer，不调 hide()；hide()(99) 被 `if (!_isPlaying.value || _resizing) return` 门禁 → resize 期间 _autoHide.visible 恒 true。player_video_controls.dart:810 Visibility(visible: _autoHide.visible) 在 visible=true 时保留 ControlBar 子树挂载+活跃语义。_animController.reverse()(585) 只淡出 decoration（glass glow），不触及 Visibility/语义。结论：resize 期间控制栏 visible 子树每帧随 MediaQuery rebuild 重新发射 ~34 semantics 节点。
  implication: 主线程每帧白烧：语义遍历 + AXTree 同步尝试 + 错误日志 ×数百。ExcludeSemantics(gated on resizing) 直击。
- timestamp: 2026-09-03
  checked: 每帧 driver 鉴别 + 既有测试覆盖
  found: isResizing 是 bool notifier（resize 起翻 true / settle 翻 false，仅 2 次/会话），非每帧 driver——_buildVideoSurface 的 VLB(filterQuality) 仅 2 次 rebuild。每帧 driver 是 MediaQuery/窗口 metrics 经全树传播（含 Scaffold 读 MediaQuery）。player_video_controls_test.dart:1245 既有测试只覆盖 hidden+resize（控件已隐藏后不暴露语义），未覆盖 visible+resize 的语义洪流场景（本 bug）。
  implication: 修复须用 ValueListenableBuilder(非 .value 直读) 保 settle 时翻回 excluding=false（parent build 不被 resizing notifier 触发）；须加 visible+resize 回归测试覆盖 bug 场景。

## Resolution

<!-- OVERWRITE as understanding evolves -->

root_cause: resize 期间 AutoHideController.resizing 只冻结 hide timer 不 suppress 语义，_autoHide.visible 恒 true → Visibility 保留控制栏子树挂载+活跃语义；MediaQuery 每帧变更经全树传播使控制栏每帧 rebuild 重新发射 ~34 semantics 节点 → accessibility_bridge 每帧 AXTree 同步失败（"Nodes left pending by the update: 34"）+ 错误日志洪流 + 语义遍历成本，白烧主线程 build 预算。（必要非充分：total jank 还含 MediaQuery 全树 widget rebuild + BackdropFilter raster 成本，见 and_gate）
fix: PlayerVideoControls.build() 返回树用 ValueListenableBuilder<bool>(widget.resizing) → ExcludeSemantics(excluding: resizing) 包裹；resize 期间丢弃控制栏语义，settle 后 VLB 自动恢复。null resizing（测试）走不包裹分支。
verification:
  guardrail_verdict: accepted（所有可自验信号通过；jank/AXTree-flood 实测须人工 profile）
  static_analysis: PASS — flutter analyze 0 error / 0 warning（64 pre-existing info 全部不在改动行）
  affected_tests: PASS — player_video_controls_test(含新回归) + build_boundary + lifecycle + control_bar + progress_bar + osd_overlay + glass_container + auto_hide，177/177
  full_widget_suite: PASS — test/widget/ 422/422，零回归
  regression_test: PASS — 新增 "resize 期间 suppress 控制栏语义 settle 后恢复（AXTree 洪流回归）"；用 SemanticsOwner.rootSemanticsNode 遍历 assembled 树验证（find.bySemanticsLabel 查 renderObject.debugSemantics，ExcludeSemantics 翻转时子节点 debugSemantics 拖留旧值不可靠）。基线 contains('Play')、resize isNot(contains)、settle contains。移除 ExcludeSemantics 则 isNot 断言失败 → mutation guardrail 有效。
  framework_mechanism_confirmed: PASS — 读 Flutter SDK 源码 RenderExcludeSemantics.visitChildrenForSemantics(proxy_box.dart:4417) excluding=true 早返回，assembled owner 树丢弃子树 → accessibility_bridge 收不到该 34 节点 → AXTree 同步不再失败。production 行为已由测试间接证实（assembled 树 resize 期间无 'Play'）。
  original_issue_repro: CANNOT self-verify — 需真实窗口拖拽 + profile（无 headless 途径复现 AXTree 洪流与 jank）。本会话 falsification_test 的机制部分已自验（assembled 树语义丢弃）；jank 数值下降须人工 profile 确认 sufficiency（and_gate: 必要非充分）。
files_changed: [lib/ui/player/player_video_controls.dart, test/widget/player/player_video_controls_test.dart]
