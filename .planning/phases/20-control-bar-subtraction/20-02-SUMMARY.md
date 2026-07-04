---
status: complete
plan: 20-02-PLAN.md
verified: true
---

# 20-02 Summary: External Subtitle Test Race Condition Fix

## Result

**SC2 达标:** 905 tests passed, 0 failures (从 899/6 → 905/0)

## Changes

### Test fix (6 tests)
**File:** `test/kernel/services/external_subtitle_test.dart`
- 在 6 个正向检测测试的 `playIndex(0)` 后添加 `await Future<void>.delayed(200ms)`
- 等待 `unawaited()` 的 `detectAndLoad` 异步文件系统 I/O 完成后再断言

### Production bug fix (1 bug)
**File:** `lib/features/player/services/subtitle_service.dart`
- `detectAndLoad()` 异步版本缺少 `return`——找到第一个匹配后继续扫描
- 添加 `return` 与 `detectAndLoadSync()` 行为一致（只加载第一个匹配字幕）

## Verification

```
flutter test test/kernel/services/external_subtitle_test.dart → 9 passed
flutter test → 905 passed, 0 failed
```
