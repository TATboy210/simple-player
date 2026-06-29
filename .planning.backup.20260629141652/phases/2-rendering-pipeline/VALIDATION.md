# Phase 2: 渲染管线优化 — Validation Architecture

**Created:** 2026-06-26
**Phase:** 2 — 渲染管线优化

## Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

## Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R2-1 | PositionPoller 静默模式 500ms | unit | `flutter test test/kernel/engine/position_poller_test.dart` | 需创建 |
| R2-2 | Snapshot Debounce 与 resize 无耦合 | unit | `flutter test test/kernel/persistence/` | 已验证（跳过） |
| R2-3 | Texture 零拷贝路径 | manual-only | 代码审查 + DevTools Timeline | 已验证（跳过） |
| R2-4 | resize 期间 UI 更新暂停 | widget | `flutter test test/widget/player/progress_bar_test.dart test/widget/player/osd_overlay_test.dart` | 需创建 |

## Sampling Rate

- **Per task commit:** `flutter test` (affected test files)
- **Per wave merge:** `flutter test --coverage`
- **Phase gate:** Full suite green + manual CPU measurement before `/gsd-verify-work`

## Wave 0 Gaps

- [ ] `test/kernel/engine/position_poller_test.dart` — 覆盖 R2-1 静默模式 + seeking Timer 重置
- [ ] `test/widget/player/progress_bar_test.dart` — 覆盖 R2-4 resize 期间跳过 rebuild
- [ ] `test/widget/player/osd_overlay_test.dart` — 覆盖 R2-4 resize 期间跳过 rebuild

## Phase Gate Validation

| Gate | Criteria | Method | Blocking? |
|------|----------|--------|-----------|
| CPU Measurement | resize 期间 CPU 下降 >30% | DevTools CPU Profiler | YES |
| Progress Bar | resize 结束后位置正确（无跳变） | 手动验证 | YES |
| OSD Response | resize 期间按音量键，resize 结束后显示 | 手动验证 | YES |
| Full Test | `flutter test` 全部通过 | 自动化 | YES |

## Manual Validation Steps

1. **CPU Baseline (优化前)**
   - 打开 4K 视频播放
   - DevTools CPU Profiler 开始记录
   - 持续拖拽窗口边缘 10 秒
   - 记录 resize 期间平均 CPU 占用

2. **CPU Measurement (优化后)**
   - 重复上述步骤
   - 确认 CPU 下降 >30%

3. **Progress Bar Continuity**
   - 4K 视频播放中
   - 拖拽窗口边缘 5 秒
   - 松手后观察进度条位置
   - 预期: 进度条平滑更新，无跳变

4. **OSD Response**
   - 4K 视频播放中
   - 拖拽窗口边缘
   - resize 期间按音量键
   - 松手后观察 OSD
   - 预期: resize 结束后 OSD 显示音量变化

## Automated Test Commands

```bash
# 单元测试 (R2-1)
flutter test test/kernel/engine/position_poller_test.dart

# Widget 测试 (R2-4)
flutter test test/widget/player/progress_bar_test.dart test/widget/player/osd_overlay_test.dart

# 全量回归
flutter test

# 覆盖率
flutter test --coverage
```
