import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';

/// 播放速度按钮 — 显示当前速度，点击弹出毛玻璃选择菜单
class SpeedButton extends StatefulWidget {
  final MediaEngine engine;

  const SpeedButton({super.key, required this.engine});

  @override
  State<SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends State<SpeedButton>
    with SingleTickerProviderStateMixin {
  bool _popupOpen = false;
  late final AnimationController _anim;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 180),
      value: 0,
    );
    _opacity = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_popupOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    _anim.stop();
    _removeOverlay();
    _popupOpen = true;
    _anim.forward(from: 0.0);

    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlay);

    _overlay = OverlayEntry(
      builder: (_) => _SpeedPopup(
        engine: widget.engine,
        buttonPosition: pos,
        buttonSize: box.size,
        opacity: _opacity,
        scale: _scale,
        onClose: _close,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    if (!_popupOpen) return;
    _popupOpen = false;
    _anim.reverse().then((_) {
      if (!_popupOpen) _removeOverlay();
    });
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.engine.playbackSpeed,
      builder: (_, speed, _) {
        final label = speed == speed.roundToDouble()
            ? '${speed.toInt()}x'
            : '${speed}x';
        return InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.spSm,
              vertical: Tokens.spXs,
            ),
            child: Text(
              label,
              style: TextStyle(
                color:
                    speed == 1.0 ? Tokens.textDisabled : Tokens.accent,
                fontSize: Tokens.fontCaption,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpeedPopup extends StatelessWidget {
  final MediaEngine engine;
  final Offset buttonPosition;
  final Size buttonSize;
  final Animation<double> opacity;
  final Animation<double> scale;
  final VoidCallback onClose;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];

  const _SpeedPopup({
    required this.engine,
    required this.buttonPosition,
    required this.buttonSize,
    required this.opacity,
    required this.scale,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const popupWidth = 72.0;
    final itemHeight = 36.0;
    final popupHeight = _speeds.length * itemHeight + 16.0;

    final left =
        buttonPosition.dx + buttonSize.width / 2 - popupWidth / 2;
    final bottom = MediaQuery.of(context).size.height -
        buttonPosition.dy +
        Tokens.spSm;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onClose,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          bottom: bottom,
          width: popupWidth,
          height: popupHeight,
          child: FadeTransition(
            opacity: opacity,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: GlassContainer(
                  tier: GlassTier.thick,
                  respectResizeState: true,
                  borderRadius:
                      BorderRadius.circular(Tokens.radiusLarge),
                  child: ValueListenableBuilder<double>(
                    valueListenable: engine.playbackSpeed,
                    builder: (_, speed, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: Tokens.spXs),
                          ..._speeds.map(
                            (s) => Semantics(
                              button: true,
                              selected: s == speed,
                              label: AppLocalizations.of(
                                context,
                              ).speedLabel(s),
                              child: InkWell(
                                onTap: () {
                                  engine.setPlaybackRate(s);
                                  onClose();
                                },
                                child: SizedBox(
                                  height: itemHeight,
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      if (s == speed)
                                        const Icon(
                                          Icons.check,
                                          size: Tokens.iconSm,
                                          color: Tokens.accent,
                                        )
                                      else
                                        const SizedBox(width: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        s == s.roundToDouble()
                                            ? '${s.toInt()}x'
                                            : '${s}x',
                                        style: TextStyle(
                                          color: s == speed
                                              ? Tokens.accent
                                              : Tokens.textPrimary,
                                          fontSize: Tokens.fontCaption,
                                          fontWeight: s == speed
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Tokens.spXs),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
