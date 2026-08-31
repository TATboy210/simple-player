/// 「通用」分区内容 —— 错误卡片开关行与日志目录路径行（SET-01/02/03 UI 收口）。
///
/// Toggle row: flipping the switch takes effect the same frame (the 04-03
/// render gate subscribes the same store notifier) and persists
/// fire-and-forget (SET-03). Path row: debounced inline validation (default
/// 300ms), browse backfill through the identical validate→save→apply chain,
/// inline ✗ without save/retarget on failure, and the always-visible
/// effective log path (D-04 第一通道).
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../kernel/diagnostics/error_log_location.dart';
import '../../theme/tokens.dart';
import 'diagnostic_log_target.dart';
import 'error_feedback_settings.dart';

/// 行内路径校验状态 —— sealed 承载「空闲/校验中/可写/不可写(原因)」。
sealed class _PathStatus {
  const _PathStatus();
}

/// 空闲 —— 尚无校验结论（不渲染状态行）。
final class _IdleStatus extends _PathStatus {
  const _IdleStatus();
}

/// 校验中 —— 防抖到期后的校验/换位进行时。
final class _ValidatingStatus extends _PathStatus {
  const _ValidatingStatus();
}

/// 校验通过 —— 目录可写（✓）。
final class _ValidStatus extends _PathStatus {
  const _ValidStatus();
}

/// 校验失败 —— 携带封闭原因枚举（✗；UI 只映射文案，不持原始异常）。
final class _InvalidStatus extends _PathStatus {
  const _InvalidStatus(this.reason);

  final ConfiguredDirectoryFailure reason;
}

/// 「通用」分区内容 —— 错误卡片开关行 + 日志目录路径行。
///
/// 开关行翻转即生效并 fire-and-forget 持久化（SET-01/03）；路径行手输防抖
/// 校验（默认 300ms）、浏览回填同链路，提交统一走 [DiagnosticLogTarget.I.apply]
/// —— 校验/保存/重定向协议由协调器单点保证（T-04-04-01：UI 不做第二套校验），
/// 校验通过即保存并立即重定向（D-03 discretion），失败行内 ✗ 且不保存不重定向；
/// 行内状态区常显当前有效路径（D-04 第一通道）。
class GeneralSettingsContent extends StatefulWidget {
  const GeneralSettingsContent({
    super.key,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.directoryPicker,
  });

  /// 输入防抖时长 —— 生产默认 300ms（RESEARCH A2 采纳）；测试注入更短值。
  final Duration debounceDuration;

  /// 目录选择网关注入缝 —— file_picker 是 plugin 通道调用，headless 测试
  /// 环境不可用；测试注入假网关覆盖取消/回填路径。缺省绑生产
  /// [FilePicker.getDirectoryPath]（禁止生产路径出现测试分支常量）。
  final Future<String?> Function()? directoryPicker;

  @override
  State<GeneralSettingsContent> createState() =>
      _GeneralSettingsContentState();
}

class _GeneralSettingsContentState extends State<GeneralSettingsContent> {
  /// 输入防抖 Timer —— dispose 必须取消（循 setting_slider_row.dart:50-53 纪律）。
  Timer? _debounce;

  late final TextEditingController _pathController;

  /// 组件本地行内校验状态（校验中/可写/不可写原因）。
  final ValueNotifier<_PathStatus> _pathStatus =
      ValueNotifier<_PathStatus>(const _IdleStatus());

  @override
  void initState() {
    super.initState();
    // D-03：输入框初始显示当前有效路径 —— 用户永远知道日志在哪。
    _pathController = TextEditingController(
      text: DiagnosticLogTarget.I.effectiveLogPath.value ?? '',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pathController.dispose();
    _pathStatus.dispose();
    super.dispose();
  }

  /// SET-01 开关翻转 —— 立即生效（04-03 门控同帧响应）+ 持久化（SET-03）。
  void _setErrorCardEnabled(bool enabled) {
    ErrorFeedbackSettings.I.setCardEnabled(enabled);
  }

  /// 输入变更 —— 重置防抖（cancel → 重新计时，300ms 合并高频输入）。
  void _onPathChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, _commitPathInput);
  }

  /// 防抖到期提交 —— 统一经协调器 apply 全协议：
  /// 空串 = 回默认链（'' = reset，D-03）；非空校验失败 → 三不（不保存 /
  /// 不重定向，协调器保证，UI 只映射行内文案）；通过 → 保存并重定向。
  Future<void> _commitPathInput() async {
    _pathStatus.value = const _ValidatingStatus();
    final result = await DiagnosticLogTarget.I.apply(_pathController.text);
    if (!mounted) {
      return;
    }
    switch (result) {
      case ConfiguredDirectoryValid():
        _pathStatus.value = const _ValidStatus();
      case ConfiguredDirectoryInvalid(:final reason):
        _pathStatus.value = _InvalidStatus(reason);
    }
  }

  /// 「浏览」—— 原生目录对话框；null（取消）静默忽略，绝不当作清空。
  Future<void> _browseForDirectory() async {
    final picker = widget.directoryPicker;
    final String? directory;
    try {
      directory = await (picker != null
          ? picker()
          : _pickDirectoryWithPlugin());
    } on Exception catch (error) {
      // picker 异常收窄捕获：行内报错不抛出（T-04-04-02）。
      debugPrint('[general_settings_content] directory picker failed: $error');
      if (!mounted) {
        return;
      }
      _pathStatus.value = const _InvalidStatus(
        ConfiguredDirectoryFailure.notWritable,
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (directory == null || directory.trim().isEmpty) {
      // null（取消）≠ 清空：不触发任何校验/保存/重定向副作用。
      return;
    }
    // 回填后走与手输相同的防抖校验→保存→apply 链路。
    _pathController.text = directory;
    _onPathChanged(directory);
  }

  /// 生产默认网关 —— file_picker v11 静态 API：lockParentWindow 保持目录
  /// 对话框模态前置（与 file_picker_adapters.dart 的 pickFiles 同参先例）。
  Future<String?> _pickDirectoryWithPlugin() => FilePicker.getDirectoryPath(
        dialogTitle: AppLocalizations.of(context).logPathBrowse,
        lockParentWindow: true,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Tokens.spLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildErrorCardToggleRow(l10n),
          const SizedBox(height: Tokens.spMd),
          _buildLogPathSection(l10n),
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

  /// 日志路径行区块 —— 标签行（含浏览）+ 输入框 + 行内状态区。
  Widget _buildLogPathSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsRow(
          label: l10n.logPathLabel,
          trailing: _BrowseButton(
            key: const ValueKey('settings-log-path-browse'),
            label: l10n.logPathBrowse,
            onTap: _browseForDirectory,
          ),
        ),
        const SizedBox(height: Tokens.spXs),
        TextField(
          controller: _pathController,
          onChanged: _onPathChanged,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
          ),
          decoration: InputDecoration(
            hintText: l10n.logPathHint,
            hintStyle: const TextStyle(
              color: Tokens.textTertiary,
              fontSize: Tokens.fontCaption,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Tokens.spSm,
              vertical: Tokens.spSm,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.borderHighlight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.accent),
            ),
          ),
        ),
        const SizedBox(height: Tokens.spXs),
        ValueListenableBuilder<_PathStatus>(
          valueListenable: _pathStatus,
          builder: (context, status, _) => _PathStatusLine(status: status),
        ),
        // D-04 第一通道 —— 有效路径常显；配置目录失效而走默认链时附加原因。
        ValueListenableBuilder<String?>(
          valueListenable: DiagnosticLogTarget.I.effectiveLogPath,
          builder: (context, effectivePath, _) {
            return ValueListenableBuilder<ErrorFeedbackSettingsData>(
              valueListenable: ErrorFeedbackSettings.I.state,
              builder: (context, settings, _) {
                return _EffectivePathLine(
                  effectivePath: effectivePath,
                  fellBack: _fellBack(
                    settings.logDirectory,
                    effectivePath,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// 「已回退」呈现判断 —— best-effort 展示启发（非正确性门）：配置目录非空
  /// 且有效路径不在其之下即视为回退。落点形态固定为 `<dir><sep>error.log`
  ///（与协调器 _logFileIn 同构），前缀比对在构造层即一致，无需归一化。
  static bool _fellBack(String configured, String? effectivePath) {
    final base = configured.trim();
    if (base.isEmpty || effectivePath == null) {
      return false;
    }
    return !(effectivePath == base ||
        effectivePath.startsWith('$base${Platform.pathSeparator}'));
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

  /// 行本体点击（可为 null —— 路径行无行级交互）。
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

/// 「浏览」按钮 — 与 setting_action_row 的 value 徽标同视觉语言的小胶囊。
class _BrowseButton extends StatelessWidget {
  const _BrowseButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusBtn),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spSm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: Tokens.bgHover,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          border: Border.all(color: Tokens.borderHighlight, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
          ),
        ),
      ),
    );
  }
}

/// 行内校验状态行 —— 依 sealed 状态映射本地化文案与语义色。
class _PathStatusLine extends StatelessWidget {
  const _PathStatusLine({required this.status});

  final _PathStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (status) {
      _IdleStatus() => const SizedBox.shrink(),
      _ValidatingStatus() => _StatusText(
          l10n.logPathValidatingStatus,
          Tokens.textSecondary,
        ),
      _ValidStatus() => _StatusText(l10n.logPathValidStatus, Tokens.accent),
      _InvalidStatus() => _StatusText(
          l10n.logPathInvalidStatus,
          Tokens.danger,
        ),
    };
  }
}

/// 有效路径行 —— D-04 第一通道：当前有效路径常显；回退时附加原因行。
class _EffectivePathLine extends StatelessWidget {
  const _EffectivePathLine({
    required this.effectivePath,
    required this.fellBack,
  });

  /// 当前有效日志落点（协调器权威读数；null = 尚未激活，不渲染误导占位）。
  final String? effectivePath;

  final bool fellBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = effectivePath;
    if (path == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.logEffectivePathLabel}：$path',
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
          ),
        ),
        if (fellBack)
          Text(
            l10n.logFallbackReasonPrefix,
            style: const TextStyle(
              color: Tokens.warning,
              fontSize: Tokens.fontCaption,
            ),
          ),
      ],
    );
  }
}

/// 状态小字 —— 语义色承载 ✓/✗ 的视觉分层（可写 accent / 失败 danger）。
class _StatusText extends StatelessWidget {
  const _StatusText(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: Tokens.fontCaption,
      ),
    );
  }
}
