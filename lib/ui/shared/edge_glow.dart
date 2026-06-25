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

  const EdgeGlow({
    super.key,
    required this.child,
    this.variant = EdgeGlowVariant.gradient,
    this.borderRadius,
    this.enabled = true,
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
        boxShadow: const [
          // 1. 顶部内高光
          BoxShadow(
            color: Color(0x08FFFFFF),
            blurRadius: 0,
            spreadRadius: 0,
            offset: Offset(0, 1),
          ),
          // 2. 实线描边
          BoxShadow(
            color: Color(0x0F5078FF),
            blurRadius: 0,
            spreadRadius: 1,
          ),
          // 3. 中层扩散
          BoxShadow(
            color: Color(0x0A5078FF),
            blurRadius: 20,
            spreadRadius: 0,
          ),
          // 4. 外层环境
          BoxShadow(
            color: Color(0x053C64DC),
            blurRadius: 50,
            spreadRadius: 0,
          ),
          // 5. 蓝色外环
          BoxShadow(
            color: Color(0x0A5082FF),
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
    if (_pulseController == null) return widget.child;

    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        final t = _pulseController!.value;
        // 正弦曲线：0 → 1 → 0
        final pulse = math.sin(t * math.pi);

        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(Tokens.radiusLg),
            boxShadow: [
              // 内层高光（脉冲）
              BoxShadow(
                color: Color(0x08FFFFFF).withValues(alpha: 0.03 + 0.05 * pulse),
                blurRadius: 0,
                spreadRadius: 0,
                offset: const Offset(0, 1),
              ),
              // 中层扩散（脉冲）
              BoxShadow(
                color: Color(0x0A5078FF).withValues(alpha: 0.03 + 0.05 * pulse),
                blurRadius: 20 + 10 * pulse,
                spreadRadius: 0,
              ),
              // 外层环境（仅脉冲高峰出现）
              if (pulse > 0.5)
                BoxShadow(
                  color: Color(0x083C64DC).withValues(alpha: 0.04 * (pulse - 0.5) * 2),
                  blurRadius: 60,
                  spreadRadius: 0,
                ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
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
          Color(0x2E64A0FF), // rgba(100,160,255,0.18)
          Color(0x0064A0FF), // transparent 30%
          Color(0x0064A0FF), // transparent 70%
          Color(0x145078FF), // rgba(80,120,255,0.08)
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
      (0.0, const Color(0x1A5082FF)),   // 右
      (0.25, const Color(0x0A3C64DC)),  // 下
      (0.5, const Color(0x1A7850DC)),   // 左
      (0.75, const Color(0x0A5082FF)),  // 上
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
