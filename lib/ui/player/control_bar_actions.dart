import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'center_controls.dart';
import 'left_button_group.dart';
import 'player_actions.dart';
import 'right_button_group.dart';

/// 控制栏动作行：左侧设置、中部播放和右侧文件动作各自保持既有可访问性契约。
class ControlBarActions extends StatelessWidget {
  final MediaEngine engine;
  final PlayerActions actions;
  final bool isIdle;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const ControlBarActions({
    super.key,
    required this.engine,
    required this.actions,
    required this.isIdle,
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
            engine: engine,
            actions: actions,
            onInteractionStart: onInteractionStart,
            onInteractionEnd: onInteractionEnd,
          ),
          const Spacer(),
          CenterGroup(
            engine: engine,
            isIdle: isIdle,
            prevTooltip: l10n.previousTrack,
            nextTooltip: l10n.nextTrack,
            onPrevious: actions.onPrevious,
            onNext: actions.onNext,
            onStop: actions.onStop,
          ),
          const Spacer(),
          RightButtonGroup(actions: actions),
        ],
      ),
    );
  }
}
