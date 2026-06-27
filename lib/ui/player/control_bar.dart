import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:player_engine/player_engine.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/edge_glow.dart';
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
    sigmaX: Tokens.glassBlurThick,
    sigmaY: Tokens.glassBlurThick,
  );

  /// CSS: .player-controls — rgba(14,17,30,0.6) + blur(24px)
  static final _decoration = BoxDecoration(
    color: Tokens.controlBarBg,
    borderRadius: ControlBar._borderRadius,
    border: Border.all(color: Tokens.controlBarBorderWhite, width: 1),
    boxShadow: const [
      // CSS: inset 0 1px 0 rgba(255,255,255,0.04) — 顶部内高光
      BoxShadow(color: Tokens.controlBarBorderWhite, blurRadius: 0, spreadRadius: 0, offset: Offset(0, -1)),
      // CSS: inset 0 -1px 0 rgba(0,0,0,0.1) — 底部内阴影
      BoxShadow(color: Tokens.controlBarShadowBlack, blurRadius: 0, spreadRadius: 0, offset: Offset(0, 1)),
      // CSS: 0 8px 32px rgba(0,0,0,0.25) — 外层投影
      BoxShadow(color: Tokens.controlBarOuterShadow, blurRadius: 32, offset: Offset(0, 8)),
      // CSS: 0 0 0 1px rgba(80,130,255,0.04) — 蓝色外环
      BoxShadow(color: Tokens.glowOuterRing, blurRadius: 1, spreadRadius: 1),
    ],
  );

  final PlayerEngine engine;
  final PlayerActions actions;
  final bool enableBlur;
  final bool isIdle;

  /// 视频标题（显示在 Row 1 左侧）
  final String? title;

  /// 淡入淡出动画 — opacity=0 时跳过 BackdropFilter
  final Animation<double>? opacity;

  /// 窗口 resize 信号 — true 时跳过 BackdropFilter 避免 GPU readback 卡顿
  final ValueListenable<bool>? resizing;

  const ControlBar({
    super.key,
    required this.engine,
    this.actions = const PlayerActions(),
    this.enableBlur = true,
    this.isIdle = false,
    this.title,
    this.opacity,
    this.resizing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prevTooltip = l10n.previousTrack;
    final nextTooltip = l10n.nextTrack;

    // 交互层 — 按钮、进度条、标题（不受 BackdropFilter 影响）
    final interactive = Material(
      color: Colors.transparent,
      child: SizedBox(
        height: Tokens.controlBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final showSecondary = w >= Tokens.compactBreakpoint;

              return Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title ?? '',
                            style: const TextStyle(
                              color: Tokens.textPrimary,
                              fontSize: Tokens.fontBody,
                              fontWeight: Tokens.weightMedium,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TimeRangeDisplay(engine: engine),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _ProgressRow(engine: engine),
                    ),
                  ),
                  Expanded(
                    child: _buildButtonRow(
                      context,
                      l10n,
                      showSecondary,
                      prevTooltip,
                      nextTooltip,
                      w,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // 背景层 — 纯视觉装饰（BackdropFilter 仅作用于此）
    final background = Container(
      height: Tokens.controlBarHeight,
      decoration: _decoration,
    );

    final content = EdgeGlow(
      variant: EdgeGlowVariant.gradient,
      borderRadius: _borderRadius,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: const [
                    Color(0x005082FF),
                    Tokens.glowAccent,
                    Color(0x005082FF),
                  ],
                ),
              ),
            ),
          ),
          interactive,
        ],
      ),
    );

    if (!enableBlur) return RepaintBoundary(child: content);

    final resizingNotifier = resizing;
    if (resizingNotifier != null) {
      return AnimatedBuilder(
        animation: resizingNotifier,
        builder: (_, child) {
          if (resizingNotifier.value) return RepaintBoundary(child: child!);
          return _buildBlur(background, child!);
        },
        child: content,
      );
    }

    return _buildBlur(background, content);
  }

  /// BackdropFilter 仅包裹背景层，交互层不受影响
  Widget _buildBlur(Widget background, Widget foreground) {
    Widget withBlur(Widget bg) => ClipRRect(
      borderRadius: _borderRadius,
      child: BackdropFilter(
        filter: _blurFilter,
        child: bg,
      ),
    );

    final opacityNotifier = opacity;
    Widget blurredBg;
    if (opacityNotifier != null) {
      blurredBg = AnimatedBuilder(
        animation: opacityNotifier,
        builder: (_, child) {
          if (opacityNotifier.value < 0.01) return child!;
          return withBlur(child!);
        },
        child: RepaintBoundary(child: background),
      );
    } else {
      blurredBg = withBlur(RepaintBoundary(child: background));
    }

    return Stack(
      children: [blurredBg, foreground],
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
    double availableWidth,
  ) {
    // 仅中心播放按钮（隐藏左右组 + stop/rewind/forward）
    final ultraCompact = availableWidth <= Tokens.breakpointUltraCompact;
    // 隐藏左右组，中心保留全部按钮
    final compact = !ultraCompact && availableWidth <= Tokens.compactBreakpoint;

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
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
          actions: actions,
        ),
      ],
    ),
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
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassButton.iconOnly(
          icon: actions.playModeIcon ?? Icons.repeat,
          tooltip: actions.playModeLabel ?? l10n.playModeLoopAll,
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

/// 右侧按钮组：文件、字幕、播放列表、设置
class _RightButtonGroup extends StatelessWidget {
  final PlayerActions actions;

  const _RightButtonGroup({
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
                ? (d) => actions.onSettingsSecondary?.call(context, d)
                : null,
            tooltip: l10n.settings,
          ),
        if (actions.onToggleFullscreen != null)
          GlassButton.iconOnly(
            icon: Icons.fullscreen,
            onPressed: actions.onToggleFullscreen,
            tooltip: l10n.shortcutFullscreen,
          ),
      ],
    );
  }
}

/// ProgressBar 圆角边框容器 — hover 时边框高亮反馈
class _ProgressRow extends StatelessWidget {
  final PlayerEngine engine;

  const _ProgressRow({required this.engine});

  @override
  Widget build(BuildContext context) {
    // 隐形边框 1px + padding 1px = 总共 2px，进度条居中
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Colors.transparent, width: 1),
      ),
      child: ProgressBar(engine: engine),
    );
  }
}
