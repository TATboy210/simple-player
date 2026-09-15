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

import '../../../kernel/services/app_settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'error_feedback_settings.dart';

/// 「通用」分区内容 —— 语言 / 错误卡片开关 / 断点续播开关（v0.0.6）。
///
/// 开关行翻转即生效并 fire-and-forget 持久化（SET-01/03）；呈现门控由
/// ErrorCardHost 订阅同一 store notifier 实现（D-05），捕获/落盘链零接触。
class GeneralSettingsContent extends StatefulWidget {
  const GeneralSettingsContent({super.key, this.settings});

  /// 应用偏好编排服务 — null 时断点续播开关行隐藏（测试退路）.
  final AppSettingsService? settings;

  @override
  State<GeneralSettingsContent> createState() => _GeneralSettingsContentState();
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
          _buildLanguageRow(l10n),
          _buildErrorCardToggleRow(l10n),
          // v0.0.6 断点续播总开关 — 服务注入后显示 (测试退路隐藏).
          if (widget.settings != null) _buildResumeToggleRow(l10n),
        ],
      ),
    );
  }

  /// 断点续播开关行 (v0.0.6) — 关闭时 coordinator 不记录断点,
  /// 面板隐藏断点进度; 打开恢复记录.
  Widget _buildResumeToggleRow(AppLocalizations l10n) {
    final settings = widget.settings!;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.resumeEnabled,
      builder: (context, enabled, _) {
        return _SettingsRow(
          label: l10n.resumeRememberPosition,
          onTap: () => settings.setResumeEnabled(!enabled),
          trailing: Switch(
            value: enabled,
            activeThumbColor: Tokens.accent,
            onChanged: settings.setResumeEnabled,
          ),
        );
      },
    );
  }

  /// 语言选择行 —— Dropdown 三选（跟随系统/English/中文），切换经
  /// [ErrorFeedbackSettings.setLanguage] 同帧生效（App 订阅同一 store）。
  ///
  /// 语言名按国际惯例以各自母语显示（English/中文），label 随当前语言切换。
  Widget _buildLanguageRow(AppLocalizations l10n) {
    return ValueListenableBuilder<ErrorFeedbackSettingsData>(
      valueListenable: ErrorFeedbackSettings.I.state,
      builder: (context, settings, _) {
        return _SettingsRow(
          label: l10n.languageLabel,
          trailing: DropdownButton<AppLanguage>(
            value: settings.language,
            underline: const SizedBox.shrink(),
            dropdownColor: Tokens.bgGlass,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontCaption,
            ),
            icon: const Icon(
              Icons.expand_more,
              size: Tokens.iconSm,
              color: Tokens.textSecondary,
            ),
            items: [
              DropdownMenuItem(
                value: AppLanguage.system,
                child: Text(l10n.languageSystem),
              ),
              const DropdownMenuItem(
                value: AppLanguage.english,
                child: Text('English'),
              ),
              const DropdownMenuItem(
                value: AppLanguage.chinese,
                child: Text('中文'),
              ),
            ],
            onChanged: (language) {
              if (language != null) {
                ErrorFeedbackSettings.I.setLanguage(language);
              }
            },
          ),
        );
      },
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
  const _SettingsRow({required this.label, required this.trailing, this.onTap});

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
