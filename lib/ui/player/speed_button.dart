import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';

/// 播放速度按钮 — 显示当前速度，点击弹出毛玻璃选择菜单
class SpeedButton extends StatefulWidget {
  final MediaEngine engine;

  /// 控制栏自动隐藏时触发，关闭弹窗
  final ValueNotifier<int>? popupCloseNotifier;

  const SpeedButton({
    super.key,
    required this.engine,
    this.popupCloseNotifier,
  });

  @override
  State<SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends State<SpeedButton>
    with SingleTickerProviderStateMixin {
  final _popupController = OverlayPortalController();
  final _layerLink = LayerLink();
  late final AnimationController _anim;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

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
    widget.popupCloseNotifier?.addListener(_onCloseRequested);
  }

  @override
  void dispose() {
    widget.popupCloseNotifier?.removeListener(_onCloseRequested);
    _anim.stop();
    if (_popupController.isShowing) _popupController.hide();
    _anim.dispose();
    super.dispose();
  }

  void _onCloseRequested() {
    if (_popupController.isShowing) closePopupImmediate();
  }

  void _toggle() {
    if (_popupController.isShowing) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    _anim.stop();
    _popupController.show();
    _anim.forward(from: 0.0);
  }

  void _close() {
    _anim.reverse().then((_) {
      if (mounted && _popupController.isShowing) {
        _popupController.hide();
      }
    });
  }

  /// 立即关闭弹窗（无动画），用于控制栏自动隐藏
  void closePopupImmediate() {
    _anim.stop();
    if (_popupController.isShowing) _popupController.hide();
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
    return ValueListenableBuilder<double>(
      valueListenable: widget.engine.playbackSpeed,
      builder: (_, speed, _) {
        final label = speed == speed.roundToDouble()
            ? '${speed.toInt()}x'
            : '${speed}x';
        final active = speed != 1.0 || _popupController.isShowing;
        return InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          hoverColor: Tokens.bgHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.spSm,
              vertical: Tokens.spXs,
            ),
            child: Container(
              decoration: active
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                      border: Border.all(
                        color: Tokens.accentegg.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    )
                  : null,
              padding: active
                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                  : EdgeInsets.zero,
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Tokens.accentegg : Tokens.textSecondary,
                  fontSize: Tokens.fontCaption,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopup(BuildContext context) {
    final itemHeight = 36.0;
    final popupHeight = _SpeedPopupContent.speeds.length * itemHeight + 16.0;
    return Stack(
      children: [
        // 全屏点击关闭背景
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        // 按钮区域穿透 — 点击按钮切换弹窗
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
        // 弹窗内容 — 定位在按钮上方
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, -(popupHeight + Tokens.spSm)),
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.topCenter,
              child: _SpeedPopupContent(
                engine: widget.engine,
                onClose: _close,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeedPopupContent extends StatelessWidget {
  final MediaEngine engine;
  final VoidCallback onClose;

  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];

  const _SpeedPopupContent({
    required this.engine,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const popupWidth = 72.0;
    final itemHeight = 36.0;
    final popupHeight = speeds.length * itemHeight + 16.0;

    return SizedBox(
      width: popupWidth,
      height: popupHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(
          color: Colors.transparent,
          child: GlassContainer(
            tier: GlassTier.thick,
            respectResizeState: true,
            borderRadius: BorderRadius.circular(Tokens.radiusLarge),
            child: ValueListenableBuilder<double>(
              valueListenable: engine.playbackSpeed,
              builder: (_, speed, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: Tokens.spXs),
                    ...speeds.map(
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
                                    color: Tokens.accentegg,
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
                                        ? Tokens.accentegg
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
    );
  }
}
