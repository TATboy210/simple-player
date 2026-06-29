import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';

/// 播放/暂停按钮
class PlayPauseButton extends StatelessWidget {
  final EngineState engine;
  final bool isIdle;
  final double iconAlpha;

  const PlayPauseButton({
    super.key,
    required this.engine,
    this.isIdle = false,
    this.iconAlpha = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<MediaState>(
      valueListenable: engine.state,
      builder: (_, state, _) {
        final playing = state == MediaState.playing;
        final baseColor = playing ? Tokens.accent : Tokens.textPrimary;
        return GlassButton.iconOnly(
          icon: playing ? Icons.pause : Icons.play_arrow,
          iconSize: Tokens.iconXl,
          color: baseColor.withValues(alpha: baseColor.a * iconAlpha),
          onPressed: isIdle ? null : engine.togglePlayPause,
          tooltip: playing ? l10n.pause : l10n.play,
        );
      },
    );
  }
}

/// 中央控制组（上一首/后退/播放暂停/前进/下一首/停止）
class CenterGroup extends StatelessWidget {
  final EngineState engine;
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
    final dimmed = isIdle
        ? Tokens.textPrimary.withValues(alpha: Tokens.textPrimary.a * 0.20)
        : Tokens.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassButton.iconOnly(
          icon: Icons.skip_previous,
          color: dimmed,
          onPressed: isIdle ? null : onPrevious,
          tooltip: prevTooltip,
        ),
        const SizedBox(width: Tokens.spXs),
        GlassButton.iconOnly(
          icon: Icons.replay_10,
          color: dimmed,
          onPressed: isIdle
              ? null
              : () => engine.skipBack(Tokens.skipSecondsShort),
          tooltip: AppLocalizations.of(context).rewind10,
        ),
        const SizedBox(width: Tokens.spSm),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: isIdle ? 0.20 : 1.0),
          duration: const Duration(milliseconds: Tokens.durationFade),
          curve: Curves.easeOut,
          builder: (context, alpha, _) =>
              PlayPauseButton(engine: engine, isIdle: isIdle, iconAlpha: alpha),
        ),
        const SizedBox(width: Tokens.spSm),
        GlassButton.iconOnly(
          icon: Icons.forward_30,
          color: dimmed,
          onPressed: isIdle
              ? null
              : () => engine.skipForward(Tokens.skipSecondsLong),
          tooltip: AppLocalizations.of(context).forward30,
        ),
        const SizedBox(width: Tokens.spXs),
        GlassButton.iconOnly(
          icon: Icons.skip_next,
          color: dimmed,
          onPressed: isIdle ? null : onNext,
          tooltip: nextTooltip,
        ),
        const SizedBox(width: Tokens.spXs),
        GlassButton.iconOnly(
          icon: Icons.stop,
          color: dimmed,
          onPressed: isIdle ? null : engine.stop,
          tooltip: AppLocalizations.of(context).stop,
        ),
      ],
    );
  }
}
