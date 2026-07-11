/// 左侧按钮组模块 — 播放模式 + 音量 + 倍速
///
/// 从 ControlBar 中提取的独立 Widget，负责控制栏底部行左侧按钮群。
/// 包含播放模式切换、音量控制、倍速选择三个功能区。
library;

import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import '../theme/tokens.dart';
import 'player_actions.dart';
import 'speed_button.dart';
import 'volume_controls.dart';

/// 左侧按钮组：播放模式 + 音量 + 倍速
class LeftButtonGroup extends StatelessWidget {
  final EngineState engine;
  final PlayerActions actions;

  const LeftButtonGroup({super.key, required this.engine, required this.actions});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassButton.iconOnly(
          icon: actions.playModeIcon ?? Icons.repeat,
          tooltip: actions.playModeLabel ?? l10n.playModeLoopAll,
          onPressed: actions.onTogglePlayMode,
        ),
        const SizedBox(width: Tokens.spXs),
        VolumeButton(engine: engine),
        VolumeSlider(engine: engine),
        const SizedBox(width: Tokens.spXs),
        SpeedButton(engine: engine),
      ],
    );
  }
}
