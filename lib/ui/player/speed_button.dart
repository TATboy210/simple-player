import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../widgets/osd_overlay.dart';

/// 三段式倍速控件 — 72×36
///
/// 左箭头(18) + 中间数字(36) + 右箭头(18)
/// - 点击箭头 ±0.25
/// - 双击数字重置 1.0
/// - 滚轮 ±0.25
class SpeedButton extends StatelessWidget {
  final MediaEngine engine;

  static const _step = 0.25;
  static const _normal = 1.0;

  const SpeedButton({super.key, required this.engine});

  void _adjust(double delta) {
    final v = (engine.playbackSpeed.value + delta).clamp(0.25, 4.0);
    engine.setPlaybackRate(v);
    OsdService.I.show('${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}x');
  }

  void _reset() {
    engine.setPlaybackRate(_normal);
    OsdService.I.show('1x');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 36,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _adjust(event.scrollDelta.dy > 0 ? -_step : _step);
          }
        },
        child: ValueListenableBuilder<double>(
          valueListenable: engine.playbackSpeed,
          builder: (_, speed, _) {
            final label = speed == speed.roundToDouble()
                ? speed.toStringAsFixed(0)
                : speed.toStringAsFixed(2);
            return Row(
              children: [
                _Segment(
                  width: 18,
                  icon: Icons.chevron_left,
                  onTap: () => _adjust(-_step),
                ),
                _Segment(width: 36, label: '${label}x', onDoubleTap: _reset),
                _Segment(
                  width: 18,
                  icon: Icons.chevron_right,
                  onTap: () => _adjust(_step),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final double width;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const _Segment({
    required this.width,
    this.icon,
    this.label,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Icon(icon, size: 18, color: Tokens.textPrimary)
        : Text(
            label ?? '',
            style: TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontCaption,
              fontWeight: Tokens.weightMedium,
              fontFeatures: [Tokens.tabularFigures],
            ),
          );

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: SizedBox(
        width: width,
        height: 36,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          child: InkWell(
            onTap: onTap,
            hoverColor: Tokens.bgHover,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
            splashFactory: InkRipple.splashFactory,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
