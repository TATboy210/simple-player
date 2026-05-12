import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';

/// 音量控件 — 按钮 + 竖向弹窗滑块
class VolumeSlider extends StatefulWidget {
  final MediaEngine engine;

  const VolumeSlider({super.key, required this.engine});

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider>
    with SingleTickerProviderStateMixin {
  bool _popupOpen = false;
  late final AnimationController _popupAnim;
  late final Animation<double> _popupOpacity;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _popupAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      value: 0,
    );
    _popupOpacity = CurvedAnimation(
      parent: _popupAnim,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _popupAnim.dispose();
    super.dispose();
  }

  IconData _icon(bool muted, double volume) {
    if (muted || volume == 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  void _togglePopup() {
    if (_popupOpen) {
      _closePopup();
    } else {
      _openPopup();
    }
  }

  void _openPopup() {
    _popupAnim.stop();
    _removeOverlay();
    _popupOpen = true;
    _popupAnim.forward(from: 0.0);

    final renderBox = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonPos =
        renderBox.localToGlobal(Offset.zero, ancestor: overlay);

    _overlayEntry = OverlayEntry(
      builder: (_) => _VolumePopup(
        engine: widget.engine,
        buttonPosition: buttonPos,
        buttonSize: renderBox.size,
        opacity: _popupOpacity,
        onClose: _closePopup,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closePopup() {
    if (!_popupOpen) return;
    _popupOpen = false;
    _popupAnim.reverse().then((_) {
      if (!_popupOpen) _removeOverlay();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.engine.isMuted,
        widget.engine.volume,
      ]),
      builder: (_, _) {
        final muted = widget.engine.isMuted.value;
        final volume = widget.engine.volume.value;
        final l10n = AppLocalizations.of(context);
        return IconButton(
          icon: Icon(
            _icon(muted, volume),
            color: _popupOpen ? Tokens.accent : Tokens.textPrimary,
            size: Tokens.iconLg,
          ),
          onPressed: _togglePopup,
          splashRadius: 18,
          tooltip: muted ? l10n.unmute : l10n.mute,
        );
      },
    );
  }
}

class _VolumePopup extends StatefulWidget {
  final MediaEngine engine;
  final Offset buttonPosition;
  final Size buttonSize;
  final Animation<double> opacity;
  final VoidCallback onClose;

  const _VolumePopup({
    required this.engine,
    required this.buttonPosition,
    required this.buttonSize,
    required this.opacity,
    required this.onClose,
  });

  @override
  State<_VolumePopup> createState() => _VolumePopupState();
}

class _VolumePopupState extends State<_VolumePopup> {
  bool _dragging = false;
  double _dragValue = 0;

  double get _effectiveValue =>
      _dragging ? _dragValue : widget.engine.volume.value;

  @override
  Widget build(BuildContext context) {
    const popupWidth = 48.0;
    const popupHeight = 200.0;
    const sliderAreaHeight = 150.0;

    final left = widget.buttonPosition.dx +
        widget.buttonSize.width / 2 -
        popupWidth / 2;
    final bottom = MediaQuery.of(context).size.height -
        widget.buttonPosition.dy +
        Tokens.spSm;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onClose,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          bottom: bottom,
          width: popupWidth,
          height: popupHeight,
          child: FadeTransition(
            opacity: widget.opacity,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  widget.engine.isMuted,
                  widget.engine.volume,
                ]),
                builder: (_, _) {
                  final muted = widget.engine.isMuted.value;
                  final volume = _effectiveValue;
                  return GlassContainer(
                    tier: GlassTier.thick,
                    respectResizeState: true,
                    borderRadius:
                        BorderRadius.circular(Tokens.radiusLarge),
                    child: Column(
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(top: Tokens.spSm),
                          child: Text(
                            '${(volume * 100).round()}',
                            style: const TextStyle(
                              color: Tokens.textPrimary,
                              fontSize: Tokens.fontOverline,
                              fontFeatures: [Tokens.tabularFigures],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              height: sliderAreaHeight,
                              child: RotatedBox(
                                quarterTurns: -1,
                                child: SliderTheme(
                                  data: const SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape:
                                        RoundSliderOverlayShape(
                                      overlayRadius: 14,
                                    ),
                                  ),
                                  child: Semantics(
                                    label: AppLocalizations.of(
                                      context,
                                    ).volume,
                                    value:
                                        '${(volume * 100).round()}%',
                                    child: Slider(
                                      value: volume,
                                      onChanged: (v) {
                                        setState(() {
                                          _dragging = true;
                                          _dragValue = v;
                                        });
                                        widget.engine.setVolume(v);
                                      },
                                      onChangeEnd: (_) {
                                        setState(
                                            () => _dragging = false);
                                      },
                                      activeColor: Tokens.accent,
                                      inactiveColor: Tokens.bgHover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            muted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: Tokens.iconSm,
                            color: muted
                                ? Tokens.danger
                                : Tokens.textSecondary,
                          ),
                          onPressed: () =>
                              widget.engine.setMute(!muted),
                          splashRadius: 14,
                          tooltip: muted
                              ? AppLocalizations.of(context).unmute
                              : AppLocalizations.of(context).mute,
                        ),
                        const SizedBox(height: Tokens.spXs),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
