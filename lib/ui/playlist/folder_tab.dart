import 'dart:async';

import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/scanner/folder_scanner.dart';
import '../theme/tokens.dart';
import '../../kernel/utils/path_utils.dart';
import '../../l10n/app_localizations.dart';
import '../shared/context_menu_row.dart';
import 'thumbnail_tile.dart';

/// 文件夹分组数据
class _FolderGroup {
  final String folderPath;
  final List<PlaylistItem> items;
  const _FolderGroup({required this.folderPath, required this.items});
}

/// 文件夹扫描 Tab — 按文件夹分组，水平缩略图排列
///
/// - 按 folderPath 分组，每组显示路径标签（中间省略 + 文件夹图标）
/// - 组间微亮分界线
/// - 右键路径标签 → 打开文件夹 / 扫描文件夹
/// - 分组结果缓存：仅在 items 引用变化时重新计算
class FolderTab extends StatefulWidget {
  final List<PlaylistItem> items;
  final int currentIndex;
  final void Function(int originalIndex) onSelectIndex;
  final void Function(int originalIndex) onRemoveIndex;
  final void Function(String path)? onShowProperties;
  final void Function(String folderPath, List<PlaylistItem> scanned)?
  onFolderScanned;

  const FolderTab({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelectIndex,
    required this.onRemoveIndex,
    this.onShowProperties,
    this.onFolderScanned,
  });

  @override
  State<FolderTab> createState() => _FolderTabState();
}

class _FolderTabState extends State<FolderTab> {
  static final _pathSeparator = RegExp(r'[/\\]');
  List<_FolderGroup>? _cachedGroups;
  List<PlaylistItem>? _cachedItems;
  Map<String, int>? _cachedPathIndexMap;

  List<_FolderGroup> _getGroups() {
    // local 捕获消除字段 `!` (字段不提升, 即便刚赋值)
    final cached = _cachedGroups;
    if (cached != null && identical(_cachedItems, widget.items)) {
      return cached;
    }
    _cachedItems = widget.items;
    final groups = _groupByFolder(widget.items);
    _cachedGroups = groups;
    _cachedPathIndexMap = {
      for (var i = 0; i < widget.items.length; i++) widget.items[i].path: i,
    };
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
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

    final groups = _getGroups();
    // _getGroups() 后必非空, ?? const {} 防御兜底消除字段 `!`
    final pathIndexMap = _cachedPathIndexMap ?? const <String, int>{};

    return ListView.builder(
      scrollDirection: Axis.vertical,
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isLast = index == groups.length - 1;
        return _FolderGroupWidget(
          key: ValueKey(group.folderPath),
          group: group,
          pathIndexMap: pathIndexMap,
          currentIndex: widget.currentIndex,
          onSelectIndex: widget.onSelectIndex,
          onRemoveIndex: widget.onRemoveIndex,
          onShowProperties: widget.onShowProperties,
          onFolderScanned: widget.onFolderScanned,
          showDivider: !isLast,
        );
      },
    );
  }

  static List<_FolderGroup> _groupByFolder(List<PlaylistItem> items) {
    final map = <String, List<PlaylistItem>>{};
    for (final item in items) {
      final sep = item.path.lastIndexOf(_pathSeparator);
      final folder = sep > 0 ? item.path.substring(0, sep) : item.path;
      map.putIfAbsent(folder, () => []).add(item);
    }
    return map.entries
        .map((e) => _FolderGroup(folderPath: e.key, items: e.value))
        .toList();
  }
}

class _FolderGroupWidget extends StatelessWidget {
  final _FolderGroup group;
  final Map<String, int> pathIndexMap;
  final int currentIndex;
  final void Function(int originalIndex) onSelectIndex;
  final void Function(int originalIndex) onRemoveIndex;
  final void Function(String path)? onShowProperties;
  final void Function(String folderPath, List<PlaylistItem> scanned)?
  onFolderScanned;
  final bool showDivider;

  const _FolderGroupWidget({
    super.key,
    required this.group,
    required this.pathIndexMap,
    required this.currentIndex,
    required this.onSelectIndex,
    required this.onRemoveIndex,
    this.onShowProperties,
    this.onFolderScanned,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 路径标签
        _FolderPathLabel(
          folderPath: group.folderPath,
          // _scanFolder 已 async；unawaited 标注 fire-and-forget，不阻塞菜单回调
          onScan: () => unawaited(_scanFolder(context)),
          onOpen: () => _openFolder(),
        ),
        // 水平缩略图列表
        SizedBox(
          height: Tokens
              .thumbnailTileHeight, // thumbnail(90) + name(28) + padding(6)
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
            itemExtent: ThumbnailTile.tileWidth + Tokens.spSm,
            itemCount: group.items.length,
            itemBuilder: (context, index) {
              final item = group.items[index];
              final originalIndex = pathIndexMap[item.path] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: Tokens.spSm),
                child: RepaintBoundary(
                  child: ThumbnailTile(
                    key: ValueKey(item.path),
                    item: item,
                    isCurrent: originalIndex == currentIndex,
                    onPlay: () => onSelectIndex(originalIndex),
                    onResume: (item.positionMs ?? 0) > 0
                        ? () => onSelectIndex(originalIndex)
                        : null,
                    onRemove: () => onRemoveIndex(originalIndex),
                    onShowProperties: onShowProperties,
                  ),
                ),
              );
            },
          ),
        ),
        // 分界线
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.spMd),
            child: Divider(height: 1, color: Tokens.borderHighlight),
          ),
      ],
    );
  }

  void _openFolder() {
    PathUtils.openFileLocation(group.folderPath);
  }

  Future<void> _scanFolder(BuildContext _) async {
    // FolderScanner.scan 已异步化：避免扫描大文件夹时阻塞 UI
    final scanned = await FolderScanner.scan(group.folderPath);
    if (scanned.isNotEmpty) {
      onFolderScanned?.call(
        group.folderPath,
        scanned.map((vf) => PlaylistItem(path: vf.path)).toList(),
      );
    }
  }
}

/// 路径标签 — 中间省略 + 文件夹图标，右键菜单
class _FolderPathLabel extends StatelessWidget {
  final String folderPath;
  final VoidCallback onScan;
  final VoidCallback onOpen;

  const _FolderPathLabel({
    required this.folderPath,
    required this.onScan,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: () => unawaited(_showPathMenu(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spMd,
          vertical: Tokens.spXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder, size: 14, color: Tokens.textTertiary),
            const SizedBox(width: 4),
            Flexible(
              child: Tooltip(
                message: folderPath,
                waitDuration: const Duration(
                  milliseconds: Tokens.tooltipDelayLong,
                ),
                child: Text(
                  _truncateMiddle(folderPath, 36),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Tokens.textTertiary,
                    fontSize: Tokens.fontOverline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 中间省略：D:\Very\Long\Path → D:\Ver...\Path
  static String _truncateMiddle(String path, int maxLen) {
    if (path.length <= maxLen) return path;
    final keep = (maxLen - 3) ~/ 2;
    return '${path.substring(0, keep)}...${path.substring(path.length - keep)}';
  }

  Future<void> _showPathMenu(BuildContext context) async {
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

    final value = await showMenu<String>(
      context: context,
      position: position,
      color: Tokens.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusPopup),
      ),
      items: [
        PopupMenuItem(
          value: 'open',
          child: ContextMenuRow(Icons.folder_open, l10n.openFileLocation),
        ),
        PopupMenuItem(
          value: 'scan',
          child: ContextMenuRow(Icons.refresh, l10n.scanFolder),
        ),
      ],
    );
    if (value == null) return;
    switch (value) {
      case 'open':
        onOpen();
        break;
      case 'scan':
        onScan();
        break;
    }
  }
}
