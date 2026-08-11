import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  final bool enableBlur;
  final bool isIdle;
  final ValueListenable<bool>? isIdleListenable;

  /// 视频标题（显示在 Row 1 左侧）。
  ///
  /// 直接传值用于独立使用的控制栏；播放器路径使用 [titleListenable]，
  /// 将文件名更新限制在标题行。
  final String? title;
  final ValueListenable<String>? titleListenable;

  /// 淡入淡出动画 — opacity=0 时停用 BackdropFilter，但保持祖先链挂载。
  final Animation<double>? opacity;

  /// 装饰动画 — 驱动 playing/idle 状态切换的 DecorationTween 插值（D-01/D-02）
  final Animation<double>? decoration;

  /// 窗口 resize 信号 — 同时停用实时背景 blur，并让 ProgressBar 冻结绘制几何。
  final ValueListenable<bool>? resizing;

  /// 进度条 seek 开始/结束回调 — 透传给 ProgressBar,通知 AutoHideController
  /// 在 seek 期间冻结/重启隐藏计时
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  /// 非 seek 子控件的交互边界，透传至 Overlay 统一管理自动隐藏。
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  /// 全屏切换回调 — 透传给 ControlBarLayout → ControlBarActions → RightButtonGroup.
  /// PlayerVideoControls 传入的全屏切换回调，同时同步窗口和 video route。
  final VoidCallback? onToggleFullscreen;

  const ControlBar({
    super.key,
    required this.vm,
    this.actions = const PlayerActions(),
    this.enableBlur = true,
    this.isIdle = false,
    this.isIdleListenable,
    this.title,
    this.titleListenable,
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
            isIdle: isIdle,
            isIdleListenable: isIdleListenable,
            title: title,
            titleListenable: titleListenable,
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

    // opacity 渐变由 PlayerVideoControls 的动画控制器驱动；
    // 淡出尾部只停用滤镜，保持可交互后代的祖先拓扑稳定。
    return _buildBlur(content);
  }

  Widget _buildBlur(Widget content) {
    return _ControlBarBlur(
      content: content,
      opacity: opacity,
      resizing: resizing,
    );
  }
}

/// 控制栏的模糊壳层。
///
/// 将 opacity 与 resize 信号的合并监听器缓存到 State 中，避免 [ControlBar]
/// 因标题或视图模型更新而重新 build 时反复分配并重新接线 [Listenable.merge]。
/// 控件祖先链仍保持 ClipRRect → BackdropFilter → content 不变。
class _ControlBarBlur extends StatefulWidget {
  final Widget content;
  final Animation<double>? opacity;
  final ValueListenable<bool>? resizing;

  const _ControlBarBlur({
    required this.content,
    required this.opacity,
    required this.resizing,
  });

  @override
  State<_ControlBarBlur> createState() => _ControlBarBlurState();
}

class _ControlBarBlurState extends State<_ControlBarBlur> {
  Listenable? _animation;

  @override
  void initState() {
    super.initState();
    _animation = _mergeSignals(widget.opacity, widget.resizing);
  }

  @override
  void didUpdateWidget(covariant _ControlBarBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opacity != widget.opacity ||
        oldWidget.resizing != widget.resizing) {
      _animation = _mergeSignals(widget.opacity, widget.resizing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    final blurContent = RepaintBoundary(child: widget.content);
    if (animation == null) {
      return _withBlur(blurContent, enabled: true);
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final isVisible = (widget.opacity?.value ?? 1) >= 0.01;
        final isResizing = widget.resizing?.value ?? false;
        return _withBlur(
          child ?? blurContent,
          enabled: isVisible && !isResizing,
        );
      },
      child: blurContent,
    );
  }

  Listenable? _mergeSignals(
    Animation<double>? opacity,
    ValueListenable<bool>? resizing,
  ) {
    return switch ((opacity, resizing)) {
      (final opacity?, final resize?) => Listenable.merge([opacity, resize]),
      (final opacity?, null) => opacity,
      (null, final resize?) => resize,
      (null, null) => null,
    };
  }

  Widget _withBlur(Widget child, {required bool enabled}) => ClipRRect(
    borderRadius: ControlBar._borderRadius,
    child: BackdropFilter(
      filter: GlassTier.normal.blurFilter,
      enabled: enabled,
      child: child,
    ),
  );
}
