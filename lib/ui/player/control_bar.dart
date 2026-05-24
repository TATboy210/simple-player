import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../kernel/bridge/window_bridge.dart';
import '../../kernel/engine/media_engine.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_icon_button.dart';
import 'center_controls.dart';
import 'progress_bar.dart';
import 'speed_button.dart';
import 'time_range_display.dart';
import 'volume_controls.dart';

class ControlBar extends StatelessWidget {
  static final _borderRadius = BorderRadius.circular(Tokens.controlBarRadius);
  static final _decoration = BoxDecoration(
    color: Tokens.bgGlass,
    borderRadius: ControlBar._borderRadius,
    border: Border.fromBorderSide(
      BorderSide(color: Tokens.controlBarBorder, width: 0.5),
    ),
    boxShadow: [
      BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  final MediaEngine engine;
  final bool isFullscreen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final void Function(BuildContext context, TapUpDetails details)?
  onSettingsSecondary;
  final VoidCallback? onOpenFile;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onTogglePlayMode;
  final VoidCallback? onOpenSubtitle;
  final IconData? playModeIcon;
  final String? playModeLabel;
  final bool isVideo;
  final bool enableBlur;
  final bool isIdle;

  /// 淡入淡出动画 — opacity=0 时跳过 BackdropFilter
  final Animation<double>? opacity;

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
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prevTooltip = l10n.previousTrack;
    final nextTooltip = l10n.nextTrack;

    final content = Material(
      color: Colors.transparent,
      child: Container(
        height: Tokens.controlBarHeight,
        decoration: _decoration,
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
                  child: _buildButtonRow(
                    context,
                    l10n,
                    showSecondary,
                    prevTooltip,
                    nextTooltip,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (!enableBlur) return RepaintBoundary(child: content);

    // opacity=0 时跳过 BackdropFilter（fade-out 尾部帧零 GPU readback）
    final blurContent = RepaintBoundary(child: content);
    final filter = ui.ImageFilter.blur(
      sigmaX: Tokens.glassBlur,
      sigmaY: Tokens.glassBlur,
    );

    if (opacity != null) {
      return AnimatedBuilder(
        animation: Listenable.merge([opacity!, WindowBridge.I.interaction]),
        builder: (_, child) {
          if (opacity!.value < 0.01) return child!;
          if (WindowBridge.I.interaction.value !=
              WindowInteractionState.idle) {
            return child!;
          }
          return ClipRRect(
            borderRadius: _borderRadius,
            child: BackdropFilter(filter: filter, child: child),
          );
        },
        child: blurContent,
      );
    }

    return ValueListenableBuilder<WindowInteractionState>(
      valueListenable: WindowBridge.I.interaction,
      builder: (_, state, child) => state != WindowInteractionState.idle
          ? child!
          : ClipRRect(
              borderRadius: _borderRadius,
              child: BackdropFilter(filter: filter, child: child),
            ),
      child: blurContent,
    );
  }

  /// 按钮行：左右组 + 居中播放按钮群
  ///
  /// 三段等 flex Spacer 将播放按钮群精确置于 Row 50% 位置。
  Widget _buildButtonRow(
    BuildContext context,
    AppLocalizations l10n,
    bool showSecondary,
    String prevTooltip,
    String nextTooltip,
  ) {
    return Row(
      children: [
        _LeftButtonGroup(
          engine: engine,
          showSecondary: showSecondary,
          playModeIcon: playModeIcon,
          playModeLabel: playModeLabel,
          onTogglePlayMode: onTogglePlayMode,
        ),
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
        _RightButtonGroup(
          isFullscreen: isFullscreen,
          onOpenFile: onOpenFile,
          onOpenSubtitle: onOpenSubtitle,
          onTogglePlaylist: onTogglePlaylist,
          onSettings: onSettings,
          onSettingsSecondary: onSettingsSecondary,
          onToggleFullscreen: onToggleFullscreen,
        ),
      ],
    );
  }
}

/// 左侧按钮组：播放模式 + 音量 + 倍速
class _LeftButtonGroup extends StatelessWidget {
  final MediaEngine engine;
  final bool showSecondary;
  final IconData? playModeIcon;
  final String? playModeLabel;
  final VoidCallback? onTogglePlayMode;

  const _LeftButtonGroup({
    required this.engine,
    required this.showSecondary,
    this.playModeIcon,
    this.playModeLabel,
    this.onTogglePlayMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
      ],
    );
  }
}

/// 右侧按钮组：文件、字幕、播放列表、设置、全屏
class _RightButtonGroup extends StatelessWidget {
  final bool isFullscreen;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenSubtitle;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onSettings;
  final void Function(BuildContext context, TapUpDetails details)?
  onSettingsSecondary;
  final VoidCallback? onToggleFullscreen;

  const _RightButtonGroup({
    required this.isFullscreen,
    this.onOpenFile,
    this.onOpenSubtitle,
    this.onTogglePlaylist,
    this.onSettings,
    this.onSettingsSecondary,
    this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
