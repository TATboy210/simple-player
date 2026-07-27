# 30-03 SUMMARY — Structural Color Route (Wave 2b)

**Plan:** 30-03 (LAYOUT-05, depends 30-01) — 结构色路由 panelSectionBg
**Wave:** 2 of 3 (b)
**Status:** COMPLETE — 42/42 shell tests + 18/18 content tests pass, analyze 30-03 文件零错误

## What landed

### Production (4 files)
- `lib/ui/theme/tokens.dart`:
  - 新增 `static const Color panelSectionBg = bgGlass;` 别名（D-02 / LAYOUT-05）
  - 放在"响应式设置面板"token section 末尾（tabBarSpacingCompact 后），紧跟 D-04 几何 token 组
  - Phase 30 保留 bgGlass 值；Phase 31 chrome 对齐时单点改此别名即可，不动四消费者
- `lib/ui/dialogs/settings/settings_overlay_shell.dart`:
  - `_buildTitleBar` Container `color: Tokens.bgGlass` → `Tokens.panelSectionBg`
  - `_buildButtonBar` Container `color: Tokens.bgGlass` → `Tokens.panelSectionBg`
  - 保留 RepaintBoundary（D-06）、几何、drag、focus、opacity、glass-tier 行为不变
- `lib/ui/dialogs/settings/tab_strip.dart`:
  - 根 Container `color: Tokens.bgGlass` → `Tokens.panelSectionBg`
  - 保留七 tab 顺序、compact/normal 切换、ValueListenable 所有权
- `lib/ui/dialogs/settings/tab_content.dart`:
  - 根 `ColoredBox(color: Tokens.bgPanel)` → `Tokens.panelSectionBg`（**消除 distinct panel-background route**）
  - doc comment（L3 + L29-30）同步更新 bgPanel → panelSectionBg，标注 D-02 结构色路由
  - 保留显式七子 IndexedStack、TweenAnimationBuilder opacity wrapper、spMd padding

### Tests (1 file, +1 test → 42 total in shell suite)
- `test/ui/dialogs/settings_overlay_shell_test.dart`:
  - 新 import：`tokens.dart` + `tab_strip.dart` + `tab_content.dart`
  - 新 group `settings overlay structural color route (30-03)`:
    1. **四段背景都解析到 Tokens.panelSectionBg**：open shell 后断言
       - 标题栏 Container（titleBarKey descendant first）
       - 按钮栏 Container（buttonBarKey 唯一定位）
       - tab 条 Container（SettingsTabStrip descendant first）
       - 内容区 ColoredBox（SettingsTabContent descendant first）
       - 全部 `== Tokens.panelSectionBg`（color-route 非 ARGB 字面值，Phase 31 改 alias 时测试零改动）

## Verification
- `flutter test test/ui/dialogs/settings_overlay_shell_test.dart`: **42/42 pass** ✅
  （35 旧 + 5  30-02 + 1  30-03；30-02 exception 测试的 debugPrint stderr 噪音为预期，非失败）
- `flutter test test/ui/dialogs/settings_tab_content_test.dart`: **18/18 pass** ✅
  （保护显式 IndexedStack 结构 + tab 行为未回归）
- `flutter analyze` 30-03 改动 5 文件: **No issues found!** ✅

## Phase 边界（D-02）
- 仅 panelSectionBg = bgGlass 别名 + 四段背景消费者路由统一
- **未动** controlBar chrome / edge-glow / density / 三态样式（归 Phase 31）
- **未动** 几何（D-04）、drag clamp（D-03/D-05）、RepaintBoundary（D-06）、tab 顺序（D-01）
- **未引入** 新 package、未动 WindowService 状态、未动 kernel

## Self-Check: PASSED
- D-02 panelSectionBg = bgGlass 别名（Phase 30 仅此别名）✅
- D-02 四段背景统一路由（标题栏/tab 条/内容区/按钮栏）✅
- D-02 tab_content distinct bgPanel route 已消除 ✅
- D-06 RepaintBoundary 保留 ✅
- 七子 IndexedStack / defaultTabIndex=3 / compact-mode 保留 ✅
- color-route 测试断言（非 ARGB 字面值，Phase 31 单点改 alias 友好）✅
- Fakes over mocks（复用 FakePlaybackController，不碰 mdk.dll）✅
