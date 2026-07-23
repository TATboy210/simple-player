// SettingsButton — 设置面板底部操作按钮（TABS-03）。
//
// 从旧 settings_panel.dart _BottomButton 提取的公共组件。
// 毛玻璃风格：bgGlass 背景 + borderHighlight 边框 + hover/press 缩放反馈。
// primary 模式使用 accent 背景 + 白色文字。

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 设置面板底部操作按钮 — Cancel / Apply / OK 等。
///
/// 样式：固定 32px 高，水平 padding spMd，圆角 radiusBtn。
/// hover → bgHover 背景变化；press → scale 0.98。
/// primary 模式 → accent 背景 + 白色文字 + 蓝色辉光阴影。
class SettingsButton extends StatefulWidget {
  const SettingsButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  /// 按钮文字（如 '取消'、'应用'、'确定'）。
  final String label;

  /// 点击回调。
  final VoidCallback onTap;

  /// 是否为主要按钮 — true 时使用 accent 背景 + 白色文字。
  final bool primary;

  @override
  State<SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SettingsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

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
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovering) {
    _scaleController.animateTo(hovering ? Tokens.hoverScale : 1.0);
  }

  void _onTapDown(TapDownDetails _) {
    _scaleController.value = Tokens.pressScale;
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.animateTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    // primary 按钮带 accent 蓝色辉光
    final boxShadow = widget.primary
        ? [
            BoxShadow(
              color: Tokens.accent.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: -2,
            ),
          ]
        : null;

    final content = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spMd),
      decoration: BoxDecoration(
        color: widget.primary ? Tokens.accent : Tokens.bgGlass,
        border: Border.all(
          color: widget.primary ? Tokens.accent : Tokens.borderHighlight,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(Tokens.radiusBtn),
        boxShadow: boxShadow,
      ),
      alignment: Alignment.center,
      child: Text(
        widget.label,
        style: TextStyle(
          color: widget.primary ? Colors.white : Tokens.textPrimary,
          fontSize: Tokens.fontCaption,
          fontWeight:
              widget.primary ? Tokens.weightMedium : Tokens.weightRegular,
        ),
      ),
    );

    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.radiusBtn),
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: () => _scaleController.animateTo(1.0),
        hoverColor: Tokens.bgHover,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(Tokens.radiusBtn),
        splashFactory: NoSplash.splashFactory,
        child: content,
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: ScaleTransition(scale: _scaleAnim, child: button),
    );
  }
}
