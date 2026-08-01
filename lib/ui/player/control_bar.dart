import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../shared/control_bar_decoration.dart';
import '../shared/edge_glow.dart';
import '../shared/glass_container.dart';
import '../shared/glass_widgets.dart';
import 'control_bar_layout.dart';
import 'player_actions.dart';

class ControlBar extends StatelessWidget {
  static final _borderRadius = BorderRadius.circular(Tokens.controlBarRadius);

  /// 播放状态装饰 — 深色毛玻璃 + 蓝色微光边框（Phase 31 D-01: 提取至共享
  /// [ControlBarDecoration]，本类 static final 缓存 no-arg 实例保持热路径零重建）
  static final _decorationPlaying = ControlBarDecoration.playing();

  /// 空状态装饰 — 2% 淡蓝描边（idle，比 playing 淡）+ 4 个 BoxShadow
  /// （Phase 31 D-03: idle 随 playing 一并提取至共享，保持 shared/local 不混用）
  static final _decorationIdle = ControlBarDecoration.idle();

  /// DecorationTween — playing/idle 状态插值（Phase 31 D-03: tween 保留本地，
  /// 仅 begin/end 源装饰改为共享工厂；DecorationTween 按 index lerp shadow 列表，
  /// idle 的 4-shadow padding 由 ControlBarDecoration.idle 保证）
  static final _decorationTween = DecorationTween(
    begin: _decorationIdle,
    end: _decorationPlaying,
  );

  final MediaEngine engine;
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

  /// 进度条 seek 开始/结束回调 — 透传给 ProgressBar,通知 AutoHideController
  /// 在 seek 期间冻结/重启隐藏计时
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  /// 非 seek 子控件的交互边界，透传至 Overlay 统一管理自动隐藏。
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

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
    this.onSeekStart,
    this.onSeekEnd,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
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
            bottom: Tokens.controlBarContentBottomPadding,
          ),
          child: ControlBarLayout(
            engine: engine,
            actions: actions,
            isIdle: isIdle,
            title: title,
            resizing: resizing,
            onSeekStart: onSeekStart,
            onSeekEnd: onSeekEnd,
            onInteractionStart: onInteractionStart,
            onInteractionEnd: onInteractionEnd,
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
}
