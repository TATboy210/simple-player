import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'resize_notifier.dart';
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
///
/// [respectResizeState] 为 true 时，窗口 resize 期间跳过 BackdropFilter
/// 以降低 GPU 开销（与 CustomTitleBar / ControlBar 行为一致）。
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Border? border;
  final GlassTier tier;
  final bool respectResizeState;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.border,
    this.tier = GlassTier.normal,
    this.respectResizeState = false,
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

    if (!respectResizeState) {
      return ClipRRect(
        borderRadius: rRect,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: tier.sigma, sigmaY: tier.sigma),
          child: RepaintBoundary(child: content),
        ),
      );
    }

    // respectResizeState == true: resize 期间降级为纯色
    return ValueListenableBuilder<bool>(
      valueListenable: ResizeNotifier.instance,
      builder: (_, state, child) {
        if (state) {
          return ClipRRect(
            borderRadius: rRect,
            child: RepaintBoundary(child: child),
          );
        }
        return ClipRRect(
          borderRadius: rRect,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: tier.sigma, sigmaY: tier.sigma),
            child: RepaintBoundary(child: child),
          ),
        );
      },
      child: content,
    );
  }
}

/// 毛玻璃风格按钮 — 支持 icon+label 和 icon-only 两种模式
///
/// label 为 null 时切换为 icon-only 模式（圆形 48×48）。
///
/// 设计：GestureDetector + MouseRegion 在最外层（BackdropFilter 之外），
/// 确保 Windows 上 hit test 不被 ClipRRect/BackdropFilter 拦截。
///
/// [respectResizeState] 传递给内部 GlassContainer，resize 期间跳过模糊。
class GlassButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool isPrimary;
  final bool enabled;
  final VoidCallback onPressed;
  final bool respectResizeState;

  const GlassButton({
    super.key,
    required this.icon,
    this.label,
    this.tooltip,
    this.isPrimary = false,
    this.enabled = true,
    required this.onPressed,
    this.respectResizeState = false,
  });

  /// 便捷构造：icon-only 模式
  const GlassButton.iconOnly({
    super.key,
    required this.icon,
    this.tooltip,
    this.isPrimary = false,
    this.enabled = true,
    required this.onPressed,
    this.respectResizeState = false,
  }) : label = null;

  bool get _isIconOnly => label == null;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isPrimary
        ? Tokens.textPrimary
        : Tokens.textSecondary;
    final scale = _pressed
        ? Tokens.pressScale
        : (_hovered ? Tokens.hoverScale : 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTap: widget.enabled
          ? () {
              setState(() => _pressed = false);
              widget.onPressed();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: Tooltip(
          message: widget.tooltip ?? widget.label ?? '',
          child: AnimatedContainer(
            duration: Duration(
              milliseconds: _pressed
                  ? Tokens.durationFast
                  : Tokens.durationNormal,
            ),
            transform: Matrix4.diagonal3Values(scale, scale, 1),
            transformAlignment: Alignment.center,
            child: widget._isIconOnly
                ? GlassContainer(
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.circular(24),
                    respectResizeState: widget.respectResizeState,
                    child: Icon(widget.icon, size: 20, color: textColor),
                  )
                : GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    respectResizeState: widget.respectResizeState,
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
                  ),
          ),
        ),
      ),
    );
  }
}
