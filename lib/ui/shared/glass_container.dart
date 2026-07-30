import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// 毛玻璃模糊层级
///
/// 保留 3 个层级（thin/normal/thick），不合并为 2 个。
/// thin(8) 和 normal(10) 之间仅 2 sigma 差距，但在 4K 显示器上
/// 标题栏和控制栏的模糊层次仍有可辨别的视觉区分。
/// 额外一个 enum 值的维护成本可忽略，视觉层次收益值得保留。（D-15）
enum GlassTier {
  /// 标题栏 — 轻模糊，低 GPU 开销
  thin(Tokens.glassBlurThin),

  /// 控制栏 — 默认模糊
  normal(Tokens.glassBlur),

  /// 弹窗/对话框 — 与 normal 相同（10 vs 12px 差异不可感知，已合并）
  thick(Tokens.glassBlur);

  final double sigma;
  const GlassTier(this.sigma);

  /// 获取缓存的 ImageFilter 实例 — 不可变对象，生命周期与应用一致（D-10）
  ui.ImageFilter get blurFilter => switch (this) {
    GlassTier.thin => _thinBlur,
    GlassTier.normal => _normalBlur,
    GlassTier.thick => _thickBlur,
  };

  /// 缓存的 ImageFilter 实例 — 避免每次 build 创建新对象（D-10/D-11）
  static final ui.ImageFilter _thinBlur = ui.ImageFilter.blur(
    sigmaX: Tokens.glassBlurThin,
    sigmaY: Tokens.glassBlurThin,
  );
  static final ui.ImageFilter _normalBlur = ui.ImageFilter.blur(
    sigmaX: Tokens.glassBlur,
    sigmaY: Tokens.glassBlur,
  );
  static final ui.ImageFilter _thickBlur = ui.ImageFilter.blur(
    sigmaX: Tokens.glassBlurThick,
    sigmaY: Tokens.glassBlurThick,
  );
}

/// 毛玻璃容器 — 可复用的 Glassmorphism 基础组件
///
/// 性能优化：
/// - [opacity] 非空且 value < 0.01 时跳过 BackdropFilter（D-13）
/// - [blurEnabled] 为 false 时跳过 BackdropFilter，仅渲染 Container（D-14）
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final GlassTier tier;

  /// 淡入淡出动画 — opacity=0 时跳过 BackdropFilter GPU readback（D-13）
  final ValueListenable<double>? opacity;

  /// 低配硬件降级模式 — false 时跳过 BackdropFilter（D-14）
  final bool blurEnabled;

  /// 窗口 resize 信号 — true 时跳过 BackdropFilter 避免 GPU readback 卡顿
  final ValueListenable<bool>? resizing;

  /// 背景色 — 默认 Tokens.bgGlass，可传入 idle token 实现状态感知
  final Color? backgroundColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.tier = GlassTier.normal,
    this.opacity,
    this.blurEnabled = true,
    this.resizing,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final rRect = borderRadius ?? BorderRadius.circular(Tokens.radiusLarge);

    final content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Tokens.bgGlass,
        borderRadius: rRect,
        border: border ?? Border.all(color: Tokens.borderHighlight, width: 1),
      ),
      child: child,
    );

    // margin 在最外层，确保不被 BackdropFilter 裁剪
    Widget result;

    // 降级模式：跳过 BackdropFilter，仅渲染半透明背景（D-14）
    if (!blurEnabled) {
      result = ClipRRect(
        borderRadius: rRect,
        child: RepaintBoundary(child: content),
      );
    } else if (resizing != null) {
      // resize 期间跳过 BackdropFilter — 避免 GPU readback 卡顿
      final resizingNotifier = resizing!;
      result = AnimatedBuilder(
        animation: resizingNotifier,
        builder: (_, child) {
          if (resizingNotifier.value) {
            return ClipRRect(
              borderRadius: rRect,
              child: RepaintBoundary(child: child),
            );
          }
          return _buildBlurContent(rRect, child!);
        },
        child: content,
      );
    } else {
      result = _buildBlurContent(rRect, content);
    }

    // margin 包裹在最外层，确保毛玻璃裁剪不影响间距
    if (margin != null) {
      return Padding(padding: margin!, child: result);
    }
    return result;
  }

  Widget _buildBlurContent(BorderRadius rRect, Widget content) {
    final blurContent = RepaintBoundary(child: content);
    // 使用缓存的 ImageFilter 实例，避免每次 build 创建新对象（D-10/D-11）
    final blurFilter = tier.blurFilter;

    // opacity < 0.01 时跳过 BackdropFilter GPU readback（D-13）
    final opacityNotifier = opacity;
    if (opacityNotifier != null) {
      return AnimatedBuilder(
        animation: opacityNotifier,
        builder: (_, child) {
          if (opacityNotifier.value < 0.01) return child!;
          return ClipRRect(
            borderRadius: rRect,
            child: BackdropFilter(filter: blurFilter, child: child),
          );
        },
        child: blurContent,
      );
    }

    return ClipRRect(
      borderRadius: rRect,
      child: BackdropFilter(filter: blurFilter, child: blurContent),
    );
  }
}

/// 毛玻璃风格按钮 — 双模式 StatefulWidget
///
/// - label 非空 → GlassContainer + Material + InkWell（带模糊背景）
/// - label 为 null（iconOnly 构造）→ SizedBox + Material + InkWell（轻量无模糊）
///
/// 悬停/按压缩放反馈（Phase 6）：
/// - hover → scale 1.02（Tokens.hoverScale）
/// - press → scale 0.98（Tokens.pressScale）
/// - disabled → cursor=basic, 无缩放（Phase 4）
class GlassButton extends StatefulWidget {
  static final _radiusBtn = BorderRadius.circular(Tokens.radiusBtn);
  static final _radiusIcon = BorderRadius.circular(Tokens.iconButtonRadius);

  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool isPrimary;
  final bool enabled;
  final VoidCallback? onPressed;
  final void Function(TapUpDetails details)? onSecondaryTapUp;
  final double iconSize;
  final Color? color;
  final Widget? child;

  /// 可选的键盘焦点节点；省略时按钮会拥有一个生命周期内稳定的内部节点。
  final FocusNode? focusNode;

  /// 是否在挂载后自动请求键盘焦点。
  final bool autofocus;

  /// 屏幕阅读器使用的明确按钮名称；未提供时回退至 tooltip 或 label。
  final String? semanticsLabel;

  /// 可选的切换状态，例如播放/暂停按钮当前是否处于播放状态。
  final bool? semanticsToggled;

  /// 焦点状态变化回调，供组合控件同步局部视觉状态。
  final ValueChanged<bool>? onFocusChange;

  const GlassButton({
    super.key,
    required this.icon,
    this.label,
    this.tooltip,
    this.isPrimary = false,
    this.enabled = true,
    required this.onPressed,
    this.onSecondaryTapUp,
    this.iconSize = Tokens.iconLg,
    this.color,
    this.child,
    this.focusNode,
    this.autofocus = false,
    this.semanticsLabel,
    this.semanticsToggled,
    this.onFocusChange,
  });

  /// 便捷构造：icon-only 模式（轻量，无 BackdropFilter）
  const GlassButton.iconOnly({
    super.key,
    required this.icon,
    this.tooltip,
    this.isPrimary = false,
    this.enabled = true,
    required this.onPressed,
    this.onSecondaryTapUp,
    this.iconSize = Tokens.iconLg,
    this.color,
    this.child,
    this.focusNode,
    this.autofocus = false,
    this.semanticsLabel,
    this.semanticsToggled,
    this.onFocusChange,
  }) : label = null;

  bool get _isIconOnly => label == null;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;
  late final FocusNode _internalFocusNode;
  bool _focused = false;

  /// 外部节点由调用方管理；未提供时按钮持有并释放内部节点。
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  /// 有效可用性 — 同时要求 [Widget.enabled] 且 [GlassButton.onPressed] 非 null。
  ///
  /// P0 修复:原仅判 `widget.enabled`(默认 true),onPressed=null 时按钮仍显示
  /// click cursor / hover / 缩放,但 InkWell.onTap=null(点不动)—— 视觉可用与
  /// 命中可用语义错位。统一用 `_effectiveEnabled` 驱动 onTap / MouseCursor /
  /// hoverColor / 缩放反馈,使"看起来可用 ⇔ 真的可点"。
  bool get _effectiveEnabled => widget.enabled && widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: Tokens.durationFast),
      lowerBound: Tokens.pressScale,
      upperBound: Tokens.hoverScale,
      value: 1.0,
    );
    _scaleAnim = _scaleController;
    _internalFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _internalFocusNode.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovering) {
    if (!_effectiveEnabled) return;
    _scaleController.animateTo(hovering ? Tokens.hoverScale : 1.0);
  }

  void _onTapDown(TapDownDetails _) {
    if (!_effectiveEnabled) return;
    _scaleController.value = Tokens.pressScale;
  }

  void _onTapUp(TapUpDetails _) {
    if (!_effectiveEnabled) return;
    _scaleController.animateTo(1.0);
  }

  void _onTapCancel() {
    if (!_effectiveEnabled) return;
    _scaleController.animateTo(1.0);
  }

  /// 同步焦点高亮，且把状态通知给需要组合视觉的调用方。
  void _handleFocusChanged(bool focused) {
    if (_focused == focused) return;
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
  }

  /// 提供可遍历焦点、键盘激活和单一语义节点，不改变被包装控件的几何。
  Widget _buildInteractive(Widget child) {
    final semanticLabel =
        widget.semanticsLabel ?? widget.tooltip ?? widget.label;
    // 边框绘制在既有边界内；透明时仍占用同一绘制槽位，焦点切换不改变布局。
    final decoratedChild = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: _focused ? Tokens.controlBarBorderWhite : Colors.transparent,
          width: 1,
        ),
        borderRadius: widget._isIconOnly
            ? GlassButton._radiusBtn
            : GlassButton._radiusIcon,
      ),
      child: child,
    );
    final semantics = Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      button: true,
      enabled: _effectiveEnabled,
      toggled: widget.semanticsToggled,
      onTap: _effectiveEnabled ? widget.onPressed : null,
      child: decoratedChild,
    );

    if (!_effectiveEnabled) {
      return ExcludeFocus(child: IgnorePointer(child: semantics));
    }

    return FocusableActionDetector(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChanged,
      onShowFocusHighlight: _handleFocusChanged,
      // 将快捷键绑定在拥有焦点的探测器上，确保事件在到达全局播放器
      // 快捷键之前被转换为本地 ActivateIntent 并消费。
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: semantics,
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = widget._isIconOnly ? _buildIconOnly() : _buildLabel();
    return _buildInteractive(button);
  }

  /// icon-only 轻量路径：SizedBox + Material + InkWell，无 BackdropFilter
  Widget _buildIconOnly() {
    final effectiveColor =
        widget.color ??
        (widget.isPrimary ? Tokens.textPrimary : Tokens.textSecondary);
    final content =
        widget.child ??
        Icon(widget.icon, size: widget.iconSize, color: effectiveColor);

    final button = Tooltip(
      message: widget.tooltip ?? '',
      waitDuration: const Duration(milliseconds: Tokens.tooltipDelayShort),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: Colors.transparent,
          borderRadius: GlassButton._radiusBtn,
          child: InkWell(
            onTap: _effectiveEnabled ? widget.onPressed : null,
            onSecondaryTapUp: widget.onSecondaryTapUp,
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            hoverColor: _effectiveEnabled ? Tokens.bgHover : Colors.transparent,
            highlightColor: Colors.transparent,
            borderRadius: GlassButton._radiusBtn,
            splashFactory: NoSplash.splashFactory,
            child: Center(child: content),
          ),
        ),
      ),
    );

    return MouseRegion(
      cursor: _effectiveEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: ScaleTransition(scale: _scaleAnim, child: button),
    );
  }

  /// label 路径：GlassContainer + Material + InkWell，带模糊背景
  Widget _buildLabel() {
    final effectiveColor =
        widget.color ??
        (widget.isPrimary ? Tokens.textPrimary : Tokens.textSecondary);

    final content = GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.iconButtonPaddingH,
        vertical: Tokens.iconButtonPaddingV,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18, color: effectiveColor),
          const SizedBox(width: Tokens.spSm),
          Text(
            widget.label ?? '',
            style: TextStyle(
              fontSize: Tokens.fontBody,
              fontWeight: Tokens.weightMedium,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );

    final button = Material(
      color: Colors.transparent,
      borderRadius: GlassButton._radiusIcon,
      child: InkWell(
        onTap: _effectiveEnabled ? widget.onPressed : null,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        hoverColor: _effectiveEnabled ? Tokens.bgHover : Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: GlassButton._radiusIcon,
        splashFactory: NoSplash.splashFactory,
        child: Tooltip(
          message: widget.tooltip ?? widget.label ?? '',
          waitDuration: const Duration(milliseconds: Tokens.tooltipDelayShort),
          child: content,
        ),
      ),
    );

    return MouseRegion(
      cursor: _effectiveEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: ScaleTransition(scale: _scaleAnim, child: button),
    );
  }
}
