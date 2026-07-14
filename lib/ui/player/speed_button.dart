import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/osd_overlay.dart';

/// 三段式倍速控件 — 72×36
///
/// 左箭头(18) + 中间数字(36) + 右箭头(18)
/// - 点击箭头切换挡位
/// - 双击数字重置 1.0
/// - 滚轮切换挡位
class SpeedButton extends StatelessWidget {
  final MediaEngine engine;

  static const _gears = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];
  static const _normal = 1.0;

  const SpeedButton({super.key, required this.engine});

  void _shift(int direction) {
    final current = engine.playbackSpeed.value;
    // 找到第一个 >= 当前值的挡位（非标准值自动 snap 到最近的较高挡位）
    var idx = _gears.indexWhere((g) => g >= current);
    if (idx < 0) idx = _gears.length - 1; // 超出最大挡位，锁定最后一档
    final next = (idx + direction).clamp(0, _gears.length - 1);
    final v = _gears[next];
    engine.setPlaybackRate(v);
    OsdService.I.show('${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}x');
  }

  void _reset() {
    engine.setPlaybackRate(_normal);
    OsdService.I.show('1x');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 静态箭头段 — 速度变化时不重建（StatelessWidget 引用不变）
    final leftArrow = _Segment(
      width: Tokens.speedArrowWidth,
      icon: Icons.chevron_left,
      tooltip: l10n.speedDecrease,
      onTap: () => _shift(-1),
    );
    final rightArrow = _Segment(
      width: Tokens.speedArrowWidth,
      icon: Icons.chevron_right,
      tooltip: l10n.speedIncrease,
      onTap: () => _shift(1),
    );

    return SizedBox(
      width: Tokens.speedButtonWidth,
      height: Tokens.speedButtonHeight,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            // scroll up (dy < 0) → increase, scroll down (dy > 0) → decrease
            _shift(event.scrollDelta.dy > 0 ? -1 : 1);
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
                leftArrow,
                _Segment(
                  width: Tokens.speedSegmentWidth,
                  label: '${label}x',
                  tooltip: l10n.speedReset,
                  onDoubleTap: _reset,
                ),
                rightArrow,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  static final _radius = BorderRadius.circular(Tokens.radiusBtn);

  final double width;
  final IconData? icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const _Segment({
    required this.width,
    this.icon,
    this.label,
    this.tooltip,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Icon(icon, size: 18, color: Tokens.textPrimary)
        : Text(
            label ?? '',
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontCaption,
              fontWeight: Tokens.weightMedium,
              fontFeatures: [Tokens.tabularFigures],
            ),
          );

    return Tooltip(
      message: tooltip ?? '',
      waitDuration: const Duration(milliseconds: Tokens.tooltipDelayShort),
      child: GestureDetector(
        onDoubleTap: onDoubleTap,
        child: SizedBox(
          width: width,
          height: Tokens.speedButtonHeight,
          child: Material(
            color: Colors.transparent,
            borderRadius: _radius,
            child: InkWell(
              onTap: onTap,
              hoverColor: Tokens.bgHover,
              highlightColor: Colors.transparent,
              borderRadius: _radius,
              splashFactory: InkRipple.splashFactory,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
