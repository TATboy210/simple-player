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
import 'control_bar_layout_mode.dart';

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

  /// 窗口 resize 信号 — 让 ProgressBar 冻结绘制几何（静止型冻结，无视觉跳变）；
  /// 玻璃模糊与辉光不随 resize 降级（视觉恒定策略，见 [_ControlBarBlur]）。
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

    // 视觉恒定策略：不再向 EdgeGlow 注入 resize 降级信号 — 辉光在拖动全程
    // 保持完整渲染（组件内部分支保留，供标题栏等其他场景使用）。
    final content = EdgeGlow(
      variant: EdgeGlowVariant.gradient,
      borderRadius: _borderRadius,
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Match the child LayoutBuilder's post-padding width so the shell
            // height and its content always select the same responsive mode.
            final contentWidth = constraints.maxWidth - (Tokens.spSm * 2);
            final mode = ControlBarLayoutMode.fromWidth(contentWidth);
            final height = switch (mode) {
              ControlBarLayoutMode.normal => Tokens.controlBarHeight,
              ControlBarLayoutMode.minimal => Tokens.controlBarHeightMinimal,
            };
            return Container(
              height: height,
              decoration: effectiveDecoration,
              padding: const EdgeInsets.only(
                left: Tokens.spSm,
                right: Tokens.spSm,
                bottom: Tokens.controlBarContentBottomPadding,
              ),
              child: ControlBarLayout(
                vm: vm,
                actions: actions,
                mode: mode,
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
            );
          },
        ),
      ),
    );

    if (!enableBlur) return RepaintBoundary(child: content);

    // opacity 渐变由 PlayerVideoControls 的动画控制器驱动；
    // 淡出尾部只停用滤镜，保持可交互后代的祖先拓扑稳定。
    return _buildBlur(content);
  }

  Widget _buildBlur(Widget content) {
    return _ControlBarBlur(content: content, opacity: opacity);
  }
}

/// 控制栏的模糊壳层。
///
/// 视觉恒定策略：[BackdropFilter] 在整个 resize 会话中**保持启用** — 历史上
/// resize 时停用滤镜以规避 GPU readback，但实测证明 raster 尖峰主因为视频
/// 纹理采样（textureIdChanges=0），且关闭/恢复会造成拖动始末的玻璃质感硬
/// 跳变。现在 blur 只随自动隐藏透明度启停（不可见即停用采样）；`resizing`
/// 信号仅由 ProgressBar / OsdOverlay 等静止型冻结消费，不再进入本层。
class _ControlBarBlur extends StatefulWidget {
  final Widget content;
  final Animation<double>? opacity;

  const _ControlBarBlur({required this.content, this.opacity});

  @override
  State<_ControlBarBlur> createState() => _ControlBarBlurState();
}

class _ControlBarBlurState extends State<_ControlBarBlur> {
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _animation = widget.opacity;
  }

  @override
  void didUpdateWidget(covariant _ControlBarBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 单一监听源（opacity），引用替换时同步即可 — 原 Listenable.merge 接线
    // 随 resize 降级分支一并移除。
    if (oldWidget.opacity != widget.opacity) {
      _animation = widget.opacity;
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
        return _withBlur(
          child ?? blurContent,
          // 仅透明度决定滤镜启停；resize 会话期间恒定启用。
          enabled: (widget.opacity?.value ?? 1) >= 0.01,
        );
      },
      child: blurContent,
    );
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
