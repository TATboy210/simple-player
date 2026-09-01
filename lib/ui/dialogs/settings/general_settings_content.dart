/// 「通用」分区内容 —— 错误卡片开关行（SET-01/03 UI 收口；G-04-1 后唯一行）。
///
/// Toggle row: flipping the switch takes effect the same frame (the 04-03
/// render gate subscribes the same store notifier) and persists
/// fire-and-forget (SET-03). The log-path row (input / browse / debounced
/// validation / inline status / effective-path display) was removed with the
/// path-configuration feature — the diagnostic log target is fixed to the
/// two-tier chain (exe root logs/ → Application Support logs/).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'error_feedback_settings.dart';

/// 「通用」分区内容 —— 错误卡片开关行。
///
/// 开关行翻转即生效并 fire-and-forget 持久化（SET-01/03）；呈现门控由
/// ErrorCardHost 订阅同一 store notifier 实现（D-05），捕获/落盘链零接触。
class GeneralSettingsContent extends StatefulWidget {
  const GeneralSettingsContent({super.key});

  @override
  State<GeneralSettingsContent> createState() =>
      _GeneralSettingsContentState();
}

class _GeneralSettingsContentState extends State<GeneralSettingsContent> {
  /// SET-01 开关翻转 —— 立即生效（04-03 门控同帧响应）+ 持久化（SET-03）。
  void _setErrorCardEnabled(bool enabled) {
    ErrorFeedbackSettings.I.setCardEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Tokens.spLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildErrorCardToggleRow(l10n),
        ],
      ),
    );
  }

  /// 错误卡片开关行 —— 行本体点击与 Switch 均可切换（桌面友好；点击区手势
  /// 由最内层胜出，不会双重翻转）。
  Widget _buildErrorCardToggleRow(AppLocalizations l10n) {
    return ValueListenableBuilder<ErrorFeedbackSettingsData>(
      valueListenable: ErrorFeedbackSettings.I.state,
      builder: (context, settings, _) {
        return _SettingsRow(
          label: l10n.errorCardToggleLabel,
          onTap: () => _setErrorCardEnabled(!settings.errorCardEnabled),
          trailing: Switch(
            value: settings.errorCardEnabled,
            // activeColor 已废弃（Flutter 3.31+）—— 用 activeThumbColor。
            activeThumbColor: Tokens.accent,
            onChanged: _setErrorCardEnabled,
          ),
        );
      },
    );
  }
}

/// 通用设置行 — MouseRegion hover + AnimatedContainer 行语法
/// （循 setting_action_row.dart:54-76 先例；trailing 位置放行内控件）。
class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final String label;
  final Widget trailing;

  /// 行本体点击（可为 null —— 纯展示行无行级交互）。
  final VoidCallback? onTap;

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // opaque 让行内空白区也可点击（桌面友好）。
        behavior: HitTestBehavior.opaque,
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
              widget.trailing,
            ],
          ),
        ),
      ),
    );
  }
}
