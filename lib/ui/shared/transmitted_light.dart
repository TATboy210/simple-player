import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 透射光效类型
enum TransmissionType {
  /// 底部透射 — 光从下方渗出
  bottom,

  /// 中心透射 — 光从中心扩散
  center,
}

/// 透射光效 — 模拟光从界面下方/背后渗出的效果
///
/// 底部透射：椭圆形光斑从底部向上扩散
/// 中心透射：圆形光斑从中心向外扩散
class TransmittedLight extends StatelessWidget {
  final Widget child;
  final TransmissionType type;
  final Color? color;
  final double intensity;

  const TransmittedLight({
    super.key,
    required this.child,
    this.type = TransmissionType.bottom,
    this.color,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 透射光效层
        Positioned.fill(
          child: IgnorePointer(
            child: switch (type) {
              TransmissionType.bottom => _buildBottomTransmission(),
              TransmissionType.center => _buildCenterTransmission(),
            },
          ),
        ),
        // 内容层
        Positioned.fill(child: child),
      ],
    );
  }

  /// 底部透射 — 椭圆形光斑
  Widget _buildBottomTransmission() {
    final glowColor = color ?? Tokens.accentBlue;

    return Transform.translate(
      offset: const Offset(0, 40),
      child: OverflowBox(
        maxHeight: 200,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 0.3),
              radius: 0.7,
              colors: [
                glowColor.withValues(alpha: 0.15 * intensity),
                glowColor.withValues(alpha: 0.03 * intensity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// 中心透射 — 圆形光斑
  Widget _buildCenterTransmission() {
    final glowColor = color ?? Tokens.glowPurple;

    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              glowColor.withValues(alpha: 0.12 * intensity),
              glowColor.withValues(alpha: 0.04 * intensity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
