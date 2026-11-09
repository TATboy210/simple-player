import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../shared/glass_confirm_strip.dart';
import '../theme/tokens.dart';
import 'pending_playlist_confirmation.dart';

/// 面板内确认遮罩 — 命中屏蔽层 + 居中 [GlassConfirmStrip].
///
/// The hit-test shield is bounded by the existing panel, never the player.
/// 点击遮罩 = 取消; U2 封闭焦点域由 [FocusScope.onKeyEvent] 执行 Tab 回绕.
class PlaylistConfirmationOverlay extends StatelessWidget {
  /// 创建确认遮罩.
  const PlaylistConfirmationOverlay({
    super.key,
    required this.pending,
    required this.cancelFocus,
    required this.confirmFocus,
    required this.onFinish,
    required this.onKeyEvent,
  });

  /// 待确认的冻结快照 (提供文案).
  final PendingPlaylistConfirmation pending;

  /// 取消按钮焦点节点.
  final FocusNode cancelFocus;

  /// 确认按钮焦点节点.
  final FocusNode confirmFocus;

  /// 结束确认 — true = 确认, false = 取消.
  final ValueChanged<bool> onFinish;

  /// 焦点域按键拦截 (Tab 陷阱) — handled 先于 FocusManager 默认遍历生效.
  final KeyEventResult Function(KeyEvent event) onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onFinish(false),
              child: const ColoredBox(color: Tokens.bgGlass),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.spSm),
              child: Center(
                // U2 封闭焦点域: FocusTraversalGroup 声明遍历边界.
                child: FocusScope(
                  onKeyEvent: (node, event) => onKeyEvent(event),
                  child: FocusTraversalGroup(
                    child: GlassConfirmStrip(
                      message: pending.message,
                      cancelLabel: l10n.cancel,
                      confirmTooltip: l10n.batchDeleteConfirmAction,
                      cancelFocus: cancelFocus,
                      confirmFocus: confirmFocus,
                      onCancel: () => onFinish(false),
                      onConfirm: () => onFinish(true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
