import 'package:flutter/material.dart';

import '../theme/tokens.dart';

export 'setting_action_row.dart';
export 'setting_slider_row.dart';

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

  const SettingRow({
    super.key,
    this.icon,
    required this.title,
    this.description,
    required this.control,
    this.onTap,
  });

  @override
  State<SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<SettingRow> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _hovered || _pressed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: Tokens.durationFast),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
          decoration: BoxDecoration(
            color: isActive ? Tokens.bgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
          child: Transform.scale(
            scale: _pressed ? Tokens.pressScale : 1.0,
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: Tokens.iconSm,
                    color: Tokens.textSecondary,
                  ),
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
                      if (widget.description != null)
                        Text(
                          widget.description!,
                          style: const TextStyle(
                            color: Tokens.textTertiary,
                            fontSize: Tokens.fontOverline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                widget.control,
              ],
            ),
          ),
        ),
      ),
    );
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
