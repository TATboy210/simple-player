/// 右侧按钮组模块 — 文件、字幕、播放列表、设置
///
/// 从 ControlBar 中提取的独立 Widget，负责控制栏底部行右侧按钮群。
/// 包含打开文件、打开字幕、播放列表、设置、全屏切换五个功能按钮。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import 'player_actions.dart';

/// 右侧按钮组：文件、字幕、播放列表、设置
///
/// 路径B Commit1:加 [isFullscreen] ValueListenable 驱动全屏按钮图标
/// (fullscreen ↔ fullscreen_exit),原恒定 Icons.fullscreen 改为动态。
class RightButtonGroup extends StatelessWidget {
  final PlayerActions actions;

  /// 全屏切换回调 — 优先于 actions.onToggleFullscreen.
  ///
  /// ControlsOverlay 传 _toggleFullscreen(同时做 setMode + 本实例 videoState
  /// route 切换); 若未传则回退 actions.onToggleFullscreen(仅 setMode, 兼容旧调用).
  final VoidCallback? onToggleFullscreen;

  /// 全屏状态 — 驱动全屏按钮图标(enter ↔ exit)。
  /// null 时 fallback 恒定 enter 图标(兼容未接入场景,生产路径总传非 null)。
  final ValueListenable<bool>? isFullscreen;

  const RightButtonGroup({
    super.key,
    required this.actions,
    this.onToggleFullscreen,
    this.isFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 全屏按钮 — 优先显式 onToggleFullscreen(ControlsOverlay._toggleFullscreen,
    // 同时 setMode 同步 + 本实例 videoState route 切换); 回退 actions.onToggleFullscreen.
    final fullscreenCb = onToggleFullscreen ?? actions.onToggleFullscreen;
    // 局部变量促 flow promotion(避免 isFullscreen! bang)。
    final fsListenable = isFullscreen;
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
        if (fullscreenCb != null)
          // isFullscreen 驱动图标:全屏时 exit 图标,非全屏时 enter 图标.
          // null 时 fallback 恒定 enter 图标(兼容未接入场景).
          fsListenable != null
              ? ValueListenableBuilder<bool>(
                  valueListenable: fsListenable,
                  builder: (_, fs, _) => GlassButton.iconOnly(
                    icon: fs ? Icons.fullscreen_exit : Icons.fullscreen,
                    onPressed: fullscreenCb,
                    tooltip: l10n.shortcutFullscreen,
                  ),
                )
              : GlassButton.iconOnly(
                  icon: Icons.fullscreen,
                  onPressed: fullscreenCb,
                  tooltip: l10n.shortcutFullscreen,
                ),
      ],
    );
  }
}
