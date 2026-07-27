// FocusableSettingRow — 可聚焦的设置行包装器（NAV-01 / D-11/D-12/D-13/D-15）。
//
// 为设置面板的键盘/D-pad 导航提供焦点检测与视觉反馈。
// 使用 FocusableActionDetector 统一管理 focus + hover + press 状态。
//
// 设计决策：
// - D-11: 焦点边框 borderHighlight 2px，无动画（Container 非 AnimatedContainer）
// - D-12: hover 背景 bgHover 仅在未聚焦时显示（焦点边框优先于 hover 背景）
// - D-13: 焦点边框变化即时生效，不使用动画
// - D-15: enabled=false 时 ExcludeFocus + IgnorePointer，不接收焦点

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 可聚焦的设置行 — 为任意子 widget 添加焦点检测与视觉反馈。
///
/// 用于设置面板中需要键盘/D-pad 导航的行项目。焦点边框使用一像素
/// `Tokens.controlBarBorderWhite`，并由此组件作为行唯一的焦点拥有者。
/// `focusedBuilder` 允许嵌入的活动值随焦点状态重建，同时保留既有 `child` API。
class FocusableSettingRow extends StatefulWidget {
  /// 要包装的静态子 widget；与 [focusedBuilder] 二选一。
  final Widget? child;

  /// 根据当前焦点状态构建子树，用于活动值的颜色等局部视觉变化。
  final Widget Function(BuildContext context, bool focused)? focusedBuilder;

  /// 焦点状态变化回调。
  final ValueChanged<bool>? onFocusChange;

  /// 可选的行焦点节点，主要供组合组件和测试控制焦点。
  final FocusNode? focusNode;

  /// 是否启用 — false 时 ExcludeFocus + IgnorePointer（D-15）。
  final bool enabled;

  /// 是否自动获取焦点。
  final bool autofocus;

  /// 测试用 key。
  final Key? focusKey;

  const FocusableSettingRow({
    super.key,
    this.child,
    this.focusedBuilder,
    this.onFocusChange,
    this.focusNode,
    this.enabled = true,
    this.autofocus = false,
    this.focusKey,
  }) : assert(child != null || focusedBuilder != null);

  @override
  State<FocusableSettingRow> createState() => _FocusableSettingRowState();
}

class _FocusableSettingRowState extends State<FocusableSettingRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final child = _buildChild(context);

    // D-15: 禁用行不接收焦点，也不让嵌入 InkWell 接收指针事件。
    if (!widget.enabled) {
      return ExcludeFocus(child: IgnorePointer(child: child));
    }

    return FocusableActionDetector(
      key: widget.focusKey,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: _handleFocusHighlight,
      // Keyboard focus must rebuild the active value even when focus highlights
      // are disabled by the current platform highlight mode.
      onFocusChange: _handleFocusHighlight,
      // Hover 由 SettingRow 的 InkWell 单一拥有，避免多个背景来源闪烁。
      child: Container(
        decoration: BoxDecoration(
          // Container 始终保留边框槽位，焦点切换不会改变行的外部几何。
          border: Border.all(
            color: _focused ? Tokens.controlBarBorderWhite : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: child,
      ),
    );
  }

  /// 同步焦点视觉和外部回调，使活动值构建器只经一个状态路径更新。
  void _handleFocusHighlight(bool focused) {
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
  }

  /// 在焦点变化时只重建需要状态的活动值子树。
  Widget _buildChild(BuildContext context) {
    final builder = widget.focusedBuilder;
    return builder?.call(context, _focused) ??
        widget.child ??
        const SizedBox.shrink();
  }
}
