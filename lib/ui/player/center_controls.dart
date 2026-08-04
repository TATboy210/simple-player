import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';

/// 播放/暂停按钮
///
/// 永可点契约:onPressed 始终绑定 [onPlayPause],不再按 isIdle 置 null。
/// 合法性由引擎层幂等 guard 保证(见 EngineStateMachine.togglePlayPause:
/// opening/error 态 no-op,playing→pause,idle/paused/completed→play)。
/// [isIdle] 仅用于 [iconAlpha] 视觉淡化(保留),不参与命中判定。
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 [isPlaying] ValueListenable
/// + [onPlayPause] 回调(playing 不再从 engine.state 派生)。
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

/// 中央控制组（上一首/后退/播放暂停/前进/下一首/停止）
///
/// 按钮永可点契约:六个按钮不以 [isIdle] 置 null。
/// 后退、播放和前进直接绑定 [onSeekBack]/[onPlayPause]/[onSeekForward];
/// 停止优先走 [onStop],使 [PlaybackController.stopCurrentMedia] 在项目层
/// 统一完成标题与空置态收尾。[isIdle] 仅用于 [dimmed] 视觉淡化(保留)。
///
/// 上一首/下一首按回调存在性禁用:[onPrevious]/[onNext] == null 时
/// GlassButton._effectiveEnabled=false(同时禁用命中与视觉反馈)。
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 ValueListenable + 回调。
/// stop 按钮:[onStop] == null 时禁用(原 fallback engine.stop 移除,
/// 生产路径 onStop 非 null,独立控件兼容性微降,可接受)。
class CenterGroup extends StatelessWidget {
  final ValueListenable<bool> isPlaying;
  final VoidCallback onPlayPause;
  final void Function(int ms) onSeekBack;
  final void Function(int ms) onSeekForward;
  final bool isIdle;
  final String prevTooltip;
  final String nextTooltip;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// 停止并卸载当前媒体的项目层收尾入口。
  final VoidCallback? onStop;

  const CenterGroup({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.isIdle,
    required this.prevTooltip,
    required this.nextTooltip,
    this.onPrevious,
    this.onNext,
    this.onStop,
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
              onPressed: () => onSeekForward(Tokens.skipLongMs),
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
              // 生产路径传入控制器收尾回调;onStop == null 时禁用
              // (原 fallback engine.stop 移除,独立控件兼容性微降,可接受).
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
