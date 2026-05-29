import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  /// 弹窗/对话框 — 深模糊
  thick(Tokens.glassBlurThick);

  final double sigma;
  const GlassTier(this.sigma);
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
  final BorderRadius? borderRadius;
  final Border? border;
  final GlassTier tier;

  /// 淡入淡出动画 — opacity=0 时跳过 BackdropFilter GPU readback（D-13）
  final ValueListenable<double>? opacity;

  /// 低配硬件降级模式 — false 时跳过 BackdropFilter（D-14）
  final bool blurEnabled;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.border,
    this.tier = GlassTier.normal,
    this.opacity,
    this.blurEnabled = true,
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

    // 降级模式：跳过 BackdropFilter，仅渲染半透明背景（D-14）
    if (!blurEnabled) {
      return ClipRRect(
        borderRadius: rRect,
        child: RepaintBoundary(child: content),
      );
    }

    final blurContent = RepaintBoundary(child: content);
    final blurFilter = ui.ImageFilter.blur(
      sigmaX: tier.sigma,
      sigmaY: tier.sigma,
    );

    // opacity < 0.01 时跳过 BackdropFilter GPU readback（D-13）
    if (opacity != null) {
      return AnimatedBuilder(
        animation: opacity!,
        builder: (_, child) {
          if (opacity!.value < 0.01) return child!;
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

/// 毛玻璃风格按钮 — 双模式 StatelessWidget
///
/// - label 非空 → GlassContainer + Material + InkWell（带模糊背景）
/// - label 为 null（iconOnly 构造）→ SizedBox + Material + InkWell（轻量无模糊）
///
/// 两种模式都使用 InkWell 处理 hover/press 反馈，无缩放动画。
class GlassButton extends StatelessWidget {
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
  }) : label = null;

  bool get _isIconOnly => label == null;

  @override
  Widget build(BuildContext context) {
    if (_isIconOnly) {
      return _buildIconOnly();
    }
    return _buildLabel();
  }

  /// icon-only 轻量路径：SizedBox + Material + InkWell，无 BackdropFilter
  Widget _buildIconOnly() {
    final effectiveColor =
        color ?? (isPrimary ? Tokens.textPrimary : Tokens.textSecondary);
    final content = child ?? Icon(icon, size: iconSize, color: effectiveColor);

    return Tooltip(
      message: tooltip ?? '',
      waitDuration: const Duration(milliseconds: 400),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: Colors.transparent,
          borderRadius: _radiusBtn,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            onSecondaryTapUp: onSecondaryTapUp,
            hoverColor: Tokens.bgHover,
            highlightColor: Colors.transparent,
            borderRadius: _radiusBtn,
            splashFactory: NoSplash.splashFactory,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }

  /// label 路径：GlassContainer + Material + InkWell，带模糊背景
  Widget _buildLabel() {
    final effectiveColor =
        color ?? (isPrimary ? Tokens.textPrimary : Tokens.textSecondary);

    final content = GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.iconButtonPaddingH,
        vertical: Tokens.iconButtonPaddingV,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(width: Tokens.spSm),
          Text(
            label!,
            style: TextStyle(
              fontSize: Tokens.fontBody,
              fontWeight: Tokens.weightMedium,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: _radiusIcon,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        hoverColor: Tokens.bgHover,
        highlightColor: Colors.transparent,
        borderRadius: _radiusIcon,
        splashFactory: NoSplash.splashFactory,
        child: Tooltip(
          message: tooltip ?? label ?? '',
          waitDuration: const Duration(milliseconds: 400),
          child: content,
        ),
      ),
    );
  }
}
