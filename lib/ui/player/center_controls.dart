import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import '../theme/tokens.dart';

/// 播放/暂停按钮。
///
/// 播放/暂停切换的视觉状态完全由 [isPlaying] 驱动；空置态淡化由
/// [iconAlpha] 承担（中央组 TweenAnimationBuilder 渐变），命令合法性由
/// 引擎状态机统一守卫。
class PlayPauseButton extends StatelessWidget {
  final ValueListenable<bool> isPlaying;
  final VoidCallback onPlayPause;
  final double iconAlpha;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
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

/// 中央控制组：上一个、后退、播放/暂停、前进、下一个与停止 (v0.0.5)。
///
/// 切曲按钮紧贴播放键两侧（高频动作）；边界回绕合法性由引擎统一守卫
/// （越界时 media_kit 步进经引擎裁定，越界不循环场景回 false，配 OSD 提示）。
/// [isIdle] 只控制视觉淡化。停止命令必须通过
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

  /// 跳到队列上一个条目 — null 时隐藏按钮（无队列协调器场景）。
  final VoidCallback? onPreviousEntry;

  /// 跳到队列下一个条目 — null 时隐藏按钮。
  final VoidCallback? onNextEntry;

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
    this.onPreviousEntry,
    this.onNextEntry,
  });

  @override
  Widget build(BuildContext context) {
    // 单构造 + idle 参数化 — 有/无 isIdleListenable 两分支共享同一装配.
    Widget buildContent(bool idle) => _CenterGroupContent(
      isPlaying: isPlaying,
      onPlayPause: onPlayPause,
      onSeekBack: onSeekBack,
      onSeekForward: onSeekForward,
      isIdle: idle,
      showTransportActions: showTransportActions,
      onStop: onStop,
      onPreviousEntry: onPreviousEntry,
      onNextEntry: onNextEntry,
    );
    final listenable = isIdleListenable;
    if (listenable == null) return buildContent(isIdle);

    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (_, value, _) => buildContent(value),
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
  final VoidCallback? onPreviousEntry;
  final VoidCallback? onNextEntry;

  const _CenterGroupContent({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.isIdle,
    required this.showTransportActions,
    required this.onStop,
    this.onPreviousEntry,
    this.onNextEntry,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = isIdle
        ? Tokens.controlBarTextPrimaryIdle
        : Tokens.textPrimary;
    final l10n = AppLocalizations.of(context);

    // 显式顺序保证 Tab 按视觉顺序遍历 — v0.0.5 恢复队列导航按钮（1-6）。
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTransportActions && onPreviousEntry != null)
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: GlassButton.iconOnly(
                icon: Icons.skip_previous,
                color: dimmed,
                onPressed: onPreviousEntry,
                tooltip: l10n.previousTrack,
                semanticsLabel: l10n.previousTrack,
              ),
            ),
          if (showTransportActions) const SizedBox(width: Tokens.spSm),
          if (showTransportActions)
            FocusTraversalOrder(
              order: const NumericFocusOrder(2),
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
            order: const NumericFocusOrder(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isIdle ? 0.20 : 1.0),
              duration: const Duration(milliseconds: Tokens.durationFade),
              curve: Curves.easeOut,
              builder: (context, alpha, _) => PlayPauseButton(
                isPlaying: isPlaying,
                onPlayPause: onPlayPause,
                iconAlpha: alpha,
              ),
            ),
          ),
          if (showTransportActions) const SizedBox(width: Tokens.spSm),
          if (showTransportActions)
            FocusTraversalOrder(
              order: const NumericFocusOrder(4),
              child: GlassButton.iconOnly(
                icon: Icons.forward_30,
                color: dimmed,
                onPressed: () => onSeekForward(Tokens.skipLongMs),
                tooltip: l10n.forward30,
                semanticsLabel: l10n.forward30,
              ),
            ),
          if (showTransportActions && onNextEntry != null)
            FocusTraversalOrder(
              order: const NumericFocusOrder(5),
              child: GlassButton.iconOnly(
                icon: Icons.skip_next,
                color: dimmed,
                onPressed: onNextEntry,
                tooltip: l10n.nextTrack,
                semanticsLabel: l10n.nextTrack,
              ),
            ),
          if (showTransportActions) const SizedBox(width: Tokens.spXs),
          if (showTransportActions)
            FocusTraversalOrder(
              order: const NumericFocusOrder(6),
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
