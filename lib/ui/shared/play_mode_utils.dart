import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../kernel/models/play_mode.dart';

/// PlayMode → IconData 映射（避免 ControlBar + PlaylistPanel 两处 switch 重复）
IconData playModeIcon(PlayMode mode) {
  return switch (mode) {
    PlayMode.loopAll => Icons.repeat,
    PlayMode.loopSingle => Icons.repeat_one,
    PlayMode.shuffle => Icons.shuffle,
  };
}

/// PlayMode → 本地化标签
String playModeLabel(PlayMode mode, AppLocalizations l10n) {
  return switch (mode) {
    PlayMode.loopAll => l10n.playModeLoopAll,
    PlayMode.loopSingle => l10n.playModeLoopSingle,
    PlayMode.shuffle => l10n.playModeShuffle,
  };
}
