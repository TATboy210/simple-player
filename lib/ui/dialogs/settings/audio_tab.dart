import 'package:flutter/material.dart';

import '../../../kernel/engine/engine_state.dart';
import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/glass_container.dart';
import '../../shared/animated_section_list.dart';
import '../../shared/section_header.dart';
import '../../shared/settings_card.dart'; // SettingRow export

/// Audio track selection tab — lists available audio tracks and allows switching.
///
/// Queries [MediaEngine.getAudioTracks] for the current file's audio streams.
/// Each track shows codec, channel count, and language when available.
/// Tapping a track calls [MediaEngine.switchAudioTrack] and closes the dialog.
class AudioTab extends StatelessWidget {
  final MediaEngine engine;

  /// 音轨切换后录制偏好 — 由上层传入，避免 UI 直接依赖 kernel 服务
  final ValueChanged<int>? onAudioTrackChanged;
  const AudioTab({super.key, required this.engine, this.onAudioTrackChanged});

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
    return AnimatedSectionList(
      children: [
        // 音轨选择 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.audioTrack, icon: Icons.headphones),
              for (int i = 0; i < tracks.length; i++)
                _AudioTrackRow(
                  track: tracks[i],
                  index: i,
                  active: engine.activeAudioTracks.contains(i),
                  l10n: l10n,
                  onTap: () {
                    engine.switchAudioTrack(i);
                    onAudioTrackChanged?.call(i);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AudioTrackRow extends StatelessWidget {
  final AudioTrackInfo track;
  final int index;
  final bool active;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _AudioTrackRow({
    required this.track,
    required this.index,
    required this.active,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = track.codec.isEmpty
        ? l10n.audioTrackN(index + 1)
        : '${track.codec} (${track.channels}ch)';

    return SettingRow(
      title: label,
      description: track.language.isNotEmpty ? track.language : null,
      control: Icon(
        active ? Icons.check_circle : Icons.radio_button_unchecked,
        color: active ? Tokens.accent : Tokens.textDisabled,
        size: Tokens.iconLg,
      ),
      onTap: onTap,
    );
  }
}
