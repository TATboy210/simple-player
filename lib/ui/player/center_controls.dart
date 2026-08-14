import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import '../theme/tokens.dart';

/// 播放/暂停按钮。
///
/// [isIdle] 仅用于视觉淡化；命令合法性由引擎状态机统一守卫。
class PlayPauseButton extends StatelessWidget {
  final ValueListenable<bool> isPlaying;
  final VoidCallback onPlayPause;
  final bool isIdle;
  final double iconAlpha;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    this.isIdle = false,
    this.iconAlpha = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: isPlaying,
      builder: (_, playing, _) {
        final baseColor = playing ? Tokens.accent : Tokens.textPrimary;
        return GlassButton.iconOnly(
          icon: playing ? Icons.pause : Icons.play_arrow,
          iconSize: Tokens.iconXl,
          color: baseColor.withValues(alpha: baseColor.a * iconAlpha),
          onPressed: onPlayPause,
          tooltip: playing ? l10n.pause : l10n.play,
          semanticsLabel: playing ? l10n.pause : l10n.play,
          semanticsToggled: playing,
        );
      },
    );
  }
}

/// 单文件播放器中央控制组：后退、播放/暂停、前进与停止。
///
/// 四个按钮均保留稳定命中目标；[isIdle] 只控制视觉淡化。停止命令必须通过
/// [onStop] 进入项目控制器，以统一完成媒体卸载、标题和空置态收尾。
class CenterGroup extends StatelessWidget {
  final ValueListenable<bool> isPlaying;
  final VoidCallback onPlayPause;
  final void Function(int ms) onSeekBack;
  final void Function(int ms) onSeekForward;
  final bool isIdle;

  /// 播放器路径使用此监听器，将 idle 变化限制在中央按钮组。
  final ValueListenable<bool>? isIdleListenable;

  /// 停止并卸载当前媒体的项目层收尾入口。
  final VoidCallback? onStop;
  final bool showTransportActions;

  const CenterGroup({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.isIdle,
    this.isIdleListenable,
    this.onStop,
    this.showTransportActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final listenable = isIdleListenable;
    final content = _CenterGroupContent(
      isPlaying: isPlaying,
      onPlayPause: onPlayPause,
      onSeekBack: onSeekBack,
      onSeekForward: onSeekForward,
      isIdle: isIdle,
      showTransportActions: showTransportActions,
      onStop: onStop,
    );
    if (listenable == null) return content;

    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (_, value, _) => _CenterGroupContent(
        isPlaying: isPlaying,
        onPlayPause: onPlayPause,
        onSeekBack: onSeekBack,
        onSeekForward: onSeekForward,
        isIdle: value,
        showTransportActions: showTransportActions,
        onStop: onStop,
      ),
    );
  }
}

/// 中央控制组的局部内容，避免在 View 中使用构建辅助方法。
class _CenterGroupContent extends StatelessWidget {
  final ValueListenable<bool> isPlaying;
  final VoidCallback onPlayPause;
  final void Function(int ms) onSeekBack;
  final void Function(int ms) onSeekForward;
  final bool isIdle;
  final bool showTransportActions;
  final VoidCallback? onStop;

  const _CenterGroupContent({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.isIdle,
    required this.showTransportActions,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = isIdle
        ? Tokens.controlBarTextPrimaryIdle
        : Tokens.textPrimary;
    final l10n = AppLocalizations.of(context);

    // 显式顺序确保删去队列导航按钮后，Tab 仍按视觉顺序遍历。
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTransportActions)
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: GlassButton.iconOnly(
                icon: Icons.replay_10,
                color: dimmed,
                onPressed: () => onSeekBack(Tokens.skipShortMs),
                tooltip: l10n.rewind10,
                semanticsLabel: l10n.rewind10,
              ),
            ),
          const SizedBox(width: Tokens.spSm),
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isIdle ? 0.20 : 1.0),
              duration: const Duration(milliseconds: Tokens.durationFade),
              curve: Curves.easeOut,
              builder: (context, alpha, _) => PlayPauseButton(
                isPlaying: isPlaying,
                onPlayPause: onPlayPause,
                isIdle: isIdle,
                iconAlpha: alpha,
              ),
            ),
          ),
          if (showTransportActions) const SizedBox(width: Tokens.spSm),
          if (showTransportActions)
            FocusTraversalOrder(
              order: const NumericFocusOrder(3),
              child: GlassButton.iconOnly(
                icon: Icons.forward_30,
                color: dimmed,
                onPressed: () => onSeekForward(Tokens.skipLongMs),
                tooltip: l10n.forward30,
                semanticsLabel: l10n.forward30,
              ),
            ),
          if (showTransportActions) const SizedBox(width: Tokens.spXs),
          if (showTransportActions)
            FocusTraversalOrder(
              order: const NumericFocusOrder(4),
              child: GlassButton.iconOnly(
                icon: Icons.stop,
                color: dimmed,
                onPressed: onStop,
                enabled: onStop != null,
                tooltip: l10n.stop,
                semanticsLabel: l10n.stop,
              ),
            ),
        ],
      ),
    );
  }
}
