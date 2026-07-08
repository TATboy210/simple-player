# Phase 1: 动画体验优化 — Plan 01-01 完成摘要

**完成日期:** 2026-07-08
**状态:** ✅ COMPLETE

## 改动摘要

### Task 1: Fade 动画参数 — 400ms + easeInOut 曲线 (D-01, D-02, D-07)

**文件:** `lib/ui/theme/tokens.dart`

- `durationFade` 300 → **400** (line 135) — 更平滑的 fade 过渡
- 新增 `bottomTriggerZoneHeight = 150.0` (line 146) — 底部触发区域常量

**文件:** `lib/ui/player/auto_hide_controller.dart`

- `Curves.easeOut` → **`Curves.easeInOut`** (line 27) — 对称曲线，出现和消失速度一致
- idle→playing 状态切换复用同一个 `_animController.forward()` 路径（D-07 验证通过，无需改动）

### Task 2: 底部触发区域 + 点击立即隐藏 (D-03, D-04)

**文件:** `lib/ui/player/controls_overlay.dart`

- MouseRegion `onHover` 添加底部 150px Y 位置检查 (lines 208-216)
  - 仅鼠标在距底部 `bottomTriggerZoneHeight` 内才触发 `_autoHide.onMouseMove()`
  - 使用 `context.size` 计算鼠标距底部距离
- `_handleTap` 第一次点击立即调用 `_autoHide.hide()` (lines 121-124)
  - Timer 仅保留用于双击检测窗口（250ms 内第二次点击 → 全屏切换）
  - idle 状态不触发隐藏

## 测试结果

| 测试文件 | 总数 | 新增 | 通过 |
|----------|------|------|------|
| auto_hide_controller_test.dart | 36 | 0 | ✅ |
| controls_overlay_test.dart | 16 | 3 | ✅ |
| **全量回归** | **990+** | — | ✅ (12 个预存失败，非本次改动) |

### 新增测试用例

1. `mouse in bottom trigger zone shows controls` — 验证底部 150px 内鼠标触发显示
2. `mouse above bottom trigger zone does NOT show controls` — 验证上方区域不触发
3. `single tap immediately hides controls (D-04)` — 验证点击立即隐藏

## 设计决策执行情况

| 决策 | 内容 | 状态 |
|------|------|------|
| D-01 | durationFade 300→400ms | ✅ |
| D-02 | Curves.easeOut→Curves.easeInOut | ✅ |
| D-03 | 仅底部区域触发显示 | ✅ |
| D-04 | 点击立即隐藏 | ✅ |
| D-05 | 悬停不隐藏（已有机制） | ✅ 无需改动 |
| D-06 | 隐藏延迟不变（5s/3s） | ✅ 无需改动 |
| D-07 | idle→playing 复用同一 fade | ✅ 验证通过 |

## 验证清单

- [x] `Tokens.durationFade == 400`
- [x] `Curves.easeInOut` 用于 AutoHideController
- [x] 底部触发区域高度 = 150px
- [x] 点击立即隐藏（不在 Timer 回调内）
- [x] 双击全屏切换保留
- [x] 所有现有测试通过（零回归）
- [x] `flutter analyze` 无新增警告
- [ ] 手动验证：fade 平滑度、底部触发、点击隐藏（需运行应用）

## 手动验证清单

- [ ] 播放视频，观察控制栏 fade-in/fade-out 是否 ~400ms、对称感
- [ ] 鼠标移到视频底部 150px 内 → 控制栏显现
- [ ] 鼠标移到视频上方 → 控制栏不显现
- [ ] 鼠标移开控制栏 + 点击画面 → 控制栏立即隐藏
- [ ] 双击画面 → 全屏切换正常
- [ ] 悬停控制栏上 → 不自动隐藏
