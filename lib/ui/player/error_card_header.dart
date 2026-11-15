import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// 错误卡片头部动作行 — 严重级色点 + 计数徽标 + 复制 + 打开日志 + chevron
/// + 关闭。
///
/// Header action row of [ErrorCard]. 所有按钮用 GestureDetector 而非
/// GlassButton — 后者的 FocusableActionDetector 会请求焦点, 破坏 CARD-01
/// 零焦点抢占 / KeyboardHandler 单焦点源假设. 按钮嵌在整卡 GestureDetector
/// 内层, 命中测试天然内层优先 (点按钮不触发展开切换). 只渲染图标, 不渲染
/// 任何路径文本 (T-03-05: 完整路径不进可见树).
class ErrorCardHeader extends StatelessWidget {
  /// 创建头部动作行.
  const ErrorCardHeader({
    super.key,
    required this.severityColor,
    required this.totalCount,
    required this.expanded,
    required this.onCopy,
    this.onBadgeTap,
    this.onOpenLog,
    this.onClose,
  });

  /// 严重级语义色 (D-03) — 色点颜色.
  final Color severityColor;

  /// D-01 计数徽标数值.
  final int totalCount;

  /// 当前是否展开 — 决定 chevron 方向.
  final bool expanded;

  /// CARD-04 一键复制回调 (同步签名; 调用方自行 unawaited 异步复制).
  final VoidCallback onCopy;

  /// D-01/D-11 徽标轮览; null 时徽标不可点.
  final VoidCallback? onBadgeTap;

  /// E97 打开日志; null 时不渲染按钮.
  final VoidCallback? onOpenLog;

  /// CARD-01 手动关闭; null 时不渲染按钮.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ErrorCardSeverityDot(color: severityColor),
        const SizedBox(width: Tokens.spSm),
        // CR-01: 挂载层收口到 errorCardExpandedMaxWidth 后本 Row 可用宽度有界.
        const SizedBox(width: Tokens.spSm),
        _CountBadge(
          label: l10n.errorCardBadgeLabel(totalCount),
          semanticLabel: l10n.errorCardCycleTooltip,
          onTap: onBadgeTap,
        ),
        const SizedBox(width: Tokens.spSm),
        ErrorCardIconAction(
          actionKey: const ValueKey('error-card-copy'),
          semanticLabel: l10n.errorCardCopyTooltip,
          icon: Icons.copy,
          onTap: onCopy,
        ),
        const SizedBox(width: Tokens.spSm),
        if (onOpenLog != null)
          ErrorCardIconAction(
            actionKey: const ValueKey('error-card-open-log'),
            semanticLabel: l10n.errorCardOpenLogTooltip,
            icon: Icons.folder_open,
            onTap: onOpenLog,
          ),
        const SizedBox(width: Tokens.spSm),
        // D-04 chevron 状态指示（纯指示器，点击切换由整卡 GestureDetector 承担）。
        Icon(
          expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          size: Tokens.iconSm,
          color: Tokens.textSecondary,
        ),
        if (onClose != null)
          ErrorCardIconAction(
            actionKey: const ValueKey('error-card-close'),
            semanticLabel: l10n.errorCardClose,
            icon: Icons.close,
            onTap: onClose,
          ),
      ],
    );
  }
}

/// 严重级色点 — 语义色随 severity 分层（D-03）. Flat semantic dot:
/// secondary surfaces have no optical glow.
class ErrorCardSeverityDot extends StatelessWidget {
  /// 创建色点.
  const ErrorCardSeverityDot({super.key, required this.color});

  /// 点颜色 (来自 Tokens 语义色).
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Tokens.spSm,
      height: Tokens.spSm,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 图标动作 — GestureDetector + Semantics, 零焦点抢占 (CARD-01).
class ErrorCardIconAction extends StatelessWidget {
  /// 创建图标动作.
  const ErrorCardIconAction({
    super.key,
    required this.actionKey,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  /// 测试/宿主定位用 key (挂在 GestureDetector 上, 与重构前一致).
  final Key actionKey;

  /// 无障碍标签.
  final String semanticLabel;

  /// 图标.
  final IconData icon;

  /// 点击回调.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        key: actionKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.spXs),
          child: Icon(icon, size: Tokens.iconSm, color: Tokens.textSecondary),
        ),
      ),
    );
  }
}

/// D-01/D-11 计数徽标 — 可点击轮览入口 (onTap 为 null 时纯展示).
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  /// 徽标垂直内边距.
  static const double _verticalPadding = 2;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: GestureDetector(
        key: const ValueKey('error-card-badge'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spSm,
            vertical: _verticalPadding,
          ),
          decoration: BoxDecoration(
            color: Tokens.surfaceFloating,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
            ),
          ),
        ),
      ),
    );
  }
}
