import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../dialogs/settings/settings_panel.dart';
import '../dialogs/settings/settings_panel_session.dart';
import 'panel_workspace_controller.dart';
import 'panel_workspace_host.dart';
import 'panel_workspace_layout.dart';
import 'workspace_focus_scope.dart';

/// 设置面板挂载点 (v0.0.7.2) — 控制栏上方区域**中列**槽位，与播放列表同层，
/// 全高度避开控制栏；共享会话保存展示数据，各 route 独立拥有焦点。
///
/// workspace 非空时走工作区任务模型；否则退回 legacy 布尔 seam (独立控件测试)，
/// 几何一致。两者都为空时不渲染。
class ControlsSettingsHost extends StatelessWidget {
  const ControlsSettingsHost({
    super.key,
    required this.workspace,
    required this.legacyVisible,
    required this.focusRegistry,
    required this.session,
    required this.services,
    required this.scrubbing,
    required this.resizing,
  });

  final PanelWorkspaceController? workspace;

  /// legacy 可见性 seam — 仅 workspace 为空时使用。
  final ValueNotifier<bool>? legacyVisible;

  /// 本 route 焦点注册表 — 关闭时走焦点归还链。
  final WorkspaceFocusRegistry? focusRegistry;
  final SettingsPanelSession? session;
  final SettingsServicesBundle? services;
  final ValueListenable<bool> scrubbing;
  final ValueListenable<bool>? resizing;

  @override
  Widget build(BuildContext context) {
    final shared = workspace;
    if (shared != null) return _workspaceHost(shared);
    final legacy = legacyVisible;
    if (legacy == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (_, constraints) {
          final layout = PanelWorkspaceLayout.calculate(constraints.biggest);
          return ValueListenableBuilder<bool>(
            valueListenable: legacy,
            builder: (_, visible, _) => Stack(
              children: [
                Positioned.fromRect(
                  rect: layout.center,
                  child: _panel(visible, onClose: () => legacy.value = false),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _workspaceHost(PanelWorkspaceController shared) {
    return Positioned.fill(
      child: PanelWorkspaceHost(
        controller: shared,
        resizeSignal: resizing,
        tasks: [
          WorkspaceTask(
            id: WorkspaceTaskIds.settings,
            builder: (_, visible, role) => _panel(
              visible,
              onClose: () => focusRegistry?.close(
                WorkspaceTaskIds.settings,
                WorkspaceCloseCause.header,
              ),
              onPromote: role == WorkspaceTaskRole.left
                  ? () => shared.promote(WorkspaceTaskIds.settings)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  SettingsPanel _panel(
    bool visible, {
    required VoidCallback onClose,
    VoidCallback? onPromote,
  }) {
    return SettingsPanel(
      visible: visible,
      session: session,
      services: services,
      scrubbing: scrubbing,
      resizing: resizing,
      onClose: onClose,
      onPromote: onPromote,
    );
  }
}
