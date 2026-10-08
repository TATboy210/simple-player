import 'package:flutter/material.dart';

import 'owned_anchored_menu.dart';
import '../player/workspace_menu_session.dart';

/// 兼容播放列表菜单入口 — opaque owned PopupRoute, not a glass overlay.
class GlassMenu {
  GlassMenu._();

  /// [position] remains a captured global pointer point for existing tile callers.
  /// The callback receives cancellation for THIS route, never the latest popup.
  static Future<String?> show(
    BuildContext context, {
    required Offset position,
    required List<GlassMenuItem> items,
    void Function(VoidCallback cancel)? onOpened,
  }) {
    final handle = OwnedAnchoredMenu.open<String>(
      context,
      owner: Object(),
      // Legacy tile onOpened installs its own ownership until pass 2C.
      useWorkspaceScope: false,
      onEscape: WorkspaceMenuScope.maybeOf(context)?.onEscape,
      position: position,
      entries: [
        for (final item in items)
          OwnedMenuEntry(
            value: item.value,
            label: item.label,
            icon: item.icon,
            isDestructive: item.isDestructive,
            isEnabled: item.isEnabled,
            isChecked: item.isChecked,
          ),
      ],
    );
    final legacy = WorkspaceMenuScope.maybeOf(context)?.session;
    final before = legacy?.currentToken;
    // Legacy callback can synchronously claim ownership. Its teardown must remove
    // THIS route even after it has invalidated its own token.
    onOpened?.call(handle.cancel);
    final claimed = legacy?.currentToken;
    if (claimed != null && !identical(claimed, before)) {
      legacy?.bindRoute(claimed, handle.route, ModalRoute.of(context));
    }
    return handle.result.then((result) => result?.value);
  }
}

/// 不可变菜单动作 — old positional facade remains source compatible.
class GlassMenuItem {
  const GlassMenuItem(
    this.icon,
    this.label, {
    required this.value,
    this.isDestructive = false,
    this.isEnabled = true,
    this.isChecked = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isDestructive;
  final bool isEnabled;
  final bool isChecked;
}
