# 技术设计：media_kit 内部全屏玻璃控制层

## 现状约束

`media_kit_video` 的内部全屏会使用 root Navigator 推入 fullscreen route，并用原始 `Video.controls` builder 重建 `Video`。因此位于 `PlayerScreen` 外层 Stack 的 controls 不会进入全屏 route。媒体库的默认 `onEnterFullscreen` / `onExitFullscreen` 负责 Windows 原生 fullscreen，项目不能用只同步状态的 callback 覆盖它。

## 目标结构

```text
PlayerScreen
  ├─ Video
  │   └─ controls(VideoState) => GlassVideoControls
  ├─ EmptyState / DropHandler
  ├─ PlaylistPanel（窗口 route）
  └─ SettingsOverlayShell（窗口 route）

FullscreenCoordinator
  ├─ requestToggle / requestExit
  ├─ 串行化进入、退出与重复请求抑制
  ├─ 从 media_kit 已确认生命周期同步 phase
  ├─ fullscreen 前关闭窗口 route 的冲突浮层
  └─ 退出后协调 frameless 恢复与持久化保护

GlassVideoControls
  ├─ ControlsOverlay 的视觉与输入层
  ├─ ControlBar / ProgressBar / VolumeControls / OSD / ErrorBanner
  ├─ AutoHideController、字幕 padding、鼠标策略
  └─ 仅向 FullscreenCoordinator 发送全屏意图
```

## 状态机

```text
windowed -> entering -> fullscreen -> exiting -> windowed
```

- `requestToggle()` 仅在 `windowed` 或 `fullscreen` 稳定态执行；过渡态忽略重复请求。
- `requestExit()` 在 `fullscreen` 或 `entering` 时请求明确退出，不用 toggle 表达退出语义。
- media_kit 的默认 enter/exit native callback 必须被保留；项目协调器通过可追加的包装或受支持的观察机制，在完成后更新 phase。
- `WindowService` 仅管理 windowed/maximized/minimized、geometry、frameless、resize；不再作为内部视频全屏事实来源。

## 跨 route 浮层策略

首轮进入全屏前关闭 `PlaylistPanel`。`SettingsOverlayShell` 打开时，明确拒绝进入或先采用产品定义的关闭策略；内部全屏 controls 不显示会在原 route 打开的入口。后续如需支持，需要 `PlayerOverlayHost` 在两个 route 分别创建 UI，并共享 controller state 而非共享 Widget 实例。

## 迁移切片

1. 独立验证 `setAsFrameless()` 白边修复及 resize 回归。
2. 新增协调器、替换 UI 双写路径、更新 F/ESC 回归测试。
3. 将普通窗口 controls factory 下沉到 `Video.controls`，先验证 media_kit 内置 controls 宿主与 native 回调。
4. 将当前 `ControlsOverlay` 重构为 `GlassVideoControls`，迁移成熟行为而非复制第三方 Material 样式。
5. 删除旧 `_fullscreenIntent`、外层 controls 与历史注释；补 Windows 手测矩阵。

## 关键风险

- 自定义 `Video.onEnterFullscreen` / `onExitFullscreen` 会替换默认 native callback，必须避免丢失 Windows 原生全屏。
- media_kit 原生退出会重新添加窗口样式，退出后要恢复 frameless。
- fullscreen 期间关闭窗口不能把显示器 bounds 持久化成普通窗口 geometry。
- F/ESC 不得同时由外部 `KeyboardHandler` 和 fullscreen controls 处理。
