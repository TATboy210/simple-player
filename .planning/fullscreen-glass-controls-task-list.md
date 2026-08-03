# 全屏玻璃控制层任务列表

## Phase A：隔离窗口边框修复

- [ ] 保留并审查 `WindowService.init()` 中 `setAsFrameless()` 的时序。
- [ ] 增加全屏/退出后 frameless 恢复设计与测试入口。
- [ ] Windows 手测：窗口四边、最大化、恢复、resize、多显示器、重启 geometry。

## Phase B：建立全屏协调器

- [ ] 为 `FullscreenPhase` 与 `FullscreenCoordinator` 编写 RED 单测。
- [ ] 实现 requestToggle/requestExit 串行化与过渡态去重。
- [ ] 用单一 coordinator 替代 PlayerScreen、键盘与双击中的双写逻辑。
- [ ] 更新 F/ESC 测试和快捷键帮助文案。
- [ ] 在 Video 真正进入/退出确认后同步 UI 状态，保留 media_kit 默认 native callback。

## Phase C：验证 Video.controls 宿主

- [ ] 提取 controls factory，移除 `Video.controls: SizedBox.shrink()`。
- [ ] 删除 PlayerScreen 外层 Stack 中重复的 controls 实例。
- [ ] 验证普通与内部 fullscreen route 都构建 controls。
- [ ] 在进入全屏前关闭播放列表；定义设置面板策略。
- [ ] 运行定向 widget 测试和 Windows 实机 smoke test。

## Phase D：迁移玻璃控制层

- [ ] 将 ControlsOverlay 拆分为 route-safe 的 `GlassVideoControls` 和纯业务适配。
- [ ] 迁移 AutoHide、鼠标、字幕 padding、OSD、ErrorBanner、ControlBar。
- [ ] 避免全屏 route 展示跨 route 无法工作的入口。
- [ ] 逐项从 MaterialDesktopVideoControls 对齐成熟交互：focus、双击、自动隐藏、拖动冻结、退出语义。
- [ ] 覆盖玻璃 controls 在 windowed/fullscreen 的行为回归。

## Phase E：清理与验收

- [ ] 删除 `_fullscreenIntent`、旧 `WindowMode.fullscreen` 镜像路径和过期注释。
- [ ] 禁止接入 `packages/fullscreen_window` 历史插件。
- [ ] 运行 flutter analyze、定向测试、完整测试并鉴别既有 mdk.dll 失败。
- [ ] 完成 Windows 手工验收矩阵：F、Esc、按钮、双击、10 次循环、最大化、多显示器、退出后 resize、重启。
- [ ] 完成 Flutter 代码审查，修复 CRITICAL/HIGH 问题。
