import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/media_engine.dart';
import '../../kernel/models/media_state.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';
import '../widgets/osd_overlay.dart';
import 'progress_bar.dart';

class ControlBar extends StatelessWidget {
  final MediaEngine engine;
  final bool isFullscreen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final VoidCallback? onOpenFile;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onTogglePlayMode;
  final VoidCallback? onOpenSubtitle;
  final IconData? playModeIcon;
  final bool playModeActive;
  final String? playModeLabel;
  final bool isVideo;
  final bool enableBlur;
  final bool isIdle;
  final ValueNotifier<int>? popupCloseNotifier;

  const ControlBar({
    super.key,
    required this.engine,
    this.isFullscreen = false,
    this.onPrevious,
    this.onNext,
    this.onTogglePlaylist,
    this.onSettings,
    this.onOpenFile,
    this.onToggleFullscreen,
    this.onTogglePlayMode,
    this.onOpenSubtitle,
    this.playModeIcon,
    this.playModeActive = false,
    this.playModeLabel,
    this.isVideo = false,
    this.enableBlur = true,
    this.isIdle = false,
    this.popupCloseNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prevTooltip = l10n.previousTrack;
    final nextTooltip = l10n.nextTrack;

    final borderRadius = BorderRadius.circular(Tokens.controlBarRadius);
    final content = Material(
      color: Colors.transparent,
      child: Container(
        height: Tokens.controlBarHeight,
        decoration: BoxDecoration(
          color: Tokens.bgGlass,
          borderRadius: borderRadius,
          border: Border.all(color: Tokens.controlBarBorder, width: 0.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spMd),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final showSecondary = w >= 500;

            return Column(
              children: [
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      _TimeRangeDisplay(engine: engine),
                      const SizedBox(width: Tokens.spSm),
                      Expanded(child: ProgressBar(engine: engine)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PlayModeButton(
                            icon: playModeIcon ?? Icons.repeat,
                            label: playModeLabel ?? '顺序',
                            active: playModeActive,
                            isIdle: isIdle,
                            onPressed: onTogglePlayMode,
                          ),
                          if (showSecondary) ...[
                            const SizedBox(width: Tokens.spXs),
                            _VolumeButton(engine: engine),
                            _VolumeSlider(engine: engine),
                            _SpeedButton(
                              engine: engine,
                              popupCloseNotifier: popupCloseNotifier,
                            ),
                          ],
                        ],
                      ),
                      _CenterGroup(
                        engine: engine,
                        isIdle: isIdle,
                        prevTooltip: prevTooltip,
                        nextTooltip: nextTooltip,
                        onPrevious: onPrevious,
                        onNext: onNext,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onOpenFile != null)
                            _GlassIconButton(
                              icon: Icons.folder_open,
                              onPressed: onOpenFile,
                              tooltip: l10n.openFileTooltip,
                            ),
                          if (onOpenSubtitle != null)
                            _GlassIconButton(
                              icon: Icons.subtitles,
                              onPressed: onOpenSubtitle,
                              tooltip: l10n.openSubtitle,
                            ),
                          if (onTogglePlaylist != null)
                            _GlassIconButton(
                              icon: Icons.queue_music,
                              onPressed: onTogglePlaylist,
                              tooltip: l10n.playlist,
                            ),
                          if (onSettings != null)
                            _GlassIconButton(
                              icon: Icons.settings,
                              onPressed: onSettings,
                              tooltip: l10n.settings,
                            ),
                          if (onToggleFullscreen != null)
                            _GlassIconButton(
                              icon: isFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              onPressed: onToggleFullscreen,
                              tooltip: isFullscreen
                                  ? l10n.exitFullscreen
                                  : l10n.fullscreen,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (!enableBlur) return RepaintBoundary(child: content);

    return ValueListenableBuilder<bool>(
      valueListenable: WindowBridge.I.isResizing,
      builder: (_, resizing, child) => resizing
          ? child!
          : ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: Tokens.glassBlur,
                  sigmaY: Tokens.glassBlur,
                ),
                child: child,
              ),
            ),
      child: RepaintBoundary(child: content),
    );
  }
}

// ─── 音量按钮（单击静音）──────────────────────────

class _VolumeButton extends StatefulWidget {
  final MediaEngine engine;

  const _VolumeButton({required this.engine});

  @override
  State<_VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<_VolumeButton> {
  double _savedVolume = 1.0;

  void _toggleMute() {
    final engine = widget.engine;
    final l10n = AppLocalizations.of(context);
    if (engine.isMuted.value) {
      engine.setMute(false);
      engine.setVolume(_savedVolume);
      OsdService.I.show(
        '${(_savedVolume * 100).round()}%',
        progress: _savedVolume,
      );
    } else {
      _savedVolume = engine.volume.value;
      engine.setVolume(0);
      engine.setMute(true);
      OsdService.I.show(l10n.mute, icon: Icons.volume_off);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder2<bool, double>(
      first: widget.engine.isMuted,
      second: widget.engine.volume,
      builder: (_, muted, volume, _) {
        IconData icon;
        if (muted || volume == 0) {
          icon = Icons.volume_off;
        } else if (volume < 0.5) {
          icon = Icons.volume_down;
        } else {
          icon = Icons.volume_up;
        }
        return _GlassIconButton(
          icon: icon,
          iconSize: Tokens.iconLg,
          color: muted ? Tokens.accent : Tokens.textPrimary,
          onPressed: _toggleMute,
          tooltip: muted ? l10n.unmute : l10n.mute,
        );
      },
    );
  }
}

// ─── 音量滑块（内联水平条）────────────────────────

class _VolumeSlider extends StatelessWidget {
  final MediaEngine engine;

  const _VolumeSlider({required this.engine});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final delta = event.scrollDelta.dy > 0 ? -0.05 : 0.05;
            final v = (engine.volume.value + delta).clamp(0.0, 1.0);
            engine.setVolume(v);
            OsdService.I.show('${(v * 100).round()}%', progress: v);
          }
        },
        child: ValueListenableBuilder<double>(
          valueListenable: engine.volume,
          builder: (_, volume, _) => SliderTheme(
            data: const SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: volume,
              onChanged: (v) {
                engine.setVolume(v);
                OsdService.I.show('${(v * 100).round()}%', progress: v);
              },
              activeColor: Tokens.accent,
              inactiveColor: Tokens.bgHover,
            ),
          ),
        ),
      ),
    );
  }
}

/// 双 ValueNotifier 组合 Builder（避免嵌套）
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueNotifier<A> first;
  final ValueNotifier<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (_, a, _) => ValueListenableBuilder<B>(
        valueListenable: second,
        builder: (ctx, b, child) => builder(ctx, a, b, child),
      ),
    );
  }
}

// ─── 倍速按钮 + 弹窗 ──────────────────────────────

class _SpeedButton extends StatefulWidget {
  final MediaEngine engine;
  final ValueNotifier<int>? popupCloseNotifier;

  const _SpeedButton({required this.engine, this.popupCloseNotifier});

  @override
  State<_SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends State<_SpeedButton>
    with SingleTickerProviderStateMixin {
  final _popupController = OverlayPortalController();
  final _layerLink = LayerLink();
  final ValueNotifier<bool> _popupShowing = ValueNotifier(false);
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
      reverseCurve: Curves.easeIn,
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );
    widget.popupCloseNotifier?.addListener(_onCloseRequested);
  }

  @override
  void dispose() {
    widget.popupCloseNotifier?.removeListener(_onCloseRequested);
    _anim.stop();
    if (_popupController.isShowing) _popupController.hide();
    _popupShowing.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _onCloseRequested() {
    if (_popupController.isShowing) _closePopupImmediate();
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
    _popupShowing.value = true;
    _anim.forward(from: 0.0);
  }

  void _close() {
    _anim.reverse().then((_) {
      if (mounted && _popupController.isShowing) {
        _popupController.hide();
      }
      if (mounted) _popupShowing.value = _popupController.isShowing;
    });
  }

  void _closePopupImmediate() {
    _anim.stop();
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
        return ValueListenableBuilder<double>(
          valueListenable: widget.engine.playbackSpeed,
          builder: (_, speed, _) {
            final label = speed == speed.roundToDouble()
                ? '${speed.toInt()}x'
                : '${speed}x';
            final active = speed != 1.0 || showing;
            return _GlassIconButton(
              onPressed: _toggle,
              tooltip: '倍速',
              active: active,
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Tokens.accent : Tokens.textSecondary,
                  fontSize: Tokens.fontCaption,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopup(BuildContext context) {
    final itemHeight = 36.0;
    final popupHeight = _SpeedPopupContent.speeds.length * itemHeight + 16.0;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, -(popupHeight + Tokens.spSm)),
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.topCenter,
              child: _SpeedPopupContent(engine: widget.engine, onClose: _close),
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

  const _SpeedPopupContent({required this.engine, required this.onClose});

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
          child: ValueListenableBuilder<double>(
            valueListenable: engine.playbackSpeed,
            builder: (_, speed, _) {
              return GlassContainer(
                tier: GlassTier.thick,
                respectResizeState: true,
                borderRadius: BorderRadius.circular(Tokens.radiusLarge),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: Tokens.spXs),
                  itemCount: speeds.length,
                  itemBuilder: (_, i) {
                    final s = speeds[i];
                    return InkWell(
                      onTap: () {
                        engine.setPlaybackRate(s);
                        onClose();
                      },
                      borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                      hoverColor: Tokens.bgHover,
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
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── 其他内部组件 ────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final double iconSize;
  final Color? color;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;

  const _GlassIconButton({
    this.icon,
    this.child,
    this.iconSize = Tokens.iconLg,
    this.color = Tokens.textPrimary,
    this.onPressed,
    this.tooltip,
    this.active = false,
  }) : assert(
         icon != null || child != null,
         'Either icon or child must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final content = child ?? Icon(icon!, size: iconSize, color: color);
    final decoration = active
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
            border: Border.all(
              color: Tokens.accent.withValues(alpha: 0.3),
              width: 1,
            ),
          )
        : null;
    final padding = active
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
        : EdgeInsets.zero;

    return Tooltip(
      message: tooltip ?? '',
      waitDuration: const Duration(milliseconds: 400),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          child: InkWell(
            onTap: onPressed,
            hoverColor: Tokens.bgHover,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
            splashFactory: InkRipple.splashFactory,
            child: Center(
              child: Container(
                decoration: decoration,
                padding: padding,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final MediaEngine engine;
  final bool isIdle;

  const _PlayPauseButton({required this.engine, this.isIdle = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<MediaState>(
      valueListenable: engine.state,
      builder: (_, state, _) {
        final playing = state == MediaState.playing;
        return _GlassIconButton(
          icon: playing ? Icons.pause : Icons.play_arrow,
          iconSize: Tokens.iconXl,
          color: playing ? Tokens.accent : Tokens.textPrimary,
          onPressed: isIdle ? null : engine.togglePlayPause,
          tooltip: playing ? l10n.pause : l10n.play,
        );
      },
    );
  }
}

class _TimeRangeDisplay extends StatefulWidget {
  final MediaEngine engine;

  const _TimeRangeDisplay({required this.engine});

  @override
  State<_TimeRangeDisplay> createState() => _TimeRangeDisplayState();
}

class _TimeRangeDisplayState extends State<_TimeRangeDisplay> {
  late final _MergedListenable _merged;

  @override
  void initState() {
    super.initState();
    _merged = _MergedListenable(widget.engine.position, widget.engine.duration);
  }

  @override
  void dispose() {
    _merged.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_TimePair>(
      valueListenable: _merged,
      builder: (_, pair, _) {
        return Text(
          '${formatMs(pair.a)} / ${formatMs(pair.b)}',
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
            fontFeatures: [Tokens.tabularFigures],
          ),
        );
      },
    );
  }
}

class _TimePair {
  const _TimePair(this.a, this.b);
  final int a, b;
}

class _MergedListenable extends ValueNotifier<_TimePair> {
  _MergedListenable(this._a, this._b) : super(_TimePair(_a.value, _b.value)) {
    _a.addListener(_sync);
    _b.addListener(_sync);
  }

  final ValueNotifier<int> _a;
  final ValueNotifier<int> _b;

  void _sync() => value = _TimePair(_a.value, _b.value);

  @override
  void dispose() {
    _a.removeListener(_sync);
    _b.removeListener(_sync);
    super.dispose();
  }
}

class _PlayModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isIdle;
  final VoidCallback? onPressed;

  const _PlayModeButton({
    required this.icon,
    required this.label,
    required this.active,
    this.isIdle = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Tokens.accent
        : (isIdle ? Tokens.textPrimary : Tokens.textDisabled);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(Tokens.radiusBtn),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spSm,
          vertical: Tokens.spXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Tokens.iconMd, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: Tokens.fontOverline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterGroup extends StatelessWidget {
  final MediaEngine engine;
  final bool isIdle;
  final String prevTooltip;
  final String nextTooltip;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _CenterGroup({
    required this.engine,
    required this.isIdle,
    required this.prevTooltip,
    required this.nextTooltip,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isIdle ? 0.38 : 1.0,
      duration: const Duration(milliseconds: Tokens.durationFade),
      curve: Curves.easeOut,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassIconButton(
            icon: Icons.skip_previous,
            onPressed: isIdle ? null : onPrevious,
            tooltip: prevTooltip,
          ),
          const SizedBox(width: Tokens.spXs),
          _GlassIconButton(
            icon: Icons.replay_10,
            onPressed: isIdle ? null : () => engine.skipBack(10),
            tooltip: AppLocalizations.of(context).rewind10,
          ),
          const SizedBox(width: Tokens.spSm),
          _PlayPauseButton(engine: engine, isIdle: isIdle),
          const SizedBox(width: Tokens.spSm),
          _GlassIconButton(
            icon: Icons.forward_10,
            onPressed: isIdle ? null : () => engine.skipForward(10),
            tooltip: AppLocalizations.of(context).forward10,
          ),
          const SizedBox(width: Tokens.spXs),
          _GlassIconButton(
            icon: Icons.skip_next,
            onPressed: isIdle ? null : onNext,
            tooltip: nextTooltip,
          ),
          const SizedBox(width: Tokens.spXs),
          _GlassIconButton(
            icon: Icons.stop,
            onPressed: isIdle ? null : engine.stop,
            tooltip: AppLocalizations.of(context).stop,
          ),
        ],
      ),
    );
  }
}
