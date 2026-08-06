import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'thumbnail_tile.dart';

/// 播放历史 Tab — 水平缩略图，按时间戳降序，相对时间标签
///
/// 最新在最左，每个缩略图下方有相对时间（"2小时前"）。
class HistoryTab extends StatefulWidget {
  final List<PlaylistItem> items;
  final int currentIndex;
  final void Function(int originalIndex) onSelectIndex;
  final void Function(int originalIndex) onRemoveIndex;
  final void Function(String path)? onShowProperties;
  final VoidCallback? onClearHistory;

  const HistoryTab({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelectIndex,
    required this.onRemoveIndex,
    this.onShowProperties,
    this.onClearHistory,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<MapEntry<int, PlaylistItem>>? _cachedHistoryItems;
  List<PlaylistItem>? _cachedItems;

  List<MapEntry<int, PlaylistItem>> _getHistoryItems() {
    // local 捕获消除字段 `!` (字段不提升, 即便刚赋值)
    final cached = _cachedHistoryItems;
    if (cached != null && identical(_cachedItems, widget.items)) {
      return cached;
    }
    _cachedItems = widget.items;
    final items =
        widget.items
            .asMap()
            .entries
            .where((e) => (e.value.timestamp ?? 0) > 0)
            .toList()
          ..sort(
            (a, b) =>
                (b.value.timestamp ?? 0).compareTo(a.value.timestamp ?? 0),
          );
    _cachedHistoryItems = items;
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final historyItems = _getHistoryItems();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 清空历史按钮
        if (widget.onClearHistory != null)
          Padding(
            padding: const EdgeInsets.only(
              left: Tokens.spMd,
              top: Tokens.spXs,
              bottom: Tokens.spXs,
            ),
            child: GestureDetector(
              onTap: widget.onClearHistory,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: Tokens.textDisabled,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).clearHistory,
                    style: const TextStyle(
                      color: Tokens.textDisabled,
                      fontSize: Tokens.fontOverline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // 水平缩略图列表
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.spSm),
            itemExtent: ThumbnailTile.tileWidth + Tokens.spSm,
            itemCount: historyItems.length,
            itemBuilder: (context, index) {
              final entry = historyItems[index];
              final item = entry.value;
              final originalIndex = entry.key;
              final isCurrent = originalIndex == widget.currentIndex;

              return Padding(
                padding: const EdgeInsets.only(right: Tokens.spSm),
                child: RepaintBoundary(
                  child: _HistoryTileWrapper(
                    key: ValueKey(item.path),
                    timestamp: item.timestamp,
                    child: ThumbnailTile(
                      item: item,
                      isCurrent: isCurrent,
                      onPlay: () => widget.onSelectIndex(originalIndex),
                      onResume: (item.positionMs ?? 0) > 0
                          ? () => widget.onSelectIndex(originalIndex)
                          : null,
                      onRemove: () => widget.onRemoveIndex(originalIndex),
                      onShowProperties: widget.onShowProperties,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 包装缩略图，添加相对时间标签
class _HistoryTileWrapper extends StatelessWidget {
  final int? timestamp;
  final Widget child;

  const _HistoryTileWrapper({
    super.key,
    required this.timestamp,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // local 捕获 timestamp 消除字段 `!` (字段不提升)
    final ts = timestamp;
    if (ts == null || ts == 0) return child;

    final l10n = AppLocalizations.of(context);
    final relativeTime = _formatRelativeTime(ts, l10n);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            relativeTime,
            style: const TextStyle(color: Tokens.textDisabled, fontSize: 9),
          ),
        ),
      ],
    );
  }

  static String _formatRelativeTime(int timestampMs, AppLocalizations l10n) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    return l10n.daysAgo(diff.inDays);
  }
}
