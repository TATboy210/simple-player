/// 右侧按钮组模块 — 文件、字幕、播放列表、设置
///
/// 从 ControlBar 中提取的独立 Widget，负责控制栏底部行右侧按钮群。
/// 包含打开文件、打开字幕、播放列表、设置、全屏切换五个功能按钮。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import 'player_actions.dart';

/// 右侧按钮组：文件、字幕、播放列表、设置
class RightButtonGroup extends StatelessWidget {
  final PlayerActions actions;

  const RightButtonGroup({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.onOpenFile != null)
          GlassButton.iconOnly(
            icon: Icons.folder_open,
            onPressed: actions.onOpenFile,
            tooltip: l10n.openFileTooltip,
          ),
        if (actions.onOpenSubtitle != null)
          GlassButton.iconOnly(
            icon: Icons.subtitles,
            onPressed: actions.onOpenSubtitle,
            tooltip: l10n.openSubtitle,
          ),
        if (actions.onTogglePlaylist != null)
          GlassButton.iconOnly(
            icon: Icons.queue_music,
            onPressed: actions.onTogglePlaylist,
            tooltip: l10n.playlist,
          ),
        if (actions.onSettings != null)
          GlassButton.iconOnly(
            icon: Icons.settings,
            onPressed: actions.onSettings,
            onSecondaryTapUp: actions.onSettingsSecondary != null
                ? (d) => actions.onSettingsSecondary!(context, d)
                : null,
            tooltip: l10n.settings,
          ),
        if (actions.onToggleFullscreen != null)
          GlassButton.iconOnly(
            icon: Icons.fullscreen,
            onPressed: actions.onToggleFullscreen,
            tooltip: l10n.shortcutFullscreen,
          ),
      ],
    );
  }
}
