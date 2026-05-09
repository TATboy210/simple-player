import 'package:flutter/material.dart';

/// 设计令牌 — 编译时常量
class Tokens {
  Tokens._();

  static const bgBase = Color(0xFF0A0A0F);
  static const bgPanel = Color(0xFF1A1A24);
  static const bgElevated = Color(0xFF242432);
  static const bgHover = Color(0xFF2A2A3A);
  static const bgGlass = Color(0x801A1A24);

  static const accent = Color(0xFF6C5CE7);
  static const accentLight = Color(0xFFA29BFE);
  static const danger = Color(0xFFFF6B6B);

  static const textPrimary = Color(0xFFE8E8F0);
  static const textSecondary = Color(0xFF9999AA);
  static const textTertiary = Color(0xFF666677);

  static const borderHighlight = Color(0x33FFFFFF);

  static const fontTitle = 18.0;
  static const fontBody = 14.0;
  static const fontCaption = 12.0;
  static const fontOverline = 10.0;

  static const iconSm = 16.0;
  static const iconMd = 20.0;

  static const spXs = 4.0;
  static const spSm = 8.0;
  static const spMd = 12.0;
  static const spLg = 16.0;
  static const spXl = 24.0;

  static const radiusSm = 6.0;
  static const radiusMd = 10.0;
  static const radiusBtn = 8.0;

  // ── 毛玻璃 ──
  static const glassBlurThin = 12.0;
  static const glassBlur = 16.0;
  static const glassBlurThick = 24.0;

  // ── 动画 ──
  static const durationFast = 80;
  static const durationNormal = 150;
  static const durationDebounce = 500;

  // ── 图标 ──
  static const iconLg = 20.0;

  // ── 标题栏 ──
  static const titleBarHeight = 36.0;
  static const titleBarButtonWidth = 36.0; // D-04: 36x36px
  static const titleBarBg = Color(0xE61A1A24); // 90% opacity bgPanel
  static const titleBarBorder = Color(0x33FFFFFF); // reuse borderHighlight
  static const titleBarHover = Color(0x1AFFFFFF); // 10% white overlay
  static const closeHoverBg = Color(0xFFC42B1C); // Win11 close red fallback
}
