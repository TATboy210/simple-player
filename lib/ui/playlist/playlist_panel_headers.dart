import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../kernel/models/play_mode.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_container.dart' show GlassButton;
import '../shared/play_mode_utils.dart';
import '../theme/tokens.dart';

/// 面板标题行文字样式 — 常态/批量共用, 仅颜色不同.
TextStyle _headerStyle(Color color) => TextStyle(
  color: color,
  fontSize: Tokens.fontBody,
  fontWeight: Tokens.weightSemiBold,
);

/// 常态标题行 — 标题 + 排序 + 模式切换 + 关闭.
///
/// Normal header row. v0.0.6: 三按钮统一 GlassButton.iconOnly 方块风格,
/// 向控制栏看齐. 模式图标随 [playMode] 变化, 点击循环切换.
class PlaylistNormalHeader extends StatelessWidget {
  /// 创建常态标题行.
  const PlaylistNormalHeader({
    super.key,
    required this.sortFocus,
    required this.onSortPressed,
    required this.playMode,
    required this.onCyclePlayMode,
    required this.onClose,
  });

  /// 排序按钮焦点节点 (菜单关闭后焦点回落).
  final FocusNode sortFocus;

  /// 排序按钮回调 — 接收按钮自身 context 作为菜单锚点.
  final Future<void> Function(BuildContext buttonContext) onSortPressed;

  /// 当前播放模式 — 驱动模式按钮图标.
  final ValueListenable<PlayMode> playMode;

  /// 切换播放模式.
  final VoidCallback onCyclePlayMode;

  /// 关闭面板.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(l10n.playlist, style: _headerStyle(Tokens.textPrimary)),
        ),
        // 排序 (v0.0.6) — 弹出排序方式菜单.
        Builder(
          builder: (buttonContext) => GlassButton.iconOnly(
            icon: Icons.sort,
            focusNode: sortFocus,
            tooltip: l10n.sortBy,
            onPressed: () => unawaited(onSortPressed(buttonContext)),
          ),
        ),
        // 模式切换 — 图标随 playMode 变化, 点击循环切换.
        ValueListenableBuilder<PlayMode>(
          valueListenable: playMode,
          builder: (_, mode, _) => GlassButton.iconOnly(
            icon: playModeIcon(mode),
            tooltip: playModeLabel(mode, l10n),
            onPressed: onCyclePlayMode,
          ),
        ),
        GlassButton.iconOnly(
          icon: Icons.close,
          tooltip: l10n.close,
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// 批量模式操作条 (v0.0.7) — 已选计数 + 全选 + 删除 + 取消.
///
/// Batch-selection action bar replacing the normal header in place.
class PlaylistBatchHeader extends StatelessWidget {
  /// 创建批量操作条.
  const PlaylistBatchHeader({
    super.key,
    required this.selectedCount,
    required this.onToggleSelectAll,
    required this.onDelete,
    required this.onCancel,
  });

  /// 已选条目数.
  final int selectedCount;

  /// 全选/反选.
  final VoidCallback onToggleSelectAll;

  /// 删除选中项 (确认条后执行); 0 选中时按钮自动禁用.
  final VoidCallback onDelete;

  /// 退出批量模式.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.batchSelectedCount(selectedCount),
            style: _headerStyle(Tokens.accent),
          ),
        ),
        // 全选/反选 — 图标随全选态切换.
        GlassButton.iconOnly(
          icon: selectedCount > 0 ? Icons.deselect : Icons.select_all,
          tooltip: l10n.selectAll,
          onPressed: onToggleSelectAll,
        ),
        // 删除 — 确认对话框后执行 (0 选中时禁用).
        GlassButton.iconOnly(
          icon: Icons.delete_outline,
          tooltip: l10n.batchDeleteConfirmAction,
          onPressed: selectedCount == 0 ? null : onDelete,
        ),
        GlassButton.iconOnly(
          icon: Icons.close,
          tooltip: l10n.cancel,
          onPressed: onCancel,
        ),
      ],
    );
  }
}
