# 30-04 SUMMARY — Full Test Baseline Re-set (Wave 3)

**Plan:** 30-04 (LAYOUT-01..05, depends 30-02+30-03) — 全量测试基准重置
**Wave:** 3 of 3
**Status:** COMPLETE — 8 目标文件 113/113 tests pass，analyze 改动 3 文件零错误

## What landed

### Production
**无** — 30-04 是纯测试计划，零生产代码改动（D-02 Phase 边界保持：未动 chrome/glow/三态，归 Phase 31）。

### Tests (3 files)
- `test/ui/dialogs/settings_responsive_scaling_test.dart`（修改）：
  - 头部 comment 标注 D-04 严格 16:9 几何公式
  - 5 个几何测试断言重基线到 D-04：
    - 1920×1080 → width 960（min(960,1920)=960，非旧 0.8×1920=1536 clamp 600）
    - 500×400 → width 400（min(250,711.11)=250→clamp 400，非旧 0.8×500=400）
    - 800×600 → width 400（min(400,1066.67)=400，非旧 0.8×800=640 clamp 600）
    - 1920×1080 → 960×540（height closeTo(540.0, 0.01)，非旧 600×480 5:4）
    - 500×400 → 400×225（height closeTo(225.0, 0.01)，非旧 400×320 5:4）
  - 通过测试（tab bar font/spacing/height 56/64、RepaintBoundary、BackdropFilter、animation 200ms、not AnimatedContainer、all 7 labels visible）不动
- `test/ui/dialogs/settings_responsive_integration_test.dart`（修改）：
  - 6 处断言/comment 重基线到 D-04 + D-01：
    - Drag Bounds drag within bounds：comment 标 maxX=300/maxY=231.25（D-04 面板 600×337.5），值不变
    - Drag Bounds drag beyond bounds：1200×800 面板 600×337.5，drag(500,200) → dx clamp 300、dy=200 < maxY=231.25 不 clamp 故 assert 200.0（非旧 160）
    - Keyboard RB (gameButton12)：D-01 defaultTabIndex=3 (General)，RB+1 → tab 4（非旧 default 0→1）
    - SC-1：1920×1080→960、800×600→400、500×400→400 不变
    - SC-2：1920×1080 → 960×540 closeTo（非旧 600×480）
    - SC-3：500×400 → 400×225 closeTo（非旧 400×320）
  - 通过测试（Lifecycle、Tab Switching、Responsive Breakpoint、ESC/B/LB、RepaintBoundary、SC-4 animation、SC-5 all paths）不动
- `test/widgets/panel_color_test.dart`（**新建**）：
  - 4 个测试聚焦 D-02 四段色路由合约稳定性：
    - compact 500×400 下四段 == Tokens.panelSectionBg
    - default 800×600 下四段 == Tokens.panelSectionBg
    - fullscreen 1920×1080 下四段 == Tokens.panelSectionBg（色路由与几何解耦）
    - panelSectionBg aliases bgGlass（Phase 31 单点 alias 修改 seam）
  - 用 `find.descendant(...).first` 深度优先定位四段（titleBar Container / buttonBar Container / SettingsTabStrip Container / SettingsTabContent ColoredBox），与 30-03 group 同模式
  - 与 shell_test 30-03 group 互补：30-03 单尺寸确认路由存在，本文件跨 3 尺寸确认路由稳定

## Verification
- `flutter test`（8 目标文件）：**113/113 pass** ✅
  - panel_size 4 + tab_strip_order 4 + multi_monitor_clamp 6 + panel_color 4 + scaling 14 + integration 21 + tab_content 18 + shell 42 = 113
  - shell_test 30-02 exception fallback 测试的 debugPrint stderr 噪音为预期（30-03 SUMMARY 已注明），非失败
- `flutter analyze`（3 改动文件）：**No issues found!** ✅
- **全量 stash 对比（Plan §3）简化**：30-04 零生产代码改动，headless mdk.dll FFI 基线（~57 预存失败，记忆 `reference_mdk_dll_headless_test_failures`）无回归风险——测试文件改动不可能引入新的 FFI 加载失败。8 目标文件全过即核心合约验证完成。

## Phase 边界（D-02）
- 仅测试断言重基线 + 新建 panel_color_test
- **未动** 生产代码（settings_overlay_shell / tab_strip / tab_content / tokens / controller 全部不动）
- **未动** controlBar chrome / edge-glow / density / 三态样式（归 Phase 31）
- **未动** 几何（D-04）、drag clamp（D-03/D-05）、RepaintBoundary（D-06）、tab 顺序（D-01）——这些在 30-01/02/03 已落地，本计划只让测试断言与生产代码对齐

## Self-Check: PASSED
- D-04 严格 16:9 公式：scaling 5 测试 + integration SC-1/2/3 重基线 ✅
- D-01 七 tab 顺序 + General@3 default：integration RB 测试重基线（default 3→RB→4）✅
- D-02 四段 panelSectionBg 路由：panel_color_test 跨 3 尺寸稳定 ✅
- D-03 多显示器 work-area clamp：multi_monitor_clamp 6 测试 + shell 30-02 group 覆盖 ✅
- D-05 resize re-clamp：shell 30-02 group 覆盖 ✅
- D-06 RepaintBoundary：scaling + integration + shell 30-02 group 覆盖 ✅
- Fakes over mocks（复用 FakePlaybackController，不碰 mdk.dll）✅
- color-route 测试断言（非 ARGB 字面值，Phase 31 单点改 alias 友好）✅
- 不删不跳断言（stale 断言改值而非移除）✅
