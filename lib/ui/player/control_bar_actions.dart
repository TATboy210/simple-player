import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/playlist/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'center_controls.dart';
import 'control_bar_view_model.dart';
import 'left_button_group.dart';
import 'player_actions.dart';
import 'right_button_group.dart';

/// 控制栏动作行：左侧设置、中部播放和右侧文件动作各自保持既有可访问性契约。
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 [ControlBarViewModel]。
class ControlBarActions extends StatelessWidget {
  final ControlBarViewModel vm;
  final PlayerActions actions;
  final Playlist playlist;
  final ValueListenable<int> playlistGeneration;
  final bool isIdle;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  /// 全屏切换回调 — 透传给 RightButtonGroup 全屏按钮.
  final VoidCallback? onToggleFullscreen;

  const ControlBarActions({
    super.key,
    required this.vm,
    required this.actions,
    required this.playlist,
    required this.playlistGeneration,
    required this.isIdle,
    this.onToggleFullscreen,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.controlBarButtonRowPadding,
      ),
      child: Row(
        children: [
          LeftButtonGroup(
            volume: vm.volume,
            isMuted: vm.isMuted,
            rate: vm.rate,
            onToggleMute: vm.onToggleMute,
            onSetVolume: vm.onSetVolume,
            onSetRate: vm.onSetRate,
            playlist: playlist,
            playlistGeneration: playlistGeneration,
            onTogglePlayMode: actions.onTogglePlayMode,
            onInteractionStart: onInteractionStart,
            onInteractionEnd: onInteractionEnd,
          ),
          const Spacer(),
          CenterGroup(
            isPlaying: vm.isPlaying,
            onPlayPause: vm.onPlayPause,
            onSeekBack: vm.onSeekBack,
            onSeekForward: vm.onSeekForward,
            isIdle: isIdle,
            prevTooltip: l10n.previousTrack,
            nextTooltip: l10n.nextTrack,
            onPrevious: actions.onPrevious,
            onNext: actions.onNext,
            onStop: actions.onStop,
          ),
          const Spacer(),
          RightButtonGroup(
            actions: actions,
            onToggleFullscreen: onToggleFullscreen,
            isFullscreen: vm.isFullscreen,
          ),
        ],
      ),
    );
  }
}
