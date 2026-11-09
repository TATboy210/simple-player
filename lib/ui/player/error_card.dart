import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/diagnostics/diagnostic_pack_formatter.dart';
import '../../kernel/diagnostics/error_report.dart';
import '../../kernel/diagnostics/error_reporter.dart';
import '../../kernel/diagnostics/kernel_logger.dart';
import '../../l10n/app_localizations.dart';
import '../shared/secondary_surface.dart';
import '../shared/osd_overlay.dart';
import 'error_card_header.dart';
import 'error_card_message.dart';
import 'error_card_sections.dart';
import '../theme/tokens.dart';

/// 错误卡片 — 折叠摘要 + 展开详情的纯呈现 widget（CARD-03/D-03/D-04）。
///
/// 职责边界（Unix 原则：只做好一件事）：
/// - **折叠态**：severity 色点 + message（l10nKey 解析）+ 媒体路径 basename
///   + D-01 计数徽标 + chevron 指示；
/// - **展开态**：D-04 Phase 2 段序五段 —— 定位 → 源码行 → 调用栈 → 日志路径
///   → 重复信息，整体包在单一外层 SingleChildScrollView 内滚动（IN-02：
///   单一外层滚动，SelectableText 附带自由文本选择；A2：栈硬上界
///   16384 字符，无需虚拟化）；
/// - **交互**：整卡点击切换折叠/展开（StatefulWidget 内部状态，无新状态库）；
///   一键复制诊断包（CARD-04/D-06，失败隔离）；徽标点击轮览历史错误
///   （D-01/D-11，宿主接线，纯视图偏移）；关闭按钮与 hit-test 宿主级
///   义务归 03-02 Task 2；
/// - **数据来源不变**：投影不可变 [ErrorReport]，intake 已脱敏限界；
///   T-03-05 —— 可见树不渲染 fullMediaPath/failedOpenPath 完整路径字段。
///
/// 视觉复用 [SecondarySurface]（D-03 零新视觉体系）；border 按严重级语义色
/// 分层（[Tokens.warning]/[Tokens.danger]/[Tokens.dangerFatal]）。ClipRRect
/// surface clipping includes the rounded hit-test boundary，这是 CARD-02 hit-test 边界的实现基础。
class ErrorCard extends StatefulWidget {
  /// Creates the expandable error card projecting the immutable [report].
  const ErrorCard({
    super.key,
    required this.report,
    required this.totalCount,
    this.onBadgeTap,
    this.onClose,
    this.onOpenLog,
    this.osdService,
  });

  /// Borrowed feedback service; defaults to the production singleton.
  /// The card never resets or disposes it.
  final OsdService? osdService;

  /// The report to project; fields are already redacted/bounded at intake —
  /// this widget never renders developer-only full paths (T-03-05). The host
  /// decides which snapshot entry (newest or cycled) to project here.
  final ErrorReport report;

  /// D-01/D-11 计数徽标：宿主本地快照长度（已捕获且未被手动关闭的错误数，
  /// 封顶 20）。
  final int totalCount;

  /// D-01/D-11 徽标轮览回调（03-03 接线）：点击沿宿主本地快照向旧循环翻页。
  ///
  /// **纯视图偏移** —— 轮览绝不调用 dismissById（research Anti-Pattern：
  /// dismiss 只由手动关闭（[onClose]）触发）。为 null 时徽标不可点（纯计数
  /// 展示）。
  final VoidCallback? onBadgeTap;

  /// CARD-01 手动关闭回调 —— 宿主以闭包捕获当前渲染的 report，接线
  /// `ErrorReporterImpl.I.dismissById(report.eventId)`（关闭精确命中所显示
  /// 条目，WR-01 裁决）；只在手动关闭调用，徽标轮览不得复用此路径。
  final VoidCallback? onClose;

  /// E97 打开日志回调 —— 宿主接线以资源管理器定位当前生效 error.log
  /// （`explorer.exe /select,`）；路径解析与失败隔离（ProcessException →
  /// OSD 反馈）全在宿主 [_openLog] 内完成，卡片只负责暴露动作入口。
  /// 为 null 时不渲染按钮（与 [onClose] 同一条件渲染纪律）。
  final VoidCallback? onOpenLog;

  @override
  State<ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<ErrorCard> {
  /// 折叠/展开状态 —— 整卡点击切换（D-04），卡片内部状态即可，无新状态库。
  bool _expanded = false;

  /// 整卡点击切换折叠态（D-04）。
  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  void didUpdateWidget(covariant ErrorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 跨报告展开态残留防护（v0.0.12 S5）：宿主换 report（新错误上屏或徽标
    // 轮览切页，eventId 不同）时重置为折叠 —— 否则上一份报告的展开动作会
    // 泄漏到新报告，卡片直接以展开态展示新报告的完整调用栈（错条栈的误导
    // 展示）。didUpdateWidget 后框架必然 rebuild，直接赋值即可，无需 setState。
    if (widget.report.eventId != oldWidget.report.eventId) {
      _expanded = false;
    }
  }

  /// D-03 严重级语义色映射 —— 三值均有 token 来源，无硬编码色字面量。
  Color _severityColor(ErrorSeverity severity) => switch (severity) {
    ErrorSeverity.warning => Tokens.warning,
    ErrorSeverity.error => Tokens.danger,
    ErrorSeverity.fatal => Tokens.dangerFatal,
  };

  /// Phase 2 契约：diagnosticLogPath 是 `ValueListenable<String?>`，展开区取
  /// 当前值渲染；reporter 未初始化（纯卡片单测）或未配置 sink 时为 null，
  /// 由调用方降级为 errorCardLogUnavailable 文案。
  String? _resolveLogPath() {
    if (!ErrorReporterImpl.isInitialized) return null;
    return ErrorReporterImpl.I.diagnosticLogPath?.value;
  }

  /// 借用的反馈服务 — 缺省为生产单例.
  OsdService get _osd => widget.osdService ?? OsdService.I;

  /// CARD-04/D-06 一键复制诊断包 —— 格式一律走
  /// [formatDiagnosticPack]（LOG-05 单一来源，F11 用户裁决 2026-10-09 契约
  /// 修订：卡内复制 == **脱敏变体** —— `redactPaths: true`，剪贴板三路径只留
  /// basename，完整路径只落 error.log；落盘日志保持全文不变，卡内禁止自拼
  /// 格式字符串），logPath 在**复制时刻**从 `diagnosticLogPath.value` 取值
  /// （不缓存，与展开区日志路径段同一读取路径）。
  ///
  /// 失败隔离（T-03-11）：typed catch 只捕 [PlatformException] 与
  /// [MissingPluginException]（widget 测试未 mock channel 的天然路径），
  /// 两态都以 OsdService pill 反馈（成功「已复制+完整路径见 error.log」/
  /// 失败「复制失败」）；不捕获任何 Error 子类型，异常绝不外溢到调用方，
  /// 卡片可见性与内容不受复制结果影响。复制期间折叠/展开状态不变（D-06）。
  Future<void> _copyDiagnosticPack() async {
    // l10n 必须在 await 之前解析（await 后使用 context 需 mounted 检查，
    // 提前捕获一次即可覆盖成功/失败两条反馈路径）。
    final l10n = AppLocalizations.of(context);
    final pack = formatDiagnosticPack(
      widget.report,
      logPath: _resolveLogPath(),
      redactPaths: true,
    );
    try {
      await Clipboard.setData(ClipboardData(text: pack));
      _osd.show(
        l10n.errorCardCopiedPathInLog,
        icon: Icons.check,
        priority: OsdPriority.success,
      );
    } on PlatformException catch (error) {
      _showCopyFailed(l10n);
      // PlatformException 属可恢复运行期故障：结构化 warn 供日志回溯。
      _logCopyWarning('clipboard copy failed', {
        'code': error.code,
        'message': error.message,
      });
    } on MissingPluginException catch (error) {
      // 防御分支：Clipboard 走 OptionalMethodChannel，其 invokeMethod 已在
      // 内部吞掉 MissingPluginException（测试环境未 mock 的 send 更是永不
      // 完成）—— 此 catch 正常不可触达，保留以对冲 channel 实现变化。
      _showCopyFailed(l10n);
      _logCopyWarning(
        'clipboard channel unavailable (MissingPluginException)',
        {'error': error.toString()},
      );
    }
  }

  /// 复制失败的结构化 warn — WR-02/CARD-04：KernelLogger.I 在未 init 时抛
  /// StateError，失败隔离路径不得自己先炸，先用 isInitialized 探针守卫.
  void _logCopyWarning(String message, Map<String, Object?> context) {
    if (KernelLoggerImpl.isInitialized) {
      KernelLogger.I.w(message, context: context);
    }
  }

  /// 复制失败两态共用的 OSD 反馈（D-06「复制失败」pill）。
  void _showCopyFailed(AppLocalizations l10n) {
    _osd.show(
      l10n.errorCardCopyFailed,
      icon: Icons.error_outline,
      priority: OsdPriority.failure,
    );
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(widget.report.severity);
    // Clipping belongs to the opaque surface, including its hit-test boundary.
    return GestureDetector(
      onTap: _toggle,
      child: SecondarySurface(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spMd,
          vertical: Tokens.spSm,
        ),
        borderColor: severityColor,
        child: SingleChildScrollView(
          child: _buildContent(context, severityColor),
        ),
      ),
    );
  }

  /// 卡片正文 — 动作行 + message + 媒体 basename + 展开五段.
  ///
  /// One outer scroll owns both full summary and diagnostics; action row stays
  /// before the message so long text cannot bury copy/log/close controls.
  Widget _buildContent(BuildContext context, Color severityColor) {
    final l10n = AppLocalizations.of(context);
    final report = widget.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ErrorCardHeader(
          severityColor: severityColor,
          totalCount: widget.totalCount,
          expanded: _expanded,
          onCopy: () => unawaited(_copyDiagnosticPack()),
          onBadgeTap: widget.onBadgeTap,
          onOpenLog: widget.onOpenLog,
          onClose: widget.onClose,
        ),
        // message 一律纯文本渲染，无富文本解析。
        Text(
          resolveErrorCardMessage(l10n, report),
          softWrap: true,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontBody,
          ),
        ),
        ..._mediaPathLine(report.mediaPath),
        // 展开态五段（D-04 Phase 2 诊断包段序）；包在外层可滚动区内 ——
        // 展开高度超出窗口可用空间时滚动而非溢出.
        if (_expanded)
          ErrorCardExpandedSections(report: report, logPath: _resolveLogPath()),
      ],
    );
  }

  /// D-07：折叠区媒体路径只允许 basename 形态（intake 已脱敏 + 防御性截取）;
  /// 无路径时返回空列表.
  List<Widget> _mediaPathLine(String? mediaPath) {
    final basename = _displayMediaPath(mediaPath);
    if (basename == null) return const [];
    return [
      const SizedBox(height: Tokens.spXs),
      Text(basename, style: errorCardSecondaryStyle),
    ];
  }

  /// D-07 折叠区媒体路径展示值：只允许 basename。
  ///
  /// intake 对本地路径/file URI 已脱敏为 basename；URL 等原样值在此再做一次
  /// 防御性截取（兼容两种分隔符），保证完整路径绝不进入可见树（T-03-05）。
  static String? _displayMediaPath(String? mediaPath) {
    if (mediaPath == null || mediaPath.isEmpty) return null;
    return mediaPath.split(RegExp(r'[/\\]')).last;
  }
}
