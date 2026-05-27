import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

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

/// 滑块设置行 — 带 debounce 的 label + slider + value 三区域布局
///
/// ```dart
/// SettingSliderRow(label: '亮度', notifier: service.brightness)
/// SettingSliderRow(label: '音量', notifier: service.volume, min: 0, max: 1)
/// ```
class SettingSliderRow extends StatefulWidget {
  final String label;
  final ValueNotifier<double> notifier;
  final double min;
  final double max;
  final int displayMultiplier;
  final String? displaySuffix;
  final Duration debounceDuration;

  const SettingSliderRow({
    super.key,
    required this.label,
    required this.notifier,
    this.min = -1.0,
    this.max = 1.0,
    this.displayMultiplier = 100,
    this.displaySuffix,
    this.debounceDuration = const Duration(milliseconds: 50),
  });

  @override
  State<SettingSliderRow> createState() => _SettingSliderRowState();
}

class _SettingSliderRowState extends State<SettingSliderRow> {
  bool _hovered = false;
  bool _dragging = false;
  double _dragValue = 0;
  Timer? _debounce;

  double get _effectiveValue => _dragging ? _dragValue : widget.notifier.value;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: Tokens.durationFast),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
        decoration: BoxDecoration(
          color: _hovered ? Tokens.bgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: ValueListenableBuilder<double>(
          valueListenable: widget.notifier,
          builder: (_, _, _) {
            final display = _effectiveValue;
            return Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Tokens.textSecondary,
                      fontSize: Tokens.fontOverline,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: display,
                    min: widget.min,
                    max: widget.max,
                    onChanged: (v) {
                      setState(() {
                        _dragging = true;
                        _dragValue = v;
                      });
                      _debounce?.cancel();
                      _debounce = Timer(widget.debounceDuration, () {
                        widget.notifier.value = v;
                      });
                    },
                    onChangeEnd: (_) {
                      setState(() => _dragging = false);
                    },
                    activeColor: Tokens.accent,
                    inactiveColor: Tokens.bgHover,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(display * widget.displayMultiplier).round()}'
                    '${widget.displaySuffix ?? ''}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Tokens.textTertiary,
                      fontSize: Tokens.fontOverline,
                      fontFeatures: [Tokens.tabularFigures],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 操作设置行 — 带激活态高亮的 label + value + action 三区域布局
///
/// ```dart
/// SettingActionRow(
///   label: '播放/暂停',
///   valueText: 'Space',
///   isActive: _recordingAction == 'playPause',
///   activeText: '按按键绑定',
///   onAction: () => _startRecording('playPause'),
///   onDeactivate: _cancelRecording,
/// )
/// ```
class SettingActionRow extends StatefulWidget {
  final String label;
  final String valueText;
  final bool isActive;
  final String? activeText;
  final VoidCallback onAction;
  final VoidCallback? onDeactivate;
  final IconData actionIcon;
  final IconData deactivateIcon;
  final Color? activeColor;
  final Color? deactivateColor;

  const SettingActionRow({
    super.key,
    required this.label,
    required this.valueText,
    this.isActive = false,
    this.activeText,
    required this.onAction,
    this.onDeactivate,
    this.actionIcon = Icons.edit,
    this.deactivateIcon = Icons.close,
    this.activeColor,
    this.deactivateColor,
  });

  @override
  State<SettingActionRow> createState() => _SettingActionRowState();
}

class _SettingActionRowState extends State<SettingActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.activeColor ?? Tokens.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: Tokens.durationFast),
        padding: const EdgeInsets.symmetric(
          vertical: 3,
          horizontal: Tokens.spSm,
        ),
        decoration: BoxDecoration(
          color: _hovered ? Tokens.bgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Tokens.textPrimary,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.spSm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? accent.withValues(alpha: 0.15)
                    : Tokens.bgHover,
                borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                border: Border.all(
                  color: widget.isActive ? accent : Tokens.borderHighlight,
                  width: 1,
                ),
              ),
              child: Text(
                widget.isActive ? (widget.activeText ?? '') : widget.valueText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isActive ? accent : Tokens.textSecondary,
                  fontSize: Tokens.fontCaption,
                  fontWeight: widget.isActive
                      ? Tokens.weightMedium
                      : Tokens.weightRegular,
                ),
              ),
            ),
            const SizedBox(width: Tokens.spXs),
            InkWell(
              onTap: widget.isActive ? widget.onDeactivate : widget.onAction,
              borderRadius: BorderRadius.circular(Tokens.radiusBtn),
              child: Padding(
                padding: const EdgeInsets.all(Tokens.spXs),
                child: Icon(
                  widget.isActive ? widget.deactivateIcon : widget.actionIcon,
                  size: Tokens.iconSm,
                  color: widget.isActive
                      ? (widget.deactivateColor ?? Tokens.danger)
                      : Tokens.textTertiary,
                ),
              ),
            ),
          ],
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
      decoration: SettingsCard.cardDecoration,
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
