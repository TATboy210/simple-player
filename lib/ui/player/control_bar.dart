import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/playlist/playlist.dart';
import '../theme/tokens.dart';
import '../shared/control_bar_decoration.dart';
import '../shared/edge_glow.dart';
import '../shared/glass_container.dart';
import '../shared/glass_widgets.dart';
import 'control_bar_layout.dart';
import 'control_bar_view_model.dart';
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

  /// 控制栏数据视图模型 — 路径B Commit1:从 engine 解耦的数据源 + 回调。
  final ControlBarViewModel vm;
  final PlayerActions actions;
  final Playlist playlist;
  final ValueListenable<int> playlistGeneration;
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

  /// 全屏切换回调 — 透传给 ControlBarLayout → ControlBarActions → RightButtonGroup.
  /// ControlsOverlay 传 _toggleFullscreen(setMode + 本实例 videoState route 切换).
  final VoidCallback? onToggleFullscreen;

  const ControlBar({
    super.key,
    required this.vm,
    this.actions = const PlayerActions(),
    required this.playlist,
    required this.playlistGeneration,
    this.enableBlur = true,
    this.isIdle = false,
    this.title,
    this.opacity,
    this.decoration,
    this.resizing,
    this.onSeekStart,
    this.onSeekEnd,
    this.onToggleFullscreen,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    // decoration 非空时用 DecorationTween 插值，否则直接使用 playing 装饰
    // switch 表达式消除字段 `!`
    final effectiveDecoration = switch (decoration) {
      final d? => _decorationTween.evaluate(d),
      null => _decorationPlaying,
    };

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
            vm: vm,
            actions: actions,
            playlist: playlist,
            playlistGeneration: playlistGeneration,
            isIdle: isIdle,
            title: title,
            resizing: resizing,
            onSeekStart: onSeekStart,
            onSeekEnd: onSeekEnd,
            onToggleFullscreen: onToggleFullscreen,
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
          // child 由 AnimatedBuilder child 参数传入 (blurContent, 必非空);
          // local 捕获提升消除 `!`, null 时 fallback blurContent (防御, 不触发)
          final c = child;
          if (c == null) return withBlur(blurContent);
          if (op.value < 0.01) return c;
          return withBlur(c);
        },
        child: blurContent,
      );
    }

    return withBlur(blurContent);
  }
}
