import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'focusable_setting_row.dart';
import 'spin_control.dart';

export 'setting_action_row.dart';
export 'setting_slider_row.dart';
export 'spin_control.dart';

/// 设置行 — 统一的 label + control 布局，带 hover/press 交互反馈
///
/// ```dart
/// SettingRow(title: '界面语言', control: DropdownButton(...))
/// SettingRow(icon: Icons.volume_up, title: '音量', control: Slider(...))
/// ```
class SettingRow extends StatefulWidget {
  final IconData? icon;
  final String title;
  final String? description;
  final Widget control;
  final VoidCallback? onTap;

  /// 是否允许行及其嵌入控件接收焦点和指针事件。
  ///
  /// 行级 [onTap] 为空时，嵌入的 Switch 或 SpinControl 仍可独立交互；
  /// 仅纯展示行需要显式设为 false。
  final bool focusable;

  /// 可选的行焦点节点；外层应用可用它控制键盘遍历的当前行。
  final FocusNode? focusNode;

  const SettingRow({
    super.key,
    this.icon,
    required this.title,
    this.description,
    required this.control,
    this.onTap,
    this.focusable = true,
    this.focusNode,
  });

  @override
  State<SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<SettingRow> {
  @override
  Widget build(BuildContext context) {
    // FocusableSettingRow is the single keyboard stop; row-level tapping and
    // embedded-control interaction are independent.
    return FocusableSettingRow(
      enabled: widget.focusable,
      focusNode: widget.focusNode,
      focusedBuilder: (context, focused) => _buildInteractiveRow(focused),
    );
  }

  /// Builds the transparent Material surface required for InkWell's visible ink effects.
  Widget _buildInteractiveRow(bool focused) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        canRequestFocus: false,
        autofocus: false,
        hoverColor: Tokens.bgHover,
        // Accent light remains visible against the dark glass during pointer press.
        splashColor: Tokens.accentLight,
        highlightColor: Tokens.bgHover,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: SizedBox(
          // The focus wrapper paints a persistent 1px border on both edges.
          // Keep its outer hit target at the locked 40 logical pixels.
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.spXs),
            child: Row(
              children: [
                if (widget.icon case final icon?) ...[
                  Icon(icon, size: Tokens.iconSm, color: Tokens.textSecondary),
                  const SizedBox(width: Tokens.spSm),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Tokens.textPrimary,
                          fontSize: Tokens.fontBody,
                          fontWeight: Tokens.weightRegular,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.description case final description?)
                        Text(
                          description,
                          style: const TextStyle(
                            color: Tokens.textTertiary,
                            fontSize: Tokens.fontOverline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildControl(focused),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Applies the locked accent route to text controls while this row owns focus.
  Widget _buildControl(bool focused) {
    final control = widget.control;
    if (control is Text) {
      final style = control.style ?? const TextStyle();
      return Text(
        control.data ?? '',
        key: control.key,
        style: style.copyWith(
          color: focused
              ? Tokens.accent
              : (style.color ?? Tokens.textSecondary),
        ),
        overflow: control.overflow,
      );
    }
    return control;
  }
}

/// 开关设置行 — ValueNotifier + Switch，包裹 SettingRow
///
/// ```dart
/// SettingSwitchRow(
///   title: '去隔行',
///   description: '仅软件解码器',
///   notifier: service.deinterlaceEnabled,
/// )
/// ```
class SettingSwitchRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? description;
  final ValueNotifier<bool> notifier;

  const SettingSwitchRow({
    super.key,
    this.icon,
    required this.title,
    this.description,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (_, enabled, _) {
        return SettingRow(
          icon: icon,
          title: title,
          description: description,
          control: Switch(
            value: enabled,
            onChanged: (v) => notifier.value = v,
            activeThumbColor: Tokens.accent,
          ),
        );
      },
    );
  }
}

/// Spin 设置行 — label + SpinControl 水平选择器，包裹 SettingRow
///
/// 用于枚举选项的水平切换（如语言、渲染器等）。
///
/// ```dart
/// SettingSpinRow(
///   icon: Icons.language,
///   title: '界面语言',
///   description: '选择界面显示语言',
///   options: ['zh', 'en'],
///   currentIndex: 0,
///   onChanged: (i) => pending.update('locale', ['zh', 'en'][i]),
///   formatValue: (v) => v == 'zh' ? '中文' : 'English',
/// )
/// ```
class SettingSpinRow extends StatelessWidget {
  /// 行图标（可选）
  final IconData? icon;

  /// 行标题
  final String title;

  /// 行描述（可选）
  final String? description;

  /// 可选值列表
  final List<String> options;

  /// 当前选中索引
  final int currentIndex;

  /// 选择变更回调
  final ValueChanged<int> onChanged;

  /// 自定义值格式化器（可选）
  final String Function(String)? formatValue;

  const SettingSpinRow({
    super.key,
    this.icon,
    required this.title,
    this.description,
    required this.options,
    required this.currentIndex,
    required this.onChanged,
    this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      icon: icon,
      title: title,
      description: description,
      control: SpinControl(
        options: options,
        currentIndex: currentIndex,
        onChanged: onChanged,
        formatValue: formatValue,
      ),
    );
  }
}
