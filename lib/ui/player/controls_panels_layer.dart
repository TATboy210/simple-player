import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/services/playlist_coordinator.dart';
import '../dialogs/settings/settings_panel.dart';
import '../dialogs/settings/settings_panel_session.dart';
import 'controls_playlist_host.dart';
import 'controls_settings_host.dart';
import 'panel_workspace_controller.dart';
import 'workspace_focus_scope.dart';

/// 浮层面板层 — 播放列表(右侧竖条) + 设置(中列)，同层叠放且都铺满。
///
/// 任一数据源缺失时对应面板整体不挂载 (测试退路)；两者的几何/动画由各自
/// host 负责，本层只做条件挂载与参数转发。
class ControlsPanelsLayer extends StatelessWidget {
  const ControlsPanelsLayer({
    super.key,
    required this.playlistCoordinator,
    required this.playlistVisible,
    required this.workspace,
    required this.legacySettingsVisible,
    required this.focusRegistry,
    required this.settingsSession,
    required this.settingsServices,
    required this.scrubbing,
    required this.resizing,
  });

  final PlaylistCoordinator? playlistCoordinator;
  final ValueNotifier<bool>? playlistVisible;
  final PanelWorkspaceController? workspace;

  /// 注意: 传入的是 widget.settingsVisible 原值；workspace 非空时 host 忽略它。
  final ValueNotifier<bool>? legacySettingsVisible;
  final WorkspaceFocusRegistry? focusRegistry;
  final SettingsPanelSession? settingsSession;
  final SettingsServicesBundle? settingsServices;
  final ValueListenable<bool> scrubbing;
  final ValueListenable<bool>? resizing;

  @override
  Widget build(BuildContext context) {
    final coordinator = playlistCoordinator;
    final visible = playlistVisible;
    return Positioned.fill(
      child: Stack(
        children: [
          // 播放列表在下、设置在上，与原同层 Stack 的叠放顺序一致。
          if (coordinator != null && visible != null)
            ControlsPlaylistHost(
              coordinator: coordinator,
              visible: visible,
              scrubbing: scrubbing,
              resizing: resizing,
              settingsServices: settingsServices,
            ),
          if (workspace != null || legacySettingsVisible != null)
            ControlsSettingsHost(
              workspace: workspace,
              legacyVisible: legacySettingsVisible,
              focusRegistry: focusRegistry,
              session: settingsSession,
              services: settingsServices,
              scrubbing: scrubbing,
              resizing: resizing,
            ),
        ],
      ),
    );
  }
}
