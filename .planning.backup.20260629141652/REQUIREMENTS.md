# v1.8 — Bug Fixes & Control Bar Polish

## R1: 控制栏按钮不可点击 [P0]

**问题:** 打开软件后鼠标无法与控制栏按钮交互，感觉被什么东西挡住了。

**根因:** `controls_overlay.dart:191` 有 `enableBlur: false` 临时标记，BackdropFilter/ClipRRect 可能干扰 hit test。Widget 层级 Listener→IgnorePointer→MouseRegion→FadeTransition→ControlBar 需排查。

**验收:** 打开软件后所有控制栏按钮可点击。

## R2: 毛玻璃效果增强 10% [P1]

**问题:** 控制栏毛玻璃效果不够明显。

**当前值:** `controlBarBg=0x990E111E` (60% 不透明), `glassBlurThick=24.0` sigma

**修复:** alpha 从 0x99→0xB3 (70%), 或 blur sigma 24→28

## R3: 窗口自由缩放 [P1]

**问题:** 播放视频后窗口只能按视频比例缩放，无法自由拖拽边缘调整大小。

**根因:** `player_screen.dart:83` 调用 `windowService.setAspectRatio(ratio)` 锁定 OS 级宽高比。

**修复:** 移除 setAspectRatio 调用。VideoSurface 已用 FittedBox(contain)，画面不裁切。

## R4: 控制栏自动隐藏行为 [P1]

**期望:**
- 空闲状态 → 控制栏常驻
- 播放中静置 → 5s 缓退隐藏
- 鼠标移入控制栏 → 缓进显示
- 鼠标停留控制栏 5s → 缓退隐藏
- 播放中点击视频画面 → 缓退隐藏

**修复:** AutoHideController — onMouseEnter 加 scheduleHide(), hide() 移除 !_hovering 检查。

## R5: 控制栏功能完整性 [P2]

**待确认:** 用户未明确哪些功能有问题，需先完成 R1-R4 后逐一排查。
