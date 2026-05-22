import 'package:flutter/material.dart';

import '../../kernel/ui/theme/tokens.dart';

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
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusLarge),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
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

/// 可展开设置卡片 — 渐进披露高级设置
///
/// ```dart
/// SettingsExpanderCard(
///   title: '色彩校正',
///   icon: Icons.color_lens,
///   children: [SettingRow(title: '亮度', control: Slider(...))],
///   expandedChildren: [SettingRow(title: '色相', control: Slider(...))],
/// )
/// ```
class SettingsExpanderCard extends StatefulWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final List<Widget> children;
  final List<Widget> expandedChildren;
  final bool initiallyExpanded;

  const SettingsExpanderCard({
    super.key,
    required this.title,
    this.description,
    this.icon,
    required this.children,
    required this.expandedChildren,
    this.initiallyExpanded = false,
  });

  @override
  State<SettingsExpanderCard> createState() => _SettingsExpanderCardState();
}

class _SettingsExpanderCardState extends State<SettingsExpanderCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spMd),
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusLarge),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spLg,
          vertical: Tokens.spMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 可点击的标题行
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: Tokens.iconSm,
                      color: Tokens.textSecondary,
                    ),
                    const SizedBox(width: Tokens.spXs),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Tokens.textSecondary,
                            fontSize: Tokens.fontCaption,
                            fontWeight: Tokens.weightMedium,
                          ),
                        ),
                        if (widget.description != null)
                          Text(
                            widget.description!,
                            style: const TextStyle(
                              color: Tokens.textTertiary,
                              fontSize: Tokens.fontOverline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: Tokens.durationFast),
                    child: const Icon(
                      Icons.expand_more,
                      size: Tokens.iconMd,
                      color: Tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // 始终可见的内容
            if (widget.children.isNotEmpty) ...[
              const SizedBox(height: Tokens.spSm),
              for (int i = 0; i < widget.children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Tokens.borderHighlight,
                    indent: widget.icon != null ? 36 : 0,
                  ),
                widget.children[i],
              ],
            ],
            // 展开区域
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  if (widget.children.isNotEmpty &&
                      widget.expandedChildren.isNotEmpty)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Tokens.borderHighlight,
                      indent: widget.icon != null ? 36 : 0,
                    ),
                  for (int i = 0; i < widget.expandedChildren.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Tokens.borderHighlight,
                        indent: widget.icon != null ? 36 : 0,
                      ),
                    widget.expandedChildren[i],
                  ],
                ],
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: Tokens.durationNormal),
            ),
          ],
        ),
      ),
    );
  }
}

/// 操作卡片 — 可点击导航行（用于许可、外部链接等）
///
/// ```dart
/// SettingsActionCard(
///   title: '开源许可',
///   icon: Icons.article,
///   onTap: () => showLicensePage(context: context),
/// )
/// ```
class SettingsActionCard extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final IconData trailingIcon;
  final VoidCallback onTap;

  const SettingsActionCard({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.trailingIcon = Icons.chevron_right,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spMd),
      decoration: BoxDecoration(
        color: Tokens.bgPanel,
        borderRadius: BorderRadius.circular(Tokens.radiusLarge),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: Tokens.iconSm, color: Tokens.textSecondary),
                const SizedBox(width: Tokens.spSm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Tokens.textPrimary,
                        fontSize: Tokens.fontBody,
                        fontWeight: Tokens.weightRegular,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description!,
                        style: const TextStyle(
                          color: Tokens.textTertiary,
                          fontSize: Tokens.fontOverline,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                trailingIcon,
                size: Tokens.iconMd,
                color: Tokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
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
