# PRD：media_kit 内部全屏玻璃控制层

## 背景

播放器目前使用 `VideoState.toggleFullscreen()` 进入 media_kit 内部全屏，但 `ControlsOverlay` 位于 `Video` 外层，无法随 fullscreen route 迁移。现有按钮和快捷键还会分别更新 `WindowService` 与 media_kit，造成状态可能不同步。

## 目标

1. 继续使用 media_kit 内部全屏及其 Windows 原生 fullscreen 能力。
2. 让玻璃风格控制层在窗口模式和内部 fullscreen route 中都可见、可隐藏、可退出全屏。
3. 使 F、Esc、双击与全屏按钮走唯一、串行且可测试的全屏请求路径。
4. 将窗口白边修复与播放器 controls 迁移隔离验证。
5. 不修改 `media_kit` 第三方源码，不重新接入仓库中的 `fullscreen_window` 历史插件。

## 非目标

- 不改为 `window_manager.setFullScreen` 作为播放器主全屏方案。
- 首轮不在内部全屏 route 中展示设置和播放列表等跨 route 浮层。
- 不复用跨 Navigator 的 Widget、FocusNode 或 OverlayEntry。

## 功能需求

- `Video.controls` 返回项目玻璃 controls，而非空控件。
- 全屏 controls 支持播放、暂停、seek、音量、字幕、速度、全屏退出、OSD 和错误提示。
- 项目玻璃 controls 保留自动隐藏、鼠标唤起、交互冻结和字幕避让。
- 进入全屏前关闭播放列表；设置面板打开时不允许直接进入全屏或需先采用明确关闭策略。
- 全屏状态仅在 media_kit 生命周期确认后更新；快速重复请求不反向切换。
- 退出全屏后恢复 frameless 窗口装饰并防止全屏瞬态几何写入普通窗口持久化。

## 验收标准

- F、Esc、双击、全屏按钮在 Windows 实机中可一致进入/退出全屏。
- 玻璃控制栏在 media_kit fullscreen route 内显示并可自动隐藏/恢复。
- 连续 10 次进入/退出无双层 controls、无卡死、无标题栏或鼠标状态残留。
- 进入/退出后无白边，窗口化 resize 仍可使用。
- `flutter analyze` 无 error，新增或更新的定向测试通过；已知 headless `mdk.dll` 失败单独鉴别。
