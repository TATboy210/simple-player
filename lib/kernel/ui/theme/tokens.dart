import 'package:flutter/material.dart';

/// 设计令牌 — 编译时常量
class Tokens {
  Tokens._();

  static const bgBase = Color(0xFF0A0A0F);
  static const bgPanel = Color(0xFF1A1A24);
  static const bgElevated = Color(0xFF242432);
  static const bgHover = Color(0xFF2A2A3A);
  static const bgGlass = Color(0x801A1A24);

  static const accent = Color.fromARGB(255, 44, 88, 244);
  static const accentLight = Color.fromARGB(180, 44, 87, 244);
  static const accentegg = Color.fromARGB(255, 102, 204, 255);
  static const danger = Color.fromARGB(255, 250, 55, 55);

  static const textPrimary = Color(0xFFE8E8F0);
  static const textSecondary = Color(0xFF9999AA);
  static const textTertiary = Color(0xFF666677);
  static const textDisabled = Color(0xFF444455);

  static const borderHighlight = Color(0x33FFFFFF);

  // ── 字体 ──
  static const fontFamily = 'Noto Sans SC';
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

  static const spXs = 4.0;
  static const spSm = 8.0;
  static const spMd = 12.0;
  static const spLg = 16.0;
  static const spXl = 24.0;

  static const radiusSm = 6.0;
  static const radiusMd = 10.0;
  static const radiusBtn = 4.0;
  static const radiusLarge = 12.0;
  static const radiusPopup = 8.0;

  // ── 毛玻璃 ──
  static const glassBlurThin = 12.0;
  static const glassBlur = 16.0;
  static const glassBlurThick = 24.0;

  // ── 动画 ──
  static const durationFast = 80;
  static const durationNormal = 150;
  static const durationFade = 300;
  static const durationSlide = 300;
  static const durationDebounce = 500;

  // ── 自动隐藏 ──
  static const hideDelayFullscreen = 3;
  static const hideDelayWindowed = 5;

  // ── 标题栏 ──
  static const titleBarHeight = 36.0;
  static const titleBarButtonWidth = 36.0;
  static const titleBarBg = Color(0xE61A1A24);
  static const titleBarBorder = Color(0x33FFFFFF);
  static const titleBarHover = Color(0x1AFFFFFF);
  static const closeHoverBg = Color(0xFFC42B1C);

  // ── 控制栏 ──
  static const controlBarHeight = 84.0;
  static const controlBarRadius = 16.0;
  static const controlBarMarginH = 18.0;
  static const controlBarMarginBottom = 16.0;
  static const controlBarBorder = Color(0x1AFFFFFF);

  // ── 进度条 ──
  static const progressBarHeight = 32.0;
  static const progressBarThickness = 3.0;
  static const progressBarThicknessDrag = 5.0;
  static const progressThumbRadius = 7.0;
  static const progressPlayed = Color(0xFF6C5CE7);
  static const progressBuffer = Color(0x44FFFFFF);

  // ── 播放列表面板 ──
  static const playlistPanelWidth = 300.0;

  // ── 缩放 ──
  static const hoverScale = 1.02;
  static const pressScale = 0.98;

  // ── 字体特性 ──
  static const tabularFigures = FontFeature.tabularFigures();
}
