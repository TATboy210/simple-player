# Phase 20: Control Bar Subtraction

## Domain

精简控制栏视觉层和组件结构：去除冗余装饰层、删除未使用变体、合并重复描边来源、减少断点级别。

## Decisions

### 视觉层精简

1. **BoxShadow 激进裁剪** — playing 状态从 11 层减到 ~5 层
   - 删除: outerShadow(15%黑, 32px)、glowOuterRing(3%蓝, 1px)、ambientBlue(2%蓝, 50px)
   - 保留: top白色描边、bottom蓝色辉光、midBlue扩散(20px)、borderBlue描边、highlightWhite

2. **EdgeGlow 只保留 gradient 变体**
   - 删除: `EdgeGlowVariant.omni`、`EdgeGlowVariant.pulse` 及对应 `_OmniGlowPainter`、`_buildOmniGlow`、`_buildPulseGlow`
   - 删除后 EdgeGlow 可简化为无 enum 的单变体组件

3. **渐变带合并到 EdgeGlow** — controls_overlay 的 60px 渐变带（transparent→bg）移入 EdgeGlow
   - EdgeGlow 新增可选 `gradientStripHeight` 参数（默认 0 = 不画渐变带）
   - controls_overlay 删除渐变带 Positioned 子项

4. **idle 装饰去掉 bottom 辉光** — `_decorationIdle` 从 2 层 BoxShadow 减到 1 层
   - 删除: `controlBarShadowBlack` bottom 辉光
   - 保留: `controlBarBorderIdle` top 描边

5. **top 描边合并为单一来源** — 当前有 3 个 top edge 来源
   - 合并: Border.all(白色10%) + EdgeGlow highlightWhite + 1px glowAccent 渐变线
   - 方案: 只保留 Border.all 作为结构描边，EdgeGlow 内部的 top highlight 和 accent 线删除

6. **删除未使用 token** — 减少 ~10 个死代码常量
   - 删除: glowOmniRight/Down/Left/Up(4个)、glowGradientStart/Mid/End(3个)、glowPurple
   - 保留: glowCore、glowMid、glowEdge、glowEdgeStrong（仍在使用）

### 组件结构精简

7. **断点 3 级→2 级** — 删除 ultraCompact(≤360px)
   - 删除: `breakpointUltraCompact` token、`_CompactCenterGroup` 内部类
   - 保留: compact(≤500px) 和 normal 两级
   - compact 时复用 CenterGroup（已有）

8. **_ProgressRow 保留** — 透明边框容器可能是 hover 高亮预留，不动

9. **内部类保持独立** — _LeftButtonGroup、CenterGroup、_RightButtonGroup 职责清晰

10. **controls_overlay 渐变带删除后足够精简** — 剩 OSD + ControlBar + ErrorBanner

## Canonical Refs

- `lib/ui/player/control_bar.dart` — 主控制栏，474 行，4 个内部类
- `lib/ui/player/controls_overlay.dart` — 自动隐藏容器，268 行，含渐变带
- `lib/ui/player/center_controls.dart` — PlayPauseButton + CenterGroup，118 行
- `lib/ui/shared/edge_glow.dart` — EdgeGlow 3 变体，286 行
- `lib/ui/theme/tokens.dart` — 设计 token，234 行
- `lib/ui/player/volume_controls.dart` — 音量控件，146 行
- `lib/ui/player/speed_button.dart` — 倍速控件，148 行

## Code Context

**可复用模式:**
- AnimatedContainer getter 模式（idle/play 双装饰插值）— 保留
- GlassButton.iconOnly 统一按钮 — 保留
- LayoutBuilder 断点响应式 — 保留但简化为 2 级

**预期改动文件:**
- `edge_glow.dart` — 删除 omni/pulse，新增渐变带参数
- `control_bar.dart` — 裁剪 BoxShadow，删除 _CompactCenterGroup，合并 top 描边
- `controls_overlay.dart` — 删除渐变带 Positioned
- `tokens.dart` — 删除 ~10 个死 token

## Deferred Ideas

- 自适应渐变强度 (基于视频帧) — defer to v2+
- 控制栏背景色从视频主色提取 — defer to v2+
