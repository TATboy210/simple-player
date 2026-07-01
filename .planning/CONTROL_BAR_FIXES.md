# Control Bar Bug Fixes

**Created:** 2026-07-01
**Scope:** 4 个控制栏组件的 bug 修复
**Priority:** P0 → P1 → P2

---

## 积木 4: VolumeControls — 静音/取消静音状态矛盾 (P0)

**文件:** `lib/ui/player/volume_controls.dart`
**问题:** 静音后手动拖滑块到 0，再取消静音 → UI 显示有音量但实际没声音
**根因:** `savedVolume` 只在点静音时记录一次，后续滑块变化不更新

**修复方案:**
- `_toggleMute()` 中：取消静音时检查 `engine.volume.value`，如果 savedVolume == 0 则恢复到 0.5
- `VolumeSlider.onChanged` 中：如果新值 > 0，同步更新父组件的 `savedVolume`

**验收标准:**
- [ ] 静音 → 拖滑块到 0 → 取消静音 → 音量恢复到合理值
- [ ] 静音 → 取消静音 → 音量恢复到之前的值
- [ ] 滑块拖到 0 → 自动触发静音图标

---

## 积木 7: AutoHideController — dispose 泄漏 (P1)

**文件:** `lib/ui/player/auto_hide_controller.dart`
**问题:** `_onAnimStatus` 监听器在 dispose 时未移除；DateTime.now() 做节流有开销

**修复方案:**
- `dispose()` 中加 `_animController.removeStatusListener(_onAnimStatus)`
- 节流改用 `Stopwatch` 或简单 bool + Timer

**验收标准:**
- [ ] dispose 后无 listener 泄漏警告
- [ ] 自动隐藏功能正常（鼠标静止后按时隐藏）

---

## 积木 5: SpeedButton — 非标倍速值跳档 (P2)

**文件:** `lib/ui/player/speed_button.dart`
**问题:** 引擎返回非标值（如 1.10）时，`lastIndexWhere` 找到 1.0，按右箭头跳到 1.25

**修复方案:**
- `_shift()` 中：如果当前值不在 `_gears` 列表里，先 snap 到最近档位再切换
- 或者：允许显示当前值，左右箭头从当前值出发找最近档位

**验收标准:**
- [ ] 非标值（如 1.10）按左箭头 → 到 1.0
- [ ] 非标值按右箭头 → 到 1.25
- [ ] 标准档位切换行为不变

---

## 积木 3: ProgressBar — 小优化 (P2)

**文件:** `lib/ui/player/progress_bar.dart`
**问题:** `Listenable.merge` 5 个源，hover tooltip 无法缓存

**修复方案:**
- 当前实现已用 RepaintBoundary + resizing 缓存，性能可接受
- 仅在 resize 信号期间跳过 rebuild，已有实现
- **暂不改动**，标记为观察项

**验收标准:**
- [ ] 进度条拖拽流畅
- [ ] hover tooltip 正常显示
- [ ] resize 期间无卡顿
