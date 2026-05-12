import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/media_engine.dart';
import '../../kernel/models/media_state.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../kernel/utils/time_utils.dart';
import '../../l10n/app_localizations.dart';
import 'progress_bar.dart';
import 'speed_button.dart';
import 'volume_slider.dart';

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
  final IconData? playModeIcon;
  final bool playModeActive;
  final String? playModeLabel;
  final bool isVideo;
  final bool enableBlur;
  final bool isIdle;

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
    this.playModeIcon,
    this.playModeActive = false,
    this.playModeLabel,
    this.isVideo = false,
    this.enableBlur = true,
    this.isIdle = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prevTooltip = l10n.previousTrack;
    final nextTooltip = l10n.nextTrack;

    final content = Container(
      height: Tokens.controlBarHeight,
      decoration: const BoxDecoration(
        color: Tokens.bgGlass,
        border: Border(
          top: BorderSide(color: Tokens.borderHighlight, width: 1),
        ),
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
                          VolumeSlider(engine: engine),
                          IgnorePointer(
                            ignoring: isIdle,
                            child: Opacity(
                              opacity: isIdle ? 0.0 : 1.0,
                              child: SpeedButton(engine: engine),
                            ),
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
                          IconButton(
                            icon: const Icon(Icons.folder_open, size: Tokens.iconLg),
                            color: Tokens.textPrimary,
                            onPressed: onOpenFile,
                            splashRadius: 18,
                            tooltip: l10n.openFileTooltip,
                          ),
                        if (onTogglePlaylist != null)
                          IconButton(
                            icon: const Icon(Icons.queue_music, size: Tokens.iconLg),
                            color: Tokens.textPrimary,
                            onPressed: onTogglePlaylist,
                            splashRadius: 18,
                            tooltip: l10n.playlist,
                          ),
                        if (onSettings != null)
                          IconButton(
                            icon: const Icon(Icons.settings, size: Tokens.iconLg),
                            color: Tokens.textPrimary,
                            onPressed: onSettings,
                            splashRadius: 18,
                            tooltip: l10n.settings,
                          ),
                        if (onToggleFullscreen != null)
                          IconButton(
                            icon: Icon(
                              isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                              size: Tokens.iconLg,
                            ),
                            color: Tokens.textPrimary,
                            onPressed: onToggleFullscreen,
                            splashRadius: 18,
                            tooltip: isFullscreen ? l10n.exitFullscreen : l10n.fullscreen,
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
    );

    if (!enableBlur) return RepaintBoundary(child: content);

    return ValueListenableBuilder<bool>(
      valueListenable: WindowBridge.I.isResizing,
      builder: (_, resizing, child) => resizing
          ? child!
          : ClipRect(
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
        return IconButton(
          icon: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            size: Tokens.iconXl,
            color: playing ? Tokens.accent : Tokens.textPrimary,
          ),
          onPressed: isIdle ? null : engine.togglePlayPause,
          splashRadius: 24,
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
          IconButton(
            icon: const Icon(Icons.skip_previous, size: Tokens.iconLg),
            color: Tokens.textPrimary,
            onPressed: isIdle ? null : onPrevious,
            splashRadius: 20,
            tooltip: prevTooltip,
          ),
          const SizedBox(width: Tokens.spXs),
          IconButton(
            icon: const Icon(Icons.replay_10, size: Tokens.iconLg),
            color: Tokens.textPrimary,
            onPressed: isIdle ? null : () => engine.skipBack(10),
            splashRadius: 20,
            tooltip: AppLocalizations.of(context).rewind10,
          ),
          const SizedBox(width: Tokens.spSm),
          _PlayPauseButton(engine: engine, isIdle: isIdle),
          const SizedBox(width: Tokens.spSm),
          IconButton(
            icon: const Icon(Icons.forward_10, size: Tokens.iconLg),
            color: Tokens.textPrimary,
            onPressed: isIdle ? null : () => engine.skipForward(10),
            splashRadius: 20,
            tooltip: AppLocalizations.of(context).forward10,
          ),
          const SizedBox(width: Tokens.spXs),
          IconButton(
            icon: const Icon(Icons.skip_next, size: Tokens.iconLg),
            color: Tokens.textPrimary,
            onPressed: isIdle ? null : onNext,
            splashRadius: 20,
            tooltip: nextTooltip,
          ),
          const SizedBox(width: Tokens.spXs),
          IconButton(
            icon: const Icon(Icons.stop, size: Tokens.iconLg),
            color: Tokens.textPrimary,
            onPressed: isIdle ? null : engine.stop,
            splashRadius: 18,
            tooltip: AppLocalizations.of(context).stop,
          ),
        ],
      ),
    );
  }
}
