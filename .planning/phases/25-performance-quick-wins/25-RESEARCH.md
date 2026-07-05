# Phase 25: Performance Quick Wins - Research

**Researched:** 2026-07-06
**Domain:** Flutter animation performance, ImageFilter caching, design token extraction
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** AnimatedBuilder + DecorationTween — 缓存 playing/idle 两个 static final BoxDecoration
- **D-02:** DecorationTween 折中 — evaluate() 每帧创建 1 个 BoxDecoration（比 getter 每帧创建 2 个好，idle 时 0 个）
- **D-03:** AnimationController 放在 ControlsOverlay
- **D-04:** 对齐 BoxShadow 结构 — idle 和 playing 都有 4 个 BoxShadow
- **D-05:** 动画时长 150ms + easeOut — 放入 Tokens 常量
- **D-06:** 复用 GlassContainer.opacity 参数驱动 resize 渐变
- **D-07:** AnimationController + Tween 驱动 — resizing true→reverse(), false→forward()
- **D-08:** 150ms 时长 — 与 Decoration 动画共享时长常量
- **D-09:** 共享 AnimationController — Decoration 和 Resize 共用，resize 优先级更高
- **D-10:** GlassTier enum + static field — 每个 tier 一个缓存 ImageFilter
- **D-11:** 删除重复缓存 — 删除 ControlBar._blurFilter 和 PlaylistPanel._blurFilter
- **D-12:** thick 与 normal 共享实例 — 两者 sigma 都是 10
- **D-13:** Tokens.tapJitterThreshold = 18.0
- **D-14:** 注释说明
- **D-15:** 控制栏颜色 — 边框+背景+阴影全部调整为淡蓝辉光
- **D-16:** 修改现有 Tokens 常量
- **D-17:** 先用近似值，运行后微调
- **D-18:** 两个状态都调整，playing 稍亮

### Claude's Discretion
- 具体色值由 Claude 先用近似值，用户运行后微调
- AnimationController 的 ticker 管理细节由 Claude 决定
- DecorationTween 的具体实现细节由 Claude 决定

### Deferred Ideas (OUT OF SCOPE)
None
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-01 | Resize 毛玻璃渐变过渡 | GlassContainer.opacity 已有 AnimatedBuilder 监听，只需 ControlsOverlay 驱动 AnimationController |
| PERF-02 | Decoration 缓存 | static final BoxDecoration + DecorationTween + AnimatedBuilder 替代 AnimatedContainer 隐式动画 |
| PERF-03 | ImageFilter.blur 缓存 | GlassTier static final ImageFilter，dart:ui 不可变对象，线程安全 |
| PERF-04 | 魔法数字 18px 提取 | 提取为 Tokens.tapJitterThreshold，controls_overlay.dart 引用常量 |
</phase_requirements>

## Summary

Phase 25 消除 4 项 P0 性能/代码质量问题。核心思路：用显式动画（AnimationController + AnimatedBuilder）替代隐式动画（AnimatedContainer），用缓存（static final）替代重复创建（getter/每次 build）。

**PERF-01 (resize 渐变):** 当前 GlassContainer 的 resizing 参数是二元跳过（true=跳过 BackdropFilter，false=正常渲染）。改为：resizing=true 时先用 150ms 渐变将 opacity 从 1.0 动画到 0.0，然后跳过 BackdropFilter；resizing=false 时恢复 BackdropFilter 并渐变回 1.0。复用已有的 GlassContainer.opacity 参数。

**PERF-02 (decoration 缓存):** 当前 ControlBar._decorationPlaying/_decorationIdle 是 getter，每次 build() 创建新的 BoxDecoration（含 4+2 个 BoxShadow）。改为：两个 static final BoxDecoration + DecorationTween.evaluate() 每帧只创建 1 个。idle 状态 AnimationController.value=0 时 evaluate() 返回 begin 实例（0 创建）。

**PERF-03 (blur 缓存):** 当前 GlassContainer._buildBlurContent() 每次调用创建新的 ImageFilter.blur。改为：GlassTier enum 上新增 static final ImageFilter 字段，3 个 tier 各缓存一个实例。thick 和 normal 的 sigma 相同（10），编译器优化后自动共享同一实例。

**PERF-04 (魔法数字):** controls_overlay.dart 第 99 行 `18` 提取为 Tokens.tapJitterThreshold。

**附加:** 控制栏颜色从白色微光改为淡蓝辉光，修改 Tokens 中相关常量。

**Primary recommendation:** 一个 AnimationController 驱动两个 Tween（DecorationTween + Tween<double>），resize 优先级高于 decoration。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| AnimationController 生命周期 | ControlsOverlay (StatefulWidget) | — | 已有 SingleTickerProviderStateMixin，D-03 锁定 |
| DecorationTween 插值 | ControlsOverlay (builder) | ControlBar (consumes decoration) | ControlsOverlay 持有 controller，传 decoration 给 ControlBar |
| GlassContainer.opacity 驱动 | ControlsOverlay (producer) | GlassContainer (consumer) | opacity ValueNotifier 从 ControlsOverlay 传入 |
| ImageFilter 缓存 | GlassTier (enum static) | — | 按 tier 缓存，全局唯一 |
| Design tokens | Tokens (compile-time) | — | 所有常量集中管理 |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:ui ImageFilter | SDK built-in | Blur filter for BackdropFilter | Flutter 标准 API，不可变对象 |
| AnimationController | Flutter SDK | 驱动 Tween 动画 | Flutter 显式动画标准方式 |
| DecorationTween | Flutter SDK | BoxDecoration 插值 | Flutter 内置 Tween，支持 BoxShadow 列表插值 |
| AnimatedBuilder | Flutter SDK | 监听动画并重建 widget | Flutter 标准动画构建器 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| CurvedAnimation | SDK built-in | easeOut 曲线 | 包裹 AnimationController 施加曲线 |
| ValueNotifier | SDK built-in | 状态通知 | ControlsOverlay 现有基础设施 |

## Architecture Patterns

### Pattern 1: Shared AnimationController 驱动多 Tween

一个 AnimationController 同时驱动 DecorationTween（decoration 状态切换）和 Tween<double>（resize opacity 渐变）。resize 期间 controller 被 resize 动画占用，decoration 动画暂停。

```dart
// ControlsOverlay._ControlsOverlayState 中
late final AnimationController _animController;
late final DecorationTween _decorationTween;
late final Tween<double> _resizeTween;

void _onResizeChanged() {
  final resizing = widget.resizing?.value ?? false;
  if (resizing) {
    _animController.reverse(); // 1.0 → 0.0，150ms
  } else {
    _animController.forward(); // 0.0 → 1.0，150ms
  }
}
```

**关键决策 D-09 解读：** "resize 优先级更高" 意味着 resize 期间 controller 被 resize 动画独占，decoration 状态切换动画被延迟到 resize 结束后。这在视觉上是合理的——resize 期间用户注意力在窗口大小变化，不会注意到 decoration 颜色过渡被延迟。

### Pattern 2: DecorationTween evaluate 替代 getter

```dart
// 当前（每次 build 创建 2 个 BoxDecoration + 8 个 BoxShadow）
BoxDecoration get _decorationPlaying => BoxDecoration(...);
BoxDecoration get _decorationIdle => BoxDecoration(...);
// AnimatedContainer 隐式插值也需要新对象

// 优化后（静态缓存 + Tween.evaluate 每帧创建 1 个）
static final _decorationPlaying = BoxDecoration(...);
static final _decorationIdle = BoxDecoration(...);
final _decorationTween = DecorationTween(
  begin: _decorationIdle,
  end: _decorationPlaying,
);
// 在 AnimatedBuilder 中：
_decorationTween.evaluate(_animController) // 每帧创建 1 个 BoxDecoration
```

### Pattern 3: GlassTier static final ImageFilter 缓存

```dart
enum GlassTier {
  thin(Tokens.glassBlurThin),
  normal(Tokens.glassBlur),
  thick(Tokens.glassBlur);

  final double sigma;
  const GlassTier(this.sigma);

  /// 每个 tier 缓存一个 ImageFilter 实例（不可变，线程安全）
  static final ImageFilter thinBlur = ImageFilter.blur(
    sigmaX: Tokens.glassBlurThin,
    sigmaY: Tokens.glassBlurThin,
  );
  static final ImageFilter normalBlur = ImageFilter.blur(
    sigmaX: Tokens.glassBlur,
    sigmaY: Tokens.glassBlur,
  );
  // thick 和 normal 共享同一实例（D-12：sigma 相同）
  static final ImageFilter thickBlur = normalBlur;
}
```

### Anti-Patterns to Avoid

- **AnimatedContainer 隐式动画用于 decoration 插值：** 隐式动画需要每次 build 传入新对象才能触发插值，这正是 PERF-02 要消除的。用 AnimatedBuilder + DecorationTween 显式控制。
- **在 _buildBlurContent 中创建 ImageFilter：** 每次 build 都创建新实例，虽然 ImageFilter 是不可变的但创建有开销。用 static final 缓存。
- **使用 `as` 强转：** 项目 CLAUDE.md 明确禁止，用 pattern matching 替代。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BoxDecoration 插值 | 自写 lerp 逻辑 | DecorationTween | Flutter 内置，处理所有字段包括 BoxShadow 列表 |
| ImageFilter 缓存 | WeakReference 或自建缓存池 | static final | dart:ui ImageFilter 不可变，static final 生命周期=应用生命周期，无泄漏 |
| 动画曲线 | 自写 easeOut 数学 | Curves.easeOut | Flutter 标准，已优化 |

## Common Pitfalls

### Pitfall 1: BoxShadow 列表长度不匹配
**What goes wrong:** DecorationTween 在 interpolate 时要求 begin 和 end 的 BoxShadow 列表长度相同，否则 lerp 会产生不可预期的结果。
**Why it happens:** idle decoration 只有 2 个 BoxShadow，playing 有 4 个。
**How to avoid:** D-04 已锁定——idle 和 playing 都对齐为 4 个 BoxShadow。idle 补齐 outer shadow 和 glow ring（用透明色或低强度色）。
**Warning signs:** 测试中 decoration 插值颜色跳变或不平滑。

### Pitfall 2: AnimationController 在 resize 期间被 decoration 状态切换打断
**What goes wrong:** 用户正在 resize，此时 playing→idle 状态切换触发 _animController.forward()，与正在进行的 reverse() 冲突。
**Why it happens:** 共享 controller，两个事件源（resize 和 engine state）竞争。
**How to avoid:** resize 期间忽略 decoration 状态变化——在 _onEngineStateChanged 中检查 `_resizing` 标志，如果正在 resize 则延迟 decoration 切换。
**Warning signs:** resize 期间 decoration 颜色跳变。

### Pitfall 3: static final ImageFilter 在测试中共享状态
**What goes wrong:** 多个测试用例共享同一个 static final ImageFilter 实例，如果测试需要验证 filter 相等性可能失败。
**Why it happens:** static final 的生命周期跨越所有测试。
**How to avoid:** 测试不验证 ImageFilter 实例相等性，只验证 BackdropFilter 是否存在。现有测试已遵循此模式。
**Warning signs:** 测试间隔离失败。

### Pitfall 4: idle decoration 的 BoxShadow 对齐
**What goes wrong:** idle 状态补齐 4 个 BoxShadow 时用了不合适的颜色值，导致 idle 视觉效果与预期不符。
**How to avoid:** 透明色（Color(0x00000000)）补齐不影响视觉，但保持列表结构一致让 Tween 平滑插值。具体色值用近似值，运行后微调（D-17）。

### Pitfall 5: SingleTickerProviderStateMixin 限制
**What goes wrong:** ControlsOverlay 使用 `SingleTickerProviderStateMixin`，AutoHideController 已占用唯一 ticker。新增 decoration/resize AnimationController 会抛出 `Ticker already created` 异常。
**How to avoid:** 将 ControlsOverlay 的 mixin 从 `SingleTickerProviderStateMixin` 改为 `TickerProviderStateMixin`。这是 Flutter 官方推荐的多 ticker 方案，仅增加一个 Set 管理开销。
**Warning signs:** 运行时异常 `A ticker was already created`。

## Code Examples

### PERF-01: Resize 渐变 — ControlsOverlay 驱动 opacity

```dart
// ControlsOverlay._ControlsOverlayState
// 复用 GlassContainer.opacity 参数（D-06）

// 在 initState 中：
_animController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: Tokens.durationNormal), // 150ms
  value: 1.0, // 初始不 resize，opacity=1.0
);
_resizeOpacity = CurvedAnimation(
  parent: _animController,
  curve: Curves.easeOut, // D-05
);

// 监听 resizing 变化：
widget.resizing?.addListener(_onResizeChanged);

void _onResizeChanged() {
  final resizing = widget.resizing?.value ?? false;
  if (resizing) {
    _animController.reverse(); // 1.0 → 0.0
  } else {
    _animController.forward(); // 0.0 → 1.0
  }
}

// 传给 ControlBar 和 PlaylistPanel：
ControlBar(
  opacity: _resizeOpacity,
  resizing: widget.resizing,
  // ...
)
```

### PERF-02: DecorationTween + AnimatedBuilder

```dart
// ControlBar 中删除 getter，改为 static final + Tween
static final _decorationPlaying = BoxDecoration(
  color: Tokens.controlBarBg, // 淡蓝辉光 (D-15)
  borderRadius: _borderRadius,
  border: Border.all(color: Tokens.controlBarBorderBlue, width: 1),
  boxShadow: [
    BoxShadow(color: Tokens.controlBarBorderBlue, blurRadius: 0, spreadRadius: 0, offset: Offset(0, -1)),
    BoxShadow(color: Tokens.controlBarShadowBlack, blurRadius: 0, spreadRadius: 0, offset: Offset(0, 1)),
    BoxShadow(color: Tokens.controlBarOuterShadow, blurRadius: 32, offset: Offset(0, 8)),
    BoxShadow(color: Tokens.glowOuterRing, blurRadius: 1, spreadRadius: 1),
  ],
);

static final _decorationIdle = BoxDecoration(
  color: Tokens.controlBarBgIdle,
  borderRadius: _borderRadius,
  border: Border.all(color: Tokens.controlBarBorderIdle, width: 1),
  boxShadow: [
    BoxShadow(color: Tokens.controlBarBorderIdle, blurRadius: 0, spreadRadius: 0, offset: Offset(0, -1)),
    BoxShadow(color: Tokens.controlBarShadowBlack, blurRadius: 0, spreadRadius: 0, offset: Offset(0, 1)),
    BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0), // 补齐 4 个 (D-04)
    BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0), // 补齐 4 个 (D-04)
  ],
);
```

### PERF-03: GlassTier blur 缓存

```dart
enum GlassTier {
  thin(Tokens.glassBlurThin),
  normal(Tokens.glassBlur),
  thick(Tokens.glassBlur);

  final double sigma;
  const GlassTier(this.sigma);

  /// 获取缓存的 ImageFilter 实例（D-10）
  ImageFilter get blurFilter => switch (this) {
    GlassTier.thin => _thinBlur,
    GlassTier.normal || GlassTier.thick => _normalBlur, // D-12: 共享
  };

  static final ImageFilter _thinBlur = ImageFilter.blur(
    sigmaX: Tokens.glassBlurThin,
    sigmaY: Tokens.glassBlurThin,
  );
  static final ImageFilter _normalBlur = ImageFilter.blur(
    sigmaX: Tokens.glassBlur,
    sigmaY: Tokens.glassBlur,
  );
}
```

### PERF-04: 魔法数字提取

```dart
// tokens.dart 新增：
static const double tapJitterThreshold = 18.0; // 手指/鼠标点击的抖动容差

// controls_overlay.dart 替换：
// 之前：if (dx > 18 || dy > 18) return;
// 之后：
if (dx > Tokens.tapJitterThreshold || dy > Tokens.tapJitterThreshold) return;
```

### 控制栏颜色调整 — 淡蓝辉光 Tokens 修改

```dart
// tokens.dart — 从白色微光改为淡蓝辉光 (D-15, D-16)
// Playing 状态
static const controlBarBorderWhite = Color(0x1A6496FF);   // 淡蓝辉光描边（替代 0x1AFFFFFF）
static const controlBarShadowBlack = Color(0x0F5078FF);    // 底部辉光 6% 蓝（已存在，保持）
static const controlBarOuterShadow = Color(0x26000000);    // 外阴影 15% 黑（保持）

// Idle 状态 — 更淡的蓝辉光
static const controlBarBorderIdle = Color(0x0D6496FF);     // 5% 淡蓝描边（替代 0x0DFFFFFF）
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AnimatedContainer 隐式动画 | AnimatedBuilder + DecorationTween | Phase 25 | 每帧减少 2 个 BoxDecoration 创建 |
| 每次 build 创建 ImageFilter | GlassTier static final 缓存 | Phase 25 | 每帧减少 1 个 ImageFilter 创建 |
| resize 二元跳过 | opacity 渐变淡出/淡入 | Phase 25 | 消除视觉跳变 |
| 18px 魔法数字 | Tokens.tapJitterThreshold | Phase 25 | 可维护性提升 |

**Deprecated/outdated:**
- ControlBar._decorationPlaying/_decorationIdle getter：每帧创建新对象，被 static final + DecorationTween 替代
- ControlBar._blurFilter static final：被 GlassTier.blurFilter 替代，统一管理
- PlaylistPanel._blurFilter static final：同上

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 蓝辉光色值 `Color(0x1A6496FF)` 作为 controlBarBorderWhite 替代值 | 控制栏颜色调整 | 视觉效果不符预期，需运行后微调（D-17 已预见） |
| A2 | idle decoration 补齐 2 个透明 BoxShadow 不影响视觉 | PERF-02 | 如果 Flutter 渲染透明 BoxShadow 有性能开销则需改用更小的 spread/blur |

## Open Questions (RESOLVED)

1. **DecorationTween 的 BoxShadow 列表长度不同时的行为**
   - What we know: Flutter 源码中 BoxShadow.lerpList 要求列表等长或用 null 补齐
   - What's unclear: 不等长时是否抛异常还是静默截断
   - Recommendation: D-04 已锁定对齐方案，不需要处理不等长情况

2. **AnimationController ticker 约束 — 已解决**
   - What we know: ControlsOverlay 使用 `SingleTickerProviderStateMixin`，AutoHideController 已通过 `vsync: this` 占用唯一 ticker
   - Finding: 新增 decoration/resize AnimationController 需要第二个 ticker，必须切换到 `TickerProviderStateMixin`（允许多个 ticker）
   - Impact: 改动范围仅 ControlsOverlay 的 `with SingleTickerProviderStateMixin` → `with TickerProviderStateMixin`，一行改动
   - Performance: TickerProviderStateMixin 比 Single 多一个 Set 管理 ticker，开销可忽略

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | (check project) | — |
| dart:ui ImageFilter | PERF-03 | ✓ (SDK built-in) | — | — |
| AnimationController | PERF-01/02 | ✓ (SDK built-in) | — | — |
| DecorationTween | PERF-02 | ✓ (SDK built-in) | — | — |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK built-in) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test test/widget/shared/glass_container_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-01 | resize 渐变 opacity 0→1→0 | widget | `flutter test test/widget/shared/glass_container_test.dart` | ✅ |
| PERF-02 | decoration 缓存 + Tween 插值 | widget | `flutter test test/widget/player/control_bar_test.dart` | ✅ |
| PERF-03 | blur filter 缓存 | unit | `flutter test test/widget/shared/glass_container_test.dart` | ✅ |
| PERF-04 | tapJitterThreshold 常量 | unit | grep 验证无硬编码 18 | — |

### Sampling Rate
- **Per task commit:** `flutter test` (affected test files)
- **Per wave merge:** `flutter test`
- **Phase gate:** `flutter analyze` + `flutter test` 全部通过

### Wave 0 Gaps
- PERF-01 渐变过渡需要新增测试：验证 resizing 状态切换时 opacity 动画值变化
- PERF-02 DecorationTween 需要新增测试：验证 decoration 插值中间态
- 现有 glass_container_test.dart 已覆盖 resizing 二元跳过，需扩展为渐变场景

## Sources

### Primary (HIGH confidence)
- Flutter SDK source: `DecorationTween`, `BoxDecoration.lerp`, `BoxShadow.lerpList` — 标准库内置
- Context7 Flutter docs: AnimationController + Tween + AnimatedBuilder 模式
- 项目代码: glass_container.dart, control_bar.dart, controls_overlay.dart, tokens.dart — 直接阅读

### Secondary (MEDIUM confidence)
- Flutter animation tutorial: explicit vs implicit animation 对比

### Tertiary (LOW confidence)
- 控制栏淡蓝辉光色值 — 近似值，需运行后微调（D-17）

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 全部使用 Flutter SDK 内置 API，无外部依赖
- Architecture: HIGH — 基于已验证的现有模式（AnimatedBuilder + ValueListenable, static final 缓存）
- Pitfalls: HIGH — BoxShadow 对齐问题已由 D-04 锁定解决方案

**Research date:** 2026-07-06
**Valid until:** 2026-08-06 (30 days — Flutter SDK 稳定，API 不频繁变化)
