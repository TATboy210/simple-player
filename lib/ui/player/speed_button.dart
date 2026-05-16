import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';
import '../shared/glass_icon_button.dart';
import '../widgets/osd_overlay.dart';
import 'popup_overlay_mixin.dart';

/// 倍速按钮 + 横向选择器弹窗
class SpeedButton extends StatefulWidget {
  final MediaEngine engine;
  final ValueNotifier<int>? popupCloseNotifier;

  const SpeedButton({super.key, required this.engine, this.popupCloseNotifier});

  @override
  State<SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends PopupOverlayState<SpeedButton> {
  @override
  double? get popupScaleBegin => 0.9;

  @override
  ValueNotifier<int>? get popupCloseNotifier => widget.popupCloseNotifier;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: OverlayPortal(
        controller: popupController,
        overlayChildBuilder: _buildPopup,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: popupShowing,
      builder: (_, showing, _) {
        return ValueListenableBuilder<double>(
          valueListenable: widget.engine.playbackSpeed,
          builder: (_, speed, _) {
            final label = speed == speed.roundToDouble()
                ? '${speed.toInt()}x'
                : '${speed}x';
            return GlassIconButton(
              onPressed: togglePopup,
              tooltip: l10n.speedTooltip,
              child: Text(
                label,
                style: TextStyle(
                  color: speed != 1.0
                      ? Tokens.accent
                      : Tokens.textPrimary,
                  fontSize: Tokens.fontCaption,
                  fontWeight: Tokens.weightMedium,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopup(BuildContext context) {
    return Stack(
      children: [
        // 全屏点击关闭层（opaque 拦截所有点击，不再穿透到按钮）
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: closePopup,
            child: const SizedBox.expand(),
          ),
        ),
        // 横向选择器弹窗
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: Offset(
            18 - (8 + SpeedSelector._itemWidth * 2 + SpeedSelector._itemWidth / 2),
            -(SpeedSelector.height + Tokens.spSm),
          ),
          child: FadeTransition(
            opacity: popupOpacity,
            child: ScaleTransition(
              scale: popupScale!,
              alignment: Alignment.topCenter,
              child: SpeedSelector(
                engine: widget.engine,
                onClose: closePopup,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 横向倍速选择器 — 毛玻璃风格，与控制栏统一设计语言
class SpeedSelector extends StatelessWidget {
  final MediaEngine engine;
  final VoidCallback onClose;

  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];
  static const _itemWidth = 48.0;
  static const _itemHeight = 32.0;
  static const height = _itemHeight + 12; // padding 6 top + 6 bottom

  const SpeedSelector({
    super.key,
    required this.engine,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final popupWidth = speeds.length * _itemWidth + 16; // 8px padding each side
    return SizedBox(
      width: popupWidth,
      height: height,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Material(
            color: Colors.transparent,
            child: ValueListenableBuilder<double>(
              valueListenable: engine.playbackSpeed,
              builder: (_, speed, _) {
                return GlassContainer(
                  tier: GlassTier.thick,
                  respectResizeState: true,
                  borderRadius: BorderRadius.circular(Tokens.radiusLarge),
                  border: Border(
                    top: BorderSide(
                      color: Tokens.borderHighlight,
                      width: 0.5,
                    ),
                    bottom: BorderSide(
                      color: Tokens.borderHighlight,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: speeds.map((s) {
                      final selected = s == speed;
                      return _SpeedChip(
                        speed: s,
                        selected: selected,
                        onTap: () {
                          engine.setPlaybackRate(s);
                          _showOsd(s);
                          onClose();
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final current = engine.playbackSpeed.value;
    final idx = speeds.indexOf(current);
    if (idx < 0) return;

    final nextIdx = event.scrollDelta.dy > 0
        ? (idx + 1).clamp(0, speeds.length - 1)
        : (idx - 1).clamp(0, speeds.length - 1);
    if (nextIdx == idx) return;

    final next = speeds[nextIdx];
    engine.setPlaybackRate(next);
    _showOsd(next);
  }

  void _showOsd(double speed) {
    final label = speed == speed.roundToDouble()
        ? '${speed.toInt()}x'
        : '${speed}x';
    OsdService.I.show(label);
  }
}

/// 单个倍速选项
class _SpeedChip extends StatelessWidget {
  final double speed;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = speed == speed.roundToDouble()
        ? '${speed.toInt()}x'
        : '${speed}x';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusBtn),
      hoverColor: Tokens.bgHover,
      child: Container(
        width: SpeedSelector._itemWidth,
        height: SpeedSelector._itemHeight,
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                color: Tokens.bgGlass,
                borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                border: Border.all(
                  color: Tokens.borderHighlight,
                  width: 0.5,
                ),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Tokens.accent : Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
            fontWeight: selected ? Tokens.weightSemiBold : Tokens.weightRegular,
          ),
        ),
      ),
    );
  }
}
