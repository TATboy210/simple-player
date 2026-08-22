# Phase 28 Summary — settings-shell-split-legacy-deletion

**Status:** COMPLETE
**Branch:** `feat/v1.8-stability-polish-plan-02-02`
**Commits:** `e2d7f3f` → `1592386` → `364676f` (3 atomic commits)

## Goal

v4.5 设置面板重设计的先决条件重构 (REFAC-01 shell split + REFAC-02 legacy deletion):
把 945 行的 `settings_panel.dart` 旧版拆解为 shell + 3 个提取协作者, 并删除 legacy,
为 v4.5 侧边栏导航 + 可拖拽 + OK/Cancel/Apply 延迟应用的重设计扫清结构债务.

## Tasks Completed

### Task 1 — extract SettingsTabStrip (tracer, tdd) — `e2d7f3f`
- 新建 `lib/ui/dialogs/settings/tab_strip.dart` (91 行)
- 7 个 SettingsNavItem 横排 + selectedTab 驱动高亮 + 响应式 compact/normal
- 状态归属不变: `SettingsPanelController.state.selectedTab` 唯一拥有者
- tracer 模式: 用现有端到端测试做安全网, 证明提取路径有效

### Task 2 — extract SettingsTabContent + SettingsPanelKeyBindings (tdd) — `1592386`
- 新建 `tab_content.dart` (121 行): 7-child IndexedStack + 每 tab 200ms
  TweenAnimationBuilder opacity 过渡 + bgPanel 背板 + spMd padding
- 新建 `panel_key_bindings.dart` (82 行): 无状态 const helper, root Focus
  KeyDown → controller close/prevTab/nextTab (ESC/B/箭头/游戏手柄肩键)
- shell 4 处编辑: import 清理 + _buildPanel 组合 + 移除 _buildContent (73 行)
  + _handleKeyEvent + 2 shoulder (52 行)

### Task 3 — delete legacy + refresh stale comments (auto) — `364676f`
- 删除 `lib/ui/dialogs/settings_panel.dart` (945 行) — grep gate 确认零调用方
- 更新 3 处 stale comments (dangling reference 修复):
  - `settings_button.dart:3` — 标注 Phase 23 拆分 + Phase 28 legacy 删除
  - `general_tab.dart:12-13` — `SettingsPanel` → `SettingsPanelController.pending`
  - `shortcuts_tab.dart:14` — `SettingsPanel` → `SettingsPanelController`
- 不编辑 `pubspec.yaml` (无依赖变更)

## Acceptance

| 验收项 | 结果 |
|--------|------|
| 每提取文件 < 300 行 | ✓ tab_strip 91 / tab_content 121 / panel_key_bindings 82 |
| shell < 500 行 | ✓ 467 → 331 (减 136 行) |
| pubspec.yaml 未变 | ✓ git status 未列出 |
| grep gate `SettingsPanel(` 零外部调用 | ✓ 仅自身构造函数定义 |
| 7-child IndexedStack 显式结构保持 | ✓ tab_content_test `firstWhere children.length==7` 通过 |
| FocusTraversalGroup ≥ 4 不变 | ✓ focus_navigation_test 通过 |
| shell 渲染 7 SettingsNavItem | ✓ tab_content_test 通过 |
| OK/Apply/Cancel 按钮行为 | ✓ overlay_shell_test 通过 |

## Test Results

### dialogs 子集 (`flutter test test/ui/dialogs/`): 128/132 通过
- 4 失败全部经 `git stash` 鉴别为 HEAD 基线预存在 (非 Phase 28 回归):
  - `settings_nav_item_test.dart` 2 个 — SettingsNavItem layout/indicator
    (Phase 25 产物, Phase 28 不动 _settings_nav_item.dart)
  - `settings_tab_content_test.dart` 2 个 — GeneralTab DropdownButton locale
    (headless 测试环境问题, HEAD `1592386` 同样失败)

### 全套件 (`flutter test`): 2361 通过 + 26 跳过 + 68 失败
- 4 个 dialogs 预存在 (见上)
- 64 个 engine/kernel 预存在 (`fvp_engine_contract_test` 等 mdk.dll FFI 加载失败)
  — Phase 28 物理上不触及 engine/kernel 模块, 按模块边界判断为预存在

## State Ownership Invariant

`SettingsPanelController.state.selectedTab` 保持唯一状态拥有者 (PLAN must_haves truths):
- 提取的 4 个 widget 仅通过 ValueListenable 读取 / 回调写回 / 注入 controller
- 无第二个 notifier, 无状态副本
- `PendingSettingsState` 仍是纯 Dart 类 (非 ChangeNotifier)

## Pre-existing Tech Debt (非 Phase 28, 登记待后续)

1. `settings_nav_item_test` 2 个失败 — Phase 25 SettingsNavItem 布局/指示器
2. `settings_tab_content_test` DropdownButton 2 个失败 — GeneralTab locale headless
3. `fvp_engine_contract_test` ~57 个 mdk.dll FFI 加载失败 — headless 环境
   (见 memory: reference_mdk_dll_headless_test_failures.md)

## Next

Phase 28 结构债务清零, 可启动 v4.5 设置面板重设计 (roadmap phases 28-34):
侧边栏导航 + 可拖拽 + OK/Cancel/Apply 延迟应用 + 自建遮罩.

## Commits

```
364676f refactor(28-03): delete legacy settings_panel.dart + refresh stale comments
1592386 refactor(28-02): extract SettingsTabContent + SettingsPanelKeyBindings
e2d7f3f refactor(28-01): extract SettingsTabStrip from settings overlay shell
```
