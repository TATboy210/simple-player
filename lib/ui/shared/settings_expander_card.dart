import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'settings_card.dart';

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

class _SettingsExpanderCardState extends State<SettingsExpanderCard> {
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
      decoration: SettingsCard.cardDecoration,
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
