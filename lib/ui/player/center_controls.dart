import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';

/// 播放/暂停按钮
///
/// 永可点契约:onPressed 始终绑定 engine.togglePlayPause,不再按 isIdle 置 null。
/// 合法性由引擎层幂等 guard 保证(见 [EngineStateMachine.togglePlayPause]:
/// opening/error 态 no-op,playing→pause,idle/paused/completed→play)。
/// [isIdle] 仅用于 [iconAlpha] 视觉淡化(保留),不参与命中判定。
class PlayPauseButton extends StatelessWidget {
  final MediaEngine engine;
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
          onPressed: engine.togglePlayPause,
          tooltip: playing ? l10n.pause : l10n.play,
          semanticsLabel: playing ? l10n.pause : l10n.play,
          semanticsToggled: playing,
        );
      },
    );
  }
}

/// 中央控制组（上一首/后退/播放暂停/前进/下一首/停止）
///
/// 按钮永可点契约:六个按钮的命令直接绑定引擎方法,不以 [isIdle] 置 null。
/// 引擎层 guard 下沉保证幂等 —— idle 态 seekTo/stop no-op、opening/error 态
/// toggle no-op,重复命令不产生不一致(见 [MediaKitEngine.play/pause/stop/seekTo])。
/// [isIdle] 仅用于 [dimmed] 视觉淡化(保留)。
///
/// 上一首/下一首按回调存在性禁用:[onPrevious]/[onNext] == null 时
/// GlassButton._effectiveEnabled=false(同时禁用命中与视觉反馈)。
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
    final dimmed = isIdle
        ? Tokens.controlBarTextPrimaryIdle
        : Tokens.textPrimary;
    final l10n = AppLocalizations.of(context);

    // 有序策略只定义遍历目标；MaterialApp 的默认 Tab 快捷键负责派发遍历意图。
    // 内部 Row 的视觉顺序、间距和命中几何保持不变。
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: GlassButton.iconOnly(
              icon: Icons.skip_previous,
              color: dimmed,
              onPressed: onPrevious,
              enabled: onPrevious != null,
              tooltip: prevTooltip,
              semanticsLabel: prevTooltip,
            ),
          ),
          const SizedBox(width: Tokens.spXs),
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: GlassButton.iconOnly(
              icon: Icons.replay_10,
              color: dimmed,
              onPressed: () => engine.skipBack(Tokens.skipShortMs),
              tooltip: l10n.rewind10,
              semanticsLabel: l10n.rewind10,
            ),
          ),
          const SizedBox(width: Tokens.spSm),
          FocusTraversalOrder(
            order: const NumericFocusOrder(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isIdle ? 0.20 : 1.0),
              duration: const Duration(milliseconds: Tokens.durationFade),
              curve: Curves.easeOut,
              builder: (context, alpha, _) => PlayPauseButton(
                engine: engine,
                isIdle: isIdle,
                iconAlpha: alpha,
              ),
            ),
          ),
          const SizedBox(width: Tokens.spSm),
          FocusTraversalOrder(
            order: const NumericFocusOrder(4),
            child: GlassButton.iconOnly(
              icon: Icons.forward_30,
              color: dimmed,
              onPressed: () => engine.skipForward(Tokens.skipLongMs),
              tooltip: l10n.forward30,
              semanticsLabel: l10n.forward30,
            ),
          ),
          const SizedBox(width: Tokens.spXs),
          FocusTraversalOrder(
            order: const NumericFocusOrder(5),
            child: GlassButton.iconOnly(
              icon: Icons.skip_next,
              color: dimmed,
              onPressed: onNext,
              enabled: onNext != null,
              tooltip: nextTooltip,
              semanticsLabel: nextTooltip,
            ),
          ),
          const SizedBox(width: Tokens.spXs),
          FocusTraversalOrder(
            order: const NumericFocusOrder(6),
            child: GlassButton.iconOnly(
              icon: Icons.stop,
              color: dimmed,
              onPressed: engine.stop,
              tooltip: l10n.stop,
              semanticsLabel: l10n.stop,
            ),
          ),
        ],
      ),
    );
  }
}
