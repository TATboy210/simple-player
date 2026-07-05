# Phase 25: Performance Quick Wins - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-05
**Phase:** 25-Performance Quick Wins
**Areas discussed:** Decoration 缓存策略, Resize 渐变实现, Blur 缓存位置, 18px 常量归属, 控制栏颜色调整

---

## Decoration 缓存策略

| Option | Description | Selected |
|--------|-------------|----------|
| AnimatedBuilder + DecorationTween | 缓存 playing/idle 两个 static final BoxDecoration，用 DecorationTween 显式驱动插值 | ✓ |
| 保留 getter + 优化 BoxShadow | 保留 getter（每帧新建），只把 BoxShadow 列表提取为 static const | |
| AnimatedCrossFade + 缓存 | 用 FadeTransition 在两个 static final BoxDecoration 之间交叉淡入淡出 | |

**User's choice:** AnimatedBuilder + DecorationTween
**Notes:** 用户确认 DecorationTween.evaluate() 每帧创建 1 个对象的折中可接受。AnimationController 放在 ControlsOverlay。动画时长 150ms + easeOut。对齐 BoxShadow 结构（idle 和 playing 都有 4 个）。

---

## Resize 渐变实现

| Option | Description | Selected |
|--------|-------------|----------|
| 复用 opacity 参数 | GlassContainer 已有 opacity ValueListenable，ControlsOverlay 传入 opacityNotifier | ✓ |
| GlassContainer 内部驱动 | GlassContainer 内部根据 resizing 信号自动驱动淡入淡出 | |
| Opacity widget 包裹 | resize 期间用 Opacity 包裹（不用 BackdropFilter） | |

**User's choice:** 复用 opacity 参数
**Notes:** AnimationController + Tween 驱动。共享一个 AnimationController（Decoration 和 Resize），resize 优先级高于 decoration。

---

## Blur 缓存位置

| Option | Description | Selected |
|--------|-------------|----------|
| GlassTier enum + static field | 在 GlassTier 上新增 static final ImageFilter 实例 | ✓ |
| GlassContainer static Map | 在 GlassContainer 类中用 static final Map<GlassTier, ImageFilter> 缓存 | |

**User's choice:** GlassTier enum + static field
**Notes:** 删除 ControlBar._blurFilter 和 PlaylistPanel._blurFilter 的重复缓存。thick 与 normal 共用 sigma=10 实例（有意设计）。

---

## 18px 常量归属

| Option | Description | Selected |
|--------|-------------|----------|
| Tokens.tapJitterThreshold | 放入 Tokens 类，命名如 tapJitterThreshold | ✓ |
| 文件级 static const | 在 controls_overlay.dart 文件顶部添加 static const | |

**User's choice:** Tokens.tapJitterThreshold
**Notes:** 与 Tokens.iconMd=18.0 语义不同，分别定义。

---

## 控制栏颜色调整

| Option | Description | Selected |
|--------|-------------|----------|
| 边框+背景+阴影全部调整 | 从白色微光改为淡蓝辉光，与午夜蓝背景融合 | ✓ |
| 只调整边框色 | 只改 controlBarBorderWhite | |
| 只调整 playing 状态 | 只改 playing 状态的颜色 | |

**User's choice:** 边框+背景+阴影全部调整
**Notes:** 修改现有 Tokens 常量。先用近似值，运行后微调。两个状态都调整，playing 稍亮。

---

## Claude's Discretion

- 具体色值由 Claude 先用近似值，用户运行后微调
- AnimationController 的 ticker 管理细节
- DecorationTween 的具体实现细节

## Deferred Ideas

None — discussion stayed within phase scope
