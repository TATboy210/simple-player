# 技术说明：MaterialDesktopVideoControls 的可迁移行为

## 事实依据

锁定依赖为 `media_kit_video 1.3.1`。默认 `Video.controls` 为 `AdaptiveVideoControls`，桌面平台使用 `MaterialDesktopVideoControls`。内部 fullscreen 会从原 `Video` 保存 controls builder，再在 root Navigator 的新 route 中重建 `Video` 并复用该 builder。

## 应学习的行为

- 通过 Focus 与 CallbackShortcuts 集中处理媒体快捷键。
- 在 mouse enter/hover 时显示 controls，并在超时后隐藏。
- 以 400ms 判定双击 fullscreen。
- seek、volume 操作期间保持 controls 可见。
- controls 显示时为字幕施加底部 padding，隐藏时恢复。
- fullscreen route pop 时通过 `FullscreenInheritedWidget` 调用 native exit callback。
- 按钮根据 route 内实际 fullscreen 上下文显示 enter/exit 图标。

## 不应复制的内容

- 不复制第三方私有源码或修改 pub cache。
- 不采用其 Material 色彩、尺寸和渐变；项目必须使用 `Tokens.*` 与玻璃设计体系。
- 不把其默认 F/ESC 与项目 KeyboardHandler 并存。

## 迁移方式

项目应将这些行为重新实现在自己的 `GlassVideoControls` 中，或者通过 media_kit 的公开 controls/theme 插槽组合已有部件。选择之前需先完成 API 兼容性 spike；任何方案都必须保证 controls builder 同时适用于普通 Video 与内部 fullscreen Video。
