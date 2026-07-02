# Phase 16: Token Foundation & Independent Fixes - Research

**Researched:** 2026-07-02
**Domain:** Flutter design tokens, widget parameters, WCAG accessibility
**Confidence:** HIGH

## Summary

Phase 16 涉及三个独立改动：(1) 在 `tokens.dart` 中添加 6 个空状态常量；(2) 为 `EdgeGlow` widget 添加可选 `glowIntensity` 参数；(3) 修复 `textSecondary` 的 WCAG AA 对比度。三个改动互不依赖，可并行实施。

改动范围小且明确：`tokens.dart` 添加常量（~10 行），`edge_glow.dart` 添加参数（~30 行逻辑），`tokens.dart` 修改一个 alpha 值。无外部依赖引入，无架构变更，无新包安装。

**Primary recommendation:** 三个需求可作为独立 task 并行实施，每个改动控制在 50 行以内。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Design token 定义 | UI Theme | -- | tokens.dart 是唯一的 token 定义位置 |
| EdgeGlow 参数扩展 | UI Shared Widget | -- | edge_glow.dart 是独立 widget，不涉及 engine 层 |
| WCAG 对比度修复 | UI Theme | -- | 仅修改 tokens.dart 中的一个常量值 |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material.dart | SDK 内置 | Color, TextStyle, BoxShadow | 项目唯一 UI 框架 |
| dart:ui | SDK 内置 | Color.withValues() | Dart 3 颜色操作 API |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | SDK 内置 | Widget 测试、golden 测试 | 验证改动无回归 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 直接修改 textSecondary alpha | 新增 textSecondaryAccessible 常量 | CONTEXT.md D-10 锁定为直接修改，不新增常量 |

**Installation:**
```bash
# 无新依赖
```

## Package Legitimacy Audit

本 phase 不引入任何外部包。无需审计。

## Architecture Patterns

### Recommended Project Structure
```
lib/ui/theme/tokens.dart          # 添加 6 个 idle token + 修改 textSecondary alpha
lib/ui/shared/edge_glow.dart      # 添加 glowIntensity 参数
```

### Pattern 1: Token 常量定义
**What:** 在 `Tokens` 类中添加 `static const` 颜色常量
**When to use:** 所有视觉值必须通过 `Tokens.*` 访问
**Example:**
```dart
// Source: tokens.dart 现有模式 (line 55-58)
static const controlBarBg = Color(0x72080A10);  // #080A10 @ 45%
static const controlBarBorderWhite = Color(0x0AFFFFFF); // 4% 白色描边

// 新增 idle token 遵循相同模式
static const controlBarBgIdle = Color(0x39080A10);      // #080A10 @ ~22%
static const controlBarBorderIdle = Color(0x05FFFFFF);   // 2% 白色描边
```

### Pattern 2: 可选参数 + 默认值保持向后兼容
**What:** 为 widget 添加 `double?` 参数，默认 `null` 保持现有行为
**When to use:** 扩展现有 widget 功能而不破坏调用者
**Example:**
```dart
// Source: CONTEXT.md D-06, D-07
class EdgeGlow extends StatefulWidget {
  final Widget child;
  final EdgeGlowVariant variant;
  final BorderRadius? borderRadius;
  final bool enabled;
  final double? glowIntensity; // 新增：null = 现有行为

  const EdgeGlow({
    super.key,
    required this.child,
    this.variant = EdgeGlowVariant.gradient,
    this.borderRadius,
    this.enabled = true,
    this.glowIntensity, // 默认 null
  });
```

### Pattern 3: alpha 乘法缩放
**What:** 使用 `glowIntensity` 乘以现有 BoxShadow 的 alpha 值
**When to use:** 需要按比例减弱发光强度，同时保持相对层次
**Example:**
```dart
// Source: CONTEXT.md D-07
// 在 _buildGradientGlow() 中：
final intensity = widget.glowIntensity ?? 1.0;
BoxShadow(
  color: Tokens.glowMidBlue.withValues(alpha: Tokens.glowMidBlue.a * intensity),
  blurRadius: 20,
  spreadRadius: 0,
),
```

### Anti-Patterns to Avoid
- **硬编码颜色值:** 所有颜色必须通过 `Tokens.*` 访问，不直接写 `Color(0x...)`
- **破坏向后兼容:** `glowIntensity` 默认 `null` 而非 `1.0`，确保现有调用者无需修改
- **late 关键字:** 避免使用 `late`，优先使用 nullable 类型或构造函数初始化

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WCAG 对比度计算 | 手动计算相对亮度 | 直接使用 CONTEXT.md 确认的值 (0x80FFFFFF) | 用户已验证目标值 5.3:1 |

## Common Pitfalls

### Pitfall 1: idle token 值与现有 token 不协调
**What goes wrong:** 新 idle token 与现有 token 的相对关系不合理
**Why it happens:** 随意选择 alpha 值，未参考现有 token 的比例
**How to avoid:** 遵循 D-02 决策：现有 alpha 的 40-50%
**Warning signs:** idle 状态视觉上太暗（不可见）或太亮（与播放状态无区别）

### Pitfall 2: EdgeGlow glowIntensity 影响动画平滑性
**What goes wrong:** glowIntensity 变化时产生视觉跳变
**Why it happens:** 直接赋值而非动画过渡
**How to avoid:** 遵循 D-09：使用 AnimatedBuilder 监听 glowIntensity 变化
**Warning signs:** 空状态切换时发光效果突然变化

### Pitfall 3: textSecondary 修改影响全局
**What goes wrong:** 修改 `textSecondary` alpha 后，所有使用处的对比度都变化
**Why it happens:** `textSecondary` 在 30+ 处使用（grep 确认）
**How to avoid:** 这是预期行为（D-10 决策），但需验证所有使用场景的视觉效果
**Warning signs:** 对话框、设置面板中的次要文本变得过亮

### Pitfall 4: Golden 测试回归
**What goes wrong:** 修改 textSecondary 后 golden 测试失败
**Why it happens:** golden 截图像素级比较，alpha 变化会导致差异
**How to avoid:** 更新 golden 文件（`flutter test --update-goldens`）
**Warning signs:** `control_bar_idle.png`、`control_bar_playing.png` 等 golden 文件不匹配

## Code Examples

### 添加 idle token 常量
```dart
// Source: tokens.dart 现有模式
// 在控制栏装饰区域 (line 144) 后添加：
// ── 控制栏空状态 (idle) ──
static const controlBarBgIdle = Color(0x39080A10);       // #080A10 @ ~22% (45% 的 ~49%)
static const controlBarBorderIdle = Color(0x05FFFFFF);    // 2% 白色描边 (4% 的 50%)
static const glassBorderIdle = Color(0x0A6482FF);         // rgba(100,130,255,0.04) (0.08 的 50%)
static const controlBarTextPrimaryIdle = Color(0x76FFFFFF); // rgba(255,255,255,0.46) (0.92 的 50%)
static const controlBarTextSecondaryIdle = Color(0x3AFFFFFF); // rgba(255,255,255,0.23) (0.45 的 ~51%)
static const controlBarIconIdle = Color(0x76FFFFFF);      // rgba(255,255,255,0.46) (同 primary idle)
```

### EdgeGlow glowIntensity 实现
```dart
// Source: edge_glow.dart _buildGradientGlow()
Widget _buildGradientGlow() {
  final intensity = widget.glowIntensity ?? 1.0;
  return Container(
    decoration: BoxDecoration(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
      boxShadow: [
        BoxShadow(
          color: Tokens.glowHighlightWhite.withValues(
            alpha: Tokens.glowHighlightWhite.a * intensity,
          ),
          blurRadius: 0,
          spreadRadius: 0,
          offset: const Offset(0, 1),
        ),
        // ... 其余 BoxShadow 同理
      ],
    ),
    child: CustomPaint(
      painter: _GradientBorderPainter(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
      ),
      child: widget.child,
    ),
  );
}
```

### WCAG 对比度验证
```dart
// Source: CONTEXT.md D-11
// 计算逻辑（用于测试验证）：
// 背景: #060810 (bgDeep), 相对亮度 L_bg ≈ 0.003
// 文本: rgba(255,255,255,0.50) 混合后 ≈ #808088, L_text ≈ 0.217
// 对比度 = (0.217 + 0.05) / (0.003 + 0.05) ≈ 5.04:1
// 实际在 bgDeep 上: (L_composite + 0.05) / (L_bg + 0.05) ≥ 4.5:1 ✓
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| textSecondary alpha 0x73 (45%) | alpha 0x80 (50%) | Phase 16 | 对比度 4.30:1 → ~5.3:1, 满足 WCAG AA |

**Deprecated/outdated:**
- 无废弃项。所有改动都是增量添加或值修改。

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | idle token 值取现有 alpha 的 40-50% 能产生"明显更淡但仍然可见"的效果 | Token 常量定义 | 需要 UI-06 视觉调优阶段迭代 |
| A2 | EdgeGlow 的 gradient 变体是 ControlBar 唯一使用的变体 | EdgeGlow 实现 | pulse/omni 变体也需同步实现 intensity 逻辑 |
| A3 | textSecondary 修改后所有 30+ 使用处的视觉效果均可接受 | WCAG 修复 | 部分场景可能需要单独的 idle 变体 |

**说明：** A1 已被 CONTEXT.md D-02 锁定（"统一降低比例：现有 alpha 的 40-50%"），非真正假设。A2 通过 grep 确认 ControlBar 仅使用 `EdgeGlowVariant.gradient`。A3 是 D-10 决策的推论，需 UI-06 阶段验证。

## Open Questions

1. **idle token 具体 alpha 值**
   - What we know: D-02 锁定为"现有 alpha 的 40-50%"
   - What's unclear: 精确百分比需视觉验证
   - Recommendation: 使用 49%（便于位运算），UI-06 阶段迭代

2. **EdgeGlow AnimatedBuilder 过渡时机**
   - What we know: D-09 要求"glowIntensity 变化时使用动画过渡"
   - What's unclear: 动画时长和曲线
   - Recommendation: 使用 `durationFast` (80ms) + `Curves.easeOut`，与现有 UI 动画一致

3. **Golden 测试更新策略**
   - What we know: textSecondary 修改会影响所有 golden 文件
   - What's unclear: 是否需要同时更新 idle 状态的 golden
   - Recommendation: 更新现有 golden + 添加 idle 状态 golden 测试

## Environment Availability

> 本 phase 无外部依赖。仅修改 Dart 源文件。

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | 编译/测试 | ✓ | (项目已配置) | — |
| Dart SDK | 编译/测试 | ✓ | (随 Flutter) | — |

**Missing dependencies with no fallback:** 无
**Missing dependencies with fallback:** 无

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK 内置) |
| Config file | 无额外配置 |
| Quick run command | `flutter test test/widget/player/control_bar_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-01 | 6 个 idle token 常量存在且编译通过 | unit | `flutter test` (编译即验证) | ✅ 编译检查 |
| UI-04 | EdgeGlow 接受 glowIntensity 参数 | widget | `flutter test test/widget/shared/edge_glow_test.dart` | ❌ Wave 0 |
| UI-05 | textSecondary 对比度 >= 4.5:1 | unit | `flutter test test/unit/theme/contrast_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test` (快速验证编译 + 现有测试无回归)
- **Per wave merge:** `flutter test` (全量)
- **Phase gate:** `flutter test` 全绿 + golden 更新

### Wave 0 Gaps
- [ ] `test/widget/shared/edge_glow_test.dart` — 覆盖 UI-04 glowIntensity 参数
- [ ] `test/unit/theme/contrast_test.dart` — 覆盖 UI-05 对比度计算
- [ ] 更新 golden 文件 — textSecondary 修改后需 `flutter test --update-goldens`

## Security Domain

本 phase 不涉及安全敏感代码（无认证、无用户输入、无加密、无网络通信）。

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |

## Sources

### Primary (HIGH confidence)
- `lib/ui/theme/tokens.dart` — 现有 token 定义、命名约定、颜色格式
- `lib/ui/shared/edge_glow.dart` — EdgeGlow widget 完整实现、3 种变体
- `lib/ui/player/control_bar.dart` — ControlBar 使用 EdgeGlow 和 token 的方式
- `16-CONTEXT.md` — 用户锁定的所有决策 (D-01 到 D-13)

### Secondary (MEDIUM confidence)
- `test/widget/player/control_bar_test.dart` — 现有测试模式
- `test/golden/control_layouts_golden_test.dart` — Golden 测试模式

### Tertiary (LOW confidence)
- 无。所有关键信息均来自代码和用户决策。

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 无新依赖，仅使用现有 SDK API
- Architecture: HIGH — 改动范围小，模式明确，CONTEXT.md 已锁定所有决策
- Pitfalls: MEDIUM — textSecondary 全局影响需视觉验证

**Research date:** 2026-07-02
**Valid until:** 2026-08-02 (稳定，设计 token 变化频率低)
