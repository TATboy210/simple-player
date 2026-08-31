import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/diagnostics/diagnostic_pack_formatter.dart';
import '../../kernel/diagnostics/error_report.dart';
import '../../kernel/diagnostics/error_reporter.dart';
import '../../kernel/diagnostics/kernel_logger.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';
import '../shared/osd_overlay.dart';
import '../theme/tokens.dart';

/// 错误卡片 — 折叠摘要 + 展开详情的纯呈现 widget（CARD-03/D-03/D-04）。
///
/// 职责边界（Unix 原则：只做好一件事）：
/// - **折叠态**：severity 色点 + message（l10nKey 解析）+ 媒体路径 basename
///   + D-01 计数徽标 + chevron 指示；
/// - **展开态**：D-04 Phase 2 段序五段 —— 定位 → 源码行 → 调用栈 → 日志路径
///   → 重复信息，整体包在单一外层 SingleChildScrollView 内滚动（IN-02：
///   删除内层同轴死滚动，SelectableText 附带自由文本选择；A2：栈硬上界
///   16384 字符，无需虚拟化）；
/// - **交互**：整卡点击切换折叠/展开（StatefulWidget 内部状态，无新状态库）；
///   一键复制诊断包（CARD-04/D-06，失败隔离）；徽标点击轮览历史错误
///   （D-01/D-11，宿主接线，纯视图偏移）；关闭按钮与 hit-test 宿主级
///   义务归 03-02 Task 2；
/// - **数据来源不变**：投影不可变 [ErrorReport]，intake 已脱敏限界；
///   T-03-05 —— 可见树不渲染 fullMediaPath/failedOpenPath 完整路径字段。
///
/// 视觉复用 [GlassContainer]（D-03 零新视觉体系）；border 按严重级语义色
/// 分层（[Tokens.warning]/[Tokens.danger]/[Tokens.dangerFatal]）。ClipRRect
/// 会把命中测试一并裁剪到圆角矩形内，这是 CARD-02 hit-test 边界的实现基础。
class ErrorCard extends StatefulWidget {
  /// Creates the expandable error card projecting the immutable [report].
  const ErrorCard({
    super.key,
    required this.report,
    required this.totalCount,
    this.onBadgeTap,
    this.onClose,
  });

  /// The report to project; fields are already redacted/bounded at intake —
  /// this widget never renders developer-only full paths (T-03-05). The host
  /// decides which snapshot entry (newest or cycled) to project here.
  final ErrorReport report;

  /// D-01/D-11 计数徽标：宿主本地快照长度（已捕获且未被手动关闭的错误数，
  /// 封顶 20）。
  final int totalCount;

  /// D-01/D-11 徽标轮览回调（03-03 接线）：点击沿宿主本地快照向旧循环翻页。
  ///
  /// **纯视图偏移** —— 轮览绝不调用 dismissCurrent（research Anti-Pattern：
  /// 误用会永久丢队首）；`dismissCurrent` 仅由手动关闭（[onClose]）与
  /// D-02 warning 分流调用。为 null 时徽标不可点（纯计数展示）。
  final VoidCallback? onBadgeTap;

  /// CARD-01 手动关闭回调 —— 宿主接线 `ErrorReporterImpl.I.dismissCurrent()`
  /// （关闭推进 FIFO）；只在手动关闭调用，徽标轮览不得复用此路径。
  final VoidCallback? onClose;

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
  /// 迁移基线 —— 与旧横幅（legacy banner，03-04 已删除）的 13 key 枚举逐项
  /// 一致，D-09 明确**不**迁移其动作按钮 switch）。
  ///
  /// ErrorReport 不携带 PlayerError 对象，只携带 intake 快照的
  /// `playerErrorCode`（`file:fileNotFound` 形态）——先还原为与旧横幅同构的
  /// `error.file.fileNotFound` 键，再走完全一致的 switch，保证旧横幅删除后
  /// 零解析能力缺口。非 player 来源（无 code）直接用 raw
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

  /// CARD-04/D-06 一键复制诊断包 —— 格式一律走
  /// [formatDiagnosticPack]（LOG-05 单一来源：卡内复制 == 日志文件格式，
  /// 卡内禁止自拼格式字符串），logPath 在**复制时刻**从
  /// `diagnosticLogPath.value` 取值（不缓存，与展开区日志路径段同一读取路径）。
  ///
  /// 失败隔离（T-03-11）：typed catch 只捕 [PlatformException] 与
  /// [MissingPluginException]（widget 测试未 mock channel 的天然路径），
  /// 两态都以 OsdService pill 反馈（成功「已复制」/失败「复制失败」）；
  /// 不捕获任何 Error 子类型，异常绝不外溢到调用方，卡片可见性与内容
  /// 不受复制结果影响。复制期间折叠/展开状态不变（D-06）。
  Future<void> _copyDiagnosticPack() async {
    // l10n 必须在 await 之前解析（await 后使用 context 需 mounted 检查，
    // 提前捕获一次即可覆盖成功/失败两条反馈路径）。
    final l10n = AppLocalizations.of(context);
    final pack = formatDiagnosticPack(
      widget.report,
      logPath: _resolveLogPath(),
    );
    try {
      await Clipboard.setData(ClipboardData(text: pack));
      OsdService.I.show(l10n.errorCardCopied, icon: Icons.check);
    } on PlatformException catch (error) {
      _showCopyFailed(l10n);
      // PlatformException 属可恢复运行期故障：结构化 warn 供日志回溯
      // （kernel 红线内 UI 层允许 debugPrint，但结构化日志优先）。
      // WR-02/CARD-04：KernelLogger.I 在未 init 时抛 StateError —— 失败
      // 隔离路径不得自己先炸，先用 isInitialized 探针守卫。
      if (KernelLoggerImpl.isInitialized) {
        KernelLogger.I.w(
          'clipboard copy failed',
          context: {'code': error.code, 'message': error.message},
        );
      }
    } on MissingPluginException catch (error) {
      // 防御分支：Clipboard 走 OptionalMethodChannel，其 invokeMethod 已在
      // 内部吞掉 MissingPluginException（测试环境未 mock 的 send 更是永不
      // 完成）—— 此 catch 正常不可触达，保留以对冲 channel 实现变化。
      _showCopyFailed(l10n);
      assert(() {
        // 同 WR-02：assert 内的日志调用同样不得在未 init 时抛错。
        if (KernelLoggerImpl.isInitialized) {
          KernelLogger.I.w(
            'clipboard channel unavailable (MissingPluginException)',
            context: {'error': error.toString()},
          );
        }
        return true;
      }());
    }
  }

  /// 复制失败两态共用的 OSD 反馈（D-06「复制失败」pill）。
  void _showCopyFailed(AppLocalizations l10n) {
    OsdService.I.show(l10n.errorCardCopyFailed, icon: Icons.error_outline);
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
            // CR-01：挂载层收口到 errorCardExpandedMaxWidth 后，本 Row 的
            // 可用宽度有界 —— message 必须 Flexible 才能在剩余空间内换行
            // 省略，否则长消息（自身 320 上限）会把 Row 撑溢出。
            Flexible(
              child: ConstrainedBox(
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
            ),
            const SizedBox(width: Tokens.spSm),
            // D-01/D-11 计数徽标：可点击轮览入口（onBadgeTap 由宿主接线，
            // 纯视图偏移不消费队列）。GestureDetector 承载，不用 GlassButton
            // —— 避免 FocusableActionDetector 抢焦点（CARD-01）。
            Semantics(
              label: l10n.errorCardCycleTooltip,
              button: widget.onBadgeTap != null,
              child: GestureDetector(
                key: const ValueKey('error-card-badge'),
                onTap: widget.onBadgeTap,
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
                    l10n.errorCardBadgeLabel(widget.totalCount),
                    style: const TextStyle(
                      color: Tokens.textSecondary,
                      fontSize: Tokens.fontCaption,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Tokens.spSm),
            // CARD-04 一键复制按钮：GestureDetector（不用 GlassButton ——
            // 其 FocusableActionDetector 会请求焦点，破坏 CARD-01 零焦点
            // 抢占）。嵌在整卡 GestureDetector 内层 —— 命中测试天然内层
            // 优先（点复制不触发展开切换），无需 IgnorePointer。
            Semantics(
              label: l10n.errorCardCopyTooltip,
              button: true,
              child: GestureDetector(
                key: const ValueKey('error-card-copy'),
                onTap: () => unawaited(_copyDiagnosticPack()),
                child: const Padding(
                  padding: EdgeInsets.all(Tokens.spXs),
                  child: Icon(
                    Icons.copy,
                    size: Tokens.iconSm,
                    color: Tokens.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Tokens.spSm),
            // D-04 chevron 状态指示（纯指示器，点击切换由整卡 GestureDetector 承担）。
            Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: Tokens.iconSm,
              color: Tokens.textSecondary,
            ),
            // CARD-01 手动关闭：GestureDetector + Semantics 语义（不用
            // GlassButton —— 其 FocusableActionDetector 会请求焦点，破坏
            // KeyboardHandler 单焦点源假设）。onTap 为 null 时不渲染。
            if (widget.onClose != null)
              Semantics(
                label: l10n.errorCardClose,
                button: true,
                child: GestureDetector(
                  key: const ValueKey('error-card-close'),
                  onTap: widget.onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(Tokens.spXs),
                    child: Icon(
                      Icons.close,
                      size: Tokens.iconSm,
                      color: Tokens.textSecondary,
                    ),
                  ),
                ),
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
  List<Widget> _buildExpandedSections(
    AppLocalizations l10n,
    ErrorReport report,
  ) {
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
      // 栈硬上界 16384 字符（A2），外层展开区滚动视图足够（IN-02：内层同轴
      // SingleChildScrollView 恒不可滚且与外层手势冲突，已删除），SelectableText
      // 附带自由文本选择。
      _sectionTitle(l10n.errorCardSectionStack),
      SelectableText(report.rawStackTrace, style: _monoStyle),
      // ④ 日志路径：diagnosticLogPath 当前值；不可用 → 降级文案。
      _sectionTitle(l10n.errorCardSectionLogPath),
      Text(
        _resolveLogPath() ?? l10n.errorCardLogUnavailable,
        style: _secondaryStyle,
      ),
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
