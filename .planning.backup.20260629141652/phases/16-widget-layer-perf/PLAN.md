# Phase 16: Widget 层优化 — 执行计划

**目标**: 消除不必要 rebuild/saveLayer，窗口调整 120fps
**依赖**: 无
**需求**: R3-1, R3-3, R3-4, R3-5（R3-2 已完成）
**风险**: 低（纯 Dart UI 层修改）

## 成功标准

1. PlayerScreen 顶层 Stack 用 RepaintBoundary 隔离视频/控制栏/播放列表
2. progress_bar.dart 的 Opacity → AnimatedOpacity
3. PlayerScreen 嵌套 VLB 扁平化
4. edge_glow.dart / control_bar.dart 硬编码颜色 → Tokens.*
5. 窗口调整 120fps（DevTools Timeline 验证）

## R3-2 已完成（跳过）

AuroraBackground `_syncTicker()` 已在非 idle 状态暂停 Ticker，无需修改。

---

## Task 1: PlayerScreen RepaintBoundary 隔离

**文件**: `lib/ui/player/player_screen.dart`
**改动**: 在 Stack 的 videoContent 和 PlaylistPanel 外层分别包裹 RepaintBoundary
**影响**: resize 时视频层不触发控制栏重绘，反之亦然

## Task 2: Progress Bar Opacity 修复

**文件**: `lib/ui/player/progress_bar.dart:313`
**改动**: `Opacity(` → `AnimatedOpacity(duration: Duration.zero, opacity:` 或直接用 `Visibility`
**影响**: 避免 saveLayer 开销

## Task 3: ValueListenableBuilder 扁平化

**文件**: `lib/ui/player/player_screen.dart`
**现状**: 4 层嵌套 VLB（textureId → playlistVisible → playlistMounted → Stack）
**改动**: 合并 playlistVisible + playlistMounted 为单一 VLB，减少嵌套层级
**影响**: 减少 build 链深度

## Task 4: 硬编码颜色迁移

**高优先级文件**（>5 处违规）：

| 文件 | 违规数 | 策略 |
|------|--------|------|
| `edge_glow.dart` | 15+ | 新增 `Tokens.glowStops` 颜色组 |
| `control_bar.dart` | 10 | 新增 `Tokens.controlBar*` 常量 |
| `app.dart` | 7 | 用 `Tokens.accentBlue` / `Tokens.textSecondary` 替换 |
| `aurora_background.dart` | 5 | 新增 `Tokens.auroraBlobColors` |

**低优先级文件**（1-2 处）：
- `thumbnail_tile.dart:297` → `Tokens.bgGlass`
- `osd_overlay.dart:135` → `Tokens.borderHighlight`
- `settings_panel.dart:66` → `ThemeService.accents`
- `general_tab.dart:131-133` → `ThemeService.accents`
- `transmitted_light.dart:81` → 新增 `Tokens.glowPurple`

## Task 5: 测试验证

- [ ] 现有测试全部通过
- [ ] 新增 RepaintBoundary 隔离的 widget 测试
- [ ] DevTools Timeline 窗口调整 120fps 验证

---

## 执行顺序

1 → 2 → 3 → 4 → 5（线性，每步验证后再下一步）
