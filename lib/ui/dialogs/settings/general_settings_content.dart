// ignore_for_file: avoid-unnecessary-stateful-widgets
/// 「通用」分区内容 —— 错误卡片开关行（SET-01/03 UI 收口；G-04-1 后唯一行）。
///
/// Toggle row: flipping the switch takes effect the same frame (the 04-03
/// render gate subscribes the same store notifier) and persists
/// fire-and-forget (SET-03). The log-path row (input / browse / debounced
/// validation / inline status / effective-path display) was removed with the
/// path-configuration feature — the diagnostic log target is fixed to the
/// two-tier chain (exe root logs/ → Application Support logs/).
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../kernel/services/app_settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'error_feedback_settings.dart';
import 'ime_test_field.dart';

/// 「通用」分区内容 —— 语言 / 错误卡片开关 / 断点续播开关（v0.0.6）。
///
/// 开关行翻转即生效并 fire-and-forget 持久化（SET-01/03）；呈现门控由
/// ErrorCardHost 订阅同一 store notifier 实现（D-05），捕获/落盘链零接触。
///
/// 纵轴键盘导航（v0.0.8 XMB 化）：宿主面板注入 [rowsFocusNode] 后，
/// ↑↓ 在行间移动焦点（回绕）、Enter/Space 激活当前行（语言行 no-op —
/// Dropdown 需鼠标展开）；←→ 及其余按键 ignored（冒泡给面板切分区）。
/// 焦点行高亮 = bgHover 常亮 + 行首 accent 竖条（与 hover 同色系并存）。
// ignore: avoid-unnecessary-stateful-widgets — State 生命周期与局部
// 控制器耦合, 保守保留 (转换风险 > 风格收益).
class GeneralSettingsContent extends StatefulWidget {
  const GeneralSettingsContent({super.key, this.settings, this.rowsFocusNode});

  /// 应用偏好编排服务 — null 时断点续播开关行隐藏（测试退路）.
  final AppSettingsService? settings;

  /// 行导航焦点节点 — 面板注入（↑↓/Enter 消费者）；null 时不挂键盘
  /// 导航（直 pump 测试退路，行 hover/点击不受影响）.
  final FocusNode? rowsFocusNode;

  @override
  State<GeneralSettingsContent> createState() => _GeneralSettingsContentState();
}

class _GeneralSettingsContentState extends State<GeneralSettingsContent> {
  /// 键盘行焦点索引 — 0 语言 / 1 错误卡片 / 2 断点（行序恒定）.
  int _focusedRow = 0;

  bool _rowsFocused = false;

  /// 行数 — 断点行随服务注入显隐，键盘导航同步收缩（天然无越界）.
  int get _rowCount => 2 + (widget.settings != null ? 1 : 0);

  /// SET-01 开关翻转 —— 立即生效（04-03 门控同帧响应）+ 持久化（SET-03）。
  void _setErrorCardEnabled(bool enabled) {
    ErrorFeedbackSettings.I.setCardEnabled(enabled);
  }

  /// 错误卡片行激活 — 行点击与键盘 Enter 共用.
  void _toggleErrorCard() {
    final current = ErrorFeedbackSettings.I.state.value.errorCardEnabled;
    _setErrorCardEnabled(!current);
  }

  /// 断点续播行激活 — 行点击与键盘 Enter 共用.
  void _toggleResume() {
    final settings = widget.settings!;
    settings.setResumeEnabled(!settings.resumeEnabled.value);
  }

  /// 行激活分发 — 语言行（0）为纯展示 + Dropdown 需鼠标展开，键盘激活
  /// no-op 但仍 handled（消费按键防外层泄漏）.
  void _activateRow(int index) {
    switch (index) {
      case 1:
        _toggleErrorCard();
      case 2:
        if (widget.settings != null) _toggleResume();
    }
  }

  /// 纵轴按键 — ↑↓ 回绕移动焦点行；Enter/Space 激活；←→ 及其余 ignored
  /// （冒泡给面板级 Focus：←→ 切分区、Esc 返回 tag 层）.
  KeyEventResult _handleRowsKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        final dir = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        _focusedRow = (_focusedRow + dir + _rowCount) % _rowCount;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _activateRow(_focusedRow);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Focus(
      focusNode: widget.rowsFocusNode,
      onFocusChange: (focused) => setState(() => _rowsFocused = focused),
      onKeyEvent: _handleRowsKeyEvent,
      child: SingleChildScrollView(
        // 滚动兜底 — debug IME 验证框使内容高于小窗口面板 (Audio 分区
        // 同款先例); 常规尺寸下内容不超视口, 滚动不出现.
        padding: const EdgeInsets.all(Tokens.spLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLanguageRow(l10n),
            _buildErrorCardToggleRow(l10n),
            // v0.0.6 断点续播总开关 — 服务注入后显示 (测试退路隐藏).
            if (widget.settings != null) _buildResumeToggleRow(l10n),
            // IME 治理验证输入框 (v0.0.8.2, debug-only + Windows) —
            // UAT 工具: 聚焦恢复默认 IMC (中文可组合/候选窗锚定光标),
            // 失焦再解除 (无文本框场景左上角候选窗不再弹出)。刻意置于
            // 行导航 Focus 之外 — 不参与 ↑↓ 行序, 不改变行数契约.
            if (kDebugMode && Platform.isWindows) ...[
              const SizedBox(height: Tokens.spMd),
              const ImeTestField(),
            ],
          ],
        ),
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
          onTap: _toggleResume,
          isFocused: _rowsFocused && _focusedRow == 2,
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
          isFocused: _rowsFocused && _focusedRow == 0,
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
              // 语言名按国际惯例以各自母语显示 (v0.0.6 增韩/日).
              const DropdownMenuItem(
                value: AppLanguage.korean,
                child: Text('한국어'),
              ),
              const DropdownMenuItem(
                value: AppLanguage.japanese,
                child: Text('日本語'),
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
          onTap: _toggleErrorCard,
          isFocused: _rowsFocused && _focusedRow == 1,
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
///
/// v0.0.8 纵轴键盘焦点：[isFocused] 恒亮 bgHover（与 hover 同色并存）+
/// 行首恒 2px 槽位 accent 竖条（透明→点亮，防布局跳动 — 旧 _NavEntry 技法）。
class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.label,
    required this.trailing,
    this.onTap,
    this.isFocused = false,
  });

  final String label;
  final Widget trailing;

  /// 行本体点击（可为 null —— 纯展示行无行级交互）。
  final VoidCallback? onTap;

  /// 键盘焦点行 — 恒亮高亮（与 hover 同色并存）.
  final bool isFocused;

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
            color: (_hovered || widget.isFocused)
                ? Tokens.bgHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
          child: Row(
            children: [
              // 焦点指示竖条 — 恒 2px 槽位（透明→accent 点亮），防跳动.
              AnimatedContainer(
                duration: const Duration(milliseconds: Tokens.durationFast),
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.isFocused ? Tokens.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                ),
              ),
              const SizedBox(width: Tokens.spSm),
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
