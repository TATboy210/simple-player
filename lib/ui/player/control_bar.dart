import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/media_engine.dart';
import '../../kernel/ui/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_icon_button.dart';
import 'center_controls.dart';
import 'progress_bar.dart';
import 'speed_button.dart';
import 'time_range_display.dart';
import 'volume_controls.dart';

class ControlBar extends StatelessWidget {
  final MediaEngine engine;
  final bool isFullscreen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final void Function(BuildContext context, TapUpDetails details)? onSettingsSecondary;
  final VoidCallback? onOpenFile;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onTogglePlayMode;
  final VoidCallback? onOpenSubtitle;
  final IconData? playModeIcon;
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
    this.onSettingsSecondary,
    this.onOpenFile,
    this.onToggleFullscreen,
    this.onTogglePlayMode,
    this.onOpenSubtitle,
    this.playModeIcon,
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
                      TimeRangeDisplay(engine: engine),
                      const SizedBox(width: Tokens.spSm),
                      Expanded(child: ProgressBar(engine: engine)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: playModeIcon ?? Icons.repeat,
                        tooltip: playModeLabel ?? '顺序',
                        onPressed: onTogglePlayMode,
                      ),
                      if (showSecondary) ...[
                        const SizedBox(width: Tokens.spXs),
                        VolumeButton(engine: engine),
                        VolumeSlider(engine: engine),
                        const SizedBox(width: Tokens.spXs),
                        SpeedButton(engine: engine),
                      ],
                      const Spacer(),
                      CenterGroup(
                        engine: engine,
                        isIdle: isIdle,
                        prevTooltip: prevTooltip,
                        nextTooltip: nextTooltip,
                        onPrevious: onPrevious,
                        onNext: onNext,
                      ),
                      const Spacer(),
                      _buildRightGroup(context, l10n),
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

    return ValueListenableBuilder<WindowInteractionState>(
      valueListenable: WindowBridge.I.interaction,
      builder: (_, state, child) => state != WindowInteractionState.idle
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

  Widget _buildRightGroup(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onOpenFile != null)
          GlassIconButton(
            icon: Icons.folder_open,
            onPressed: onOpenFile,
            tooltip: l10n.openFileTooltip,
          ),
        if (onOpenSubtitle != null)
          GlassIconButton(
            icon: Icons.subtitles,
            onPressed: onOpenSubtitle,
            tooltip: l10n.openSubtitle,
          ),
        if (onTogglePlaylist != null)
          GlassIconButton(
            icon: Icons.queue_music,
            onPressed: onTogglePlaylist,
            tooltip: l10n.playlist,
          ),
        if (onSettings != null)
          GlassIconButton(
            icon: Icons.settings,
            onPressed: onSettings,
            onSecondaryTapUp: onSettingsSecondary != null
                ? (d) => onSettingsSecondary!(context, d)
                : null,
            tooltip: l10n.settings,
          ),
        if (onToggleFullscreen != null)
          GlassIconButton(
            icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            onPressed: onToggleFullscreen,
            tooltip: isFullscreen ? l10n.exitFullscreen : l10n.fullscreen,
          ),
      ],
    );
  }
}
