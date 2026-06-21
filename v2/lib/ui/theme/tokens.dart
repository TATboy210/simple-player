import 'dart:ui';

/// 设计常量 — 编译时静态值，全局统一引用
abstract final class Tokens {
  // ─── Title bar ───
  static const double titleBarHeight = 32.0;
  static const double titleBarButtonWidth = 36.0;
  static const Color titleBarHover = Color(0x19FFFFFF); // white 10%
  static const Color titleBarPressed = Color(0x33FFFFFF); // white 20%
  static const Color closeHoverBg = Color(0xFFE81123); // Windows red
  static const Color closePressedBg = Color(0xFFFF6B6B);
  static const int durationFullscreenAnim = 300;

  // ─── Typography ───
  static const double fontCaption = 12.0;
  static const FontWeight weightMedium = FontWeight.w500;

  // ─── Colors ───
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // white 70%
  static const Color accent = Color(0xFF4FC3F7);

  // ─── Spacing ───
  static const double spMd = 12.0;

  // ─── Radius ───
  static const double radiusS = 6.0;
  static const double radiusM = 12.0;
  static const double radiusCard = 12.0;

  // ─── Icons ───
  static const double iconSm = 16.0;

  // ─── Typography extra ───
  static const double fontBody = 14.0;

  // ─── Control bar ───
  static const double controlBarHeight = 84.0;
  static const double controlBarMarginBottom = 16.0;
  static const double controlBarMarginH = 18.0;
  static const double progressBarHeight = 36.0;
  static const int durationFade = 300; // ms
  static const int hideDelayFullscreen = 3; // seconds
  static const int hideDelayWindowed = 5; // seconds

  // ─── OSD ───
  static const int osdDefaultHoldMs = 1200;
  static const int osdFadeDurationMs = 200;
  static const double osdIconSize = 22.0;
  static const double fontTitle = 24.0;
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontFeature tabularFigures = FontFeature.tabularFigures();

  // ─── Control buttons ───
  static const double controlButtonSize = 36.0;
  static const double controlIconSize = 20.0;
  static const Color controlBg = Color(0xCC000000); // black 80%
  static const Color controlHover = Color(0x33FFFFFF); // white 20%
}
