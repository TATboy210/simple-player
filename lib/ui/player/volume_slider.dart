import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';

/// 音量控件 — 按钮 + OverlayPortal 竖向弹窗滑块
class VolumeSlider extends StatefulWidget {
  final MediaEngine engine;

  /// 控制栏自动隐藏时触发，关闭弹窗
  final ValueNotifier<int>? popupCloseNotifier;

  const VolumeSlider({
    super.key,
    required this.engine,
    this.popupCloseNotifier,
  });

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider>
    with SingleTickerProviderStateMixin {
  final _popupController = OverlayPortalController();
  final _layerLink = LayerLink();
  final ValueNotifier<bool> _popupShowing = ValueNotifier(false);
  late final AnimationController _popupAnim;
  late final Animation<double> _popupOpacity;
  late final _VolumeMerged _volumeMerged;

  @override
  void initState() {
    super.initState();
    _volumeMerged = _VolumeMerged(widget.engine.isMuted, widget.engine.volume);
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
    widget.popupCloseNotifier?.addListener(_onCloseRequested);
  }

  @override
  void dispose() {
    widget.popupCloseNotifier?.removeListener(_onCloseRequested);
    _popupAnim.stop();
    if (_popupController.isShowing) _popupController.hide();
    _popupAnim.dispose();
    _volumeMerged.dispose();
    _popupShowing.dispose();
    super.dispose();
  }

  void _onCloseRequested() {
    if (_popupController.isShowing) closePopupImmediate();
  }

  IconData _icon(bool muted, double volume) {
    if (muted || volume == 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  void _togglePopup() {
    if (_popupController.isShowing) {
      _closePopup();
    } else {
      _openPopup();
    }
  }

  void _openPopup() {
    _popupAnim.stop();
    _popupController.show();
    _popupShowing.value = true;
    _popupAnim.forward(from: 0.0);
  }

  void _closePopup() {
    _popupAnim.reverse().then((_) {
      if (mounted && _popupController.isShowing) {
        _popupController.hide();
      }
      if (mounted) _popupShowing.value = _popupController.isShowing;
    });
  }

  /// 立即关闭弹窗（无动画），用于控制栏自动隐藏
  void closePopupImmediate() {
    _popupAnim.stop();
    if (_popupController.isShowing) _popupController.hide();
    if (mounted) _popupShowing.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _popupController,
        overlayChildBuilder: _buildPopup,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _popupShowing,
      builder: (_, showing, _) {
        return ValueListenableBuilder<_VolumeState>(
          valueListenable: _volumeMerged,
          builder: (_, state, _) {
            final l10n = AppLocalizations.of(context);
            final iconColor = showing ? Tokens.accentegg : Tokens.textPrimary;
            return IconButton(
              icon: Icon(
                _icon(state.muted, state.volume),
                color: iconColor,
                size: Tokens.iconLg,
              ),
              onPressed: _togglePopup,
              splashRadius: 18,
              tooltip: state.muted ? l10n.unmute : l10n.mute,
            );
          },
        );
      },
    );
  }

  Widget _buildPopup(BuildContext context) {
    const popupHeight = 200.0;
    return Stack(
      children: [
        // 全屏点击关闭背景
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closePopup,
            child: const SizedBox.expand(),
          ),
        ),
        // 按钮区域穿透 — 点击按钮切换弹窗
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePopup,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
        // 弹窗内容 — 定位在按钮上方
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -(popupHeight + Tokens.spSm)),
          child: FadeTransition(
            opacity: _popupOpacity,
            child: _VolumePopupContent(
              engine: widget.engine,
              volumeState: _volumeMerged,
            ),
          ),
        ),
      ],
    );
  }
}

class _VolumePopupContent extends StatefulWidget {
  final MediaEngine engine;
  final ValueNotifier<_VolumeState> volumeState;

  const _VolumePopupContent({required this.engine, required this.volumeState});

  @override
  State<_VolumePopupContent> createState() => _VolumePopupContentState();
}

class _VolumePopupContentState extends State<_VolumePopupContent> {
  bool _dragging = false;
  double _dragValue = 0;

  double get _effectiveValue =>
      _dragging ? _dragValue : widget.engine.volume.value;

  @override
  Widget build(BuildContext context) {
    const sliderAreaHeight = 150.0;

    return SizedBox(
      width: 48.0,
      height: 200.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(
          color: Colors.transparent,
          child: ValueListenableBuilder<_VolumeState>(
            valueListenable: widget.volumeState,
            builder: (_, state, _) {
              final muted = state.muted;
              final volume = _effectiveValue;
              return GlassContainer(
                tier: GlassTier.thick,
                respectResizeState: true,
                borderRadius: BorderRadius.circular(Tokens.radiusLarge),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: Tokens.spSm),
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
                                overlayShape: RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
                              ),
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
                                  setState(() => _dragging = false);
                                },
                                activeColor: Tokens.accent,
                                inactiveColor: Tokens.bgHover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        muted ? Icons.volume_off : Icons.volume_up,
                        size: Tokens.iconSm,
                        color: muted ? Tokens.danger : Tokens.textSecondary,
                      ),
                      onPressed: () => widget.engine.setMute(!muted),
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
    );
  }
}

class _VolumeState {
  const _VolumeState(this.muted, this.volume);
  final bool muted;
  final double volume;
}

class _VolumeMerged extends ValueNotifier<_VolumeState> {
  _VolumeMerged(this._isMuted, this._volume)
    : super(_VolumeState(_isMuted.value, _volume.value)) {
    _isMuted.addListener(_sync);
    _volume.addListener(_sync);
  }

  final ValueNotifier<bool> _isMuted;
  final ValueNotifier<double> _volume;

  void _sync() => value = _VolumeState(_isMuted.value, _volume.value);

  @override
  void dispose() {
    _isMuted.removeListener(_sync);
    _volume.removeListener(_sync);
    super.dispose();
  }
}
