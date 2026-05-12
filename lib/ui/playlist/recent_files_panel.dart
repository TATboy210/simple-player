import 'package:flutter/material.dart';

import '../../kernel/models/playlist_item.dart';
import '../../kernel/ui/theme/tokens.dart';

class RecentFilesPanel extends StatelessWidget {
  final List<PlaylistItem> items;
  final void Function(int index)? onTapItem;

  const RecentFilesPanel({super.key, required this.items, this.onTapItem});

  @override
  Widget build(BuildContext context) {
    final recent = items.where((i) => i.timestamp != null).toList()
      ..sort((a, b) => b.timestamp!.compareTo(a.timestamp!));

    if (recent.isEmpty) {
      return const Center(
        child: Text('No recent files', style: TextStyle(color: Tokens.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: recent.length,
      itemBuilder: (_, i) {
        final item = recent[i];
        return ListTile(
          leading: const Icon(Icons.history, color: Tokens.textTertiary, size: Tokens.iconMd),
          title: Text(
            item.name,
            style: const TextStyle(color: Tokens.textPrimary, fontSize: Tokens.fontCaption),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _relativeTime(item.timestamp!),
            style: const TextStyle(color: Tokens.textTertiary, fontSize: Tokens.fontOverline),
          ),
          onTap: onTapItem != null ? () => onTapItem!(items.indexOf(item)) : null,
        );
      },
    );
  }

  String _relativeTime(int timestampMs) {
    final diff = DateTime.now().millisecondsSinceEpoch - timestampMs;
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return '${(diff / 60000).floor()} min ago';
    if (diff < 86400000) return '${(diff / 3600000).floor()} hr ago';
    return '${(diff / 86400000).floor()} days ago';
  }
}
