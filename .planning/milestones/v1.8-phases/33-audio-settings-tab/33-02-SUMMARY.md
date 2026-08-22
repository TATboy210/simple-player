# 33-02 Summary — Balance + Audio-Sync Deferred Sliders

**Status:** ✅ Complete (code + headless tests committed)
**Commit:** `77dcaff`

## Delivered

### UI — deferred balance + audio-sync sliders
- **EqualizerTab** 扩展第二个 `GlassContainer`（"空间与同步"区），承载两个 `_PendingSliderRow`：
  - **平衡** slider `[-1.0..1.0]` → `pending.update('balance', v)`，显示 `-100..100` 百分比（负=偏左，正=偏右）。
  - **音频延迟** slider `[0..10000ms]` → `pending.update('syncMs', v.round())`，显示整毫秒（正值=音频延后——FFmpeg `adelay` 无法提前音频，故 UI 正值统一表示延后）。
- **`_PendingSliderRow`**（私有 widget）：仿 `SettingSliderRow` 布局（42 高 + hover `bgHover` + `Tokens.accent` + label/Slider/数值三段 Row + `tabularFigures`），但绑定 `PendingSettingsState`（非 `ValueNotifier`）——value 由父 `_EqualizerTabState` getter 投影注入，`onChanged` 由父调 `pending.update` + `setState` 重建；hover 态本地持有避免父重建干扰交互反馈。
- 稳定 `ValueKey('audio-balance-slider')` / `ValueKey('audio-sync-slider')` 供 widget 测试定位。

### Compositor — pan/adelay（33-01 已就绪，本波验证）
- `AudioFilterCompositor._appendPan` / `_appendAdelay` 实现于 33-01，本波未改动源码。33-02 plan Test 1-4（pan 全左/全右/居中边界、adelay 0/200/10000/越界 clamp、EQ→pan→adelay 链顺序）已由 33-01 的 `audio_filter_compositor_test.dart` 27 tests 超额覆盖。

## Tests (37 headless, all pass)
- `audio_filter_compositor_test.dart` (27, unchanged from 33-01)：pan/adelay/dynaudnorm 边界 + 链顺序 + 不可用省略 + probe。
- `audio_tab_test.dart` (10, +3 from 33-01)：
  - 5 controller 单测（open/register/commit/cancel/snapshot，unchanged）。
  - 2 EQ widget 测试（unchanged）。
  - **+3 新 slider widget 测试**：balance drag→pending(double>0)、sync drag→pending(int>0, rounded)、两 slider 拖动只 stage pending 不触达 commit 回调。

### Slider 测试断言策略
`tester.drag(slider, Offset(80,0))` 终值随 slider 轨道宽度变化，故用 `greaterThan(0.0)` + `isA<double>()`/`isA<int>()` 类型断言验证"slider→pending"链路 + sync 四舍五入为 int；精确边界值（pan `c0=1.00*c0|c1=0.00*c1`、adelay `10000|10000`）由 compositor 纯 Dart 测试覆盖。widget 测试职责 = 交互链路，单元测试职责 = 精确输出。

## Validation gates
- ✅ `flutter analyze`（2 文件）— No issues found.
- ✅ 2 headless test files — 37/37 pass（compositor 27 + audio_tab 10）。
- ⏳ Runtime gate（Task #6，与 33-03 合并）：用户在 target Windows 跑 smoke + **人工听觉**确认 pan（全左/全右 mute 单声道）、adelay（500ms 延后）各自应用。`_guardedAction` 吞异常→probe 不权威，听觉是权威门；3 滤镜都须生效，不允许部分遗漏。

## Decisions honored
- **AUDIO-06 延迟应用**：slider callback 只调 `pending.update` + `setState`，不触达 commit 回调 / PlayerFeature / engine 对象（widget 测试 + controller 单测双重保证）。
- **syncMs 直传非负值无 abs()**：compositor `_appendAdelay` 直接用 `clamp(0,10000)` 值，不 `abs()`——FFmpeg adelay 无法提前音频，UI 正值统一表示延后。
- **balance 居中省略**：`_appendPan` 在 `balance == 0.0` 时省略 pan 段（恒等值不进 af 链）。
- **第二个 `tabs/audio_tab.dart` + 非音频 tab 未改动**：scope 边界保持（33-03 回归测试将显式断言 7-child IndexedStack + placeholder tabs 完整）。
- **无引擎接口变更**：复用 33-01 的 `setEqualizer(String)` seam。

## Env note
`flutter pub get` 先于 `flutter test`（kernel 编译器需新鲜 `package_config.json`，analyzer 容忍过期——同 33-01）。

## Next
- **33-03**（Task #5）：normalization Switch UI + 全链 widget 集成测试（Apply/OK 一次 + Cancel 零回调 + 4 原始值持久化 round-trip）+ tab-content 回归（7-child IndexedStack + 第二个 AudioTab 保持）+ 覆盖率门 + analyze 零警告门。
- **运行时门**（Task #6）：target Windows smoke + 人工听觉（pan/adelay/dynaudnorm 各自生效）。
