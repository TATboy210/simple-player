import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/edge_glow.dart';
import '../shared/glass_container.dart';
import '../shared/glass_widgets.dart';
import 'center_controls.dart';
import 'left_button_group.dart';
import 'player_actions.dart';
import 'progress_bar.dart';
import 'right_button_group.dart';
import 'time_range_display.dart';

class ControlBar extends StatelessWidget {
  static final _borderRadius = BorderRadius.circular(Tokens.controlBarRadius);

  /// 播放状态装饰 — 深色毛玻璃 + 蓝色微光边框（D-01: static final 缓存）
  static final _decorationPlaying = BoxDecoration(
    color: Tokens.controlBarBg,
    borderRadius: ControlBar._borderRadius,
    border: Border.all(color: Tokens.controlBarBorderWhite, width: 1),
    boxShadow: const [
      // CSS: inset 0 1px 0 rgba(255,255,255,0.04) — 顶部内高光
      BoxShadow(
        color: Tokens.controlBarBorderWhite,
        blurRadius: 0,
        spreadRadius: 0,
        offset: Offset(0, -1),
      ),
      // CSS: inset 0 -1px 0 rgba(0,0,0,0.1) — 底部内阴影
      BoxShadow(
        color: Tokens.controlBarShadowBlack,
        blurRadius: 0,
        spreadRadius: 0,
        offset: Offset(0, 1),
      ),
      // CSS: 0 8px 32px rgba(0,0,0,0.25) — 外层投影
      BoxShadow(
        color: Tokens.controlBarOuterShadow,
        blurRadius: 32,
        offset: Offset(0, 8),
      ),
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
      BoxShadow(
        color: Tokens.controlBarBorderIdle,
        blurRadius: 0,
        spreadRadius: 0,
        offset: Offset(0, -1),
      ),
      BoxShadow(
        color: Tokens.controlBarShadowBlack,
        blurRadius: 0,
        spreadRadius: 0,
        offset: Offset(0, 1),
      ),
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

  /// 窗口 resize 信号 — 透传给 ProgressBar 跳过内部 bar 重建（CB-06）
  final ValueListenable<bool>? resizing;

  const ControlBar({
    super.key,
    required this.engine,
    this.actions = const PlayerActions(),
    this.enableBlur = true,
    this.isIdle = false,
    this.title,
    this.opacity,
    this.decoration,
    this.resizing,
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
          padding: const EdgeInsets.only(
            left: Tokens.spSm,
            right: Tokens.spSm,
            bottom: 6,
          ),
          child: Stack(
            children: [
              // CSS .player-controls::before — 顶部渐变光线
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Tokens.glowTransparent,
                        Tokens.glowAccent,
                        Tokens.glowTransparent,
                      ],
                    ),
                  ),
                ),
              ),
              // 3 行等分布局：标题+时间 / 进度条 / 按钮行
              Column(
                children: [
                  // Row 1 (Top): 标题 | 时间显示
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
                  // Row 2 (Middle): ProgressBar
                  Expanded(
                    child: Center(
                      child: ProgressBar(engine: engine, resizing: resizing),
                    ),
                  ),
                  // Row 3 (Bottom): 左组 | Spacer | 中心组 | Spacer | 右组
                  Expanded(
                    child: _buildButtonRow(
                      context,
                      l10n,
                      prevTooltip,
                      nextTooltip,
                    ),
                  ),
                ],
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
      child: BackdropFilter(filter: GlassTier.normal.blurFilter, child: child),
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

  /// 按钮行：左组 | Spacer | 中心组 | Spacer | 右组
  ///
  /// 三段等 flex Spacer 将播放按钮群精确置于 Row 50% 位置。
  Widget _buildButtonRow(
    BuildContext context,
    AppLocalizations l10n,
    String prevTooltip,
    String nextTooltip,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          LeftButtonGroup(engine: engine, actions: actions),
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
          RightButtonGroup(actions: actions),
        ],
      ),
    );
  }
}
