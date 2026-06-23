import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:player_engine/player_engine.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import 'center_controls.dart';
import 'player_actions.dart';
import 'progress_bar.dart';
import 'speed_button.dart';
import 'time_range_display.dart';
import 'volume_controls.dart';

class ControlBar extends StatelessWidget {
  static final _borderRadius = BorderRadius.circular(Tokens.controlBarRadius);
  static final _blurFilter = ui.ImageFilter.blur(
    sigmaX: Tokens.glassBlur,
    sigmaY: Tokens.glassBlur,
  );
  static final _decoration = BoxDecoration(
    color: Tokens.bgGlass,
    borderRadius: ControlBar._borderRadius,
    border: Border.all(color: Tokens.controlBarBorder, width: 0.5),
    boxShadow: const [
      BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  final PlayerEngine engine;
  final PlayerActions actions;
  final bool isFullscreen;
  final bool enableBlur;
  final bool isIdle;

  /// 淡入淡出动画 — opacity=0 时跳过 BackdropFilter
  final Animation<double>? opacity;

  /// 窗口 resize 信号 — true 时跳过 BackdropFilter 避免 GPU readback 卡顿
  final ValueListenable<bool>? resizing;

  const ControlBar({
    super.key,
    required this.engine,
    this.actions = const PlayerActions(),
    this.isFullscreen = false,
    this.enableBlur = true,
    this.isIdle = false,
    this.opacity,
    this.resizing,
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
            final showSecondary = w >= Tokens.compactBreakpoint;

            return Column(
              children: [
                SizedBox(
                  height: 36,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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

    // resize 期间跳过 BackdropFilter — 避免 GPU readback 卡顿
    if (resizing != null) {
      return AnimatedBuilder(
        animation: resizing!,
        builder: (_, child) {
          if (resizing!.value) return RepaintBoundary(child: child!);
          return _buildBlur(child!);
        },
        child: content,
      );
    }

    return _buildBlur(content);
  }

  Widget _buildBlur(Widget content) {
    // opacity=0 时跳过 BackdropFilter（fade-out 尾部帧零 GPU readback）
    final blurContent = RepaintBoundary(child: content);

    if (opacity != null) {
      return AnimatedBuilder(
        animation: opacity!,
        builder: (_, child) {
          if (opacity!.value < 0.01) return child!;
          return ClipRRect(
            borderRadius: _borderRadius,
            child: BackdropFilter(filter: _blurFilter, child: child),
          );
        },
        child: blurContent,
      );
    }

    return ClipRRect(
      borderRadius: _borderRadius,
      child: BackdropFilter(filter: _blurFilter, child: blurContent),
    );
  }

  /// 按钮行：左右组 + 居中播放按钮群
  ///
  /// 三段等 flex Spacer 将播放按钮群精确置于 Row 50% 位置。
  /// 窄窗口分级隐藏：≤360 隐藏左右组，≤500 隐藏次要按钮。
  Widget _buildButtonRow(
    BuildContext context,
    AppLocalizations l10n,
    bool showSecondary,
    String prevTooltip,
    String nextTooltip,
  ) {
    final w = MediaQuery.sizeOf(context).width;
    // 仅中心播放按钮（隐藏左右组 + stop/rewind/forward）
    final ultraCompact = w <= 360;
    // 隐藏左右组，中心保留全部按钮
    final compact = !ultraCompact && w <= 500;

    if (ultraCompact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CompactCenterGroup(
            engine: engine,
            isIdle: isIdle,
            prevTooltip: prevTooltip,
            nextTooltip: nextTooltip,
            onPrevious: actions.onPrevious,
            onNext: actions.onNext,
          ),
        ],
      );
    }

    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CenterGroup(
            engine: engine,
            isIdle: isIdle,
            prevTooltip: prevTooltip,
            nextTooltip: nextTooltip,
            onPrevious: actions.onPrevious,
            onNext: actions.onNext,
          ),
        ],
      );
    }

    return Row(
      children: [
        _LeftButtonGroup(
          engine: engine,
          showSecondary: showSecondary,
          actions: actions,
        ),
        const Spacer(),
        CenterGroup(
          engine: engine,
          isIdle: isIdle,
          prevTooltip: prevTooltip,
          nextTooltip: nextTooltip,
          onPrevious: actions.onPrevious,
          onNext: actions.onNext,
        ),
        const Spacer(),
        _RightButtonGroup(
          isFullscreen: isFullscreen,
          actions: actions,
        ),
      ],
    );
  }
}

/// 左侧按钮组：播放模式 + 音量 + 倍速
class _LeftButtonGroup extends StatelessWidget {
  final PlayerEngine engine;
  final bool showSecondary;
  final PlayerActions actions;

  const _LeftButtonGroup({
    required this.engine,
    required this.showSecondary,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassButton.iconOnly(
          icon: actions.playModeIcon ?? Icons.repeat,
          tooltip: actions.playModeLabel ?? '顺序',
          onPressed: actions.onTogglePlayMode,
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

/// 超紧凑中心组：仅上一首/播放暂停/下一首（窗口 ≤360px 时）
class _CompactCenterGroup extends StatelessWidget {
  final PlayerEngine engine;
  final bool isIdle;
  final String prevTooltip;
  final String nextTooltip;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _CompactCenterGroup({
    super.key,
    required this.engine,
    required this.isIdle,
    required this.prevTooltip,
    required this.nextTooltip,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = isIdle
        ? Tokens.textPrimary.withValues(alpha: Tokens.textPrimary.a * 0.20)
        : Tokens.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassButton.iconOnly(
          icon: Icons.skip_previous,
          color: dimmed,
          onPressed: isIdle ? null : onPrevious,
          tooltip: prevTooltip,
        ),
        const SizedBox(width: Tokens.spSm),
        PlayPauseButton(engine: engine, isIdle: isIdle),
        const SizedBox(width: Tokens.spSm),
        GlassButton.iconOnly(
          icon: Icons.skip_next,
          color: dimmed,
          onPressed: isIdle ? null : onNext,
          tooltip: nextTooltip,
        ),
      ],
    );
  }
}

/// 右侧按钮组：文件、字幕、播放列表、设置、全屏
class _RightButtonGroup extends StatelessWidget {
  final bool isFullscreen;
  final PlayerActions actions;

  const _RightButtonGroup({
    required this.isFullscreen,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.onOpenFile != null)
          GlassButton.iconOnly(
            icon: Icons.folder_open,
            onPressed: actions.onOpenFile,
            tooltip: l10n.openFileTooltip,
          ),
        if (actions.onOpenSubtitle != null)
          GlassButton.iconOnly(
            icon: Icons.subtitles,
            onPressed: actions.onOpenSubtitle,
            tooltip: l10n.openSubtitle,
          ),
        if (actions.onTogglePlaylist != null)
          GlassButton.iconOnly(
            icon: Icons.queue_music,
            onPressed: actions.onTogglePlaylist,
            tooltip: l10n.playlist,
          ),
        if (actions.onSettings != null)
          GlassButton.iconOnly(
            icon: Icons.settings,
            onPressed: actions.onSettings,
            onSecondaryTapUp: actions.onSettingsSecondary != null
                ? (d) => actions.onSettingsSecondary!(context, d)
                : null,
            tooltip: l10n.settings,
          ),
        if (actions.onToggleFullscreen != null)
          GlassButton.iconOnly(
            icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            onPressed: actions.onToggleFullscreen,
            tooltip: isFullscreen ? l10n.exitFullscreen : l10n.fullscreen,
          ),
      ],
    );
  }
}
