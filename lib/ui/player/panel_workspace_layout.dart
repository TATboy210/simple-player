import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// 纯布局过滤器 — 列表显隐不参与计算，确保中列位置稳定。
@immutable
class PanelWorkspaceLayout {
  const PanelWorkspaceLayout({required this.left, required this.center});

  final Rect left;
  final Rect center;

  /// 把可用视频区域变为左/中面板矩形。
  ///
  /// 右列槽位不再输出 Rect — 播放列表由 player_video_controls 静态定位
  /// (right: Tokens.controlBarMarginH), 宽度即 PlaylistPanel.panelWidth
  /// (= Tokens.workspaceTaskMinWidth); rightWidth 局部变量仍作中列推导上界。
  static PanelWorkspaceLayout calculate(Size size) {
    final margin = math.min(Tokens.controlBarMarginH, size.width / 2);
    final innerWidth = math.max(0.0, size.width - margin * 2);
    final gap = math.min(Tokens.spMd, innerWidth / 2);
    final width = math.max(0.0, innerWidth - gap * 2);
    final rightWidth = math.min(Tokens.workspaceTaskMinWidth, width);
    final remaining = width - rightWidth;
    // Preserve two equal 280 columns at the supported minimum; left yields first.
    final centerWidth = math.min(
      remaining,
      math.max(Tokens.workspaceTaskMinWidth, width * 2 / 3 - rightWidth),
    );
    final leftWidth = remaining - centerWidth;
    final top = math.min(Tokens.spMd, size.height);
    final bottom =
        Tokens.controlBarMarginBottom + Tokens.controlBarHeight + Tokens.spMd;
    final height = math.max(0.0, size.height - top - bottom);
    final centerX = margin + leftWidth + gap;
    return PanelWorkspaceLayout(
      left: Rect.fromLTWH(margin, top, leftWidth, height),
      center: Rect.fromLTWH(centerX, top, centerWidth, height),
    );
  }
}
