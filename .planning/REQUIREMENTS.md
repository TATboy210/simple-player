# Requirements: v1.9 控制栏进度条修复与精简

**Defined:** 2026-08-22
**Core Value:** 加载视频后进度条正常显示、可交互、悬停有时间预览，同时降低进度条/Tooltip 相关代码的监听与 rebuild 占用。

## PROG — 进度条三症状修复

- [ ] **PROG-01**：加载视频后进度条正常显示，反映真实播放进度（duration/position 数据链修复）。
- [ ] **PROG-02**：进度条可交互——点击/拖拽 seek 正常，拖拽期间 thumb 跟手且不回跳。
- [ ] **PROG-03**：鼠标悬停进度条时时间预览气泡正常显示并跟随指针。

## REFACTOR — 局部重构减占用

- [ ] **REFACTOR-01**：梳理 `PlayerControlsState → ControlBarViewModel → ProgressBar` 数据链，消除冗余监听/无效 rebuild，保持 v1.8 已建立的局部重建边界。
- [ ] **REFACTOR-02**：Tooltip 双轨（AppTooltip 统一提示 + ProgressBar 自绘气泡）职责边界清晰，无重复实现。

## VERIFY — 验证

- [ ] **VERIFY-01**：`flutter analyze` 零 error；相关现有测试通过（headless mdk.dll 既有失败单独鉴别）。
- [ ] **VERIFY-02**：实机验证三症状消失（用户手动 `flutter run -d windows` smoke）。

## Constraints

- **media_kit 不可修改（红线）**：所有修复/重构只允许动项目封装层（`media_kit_player_port.dart`、`PlayerControlsState`、`ProgressBar` 等项目文件）。诊断时必须考虑 media_kit 链路特性（`Video.controls` builder、`VideoState` 生命周期、`player.stream` 事件时序），但绝不修改 media_kit 包本身。

## Out of Scope

| Feature | Reason |
|---|---|
| media_kit/libmpv 包内任何修改 | 底线红线，只动项目封装层 |
| ControlsOverlay 恢复 | 已被 PlayerVideoControls 取代，会造成双控制树和状态竞争 |
| 全屏/标题栏/音量等其他控制栏问题 | 不在本里程碑范围，发现另开 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROG-01 | 39 | Pending |
| PROG-02 | 39 | Pending |
| PROG-03 | 39 | Pending |
| REFACTOR-01 | 40 | Pending |
| REFACTOR-02 | 40 | Pending |
| VERIFY-01 | 41 | Pending |
| VERIFY-02 | 41 | Pending |

---
*Requirements defined: 2026-08-22*
*Last updated: 2026-08-22 after milestone v1.9 definition*
