import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 悬停辉光效果 — 鼠标悬停时显示蓝色边框辉光
///
/// 包裹视频区域，hover 时边框渐显蓝色辉光（Tokens.glowEdge）。
class HoverGlow extends StatefulWidget {
  final Widget child;

  const HoverGlow({super.key, required this.child});

  @override
  State<HoverGlow> createState() => _HoverGlowState();
}

class _HoverGlowState extends State<HoverGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationNormal),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: CustomPaint(
        // 动画只改变边框绘制，不再每帧重建 DecoratedBox/BoxDecoration。
        painter: _HoverGlowPainter(
          repaint: _opacity,
          opacity: () => _opacity.value,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 绘制悬停边框的画笔。
///
/// [repaint] 让动画帧直接进入 paint 阶段，保持子树 Widget identity 不变。
class _HoverGlowPainter extends CustomPainter {
  _HoverGlowPainter({required this.repaint, required this.opacity})
    : super(repaint: repaint);

  final Listenable repaint;
  final double Function() opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final borderRadius = BorderRadius.circular(Tokens.radiusSm);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Tokens.glowEdge.withValues(
        alpha: Tokens.glowEdge.a * opacity(),
      );
    canvas.drawRRect(borderRadius.toRRect(Offset.zero & size), paint);
  }

  @override
  bool shouldRepaint(covariant _HoverGlowPainter oldDelegate) =>
      oldDelegate.repaint != repaint || oldDelegate.opacity != opacity;
}
