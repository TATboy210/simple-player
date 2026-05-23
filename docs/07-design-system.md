# 07 — 设计系统

> Tokens 设计令牌、毛玻璃组件、Aurora 背景、OSD 浮动提示、字体与本地化。

## 设计令牌 (Tokens)

`lib/kernel/ui/theme/tokens.dart` — 全部编译时常量，单例 `Tokens` 类。

### 颜色

| 令牌 | 值 | 用途 |
|------|-----|------|
| `bgBase` | `#0A0A0F` | 最深层背景 |
| `bgPanel` | `#1A1A24` | 面板背景 |
| `bgElevated` | `#242432` | 悬浮元素背景 |
| `bgHover` | `#2A2A3A` | 悬停态背景 |
| `bgGlass` | `#801A1A24` | 毛玻璃底色 (50% alpha) |
| `accent` | `#2C58F4` | 主题色 |
| `accentLight` | `#2C57F4B4` | 浅主题色 (70% alpha) |
| `accentegg` | `#66CCFF` | 强调色 |
| `danger` | `#FA3737` | 危险/错误色 |
| `textPrimary` | `#E8E8F0` | 主文本 |
| `textSecondary` | `#9999AA` | 次文本 |
| `textTertiary` | `#666677` | 三级文本 |
| `textDisabled` | `#444455` | 禁用文本 |
| `borderHighlight` | `#33FFFFFF` | 边框高光 (20% 白) |

### 字体

| 令牌 | 值 | 说明 |
|------|-----|------|
| `fontFamily` | `'Noto Sans SC'` | 全局字体 |
| `fontTitle` | `18.0` | 标题 |
| `fontBody` | `14.0` | 正文 |
| `fontCaption` | `12.0` | 说明文字 |
| `fontOverline` | `10.0` | 上划线 |
| `fontBranding` | `18.0` | 品牌标识 |

**字重:** `weightExtraLight` (w200) / `weightLight` (w300) / `weightRegular` (w400) / `weightMedium` (w500) / `weightSemiBold` (w600)

### 图标尺寸

`iconSm` (16) / `iconMd` (18) / `iconLg` (20) / `iconXl` (28)

### 间距

`spXs` (4) / `spSm` (8) / `spMd` (12) / `spLg` (16) / `spXl` (24)

### 圆角

`radiusSm` (6) / `radiusMd` (10) / `radiusBtn` (4) / `radiusLarge` (12) / `radiusPopup` (8)

### 毛玻璃模糊

`glassBlurThin` (12) / `glassBlur` (16) / `glassBlurThick` (24)

### 动画时长 (毫秒)

| 令牌 | 值 | 用途 |
|------|-----|------|
| `durationFast` | 80 | 按钮反馈 |
| `durationNormal` | 150 | 状态切换 |
| `durationFade` | 300 | 淡入淡出 |
| `durationSlide` | 300 | 滑动 |
| `durationDebounce` | 500 | 防抖 |

### 自动隐藏

`hideDelayFullscreen` (3s) / `hideDelayWindowed` (5s)

### 缩放

`hoverScale` (1.02) / `pressScale` (0.98)

### 控件专用

| 分类 | 令牌 | 值 |
|------|------|-----|
| 标题栏 | `titleBarHeight` | 36 |
| 标题栏 | `titleBarButtonWidth` | 36 |
| 标题栏 | `titleBarBg` | `#E61A1A24` |
| 控制栏 | `controlBarHeight` | 84 |
| 控制栏 | `controlBarRadius` | 16 |
| 控制栏 | `controlBarMarginH` | 18 |
| 控制栏 | `controlBarMarginBottom` | 16 |
| 进度条 | `progressBarHeight` | 32 |
| 进度条 | `progressBarThickness` | 3 |
| 进度条 | `progressPlayed` | `#6C5CE7` |

## 主题桥接

`lib/kernel/ui/theme/app_theme.dart` 将 Tokens 桥接到 Flutter ThemeData：

```dart
class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Tokens.bgBase,
    colorScheme: const ColorScheme.dark(
      primary: Tokens.accent,
      secondary: Tokens.accentLight,
      surface: Tokens.bgElevated,
      error: Tokens.danger,
    ),
    fontFamily: Tokens.fontFamily,
    // ...
  );
}
```

项目采用单主题 (Midnight)，编译时常量，无运行时主题切换。

## 毛玻璃组件 (GlassContainer)

`lib/ui/shared/glass_container.dart` — 可复用的 Glassmorphism 基础组件。

```dart
enum GlassTier {
  thin(Tokens.glassBlurThin),    // 标题栏 — 12 sigma
  normal(Tokens.glassBlur),      // 控制栏 — 16 sigma
  thick(Tokens.glassBlurThick);  // 弹窗 — 24 sigma
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final GlassTier tier;
  final bool respectResizeState;  // resize 期间跳过 BackdropFilter
  // ...
}
```

**渲染结构:**

```
ClipRRect (圆角裁剪)
  └─ BackdropFilter (高斯模糊)
      └─ Container
          ├─ color: Tokens.bgGlass
          ├─ borderRadius
          └─ border: Tokens.borderHighlight
```

**`respectResizeState` 优化:** 窗口 resize 期间跳过 `BackdropFilter`，降低 GPU 开销。通过 `WindowBridge.isResizing` 监听。

## Aurora 背景动画

`lib/ui/shared/aurora_background.dart` — 极光背景，用于空状态和品牌展示。

**实现:**
- `CustomPainter` 绘制多个颜色 blob
- 使用 Lissajous 曲线参数控制 blob 运动轨迹
- `Ticker` 驱动动画循环
- 噪点叠加层防止色带 (50 个随机点，每秒更新种子)
- 与播放状态联动：播放时淡出，暂停/空闲时显示

**关键类:**
- `AuroraBackground` — StatefulWidget，管理 Ticker 生命周期
- `_AuroraPainter` — CustomPainter，绘制渐变 blob + 噪点
- `_LissajousParams` — Lissajous 曲线参数 (freqX/Y, phaseX/Y)
- `_RepaintNotifier` — 暴露 `markDirty()` 绕过 `@protected` 限制

## OSD 浮动提示

`lib/ui/player/osd_overlay.dart` — 临时消息显示 (音量变化、播放模式切换)。

**架构:**
- `OsdService` — 单例，`ValueNotifier<String>` 驱动消息
- `OsdOverlay` — StatefulWidget，监听 `OsdService`，`FadeTransition` 动画
- `_OsdBubble` — 毛玻璃背景的提示气泡

**调用示例:**
```dart
// control_bar.dart
OsdService.I.show('${(_savedVolume * 100).round()}%');
OsdService.I.show(l10n.mute, icon: Icons.volume_off);
```

**集成位置:** `app.dart:176` 在 Stack 顶层放置 `OsdOverlay`，`IgnorePointer` 确保不拦截交互。

## 字体

**主字体:** Noto Sans SC (思源黑体)

```
assets/fonts/
├── NotoSansSC-Regular.ttf    (weight: 400)
├── NotoSansSC-Medium.ttf     (weight: 500)
└── NotoSansSC-SemiBold.ttf   (weight: 600)
```

**字体特性:** `FontFeature.tabularFigures()` — 等宽数字，用于时间码对齐。

## 本地化

```
lib/l10n/
├── app_en.arb            # 英文
├── app_zh.arb            # 中文
└── app_localizations.dart # 生成代码
```

- 使用 Flutter 官方 `gen_l10n` 生成
- `pubspec.yaml` 设置 `generate: true`
- 2 个 locale: en / zh
- 通过 `AppLocalizations.of(context)` 访问
- 设置面板可切换语言，延迟应用 (关闭对话框后生效)

## 使用规范

```dart
// ✅ 使用 Tokens
Container(color: Tokens.bgPanel)

// ❌ 硬编码颜色
Container(color: Color(0xFF1A1A24))

// ✅ 使用 GlassContainer
GlassContainer(tier: GlassTier.normal, child: ...)

// ❌ 手动 BackdropFilter
ClipRRect(child: BackdropFilter(sigma: 16, ...))

// ✅ 使用 Tokens 间距
SizedBox(height: Tokens.spMd)

// ❌ 魔法数字
SizedBox(height: 12)
```
