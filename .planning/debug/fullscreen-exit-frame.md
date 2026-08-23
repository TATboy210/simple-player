---
status: investigating
trigger: "全屏退出瞬间一帧画面出错(用户报告, 判断与 widget tree 相关)。C1/C2 已修缝隙与图标卡死; 本文件为退出单帧异常的取证方案与候选修复, 待实机证据。"
created: 2026-08-23
updated: 2026-08-23
---

## Current Focus

hypothesis: 退出全屏时, 窗口原生恢复(SetWindowPos 从显示器尺寸回到原几何)与窗口态 Video/controls 子树的首次重建(恢复 resize 触发 isResizing → filterQuality 翻转)在同一窗口交叠 → 异常帧。候选异常帧类型: (a) native 纹理重建(textureId 变化, mpv 输出随窗口 style 变化重建 — media_kit 原生行为, 红线不改); (b) 1px 纹理 guard 切换(Video 内 rect<=1 时显示 fill 容器=黑帧); (c) 纯合成缩放(rect-only, 重排中一帧)。
test: flutter run -d windows (debug), 复现退出单帧异常, 抓取 console 中 video_texture_resize_probe 日志(sessionKind=fullscreen-exit 会话)。
expecting: fullscreen-exit 会话的 classification 字段直接定位异常帧来源(texture-id-changed → 假设a; rect-only-changed → 假设c)。
next_action: 实机取证后按下方"候选修复"选最小修复, 独立 commit。
bug_class: Bohrbug
candidate_causes: code: 窗口恢复与 Flutter 重建时序交叠; native: mpv 输出随窗口 style 变化重建纹理; config/environment: N/A

## Symptoms

expected: 退出全屏瞬间画面连续, 无黑帧/花屏/错位。
actual: 退出全屏同时有一帧画面出错(用户观察, 具体形态待实机确认: 黑帧/花屏/拉伸错位)。
reproduction: 播放视频 → 进入全屏(小窗或最大化) → 退出全屏(按钮/F/ESC 任意) → 观察退出瞬间第一帧。

## Eliminated

- (2026-08-23) 窗口态 Video 被卸载/重挂: route 是覆盖式(窗口态 Video 全程挂载), 退出仅拆除 route 子树 — 静态代码确认。
- (2026-08-23) 图标/chrome 陈旧导致的误判: C2 已统一 mode 单一数据源, 与画面帧无关。

## Evidence

- timestamp: 2026-08-23
  checked: media_kit_video 2.0.1 video_texture.dart:420-450
  found: Video 渲染链 Texture(textureId: id) 前有 rect.width/height <= 1.0 的 guard — 首帧前 1px 纹理显示 fill 色容器; 若退出时 controller.rect 瞬时回落到 1x1, 窗口态 Video 会显示一帧 fill(黑)。
  implication: 假设(b) 的具体机制; 探针 fullscreen-exit 会话的 rectTrail 可直接验证(出现 1x1 即坐实)。
- timestamp: 2026-08-23
  checked: windows/utils.cc::ExitNativeFullscreen + player_screen.dart filterQuality 分支
  found: 退出 = 原生 SetWindowPos 恢复几何(WM_SIZE → isResizing 脉冲); 窗口态 Video 的 filterQuality 随 isResizing 翻转(none↔low)触发 Video 重建 → controls builder 重调 → PlayerVideoControls didUpdateWidget。
  implication: 重建与窗口尺寸剧变交叠的窗口已确认存在; 是否产生可见异常帧取决于 native 侧(textureId 是否变化)。

## Resolution

root_cause: (待实机证据)
fix: (待选, 见下方候选)
verification: 实机连续 5 次进出全屏, 退出瞬间无异常帧 + console 无断言。

### 取证方法

1. `flutter run -d windows`(debug, 探针默认启用; Release 不输出)。
2. 播放视频 → 小窗进入全屏 → 停留 2s(等 settle) → 退出全屏。
3. 抓取 console 中 `video_texture_resize_probe` 日志, 关注 `sessionKind: fullscreen-exit` 会话:
   - `classification: texture-id-changed` → 假设(a): native 纹理重建(media_kit/mpv 行为, 红线不改) → 只能 UI 侧收敛(候选3)。
   - `classification: rect-only-changed` + rectTrail 含 1x1 → 假设(b): guard 切黑帧 → 候选2。
   - `classification: rect-only-changed` 无 1x1 → 假设(c): 纯合成重排 → 候选1。
4. 同时记录: 异常帧形态(黑/花/错位)、出现时机(退出后第几帧)、三种退出方式(按钮/F/ESC)是否一致。
5. 把日志与观察追加到本文件 Evidence 区。

### 候选修复(按证据选择, 各自独立 commit)

1. 过渡期 gate filterQuality 翻转: `_isFullscreenTransition` 期间保持 low, 避免恢复 resize 中途窗口态 Video 重建(C2 后该标记由 mode 可靠置位)。改动点: player_screen.dart filterQuality 分支。
2. 若 rect 瞬时 1x1: 属 media_kit 原生纹理初始化语义(红线不改 media_kit); UI 侧评估: 退出过渡期窗口态 Video 之上保留 route 最后一帧不可行(route 已拆) → 记录为平台行为, 评估是否可接受/仅日志标注。
3. 若 texture-id-changed: 同上, media_kit/mpv native 行为; 评估 UI 侧收敛窗口(过渡标记延长至 settle 完成, 抑制期间 controls 动画, 降低视觉冲击), 不改 media_kit。

## Files

- lib/kernel/diagnostics/video_texture_resize_probe.dart — mode 维度(sessionKind/modeAtStart/modeAtEnd)已加
- lib/ui/player/player_screen.dart — 探针已接 windowMode
- windows/utils.cc (media_kit_video, 只读参考) — ExitNativeFullscreen 恢复时序
