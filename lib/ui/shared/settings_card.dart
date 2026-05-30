import 'package:flutter/material.dart';

import '../theme/tokens.dart';

export 'setting_action_row.dart';
export 'setting_slider_row.dart';
export 'settings_action_card.dart';
export 'settings_expander_card.dart';

/// 设置卡片 — 阴影 + 圆角 + section header + children 嵌套
///
/// 平衡型视觉风格（Plex/IINA）：卡片间留白适中，内容区紧凑。
///
/// ```dart
/// SettingsCard(
///   title: '语言',
///   icon: Icons.language,
///   children: [
///     SettingRow(title: '界面语言', control: DropdownButton(...)),
///   ],
/// )
/// ```
class SettingsCard extends StatelessWidget {
  /// 共享的卡片装饰 — SettingsCard、SettingsExpanderCard、SettingsActionCard 复用
  static const cardDecoration = BoxDecoration(
    color: Tokens.bgPanel,
    borderRadius: BorderRadius.all(Radius.circular(Tokens.radiusLarge)),
    boxShadow: [
      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  final String title;
  final String? description;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const SettingsCard({
    super.key,
    required this.title,
    this.description,
    this.icon,
    required this.children,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: Tokens.spMd),
      decoration: SettingsCard.cardDecoration,
      child: Padding(
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: Tokens.spLg,
              vertical: Tokens.spMd,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            _SectionHeader(title: title, description: description, icon: icon),
            // Content rows
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Tokens.borderHighlight,
                  indent: icon != null ? 36 : 0,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

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

/// Section Header — 卡片内的标题行
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;

  const _SectionHeader({required this.title, this.description, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spSm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: Tokens.iconSm, color: Tokens.textSecondary),
            const SizedBox(width: Tokens.spXs),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
              fontWeight: Tokens.weightMedium,
            ),
          ),
          if (description != null) ...[
            const SizedBox(width: Tokens.spSm),
            Text(
              description!,
              style: const TextStyle(
                color: Tokens.textTertiary,
                fontSize: Tokens.fontOverline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
