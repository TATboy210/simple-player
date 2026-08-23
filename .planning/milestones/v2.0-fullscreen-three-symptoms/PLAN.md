# Milestone v2.0 — 全屏三症状修复

**状态**：✅ 完成（2026-08-23 实机验证三症状全部通过：无缝隙 / 图标还原 / 退出无单帧异常）。
**约束（用户确认）**：保持 media_kit 原生全屏链路（默认 `Utils.EnterNativeFullscreen`），media_kit 核心零改动；不改 window_manager 插件。
**分支**：feat/v1.8-stability-polish-plan-02-02
**完整计划**：`C:\Users\35490\.claude\plans\agent-skill-token-media-kit-widget-typed-conway.md`
**取证文档**：`.planning/debug/fullscreen-exit-frame.md`

## 实机验证记录（2026-08-23）

- 小窗→全屏：四边无缝隙 ✓（C1）
- 最大化→全屏：无缝隙 ✓；退出正确恢复最大化 ✓
- 按钮/F/ESC 退出：图标立即还原 enter 图标、标题栏/cursor 正常 ✓（C2）
- 连续多轮进出全屏（10+ 轮）：无累积问题、无单帧画面异常 ✓（C3 通过；
  证据链：进出会话均 `no-dart-signal-change`，Dart 侧零重建，与过渡期
  UI 动画竞争类根因一致 — C2 后 `_isFullscreenTransition` 由 mode 可靠
  置位，过渡期控制栏动画被抑制）
- 探针会话分类修正后正确输出 `sessionKind: fullscreen-exit` ✓

## 附带尝试（已撤回）

- `184dc804` 禁用 DWM 非客户区渲染（DWMNCRP_DISABLED）用于消除退出时
  Windows 风格标题栏闪现 → 用户要求撤回（`622eece5`）。若该闪现后续仍
  需要处理，候选方案：仅在全屏样式切换过渡窗口期临时禁用 DWM 非客户区
  渲染，恢复几何落定后恢复（窗口态外观零影响）。

## 症状与根因

| # | 症状 | 根因（源码定位） |
|---|------|------------------|
| 1 | 小窗入全屏边缘有缝（最大化入无缝） | window_manager 0.5.2 插件 WM_NCCALCSIZE delegate 先于 runner，hidden 标题栏分支对非最大化窗口施加 8px 客户区内缩；media_kit 原生全屏只摘 WS_OVERLAPPEDWINDOW + resize 到显示器，不更新插件状态 |
| 2 | 退出全屏后按钮不还原 fullscreen 图标 | media_kit 2.0.1 全屏 route 把窗口态 VideoState 的 context 换成 route context（窗口态实例 isFullscreen()=true）；退出后 refreshView() 空实现 + VideoViewParameters 相等抑制重建，notifier 永不同步回。连带：F/ESC 路径不调 setMode，WindowMode 卡 fullscreen |
| 3 | 退出全屏一帧画面异常 | 窗口原生恢复与窗口态 Video/controls 首次重建交叠；具体类型待探针证据 |

## 修复记录

| Commit | 内容 | 验证 |
|--------|------|------|
| `b291d7a` | C1：runner（flutter_window.cpp）仅在 media_kit 全屏样式（WS_OVERLAPPEDWINDOW 已摘除）时抢先 WM_NCCALCSIZE return 0；WindowResizeCoordinator._settle 全屏期间跳过 windowSize 更新（防巨窗启动） | analyze 0；window_service_test 49 过；flutter build windows --debug 成功 |
| `0286c22` | C2：PlayerVideoControls 图标/AutoHide/cursor/过渡标记统一由 WindowMode 驱动；F/ESC 路径先同步 mode 再切 route；新增图标跟随 mode 回归用例 | analyze 0；player 目录+集成 297 过；全量 1270 过 |
| `4704ae4` | C3：探针增加 mode 维度（sessionKind=fullscreen-enter/exit），取证文档 | analyze 0；diagnostics 23 过 |

（另：`2de126f` 为工作树既有关窗 hide-first 改动，先行隔离提交，非本 milestone。）

## 待办

- [x] 实机验证 C1/C2（2026-08-23 通过）
- [x] C3 退出单帧异常（2026-08-23 实机通过，无需额外修复 commit）
