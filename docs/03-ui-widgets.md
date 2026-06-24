# Simple Player Flutter -- UI层 (Widgets/Theme/Shared组件)

> Player Screen、Control Bar、OSD、Playlist、Dialogs、Shared组件、Theme系统的完整技术分析。

---

## 1. Player Screen Architecture (播放器屏幕架构)

**文件:** `lib/ui/player/player_screen.dart`

**职责:** 顶层编排 widget，组合整个播放 UI。接收 `MediaEngine`、`PlaybackController` 和文件操作回调。

### Widget 树结构

```
KeyboardListener (onKeyEvent)
  GestureDetector (onAspectRatioCycle, onMediaPlayPause)
    Scaffold (backgroundColor: Tokens.bgBase)
      Column
        CustomTitleBar (全屏时省略)
        Expanded
          Row
            Expanded
              DropHandler (onFilesDropped, onHoverChanged)
                Stack (fit: StackFit.expand)
                  VideoSurface (engine)
                  ValueListenableBuilder<MediaState> (idle → EmptyState)
                  ValueListenableBuilder<int> (playlist generation → ControlsOverlay)
            PlaylistPanel (AnimatedSwitcher 切换)
```

### 全屏处理

全屏时 `CustomTitleBar` 从树中完全排除 (非 `Offstage` 包装)，避免 `BackdropFilter` GPU 开销。

### 键盘快捷键

| 按键 | 动作 |
|------|------|
| Space | 播放/暂停 |
| Left/Right | 快退/快进 5秒 |
| Up/Down | 音量 +/-5% |
| F | 切换全屏 |
| M | 切换静音 |
| N | 上一首 |
| P | 下一首 |
| O | 打开文件 |
| A | 设置AB循环A点 |
| B | 设置AB循环B点 |
| S | 切换字幕 |
| ESC | 退出全屏 |

---

## 2. Control Bar System (控制栏系统)

**文件:** `lib/ui/player/control_bar.dart` (~550行)

**职责:** 底部毛玻璃栏，包含所有播放控件: 进度条、时间显示、音量、倍速、AB循环、播放模式、播放列表切换。

### Widget 树结构

```
GlassContainer (tier: normal, respectResizeState: true)
  Column
    ProgressBar (顶部 -- seek栏)
    Row
      VolumeButton (左侧)
      Spacer
      _SpeedButton (内联标签按钮)
      _AbLoopButton (3态: off/A/AB)
      _PlayModeButton (循环播放模式)
      _PlaylistToggleButton
```

### 内部组件

**`_VolumeButton`**: 包装 `GestureDetector` + `InkWell`。显示图标+百分比标签。点击切换静音。通过自定义 `_VolumeMerged` ValueNotifier 组合 `engine.isMuted` 和 `engine.volume`。

**`_SpeedButton`**: 显示当前播放速率标签 (如 "1.0x")。点击循环预定义速度值。活跃状态使用 `Tokens.accent` 高亮边框。

**`_AbLoopButton`**: 3态按钮: off → A点已设 → AB循环激活。

### OSD集成

每次音量/速度变更调用 `OsdService.I.show()` 显示浮动通知。音量变更包含 `progress` 参数用于OSD内迷你进度条。

---

## 3. Controls Overlay (控制叠加层)

**文件:** `lib/ui/player/controls_overlay.dart` (~250行)

**职责:** 全屏手势和动画层，管理控制栏可见性、淡入淡出过渡、居中控件和用户交互。

### Widget 树

```
GestureDetector (behavior: translucent)
  onTap → 切换可见性
  onDoubleTap → 切换全屏
  MouseRegion
    onEnter → 显示控件
    onExit → 计划隐藏
    IgnorePointer (ignoring: !_visible)
      RepaintBoundary
        Stack
          Positioned (bottom) → FadeTransition > ControlBar
          Positioned (center) → CenterGroup (play/pause/prev/next)
```

### 自动隐藏状态机

| 引擎状态 | 行为 |
|----------|------|
| `idle` | 控件永久可见，无自动隐藏 |
| `loading` / `playing` | 显示控件，启动自动隐藏计时器 |
| `paused` / `stopped` / `completed` / `error` | 强制显示，取消隐藏计时器 |

### 手势处理

- **单击** 空白区域: 切换控制栏可见性 (300ms防抖区分双击)
- **双击**: 调用 `onToggleFullscreen`
- **鼠标进入**: 立即显示控件
- **鼠标退出**: 计划隐藏 (尊重idle状态)
- 当 `emptyStatePresent && isIdle`: 手势识别器禁用，让点击穿透到 EmptyState 按钮

---

## 4. Auto-Hide Controller (自动隐藏控制器)

**文件:** `lib/ui/player/auto_hide_controller.dart` (~150行)

**职责:** 从 ControlsOverlay 提取的独立可测试组件。管理控制栏可见性、淡入/淡出动画、自动隐藏计时器和鼠标悬停节流。

### 关键字段

| 字段 | 说明 |
|------|------|
| `_animController` | 300ms 正向时长的 AnimationController |
| `_opacity` | CurvedAnimation (Curves.easeOut) |
| `_hideTimer` | 延迟自动隐藏的 Timer |
| `_hoverThrottle` | 100ms 悬停事件防抖 |
| `visible` | ValueNotifier<bool> 本地重建 |

### 隐藏延迟逻辑

- 全屏: 3秒
- 窗口模式: 5秒
- 弹窗显示时: 延迟隐藏

---

## 5. Center Controls (居中控制组)

**文件:** `lib/ui/player/center_controls.dart` (~100行)

### PlayPauseButton

`StatelessWidget` 使用 `ValueListenableBuilder<MediaState>` 切换播放/暂停图标。使用 `GlassIconButton` (28dp)。播放时图标颜色为 `Tokens.accent`，否则 `Tokens.textPrimary`。

### CenterGroup

5个按钮的 `Row`:
```
AnimatedOpacity (idle时0.38, 否则1.0)
  Row
    GlassIconButton (skip_previous)
    GlassIconButton (replay_10 / forward_10)
    PlayPauseButton
    GlassIconButton (forward_10 / replay_10)
    GlassIconButton (skip_next)
```

---

## 6. Video Surface (视频表面)

**文件:** `lib/ui/player/video_surface.dart` (~60行)

**职责:** 渲染原生视频纹理。处理画面比例适配和滚轮音量调节。

### Widget 树

```
RepaintBoundary
  AnimatedBuilder (listening: engine.textureId + engine.aspectRatio)
    AspectRatio (ratio: safeRatio)
      FittedBox (fit: BoxFit.contain)
        SizedBox (calculated)
          Texture (textureId: id)
```

- 监听 `engine.textureId` 和 `engine.aspectRatio` 通过 `Listenable.merge`
- `textureId` 为 -1 时返回空 `SizedBox.shrink()`
- 画面比例钳位最小 0.1 防止除零
- 手势 (点击/双击) 不在此处理 -- 由 `ControlsOverlay` 管理以避免手势竞技场冲突

---

## 7. OSD (On-Screen Display) Overlay

**文件:** `lib/ui/player/osd_overlay.dart` (~200行)

**职责:** 浮动胶囊状通知，显示临时消息 (音量变更、播放模式切换、速度变更)。

### 架构

**`OsdService`** (单例): 全局服务，通过 `OsdService.I` 访问。
```dart
ValueNotifier<OsdMessage?> message;  // 驱动UI内容
ValueNotifier<bool> _visible;        // 驱动动画进入/退出
void show(text, {icon, progress, hold});  // 默认1200ms保持
void hide();
```

**`OsdOverlay`** (widget): 渲染动画胶囊。
- 不对称时长: 150ms 进入, 300ms 退出
- `FadeTransition` + `ScaleTransition` 组合 (0.95→1.0缩放)
- 进入: `Curves.easeOutCubic`, 退出: `Curves.easeIn`
- 内容: `GlassContainer` (thick tier) + Row (可选图标 + 文字 + 可选进度条)

### OsdMessage 数据

```dart
class OsdMessage {
  final String text;
  final IconData? icon;
  final double? progress;  // 0.0-1.0 迷你进度条, null=隐藏
}
```

---

## 8. Time Range Display (时间显示)

**文件:** `lib/ui/player/time_range_display.dart` (~50行)

**职责:** 显示当前位置/总时长 (如 "01:23 / 04:56")。

- 使用 `MergedListenable` 合并 `engine.position` 和 `engine.duration`
- 使用 `FontFeature.tabularFigures` 防止数字跳动 (1和8宽度不同)
- 文本样式: `Tokens.textSecondary`, `Tokens.fontCaption` (12dp)

---

## 9. Volume Controls (音量控制)

**文件:** `lib/ui/player/volume_controls.dart` (~100行)

**类: `VolumeButton`**
- 追踪 `_savedVolume` (静音前音量)
- 点击: 如果已静音则恢复保存音量；如果未静音则保存当前并静音
- 使用 `ValueListenableBuilder2<bool, double>` 同时监听 `engine.isMuted` 和 `engine.volume`
- 图标选择: `volume_off` (静音/0), `volume_down` (<0.5), `volume_up` (>=0.5)

---

## 10. Playlist Panel (播放列表面板)

**文件:** `lib/ui/playlist/playlist_panel.dart` (~350行)

**职责:** 右侧面板，两个标签页: 播放列表和播放历史。

### Widget 树

```
Container (width: Tokens.playlistPanelWidth, bgPanel, border left)
  Column
    _Header (项目数, 标签选择器, 清空按钮)
    TabBar (Playlist / History)
    Expanded
      TabBarView
        _PlaylistTab (ReorderableListView)
        _HistoryTab (ListView)
```

### 功能

| 功能 | 说明 |
|------|------|
| 拖拽重排 | `ReorderableListView` + `onReorder` |
| 右键菜单 | 播放、复制路径、属性、移除 |
| 工具提示 | 显示断点位置和总时长 |
| 活跃高亮 | 当前播放项使用 `Tokens.accent` 高亮 |

---

## 11. Recent Files Panel (最近播放面板)

**文件:** `lib/ui/playlist/recent_files_panel.dart` (~60行)

- 按时间戳降序排列 (最近优先)
- 仅显示有非空 `timestamp` 的项
- 空状态显示 "No recent files" 居中文本

---

## 12. Dialogs (对话框)

### 12.1 Media Info Dialog (媒体属性对话框)

**文件:** `lib/ui/dialogs/media_info_dialog.dart` (~250行)

显示媒体文件元数据: 文件路径、名称、视频编码、分辨率、码率、音频编码、声道数、采样率、时长。

**`_CopyableRow`**: 显示标签+值。长按或点击通过 `Clipboard.setData` 复制到剪贴板。

### 12.2 Settings Dialog (设置对话框)

**文件:** `lib/ui/dialogs/settings_dialog.dart` (~150行)

标签页设置对话框:
- **Equalizer Tab**: 10段均衡器
- **Audio Track Tab**: 音轨列表，活跃轨高亮
- **Video Processing Tab**: 亮度/对比度/饱和度/色调/旋转/画面比例/去隔行

---

## 13. Shared Components (共享组件)

### 13.1 GlassContainer -- 毛玻璃容器

**文件:** `lib/ui/shared/glass_container.dart` (~100行)

可复用毛玻璃基础组件，提供背景模糊 + 半透明背景。

**GlassTier 枚举:**

| Tier | 模糊度 (sigma) | 用途 |
|------|---------------|------|
| `thin` | 12 | 标题栏 |
| `normal` | 16 | 控制栏 |
| `thick` | 24 | 对话框 |

**`respectResizeState`**: 为 true 时监听 `WindowBridge.I.isResizing`，窗口调整大小期间跳过 `BackdropFilter`，降级为纯色 `bgGlass`。防止调整大小期间GPU卡顿。

### 13.2 GlassIconButton -- 毛玻璃图标按钮

**文件:** `lib/ui/shared/glass_icon_button.dart` (~60行)

36x36 毛玻璃风格图标按钮。

```
Tooltip (waitDuration: 400ms)
  SizedBox (36x36)
    Material (transparent)
      InkWell
        hoverColor: Tokens.bgHover
        Center → Icon / child
```

### 13.3 AuroraBackground -- 极光动画背景

**文件:** `lib/ui/shared/aurora_background.dart` (~250行)

3个发光 blob 沿 Lissajous 曲线漂移的动画背景。灵感来自 Apple iOS 锁屏和 Spotify 渐变背景。

**架构:**
```
Positioned.fill
  RepaintBoundary
    AnimatedBuilder (listening to _repaint)
      CustomPaint (painter: _AuroraPainter)
```

**关键设计:**
- 使用原始 `Ticker` (非 AnimationController) 最大化性能
- 3个 blob 位置通过 Lissajous 参数方程计算，使用素数频率比避免同步
- Blob 预渲染为 256x256 `ui.Image` (径向渐变)，通过 `drawImage` + translate/scale 绘制
- `WidgetsBindingObserver` 在窗口失焦时暂停 ticker
- 引擎状态非 idle 时暂停 ticker (视频播放中背景被遮挡)
- 默认 blob 颜色: `#3B82F6` (蓝), `#1130A3` (深蓝), `#5578DC` (浅蓝)，透明度 0.08/0.06/0.05

### 13.4 EmptyState -- 空状态品牌页

**文件:** `lib/ui/shared/empty_state.dart` (~200行)

无媒体加载时显示的品牌登录页 (idle状态)。

```
Stack
  AuroraBackground (layer 0)
  Align (center, offset 0.1)
    Column
      _buildBranding (品牌名文本)
      Cross-fade animation:
        GlassButton ("Open File") -- 拖拽悬停时淡出
        Drag hint text -- 拖拽悬停时淡入
```

- 拖拽悬停时 "Open File" 按钮和拖拽提示文本交叉淡入淡出
- `GlassButton` 使用 `respectResizeState: true` 跳过调整大小期间的 `BackdropFilter`

### 13.5 AppDialog -- 统一对话框壳

**文件:** `lib/ui/shared/app_dialog.dart` (~70行)

统一的对话框包装器，提供一致的毛玻璃样式。

- 响应式尺寸: 宽度钳位到 `[200, maxWidth*0.9]`，高度到 `[150, maxHeight*0.85]`
- 始终包含本地化 "Close" 按钮
- 支持额外 `actions` 列表

---

## 14. Theme System (主题系统)

### 14.1 Design Tokens (设计令牌)

**文件:** `lib/kernel/ui/theme/tokens.dart` (~100行)

所有视觉常量的单一真相来源。所有UI组件引用这些编译时常量，无硬编码魔法数字。

#### 背景

| 令牌 | 值 | 用途 |
|------|-----|------|
| `bgBase` | `#0A0A0F` | Scaffold背景 |
| `bgPanel` | `#1A1A24` | 播放列表面板、侧边栏 |
| `bgElevated` | `#242432` | 对话框、提升表面 |
| `bgGlass` | `#801A1A24` | 毛玻璃容器填充 (50% alpha) |
| `bgHover` | `#2A2A3A` | 悬停状态背景 |
| `borderHighlight` | `#33FFFFFF` | 20%白色边框 |

#### 强调色

| 令牌 | 值 |
|------|-----|
| `accent` | `#2C58F4` (蓝) |
| `accentLight` | 更亮变体 |

#### 文本 (Apple iOS 4级透明度)

| 令牌 | 透明度 | 用途 |
|------|--------|------|
| `textPrimary` | 85% | 标题、活跃元素 |
| `textSecondary` | 60% | 正文、说明 |
| `textTertiary` | 38% | 禁用提示 |
| `textDisabled` | 固定 | 真正禁用元素 |

#### 间距 (dp)

`spXs`(4), `spSm`(8), `spMd`(12), `spLg`(16), `spXl`(24)

#### 圆角

`radiusBtn`(4), `radiusPopup`(8), `radiusSm`(6), `radiusMd`(10), `radiusLarge`(12)

#### 字体大小

`fontTitle`(18), `fontBody`(14), `fontCaption`(12), `fontOverline`(10), `fontBranding`(18)

#### 图标大小

`iconSm`(16), `iconMd`(18), `iconLg`(20), `iconXl`(28)

#### 毛玻璃模糊度

`glassBlurThin`(12), `glassBlur`(16), `glassBlurThick`(24)

#### 动画时长 (ms)

`durationFast`(80), `durationNormal`(150), `durationFade`(300), `durationSlide`(300)

#### 布局

`controlBarMarginH`, `controlBarMarginBottom`, `playlistPanelWidth`, `titleBarHeight`, `titleBarButtonWidth`

#### 字体特性

`tabularFigures` = `FontFeature.tabularFigures()` 用于时间显示的等宽数字

### 14.2 AppTheme -- ThemeData 桥接

**文件:** `lib/kernel/ui/theme/app_theme.dart` (~40行)

将 `Tokens` 桥接到 Flutter 的 `ThemeData` 用于 Material 组件。

```dart
class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Tokens.bgBase,
    colorScheme: ColorScheme.dark(
      primary: Tokens.accent,
      secondary: Tokens.accentLight,
      surface: Tokens.bgElevated,
      error: Tokens.danger,
    ),
    // ...
  );
}
```

**设计决策:** 应用使用单一暗色主题 ("Midnight")。不支持亮色主题。Material 组件从 ThemeData 获取颜色，自定义 widget 直接引用 Tokens。

---

## 15. Custom Title Bar (自定义标题栏)

**文件:** `lib/kernel/ui/window/custom_title_bar.dart` (~200行)

带毛玻璃、拖拽移动和窗口控制按钮的自定义窗口标题栏。

### Widget 树

```
GlassContainer (tier: thin, respectResizeState: true)
  GestureDetector (onPanStart → dragWindow)
    Row
      [左侧空白区域 -- 可拖拽]
      _TitleBarButton (Pin / 置顶)
      _TitleBarButton (Minimize)
      _TitleBarButton (Maximize / Restore)
      _TitleBarButton (Close)
```

**关键特性:**
- 高度: 36px (Win11标准32px + 4px触摸目标)
- 毛玻璃降级: 窗口调整大小期间跳过 `BackdropFilter`
- Pin按钮: `ValueListenableBuilder<bool>` 监听 `wm.isAlwaysOnTop`
- 关闭按钮: 悬停状态使用 `Tokens.danger` (红色) 背景

---

## 16. Widget-to-Service 绑定模式

### 模式 1: ValueListenableBuilder (主要模式)

```dart
ValueListenableBuilder<MediaState>(
  valueListenable: engine.state,
  builder: (_, state, _) => /* rebuild */,
)
```

### 模式 2: ValueListenableBuilder2 (自定义双监听)

```dart
ValueListenableBuilder2<bool, double>(
  first: engine.isMuted,
  second: engine.volume,
  builder: (_, muted, volume, _) => /* rebuild */,
)
```

### 模式 3: MergedListenable (合并监听)

```dart
_merged = MergedListenable(engine.position, engine.duration);
// 单个 ValueListenableBuilder 监听 _merged
```

### 模式 4: AnimatedBuilder + Listenable.merge

```dart
AnimatedBuilder(
  animation: Listenable.merge([engine.textureId, engine.aspectRatio]),
  builder: (_, _) => /* repaint */,
)
```

### 模式 5: 单例服务

`OsdService.I` 全局单例，任何widget可访问。

### 模式 6: 回调属性

父子通信使用类型化回调属性。

---

## 17. Animation & Transition Patterns (动画模式)

| 模式 | 位置 | 说明 |
|------|------|------|
| FadeTransition | ControlBar | Curves.easeOut, 300ms |
| Scale+Fade组合 | OSD | 0.95→1.0, 不对称时长 (150ms/300ms) |
| AnimatedOpacity | CenterGroup | 300ms, idle时38%透明度 |
| AnimatedSwitcher | PlaylistPanel | 隐式动画切换 |
| Ticker自定义绘制 | AuroraBackground | ~60fps, Lissajous曲线, 预渲染blob |
| 弹窗动画 | Volume popup | 300ms显示/200ms隐藏 |
| 拖拽交叉淡入 | EmptyState | 按钮↔提示文本 |
| RepaintBoundary | VideoSurface/Controls/Aurora | 重绘隔离 |
