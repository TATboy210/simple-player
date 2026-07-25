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
/// 用于设置面板中需要键盘/D-pad 导航的行项目。
/// 焦点边框（D-11）：2px borderHighlight，即时切换无动画（D-13）。
/// hover 背景（D-12）：bgHover 仅在未聚焦时显示。
/// disabled（D-15）：ExcludeFocus + IgnorePointer，不接收焦点。
///
/// 作为纯装饰包装器，不拦截子 widget 的手势事件。
/// 子 widget 可自行处理 hover/press 逻辑（如 SettingRow 的 AnimatedContainer）。
///
/// ```dart
/// FocusableSettingRow(
///   child: SettingRow(title: '音量', control: Slider(...)),
///   onFocusChange: (focused) => debugPrint('focused: $focused'),
/// )
/// ```
class FocusableSettingRow extends StatefulWidget {
  /// 要包装的子 widget。
  final Widget child;

  /// 焦点状态变化回调。
  final ValueChanged<bool>? onFocusChange;

  /// 是否启用 — false 时 ExcludeFocus + IgnorePointer（D-15）。
  final bool enabled;

  /// 是否自动获取焦点。
  final bool autofocus;

  /// 测试用 key。
  final Key? focusKey;

  const FocusableSettingRow({
    super.key,
    required this.child,
    this.onFocusChange,
    this.enabled = true,
    this.autofocus = false,
    this.focusKey,
  });

  @override
  State<FocusableSettingRow> createState() => _FocusableSettingRowState();
}

class _FocusableSettingRowState extends State<FocusableSettingRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // D-15: 禁用行不接收焦点，不响应交互
    if (!widget.enabled) {
      return ExcludeFocus(
        child: IgnorePointer(child: widget.child),
      );
    }

    // D-12: hover 背景仅在未聚焦时显示（焦点边框优先）
    final showHoverBg = _hovered && !_focused;
    // D-11: 焦点边框颜色
    final borderColor = _focused ? Tokens.borderHighlight : Colors.transparent;

    return FocusableActionDetector(
      key: widget.focusKey,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (focused) {
        setState(() => _focused = focused);
        widget.onFocusChange?.call(focused);
      },
      onShowHoverHighlight: (hovering) {
        setState(() => _hovered = hovering);
      },
      onFocusChange: (focused) {
        // onShowFocusHighlight 已处理视觉反馈，此处仅转发回调
        widget.onFocusChange?.call(focused);
      },
      // D-13: 焦点边框即时切换，无动画 — 使用 Container 而非 AnimatedContainer
      child: Container(
        decoration: BoxDecoration(
          // D-12: hover 背景（仅未聚焦时）
          color: showHoverBg ? Tokens.bgHover : Colors.transparent,
          // D-11: 焦点边框 2px borderHighlight，即时切换无动画（D-13）
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: widget.child,
      ),
    );
  }
}
