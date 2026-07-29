import 'package:flutter/material.dart';

import '../../../kernel/services/input_mode_detector.dart';
import '../../theme/tokens.dart';

/// Paints translucent up/down navigation indicators over one scrollable child.
///
/// The caller passes the complete scrollable [child]; this widget owns the
/// [Stack] composition so callers never add a competing sibling overlay.
class OptionListNavigationOverlay extends StatelessWidget {
  const OptionListNavigationOverlay({super.key, required this.child});

  /// The scrollable option list that remains the base layer of the overlay.
  final Widget child;

  /// Stable test and inspection anchor for the top arrow indicator.
  static const topIndicatorKey = Key('option-list-navigation-top-indicator');

  /// Stable test and inspection anchor for the bottom arrow indicator.
  static const bottomIndicatorKey = Key(
    'option-list-navigation-bottom-indicator',
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The overlay owns this Stack so the supplied scrollable remains its
        // base layer instead of becoming a fragile sibling in GeneralTab.
        child,
        ValueListenableBuilder<ArrowDirection?>(
          valueListenable: InputModeDetector.instance.arrowGlow,
          builder: (context, glowDirection, _) {
            // InputModeDetector owns the cancellable reset timer. This overlay
            // only renders the notifier value, including its null reset state.
            return Positioned.fill(
              child: IgnorePointer(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ArrowIndicator(
                      key: topIndicatorKey,
                      icon: Icons.arrow_drop_up,
                      isGlowing: glowDirection == ArrowDirection.up,
                    ),
                    _ArrowIndicator(
                      key: bottomIndicatorKey,
                      icon: Icons.arrow_drop_down,
                      isGlowing: glowDirection == ArrowDirection.down,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// One color-only directional indicator inside the panel's existing blur.
class _ArrowIndicator extends StatelessWidget {
  const _ArrowIndicator({
    super.key,
    required this.icon,
    required this.isGlowing,
  });

  final IconData icon;
  final bool isGlowing;

  @override
  Widget build(BuildContext context) {
    // The panel GlassContainer is the sole blur owner. Adding a BackdropFilter
    // here would nest GPU readback work and degrade raster performance.
    final iconColor = isGlowing ? Tokens.accentBlue : Tokens.textSecondary;
    return Container(
      color: Tokens.bgGlass,
      child: Icon(icon, size: Tokens.iconMd, color: iconColor),
    );
  }
}
