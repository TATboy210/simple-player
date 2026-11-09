import 'package:flutter/material.dart';

import '../../kernel/diagnostics/error_report.dart';
import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// 等宽字体诊断文本样式 —— 源码行/调用栈段共享（terminal 语义）。
const TextStyle _monoStyle = TextStyle(
  color: Tokens.textPrimary,
  fontSize: Tokens.fontCaption,
  fontFamily: Tokens.fontFamilyMono,
);

/// 次要信息文本样式 —— 日志路径/时间戳/媒体路径段共享。
const TextStyle errorCardSecondaryStyle = TextStyle(
  color: Tokens.textSecondary,
  fontSize: Tokens.fontCaption,
);

/// 错误卡片展开态五段 — 定位 → 源码行 → 调用栈 → 日志路径 → 重复信息
/// （D-04 Phase 2 诊断包段序）.
///
/// Expanded diagnostic sections, plain-text only. location 为 null（D-05
/// fallback）时定位段降级为 errorCardLocationUnavailable, 其余段照常展示 ——
/// 不抛错不缺段; 源码行段依赖 location 数据, 随之省略. 栈硬上界 16384 字符
/// (A2), 由外层展开区单一滚动视图承载 (IN-02), SelectableText 附带自由
/// 文本选择.
class ErrorCardExpandedSections extends StatelessWidget {
  /// 创建展开态五段.
  const ErrorCardExpandedSections({
    super.key,
    required this.report,
    required this.logPath,
  });

  /// 被投影的报告 (intake 已脱敏限界).
  final ErrorReport report;

  /// 当前生效日志路径; null → errorCardLogUnavailable 降级文案.
  final String? logPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._locationAndSource(l10n),
        // ③ 调用栈：rawStackTrace 逐字符原样（terminal 语义，不二次处理）。
        _SectionTitle(l10n.errorCardSectionStack),
        SelectableText(report.rawStackTrace, style: _monoStyle),
        // ④ 日志路径：diagnosticLogPath 当前值；不可用 → 降级文案。
        _SectionTitle(l10n.errorCardSectionLogPath),
        Text(
          logPath ?? l10n.errorCardLogUnavailable,
          style: errorCardSecondaryStyle,
        ),
        // ⑤ 重复信息：出现次数 + 首次/末次时间。
        _SectionTitle(l10n.errorCardSectionRepeats(report.occurrenceCount)),
        Text(
          '${_formatTime(report.firstOccurredAt)} → '
          '${_formatTime(report.lastOccurredAt)}',
          style: errorCardSecondaryStyle,
        ),
      ],
    );
  }

  /// ① 定位 + ② 源码行 — 均依赖 location.
  List<Widget> _locationAndSource(AppLocalizations l10n) {
    final location = report.location;
    return [
      // ① 定位：file:line + 成员名；无项目帧 → 降级文案。
      _SectionTitle(l10n.errorCardSectionLocation),
      if (location != null)
        SelectableText(
          '${location.primaryFrame.file}:${location.primaryFrame.line}'
          '  ${location.primaryFrame.member}',
          style: _monoStyle,
        )
      else
        Text(l10n.errorCardLocationUnavailable, style: errorCardSecondaryStyle),
      // ② 源码行：intake 已格式化为 'lineNumber: text'，逐行原样展示。
      if (location != null && location.sourceLines.isNotEmpty) ...[
        _SectionTitle(l10n.errorCardSectionSource),
        SelectableText(location.sourceLines.join('\n'), style: _monoStyle),
      ],
    ];
  }

  /// ISO8601 UTC 纯文本时间 —— 与诊断包 formatter 的时区口径一致，确定性可测。
  static String _formatTime(DateTime time) => time.toUtc().toIso8601String();
}

/// 展开区段标题 —— caption 加粗次要色，与内容保持呼吸间距。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.spSm, bottom: Tokens.spXs),
      child: Text(
        text,
        style: const TextStyle(
          color: Tokens.textSecondary,
          fontSize: Tokens.fontCaption,
          fontWeight: Tokens.weightMedium,
        ),
      ),
    );
  }
}
