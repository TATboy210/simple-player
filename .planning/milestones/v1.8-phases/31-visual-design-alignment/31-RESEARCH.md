# Phase 31: Visual Design Alignment - Research

**Researched:** 2026-07-27
**Domain:** Flutter desktop UI — 面板 chrome 对齐控制栏 (glass decoration extraction + option-row three-state + density)
**Confidence:** HIGH (全部代码缝 live-verified; Flutter 行为经 Context7 官方文档 + 代码库既有 live 证据双重确认)

## Summary

Phase 31 的 WHAT 已由 31-CONTEXT.md (D-01..D-12) + 31-UI-SPEC.md (6 维契约) 完全锁定。本研究不重开任何设计决策，只验证 7 个实现层面的 Flutter 行为假设并给出 HOW。核心结论：(1) D-06 依赖的 "BoxDecoration border 不占布局" 在代码库中已有 live 证据（`FocusableSettingRow` 常驻 2px 边框仅切色），1px focused 边框零行位移成立；(2) BackdropFilter 不堆叠是结构性事实（grep 证实面板子树仅 glass_container.dart 一处），SC#5 profile-mode 检查可用既有 `PerfMonitor` 执行；(3) InkWell 迁移有两个隐藏坑——面板子树无 Material 祖先（ripple 会不可见）+ InkWell 默认 `canRequestFocus: true` 会造成双焦点停靠点，均已在 GlassButton 中有先例解法；(4) `ControlBarDecoration` 提取的逐字 spec 已从 control_bar.dart L18-79 转录，idle 必须保留 4-shadow padding 以维持 DecorationTween 插值兼容；(5) 每段 chrome 独立应用 4-shadow 会产生段间阴影接缝——D-04 的 `borderRadius` 参数是合规缓解杠杆；(6) accent #2C58F4 在 controlBarBg 合成背景上对比度 ~3.4:1（未达 AA 4.5），D-07 backstop 推荐改用既有 `Tokens.accentBlue` #4A8EFF (~5.9:1)；(7) D-01..D-12 引用的全部 16 个 token 均在 tokens.dart 存在并核实行号，零阻塞缺口。

**Primary recommendation:** 按 §5 的逐字 spec 提取 `ControlBarDecoration`；`SettingRow` 重构保留 `FocusableSettingRow` 为唯一焦点拥有者、InkWell 设 `canRequestFocus: false` + `Material(type: transparency)` 包裹；chrome 三段用 `borderRadius` 参数做 corner-only 圆角以消除段间阴影接缝；Wave 0 先落 `control_bar_decoration_test.dart` 字段等价单测 + `panel_color_test.dart` re-baseline。

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Carried Forward (pre-locked — DO NOT re-litigate):**
- **CF-01..CF-08 + D-02** (Phase 30 keystone boundary): Phase 30 did placeholder structural color unification only (`panelSectionBg=bgGlass` alias); Phase 31 owns the switch to `controlBarBg`/`controlBarBorderWhite`/`glowOuterRing` + edge-glow + three-state + density.
- **SC#1**: `controlBarBg` / `controlBarBorderWhite` / `glowOuterRing` named exactly (token names pre-locked)
- **SC#2**: 4-shadow decoration source = `ControlBar._decorationPlaying` (Phase 31 extracts this into shared token)
- **SC#3**: Three-state semantics (default borderless / hover / selected) — control bar button three-state is the target state
- **SC#4**: BackdropFilter stacking mitigation (Pitfall 3) — thin glass via `Container(color:)` not second `BackdropFilter`
- **SC#5**: Test assertions re-baseline (visual assertion updates if chrome alignment changes geometry)
- **Design north star**: 面板对齐控制栏毛玻璃语言 (control bar is the visual baseline, panel is the adopter)
- **CF-06**: All visual values via `Tokens.*` (no hardcoded colors/fonts/spacing)

**A. Shared Decoration Token:**
- **D-01:** New file `lib/ui/shared/control_bar_decoration.dart` — bidirectional reuse; single-route.
- **D-02:** Class name `ControlBarDecoration` — directional naming (control bar = baseline, panel = adopter).
- **D-03:** `playing` + `idle` extracted to shared, `tween` stays local in `control_bar.dart`.
- **D-04:** Method `playing({BorderRadius? borderRadius})` — default `controlBarRadius`; panel overrides `radiusLg`.

**B. Option Row Three-State:**
- **D-05:** `selected` = focused row (keyboard/gamepad navigation focus) — unified across all row types, paving Phase 32 NAV-06/07.
- **D-06:** Focused highlight = `controlBarBorderWhite` blue glow border; hover = `bgHover` background; default = transparent fusion.
- **D-07:** Active value representation = accent text color (`Tokens.accent` #2C58F4); a11y risk recorded, plan-phase mitigates.
- **D-08:** Pressed = InkWell built-in highlight + ripple, no custom scale animation; requires `GestureDetector`→`InkWell` refactor.

**C. Density Pixels:**
- **D-09:** Row height = 40px.
- **D-10:** Horizontal padding = `spXs` (4px).

**D. See-Through Thin Glass:**
- **D-11:** Content section keeps `bgGlass`, chrome three sections switch to `controlBarBg` (layered).
- **D-12:** NAV-05 top/bottom covers NOT pre-wired; Phase 31 content = simple `Container(color: bgGlass)`.

### Claude's Discretion

- **panelSectionBg alias fate**: Recommendation — keep `panelSectionBg` alias for content (preserves single-swap-route semantics).
- **Chrome decoration method**: `ControlBarDecoration.playing` (4-shadow) for chrome three sections — panel chrome恒用 playing 装饰 (visual alignment, not state alignment).
- **D-07 a11y mitigation**: If accent #2C58F4 insufficient contrast, plan-phase may deepen accent or apply SemiBold weight.

### Deferred Ideas (OUT OF SCOPE)

- **NAV-05 top/bottom thin glass covers** — Phase 32 (D-12)
- **NAV-06 keyboard arrow glow feedback** — Phase 32
- **NAV-07 single Focus root capture** — Phase 32
- **D-07 a11y mitigation (deeper accent or SemiBold)** — plan-phase decision after contrast audit
- **panelSectionBg alias final form (alias vs direct bgGlass)** — plan-phase implementation detail
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VISUAL-01 | 面板 chrome 对齐控制栏 — `bgGlass` → `controlBarBg` + `controlBarBorderWhite` + `glowOuterRing` (4-shadow from `ControlBar._decorationPlaying`) | §5 逐字 spec 转录 + §1 段间阴影接缝缓解 (borderRadius 杠杆) |
| VISUAL-02 | 选项行默认无边框无白光融合，仅选中态高亮 (三态 default/hover/selected) | §3 InkWell 迁移双坑 + §4 焦点接线 + §1 border 零位移证据 |
| VISUAL-03 | 选项边界更紧凑 (与控制栏按钮密度对齐) | §7 token 核实 (spXs=4) + 无既有 height-42 断言需 re-baseline (Wave 0 新增) |
| VISUAL-04 | 薄毛玻璃"透看选项"用 `Tokens.bgGlass` 色 (非第二层 BackdropFilter) | §2 grep 结构证明 + 自动化 BackdropFilter 计数闸门 |
| VISUAL-05 | 提取 `ControlBarDecoration` 共享 token，颜色统一单路由 | §5 API 形状验证 + 等价性单测方案 |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 共享装饰定义 (`ControlBarDecoration`) | `lib/ui/shared/` (generic layer) | — | D-01/D-02: shared generic layer depends on neither consumer (control_bar / settings shell) |
| Chrome 装饰消费 (3 sections) | `settings_overlay_shell.dart` + `tab_strip.dart` (panel widgets) | — | 装饰应用是 widget 层职责；无 kernel 参与 |
| 选项行三态 + density | `lib/ui/shared/settings_card.dart` + `focusable_setting_row.dart` | — | 行级交互状态 (hover/focus/press) 纯 widget 本地状态 |
| 性能验证 (BackdropFilter 不堆叠) | `lib/kernel/utils/perf_monitor.dart` (既有) | Flutter DevTools | 帧计时采样本就是 kernel diagnostics 职责，Phase 31 零改动复用 |
| Token 单一事实源 | `lib/ui/theme/tokens.dart` | — | CF-06: 无新 token 值，仅路由变更 |

## Implementation Approach

### 1. BoxDecoration border 布局行为 (D-06 依赖) — VERIFIED

**结论：focused 1px 边框零行位移成立。** Flutter 的 `Container` 尺寸由 constraints/child 决定，decoration 永不影响外部几何；border 由 `BoxPainter` 绘制在给定 rect 内侧，仅向内 inset 子内容（border.width 从内部扣除），不改变 widget 自身尺寸。Context7 `/websites/api_flutter_dev` 确认 `Decoration`/`BoxBorder` 是纯绘制抽象（`paintBorder(Canvas, Rect, ...)`），不参与布局协议。 [VERIFIED: Context7 /websites/api_flutter_dev + codebase live evidence]

**代码库 live 证据（最强）**：`focusable_setting_row.dart` L94-104 的 Container **常驻** 2px border（未聚焦时 `Colors.transparent`，聚焦时 `Tokens.borderHighlight`），仅切换 color——这是 Phase 25 D-11/D-13 已上线且测试覆盖 (`test/ui/shared/focusable_setting_row_test.dart`) 的零位移 pattern。Phase 31 把 width 2→1、color `borderHighlight`→`controlBarBorderWhite` 是同一 pattern 的参数变更，几何行为不变。

**注意事项 (caveats)**：
- 行高固定 40px 时，1px border 从内部扣除 → 内容区 38px 垂直空间。14px body 文本无影响，但 `Switch` 等 control 高度须不溢出（既有 control 均 ≤36px，安全）。
- border 切换**不要**用 `AnimatedContainer`（Phase 25 D-13 先例：焦点边框即时切换无动画），避免插值中间态的亚像素抖动。
- `Border.all(width: 1)` 在 1.0 devicePixelRatio 下可渲染；Windows 桌面普遍 1.25-2.0 DPR，1px 逻辑边框清晰。

### 2. BackdropFilter 堆叠 + 性能测量 (SC#4/SC#5) — VERIFIED (结构) / 手动 (性能)

**结构证明（grep-verified）**：`BackdropFilter` 在 `lib/ui/` 全库仅 3 个宿主——`glass_container.dart` L158/167（面板唯一 blur）、`control_bar.dart` L215、`playlist_panel.dart` L118。设置面板子树内**有且仅有一个** BackdropFilter（`GlassContainer` 持有）。`Container(color: bgGlass)`（content）与 `Container(decoration: BoxDecoration)`（chrome）都是该唯一 blur 的 paint-only 子节点——BoxDecoration 的 color/border/boxShadow 全部走 GPU paint path，零额外 readback。SC#4 结构性满足。`RepaintBoundary` 在 `settings_overlay_shell.dart` L264 保留。 [VERIFIED: codebase grep]

**手动 profile-mode 检查协议（SC#5，planner 原样落入 task）**：
1. `D:/flutter/bin/flutter run --profile -d windows`（**必须 profile mode**——debug mode JIT/断言开销掩盖真实 raster 成本，数据无效）
2. 启用既有 `PerfMonitor.instance.enable()`（`lib/kernel/utils/perf_monitor.dart` L36-43，经 `SchedulerBinding.addTimingsCallback` **每帧采样**，>16ms 慢帧打 'Slow frame' 日志含 build/raster 分解，每 100 帧输出 avg/max 统计，L68-84）
3. 操作：打开面板 → 标题栏拖拽横跨窗口（多显示器跨屏更佳，触发 LAYOUT-04 clamp 路径）→ General tab 滚动 + EQ slider 拖动
4. **Pass 判据**：拖拽/滚动期间无持续性 raster-主导慢帧（偶发单帧 ≤2 帧可接受）；`exportStats()` 的 `raster.avgMs` 相对改造前基线增幅 ≤1ms。**Fail 判据**：连续慢帧且 `raster` 显著高于 `build`（GPU readback 特征）
5. **A/B 基线**：先在改造前代码上跑一次取 `exportStats()` JSON 基线，改造后对比
6. DevTools 备选：Performance view raster thread 时间轴（等价数据源）

**Nyquist 采样节奏**：PerfMonitor 每帧采样（≥60Hz）≥ 2× 最快有意义变化率（30Hz jank 信号）——满足奈奎斯特准则。`MemoryMonitor`/`EngineMetrics` 本 phase 无需接入（无内存/引擎行为变更）。

**自动化结构闸门（防止未来回归）**：widget 测试断言面板子树 `find.byType(BackdropFilter)` 计数 == 1。任何人将来加第二层 blur 会立即红灯。

### 3. InkWell 迁移 (D-08) — VERIFIED 双坑 + 先例解法

`SettingRow` 现状（`settings_card.dart` L42-117）：`GestureDetector` + `AnimatedContainer`（transparent→bgHover，height 42，padding spSm）+ `Transform.scale(_pressed ? pressScale : 1.0)`。D-08 要求：InkWell 内建 highlight+ripple、**删除自定义 scale**。

**坑 1 — 面板子树无 Material 祖先（ripple 不可见）**：grep 证实 `lib/ui/dialogs/settings/` 与 `settings_card.dart` 内**无任何 `Material(`**。InkWell 的 ink 绘制在最近 Material 祖先上——面板子树内没有，splash 会画到 app 级远处 Material 上、被玻璃面遮蔽，**ripple 完全不可见**。解法（既有先例）：包裹 `Material(type: MaterialType.transparency)`——`GlassButton` (`glass_container.dart` L295-309) 与 `ControlBar` (`control_bar.dart` L124-125) 均用此 pattern。 [VERIFIED: codebase grep + 两处 live 先例]

**坑 2 — InkWell 默认 focusable → 双焦点停靠点**：InkWell `canRequestFocus` 默认 true。`FocusableSettingRow` 的 `FocusableActionDetector` 已是行的焦点拥有者（D-05 selected=focused 的承载者）。若 InkWell 默认可聚焦，Tab 遍历会每行停两次（外层 wrapper + 内层 InkWell）。解法：`InkWell(canRequestFocus: false, autofocus: false)`，焦点统一归 `FocusableSettingRow`——`focusable_setting_row_test.dart` 既有测试零改动保持绿。 [VERIFIED: Flutter InkWell API + codebase 结构]

**Ripple 在毛玻璃上的可见性（planner 决策点）**：GlassButton 先例用 `splashFactory: NoSplash.splashFactory` + `highlightColor: Colors.transparent` + `hoverColor: Tokens.bgHover`——即项目已实践过"深色玻璃上默认灰 ripple 不可见"的判断。D-08 字面要求 "InkWell built-in highlight + ripple"。三个合规选项（均 CF-06 tokens-only）：
- (a) 字面 D-08：默认 splash（深色玻璃上近乎不可见，不推荐）
- (b) `splashColor: Tokens.accentLight`（既有 token，0xB4 alpha accent，深玻璃上可见）+ `highlightColor: Tokens.bgHover` 半透明化 — **推荐**，既满足 D-08 "内建 ripple" 字面又在玻璃上可见
- (c) 与 GlassButton 完全一致 NoSplash + hover only — 最一致但不满足 D-08 的 "ripple" 字面

**Hover 背景去重**：现状 hover 背景有**两处**来源——`FocusableSettingRow` L97（未聚焦时 bgHover）+ `SettingRow` 内部 AnimatedContainer L69（isActive→bgHover）。同色无视觉冲突但属重复。重构时收敛为单一来源：推荐 InkWell `hoverColor: Tokens.bgHover`（borderRadius radiusSm 裁剪），`FocusableSettingRow` 退化为纯焦点边框职责（删其 hover bg 分支），`SettingRow` 删内部 AnimatedContainer + `_pressed` state + `Transform.scale`。

### 4. 焦点遍历统一 (D-05 → Phase 32 NAV-06/07 铺路) — VERIFIED

**既有基础设施（全部 live，Phase 31 零新建）**：
- `settings_overlay_shell.dart` L265-268：`FocusTraversalGroup` + `Focus(autofocus: true, onKeyEvent: keyBindings.handle)`——NAV-07 所需的单一 Focus 根**已存在**，Phase 31 禁止新增竞争性 Focus 根
- `focusable_setting_row.dart`：`FocusableActionDetector` 每行一个焦点节点 + `onFocusChange` 回调（NAV-06 箭头发光所需的状态信号源已存在）+ D-15 disabled `ExcludeFocus + IgnorePointer`
- `panel_key_bindings.dart`：纯索引循环键盘路由（Phase 28 提取，REFAC-01）

**Focus API 面（Phase 31 需要触碰的）**：
| API | 用途 | Phase 31 动作 |
|-----|------|--------------|
| `FocusableActionDetector` | 行级焦点检测 + 视觉反馈 | 保留于 `FocusableSettingRow`，唯一焦点拥有者 |
| `FocusTraversalGroup` (默认 `ReadingOrderTraversalPolicy`) | Column 内行列表纵向遍历开箱可用 | 零改动；7 tab 内容区行列表天然按阅读顺序遍历 |
| `InkWell.canRequestFocus: false` | 防双停靠点 | 新增（§3 坑 2） |
| `FocusableSettingRow.onFocusChange` | D-05 selected=focused 信号 | 既有，接入 accent 文本态 |
| `FocusNode`/`FocusOrder` | 显式排序 | **不使用**——ReadingOrder 已满足；Phase 32 如需再引入 |

**D-07 accent 文本的焦点态接线（推荐实现）**：`SettingRow` 需感知 focused 以切换 active-value 文本色。推荐给 `FocusableSettingRow` 增加向后兼容的可选 `focusedBuilder(BuildContext, bool focused)` 构造（既有 `child` API 与全部测试不变），`SettingRow` 经 builder 拿到 focused 渲染 accent 文本。替代方案（`Focus.of(context)` 轮询）会在焦点变化时漏 rebuild，不推荐。

**Phase 32 铺路不变量（Phase 31 必须保持）**：① 每行恰好一个焦点节点（FocusableSettingRow）；② 焦点变化信号经 `onFocusChange` 单路由；③ shell 根部单一 `Focus(onKeyEvent:)` 捕获不被新增 Focus 根稀释。满足这三条，Phase 32 NAV-06 只需读 onFocusChange 驱动箭头发光、NAV-07 只需扩展既有根 handler——零返工 Phase 31 接线。

### 5. ControlBarDecoration 提取 (D-01..D-04) — VERIFIED 逐字 spec

**从 `control_bar.dart` L18-79 逐字转录**（planner 可直接落入 action）：

```dart
// lib/ui/shared/control_bar_decoration.dart — NEW (D-01/D-02)
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// 控制栏装饰 — 深色毛玻璃 + 蓝色微光边框 (D-02: 控制栏为视觉基准，面板是 adopter)。
/// 双向复用: control_bar.dart (no-arg, 默认 controlBarRadius) +
/// settings_overlay_shell.dart (chrome 3 sections, borderRadius: radiusLg override)。
/// tween 保留在 control_bar.dart 本地 (D-03)。
class ControlBarDecoration {
  ControlBarDecoration._();

  static final _defaultRadius = BorderRadius.circular(Tokens.controlBarRadius);

  /// playing 装饰 — 4-shadow (源: ControlBar._decorationPlaying, control_bar.dart L21-49)
  static BoxDecoration playing({BorderRadius? borderRadius}) => BoxDecoration(
    color: Tokens.controlBarBg,
    borderRadius: borderRadius ?? _defaultRadius,
    border: Border.all(color: Tokens.controlBarBorderWhite, width: 1),
    boxShadow: const [
      // CSS: inset 0 1px 0 rgba(255,255,255,0.04) — 顶部内高光
      BoxShadow(color: Tokens.controlBarBorderWhite, blurRadius: 0, spreadRadius: 0, offset: Offset(0, -1)),
      // CSS: inset 0 -1px 0 rgba(0,0,0,0.1) — 底部内阴影
      BoxShadow(color: Tokens.controlBarShadowBlack, blurRadius: 0, spreadRadius: 0, offset: Offset(0, 1)),
      // CSS: 0 8px 32px rgba(0,0,0,0.25) — 外层投影
      BoxShadow(color: Tokens.controlBarOuterShadow, blurRadius: 32, offset: Offset(0, 8)),
      // CSS: 0 0 0 1px rgba(80,130,255,0.04) — 蓝色外环
      BoxShadow(color: Tokens.glowOuterRing, blurRadius: 1, spreadRadius: 1),
    ],
  );

  /// idle 装饰 — 2% 淡蓝描边 + 补齐 4 shadow (源: ControlBar._decorationIdle, L52-73)
  /// 4-shadow 列表必须保留 (含 2 个 transparent padding) — DecorationTween
  /// 按 index lerp BoxShadow 列表，数量不齐会插值断裂 (control_bar.dart L69 注释)。
  static BoxDecoration idle({BorderRadius? borderRadius}) => BoxDecoration(
    color: Tokens.controlBarBg,
    borderRadius: borderRadius ?? _defaultRadius,
    border: Border.all(color: Tokens.controlBarBorderIdle, width: 1),
    boxShadow: const [
      BoxShadow(color: Tokens.controlBarBorderIdle, blurRadius: 0, spreadRadius: 0, offset: Offset(0, -1)),
      BoxShadow(color: Tokens.controlBarShadowBlack, blurRadius: 0, spreadRadius: 0, offset: Offset(0, 1)),
      BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0),
      BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0),
    ],
  );
}
```

**API 形状验证结论**：
- `playing({BorderRadius? borderRadius})` / `idle({BorderRadius? borderRadius})` 签名 sound。borderRadius 参数化破坏 const 构造 → 对 no-arg 热路径，调用方 (control_bar) 应缓存 `static final` 实例（保持 control_bar L18/21 既有 static-final 缓存先例 D-01）。override 路径按调用构建（面板 chrome 静态场景，零热路径成本）。
- **idle 4-shadow padding 是硬约束**：control_bar.dart L69-72 注释明确 "补齐 4 个 BoxShadow，让 DecorationTween 插值更平滑"。`DecorationTween` 按 index lerp shadow 列表；提取时若把 idle "简化" 为 2-shadow 会破坏 playing↔idle 动画。提取必须逐字保留。
- **tween 本地化 (D-03) sound**：`control_bar.dart` 改为 `DecorationTween(begin: ControlBarDecoration.idle(), end: ControlBarDecoration.playing())`，面板无 playing/idle 动画无需 tween。
- **不提取的部分**：`EdgeGlow` 包装 (L121-123)、`_buildBlur` 的 `ClipRRect`+`BackdropFilter` (L208-231)、顶部渐变光线 `DecoratedBox` (L137-152)——这些是控制栏专属 chrome 增强，非装饰 spec 本体。面板 chrome 是否加 EdgeGlow 属 UI-SPEC 未列项 → **不加**（YAGNI，D-12 精神）。
- **半径三方不一致 (D-04) 实况**：`controlBarRadius` = 22.0 (tokens.dart L163) 与 `radiusLg` = 22.0 (L121) **数值相等**；`radiusLarge` = 12.0 (L124) 才是 GlassContainer 默认。面板 override `radiusLg` 在几何上与 no-arg 等价——override 的价值是**语义解耦**（面板半径不随控制栏半径漂移），非几何变更。

**⚠ 段间阴影接缝（本 phase 最大视觉风险，见 Pitfalls #1）**：4-shadow 装饰是为**独立悬浮条**设计（阴影落在视频上）。面板 chrome 三段在 Column 内堆叠，每段独立应用完整装饰会让 title bar 的 outer drop shadow (blur 32, offset(0,8)) 投到 tab strip 上、bottom inner shadow 与下一段 top inner highlight 形成可见棱线。**合规缓解**：D-04 的 `borderRadius` 参数是 sanctioned 杠杆——title bar 传 `BorderRadius.vertical(top: Radius.circular(Tokens.radiusLg))`、button bar 传 `vertical(bottom: ...)`、tab strip 传 `BorderRadius.zero`；段间接缝接受为 chrome 分段语义或视觉 check backstop。planner 必须显式决策，不得默认全圆角应用。

### 6. a11y 对比度 (D-07 backstop，记录不阻塞) — VERIFIED (WCAG 公式计算)

**合成背景法**：WCAG 对比度要求实色，对半透明背景须先 alpha 合成。面板 chrome = `controlBarBg` (alpha 0x99=0.6, #0E111E) 合成于 `bgBase` #0C0F18 之上 → 实色 ≈ rgb(13,16,28)，相对亮度 L_bg ≈ 0.0059。

| 候选文本色 | 相对亮度 L | 对比度 (vs L_bg) | WCAG AA 4.5:1 (14px normal) | WCAG 3:1 (大字/UI 组件) |
|-----------|-----------|-----------------|---------------------------|------------------------|
| `Tokens.accent` #2C58F4 (D-07 locked) | 0.140 | **~3.4:1** | ✗ FAIL | ✓ PASS |
| `Tokens.accentBlue` #4A8EFF (既有 token) | 0.280 | **~5.9:1** | ✓ PASS | ✓ PASS |

[VERIFIED: computed — sRGB 线性化 + WCAG 2.x 相对亮度公式，理论值非实测]

**结论与推荐**：
- accent #2C58F4 在 chrome 玻璃上 ~3.4:1——14px normal 文本**不达 AA 4.5**，但达 3:1（focus 指示器等非文本组件标准）。
- **"加深 accent" 是错误方向**——深底上加深只会更糟。正确方向是**调亮**。D-07 允许的 SemiBold 缓解**不改变对比度比值**（纯感知增强）。
- **推荐（backstop，非阻塞）**：若 plan-phase 对比度审计触发，active-value 文本路由到既有 `Tokens.accentBlue` #4A8EFF (~5.9:1 过 AA)——零新 token、CF-06 合规。否则保持 D-07 locked accent。
- focused 边框本身（1px `controlBarBorderWhite` 0x0A alpha≈0.04）对比度极低，但这与控制栏本体一致（设计系统全局先例），记 backstop 不单列。

### 7. Token 清单核实 — VERIFIED (全部存在，零阻塞)

D-01..D-12 引用的 16 个 token 逐一核实于 `lib/ui/theme/tokens.dart`：

| Token | 值 | 行号 | 引用决策 |
|-------|-----|------|---------|
| `controlBarBg` | 0x990E111E | L57 | SC#1, VISUAL-01, D-11 |
| `controlBarBorderWhite` | 0x0A6496FF | L59 | SC#1, D-06 |
| `glowOuterRing` | 0x0A5082FF | L31 | SC#1, VISUAL-01 |
| `controlBarBorderIdle` | 0x056496FF | L61 | idle 装饰 (D-03) |
| `controlBarOuterShadow` | 0x40000000 | L63 | 4-shadow spec |
| `controlBarShadowBlack` | 0x1A000000 | L62 | 4-shadow spec |
| `bgGlass` | 0x8C0C0F18 | L12 | D-11 content, VISUAL-04 |
| `bgHover` | #283045 | L11 | D-06 hover |
| `accent` | #2C58F4 | L14 | D-07 |
| `accentBlue` | #4A8EFF | L16 | D-07 backstop 推荐 (§6) |
| `accentLight` | rgba(44,87,244,0.71) | L15 | InkWell splashColor 候选 (§3) |
| `borderHighlight` | 0x33FFFFFF | L87 | 现状 focus 边框 (被替换) |
| `controlBarRadius` | 22.0 | L163 | D-04 default |
| `radiusLg` | 22.0 | L121 | D-04 panel override |
| `radiusLarge` | 12.0 | L124 | 三方不一致注记 (D-04) |
| `spXs` / `spSm` | 4.0 / 8.0 | L113 / L114 | D-10 / 现状 padding |
| `panelSectionBg` | = bgGlass | L254 | content 单路由 (D-11) |

**缺口：无。** 决策引用的全部 token 存在。无需新增 token 值（§3 splashColor 与 §6 backstop 均复用既有 token）。

## Standard Stack

零新依赖——全部经既有 Flutter SDK (3.44.8 stable, verified) + 项目内 `Tokens.*` + 既有 glass widget 库。

| Component | Source | Purpose |
|-----------|--------|---------|
| `BoxDecoration`/`BoxShadow`/`Border` | Flutter SDK | 装饰 spec 本体 |
| `InkWell` + `Material(type: transparency)` | Flutter SDK | D-08 pressed 反馈（§3 双坑解法） |
| `FocusableActionDetector`/`FocusTraversalGroup` | Flutter SDK | D-05 焦点语义（既有 FocusableSettingRow 承载） |
| `BackdropFilter` (既有 1 处) | `GlassContainer` | SC#4 唯一 blur 层 |
| `PerfMonitor` (既有) | `lib/kernel/utils/perf_monitor.dart` | SC#5 性能采样 |
| `flutter_test` | SDK | widget/单元测试 |

## Package Legitimacy Audit

**Not applicable — 零外部包安装。** Phase 31 是纯视觉 token 路由 + widget 重构，不引入任何新 pub 依赖（31-CONTEXT "New dependencies: 无"）。无 `pubspec.yaml` 变更。

## Validation Architecture

> nyquist_validation = true (.planning/config.json)。Dimension 8 种子。

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter 3.44.8 stable) |
| Config file | none — `flutter test` 零配置 |
| Quick run command | `D:/flutter/bin/flutter test test/widgets/panel_color_test.dart test/ui/shared/focusable_setting_row_test.dart test/ui/shared/control_bar_decoration_test.dart` |
| Full suite command | `D:/flutter/bin/flutter test` |

**既有测试基线（预存在失败，非回归）**：全套件 ~64 个 engine/kernel mdk.dll FFI 失败（headless 环境，见 memory `reference_mdk_dll_headless_test_failures`）+ 4 个 dialogs 预存在（settings_nav_item 2 + settings_tab_content DropdownButton 2）。鉴别法：stash → HEAD 基线对比，或按模块边界判断（Phase 31 只触 `lib/ui/`，engine/kernel 失败物理不可达）。

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VISUAL-01 | chrome 3 段装饰 == ControlBarDecoration.playing spec (color controlBarBg / 1px controlBarBorderWhite / 4-shadow 末位 glowOuterRing) | widget (re-baseline) | `flutter test test/widgets/panel_color_test.dart` | ✅ exists — 须 re-baseline：现断言 4 段 `Container.color == panelSectionBg`（L49-84），chrome 3 段改为断言 `decoration` 字段；content 保持 panelSectionBg 断言 |
| VISUAL-02 | 三态渲染：default transparent / hover bgHover / focused 1px controlBarBorderWhite + accent 文本 / pressed InkWell 响应 | widget | `flutter test test/ui/shared/focusable_setting_row_test.dart test/widget/settings/` | ⚠ partial — focusable_setting_row_test 存在但断言 2px borderHighlight，须 re-baseline 1px controlBarBorderWhite；三态 + accent 文本断言 Wave 0 新增 |
| VISUAL-03 | SettingRow height 40 + padding spXs=4 | widget | `flutter test test/ui/shared/settings_card_test.dart` (Wave 0 新建) | ❌ Wave 0 — grep 证实无既有 height-42 断言，新断言净增 |
| VISUAL-04 | 面板子树 BackdropFilter 计数 == 1 + content `Container(color: panelSectionBg)` | widget | `flutter test test/widgets/panel_color_test.dart` (扩展) | ⚠ partial — 计数闸门 Wave 0 新增至 panel_color_test 或 shell test |
| VISUAL-05 | `ControlBarDecoration.playing()` 字段等价原 `_decorationPlaying`；no-arg 默认 controlBarRadius；override 生效；idle 4-shadow | unit | `flutter test test/ui/shared/control_bar_decoration_test.dart` | ❌ Wave 0 新建 |

### 附加可测属性（研究区 1-7 派生）

| Property | Test Type | Method |
|----------|-----------|--------|
| BoxDecoration-no-layout-shift (§1) | widget | pump SettingRow → `focusNode.requestFocus()` → pump → 断言 render box height 前后相等 (40.0)；既有 focusable_setting_row_test 同 pattern 可复用 |
| BackdropFilter-no-stacking perf (§2) | manual profile | §2 六步协议：profile mode + PerfMonitor 每帧采样 + 拖拽/滚动 + A/B exportStats 基线对比 |
| focus-traversal-reachability (§4) | widget | shell 内 `FocusTraversalGroup` + 模拟 Tab/方向键 → 断言每个交互 SettingRow + GlassButton 依次获得 focus highlight；断言 InkWell 不产生额外停靠点（每行恰好 1 次） |
| decoration-extraction-API-stability (§5) | unit | `ControlBarDecoration.playing()` 逐字段比对转录 spec（color/border/boxShadow.length==4/boxShadow[3].color==glowOuterRing/borderRadius==circular(22)）；`playing(borderRadius: r)` override 生效；`idle().boxShadow.length == 4` (tween 兼容硬约束) |
| density-geometry (§7) | widget | SettingRow render box height == 40.0；**Phase 30 几何断言零改动**（panel_size_test 16:9 公式不受本 phase 影响，grep 证实断言只涉 panel 尺寸） |
| contrast-a11y (§6) | backstop | §6 理论计算已落档 (~3.4:1 vs 4.5 AA)；若触发缓解，单测断言 active-value 文本色 token == accentBlue |

### Sampling Rate
- **Per task commit:** quick run command（上述 3-4 个受影响测试文件，<30s）
- **Per wave merge:** `D:/flutter/bin/flutter test` 全套件（按模块边界鉴别预存在失败）
- **Phase gate:** 全套件绿（相对基线零新增失败）+ §2 手动 profile 检查通过，方入 `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/ui/shared/control_bar_decoration_test.dart` — VISUAL-05 字段等价 + API 稳定性（新建）
- [ ] `test/ui/shared/settings_card_test.dart` — VISUAL-02 三态 + VISUAL-03 density 断言（新建或并入既有 settings 测试目录）
- [ ] `test/widgets/panel_color_test.dart` — re-baseline：chrome 3 段 decoration 断言 + BackdropFilter 计数闸门（修改既有）
- [ ] `test/ui/shared/focusable_setting_row_test.dart` — re-baseline：1px controlBarBorderWhite 边框断言（修改既有）
- [ ] 手动 profile 基线：改造前跑 `flutter run --profile` + PerfMonitor `exportStats()` 存基线 JSON

## Pitfalls & Risks

### Pitfall 1: chrome 段间阴影接缝 (最高视觉风险)
**What goes wrong:** 4-shadow 装饰为独立悬浮条设计；三段 chrome 在 Column 堆叠各自带 blur-32 外阴影 → title bar 阴影投到 tab strip、段间出现内阴影+内高光棱线，面板不像"一条控制栏"而像"三条叠放的条"。
**Why it happens:** 逐字应用 `ControlBarDecoration.playing` 到每个 section Container，未考虑装饰的悬浮语境假设。
**How to avoid:** 用 D-04 `borderRadius` 参数做 corner-only 圆角（title bar `vertical(top:)`、button bar `vertical(bottom:)`、tab strip `BorderRadius.zero`）；planner 显式决策段间阴影保留与否；视觉 check 列为 backstop。
**Warning signs:** 面板打开后段间有暗带/亮线；截图对比控制栏底部边缘。

### Pitfall 2: InkWell 无 Material 祖先 → ripple 不可见
**What goes wrong:** D-08 迁移后 pressed 态毫无视觉反馈（ink 画到面板外远处 Material 上被玻璃遮蔽）。
**Why it happens:** 面板子树无 Material（grep 证实）；InkWell ink 依赖最近 Material 祖先。
**How to avoid:** `Material(type: MaterialType.transparency)` 包裹 InkWell（GlassButton L295 / ControlBar L124 双先例）。
**Warning signs:** 按下选项行无涟漪无 highlight；widget 测试找不到 InkWell 的 ink 渲染。

### Pitfall 3: InkWell 双焦点停靠点
**What goes wrong:** Tab 遍历每行停两次（FocusableSettingRow + InkWell 各自可聚焦），D-05 selected=focused 语义错乱，Phase 32 NAV 铺路被破坏。
**Why it happens:** InkWell `canRequestFocus` 默认 true。
**How to avoid:** `InkWell(canRequestFocus: false)`，焦点单一归 FocusableSettingRow；widget 测试断言每行恰好一个焦点停靠点。
**Warning signs:** 键盘 Tab 需按两倍次数才能遍历完行列表。

### Pitfall 4: idle 装饰 shadow 数量"简化" → tween 插值断裂
**What goes wrong:** 提取时把 idle 的 4-shadow（含 2 个 transparent padding）"优化"为 2-shadow → 控制栏 playing↔idle DecorationTween 按 index lerp 失败/跳变。
**Why it happens:** control_bar.dart L69-72 的 padding shadow 意图不直观，易被当作冗余。
**How to avoid:** 逐字保留 4-shadow；单测断言 `idle().boxShadow.length == 4`。
**Warning signs:** 控制栏 idle→playing 过渡阴影闪变。

### Pitfall 5: panel_color_test re-baseline 漏改 → 误报红
**What goes wrong:** 既有测试断言 4 段 `Container.color == panelSectionBg`；chrome 改 decoration 后 `color` getter 为 null → 3 处断言失败被误判为回归。
**Why it happens:** Phase 30-04 的 color-route 合约测试是 Phase 31 的直接冲击面。
**How to avoid:** Wave 0 先行 re-baseline（chrome 3 段改 decoration 字段断言，content 保持 panelSectionBg 断言）；TDD 顺序：先改测试（红）→ 再改实现（绿）。
**Warning signs:** panel_color_test 在 chrome 切换后立即红。

### Pitfall 6: hover 背景双来源残留
**What goes wrong:** FocusableSettingRow hover bg + SettingRow 内部 AnimatedContainer hover bg + InkWell hoverColor 三处并存，态切换时序不一致出现闪烁。
**How to avoid:** 收敛单一来源（推荐 InkWell hoverColor），删 FocusableSettingRow hover 分支与 SettingRow AnimatedContainer（§3）。

### Pitfall 7: focus 文本 accent 用 `Focus.of(context)` 轮询 → 漏 rebuild
**How to avoid:** 经 `FocusableSettingRow` 的 focusedBuilder/onFocusChange 显式传递（§4）；`Focus.of` 在焦点变化时不保证子树重建。

## Dependencies

既有代码缝（全部 live-verified，行号以当前工作树为准）：

| 文件 | 关键行号 | Phase 31 动作 |
|------|---------|--------------|
| `lib/ui/player/control_bar.dart` | L18 `_borderRadius`；L21-49 `_decorationPlaying` (4-shadow 源)；L52-73 `_decorationIdle`；L76-79 `_decorationTween`；L116-119 tween 消费；L124 Material 先例；L121-123 EdgeGlow (不提取) | playing+idle 提取至共享 (D-01/D-03)；tween 改从共享构造，留本地 |
| `lib/ui/shared/control_bar_decoration.dart` | NEW | D-01 家；§5 逐字 spec |
| `lib/ui/shared/glass_container.dart` | L158/167 唯一 BackdropFilter；L111-135 blur skip 逻辑 (D-13/14 + resize)；L181-383 GlassButton (InkWell + Material + NoSplash 先例, L295-309) | 零改动（SC#4 锚点）；GlassButton 三态 selected bg 属 D-05 target-state，planner 决定是否本 phase 触及 |
| `lib/ui/shared/settings_card.dart` | L42-117 SettingRow (GestureDetector L55, AnimatedContainer L64-71, height 42 L66, padding spSm L67, Transform.scale L72-73) | 三态重构 + height 40 + padding spXs + InkWell (D-05..D-10) |
| `lib/ui/shared/focusable_setting_row.dart` | L79-107 FocusableActionDetector + 2px borderHighlight border (L99-102) + hover bg (L97) | border → 1px controlBarBorderWhite (D-06)；hover bg 收敛 (Pitfall 6)；可选 focusedBuilder API (§4) |
| `lib/ui/dialogs/settings/settings_overlay_shell.dart` | L264 RepaintBoundary；L265-268 FocusTraversalGroup + Focus 根；L269-272 GlassContainer(radiusLg)；L304-341 button bar (`color: panelSectionBg` L311)；L347-379 title bar (`color: panelSectionBg` L356) | chrome 2 段 → `ControlBarDecoration.playing(borderRadius:)`；content 不动 |
| `lib/ui/dialogs/settings/tab_strip.dart` | L71-73 Container (`color: panelSectionBg` L73) | chrome 第 3 段 → ControlBarDecoration |
| `lib/ui/dialogs/settings/tab_content.dart` | L52 content `color: panelSectionBg` | **保持** panelSectionBg 别名 (D-11 content) |
| `lib/ui/theme/tokens.dart` | §7 表格 16 token 行号 | 零改动（无新 token 值） |
| `test/widgets/panel_color_test.dart` | L49-84 四段 color 断言；L131-135 alias 契约 | Wave 0 re-baseline (Pitfall 5) |
| `test/ui/shared/focusable_setting_row_test.dart` | D-11/12/13/15 覆盖 | Wave 0 re-baseline 1px 边框 |
| `lib/kernel/utils/perf_monitor.dart` | L36-43 enable；L55-84 慢帧+统计；L143-180 exportStats | 零改动；SC#5 手动检查工具 |
| `lib/ui/dialogs/settings/panel_key_bindings.dart` | Phase 28 提取 | 零改动（NAV-07 根已存在） |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | 全部构建/测试 | ✓ | 3.44.8 stable (verified `flutter --version`) | — |
| Flutter binary path | 测试/运行命令 | ✓ | `D:/flutter/bin/flutter`（**不在 PATH**，用全路径 per STATE.md 先例） | — |
| Windows desktop target | profile-mode 性能检查 | ✓ | Windows 11 (win32) | — |
| DevTools | 性能备选 | ✓ | 随 SDK | PerfMonitor 日志已足够 |
| 新 pub 依赖 | — | 不需要 | — | — |

**Missing dependencies:** 无。

## Security Domain

纯 UI 视觉 phase——零新输入面、零 I/O、零 FFI、零密钥。无 ASVS 类别新增适用项。

| ASVS Category | Applies | Note |
|---------------|---------|------|
| V5 Input Validation | no | 无新用户输入面（设置行控件均为既有） |
| V6 Cryptography | no | — |
| V7 Error Handling/Logging | partial | 沿用项目约定：错误 `debugPrint` + graceful fallback，零敏感信息 |

威胁面评估：装饰提取与 token 路由不产生注入/XSS/路径遍历面；`GestureDetector→InkWell` 不扩大手势攻击面。无需 `<threat_model>` 深度分析。

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | InkWell splashColor 用既有 `Tokens.accentLight` 可满足 D-08 "ripple" 字面且玻璃上可见 | §3 | LOW — planner 可选 NoSplash 对齐 GlassButton；三选项均已列出，非阻塞 |
| A2 | chrome 段间阴影接缝用 corner-only borderRadius 缓解是 D-04 参数精神内的合规路径 | §5/Pitfall 1 | LOW — 最坏情况是全圆角应用后视觉 check 返工一段 decoration 调用，无结构风险 |
| A3 | `FocusableSettingRow` 增 `focusedBuilder` 可选 API 是 D-07 accent 文本接线的最小侵入路径 | §4 | LOW — 替代方案（onFocusChange 回调上抛）等价，仅风格差异 |
| A4 | §6 对比度比值为 sRGB/WCAG 公式理论计算（非 on-device 实测）；实际观感受背板视频内容影响 | §6 | LOW — D-07 本就是 backstop 非阻塞；推荐方向（调亮非加深）在理论框架内稳健 |
| A5 | GlassButton 是否本 phase 加 selected 背景（D-05 "target state"）由 planner 定界 | Dependencies 表 | LOW — CONTEXT 未把 GlassButton 修改列入成功标准；仅 SettingRow 三态是硬要求 |

## Open Questions

1. **Chrome 段间阴影的最终形态（Pitfall 1）**
   - What we know: 4-shadow 为悬浮条设计；borderRadius 参数是合规杠杆
   - What's unclear: 段间接缝在真机上的视觉接受度（"chrome 分段" vs "一条整体"）
   - Recommendation: planner 在 PLAN 中显式指定 corner-only radii 方案 + 视觉 check backstop；若 verify 阶段不可接受，单点调整 decoration 调用

2. **InkWell ripple 三选项（§3）**
   - Recommendation: (b) `splashColor: Tokens.accentLight` + 半透明 highlight；在 PLAN 中锁定，不留 executor 自由发挥

3. **GlassButton selected 背景是否本 phase 落地（A5）**
   - Recommendation: 保守——本 phase 只交付 SettingRow 三态（成功标准 SC#2/SC#3 的检验对象），GlassButton selected bg 与 Phase 32 NAV-06 箭头发光同批落地更顺

## Sources

### Primary (HIGH confidence)
- Codebase live reads (verified this session): `control_bar.dart` L18-262 / `glass_container.dart` full / `settings_card.dart` full / `focusable_setting_row.dart` full / `settings_overlay_shell.dart` full / `tab_strip.dart` full / `tokens.dart` full / `perf_monitor.dart` full / `panel_color_test.dart` L1-135 / `panel_size_test.dart` L1-131
- Codebase grep sweeps: `BackdropFilter` (lib/ 全库 3 宿主) / `panelSectionBg` (5 消费点) / `Material(` 面板子树零命中 / 无 height-42 断言
- Context7 `/websites/api_flutter_dev` — Decoration/BoxBorder/paintBorder API 文档（border 纯绘制、不参与布局协议）

### Secondary (MEDIUM confidence)
- WCAG 2.x 相对亮度公式 + sRGB 线性化 — 理论对比度计算 (§6)，公式本身标准，数值为手算
- Flutter `Container`/`InkWell` 行为（decoration 不影响尺寸 / canRequestFocus 默认 true / ink 需 Material 祖先）— 官方文档语义 + 代码库既有先例 (GlassButton/ControlBar/FocusableSettingRow) 交叉印证

### Tertiary (LOW confidence)
- 无 — 本 phase 无依赖训练数据外推的关键声明

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 零新依赖，全既有组件
- Architecture (extraction/refactor seams): HIGH — 逐字 spec 转录 + 双先例验证 (Material 包裹 / NoSplash)
- Pitfalls: HIGH — 7 个坑全部有代码行号锚点或 grep 证据
- 性能测量协议: MEDIUM-HIGH — PerfMonitor 能力 live-verified；pass/fail 阈值 (±1ms) 为工程判断，planner 可微调

**Research date:** 2026-07-27
**Valid until:** 2026-08-26 (30 天 — 稳定域：Flutter stable SDK + 项目内 token，无快变外部依赖)
