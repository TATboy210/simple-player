import 'package:flutter/material.dart';

import '../../kernel/diagnostics/error_report.dart';
import '../../kernel/diagnostics/error_reporter.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';
import '../theme/tokens.dart';

/// 错误卡片 — 折叠摘要 + 展开详情的纯呈现 widget（CARD-03/D-03/D-04）。
///
/// 职责边界（Unix 原则：只做好一件事）：
/// - **折叠态**：severity 色点 + message（l10nKey 解析）+ 媒体路径 basename
///   + D-01 计数徽标 + chevron 指示；
/// - **展开态**：D-04 Phase 2 段序五段 —— 定位 → 源码行 → 调用栈 → 日志路径
///   → 重复信息，长文本段 SingleChildScrollView + SelectableText（A2：栈硬
///   上界 16384 字符，无需虚拟化）；
/// - **交互**：整卡点击切换折叠/展开（StatefulWidget 内部状态，无新状态库）；
///   徽标点击为空操作占位（轮览接线归 03-03）；关闭按钮与 hit-test 宿主级
///   义务归 03-02 Task 2；
/// - **数据来源不变**：投影不可变 [ErrorReport]，intake 已脱敏限界；
///   T-03-05 —— 可见树不渲染 fullMediaPath/failedOpenPath 完整路径字段。
///
/// 视觉复用 [GlassContainer]（D-03 零新视觉体系）；border 按严重级语义色
/// 分层（[Tokens.warning]/[Tokens.danger]/[Tokens.dangerFatal]）。ClipRRect
/// 会把命中测试一并裁剪到圆角矩形内，这是 CARD-02 hit-test 边界的实现基础。
class ErrorCard extends StatefulWidget {
  /// Creates the expandable error card projecting the immutable [report].
  const ErrorCard({super.key, required this.report, required this.totalCount});

  /// The FIFO head report to project; fields are already redacted/bounded at
  /// intake — this widget never renders developer-only full paths (T-03-05).
  final ErrorReport report;

  /// D-01 计数徽标：已捕获错误总数（含队首）。
  final int totalCount;

  @override
  State<ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<ErrorCard> {
  /// 折叠/展开状态 —— 整卡点击切换（D-04），卡片内部状态即可，无新状态库。
  bool _expanded = false;

  /// 等宽字体诊断文本样式 —— 源码行/调用栈段共享（terminal 语义）。
  static const _monoStyle = TextStyle(
    color: Tokens.textPrimary,
    fontSize: Tokens.fontCaption,
    fontFamily: Tokens.fontFamilyMono,
  );

  /// 次要信息文本样式 —— 日志路径/时间戳段共享。
  static const _secondaryStyle = TextStyle(
    color: Tokens.textSecondary,
    fontSize: Tokens.fontCaption,
  );

  /// 整卡点击切换折叠态（D-04）。
  void _toggle() => setState(() => _expanded = !_expanded);

  /// D-03 严重级语义色映射 —— 三值均有 token 来源，无硬编码色字面量。
  Color _severityColor(ErrorSeverity severity) => switch (severity) {
    ErrorSeverity.warning => Tokens.warning,
    ErrorSeverity.error => Tokens.danger,
    ErrorSeverity.fatal => Tokens.dangerFatal,
  };

  /// l10nKey → AppLocalizations 查找，未知键 fallback 到原始 message（MIG-01
  /// 迁移基线 —— 与 error_banner.dart 的 13 key 枚举逐项一致，D-09 明确
  /// **不**迁移其动作按钮 switch）。
  ///
  /// ErrorReport 不携带 PlayerError 对象，只携带 intake 快照的
  /// `playerErrorCode`（`file:fileNotFound` 形态）——先还原为与旧横幅同构的
  /// `error.file.fileNotFound` 键，再走完全一致的 switch，保证 03-04 删除
  /// ErrorBanner 后零解析能力缺口。非 player 来源（无 code）直接用 raw
  /// message（全局钩子错误的 message 本身可读）。
  String _resolveMessage(AppLocalizations l10n, ErrorReport report) {
    final code = report.playerErrorCode;
    if (code == null) return report.message;
    // 'file:fileNotFound' → 'error.file.fileNotFound'（unknown → error.unknown）。
    final l10nKey = 'error.${code.replaceFirst(':', '.')}';
    return switch (l10nKey) {
      'error.file.pathEmpty' => l10n.errorFilePathEmpty,
      'error.file.fileNotFound' => l10n.errorFileNotFound,
      'error.file.pathTraversal' => l10n.errorFilepathTraversal,
      'error.codec.unsupportedFormat' => l10n.errorCodecUnsupportedFormat,
      'error.codec.decodeFailed' => l10n.errorCodecDecodeFailed,
      'error.codec.codecUnsupported' => l10n.errorCodecCodecUnsupported,
      'error.playback.playFailed' => l10n.errorPlaybackPlayFailed,
      'error.playback.seekFailed' => l10n.errorPlaybackSeekFailed,
      'error.playback.textureFailed' => l10n.errorPlaybackTextureFailed,
      'error.playback.openTimeout' => l10n.errorPlaybackOpenTimeout,
      'error.network.timeout' => l10n.errorNetworkTimeout,
      'error.network.connectionLost' => l10n.errorNetworkConnectionLost,
      'error.unknown' => l10n.errorUnknown,
      _ => report.message, // fallback: 未知 l10nKey 用原始消息
    };
  }

  /// Phase 2 契约：diagnosticLogPath 是 `ValueListenable<String?>`，展开区取
  /// 当前值渲染；reporter 未初始化（纯卡片单测）或未配置 sink 时为 null，
  /// 由调用方降级为 errorCardLogUnavailable 文案。
  String? _resolveLogPath() {
    if (!ErrorReporterImpl.isInitialized) return null;
    return ErrorReporterImpl.I.diagnosticLogPath?.value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = widget.report;
    final severityColor = _severityColor(report.severity);
    final basename = _displayMediaPath(report.mediaPath);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 严重级色点 —— 语义色随 severity 分层（D-03）；message 一律
            // 纯文本渲染，无富文本解析。
            Container(
              width: Tokens.spSm,
              height: Tokens.spSm,
              decoration: BoxDecoration(
                color: severityColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Tokens.spSm),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Tokens.errorCardMaxWidth,
              ),
              child: Text(
                _resolveMessage(l10n, report),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Tokens.textPrimary,
                  fontSize: Tokens.fontBody,
                ),
              ),
            ),
            const SizedBox(width: Tokens.spSm),
            // D-01 计数徽标：GestureDetector 承载（03-03 接轮览回调），
            // 不用 GlassButton —— 避免 FocusableActionDetector 抢焦点（CARD-01）。
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.spSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Tokens.bgElevated,
                  borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                ),
                child: Text(
                  // 03-03 在此接线徽标轮览；点击目标目前为空操作占位由该
                  // 计划回收 —— 非可消失 stub。
                  l10n.errorCardBadgeLabel(widget.totalCount),
                  style: const TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Tokens.spSm),
            // D-04 chevron 状态指示（纯指示器，点击切换由整卡 GestureDetector 承担）。
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: Tokens.iconSm,
              color: Tokens.textSecondary,
            ),
          ],
        ),
        // D-07：折叠区媒体路径只允许 basename 形态（intake 已脱敏 + 防御性截取）。
        if (basename != null) ...[
          const SizedBox(height: Tokens.spXs),
          Text(basename, style: _secondaryStyle),
        ],
        // 展开态五段（D-04 Phase 2 诊断包段序），一律纯文本渲染；包在可滚动
        // 区内 —— 展开高度超出窗口可用空间时滚动而非溢出（A2：栈硬上界
        // 16384 字符，无需虚拟化）。
        if (_expanded)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _buildExpandedSections(l10n, report),
              ),
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: _toggle,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spMd,
          vertical: Tokens.spSm,
        ),
        // D-03：severity 对应色 border 分层（覆盖默认 borderHighlight）。
        border: Border.all(color: severityColor, width: 1),
        child: content,
      ),
    );
  }

  /// 展开态五段，顺序遵循 D-04 Phase 2 诊断包段序：
  /// 定位 → 源码行 → 调用栈 → 日志路径 → 重复信息。
  ///
  /// location 为 null（D-05 fallback）时定位段降级为 errorCardLocationUnavailable，
  /// 其余段照常展示 —— 不抛错不缺段；源码行段依赖 location 数据，随之省略。
  List<Widget> _buildExpandedSections(AppLocalizations l10n, ErrorReport report) {
    final location = report.location;
    return [
      // ① 定位：file:line + 成员名；无项目帧 → 降级文案。
      _sectionTitle(l10n.errorCardSectionLocation),
      if (location != null)
        SelectableText(
          '${location.primaryFrame.file}:${location.primaryFrame.line}'
          '  ${location.primaryFrame.member}',
          style: _monoStyle,
        )
      else
        Text(l10n.errorCardLocationUnavailable, style: _secondaryStyle),
      // ② 源码行：intake 已格式化为 'lineNumber: text'，逐行原样展示。
      if (location != null && location.sourceLines.isNotEmpty) ...[
        _sectionTitle(l10n.errorCardSectionSource),
        SelectableText(location.sourceLines.join('\n'), style: _monoStyle),
      ],
      // ③ 调用栈：rawStackTrace 逐字符原样（terminal 语义，不二次处理）；
      // 栈硬上界 16384 字符（A2），SingleChildScrollView 足够，SelectableText
      // 附带自由文本选择。
      _sectionTitle(l10n.errorCardSectionStack),
      SingleChildScrollView(
        child: SelectableText(report.rawStackTrace, style: _monoStyle),
      ),
      // ④ 日志路径：diagnosticLogPath 当前值；不可用 → 降级文案。
      _sectionTitle(l10n.errorCardSectionLogPath),
      Text(_resolveLogPath() ?? l10n.errorCardLogUnavailable, style: _secondaryStyle),
      // ⑤ 重复信息：出现次数 + 首次/末次时间。
      _sectionTitle(l10n.errorCardSectionRepeats(report.occurrenceCount)),
      Text(
        '${_formatTime(report.firstOccurredAt)} → '
        '${_formatTime(report.lastOccurredAt)}',
        style: _secondaryStyle,
      ),
    ];
  }

  /// 展开区段标题 —— caption 加粗次要色，与内容保持呼吸间距。
  Widget _sectionTitle(String text) => Padding(
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

  /// ISO8601 UTC 纯文本时间 —— 与诊断包 formatter 的时区口径一致，确定性可测。
  String _formatTime(DateTime time) => time.toUtc().toIso8601String();

  /// D-07 折叠区媒体路径展示值：只允许 basename。
  ///
  /// intake 对本地路径/file URI 已脱敏为 basename；URL 等原样值在此再做一次
  /// 防御性截取（兼容两种分隔符），保证完整路径绝不进入可见树（T-03-05）。
  static String? _displayMediaPath(String? mediaPath) {
    if (mediaPath == null || mediaPath.isEmpty) return null;
    return mediaPath.split(RegExp(r'[/\\]')).last;
  }
}
