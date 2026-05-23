import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/models/media_state.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_icon_button.dart';

/// 播放/暂停按钮
class PlayPauseButton extends StatelessWidget {
  final MediaEngine engine;
  final bool isIdle;

  const PlayPauseButton({super.key, required this.engine, this.isIdle = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<MediaState>(
      valueListenable: engine.state,
      builder: (_, state, _) {
        final playing = state == MediaState.playing;
        return GlassIconButton(
          icon: playing ? Icons.pause : Icons.play_arrow,
          iconSize: Tokens.iconXl,
          color: playing ? Tokens.accent : Tokens.textPrimary,
          onPressed: isIdle ? null : engine.togglePlayPause,
          tooltip: playing ? l10n.pause : l10n.play,
        );
      },
    );
  }
}

/// 中央控制组（上一首/后退/播放暂停/前进/下一首/停止）
class CenterGroup extends StatelessWidget {
  final MediaEngine engine;
  final bool isIdle;
  final String prevTooltip;
  final String nextTooltip;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const CenterGroup({
    super.key,
    required this.engine,
    required this.isIdle,
    required this.prevTooltip,
    required this.nextTooltip,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isIdle ? 0.20 : 1.0,
      duration: const Duration(milliseconds: Tokens.durationFade),
      curve: Curves.easeOut,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassIconButton(
            icon: Icons.skip_previous,
            onPressed: isIdle ? null : onPrevious,
            tooltip: prevTooltip,
          ),
          const SizedBox(width: Tokens.spXs),
          GlassIconButton(
            icon: Icons.replay_10,
            onPressed: isIdle ? null : () => engine.skipBack(10),
            tooltip: AppLocalizations.of(context).rewind10,
          ),
          const SizedBox(width: Tokens.spSm),
          PlayPauseButton(engine: engine, isIdle: isIdle),
          const SizedBox(width: Tokens.spSm),
          GlassIconButton(
            icon: Icons.forward_30,
            onPressed: isIdle ? null : () => engine.skipForward(30),
            tooltip: AppLocalizations.of(context).forward30,
          ),
          const SizedBox(width: Tokens.spXs),
          GlassIconButton(
            icon: Icons.skip_next,
            onPressed: isIdle ? null : onNext,
            tooltip: nextTooltip,
          ),
          const SizedBox(width: Tokens.spXs),
          GlassIconButton(
            icon: Icons.stop,
            onPressed: isIdle ? null : engine.stop,
            tooltip: AppLocalizations.of(context).stop,
          ),
        ],
      ),
    );
  }
}
