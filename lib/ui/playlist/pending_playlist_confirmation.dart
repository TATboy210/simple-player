import 'dart:async';

import '../../kernel/models/playlist_item.dart';

/// 删除确认快照 — freezes path identity before any asynchronous user choice.
/// Ambiguous duplicates are never expanded into extra removals.
class PendingPlaylistConfirmation {
  PendingPlaylistConfirmation({
    required this.message,
    required List<PlaylistItem> entries,
    required Set<int> indices,
  }) : targets = List.unmodifiable([
         for (final index in indices)
           if (index >= 0 &&
               index < entries.length &&
               entries
                       .where((item) => item.path == entries[index].path)
                       .length ==
                   1)
             entries[index],
       ]);

  final String message;
  final List<PlaylistItem> targets;
  final Completer<bool> _result = Completer<bool>();
  Future<bool> get result => _result.future;

  /// Complete once; owner hide/replacement and user choice may race.
  void complete(bool confirmed) {
    if (!_result.isCompleted) _result.complete(confirmed);
  }

  /// Resolve synchronously at commit, skipping vanished/re-added/ambiguous paths.
  Set<int> resolve(List<PlaylistItem> entries) => Set.unmodifiable({
    for (final target in targets)
      if (entries.where((item) => item.path == target.path).length == 1)
        for (var index = 0; index < entries.length; index++)
          if (entries[index].path == target.path &&
              entries[index].addedSeq == target.addedSeq)
            index,
  });
}
