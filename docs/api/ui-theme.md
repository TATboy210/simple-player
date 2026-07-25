# Theme API

## Tokens (class)

**File:** `lib/ui/theme/tokens.dart`

设计令牌 — 编译时常量。所有视觉值通过 `Tokens.*` 访问。

### Colors

| Token | Value | Description |
|-------|-------|-------------|
| `bgDeep` | `#060810` | 最深背景 |
| `bgBase` | `#0C0F18` | 基础背景 |
| `bgPanel` | `#111520` | 面板背景 |
| `bgElevated` | `#161A28` | 提升背景 |
| `bgHover` | `#283045` | hover 高亮 |
| `bgGlass` | `#8C0C0F18` | 毛玻璃背景 |
| `accent` | `#2C58F4` | 主强调色 |
| `accentBlue` | `#4A8EFF` | 蓝色辉光 |
| `danger` | `#FA3737` | 危险色 |
| `textPrimary` | `#EBFFFFFF` | 主文字色 (92% 白) |
| `textSecondary` | `#73FFFFFF` | 次文字色 (45% 白) |
| `textTertiary` | `#38FFFFFF` | 三级文字色 (22% 白) |
| `textDisabled` | `#444455` | 禁用文字色 |
| `borderHighlight` | `#33FFFFFF` | 边框高光 |
| `glassBorder` | `#146482FF` | 玻璃边框 |

### Typography

| Token | Value | Description |
|-------|-------|-------------|
| `fontFamily` | `'SF Pro Display'` | 主字体 |
| `fontFamilyMono` | `'SF Mono'` | 等宽字体 |
| `fontTitle` | `18.0` | 标题字号 |
| `fontBody` | `14.0` | 正文字号 |
| `fontCaption` | `12.0` | 说明字号 |
| `fontOverline` | `10.0` | 上划线字号 |

### Spacing

| Token | Value | Description |
|-------|-------|-------------|
| `spXs` | `4.0` | 极小间距 |
| `spSm` | `8.0` | 小间距 |
| `spMd` | `12.0` | 中间距 |
| `spLg` | `16.0` | 大间距 |
| `spXl` | `24.0` | 超大间距 |

### Border Radius

| Token | Value | Description |
|-------|-------|-------------|
| `radiusSm` | `8.0` | 按钮、标签 |
| `radiusMd` | `14.0` | 色板方块 |
| `radiusLg` | `22.0` | 卡片、控制栏 |
| `radiusXl` | `32.0` | 外框容器 |
| `radiusBtn` | `4.0` | 按钮圆角 |
| `radiusLarge` | `12.0` | 兼容保留 |
| `radiusPopup` | `8.0` | 弹窗圆角 |

### Glass Blur

| Token | Value | Description |
|-------|-------|-------------|
| `glassBlurThin` | `8.0` | 标题栏模糊 |
| `glassBlur` | `11.5` | 控制栏模糊 |
| `glassBlurThick` | `24.0` | 弹窗模糊 |

### Animation Durations (ms)

| Token | Value | Description |
|-------|-------|-------------|
| `durationFast` | `80` | 快速动画 |
| `durationNormal` | `150` | 普通动画 |
| `durationFade` | `400` | 淡入淡出 |
| `durationSlide` | `300` | 滑动动画 |
| `durationDebounce` | `500` | 防抖延迟 |
| `durationFullscreenAnim` | `200` | 全屏切换动画 |

### Control Bar

| Token | Value | Description |
|-------|-------|-------------|
| `controlBarHeight` | `110.0` | 控制栏高度 |
| `controlBarRadius` | `22.0` | 控制栏圆角 |
| `controlBarMarginH` | `18.0` | 水平边距 |
| `controlBarMarginBottom` | `16.0` | 底部边距 |

### Progress Bar

| Token | Value | Description |
|-------|-------|-------------|
| `progressBarHeight` | `31.0` | 进度条高度 |
| `progressBarThickness` | `3.0` | 进度条厚度 |
| `progressBarThicknessDrag` | `5.0` | 拖拽时厚度 |
| `progressThumbRadius` | `7.0` | thumb 半径 |
| `progressSeekThrottleMs` | `150` | seek 节流间隔 |

### Playlist

| Token | Value | Description |
|-------|-------|-------------|
| `playlistPanelWidth` | `420.0` | 面板宽度 |
| `playlistPanelWidthNarrow` | `320.0` | 窄屏面板宽度 |
| `playlistPanelHeight` | `240.0` | 面板高度 |
| `thumbnailTileHeight` | `124.0` | 缩略图高度 |

### Breakpoints

| Token | Value | Description |
|-------|-------|-------------|
| `compactBreakpoint` | `500.0` | 紧凑布局断点 |
| `breakpointUltraCompact` | `360.0` | 超紧凑断点 |
| `breakpointWide` | `1200.0` | 宽屏断点 |

### Auto-Hide

| Token | Value | Description |
|-------|-------|-------------|
| `hideDelayWindowed` | `5` (seconds) | 窗口模式隐藏延迟 |
| `hideDelayFullscreen` | `3` (seconds) | 全屏模式隐藏延迟 |
| `bottomTriggerZoneHeight` | `150.0` | 底部触发区域高度 |

### Scale

| Token | Value | Description |
|-------|-------|-------------|
| `hoverScale` | `1.02` | 悬停缩放 |
| `pressScale` | `0.98` | 按压缩放 |
