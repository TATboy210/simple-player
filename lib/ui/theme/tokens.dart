import 'package:flutter/material.dart';

/// 设计令牌 — 编译时常量
class Tokens {
  Tokens._();

  static const bgDeep = Color(0xFF060810); // 最深背景 - 加深
  static const bgBase = Color(0xFF0C0F18); // 加深
  static const bgPanel = Color(0xFF111520); // 加深
  static const bgElevated = Color(0xFF161A28); // 加深
  static const bgHover = Color(0xFF283045); // hover 高亮 — 比 bgElevated 明显更亮
  static const bgGlass = Color(0x8C0C0F18); // 加深

  static const accent = Color.fromARGB(255, 44, 88, 244);
  static const accentLight = Color.fromARGB(180, 44, 87, 244);
  static const accentBlue = Color(0xFF4A8EFF); // 蓝色辉光（进度条/边框）
  static const accentEgg = Color.fromARGB(255, 102, 204, 255);
  static const danger = Color.fromARGB(255, 250, 55, 55);

  // ── 边缘微光 ──
  static const glowCore = Color(0xE6A0BEFF); // rgba(160,190,255,0.9)
  static const glowMid = Color(0x40648CFF); // rgba(100,140,255,0.25)
  static const glowEdge = Color(0x265078FF); // rgba(80,120,255,0.15)
  static const glowEdgeStrong = Color(0x596496FF); // rgba(100,150,255,0.35)

  // ── 边缘微光 — gradient 变体 box-shadow ──
  static const glowHighlightWhite = Color(0x08FFFFFF);
  static const glowBorderBlue = Color(0x0F5078FF);
  static const glowMidBlue = Color(0x0A5078FF);
  static const glowAmbientBlue = Color(0x053C64DC);
  static const glowOuterRing = Color(0x0A5082FF);
  static const glowAccent = Color(0x1F5082FF);

  // ── 边缘微光 — gradient 描边渐变 ──
  static const glowGradientStart = Color(0x2E64A0FF);
  static const glowGradientMid = Color(0x0064A0FF);
  static const glowGradientEnd = Color(0x145078FF);
  static const glowTransparent = Color(0x005082FF); // 全透明，用于渐变端点

  // ── 边缘微光 — omni 变体方向色 ──
  static const glowOmniRight = Color(0x1A5082FF);
  static const glowOmniDown = Color(0x0A3C64DC);
  static const glowOmniLeft = Color(0x1A7850DC);
  static const glowOmniUp = Color(0x0A5082FF);

  // ── 极光背景 ──
  /// 极光光团色 — 三层蓝色渐变（高→低 alpha）
  static const auroraBlue1 = Color(0x1A4A8EFF);
  static const auroraBlue2 = Color(0x144A8EFF);
  static const auroraBlue3 = Color(0x0F4A8EFF);

  /// 噪点叠加色 — 低 alpha 白色，模拟胶片颗粒
  static const noiseOverlay = Color(0x0AFFFFFF);

  /// 紫色透射光斑 — 中心光效默认色
  static const glowPurple = Color(0x1AA855F7);

  // ── 控制栏装饰 ──
  static const controlBarBg = Color(0x990E111E);

  /// 10% 淡蓝辉光描边（playing 状态，替代白色微光 D-15/D-16）
  static const controlBarBorderWhite = Color(0x0A6496FF);

  /// 2% 淡蓝描边（idle 状态，比 playing 的 10% 更淡，per D-18）
  static const controlBarBorderIdle = Color(0x056496FF);
  static const controlBarShadowBlack = Color(0x1A000000);
  static const controlBarOuterShadow = Color(0x40000000);

  /// idle 状态下中心控件文字色 — 淡化版 textPrimary
  static const controlBarTextPrimaryIdle = Color(0x73FFFFFF);

  /// idle 状态下次要文字色
  static const controlBarTextSecondaryIdle = Color(0x38FFFFFF);

  /// idle 状态下控制栏背景
  static const controlBarBgIdle = Color(0x660E111E);

  /// idle 状态下玻璃边框
  static const glassBorderIdle = Color(0x0A6482FF);

  /// idle 状态下图标色
  static const controlBarIconIdle = Color(0x73FFFFFF);

  // ── 右键菜单 ──
  static const menuBg = Color(0xE61A1A2E);
  static const menuBorder = Color(0x22FFFFFF);
  static const menuTextMuted = Color(0x99FFFFFF);
  static const menuAccent = Color(0xFF2C58F4);
  static const menuTextNormal = Color(0xCCFFFFFF);

  static const textPrimary = Color(0xEBFFFFFF); // rgba(255,255,255,0.92)
  static const textSecondary = Color(0x73FFFFFF); // rgba(255,255,255,0.45)
  static const textTertiary = Color(0x38FFFFFF); // rgba(255,255,255,0.22)
  static const textDisabled = Color(0xFF444455);

  static const borderHighlight = Color(0x33FFFFFF);
  static const glassBorder = Color(0x146482FF); // rgba(100,130,255,0.08)

  // ── 字体 ──
  static const fontFamily = 'SF Pro Display'; // 主字体（Windows 回退 Segoe UI）
  static const fontFamilyMono = 'SF Mono'; // 等宽字体
  static const fontTitle = 18.0;
  static const fontBody = 14.0;
  static const fontCaption = 12.0;
  static const fontOverline = 10.0;
  static const fontBranding = 18.0;

  static const weightExtraLight = FontWeight.w200;
  static const weightLight = FontWeight.w300;
  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemiBold = FontWeight.w600;

  static const iconSm = 16.0;
  static const iconMd = 18.0;
  static const iconLg = 20.0;
  static const iconXl = 28.0;

  /// 手指/鼠标点击的抖动容差，小于此距离视为点击而非拖拽
  static const double tapJitterThreshold = 18.0;

  static const spXs = 4.0;
  static const spSm = 8.0;

  /// 进度条与右侧时间读数的固定间距，保留 seek 热区的视觉边界。
  static const controlBarTimeGap = spSm;
  static const spMd = 12.0;
  static const spLg = 16.0;
  static const spXl = 24.0;

  static const radiusSm = 8.0; // 按钮、speed 标签
  static const radiusMd = 14.0; // 色板方块、透射卡片图标
  static const radiusLg = 22.0; // 卡片、控制栏、hover 区域
  static const radiusXl = 32.0; // 外框容器
  static const radiusBtn = 4.0;
  static const radiusLarge = 12.0; // 保留兼容
  static const radiusPopup = 8.0;

  // ── 毛玻璃 ──
  static const glassBlurThin = 8.0;
  static const glassBlur = 11.5;
  static const glassBlurThick = 24.0;

  // ── 动画 ──
  static const durationFast = 80;
  static const durationNormal = 150;
  static const durationFade = 400;
  // auto-hide 控件淡入淡出专用 — 对齐 media_kit 原生 150ms(独立于
  // durationFade=400,后者驱动 center_controls 中心播放/暂停图标,隔离影响)
  static const durationControlsFade = 150;
  static const durationSlide = 300;
  static const durationDebounce = 500;
  static const durationWindowResize = 100;

  // ── 自动隐藏 ──
  // 窗口/全屏统一 3s — 对齐 media_kit 原生隐藏延迟(原 windowed=5s 偏长)
  static const hideDelayWindowed = 3;
  static const hideDelayFullscreen = 3;

  /// 鼠标距底部多少 px 内触发控制栏显示
  /// controlBarHeight(110) + controlBarMarginBottom(16) + 24px buffer = 150
  static const bottomTriggerZoneHeight = 150.0;

  // ── 全屏动画 ──
  static const durationFullscreenAnim = 200;

  // ── 标题栏 ──
  static const titleBarHeight = 32.0;
  static const titleBarButtonWidth = 36.0;
  static const titleBarBg = Color(0xE61A1A24);
  static const titleBarBorder = Color(0x33FFFFFF);
  static const titleBarHover = Color(0x1AFFFFFF);
  static const titleBarPressed = Color(0x33FFFFFF);
  static const closeHoverBg = Color(0xFFC42B1C);
  static const closePressedBg = Color(0xFFB01C14);

  // ── 控制栏 ──
  static const controlBarHeight = 110.0;

  /// 控制栏在窄窗口中的高度；为标题、时间轴和核心动作保留独立命中区。
  static const controlBarHeightMinimal = 100.0;
  static const controlBarTitleHeightMinimal = 16.0;
  static const controlBarActionsHeightMinimal = 44.0;

  /// 低于该宽度仅保留核心播放控制，避免动作组发生横向溢出。
  static const controlBarMinimalBreakpoint = 600.0;
  static const controlBarRadius = 22.0; // 修正为 22px（与设计稿一致）
  static const controlBarMarginH = 18.0;
  static const controlBarMarginBottom = 16.0;
  static const controlBarBorder = Color(0x146482FF); // rgba(100,130,255,0.08)

  // ── 缩略图 ──
  /// 缩略图播放中叠加层 — 半透明黑色标识当前播放项
  static const thumbnailOverlay = Color(0x66000000);

  /// 缩略图迷你进度条背景轨道
  static const progressBarBg = Color(0x33FFFFFF);

  // ── 进度条 ──
  static const progressBarRadius = 2.0;
  static const progressBarHeight = 31.0;
  static const progressBarThickness = 3.0;
  static const progressBarThicknessDrag = 5.0;
  static const progressThumbRadius = 7.0;
  static const progressPlayed = Color(0xFFFFFFFF); // 白色（与设计稿一致）
  static const Color progressThumb = Color(0xFFFFFFFF);
  static const int progressSeekThrottleMs = 150;

  /// 修 C (事件驱动 v2): position 到达 seek 目标的容差 — 容差内视为 seek 完成, 清 drag.
  /// 比 v1 固定 300ms 定时器更贴近 media_kit_control_bar 原生内部协调, 网络流/慢 seek 不回跳.
  static const int progressSeekArriveToleranceMs = 500;

  /// 修 C (事件驱动 v2): seek 超时兜底 — position 一直未到达 (seek 失败/极慢) 时强制清 drag,
  /// 避免进度条永久卡在 drag 位置. 兜底大于典型 seek 完成时间.
  static const int progressSeekHoldTimeoutMs = 2000;

  /// 渐变条高度
  static const double gradientStripHeight = 3.0;
  static const int progressExpandDurationMs = 200;
  static const double progressDragThreshold = 5.0;
  static const double progressDisabledBgAlpha = 0.3;
  static const double progressDisabledPlayedAlpha = 0.3;

  // ── 缩放 ──
  static const hoverScale = 1.02;
  static const pressScale = 0.98;

  // ── 字体特性 ──
  static const tabularFigures = FontFeature.tabularFigures();

  // ── OSD ──
  static const double osdIconSize = 22;
  static const int osdFadeDurationMs = 200;
  static const int osdDefaultHoldMs = 1200;

  /// OSD 迷你进度条背景轨道色
  static const Color osdTrackColor = Color(0x33FFFFFF);

  // ── 对话框 ──
  /// 占位/空态对话框的居中大图标尺寸（如设置壳）
  static const double dialogEmptyIconSize = 40;

  // ── 滑块 ──
  static const double sliderHeight = 42;
  static const double sliderLabelWidth = 64;
  static const double sliderValueWidth = 36;

  // ── 错误卡片（Phase 3）──
  /// 折叠视图 message 文本的最大宽度 —— 长诊断文本省略号截断，
  /// 不横向撑爆左上角卡片。
  static const double errorCardMaxWidth = 320.0;

  // ── 按钮尺寸 ──
  static const double iconButtonSizeLarge = 48;
  static const double iconButtonSizeSmall = 24;
  static const double iconButtonRadius = 24;
  static const double iconButtonPaddingH = 20;
  static const double iconButtonPaddingV = 12;

  // ── 播放列表 ──
  static const double playlistPanelWidth = 420;
  static const double playlistPanelWidthNarrow = 320;
  static const double playlistPanelHeight = 240;
  static const double playlistPanelHeightNarrow = 180;
  static const double thumbnailTileHeight = 124;

  // ── 断点 ──
  static const double compactBreakpoint = 500;
  static const double breakpointUltraCompact = 360;
  static const double breakpointWide = 1200;

  // ── 设置面板 chrome ──
  /// 设置面板的半透明背景遮罩。
  static const Color settingsOverlayMask = Colors.black54;

  /// 设置面板标题栏高度。
  static const double settingsTitleBarHeight = 44.0;

  /// 紧凑布局的设置 tab 条高度。
  static const double tabStripHeightCompact = 56.0;

  /// 常规布局的设置 tab 条高度。
  static const double tabStripHeightNormal = 64.0;

  // ── 控制栏局部布局 ──
  /// 控制栏内容与底部边缘之间的留白。
  static const double controlBarContentBottomPadding = 6.0;

  /// 控制栏顶部装饰渐变条的高度。
  static const double controlBarGradientHeight = 1.0;

  /// 控制栏按钮行的水平留白。
  static const double controlBarButtonRowPadding = 4.0;

  // ── 响应式设置面板（D-04：严格 16:9 几何）──
  /// 设置面板 tab bar 切换 normal/compact 的窗口宽度断点（>=800 normal, <800 compact）
  /// 注意：仅驱动 tab-compact 呈现，不参与 sizing 公式（D-04：sizing 无断点分支）
  static const double breakpointResponsive = 800.0;

  /// 面板最小宽度（clamp 下限）
  static const double panelMinWidth = 400.0;

  /// 面板最大宽度（clamp 上限，D-04：16:9 几何上限 960）
  static const double panelMaxWidth = 960.0;

  /// 面板宽度占窗口宽度比例（D-04：0.5，width=min(0.5×W, H×16/9)）
  static const double panelWidthRatio = 0.5;

  /// 面板宽高比（D-04：16:9，height = width / panelAspectRatio）
  static const double panelAspectRatio = 16.0 / 9.0;

  /// normal 模式 tab 字体大小
  static const double tabBarFontNormal = 14.0;

  /// compact 模式 tab 字体大小
  static const double tabBarFontCompact = 12.0;

  /// normal 模式 tab 内容间距
  static const double tabBarSpacingNormal = 16.0;

  /// compact 模式 tab 内容间距
  static const double tabBarSpacingCompact = 8.0;

  // ── 响应式设置面板结构色路由（D-02 / LAYOUT-05）──
  /// 设置面板四段（标题栏 / tab 条 / 内容区 / 按钮栏）结构背景统一路由。
  /// Phase 30 保留 bgGlass 值；Phase 31 chrome 对齐时单点改此别名即可，不动四消费者。
  static const Color panelSectionBg = bgGlass;

  // ── 跳秒（毫秒）──
  // P0' 修复:原 skipSecondsShort/Long(秒命名 + 值 10/30)误传引擎 ms 接口,
  // 实际只跳 10ms/30ms。改名 skipShortMs/skipLongMs + 值改 10000/30000,
  // 与 EngineConstants.defaultSkipMs 的毫秒语义对齐,消除 UI/引擎单位错配。
  static const int skipShortMs = 10000;
  static const int skipLongMs = 30000;

  // ── 字体补充 ──
  static const double fontSizeSmall = 9.0;

  // ── Tooltip 延迟 ──
  static const int tooltipDelayShort = 400;
  static const int tooltipDelayLong = 600;

  // ── 音量/倍速控件 ──
  static const double volumeSliderWidth = 100;

  /// VolumeSlider 拖拽节流间隔（≤10 次/秒）
  static const int volumeThrottleMs = 100;
  static const double speedButtonWidth = 72;
  static const double speedButtonHeight = 36;
  static const double speedSegmentWidth = 36;
  static const double speedArrowWidth = 18;

  // ── Phase 32 输入模式检测 (NAV-02/NAV-06) ──
  /// InputModeDetector 启发式空闲阈值（秒）—— 鼠标空闲超过此值且出现方向键时
  /// 推断为 gamepad (D-06：无硬编码，InputModeDetector 生产默认读此令牌)。
  static const int inputModeIdleTimeoutSec = 5;

  /// 方向辉光显示窗口（毫秒）—— setArrowGlow 后到此时长自动回 null (NAV-06)，
  /// 复用 osdDefaultHoldMs=1200 的瞬态显示先例。
  static const int arrowGlowDuration = 1200;

  // ── Phase 32 端帽箭头 + 输入提示 (NAV-01/NAV-03) ──
  /// 端帽箭头圆角 —— 复用 [radiusBtn] 按钮尺度（GlassButton 先例），端帽为
  /// 按钮级可交互元素，4px 圆角在零圆角 tab 条内作微妙区分 (NAV-01)。
  static const double tabArrowRadius = radiusBtn;

  /// 端帽箭头固定宽 —— 匹配 GlassButton.iconOnly 的 36px 点击靶，留给 7 个
  /// Expanded tab 足够空间（面板最小宽 400 - 2×36 = 328px / 7 ≈ 47px/项）。
  static const double tabArrowWidth = 36.0;

  /// 输入提示淡入淡出时长（毫秒）—— AnimatedSwitcher 交叉淡入键盘↔手柄标签，
  /// 复用 [durationSlide] 的瞬态切换先例 (NAV-03)。
  static const int hintFadeDuration = durationSlide;
}
