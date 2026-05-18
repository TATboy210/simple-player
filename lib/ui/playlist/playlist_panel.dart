import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../kernel/models/playlist_item.dart';
import '../../kernel/playlist/playlist.dart';
import '../../kernel/utils/time_utils.dart';
import '../../kernel/ui/theme/tokens.dart';

/// 右侧播放列表面板 — 播放列表 / 播放历史 标签页切换
///
/// 功能：
/// - 拖拽排序、点击播放、关闭按钮
/// - 断点位置显示（subtitle）
/// - 右键菜单（播放/复制路径/属性/移除）
/// - Tooltip（断点/总时长信息）
/// - 播放列表 / 播放历史 标签切换
class PlaylistPanel extends StatefulWidget {
  final Playlist playlist;
  final void Function(int index) onSelectIndex;
  final void Function(int index) onRemoveIndex;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onClear;
  final void Function(String path)? onShowProperties;

  const PlaylistPanel({
    super.key,
    required this.playlist,
    required this.onSelectIndex,
    required this.onRemoveIndex,
    required this.onReorder,
    required this.onClear,
    this.onShowProperties,
  });

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel> {
  int _selectedTab = 0; // 0=播放列表, 1=播放历史

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Tokens.playlistPanelWidth,
      decoration: const BoxDecoration(
        color: Tokens.bgPanel,
        border: Border(
          left: BorderSide(color: Tokens.borderHighlight, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            itemCount: widget.playlist.items.length,
            selectedTab: _selectedTab,
            onTabChanged: (i) => setState(() => _selectedTab = i),
            onClear: widget.onClear,
          ),
          const Divider(height: 1, color: Tokens.bgHover),
          Expanded(
            child: _selectedTab == 0 ? _buildPlaylist() : _buildHistory(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist() {
    final items = widget.playlist.items;
    if (items.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).playlistEmpty,
          style: const TextStyle(
            color: Tokens.textDisabled,
            fontSize: Tokens.fontCaption,
          ),
        ),
      );
    }
    return ReorderableListView.builder(
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) {
        // onReorderItem passes unadjusted newIndex; Playlist.reorder expects adjusted
        if (oldIndex < newIndex) newIndex -= 1;
        widget.onReorder(oldIndex, newIndex);
      },
      itemBuilder: (_, index) {
        final item = items[index];
        final isCurrent = index == widget.playlist.currentIndex;
        return _PlaylistItemTile(
          key: ValueKey(item.path),
          item: item,
          isCurrent: isCurrent,
          onSelect: () => widget.onSelectIndex(index),
          onRemove: () => widget.onRemoveIndex(index),
          onShowProperties: widget.onShowProperties,
        );
      },
    );
  }

  Widget _buildHistory() {
    // 播放历史：显示有播放记录的项目（按最近播放排序）
    final historyItems =
        widget.playlist.items
            .asMap()
            .entries
            .where((e) => (e.value.timestamp ?? 0) > 0)
            .toList()
          ..sort(
            (a, b) =>
                (b.value.timestamp ?? 0).compareTo(a.value.timestamp ?? 0),
          );

    if (historyItems.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).noHistory,
          style: const TextStyle(
            color: Tokens.textDisabled,
            fontSize: Tokens.fontCaption,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: historyItems.length,
      itemBuilder: (_, i) {
        final entry = historyItems[i];
        final item = entry.value;
        final originalIndex = entry.key;
        final isCurrent = originalIndex == widget.playlist.currentIndex;
        return _PlaylistItemTile(
          key: ValueKey('history_${item.path}'),
          item: item,
          isCurrent: isCurrent,
          onSelect: () => widget.onSelectIndex(originalIndex),
          onRemove: () => widget.onRemoveIndex(originalIndex),
          onShowProperties: widget.onShowProperties,
        );
      },
    );
  }
}

/// 播放列表单项 — 断点显示 + Tooltip + 右键菜单
class _PlaylistItemTile extends StatelessWidget {
  final PlaylistItem item;
  final bool isCurrent;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final void Function(String path)? onShowProperties;

  const _PlaylistItemTile({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.onSelect,
    required this.onRemove,
    this.onShowProperties,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasBreakpoint = (item.positionMs ?? 0) > 0;
    final baseTooltip = hasBreakpoint
        ? l10n.lastPlayedAt(formatMs(item.positionMs!))
        : '';
    final durationPart = item.durationMs != null
        ? ' / ${formatMs(item.durationMs!)}'
        : '';
    final tooltipText = hasBreakpoint ? '$baseTooltip$durationPart' : '';

    Widget tile = Material(
      color: isCurrent ? Tokens.bgHover : Colors.transparent,
      child: ListTile(
        dense: true,
        selected: isCurrent,
        selectedTileColor: Tokens.bgHover,
        leading: Icon(
          hasBreakpoint ? Icons.play_circle : Icons.play_arrow,
          color: isCurrent
              ? Tokens.accent
              : (hasBreakpoint ? Tokens.accent : Tokens.textDisabled),
          size: Tokens.iconMd,
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? Tokens.accent : Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
          ),
        ),
        subtitle: hasBreakpoint
            ? Text(
                l10n.breakpointAt(formatMs(item.positionMs!)),
                style: const TextStyle(
                  color: Tokens.accent,
                  fontSize: Tokens.fontOverline,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 14, color: Tokens.textDisabled),
          onPressed: onRemove,
          splashRadius: 14,
          tooltip: l10n.remove,
        ),
        onTap: onSelect,
      ),
    );

    // Tooltip（仅有断点时显示）
    if (tooltipText.isNotEmpty) {
      tile = Tooltip(
        message: tooltipText,
        waitDuration: const Duration(milliseconds: 400),
        child: tile,
      );
    }

    // 右键菜单
    return GestureDetector(
      onSecondaryTap: () => _showContextMenu(context),
      child: tile,
    );
  }

  void _showContextMenu(BuildContext context) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final l10n = AppLocalizations.of(context);
    showMenu<String>(
      context: context,
      position: position,
      color: Tokens.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusPopup),
      ),
      items: [
        PopupMenuItem(
          value: 'play',
          child: _MenuItemRow(Icons.play_arrow, l10n.playAction),
        ),
        PopupMenuItem(
          value: 'copy',
          child: _MenuItemRow(Icons.copy, l10n.copyPath),
        ),
        const PopupMenuDivider(),
        if (onShowProperties != null)
          PopupMenuItem(
            value: 'properties',
            child: _MenuItemRow(Icons.info_outline, l10n.properties),
          ),
        PopupMenuItem(
          value: 'remove',
          child: _MenuItemRow(Icons.delete_outline, l10n.remove),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'play':
          onSelect();
          break;
        case 'copy':
          Clipboard.setData(ClipboardData(text: item.path));
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(l10n.pathCopied),
              duration: const Duration(seconds: 1),
            ),
          );
          break;
        case 'properties':
          onShowProperties?.call(item.path);
          break;
        case 'remove':
          onRemove();
          break;
      }
    });
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuItemRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: Tokens.iconMd, color: Tokens.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int itemCount;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onClear;

  const _Header({
    required this.itemCount,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签行：播放列表 / 播放历史
          Row(
            children: [
              _TabButton(
                label: l10n.playlistTab,
                selected: selectedTab == 0,
                onTap: () => onTabChanged(0),
              ),
              const SizedBox(width: Tokens.spSm),
              _TabButton(
                label: l10n.historyTab,
                selected: selectedTab == 1,
                onTap: () => onTabChanged(1),
              ),
              const Spacer(),
              if (itemCount > 0 && selectedTab == 0)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: Tokens.iconMd),
                  color: Tokens.textDisabled,
                  onPressed: onClear,
                  splashRadius: 16,
                  tooltip: l10n.clear,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spSm,
            vertical: Tokens.spXs,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.bgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Tokens.accent : Tokens.textDisabled,
              fontSize: Tokens.fontCaption,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
