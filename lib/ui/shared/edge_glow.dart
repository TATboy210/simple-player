import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 边缘微光变体
enum EdgeGlowVariant {
  /// 渐变描边 — 5 层 box-shadow + 对角发光
  gradient,

  /// 全向柔光 — 锥形渐变环绕
  omni,

  /// 脉冲呼吸 — 动态强度循环
  pulse,
}

/// 边缘微光容器 — 实现设计语言中的 3 种微光效果
///
/// 变体 A（gradient）：5 层 box-shadow + 渐变描边
/// 变体 B（omni）：conic-gradient 全向柔光
/// 变体 C（pulse）：脉冲呼吸动画
class EdgeGlow extends StatefulWidget {
  final Widget child;
  final EdgeGlowVariant variant;
  final BorderRadius? borderRadius;
  final bool enabled;
  final double? glowIntensity;

  const EdgeGlow({
    super.key,
    required this.child,
    this.variant = EdgeGlowVariant.gradient,
    this.borderRadius,
    this.enabled = true,
    this.glowIntensity,
  });

  @override
  State<EdgeGlow> createState() => _EdgeGlowState();
}

class _EdgeGlowState extends State<EdgeGlow>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.variant == EdgeGlowVariant.pulse) {
      _initPulseAnimation();
    }
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(EdgeGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.variant == EdgeGlowVariant.pulse &&
        oldWidget.variant != EdgeGlowVariant.pulse) {
      _initPulseAnimation();
    } else if (widget.variant != EdgeGlowVariant.pulse &&
        oldWidget.variant == EdgeGlowVariant.pulse) {
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return switch (widget.variant) {
      EdgeGlowVariant.gradient => _buildGradientGlow(),
      EdgeGlowVariant.omni => _buildOmniGlow(),
      EdgeGlowVariant.pulse => _buildPulseGlow(),
    };
  }

  /// 变体 A — 渐变描边（5 层 box-shadow）
  Widget _buildGradientGlow() {
    final intensity = widget.glowIntensity ?? 1.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
        boxShadow: [
          // 1. 顶部内高光
          BoxShadow(
            color: Tokens.glowHighlightWhite.withValues(alpha: Tokens.glowHighlightWhite.a * intensity),
            blurRadius: 0,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
          // 2. 实线描边
          BoxShadow(
            color: Tokens.glowBorderBlue.withValues(alpha: Tokens.glowBorderBlue.a * intensity),
            blurRadius: 0,
            spreadRadius: 1,
          ),
          // 3. 中层扩散
          BoxShadow(
            color: Tokens.glowMidBlue.withValues(alpha: Tokens.glowMidBlue.a * intensity),
            blurRadius: 20,
            spreadRadius: 0,
          ),
          // 4. 外层环境
          BoxShadow(
            color: Tokens.glowAmbientBlue.withValues(alpha: Tokens.glowAmbientBlue.a * intensity),
            blurRadius: 50,
            spreadRadius: 0,
          ),
          // 5. 蓝色外环
          BoxShadow(
            color: Tokens.glowOuterRing.withValues(alpha: Tokens.glowOuterRing.a * intensity),
            blurRadius: 1,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _GradientBorderPainter(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
        ),
        child: widget.child,
      ),
    );
  }

  /// 变体 B — 全向柔光（conic-gradient）
  Widget _buildOmniGlow() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
      ),
      child: CustomPaint(
        painter: _OmniGlowPainter(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
        ),
        child: widget.child,
      ),
    );
  }

  /// 变体 C — 脉冲呼吸
  Widget _buildPulseGlow() {
    final pulseController = _pulseController;
    if (pulseController == null) return widget.child;

    return CustomPaint(
      // 脉冲只改变辉光绘制参数，避免每帧创建 Container、Decoration 和阴影列表。
      painter: _PulseGlowPainter(
        repaint: pulseController,
        pulse: () => pulseController.value,
        intensity: () => widget.glowIntensity ?? 1.0,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
      ),
      child: widget.child,
    );
  }
}

/// 脉冲辉光画笔。
///
/// 动画帧通过 [CustomPainter.repaint] 直接进入 paint 阶段，子树只在参数
/// 或内容变化时重建；绘制顺序与原 BoxShadow 列表保持一致。
class _PulseGlowPainter extends CustomPainter {
  _PulseGlowPainter({
    required this.repaint,
    required this.pulse,
    required this.intensity,
    required this.borderRadius,
  }) : super(repaint: repaint);

  final Listenable repaint;
  final double Function() pulse;
  final double Function() intensity;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final t = pulse();
    final value = math.sin(t * math.pi);
    final factor = intensity();
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // 先绘制内层高光，再绘制中层与外层扩散，保持原阴影的叠加顺序。
    _drawGlow(
      canvas,
      rrect,
      color: Tokens.glowHighlightWhite.withValues(
        alpha: (0.03 + 0.05 * value) * factor,
      ),
      blurRadius: 0,
      offset: const Offset(0, 1),
    );
    _drawGlow(
      canvas,
      rrect,
      color: Tokens.glowMidBlue.withValues(
        alpha: (0.03 + 0.05 * value) * factor,
      ),
      blurRadius: 20 + 10 * value,
    );
    if (value > 0.5) {
      _drawGlow(
        canvas,
        rrect,
        color: Tokens.glowAmbientBlue.withValues(
          alpha: 0.04 * (value - 0.5) * 2 * factor,
        ),
        blurRadius: 60,
      );
    }
  }

  void _drawGlow(
    Canvas canvas,
    RRect rrect, {
    required Color color,
    required double blurRadius,
    Offset offset = Offset.zero,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = blurRadius == 0
          ? null
          : MaskFilter.blur(BlurStyle.normal, blurRadius);
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PulseGlowPainter oldDelegate) =>
      oldDelegate.repaint != repaint ||
      oldDelegate.pulse != pulse ||
      oldDelegate.intensity != intensity ||
      oldDelegate.borderRadius != borderRadius;
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

/// 全向柔光画笔 — conic-gradient 模拟
class _OmniGlowPainter extends CustomPainter {
  final BorderRadius borderRadius;

  _OmniGlowPainter({required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final center = rect.center;

    // conic-gradient 效果 — 使用多个径向渐变模拟
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // 4 个方向的渐变
    final directions = [
      (0.0, Tokens.glowOmniRight),
      (0.25, Tokens.glowOmniDown),
      (0.5, Tokens.glowOmniLeft),
      (0.75, Tokens.glowOmniUp),
    ];

    for (final (angle, color) in directions) {
      final rad = angle * 2 * math.pi;
      final end = Offset(
        center.dx + math.cos(rad) * size.width / 2,
        center.dy + math.sin(rad) * size.height / 2,
      );

      paint.shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment(end.dx / size.width * 2 - 1, end.dy / size.height * 2 - 1),
        colors: [color, Colors.transparent],
      ).createShader(rect);

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(_OmniGlowPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius;
}
