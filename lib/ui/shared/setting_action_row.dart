import 'package:flutter/material.dart';

import '../theme/tokens.dart';

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
