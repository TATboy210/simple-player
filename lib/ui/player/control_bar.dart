import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/edge_glow.dart';
import '../shared/glass_container.dart';
import '../shared/glass_widgets.dart';
import 'center_controls.dart';
import 'player_actions.dart';
import 'progress_bar.dart';
import 'speed_button.dart';
import 'time_range_display.dart';
import 'volume_controls.dart';

class ControlBar extends StatelessWidget {
  static final _borderRadius = BorderRadius.circular(Tokens.controlBarRadius);

  /// 播放状态装饰 — 深色毛玻璃 + 蓝色微光边框（D-01: static final 缓存）
  static final _decorationPlaying = BoxDecoration(
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

  /// 空状态装饰 — 2% 淡蓝描边（idle，比 playing 淡，per D-18）+ 补齐 4 个 BoxShadow（D-01/D-04）
  static final _decorationIdle = BoxDecoration(
    color: Tokens.controlBarBg,
    borderRadius: ControlBar._borderRadius,
    border: Border.all(color: Tokens.controlBarBorderIdle, width: 1),
    boxShadow: const [
      BoxShadow(color: Tokens.controlBarBorderIdle, blurRadius: 0, spreadRadius: 0, offset: Offset(0, -1)),
      BoxShadow(color: Tokens.controlBarShadowBlack, blurRadius: 0, spreadRadius: 0, offset: Offset(0, 1)),
      // 补齐 4 个 BoxShadow，让 DecorationTween 插值更平滑（D-04）
      BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0),
      BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0),
    ],
  );

  /// DecorationTween — playing/idle 状态插值（D-01/D-02）
  static final _decorationTween = DecorationTween(
    begin: _decorationIdle,
    end: _decorationPlaying,
  );

  final EngineState engine;
  final PlayerActions actions;
  final bool enableBlur;
  final bool isIdle;

  /// 视频标题（显示在 Row 1 左侧）
  final String? title;

  /// 淡入淡出动画 — opacity=0 时跳过 BackdropFilter
  final Animation<double>? opacity;

  /// 装饰动画 — 驱动 playing/idle 状态切换的 DecorationTween 插值（D-01/D-02）
  final Animation<double>? decoration;

  const ControlBar({
    super.key,
    required this.engine,
    this.actions = const PlayerActions(),
    this.enableBlur = true,
    this.isIdle = false,
    this.title,
    this.opacity,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prevTooltip = l10n.previousTrack;
    final nextTooltip = l10n.nextTrack;

    // decoration 非空时用 DecorationTween 插值，否则直接使用 playing 装饰
    final effectiveDecoration = decoration != null
        ? _decorationTween.evaluate(decoration!)
        : _decorationPlaying;

    final content = EdgeGlow(
      variant: EdgeGlowVariant.gradient,
      borderRadius: _borderRadius,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: Tokens.controlBarHeight,
          decoration: effectiveDecoration,
          padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
          child: Stack(
            children: [
              // CSS .player-controls::before — 顶部渐变光线
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [
                        Tokens.glowTransparent,
                        Tokens.glowAccent,
                        Tokens.glowTransparent,
                      ],
                    ),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final showSecondary = w >= Tokens.compactBreakpoint;

                  return Column(
                    children: [
                      // Row 1 (Top): 标题 | 时间显示 — 等分空间
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
                      // Row 2 (Middle): ProgressBar — 等分空间
                      Expanded(
                        child: Center(
                          child: _ProgressRow(engine: engine),
                        ),
                      ),
                      // Row 3 (Bottom): Left | Spacer | Center | Spacer | Right — 等分空间
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
            ],
          ),
        ),
      ),
    );

    if (!enableBlur) return RepaintBoundary(child: content);

    // opacity 渐变由 _animController 驱动（ControlsOverlay 传入），
    // _buildBlur 中 opacity < 0.01 时自动跳过 BackdropFilter，避免 resize 期间 GPU readback 卡顿
    return _buildBlur(content);
  }

  Widget _buildBlur(Widget content) {
    // opacity=0 时跳过 BackdropFilter（fade-out 尾部帧零 GPU readback）
    final blurContent = RepaintBoundary(child: content);

    // P1 优化：移除 ColorFilter.matrix 饱和度矩阵（每帧 GPU pass）
    Widget withBlur(Widget child) => ClipRRect(
      borderRadius: _borderRadius,
      child: BackdropFilter(
        filter: GlassTier.normal.blurFilter,
        child: child,
      ),
    );

    final op = opacity;
    if (op != null) {
      return AnimatedBuilder(
        animation: op,
        builder: (_, child) {
          if (op.value < 0.01) return child!;
          return withBlur(child!);
        },
        child: blurContent,
      );
    }

    return withBlur(blurContent);
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
  final EngineState engine;
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
  final EngineState engine;
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
                ? (d) => actions.onSettingsSecondary!(context, d)
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
  final EngineState engine;

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
