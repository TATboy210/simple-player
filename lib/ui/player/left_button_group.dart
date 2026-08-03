/// 左侧按钮组模块 — 播放模式 + 音量 + 倍速
///
/// 从 ControlBar 中提取的独立 Widget，负责控制栏底部行左侧按钮群。
/// 包含播放模式切换、音量控制、倍速选择三个功能区。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../../kernel/playlist/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import '../shared/play_mode_utils.dart';
import '../theme/tokens.dart';
import 'speed_button.dart';
import 'volume_controls.dart';

/// 左侧按钮组：播放模式 + 音量 + 倍速
///
/// playMode 下沉：原由 PlayerScreen 在 build 时算好 playModeIcon/Label 经
/// PlayerActions 传入；ControlsOverlay 住进 Video.controls builder 后 actions
/// 必须稳定化，故 mode 图标/标签改为本组件内部用 [playlist.mode] +
/// [playlistGeneration] 计算（generation 变化驱动重建读最新 mode）。
class LeftButtonGroup extends StatelessWidget {
  final MediaEngine engine;
  final Playlist playlist;

  /// 播放模式切换的间接驱动源 — 切换 mode 时 generation++ 触发本组重建。
  final ValueListenable<int> playlistGeneration;

  /// 播放模式切换回调（来自稳定的 PlayerActions.onTogglePlayMode）。
  final VoidCallback? onTogglePlayMode;

  /// 子控件交互边界透传给 Overlay，统一冻结或恢复自动隐藏策略。
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const LeftButtonGroup({
    super.key,
    required this.engine,
    required this.playlist,
    required this.playlistGeneration,
    this.onTogglePlayMode,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // playlist.mode 是普通 getter（非 ValueNotifier），借
        // playlistGeneration ValueListenableBuilder 间接驱动刷新 —
        // 切换播放模式时 generation++ 触发重建，读取最新 mode。
        ValueListenableBuilder<int>(
          valueListenable: playlistGeneration,
          builder: (_, _, _) {
            final mode = playlist.mode;
            return GlassButton.iconOnly(
              icon: playModeIcon(mode),
              tooltip: playModeLabel(mode, l10n),
              onPressed: onTogglePlayMode,
            );
          },
        ),
        const SizedBox(width: Tokens.spXs),
        VolumeButton(engine: engine),
        VolumeSlider(
          engine: engine,
          onInteractionStart: onInteractionStart,
          onInteractionEnd: onInteractionEnd,
        ),
        const SizedBox(width: Tokens.spXs),
        SpeedButton(engine: engine),
      ],
    );
  }
}
