import 'package:material_ui/material_ui.dart';

import '../../kernel/utils/path_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/owned_anchored_menu.dart';
import '../shared/secondary_surface_visibility.dart';

/// Captured playlist-entry actions, independent of the currently playing path.
enum PlaylistEntryAction { play, locate, remove, batchDelete }

/// 条目右键菜单控制器 — 持有菜单句柄/焦点触发器, 执行捕获路径上的动作.
///
/// Captured pointer/path, exact typed route, no legacy double claim.
/// 由 [PlaylistTile] State 持有一个实例并转发 deactivate/dispose.
class PlaylistEntryMenu {
  final Object _owner = Object();
  OwnedMenuHandle<PlaylistEntryAction>? _handle;

  /// 触发器焦点节点 — 挂在条目 InkWell 上, 菜单关闭后焦点回落点.
  final FocusNode trigger = FocusNode(debugLabel: 'playlist-entry-trigger');

  /// 弹出菜单并在选定后回调. [path] 为发起时捕获的条目路径; [currentPath]
  /// 读取宿主当前条目路径 (复用 State 时用于失效判定); 动作仅作用于捕获条目.
  Future<void> open(
    BuildContext context,
    Offset position, {
    required String path,
    required String Function() currentPath,
    required bool Function() isMounted,
    required bool canBatchDelete,
    required void Function(PlaylistEntryAction action) onAction,
  }) async {
    final l10n = AppLocalizations.of(context);
    final handle = OwnedAnchoredMenu.open<PlaylistEntryAction>(
      context,
      owner: _owner,
      position: position,
      triggerFocus: trigger,
      // State/FocusNode reuse does not mean the captured entry still owns focus
      // return. Capture only its path, never the mutable playback/item object.
      isOwnerValid: () => isMounted() && currentPath() == path,
      entries: _entries(l10n, canBatchDelete),
    );
    _handle = handle;
    final selection = await handle.result;
    if (!identical(_handle, handle)) return;
    _handle = null;
    if (!isMounted() ||
        !context.mounted ||
        selection == null ||
        path != currentPath() ||
        SecondarySurfaceVisibility.read(context)?.value == false ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    // Act only on the captured entry; a playback switch never invalidates it.
    onAction(selection.value);
  }

  /// 菜单项 — 批量删除仅在面板提供回调时出现.
  List<OwnedMenuEntry<PlaylistEntryAction>> _entries(
    AppLocalizations l10n,
    bool canBatchDelete,
  ) {
    return [
      OwnedMenuEntry(
        value: PlaylistEntryAction.play,
        label: l10n.play,
        icon: Icons.play_arrow,
      ),
      OwnedMenuEntry(
        value: PlaylistEntryAction.locate,
        label: l10n.openFileLocation,
        icon: Icons.folder_open,
      ),
      OwnedMenuEntry(
        value: PlaylistEntryAction.remove,
        label: l10n.remove,
        icon: Icons.delete_outline,
        isDestructive: true,
      ),
      if (canBatchDelete)
        OwnedMenuEntry(
          value: PlaylistEntryAction.batchDelete,
          label: l10n.batchDelete,
          icon: Icons.checklist,
        ),
    ];
  }

  /// 取消在显菜单.
  void cancel() => _handle?.cancel();

  /// 取消菜单并释放焦点节点.
  void dispose() {
    cancel();
    trigger.dispose();
  }

  /// 在系统文件管理器定位文件 — 菜单"打开文件位置"动作.
  static void locate(String path) => PathUtils.openFileLocation(path);
}
