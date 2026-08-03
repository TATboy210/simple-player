# media_kit 内部全屏玻璃控制层：总执行计划

> **恢复规则（强制）**：每次上下文压缩、重新进入会话或开始新阶段前，先读取本文件和以下文件：
> - `.planning/fullscreen-glass-controls-prd.md`
> - `.planning/fullscreen-glass-controls-architecture.md`
> - `.planning/fullscreen-glass-controls-task-list.md`
> - `.planning/fullscreen-glass-controls-tech-doc.md`
> - `.planning/debug/fullscreen-white-border-gap.md`
>
> 然后执行“当前阶段”中第一个未勾选项目。不得根据记忆跳过测试、风险确认或验收步骤。

## 已确认的技术决策

1. 播放器全屏使用 `media_kit` 内部 fullscreen route，不以 `window_manager.setFullScreen` 作为主方案。
2. 玻璃控制栏必须由 `Video.controls` 构建，才能随着 media_kit fullscreen route 重建。
3. 不修改 `media_kit`、pub cache 或历史 `packages/fullscreen_window` 插件。
4. `WindowService` 只管理普通应用窗口；它的 `WindowMode.fullscreen` 不得再作为视频内部全屏状态来源。
5. F、ESC、双击和全屏按钮必须只向唯一的 `FullscreenCoordinator` 发出请求。
6. 绝不以仅更新项目状态的 callback 覆盖 `Video` 默认 native fullscreen callback。
7. Windows 白边/frameless 是独立问题，必须与控件迁移分别验证。

## 基线

- 基线提交：`336b1f82 fix(player): document fullscreen controls migration baseline`
- 依赖锁定版本：`media_kit_video 1.3.1`、`window_manager 0.5.2`
- 当前 UI 根因：`PlayerScreen` 中的 `Video.controls` 返回空 widget，外层 `ControlsOverlay` 无法随 fullscreen route 迁移。
- 已知环境限制：headless `flutter test` 存在既有 `mdk.dll` FFI 失败；必须通过定向测试、对照基线或 stash 鉴别，禁止删除断言或 skip 测试掩盖失败。

## 体验与维护风险

| 类别 | 风险 | 防护措施 |
| --- | --- | --- |
| 体验 | fullscreen route 内没有 controls | 将 glass controls 迁入 `Video.controls` |
| 体验 | F/ESC/双击/按钮竞争导致闪退或反向切换 | 协调器串行化并拒绝转场期间的重复请求 |
| 体验 | fullscreen 点击设置或播放列表后面板不可见 | 首轮 fullscreen controls 隐藏跨 route 入口，进入前关闭播放列表 |
| 体验 | 控制栏遮挡字幕 | controls visibility 驱动当前 `VideoState` 的字幕 bottom padding |
| 维护 | `WindowMode` 与 route/native HWND 分裂 | 以 coordinator phase 作为 UI 单一状态源 |
| 维护 | native callback 被替换 | 保留 media_kit 默认 callback，仅在验证过的边界同步状态 |
| Windows | native exit 重加 `WS_OVERLAPPEDWINDOW` | 退出后恢复 frameless，并回归验证 Flutter resize |
| 测试 | fake window state 造成伪覆盖 | coordinator 单测 + controls widget 测试 + Windows 手工 smoke test |

## 当前阶段：Phase A — 隔离窗口白边与普通窗口职责

- [x] 在 `waitUntilReadyToShow` 中调用 `setAsFrameless()`，消除 hidden title bar 的 8px NCCALCSIZE inset。
- [ ] 为 fullscreen native exit 后的 frameless 恢复定义受测接口与调用时机。
- [ ] 保护 fullscreen 期间的 geometry，不将显示器 bounds 持久化成普通窗口尺寸。
- [ ] 验证 `SmartDragToResizeArea` 在普通窗口、最大化恢复、fullscreen 退出后仍可 resize。
- [ ] Windows 手工验收：普通窗口、最大化、最大化恢复、F/ESC、按钮、双击、多显示器与重启 geometry。

**阶段出口**：白边和 resize 的验证结论独立记录；不得通过 controls padding/margin 修复白边。

## Phase B — 先以 TDD 消除双状态源

- [ ] 使用 `dart-testing` agent 设计并写入 RED tests。
- [ ] 新增 `FullscreenPhase`：`windowed`、`entering`、`fullscreen`、`exiting`。
- [ ] 新增可单测的 `FullscreenCoordinator`，包含 `requestToggle()`、`requestExit()`、重复请求抑制和失败回滚。
- [ ] `VideoState` 未挂载时不得乐观写入 fullscreen phase。
- [ ] 替换 `PlayerScreen`、`player_keyboard_actions.dart`、`ControlsOverlay` 的 `setMode(...) + toggleFullscreen()` 双写路径。
- [ ] ESC 只调用明确退出；F、双击、按钮只调用 toggle request。
- [ ] 修正 `keyboard_handler_test.dart` 中 F 键仍断言 callback 次数为 0 的过期测试。
- [ ] 禁止用 `WindowMode.fullscreen` 或 maximize/unmaximize 推断 video fullscreen。

**阶段出口**：协调器单测覆盖成功、失败、未挂载、重复请求、明确退出与外部退出同步；原双写路径不存在。

## Phase C — 验证 `Video.controls` 的 route-safe 宿主

- [ ] 先建立最小 controls builder，替换 `controls: (_) => const SizedBox.shrink()`。
- [ ] 验证 windowed 和 fullscreen route 都渲染 controls builder 产物。
- [ ] 验证不会覆盖 media_kit 默认 native enter/exit callback。
- [ ] 明确 fullscreen 生命周期同步机制；仅使用已验证的公开 API/安全包装。
- [ ] 进入 fullscreen 前关闭播放列表；设置打开时定义拒绝进入或关闭策略。
- [ ] 为无 MDK 的 widget 测试扩展可控 seam，不能以真实 native runtime 作为唯一覆盖路径。

**阶段出口**：最小 glass host 可在两个 route 显示，并且 native fullscreen 保持有效。

## Phase D — 迁移和优化玻璃控制层

- [ ] 将 `ControlsOverlay` 提取为 route-safe `GlassVideoControls`（可保留兼容外壳）。
- [ ] 保留 `AutoHideController`、`ControlBar`、`ProgressBar`、音量、倍速、字幕、OSD、错误条和 `Tokens.*` 视觉风格。
- [ ] controls 可见性改变时调整当前 `VideoState` 的 subtitle padding。
- [ ] 全屏状态下显示 `Icons.fullscreen_exit`；窗口状态下显示 `Icons.fullscreen`。
- [ ] 将 `MaterialDesktopVideoControls` 的行为模式移植为项目实现：focus、F、ESC、400ms 双击、hover、自动隐藏和交互冻结。
- [ ] fullscreen 首轮隐藏设置和播放列表等原 route 不可见入口。
- [ ] 删除 `PlayerScreen` Stack 中重复的外层 `ControlsOverlay`。

**阶段出口**：窗口态与内部全屏态均为同一玻璃体验；播放主功能完整，无跨 route 的失效入口。

## Phase E — 清理、回归与审查

- [ ] 清理 `_fullscreenIntent` 及依赖 maximize/unmaximize 推断的逻辑。
- [ ] 将 `WindowMode.fullscreen` 从视频全屏职责移除、隔离或语义化重命名。
- [ ] 清理旧“方案 B”与 `fullscreen_window` 相关的过时注释和测试假设。
- [ ] 运行 `flutter analyze`。
- [ ] 运行 coordinator、keyboard、controls、PlayerScreen、window service 的定向测试。
- [ ] 运行完整 `flutter test`，逐项鉴别既有 `mdk.dll` 与历史失败。
- [ ] 使用 `flutter-code-reviewer` 复审；修复所有 CRITICAL/HIGH 问题。
- [ ] 使用 `flutter-security` 审查涉及窗口/文件边界的新调用。
- [ ] Windows 手工完成 10 轮：按钮进/出、F/ESC、双击/ESC、混合退出与系统返回。

## 恢复后必做检查清单

1. 执行 `git status --short`，确认上一阶段是否留下未提交变更。
2. 读取本总计划和五份关联规划文档。
3. 执行 `TaskList`，确认当前未完成任务。
4. 从“当前阶段”第一个未勾选项继续；先更新对应任务为 `in_progress`。
5. 修改前先查阅受影响符号；涉及 Flutter/media_kit API 不确定性时使用 Context7。
6. 每写完代码立即补相应测试，随后运行最小定向检查。
7. 代码改动完成后必须运行 `flutter-code-reviewer`；触达文件/窗口系统边界时再运行 `flutter-security`。
8. 完成一个阶段后更新本文件的 checkbox 与 `.planning/fullscreen-glass-controls-task-list.md`，然后提交该阶段；没有用户明确请求不得 push。

## 验收命令

```bash
flutter analyze
flutter test test/unit/kernel/bridge/window_service_test.dart
flutter test test/widget/player/keyboard_handler_test.dart
flutter test test/widget/player/controls_overlay_test.dart
flutter test test/widget/player/player_screen_stop_empty_state_test.dart
flutter test test/integration/controls_flow_test.dart
flutter test
```

> 新增 coordinator 测试后必须加入上述定向测试列表。完整测试失败时，先与基线及已知的 `mdk.dll`/历史 failures 比较，再判定是否为本次回归。
