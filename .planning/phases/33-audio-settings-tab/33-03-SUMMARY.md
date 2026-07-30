# 33-03 Summary — Normalization + Full-Chain + Coverage/Analyze Gates

**Status:** ✅ Code + tests committed; ⏳ runtime gate (Task #6) pending
**Commits:** `c479e820` (Task 1 code+tests), `2c72a0b7` (stale test fix)

## Delivered

### UI — Volume Normalization Switch（AUDIO-04）
- **EqualizerTab** 第三个 `GlassContainer`（"音量标准化"区，`SectionHeader` `Icons.graphic_eq`）：`SettingRow` + `Switch(key: ValueKey('audio-normalization-switch'), activeThumbColor: Tokens.accent)`。
- Switch 仅 `pending.update('normalization', value)` + `setState`——不触达 commit 回调 / engine（AUDIO-06 延迟应用）。
- `_currentNormalization` getter 从 pending 投影，非 bool 回退 false。

### Compositor — dynaudnorm（33-01 已就绪，本波验证）
- `_appendDynaudnorm`：`normalization == true` 追加 `dynaudnorm=f=500:g=15:p=0.95`（链末段，EQ→pan→adelay→dynaudnorm）；false 省略。
- 规范全链测试：摇滚(3) + balance 0.3 + sync 200 + 标准化 → `bass=g=8,treble=g=6,pan=stereo|c0=0.70*c0|c1=1.00*c1,adelay=200|200,dynaudnorm=f=500:g=15:p=0.95`。

### Integration — Apply/OK/Cancel（AUDIO-05/06/07）
- `settings_overlay_shell_test.dart` 扩展 `pumpShell` 注入 `AudioCommitCallback? onAudioCommit` + `_AudioCommitSpy`：
  - Apply：一次提交 + 4 原始值快照（eqPresetIndex=3/balance=0.3/syncMs=200/normalization=true）+ shell 保持打开。
  - OK：一次提交 + 关闭。Cancel：零提交 + 关闭。
- `audio_tab_test.dart`：normalization toggle → pending('normalization')=true（不触达 commit）。
- `settings_tab_content_test.dart`：旧 EQ 骨架断言修复（均衡器预设/摇滚 + Slider=2 descendant）。

### 陈旧测试回归修复（`2c72a0b7`）
- `general_equalizer_tab_test.dart` 2 断言陈旧（33-01 重写 EqualizerTab 后漏更新）：
  - GlassContainer `findsOneWidget`→`findsNWidgets(3)`；SectionHeader 改 `widgetList` + `contains(Icons.equalizer)`。
  - SettingRow `findsOneWidget`→`findsNWidgets(6)`；FocusableSettingRow 同（SettingRow 内部包装 FocusableSettingRow，6 行锁定 40px）。
- **master(291c2187) 基线确认**：该测试 Phase 33 前通过 → 33-01 回归，33-03 Task 1 现补。

## Validation gates

### ✅ Phase 33 聚焦套件 121/121
`flutter test` 5 文件（compositor 28 + store 19 + audio_tab 11 + tab_content + overlay_shell）`--concurrency=1` 全绿。

### ✅ 陈旧测试修复 5/5
`general_equalizer_tab_test.dart` 隔离重跑全绿。

### ✅ coverage/lcov.info 生成
全量 `flutter test --coverage`：`+2488 ~26 -71`，`coverage/lcov.info`（72KB）生成。

### ⏳ coverage/html — 工具链缺口（非代码问题）
- `genhtml`（lcov）未安装于此 Windows 主机（`command not found`）。
- `coverde`（纯 Dart 替代）已 `dart pub global activate coverde` 0.4.0，但运行被 auto-mode 分类器拒绝（外部包需用户显式授权）。
- `coverage/lcov.info`（规范源证据）已生成，可用任意 lcov viewer 渲染；HTML 渲染待用户授权 coverde 或安装 lcov。

### ⚠️ flutter analyze — exit 1（预存在技术债，非 Phase 33）
- 全量 118 issues（72 error + 11 warning + 35 info 级 lint），均在**非 Phase 33 文件**（option_list_navigation_overlay_test / multi_monitor_clamp_test 等）。
- **Phase 33 改动文件零新增 warning/error**：唯一 Phase 33 文件 issue 是 `settings_tab_content_test.dart:17 - unnecessary_import`（spin_control）——`git show 291c2187` 确认该 import 在 master 已存在（L16，33-03 加 equalizer_tab import 移至 L17），**预存在 info**，非 33-03 引入。
- PLAN 禁止"merely to improve report"改无关文件，故 118 预存在 issue 不修。gate 实质达成：Phase 33 不引入新诊断。

## 全量套件失败定性（71 失败，均非 Phase 33 回归）

| 类别 | 文件 | 数 | 性质 |
|---|---|---|---|
| mdk.dll FFI 环境性 | engine/fvp_engine_contract_test | 59 | headless 无 mdk.dll，预存在（memory 记录） |
| engine 依赖 | integration/error_propagation / fvp_engine_open / mixin_capability | 6 | mdk.dll |
| 运行时门 | audio_filter_runtime_smoke_test | 1 | **预期**——需 Windows 真机 mdk.dll（Task #6） |
| 预存在 UI | nav_item / spin_control_integration / controls_overlay / about_tab | 5 | **master(291c2187) 基线确认**同失败，Phase 33 未触碰其代码 |
| Phase 33 回归 | general_equalizer_tab_test | 2 | **已修**（`2c72a0b7`） |

Phase 33 五文件（compositor/store/audio_tab/tab_content/overlay_shell）**全部缺席失败清单**。

## Decisions honored
- **AUDIO-06 延迟应用**：Switch/slider 只写 pending，Apply/OK 才经单个 `AudioCommitCallback` 提交（widget + controller + shell 集成测试三重保证）。
- **不可用滤镜零部分遗漏**：`AudioFilterAvailability` probe 不可用→组合器省略该段；运行时门要求 pan/adelay/dynaudnorm **全部**生效才完成（不允许部分遗漏）。
- **scope 边界**：第二个 `tabs/audio_tab.dart` + 非音频 tab 未改动；7-child IndexedStack 契约保持。
- **无引擎接口变更**：复用 33-01 `setEqualizer(String)` seam。

## Next — 运行时门（Task #6，phase 完成的前置）
用户在 target Windows 真机跑 `audio_filter_runtime_smoke_test.dart` + **人工听觉**确认：
- pan（全左/全右 mute 单声道）
- adelay（500ms 音频延后）
- dynaudnorm（音量标准化）

`_guardedAction` 吞 Exception → probe 不权威，**听觉是权威门**。3 滤镜都须生效；任何不可用须找等效受支持路径（不允许部分遗漏）。
