import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/models/playlist_sort.dart';
import '../../l10n/app_localizations.dart';
import '../player/workspace_menu_session.dart';
import '../shared/owned_anchored_menu.dart';
import '../shared/secondary_surface_visibility.dart';

/// 播放列表排序菜单控制器 — 排序按钮焦点 + 锚定菜单生命周期 (v0.0.6).
///
/// Owns the sort-trigger [FocusNode], the anchored menu handle and the early
/// key latch. 面板 State 只持有一个实例并转发 [cancel]/[dispose].
class PlaylistSortMenu {
  /// [isVisible] 读取面板当前可见性; [isMounted] 读取宿主 State 是否仍挂载.
  PlaylistSortMenu({required this.isVisible, required this.isMounted});

  /// 面板当前是否可见.
  final bool Function() isVisible;

  /// 宿主 State 是否仍挂载 (菜单 await 之后的守卫).
  final bool Function() isMounted;

  final Object _owner = Object();
  OwnedMenuHandle<PlaylistSortKey>? _handle;

  /// 排序触发按钮焦点节点 — 菜单关闭后焦点回落点.
  final FocusNode focusNode = FocusNode(debugLabel: 'playlist-sort-trigger');

  /// Observe only the actual trigger: latch before FAD activates or mutates
  /// routes. 注册为 FocusManager early handler, 永不消费事件.
  KeyEventResult onEarlyKey(KeyEvent event) {
    final trigger = focusNode.context;
    if (trigger == null ||
        !focusNode.hasPrimaryFocus ||
        !isVisible() ||
        ModalRoute.of(trigger)?.isCurrent != true ||
        SecondarySurfaceVisibility.read(trigger)?.value == false ||
        event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      WorkspaceMenuScope.maybeOf(trigger)?.session.latchEvent(event);
    }
    return KeyEventResult.ignored;
  }

  /// 排序方式菜单 — 锚定排序按钮下方, 当前键打勾并显示方向箭头.
  /// 同键再次选择 = 翻转方向 (由协调器裁定, 经 [onSelected] 转发).
  Future<void> open(
    BuildContext buttonContext, {
    required PlaylistSortKey sortKey,
    required bool ascending,
    required ValueChanged<PlaylistSortKey> onSelected,
  }) async {
    final l10n = AppLocalizations.of(buttonContext);
    final handle = OwnedAnchoredMenu.open<PlaylistSortKey>(
      buttonContext,
      owner: _owner,
      triggerFocus: focusNode,
      entries: [
        for (final key in PlaylistSortKey.values)
          OwnedMenuEntry(
            value: key,
            label: _label(key, l10n),
            isChecked: key == sortKey,
            icon: key == sortKey
                ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
                : null,
          ),
      ],
    );
    _handle = handle;
    final action = await handle.result;
    if (!identical(_handle, handle)) return;
    _handle = null;
    if (!isMounted() ||
        action == null ||
        !isVisible() ||
        !buttonContext.mounted ||
        SecondarySurfaceVisibility.read(buttonContext)?.value == false ||
        ModalRoute.of(buttonContext)?.isCurrent != true) {
      return;
    }
    // Checked keys are still actions: the coordinator alone flips direction.
    onSelected(action.value);
  }

  /// 取消在显菜单 (面板 deactivate/dispose 时调用).
  void cancel() => _handle?.cancel();

  /// 释放焦点节点 — 先 [cancel] 再释放, 顺序与重构前一致.
  void dispose() {
    cancel();
    focusNode.dispose();
  }

  /// 排序键 → 菜单文案.
  static String _label(PlaylistSortKey key, AppLocalizations l10n) =>
      switch (key) {
        PlaylistSortKey.addedOrder => l10n.sortByAddedOrder,
        PlaylistSortKey.name => l10n.sortByName,
        PlaylistSortKey.lastPlayed => l10n.sortByLastPlayed,
        PlaylistSortKey.duration => l10n.sortByDuration,
      };
}
