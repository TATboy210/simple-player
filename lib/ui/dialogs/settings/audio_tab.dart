import 'package:flutter/material.dart';

import '../../../kernel/engine/media_engine.dart';
import '../../../kernel/ui/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// 音轨选择 tab — 列出可用音轨，点击切换
class AudioTab extends StatelessWidget {
  final MediaEngine engine;
  const AudioTab({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tracks = engine.getAudioTracks();
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          l10n.noAudioTracks,
          style: const TextStyle(color: Tokens.textSecondary),
        ),
      );
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final track = tracks[i];
        final active = engine.activeAudioTracks.contains(i);
        final label = track.codec.isEmpty
            ? l10n.audioTrackN(i + 1)
            : '${track.codec} (${track.channels}ch)';
        return ListTile(
          leading: Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            color: active ? Tokens.accent : Tokens.textDisabled,
            size: Tokens.iconLg,
          ),
          title: Text(
            label,
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontCaption,
            ),
          ),
          subtitle: track.language.isNotEmpty
              ? Text(
                  track.language,
                  style: const TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontOverline,
                  ),
                )
              : null,
          onTap: () {
            engine.switchAudioTrack(i);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
