# Shared UI Widgets

## GlassContainer (StatelessWidget)

**File:** `lib/ui/shared/glass_container.dart`

毛玻璃容器 — 可复用的 Glassmorphism 基础组件。

### Constructor

```dart
const GlassContainer({
  required Widget child,
  double? width,
  double? height,
  EdgeInsetsGeometry? padding,
  EdgeInsetsGeometry? margin,
  BorderRadius? borderRadius,
  Border? border,
  GlassTier tier = GlassTier.normal,
  ValueListenable<double>? opacity,
  bool blurEnabled = true,
  ValueListenable<bool>? resizing,
  Color? backgroundColor,
})
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `tier` | 模糊层级（thin/normal/thick） |
| `opacity` | 淡入淡出动画，< 0.01 时跳过 BackdropFilter |
| `blurEnabled` | 低配硬件降级模式 |
| `resizing` | 窗口 resize 信号，true 时跳过 BackdropFilter |
| `backgroundColor` | 背景色，默认 Tokens.bgGlass |

### GlassTier (enum)

| Value | Sigma | Use Case |
|-------|-------|----------|
| `thin` | 8.0 | 标题栏 — 轻模糊，低 GPU 开销 |
| `normal` | 11.5 | 控制栏 — 默认模糊 |
| `thick` | 24.0 | 弹窗/对话框 |

### Usage

```dart
GlassContainer(
  tier: GlassTier.normal,
  padding: EdgeInsets.all(16),
  child: Text('Hello Glass'),
)
```

---

## GlassButton (StatefulWidget)

**File:** `lib/ui/shared/glass_container.dart`

毛玻璃风格按钮 — 双模式。

### Constructor

```dart
const GlassButton({
  required IconData icon,
  String? label,          // 非空 → 带模糊背景
  String? tooltip,
  bool isPrimary = false,
  bool enabled = true,
  required VoidCallback? onPressed,
  void Function(TapUpDetails)? onSecondaryTapUp,
  double iconSize = Tokens.iconLg,
  Color? color,
  Widget? child,
})

// Lightweight icon-only mode (no BackdropFilter)
const GlassButton.iconOnly({...})
```

### Features

- hover → scale 1.02
- press → scale 0.98
- disabled → cursor=basic, no scale

---

## OSD Overlay

**File:** `lib/ui/shared/osd_overlay.dart`

浮动 OSD 丸 — 显示临时状态提示（音量、倍速等）。

---

## EmptyState (StatelessWidget)

**File:** `lib/ui/shared/empty_state.dart`

空状态屏幕 — 无媒体时显示。

---

## AuroraBackground

**File:** `lib/ui/shared/aurora_background.dart`

极光背景效果。

---

## EdgeGlow

**File:** `lib/ui/shared/edge_glow.dart`

边缘微光效果。

---

## TransmittedLight

**File:** `lib/ui/shared/transmitted_light.dart`

透射光效果。

---

## HoverGlow

**File:** `lib/ui/shared/hover_glow.dart`

悬停发光效果。

---

## MergedListenable

**File:** `lib/ui/shared/merged_listenable.dart`

合并多个 ValueListenable 的辅助类。

---

## ValueListenableBuilder2

**File:** `lib/ui/shared/value_listenable_builder2.dart`

监听两个 ValueListenable 的 Builder。

---

## PlayModeUtils

**File:** `lib/ui/shared/play_mode_utils.dart`

PlayMode → icon/label 转换工具。

---

## SplashScreen

**File:** `lib/ui/shared/splash_screen.dart`

启动闪屏。

---

## ProgressSplashScreen

**File:** `lib/ui/shared/progress_splash_screen.dart`

带进度条的启动闪屏。
