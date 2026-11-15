import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// 边缘微光容器 — 渐变描边 + 5 层 box-shadow 发光.
///
/// 设计语言中的微光效果；生产仅控制栏使用。历史上的 pulse/omni 变体、
/// resize 降级与强度参数均无调用方，已移除（pulse 携带永不停止的
/// AnimationController.repeat() 每帧动画，留着是误用陷阱）。
class EdgeGlow extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  const EdgeGlow({super.key, required this.child, this.borderRadius});

  /// 5 层发光阴影 — 常量，避免每次 build 重新分配。
  static const List<BoxShadow> _glowShadows = [
    BoxShadow(color: Tokens.glowHighlightWhite, offset: Offset(0, 1)),
    BoxShadow(color: Tokens.glowBorderBlue, spreadRadius: 1),
    BoxShadow(color: Tokens.glowMidBlue, blurRadius: 20),
    BoxShadow(color: Tokens.glowAmbientBlue, blurRadius: 50),
    BoxShadow(color: Tokens.glowOuterRing, blurRadius: 1, spreadRadius: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(Tokens.radiusLg);
    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: _glowShadows),
      child: CustomPaint(
        painter: _GradientBorderPainter(borderRadius: radius),
        child: child,
      ),
    );
  }
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
