import 'package:flutter/material.dart';

import '../../kernel/diagnostics/error_report.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart';
import '../theme/tokens.dart';

/// 错误卡片折叠视图 — 纯呈现 widget，投影不可变 [ErrorReport]（CARD-03）。
///
/// 职责边界（Unix 原则：只做好一件事）：
/// - 本计划（03-01）只渲染折叠摘要：severity 色点 + message + 计数徽标；
/// - 展开区（定位/源码行/调用栈/日志路径）、复制动作与徽标轮览由 03-02/03-03
///   在同一骨架上扩展，不改动数据来源；
/// - D-03 完整语义色分层（warning/fatal 区分）在 03-02 扩展，当前统一用
///   [Tokens.danger] 固定色（四个捕获源不产生 warning，无 stub 需要）。
///
/// 视觉复用 [GlassContainer]（D-03 零新视觉体系）；ClipRRect 会把命中测试
/// 一并裁剪到圆角矩形内，这是 CARD-02 hit-test 边界的实现基础之一。
class ErrorCard extends StatelessWidget {
  /// Creates the collapsed error card projecting the immutable [report].
  const ErrorCard({super.key, required this.report, required this.totalCount});

  /// The FIFO head report to project; fields are already redacted/bounded at
  /// intake — this widget never renders developer-only full paths (T-03-01).
  final ErrorReport report;

  /// D-01 计数徽标：已捕获错误总数（含队首）。
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 严重级色点 —— T-03-02: message 一律纯 Text 渲染,无富文本解析。
          Container(
            width: Tokens.spSm,
            height: Tokens.spSm,
            decoration: const BoxDecoration(
              color: Tokens.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Tokens.spSm),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Tokens.errorCardMaxWidth,
            ),
            child: Text(
              report.message,
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
                l10n.errorCardBadgeLabel(totalCount),
                style: const TextStyle(
                  color: Tokens.textSecondary,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
