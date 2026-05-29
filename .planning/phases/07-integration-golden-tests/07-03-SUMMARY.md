---
phase: 07-integration-golden-tests
plan: 03
status: completed
commit: bdff0a5
timestamp: 2026-05-30T01:00:00+08:00
---

# Summary: 窗口优化 — BoxFit.contain + 自定义最大化

## 完成内容

### 1. BoxFit.contain（video_surface.dart）
- `BoxFit.cover` → `BoxFit.contain`
- 视频完整显示，非16:9内容显示黑边
- 背景色：`Tokens.bgBase`（`0xFF0A0A0F`）近黑色

### 2. 自定义 maximize()（window_service.dart）
- 重写 `maximize()` 使用 `rcWork`（工作区）
- 重写 `restore()` 恢复最大化前位置
- 新增 `_savedMaximizeFrame` 字段保存窗口位置
- `DWMWA_TRANSITIONS_FORCEDISABLED` 包裹操作消除白边闪现

## 关键决策

| 决策 | 理由 |
|------|------|
| `BoxFit.contain` | 用户要求完整显示视频，黑边可接受 |
| 自定义 FFI `maximize()` | 插件 `adjustNCCALCSIZE` 在无边框窗口覆盖任务栏 |
| 使用 `rcWork` | 标准 Windows 最大化：工作区不含任务栏 |
| `DWMWA_TRANSITIONS_FORCEDISABLED` | 消除无边框窗口白边闪现 |

## 验证结果

- [x] 16:9 视频无黑边
- [x] 4:3 视频显示左右黑边
- [x] 最大化不覆盖任务栏
- [x] 恢复回到之前位置
- [x] 全屏仍覆盖任务栏
- [x] 无白边闪现

## 提交

- **Commit:** `bdff0a5`
- **Message:** `fix: custom maximize uses rcWork + video BoxFit.contain`
- **Branch:** `fix/window-startup`
