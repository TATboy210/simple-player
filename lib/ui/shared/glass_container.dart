import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 毛玻璃模糊层级
enum GlassTier {
  /// 标题栏 — 轻模糊，低 GPU 开销
  thin(Tokens.glassBlurThin),

  /// 控制栏 — 默认模糊
  normal(Tokens.glassBlur),

  /// 弹窗/对话框 — 深模糊
  thick(Tokens.glassBlurThick);

  final double sigma;
  const GlassTier(this.sigma);
}

/// 毛玻璃容器 — 可复用的 Glassmorphism 基础组件
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Border? border;
  final GlassTier tier;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.border,
    this.tier = GlassTier.normal,
  });

  @override
  Widget build(BuildContext context) {
    final rRect = borderRadius ?? BorderRadius.circular(Tokens.radiusLarge);

    final content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Tokens.bgGlass,
        borderRadius: rRect,
        border: border ?? Border.all(color: Tokens.borderHighlight, width: 1),
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: rRect,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: tier.sigma, sigmaY: tier.sigma),
        child: RepaintBoundary(child: content),
      ),
    );
  }
}

/// 毛玻璃风格按钮 — 支持 icon+label 和 icon-only 两种模式
///
/// label 为 null 时切换为 icon-only 模式（圆形 48×48）。
///
/// 设计：GestureDetector + MouseRegion 在最外层（BackdropFilter 之外），
/// 确保 Windows 上 hit test 不被 ClipRRect/BackdropFilter 拦截。
class GlassButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool isPrimary;
  final bool enabled;
  final VoidCallback onPressed;

  const GlassButton({
    super.key,
    required this.icon,
    this.label,
    this.tooltip,
    this.isPrimary = false,
    this.enabled = true,
    required this.onPressed,
  });

  /// 便捷构造：icon-only 模式
  const GlassButton.iconOnly({
    super.key,
    required this.icon,
    this.tooltip,
    this.isPrimary = false,
    this.enabled = true,
    required this.onPressed,
  }) : label = null;

  bool get _isIconOnly => label == null;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  final _hovered = ValueNotifier<bool>(false);
  final _pressed = ValueNotifier<bool>(false);
  late final Listenable _interaction;

  @override
  void initState() {
    super.initState();
    _interaction = Listenable.merge([_hovered, _pressed]);
  }

  @override
  void dispose() {
    _hovered.dispose();
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isPrimary
        ? Tokens.textPrimary
        : Tokens.textSecondary;

    // 静态子组件 — 只构建一次，hover/press 时复用
    final content = widget._isIconOnly
        ? GlassContainer(
            width: Tokens.iconButtonSizeLarge,
            height: Tokens.iconButtonSizeLarge,
            borderRadius: BorderRadius.circular(Tokens.iconButtonRadius),
            child: Icon(widget.icon, size: 20, color: textColor),
          )
        : GlassContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.iconButtonPaddingH,
              vertical: Tokens.iconButtonPaddingV,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: textColor),
                const SizedBox(width: Tokens.spSm),
                Text(
                  widget.label!,
                  style: TextStyle(
                    fontSize: Tokens.fontBody,
                    fontWeight: Tokens.weightMedium,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _pressed.value = true : null,
      onTap: widget.enabled
          ? () {
              _pressed.value = false;
              widget.onPressed();
            }
          : null,
      onTapCancel: () => _pressed.value = false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _hovered.value = true,
        onExit: (_) {
          _hovered.value = false;
          _pressed.value = false;
        },
        child: Tooltip(
          message: widget.tooltip ?? widget.label ?? '',
          child: AnimatedBuilder(
            animation: _interaction,
            builder: (context, child) {
              final scale = _pressed.value
                  ? Tokens.pressScale
                  : (_hovered.value ? Tokens.hoverScale : 1.0);
              return AnimatedContainer(
                duration: const Duration(
                  milliseconds: Tokens.durationFast,
                ),
                transform: Matrix4.diagonal3Values(scale, scale, 1),
                transformAlignment: Alignment.center,
                child: child,
              );
            },
            child: content,
          ),
        ),
      ),
    );
  }
}
