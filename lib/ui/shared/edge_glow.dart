import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 边缘微光容器 — 渐变描边 + 5 层 box-shadow 发光.
///
/// 设计语言中的微光效果（原 pulse/omni 变体为死代码，已于 2026-09-08
/// 移除 —— pulse 携带永不停止的 AnimationController.repeat() 每帧动画，
/// 留在代码库中是误用陷阱）。
class EdgeGlow extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final bool enabled;
  final double? glowIntensity;

  /// Resize 期间跳过模糊阴影，避免与视频纹理合成争用 raster 线程。
  final ValueListenable<bool>? resizing;

  const EdgeGlow({
    super.key,
    required this.child,
    this.borderRadius,
    this.enabled = true,
    this.glowIntensity,
    this.resizing,
  });

  @override
  State<EdgeGlow> createState() => _EdgeGlowState();
}

class _EdgeGlowState extends State<EdgeGlow> {
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final resizing = widget.resizing;
    // ValueListenable 不会自动触发父组件重建；监听它可让 resize 降级阴影
    // 在窗口状态变化的同一帧生效，而无需依赖无关的父级 build。
    if (resizing != null) {
      return AnimatedBuilder(
        animation: resizing,
        builder: (_, child) => _buildGradientGlow(),
      );
    }
    return _buildGradientGlow();
  }

  /// 渐变描边 + 5 层 box-shadow
  Widget _buildGradientGlow() {
    final intensity = widget.glowIntensity ?? 1.0;
    final isResizing = widget.resizing?.value ?? false;
    // Resize 时保留边框和子树 identity，只移除高成本的模糊阴影。
    final shadows = isResizing
        ? _buildResizeShadows(intensity)
        : _buildGlowShadows(intensity);
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
        boxShadow: shadows,
      ),
      child: CustomPaint(
        painter: _GradientBorderPainter(
          borderRadius:
              widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
        ),
        child: widget.child,
      ),
    );
  }

  List<BoxShadow> _buildGlowShadows(double intensity) => [
    BoxShadow(
      color: Tokens.glowHighlightWhite.withValues(
        alpha: Tokens.glowHighlightWhite.a * intensity,
      ),
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Tokens.glowBorderBlue.withValues(
        alpha: Tokens.glowBorderBlue.a * intensity,
      ),
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Tokens.glowMidBlue.withValues(
        alpha: Tokens.glowMidBlue.a * intensity,
      ),
      blurRadius: 20,
    ),
    BoxShadow(
      color: Tokens.glowAmbientBlue.withValues(
        alpha: Tokens.glowAmbientBlue.a * intensity,
      ),
      blurRadius: 50,
    ),
    BoxShadow(
      color: Tokens.glowOuterRing.withValues(
        alpha: Tokens.glowOuterRing.a * intensity,
      ),
      blurRadius: 1,
      spreadRadius: 1,
    ),
  ];

  /// Resize 时只保留无 blur 的边框，避免触发多层离屏模糊。
  List<BoxShadow> _buildResizeShadows(double intensity) => [
    BoxShadow(
      color: Tokens.glowBorderBlue.withValues(
        alpha: Tokens.glowBorderBlue.a * intensity,
      ),
      spreadRadius: 1,
    ),
  ];
}

/// 渐变描边画笔 — 模拟 mask-composite: exclude 效果
class _GradientBorderPainter extends CustomPainter {
  final BorderRadius borderRadius;

  _GradientBorderPainter({required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // 渐变描边 — 135° 角度，对角发光
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Tokens.glowGradientStart,
          Tokens.glowGradientMid,
          Tokens.glowGradientMid,
          Tokens.glowGradientEnd,
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius;
}
